using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Application.UseCases
{
    /// <summary>
    /// Event args for loading state.
    /// </summary>
    public class LoadingEventArgs : EventArgs
    {
        public string Message { get; }
        public string ColorName { get; }

        public LoadingEventArgs(string message, string colorName)
        {
            Message = message;
            ColorName = colorName;
        }
    }

    /// <summary>
    /// Event args for received question.
    /// </summary>
    public class QuestionReceivedEventArgs : EventArgs
    {
        public string Text { get; }
        public string Topic { get; }
        public InterviewMessage.MessageType MessageType { get; }
        public AudioSource Source { get; }

        public QuestionReceivedEventArgs(string text, string topic, InterviewMessage.MessageType messageType, AudioSource source)
        {
            Text = text;
            Topic = topic;
            MessageType = messageType;
            Source = source;
        }
    }

    /// <summary>
    /// Event args for streaming started.
    /// </summary>
    public class StreamingStartedEventArgs : EventArgs
    {
        public InterviewMessage.MessageType MessageType { get; }
        public string Topic { get; }
        public int? LatencyMs { get; }

        public StreamingStartedEventArgs(InterviewMessage.MessageType messageType, string topic, int? latencyMs)
        {
            MessageType = messageType;
            Topic = topic;
            LatencyMs = latencyMs;
        }
    }

    /// <summary>
    /// Protocol for voice interview processor callbacks.
    /// </summary>
    public interface IVoiceInterviewProcessorDelegate
    {
        string UserBackground { get; }
        string PinnedSolution { get; }
        ConversationContext ConversationContext { get; }
    }

    /// <summary>
    /// Handles voice interview audio processing: transcription, classification, and answer generation.
    /// </summary>
    public class VoiceInterviewProcessor : IDisposable
    {
        private static readonly string _logFile = Path.Combine(Directory.GetCurrentDirectory(), "interview_debug.log");
        private static readonly object _logLock = new();

        private static void PipelineLog(string message)
        {
            var entry = $"[{DateTime.Now:HH:mm:ss.fff}] [VoiceProcessor] {message}{Environment.NewLine}";
            lock (_logLock) { try { File.AppendAllText(_logFile, entry); } catch { } }
            System.Diagnostics.Debug.WriteLine(message);
        }

        private IGroqInterviewClient? _groqClient;
        private IAnthropicClient? _anthropicClient;
        private IVoiceInterviewProcessorDelegate? _delegate;

        // Deduplication state
        private List<(string text, DateTime timestamp, AudioSource source)> _recentTranscriptions = new();
        private const double DedupeWindow = 3.0;
        private const double SimilarityThreshold = 0.7;

        // Utterance buffering state
        private string _utteranceBuffer = "";
        private DateTime? _bufferTimestamp;
        private const double BufferTimeout = 2.0;

        // Answer cooldown
        private DateTime? _lastAnswerTime;
        private const double AnswerCooldown = 5.0;

        // Streaming content
        private string _streamingContent = "";

        // Latency tracking
        private DateTime? _questionEndTime;

        // Events - signatures match what VoiceInterviewController expects
        public event EventHandler<LoadingEventArgs>? ShowLoading;
        public event EventHandler? HideLoading;
        public event EventHandler<QuestionReceivedEventArgs>? QuestionReceived;
        public event EventHandler<StreamingStartedEventArgs>? StreamingStarted;
        public event EventHandler<string>? AnswerChunkReceived;
        public event EventHandler<string>? AnswerFinished;
        public event EventHandler<string>? StatusUpdated;

        public VoiceInterviewProcessor()
        {
            AppNotifications.ApiKeysUpdated += OnApiKeysUpdated;
            AppNotifications.InterviewSettingsUpdated += OnInterviewSettingsUpdated;
        }

        public void Configure(IGroqInterviewClient groqClient, IAnthropicClient anthropicClient, IVoiceInterviewProcessorDelegate @delegate)
        {
            _groqClient = groqClient;
            _anthropicClient = anthropicClient;
            _delegate = @delegate;
            System.Diagnostics.Debug.WriteLine(
                $"VoiceInterviewProcessor configured - groq: {(groqClient != null)}, anthropic: {(anthropicClient != null)}"
            );
        }

        public void Reset()
        {
            _recentTranscriptions.Clear();
            _utteranceBuffer = "";
            _bufferTimestamp = null;
            _lastAnswerTime = null;
            _streamingContent = "";
            _questionEndTime = null;
        }

        // MARK: - Deduplication

        private double StringSimilarity(string a, string b)
        {
            var wordsA = new HashSet<string>(a.ToLower().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries));
            var wordsB = new HashSet<string>(b.ToLower().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries));

            if (wordsA.Count == 0 && wordsB.Count == 0) return 0;

            var intersection = wordsA.Intersect(wordsB).Count();
            var union = wordsA.Union(wordsB).Count();

            return union > 0 ? (double)intersection / union : 0;
        }

        private bool IsDuplicateTranscription(string text, AudioSource source)
        {
            var now = DateTime.UtcNow;
            _recentTranscriptions.RemoveAll(entry => (now - entry.timestamp).TotalSeconds > DedupeWindow);

            foreach (var recent in _recentTranscriptions)
            {
                var similarity = StringSimilarity(text, recent.text);
                if (similarity > SimilarityThreshold)
                {
                    var lengthRatio = (double)text.Length / Math.Max(recent.text.Length, 1);
                    if (lengthRatio > 1.3) continue;
                    return true;
                }
            }

            _recentTranscriptions.Add((text, now, source));
            return false;
        }

        public bool CheckForQuestionMarkers(string text)
        {
            var lowerText = text.ToLower();
            var markers = new[]
            {
                "?",
                "what is", "what are", "what's", "whats", "what did", "what do",
                "how do", "how does", "how is", "how would", "how can", "how to",
                "why do", "why does", "why is", "why would",
                "can you explain", "could you explain", "can you tell", "could you tell",
                "tell me about", "tell me more",
                "explain ", "describe ",
                "what about", "how about",
                "difference between", "differences between",
                "when do", "when does", "when would", "when should",
                "where do", "where does", "where is",
                "which ", "who ", "whose "
            };

            return markers.Any(marker => lowerText.Contains(marker));
        }

        // MARK: - Main Processing Pipeline

        public async Task ProcessAudioSegmentAsync(byte[] audioData, AudioSource source)
        {
            var sourceLabel = source == AudioSource.Microphone ? "MIC" : "SYS";
            PipelineLog($"AUDIO [{sourceLabel}] ProcessAudioSegment called with {audioData.Length} bytes");

            if (_groqClient == null)
            {
                PipelineLog($"ERROR [{sourceLabel}] groqClient is NULL - cannot transcribe");
                return;
            }

            try
            {
                // 1. Show loading state
                OnShowLoading("Transcribing...", "CornflowerBlue");

                // 2. Start Anthropic connection warmup in background
                if (_anthropicClient != null)
                {
                    _ = _anthropicClient.WarmupConnectionAsync();
                }

                // 3. Transcribe audio
                PipelineLog($"TRANSCRIBE [{sourceLabel}] sending {audioData.Length} bytes to Groq STT...");
                var (transcription, sttLatency) = await _groqClient.TranscribeAsync(audioData);
                _questionEndTime = DateTime.UtcNow;

                var trimmed = transcription.Trim();
                PipelineLog($"TRANSCRIBE [{sourceLabel}] STT result ({sttLatency:F0}ms): \"{(trimmed.Length > 80 ? trimmed.Substring(0, 80) + "..." : trimmed)}\"");

                // 4. Validate
                if (string.IsNullOrEmpty(trimmed))
                {
                    PipelineLog($"TRANSCRIBE [{sourceLabel}] empty transcription, skipping");
                    OnHideLoading();
                    return;
                }

                // 5. Deduplication
                if (IsDuplicateTranscription(trimmed, source))
                {
                    PipelineLog($"TRANSCRIBE [{sourceLabel}] duplicate transcription, skipping");
                    OnHideLoading();
                    return;
                }

                // 6. MICROPHONE = YOUR VOICE
                if (source == AudioSource.Microphone)
                {
                    PipelineLog($"AUDIO [MIC] adding user utterance to context: \"{trimmed.Substring(0, Math.Min(50, trimmed.Length))}...\"");
                    OnHideLoading();
                    _delegate?.ConversationContext.AddUtterance(
                        trimmed,
                        _delegate?.ConversationContext.LastTopic ?? "unknown"
                    );
                    return;
                }

                // 7. SYSTEM AUDIO = INTERVIEWER
                if (_anthropicClient == null)
                {
                    PipelineLog("ERROR [SYS] anthropicClient is NULL - cannot generate answer");
                    OnHideLoading();
                    return;
                }

                OnShowLoading("Analyzing...", "MediumPurple");

                // 8. Classify utterance
                PipelineLog("[SYS] CLASSIFY: classifying utterance...");
                var (classification, classLatency) = await _groqClient.ClassifyUtteranceAsync(
                    trimmed, _utteranceBuffer, _delegate?.ConversationContext.LastTopic ?? "unknown");

                var isQuestion = classification.Status == "question" || CheckForQuestionMarkers(trimmed);
                var topic = classification.Topic ?? "unknown";
                PipelineLog($"[SYS] CLASSIFY: status={classification.Status} topic={topic} isQuestion={isQuestion}");

                // 9. Fire question received event
                var messageType = isQuestion ? InterviewMessage.MessageType.Question : InterviewMessage.MessageType.UserResponse;
                OnQuestionReceived(trimmed, topic, messageType, source);

                // 10. Add to conversation context
                _delegate?.ConversationContext.AddUtterance(trimmed, topic, isQuestion);

                if (!isQuestion)
                {
                    PipelineLog("[SYS] CLASSIFY: not a question, buffering statement");
                    _utteranceBuffer = trimmed;
                    OnHideLoading();
                    return;
                }

                // 11. Answer cooldown check
                if (_lastAnswerTime.HasValue && (DateTime.UtcNow - _lastAnswerTime.Value).TotalSeconds < AnswerCooldown)
                {
                    PipelineLog("[SYS] ANSWER: cooldown active, skipping");
                    OnHideLoading();
                    return;
                }

                // 12. Calculate latency
                var latencyMs = _questionEndTime.HasValue
                    ? (int)(DateTime.UtcNow - _questionEndTime.Value).TotalMilliseconds
                    : (int?)null;

                // 13. Fire streaming started
                PipelineLog($"[SYS] ANSWER: streaming for topic={topic} latency={latencyMs}ms");
                OnStreamingStarted(InterviewMessage.MessageType.Answer, topic, latencyMs);

                // 14. Build messages and stream answer
                var userBackground = _delegate?.UserBackground ?? "";
                var pinnedSolution = _delegate?.PinnedSolution;
                var context = _delegate?.ConversationContext;

                var multiTurnMessages = context?.BuildMultiTurnMessages(trimmed, pinnedSolution) ?? new List<ConversationContext.MultiTurnMessage>();
                var messagesForAPI = context?.MessagesToAPIFormat(multiTurnMessages) ?? new List<object>();

                PipelineLog($"[SYS] STREAM: calling Anthropic StreamAnswer with {messagesForAPI.Count} messages...");
                _streamingContent = "";
                await _anthropicClient.StreamAnswerAsync(
                    trimmed,
                    messagesForAPI,
                    userBackground,
                    onChunk: (chunk) =>
                    {
                        _streamingContent += chunk;
                        OnAnswerChunkReceived(_streamingContent);
                    }
                );

                _lastAnswerTime = DateTime.UtcNow;
                PipelineLog($"[SYS] ANSWER: complete, {_streamingContent.Length} chars");
                OnFinishedAnswer(_streamingContent);

                // Add answer to conversation context
                context?.AddUtterance(_streamingContent, topic);

                OnHideLoading();
            }
            catch (Exception ex)
            {
                PipelineLog($"ERROR [{sourceLabel}] ProcessAudioSegment FAILED: {ex.Message}\n{ex.StackTrace}");
                OnHideLoading();
            }
        }

        private void OnApiKeysUpdated()
        {
            System.Diagnostics.Debug.WriteLine("AppNotifications: ApiKeysUpdated received");
            OnStatusUpdated("API keys updated");
        }

        private void OnInterviewSettingsUpdated()
        {
            System.Diagnostics.Debug.WriteLine("AppNotifications: InterviewSettingsUpdated received");
            OnStatusUpdated("Interview settings updated");
        }

        public void Dispose()
        {
            AppNotifications.ApiKeysUpdated -= OnApiKeysUpdated;
            AppNotifications.InterviewSettingsUpdated -= OnInterviewSettingsUpdated;
        }

        // Event helpers
        protected virtual void OnShowLoading(string message, string colorName)
        {
            ShowLoading?.Invoke(this, new LoadingEventArgs(message, colorName));
        }

        protected virtual void OnHideLoading()
        {
            HideLoading?.Invoke(this, EventArgs.Empty);
        }

        protected virtual void OnQuestionReceived(string text, string topic, InterviewMessage.MessageType messageType, AudioSource source)
        {
            QuestionReceived?.Invoke(this, new QuestionReceivedEventArgs(text, topic, messageType, source));
        }

        protected virtual void OnStreamingStarted(InterviewMessage.MessageType messageType, string topic, int? latencyMs)
        {
            StreamingStarted?.Invoke(this, new StreamingStartedEventArgs(messageType, topic, latencyMs));
        }

        protected virtual void OnAnswerChunkReceived(string chunk)
        {
            AnswerChunkReceived?.Invoke(this, chunk);
        }

        protected virtual void OnFinishedAnswer(string fullAnswer)
        {
            AnswerFinished?.Invoke(this, fullAnswer);
        }

        protected virtual void OnStatusUpdated(string status)
        {
            StatusUpdated?.Invoke(this, status);
        }
    }
}
