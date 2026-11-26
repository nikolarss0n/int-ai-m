using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Application.UseCases
{
    public class LoadingEventArgs : EventArgs
    {
        public string Message { get; }
        public string ColorName { get; }
        public Guid TurnId { get; }

        public LoadingEventArgs(string message, string colorName, Guid? turnId = null)
        {
            Message = message;
            ColorName = colorName;
            TurnId = turnId ?? Guid.NewGuid();
        }
    }

    public class QuestionReceivedEventArgs : EventArgs
    {
        public string Text { get; }
        public string Topic { get; }
        public InterviewMessage.MessageType MessageType { get; }
        public AudioSource Source { get; }
        public Guid TurnId { get; }
        public int Sequence { get; }

        public QuestionReceivedEventArgs(
            string text,
            string topic,
            InterviewMessage.MessageType messageType,
            AudioSource source,
            Guid? turnId = null,
            int sequence = 0)
        {
            Text = text;
            Topic = topic;
            MessageType = messageType;
            Source = source;
            TurnId = turnId ?? Guid.NewGuid();
            Sequence = sequence;
        }
    }

    public class StreamingStartedEventArgs : EventArgs
    {
        public InterviewMessage.MessageType MessageType { get; }
        public string Topic { get; }
        public int? LatencyMs { get; }
        public Guid TurnId { get; }
        public int Sequence { get; }

        public StreamingStartedEventArgs(
            InterviewMessage.MessageType messageType,
            string topic,
            int? latencyMs,
            Guid? turnId = null,
            int sequence = 0)
        {
            MessageType = messageType;
            Topic = topic;
            LatencyMs = latencyMs;
            TurnId = turnId ?? Guid.NewGuid();
            Sequence = sequence;
        }
    }

    public class AnswerChunkEventArgs : EventArgs
    {
        public string FullContent { get; }
        public Guid TurnId { get; }
        public AnswerChunkEventArgs(string fullContent, Guid turnId) { FullContent = fullContent; TurnId = turnId; }
    }

    public class AnswerFinishedEventArgs : EventArgs
    {
        public string FullAnswer { get; }
        public int? TotalLatencyMs { get; }
        public Guid TurnId { get; }
        public AnswerFinishedEventArgs(string fullAnswer, int? totalLatencyMs, Guid turnId)
        {
            FullAnswer = fullAnswer;
            TotalLatencyMs = totalLatencyMs;
            TurnId = turnId;
        }
    }

    public interface IVoiceInterviewProcessorDelegate
    {
        string UserBackground { get; }
        string ResumeText { get; }
        string? PinnedSolution { get; }
        ConversationContext ConversationContext { get; }
    }

    /// <summary>
    /// Handles live voice interview audio processing: transcription, local understanding guards,
    /// combined classify-and-stream answering, spoken coding task streaming, briefing updates,
    /// memory retrieval, and automatic conversation summarization.
    /// </summary>
    public class VoiceInterviewProcessor : IDisposable
    {
        private static readonly string LogFile = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "InterviewMaster",
            "interview_debug.log");
        private static readonly object LogLock = new();

        private static void PipelineLog(string message)
        {
            var entry = $"[{DateTime.Now:HH:mm:ss.fff}] [VoiceProcessor] {message}{Environment.NewLine}";
            lock (LogLock)
            {
                try
                {
                    var dir = Path.GetDirectoryName(LogFile);
                    if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir)) Directory.CreateDirectory(dir);
                    File.AppendAllText(LogFile, entry);
                }
                catch { }
            }
            System.Diagnostics.Debug.WriteLine(message);
        }

        private IGroqInterviewClient? _groqClient;
        private IAnthropicClient? _llmClient;
        private IVoiceInterviewProcessorDelegate? _delegate;
        private MemoryRetrievalUseCase _memoryRetrieval = new();

        private readonly object _stateLock = new();
        private readonly Func<DateTime> _now;

        private readonly List<(string Text, DateTime Timestamp, AudioSource Source)> _recentTranscriptions = new();
        private string _utteranceBuffer = string.Empty;
        private DateTime? _bufferTimestamp;
        private string? _lastQuestionText;
        private DateTime? _lastQuestionTime;
        private DateTime? _lastAnswerTime;
        private InterviewBriefing? _currentBriefing;
        private int _nextTurnSequence = 1;
        private int _turnGeneration;
        private bool _summaryInFlight;

        private readonly CodingSessionState _codingSession = new();
        private CodingRequest? _lastCodingRequest;

        private sealed record CodingRequest(string Task, string Text, string? Change, Guid CardTurnId, int TurnSequence);

        public event EventHandler<LoadingEventArgs>? ShowLoading;
        public event EventHandler? HideLoading;
        public event EventHandler<QuestionReceivedEventArgs>? QuestionReceived;
        public event EventHandler<StreamingStartedEventArgs>? StreamingStarted;
        public event EventHandler<AnswerChunkEventArgs>? AnswerChunkReceived;
        public event EventHandler<AnswerFinishedEventArgs>? AnswerFinished;
        public event EventHandler<string>? StatusUpdated;
        public event EventHandler<InterviewBriefing>? BriefingUpdated;
        public event EventHandler<CodingTaskInfo>? CodingTaskStarted;
        public event EventHandler<string>? CodingTaskUpdated;
        public event EventHandler<CodingTaskOutcome>? CodingTaskFinished;

        public VoiceInterviewProcessor(Func<DateTime>? now = null)
        {
            _now = now ?? (() => DateTime.UtcNow);
            AppNotifications.ApiKeysUpdated += OnApiKeysUpdated;
            AppNotifications.InterviewSettingsUpdated += OnInterviewSettingsUpdated;
        }

        public void Configure(
            IGroqInterviewClient? groqClient,
            IAnthropicClient? llmClient,
            IVoiceInterviewProcessorDelegate @delegate,
            IMemoryStore? memoryStore = null)
        {
            _groqClient = groqClient;
            _llmClient = llmClient;
            _delegate = @delegate;
            _memoryRetrieval = new MemoryRetrievalUseCase(memoryStore);

            if (groqClient != null) _ = groqClient.WarmupConnectionAsync();
            if (llmClient != null) _ = llmClient.WarmupConnectionAsync();
        }

        public void Reset()
        {
            lock (_stateLock)
            {
                _turnGeneration++;
                _recentTranscriptions.Clear();
                _utteranceBuffer = string.Empty;
                _bufferTimestamp = null;
                _lastQuestionText = null;
                _lastQuestionTime = null;
                _lastAnswerTime = null;
                _currentBriefing = null;
                _nextTurnSequence = 1;
                _summaryInFlight = false;
                _codingSession.Clear();
                _lastCodingRequest = null;
            }
            _groqClient?.CancelCurrentRequest();
            _llmClient?.CancelCurrentRequest();
        }

        public void ResetCaptureBuffers()
        {
            lock (_stateLock)
            {
                _utteranceBuffer = string.Empty;
                _bufferTimestamp = null;
            }
        }

        // MARK: - Pure helpers (also tested directly)

        public static double StringSimilarity(string a, string b)
        {
            var wordsA = new HashSet<string>((a ?? string.Empty).ToLowerInvariant().Split(' ', StringSplitOptions.RemoveEmptyEntries));
            var wordsB = new HashSet<string>((b ?? string.Empty).ToLowerInvariant().Split(' ', StringSplitOptions.RemoveEmptyEntries));
            if (wordsA.Count == 0 && wordsB.Count == 0) return 0;
            var intersection = wordsA.Intersect(wordsB).Count();
            var union = wordsA.Union(wordsB).Count();
            return union > 0 ? (double)intersection / union : 0;
        }

        public bool CheckForQuestionMarkers(string text) => ConversationUnderstanding.HasQuestionMarkers(text);

        /// <summary>
        /// Deterministic cleanup of cue-card answers so bullets read naturally while preserving code blocks.
        /// </summary>
        public static string ConversationalDisplayAnswer(string raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return string.Empty;
            var text = raw.Replace("\r\n", "\n").Trim();

            // Preserve code blocks untouched
            if (text.Contains("```", StringComparison.Ordinal)) return text;

            var lines = text.Split('\n')
                .Select(l => l.Trim())
                .Where(l => !string.IsNullOrEmpty(l))
                .ToList();

            var cleaned = new List<string>();
            foreach (var line in lines)
            {
                var s = line;
                // Drop boilerplate intros
                if (cleaned.Count == 0 &&
                    (s.StartsWith("Sure,", StringComparison.OrdinalIgnoreCase) ||
                     s.StartsWith("Here's", StringComparison.OrdinalIgnoreCase) ||
                     s.StartsWith("Here is", StringComparison.OrdinalIgnoreCase) ||
                     s.StartsWith("Great question", StringComparison.OrdinalIgnoreCase)))
                {
                    continue;
                }

                // Strip markdown bold markers in cue-card bullets
                s = Regex.Replace(s, @"\*\*(.+?)\*\*", "$1");
                if (s.StartsWith("• ", StringComparison.Ordinal) || s.StartsWith("* ", StringComparison.Ordinal))
                    s = "- " + s[2..].Trim();
                else if (Regex.IsMatch(s, @"^\d+\.\s+"))
                    s = "- " + Regex.Replace(s, @"^\d+\.\s+", string.Empty).Trim();

                cleaned.Add(s);
            }

            return cleaned.Count == 0 ? text : string.Join("\n", cleaned);
        }

        private bool IsDuplicateTranscription(string text, AudioSource source)
        {
            var now = _now();
            lock (_stateLock)
            {
                _recentTranscriptions.RemoveAll(e => (now - e.Timestamp).TotalSeconds > AppConstants.Thresholds.DedupeWindow);
                foreach (var recent in _recentTranscriptions)
                {
                    var sim = StringSimilarity(text, recent.Text);
                    if (sim > AppConstants.Thresholds.SimilarityThreshold)
                    {
                        var lengthRatio = (double)text.Length / Math.Max(recent.Text.Length, 1);
                        if (lengthRatio > 1.3) continue;
                        return true;
                    }
                }
                _recentTranscriptions.Add((text, now, source));
                return false;
            }
        }

        // MARK: - Main audio pipeline

        public async Task ProcessAudioSegmentAsync(byte[] audioData, AudioSource source, CancellationToken ct = default)
        {
            var sourceLabel = source == AudioSource.Microphone ? "MIC" : "SYS";
            PipelineLog($"AUDIO [{sourceLabel}] received {audioData.Length} bytes");

            if (_groqClient == null)
            {
                PipelineLog($"ERROR [{sourceLabel}] groqClient is NULL");
                OnStatusUpdated("Error: Groq API key is not configured.");
                return;
            }

            var turnId = Guid.NewGuid();
            int generation;
            lock (_stateLock) generation = _turnGeneration;

            try
            {
                OnShowLoading("Transcribing…", "CornflowerBlue", turnId);
                if (_llmClient != null) _ = _llmClient.WarmupConnectionAsync();

                var (transcription, sttLatency) = await _groqClient.TranscribeAsync(audioData, ct: ct).ConfigureAwait(false);
                var questionEndTime = _now();
                var trimmed = (transcription ?? string.Empty).Trim();
                PipelineLog($"TRANSCRIBE [{sourceLabel}] ({sttLatency:F0}ms): \"{trimmed}\"");

                if (string.IsNullOrEmpty(trimmed) ||
                    ConversationUnderstanding.IsWhisperHallucination(trimmed) ||
                    ConversationUnderstanding.IsNonAsciiGarbageForEnglish(trimmed, AppSettings.Shared.ListeningLanguage))
                {
                    PipelineLog($"SKIP [{sourceLabel}] empty/hallucination/non-ASCII");
                    OnHideLoading();
                    return;
                }

                if (IsDuplicateTranscription(trimmed, source))
                {
                    PipelineLog($"SKIP [{sourceLabel}] duplicate");
                    OnHideLoading();
                    return;
                }

                // Microphone = candidate voice (unless user selected Microphone-only as interviewer capture)
                if (source == AudioSource.Microphone && AppSettings.Shared.CaptureDevice == CaptureDevice.Both)
                {
                    OnHideLoading();
                    _delegate?.ConversationContext.AddUtterance(
                        trimmed,
                        _delegate?.ConversationContext.LastTopic ?? "unknown",
                        isQuestion: false);
                    return;
                }

                await ProcessInterviewerTranscriptAsync(trimmed, source, questionEndTime, turnId, generation, ct)
                    .ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                OnHideLoading();
            }
            catch (Exception ex)
            {
                PipelineLog($"ERROR [{sourceLabel}] {ex.Message}");
                OnStatusUpdated($"Error: {ex.Message}");
                OnHideLoading();
            }
        }

        /// <summary>
        /// Processes a transcribed interviewer utterance (also directly testable without audio hardware).
        /// </summary>
        public async Task ProcessInterviewerTranscriptAsync(
            string trimmed,
            AudioSource source,
            DateTime questionEndTime,
            Guid turnId,
            int generation,
            CancellationToken ct = default)
        {
            if (ConversationUnderstanding.LooksGarbled(trimmed))
            {
                PipelineLog($"GARBLED: \"{trimmed}\"");
                OnStatusUpdated(FeedbackCopy.DidntCatchThat);
                OnHideLoading();
                return;
            }

            // Expire stale utterance buffer and combine if buffered
            string combinedText;
            lock (_stateLock)
            {
                if (!string.IsNullOrEmpty(_utteranceBuffer) && _bufferTimestamp.HasValue &&
                    (questionEndTime - _bufferTimestamp.Value).TotalSeconds > AppConstants.Thresholds.BufferTimeout)
                {
                    _utteranceBuffer = string.Empty;
                    _bufferTimestamp = null;
                }

                if (!string.IsNullOrEmpty(_utteranceBuffer))
                {
                    combinedText = $"{_utteranceBuffer} {trimmed}".Trim();
                    _utteranceBuffer = string.Empty;
                    _bufferTimestamp = null;
                }
                else
                {
                    var continued = ConversationUnderstanding.ContinuedQuestion(
                        _lastQuestionText,
                        trimmed,
                        _lastQuestionTime.HasValue ? (questionEndTime - _lastQuestionTime.Value).TotalSeconds : null,
                        AppConstants.Thresholds.QuestionContinuationWindow);
                    combinedText = continued ?? trimmed;
                }
            }

            // Local candidate speech / filler / incomplete guards
            var norm = ConversationUnderstanding.Normalized(combinedText);
            if (ConversationUnderstanding.ShouldSkipAsFillerOrGreeting(combinedText) ||
                ConversationUnderstanding.IsCandidateMetaUtterance(combinedText) ||
                ConversationUnderstanding.LooksLikeCandidateNarrative(norm))
            {
                PipelineLog($"SKIP candidate/filler: \"{combinedText}\"");
                _delegate?.ConversationContext.AddUtterance(combinedText, _delegate?.ConversationContext.LastTopic ?? "unknown", isQuestion: false);
                OnHideLoading();
                return;
            }

            if (ConversationUnderstanding.IsLocallyIncomplete(combinedText))
            {
                PipelineLog($"BUFFER incomplete: \"{combinedText}\"");
                lock (_stateLock)
                {
                    _utteranceBuffer = combinedText;
                    _bufferTimestamp = questionEndTime;
                }
                OnHideLoading();
                return;
            }

            // Trim trailing connective if question trailed off
            var held = ConversationUnderstanding.HeldQuestion(combinedText);
            if (!string.IsNullOrEmpty(held))
                combinedText = held;

            // Update CV briefing strip (never blocks or opens a cue card)
            var resumeText = _delegate?.ResumeText ?? string.Empty;
            var nextBriefing = InterviewBriefingHelper.NextBriefing(combinedText, true, resumeText, _currentBriefing);
            if (nextBriefing != null)
            {
                _currentBriefing = nextBriefing;
                BriefingUpdated?.Invoke(this, nextBriefing);
            }

            if (_llmClient == null)
            {
                OnStatusUpdated("Error: Answer model API key is not configured.");
                OnHideLoading();
                return;
            }

            // Check spoken coding task flow
            CodingTurnDecision? codingDecision;
            lock (_stateLock)
            {
                codingDecision = CodingInterviewStepsHelper.DecideTurn(
                    combinedText,
                    _codingSession,
                    questionEndTime,
                    _delegate?.ConversationContext.LastInterviewerQuestion);
            }

            if (codingDecision != null)
            {
                await HandleCodingDecisionAsync(codingDecision, combinedText, source, questionEndTime, turnId, ct)
                    .ConfigureAwait(false);
                return;
            }

            // Standard live interview classify-and-stream path
            int sequence;
            lock (_stateLock)
            {
                sequence = _nextTurnSequence++;
                _lastQuestionText = combinedText;
                _lastQuestionTime = questionEndTime;
            }

            var context = _delegate?.ConversationContext;
            var recentContext = context?.GetContextForLLM() ?? string.Empty;
            var refersBack = ConversationUnderstanding.RefersBackToConversation(combinedText);
            var lastTopic = refersBack ? context?.LastTopic : null;
            var memoryTopics = !string.IsNullOrWhiteSpace(lastTopic) ? new[] { lastTopic } : Array.Empty<string>();
            var memoryContext = _memoryRetrieval.Retrieve(memoryTopics);

            OnShowLoading("Thinking…", "MediumPurple", turnId);

            bool cardOpened = false;
            string resolvedTopic = lastTopic ?? "unknown";
            var answerAccum = string.Empty;

            var result = await _llmClient.ClassifyAndStreamAnswerAsync(
                utterance: combinedText,
                recentContext: recentContext,
                userBackground: _delegate?.UserBackground ?? string.Empty,
                resumeText: resumeText,
                memoryContext: memoryContext,
                pinnedSolution: _delegate?.PinnedSolution,
                lastTopic: lastTopic,
                onClassification: classification =>
                {
                    var isQuestion = string.Equals(classification.Status, "question", StringComparison.OrdinalIgnoreCase) ||
                                     CheckForQuestionMarkers(combinedText);
                    resolvedTopic = string.IsNullOrWhiteSpace(classification.Topic) ? (lastTopic ?? "unknown") : classification.Topic;

                    if (isQuestion && !cardOpened)
                    {
                        cardOpened = true;
                        var latencyMs = (int)(_now() - questionEndTime).TotalMilliseconds;
                        OnQuestionReceived(combinedText, resolvedTopic, InterviewMessage.MessageType.Question, source, turnId, sequence);
                        var isFollowUp = ConversationUnderstanding.FollowsPrevious(combinedText, resolvedTopic, context?.LastTopic);
                        OnStreamingStarted(
                            isFollowUp ? InterviewMessage.MessageType.FollowUp : InterviewMessage.MessageType.Answer,
                            resolvedTopic,
                            latencyMs,
                            turnId,
                            sequence);
                    }
                },
                onAnswerChunk: chunk =>
                {
                    if (!cardOpened)
                    {
                        cardOpened = true;
                        var latencyMs = (int)(_now() - questionEndTime).TotalMilliseconds;
                        OnQuestionReceived(combinedText, resolvedTopic, InterviewMessage.MessageType.Question, source, turnId, sequence);
                        OnStreamingStarted(InterviewMessage.MessageType.Answer, resolvedTopic, latencyMs, turnId, sequence);
                    }
                    answerAccum += chunk;
                    OnAnswerChunkReceived(answerAccum, turnId);
                },
                ct: ct).ConfigureAwait(false);

            var isQuestionFinal = string.Equals(result.Classification.Status, "question", StringComparison.OrdinalIgnoreCase) ||
                                  CheckForQuestionMarkers(combinedText) ||
                                  !string.IsNullOrWhiteSpace(result.FullAnswer);

            if (!isQuestionFinal)
            {
                if (string.Equals(result.Classification.Status, "incomplete", StringComparison.OrdinalIgnoreCase))
                {
                    lock (_stateLock)
                    {
                        _utteranceBuffer = combinedText;
                        _bufferTimestamp = questionEndTime;
                    }
                }
                context?.AddUtterance(combinedText, resolvedTopic, isQuestion: false, sequence: sequence);
                OnHideLoading();
                return;
            }

            if (!cardOpened)
            {
                var latencyMs = (int)(_now() - questionEndTime).TotalMilliseconds;
                OnQuestionReceived(combinedText, resolvedTopic, InterviewMessage.MessageType.Question, source, turnId, sequence);
                OnStreamingStarted(InterviewMessage.MessageType.Answer, resolvedTopic, latencyMs, turnId, sequence);
            }

            // Empty-answer fallback recovery
            var finalRaw = !string.IsNullOrWhiteSpace(result.FullAnswer) ? result.FullAnswer : answerAccum;
            if (string.IsNullOrWhiteSpace(finalRaw))
            {
                var multiTurn = context?.BuildMultiTurnMessages(combinedText, _delegate?.PinnedSolution) ?? new();
                var apiMsgs = context?.MessagesToAPIFormat(multiTurn) ?? new();
                var recovered = string.Empty;
                await _llmClient.StreamAnswerAsync(
                    combinedText,
                    apiMsgs,
                    _delegate?.UserBackground ?? string.Empty,
                    chunk =>
                    {
                        recovered += chunk;
                        OnAnswerChunkReceived(recovered, turnId);
                    },
                    ct).ConfigureAwait(false);
                finalRaw = recovered;
            }

            var displayAnswer = ConversationalDisplayAnswer(finalRaw);
            var totalLatencyMs = (int)(_now() - questionEndTime).TotalMilliseconds;

            context?.AddUtterance(combinedText, resolvedTopic, isQuestion: true, sequence: sequence);
            context?.AddUtterance(displayAnswer, resolvedTopic, isQuestion: false);

            lock (_stateLock) _lastAnswerTime = _now();
            OnFinishedAnswer(displayAnswer, totalLatencyMs, turnId);
            OnHideLoading();

            // Background auto-summarization
            if (context != null && context.NeedsSummarization)
                ScheduleSummarization(context, generation);
        }

        private async Task HandleCodingDecisionAsync(
            CodingTurnDecision decision,
            string spokenText,
            AudioSource source,
            DateTime questionEndTime,
            Guid turnId,
            CancellationToken ct)
        {
            if (decision.Kind == CodingTurnDecisionKind.ArmSession)
            {
                lock (_stateLock) _codingSession.Arm(questionEndTime);
                OnStatusUpdated("Coding session ready — listening for the task…");
                OnHideLoading();
                return;
            }

            int sequence;
            lock (_stateLock) sequence = _nextTurnSequence++;

            if (decision.Kind == CodingTurnDecisionKind.NeedsScreenContext)
            {
                OnQuestionReceived(spokenText, "coding", InterviewMessage.MessageType.Question, source, turnId, sequence);
                OnStreamingStarted(InterviewMessage.MessageType.Answer, "coding", 0, turnId, sequence);
                const string hint = "- Capture the task on screen with Ctrl+Alt+S, then press Ctrl+Alt+Enter to analyze it.";
                OnAnswerChunkReceived(hint, turnId);
                OnFinishedAnswer(hint, 0, turnId);
                OnHideLoading();
                return;
            }

            string task;
            string? changeRequest = null;
            string? currentCode;
            bool isRefinement = false;
            Guid cardTurnId = turnId;

            lock (_stateLock)
            {
                currentCode = _codingSession.CurrentCode;
                switch (decision.Kind)
                {
                    case CodingTurnDecisionKind.NewTask:
                        task = decision.Text;
                        currentCode = null;
                        _codingSession.Begin(task, turnId, questionEndTime);
                        break;
                    case CodingTurnDecisionKind.RefineTask:
                        task = decision.Text;
                        isRefinement = true;
                        cardTurnId = _codingSession.CardTurnId ?? turnId;
                        _codingSession.Refine(task, questionEndTime);
                        break;
                    case CodingTurnDecisionKind.ChangeCode:
                        task = _codingSession.Task;
                        changeRequest = decision.Text;
                        _codingSession.ApplyChange(changeRequest, turnId, questionEndTime);
                        break;
                    default:
                        task = spokenText;
                        break;
                }
                _lastCodingRequest = new CodingRequest(task, spokenText, changeRequest, cardTurnId, sequence);
            }

            await StreamCodingRequestAsync(task, spokenText, changeRequest, currentCode, isRefinement, cardTurnId, sequence, source, questionEndTime, ct)
                .ConfigureAwait(false);
        }

        public async Task RequestCodeChangeAsync(string instruction, CancellationToken ct = default)
        {
            if (_llmClient == null || string.IsNullOrWhiteSpace(instruction)) return;
            var now = _now();
            var turnId = Guid.NewGuid();
            int seq;
            string task;
            string currentCode;
            lock (_stateLock)
            {
                if (string.IsNullOrWhiteSpace(_codingSession.CurrentCode)) return;
                seq = _nextTurnSequence++;
                task = _codingSession.Task;
                currentCode = _codingSession.CurrentCode;
                _codingSession.ApplyChange(instruction, turnId, now);
                _lastCodingRequest = new CodingRequest(task, instruction, instruction, turnId, seq);
            }
            await StreamCodingRequestAsync(task, instruction, instruction, currentCode, false, turnId, seq, AudioSource.SystemAudio, now, ct)
                .ConfigureAwait(false);
        }

        public async Task RetryLastCodingRequestAsync(CancellationToken ct = default)
        {
            CodingRequest? req;
            string? currentCode;
            lock (_stateLock)
            {
                req = _lastCodingRequest;
                if (req == null) return;
                _codingSession.Touch(_now());
                currentCode = req.Change != null ? _codingSession.CurrentCode : null;
            }
            await StreamCodingRequestAsync(req.Task, req.Text, req.Change, currentCode, true, req.CardTurnId, req.TurnSequence, AudioSource.SystemAudio, _now(), ct)
                .ConfigureAwait(false);
        }

        public async Task RetryAnswerAsync(Guid turnId, string question, string topic, CancellationToken ct = default)
        {
            if (_llmClient == null) return;
            var start = _now();
            var context = _delegate?.ConversationContext;
            var multiTurn = context?.BuildMultiTurnMessages(question, _delegate?.PinnedSolution) ?? new();
            var apiMsgs = context?.MessagesToAPIFormat(multiTurn) ?? new();

            var accum = string.Empty;
            try
            {
                await _llmClient.StreamAnswerAsync(
                    question,
                    apiMsgs,
                    _delegate?.UserBackground ?? string.Empty,
                    chunk =>
                    {
                        accum += chunk;
                        OnAnswerChunkReceived(accum, turnId);
                    },
                    ct).ConfigureAwait(false);

                var display = ConversationalDisplayAnswer(accum);
                OnFinishedAnswer(display, (int)(_now() - start).TotalMilliseconds, turnId);
            }
            catch (Exception ex)
            {
                OnFinishedAnswer($"Error: {ex.Message}", (int)(_now() - start).TotalMilliseconds, turnId);
            }
        }

        private async Task StreamCodingRequestAsync(
            string task,
            string displayRequest,
            string? changeRequest,
            string? currentCode,
            bool isRefinement,
            Guid cardTurnId,
            int sequence,
            AudioSource source,
            DateTime startTime,
            CancellationToken ct)
        {
            if (_llmClient == null) return;

            if (!isRefinement)
            {
                OnQuestionReceived(displayRequest, "coding", InterviewMessage.MessageType.Question, source, cardTurnId, sequence);
                OnStreamingStarted(InterviewMessage.MessageType.Answer, "coding", (int)(_now() - startTime).TotalMilliseconds, cardTurnId, sequence);
            }

            CodingTaskStarted?.Invoke(this, new CodingTaskInfo(cardTurnId, displayRequest, isRefinement, AllowsChanges: true));

            var raw = string.Empty;
            var lang = AppSettings.Shared.LanguageDisplayName;

            try
            {
                await _llmClient.StreamCodingSolutionAsync(
                    task,
                    lang,
                    spoken: true,
                    currentCode: currentCode,
                    changeRequest: changeRequest,
                    onChunk: chunk =>
                    {
                        raw += chunk;
                        var split = CodingInterviewStepsHelper.SplitCodingResponse(raw);
                        var progress = CodingInterviewStepsHelper.ParseStepsStreaming(split.StepsMarkdown);
                        var cardText = CodingInterviewStepsHelper.CodingCardBullets(split, progress.Steps.Count, isComplete: false);
                        if (!string.IsNullOrEmpty(cardText))
                            OnAnswerChunkReceived(cardText, cardTurnId);
                        if (!string.IsNullOrEmpty(split.StepsMarkdown))
                            CodingTaskUpdated?.Invoke(this, split.StepsMarkdown);
                    },
                    ct: ct).ConfigureAwait(false);

                var finalSplit = CodingInterviewStepsHelper.SplitCodingResponse(raw);
                var finalProgress = CodingInterviewStepsHelper.ParseStepsStreaming(finalSplit.StepsMarkdown);
                var isComplete = finalProgress.Steps.Count > 0 && !finalProgress.LastStepIsOpen;

                if (isComplete)
                {
                    lock (_stateLock) _codingSession.StoreCode(finalSplit.StepsMarkdown);
                    CodingTaskUpdated?.Invoke(this, finalSplit.StepsMarkdown);
                    CodingTaskFinished?.Invoke(this, CodingTaskOutcome.Complete());
                }
                else
                {
                    CodingTaskFinished?.Invoke(this, CodingTaskOutcome.Incomplete("The code stopped before finishing."));
                }

                var finalCard = CodingInterviewStepsHelper.CodingCardBullets(finalSplit, finalProgress.Steps.Count, isComplete);
                var totalMs = (int)(_now() - startTime).TotalMilliseconds;
                _delegate?.ConversationContext.AddUtterance(displayRequest, "coding", isQuestion: true, sequence: sequence);
                if (!string.IsNullOrEmpty(finalCard))
                {
                    OnFinishedAnswer(finalCard, totalMs, cardTurnId);
                    _delegate?.ConversationContext.AddUtterance(finalCard, "coding", isQuestion: false);
                }
            }
            catch (Exception ex)
            {
                CodingTaskFinished?.Invoke(this, CodingTaskOutcome.Incomplete(ex.Message));
                OnFinishedAnswer($"Error: {ex.Message}", (int)(_now() - startTime).TotalMilliseconds, cardTurnId);
            }
            finally
            {
                OnHideLoading();
            }
        }

        private void ScheduleSummarization(ConversationContext context, int generation)
        {
            if (_llmClient == null) return;
            string text;
            lock (_stateLock)
            {
                if (_summaryInFlight || !context.NeedsSummarization) return;
                _summaryInFlight = true;
                text = context.GetTextForSummarization();
            }
            if (string.IsNullOrWhiteSpace(text))
            {
                lock (_stateLock) _summaryInFlight = false;
                return;
            }

            _ = Task.Run(async () =>
            {
                try
                {
                    var summary = await _llmClient.SummarizeConversationAsync(text).ConfigureAwait(false);
                    lock (_stateLock)
                    {
                        if (generation == _turnGeneration && !string.IsNullOrWhiteSpace(summary))
                            context.SetSummary(summary);
                    }
                }
                catch (Exception ex)
                {
                    PipelineLog($"Summarization failed: {ex.Message}");
                }
                finally
                {
                    lock (_stateLock) _summaryInFlight = false;
                }
            });
        }

        private void OnApiKeysUpdated() => OnStatusUpdated("API keys updated");
        private void OnInterviewSettingsUpdated() => OnStatusUpdated("Interview settings updated");

        public void Dispose()
        {
            AppNotifications.ApiKeysUpdated -= OnApiKeysUpdated;
            AppNotifications.InterviewSettingsUpdated -= OnInterviewSettingsUpdated;
        }

        protected virtual void OnShowLoading(string message, string colorName, Guid turnId) =>
            ShowLoading?.Invoke(this, new LoadingEventArgs(message, colorName, turnId));
        protected virtual void OnHideLoading() => HideLoading?.Invoke(this, EventArgs.Empty);
        protected virtual void OnQuestionReceived(string text, string topic, InterviewMessage.MessageType messageType, AudioSource source, Guid turnId, int sequence) =>
            QuestionReceived?.Invoke(this, new QuestionReceivedEventArgs(text, topic, messageType, source, turnId, sequence));
        protected virtual void OnStreamingStarted(InterviewMessage.MessageType messageType, string topic, int? latencyMs, Guid turnId, int sequence) =>
            StreamingStarted?.Invoke(this, new StreamingStartedEventArgs(messageType, topic, latencyMs, turnId, sequence));
        protected virtual void OnAnswerChunkReceived(string fullContent, Guid turnId) =>
            AnswerChunkReceived?.Invoke(this, new AnswerChunkEventArgs(fullContent, turnId));
        protected virtual void OnFinishedAnswer(string fullAnswer, int? totalLatencyMs, Guid turnId) =>
            AnswerFinished?.Invoke(this, new AnswerFinishedEventArgs(fullAnswer, totalLatencyMs, turnId));
        protected virtual void OnStatusUpdated(string status) => StatusUpdated?.Invoke(this, status);
    }
}
