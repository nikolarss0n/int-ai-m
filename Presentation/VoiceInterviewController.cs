using System;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using InterviewMasterApp.Application;
using InterviewMasterApp.Application.UseCases;
using InterviewMasterApp.Domain.Entities;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Infrastructure;
using InterviewMasterApp.Infrastructure.API;
using InterviewMasterApp.Infrastructure.Audio;
using InterviewMasterApp.Infrastructure.Speech;
using InterviewMasterApp.Presentation.Timeline;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Voice interview controller - handles voice interview lifecycle and callbacks.
    /// </summary>
    public class VoiceInterviewController : IVoiceInterviewProcessorDelegate
    {
        private readonly Window _mainWindow;
        private readonly RichTextBox _notesTextBox;
        private readonly TextBlock _voiceStatusLabel;
        private readonly TimelineManager _timelineManager;
        private readonly RecordingIndicator _recordingIndicator;
        private readonly ConversationContext _conversationContext;
        private readonly VoiceInterviewProcessor _voiceInterviewProcessor;
        private readonly InterviewExport _interviewExport;
        private readonly Action? _showSettingsCallback;

        private SileroVADRecorder? _vadRecorder;
        private WasapiLoopbackCaptureService? _systemAudioCapture;
        private WindowsAudioCapture? _microphoneCapture;
        private GroqInterviewClient? _groqClient;
        private AnthropicStreamingClient? _anthropicClient;

        private string? _groqApiKey;
        private string? _anthropicApiKey;
        private bool _isInterviewActive;
        // IVoiceInterviewProcessorDelegate implementation
        public string UserBackground => GetPlainText(_notesTextBox);
        public string PinnedSolution => string.Empty;
        public ConversationContext ConversationContext => _conversationContext;

        public bool IsInterviewActive => _isInterviewActive;

        public VoiceInterviewController(
            Window mainWindow,
            RichTextBox notesTextBox,
            TextBlock voiceStatusLabel,
            TimelineManager timelineManager,
            RecordingIndicator recordingIndicator,
            ConversationContext conversationContext,
            VoiceInterviewProcessor voiceInterviewProcessor,
            InterviewExport interviewExport,
            Action? showSettingsCallback = null)
        {
            _mainWindow = mainWindow ?? throw new ArgumentNullException(nameof(mainWindow));
            _notesTextBox = notesTextBox ?? throw new ArgumentNullException(nameof(notesTextBox));
            _voiceStatusLabel = voiceStatusLabel ?? throw new ArgumentNullException(nameof(voiceStatusLabel));
            _timelineManager = timelineManager ?? throw new ArgumentNullException(nameof(timelineManager));
            _recordingIndicator = recordingIndicator ?? throw new ArgumentNullException(nameof(recordingIndicator));
            _conversationContext = conversationContext ?? throw new ArgumentNullException(nameof(conversationContext));
            _voiceInterviewProcessor = voiceInterviewProcessor ?? throw new ArgumentNullException(nameof(voiceInterviewProcessor));
            _interviewExport = interviewExport ?? throw new ArgumentNullException(nameof(interviewExport));
            _showSettingsCallback = showSettingsCallback;

            // Subscribe to processor events
            _voiceInterviewProcessor.ShowLoading += ProcessorShowLoading;
            _voiceInterviewProcessor.HideLoading += ProcessorHideLoading;
            _voiceInterviewProcessor.QuestionReceived += ProcessorDidReceiveQuestion;
            _voiceInterviewProcessor.StreamingStarted += ProcessorDidStartStreaming;
            _voiceInterviewProcessor.AnswerChunkReceived += ProcessorDidReceiveAnswerChunk;
            _voiceInterviewProcessor.AnswerFinished += ProcessorDidFinishAnswer;
            _voiceInterviewProcessor.StatusUpdated += ProcessorDidUpdateStatus;
        }

        // MARK: - VoiceInterviewProcessorDelegate Event Handlers

        private void ProcessorShowLoading(object? sender, LoadingEventArgs args)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                // Convert color name to WPF color
                var color = args.ColorName switch
                {
                    "CornflowerBlue" => Colors.CornflowerBlue,
                    "MediumPurple" => Colors.MediumPurple,
                    _ => Colors.White
                };
                _timelineManager.ShowLoading(args.Message, color);
            }));
        }

        private void ProcessorHideLoading(object? sender, EventArgs e)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _timelineManager.HideLoading();
            }));
        }

        private void ProcessorDidReceiveQuestion(object? sender, QuestionReceivedEventArgs args)
        {
            StealthLogger.Shared.Log($"processorDidReceiveQuestion: '{args.Text.Substring(0, Math.Min(50, args.Text.Length))}...' topic={args.Topic}");

            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _timelineManager.AddVoiceMessage(args.MessageType, args.Text, args.Topic, args.Source);
            }));
        }

        private void ProcessorDidStartStreaming(object? sender, StreamingStartedEventArgs args)
        {
            StealthLogger.Shared.Log($"processorDidStartStreaming: type={args.MessageType} topic={args.Topic} latency={args.LatencyMs ?? -1}ms");

            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                // Start showing streaming answer placeholder
                _timelineManager.UpdateStreamingAnswer("", args.Topic);
            }));
        }

        private void ProcessorDidReceiveAnswerChunk(object? sender, string fullContent)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                // Update streaming message in timeline with accumulated content
                _timelineManager.UpdateStreamingAnswer(fullContent, _conversationContext.LastTopic);
            }));
        }

        private void ProcessorDidFinishAnswer(object? sender, string fullAnswer)
        {
            StealthLogger.Shared.Log($"processorDidFinishAnswer: {fullAnswer.Length} chars");

            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                // Remove streaming placeholder and add the final answer
                _timelineManager.FinalizeStreamingAnswer();
                _timelineManager.AddVoiceMessage(
                    InterviewMessage.MessageType.Answer,
                    fullAnswer,
                    _conversationContext.LastTopic);
            }));
        }

        private void ProcessorDidUpdateStatus(object? sender, string message)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _voiceStatusLabel.Text = message;
            }));
        }

        // MARK: - Voice Interview Methods

        public void SetApiKeys(string? groqApiKey, string? anthropicApiKey)
        {
            _groqApiKey = groqApiKey;
            _anthropicApiKey = anthropicApiKey;
        }

        public void ToggleInterview()
        {
            if (_isInterviewActive)
                StopInterview();
            else
                StartInterview();
        }

        public void StartInterview()
        {
            DebugLogger.Shared.Clear();
            DebugLogger.Shared.Log("=== StartInterview called ===");
            DebugLogger.Shared.Log($"Groq API key: {(string.IsNullOrWhiteSpace(_groqApiKey) ? "MISSING" : "present (" + _groqApiKey!.Length + " chars)")}");
            DebugLogger.Shared.Log($"Anthropic API key: {(string.IsNullOrWhiteSpace(_anthropicApiKey) ? "MISSING" : "present (" + _anthropicApiKey!.Length + " chars)")}");

            if (string.IsNullOrWhiteSpace(_groqApiKey))
            {
                DebugLogger.Shared.Log(DebugLogger.LogCategory.Error, "Groq API key missing, prompting user");
                _timelineManager.PromptForGroqApiKey(_mainWindow);
                return;
            }

            if (string.IsNullOrWhiteSpace(_anthropicApiKey))
            {
                DebugLogger.Shared.Log(DebugLogger.LogCategory.Error, "Anthropic API key missing, prompting user");
                MessageBox.Show(
                    _mainWindow,
                    "Please configure your Anthropic API key in Settings (Ctrl+,)",
                    "API Key Required",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
                return;
            }

            try
            {
                DebugLogger.Shared.Log("Creating Groq + Anthropic clients...");
                _groqClient = new GroqInterviewClient(_groqApiKey!);
                _anthropicClient = new AnthropicStreamingClient(_anthropicApiKey!);

                // Configure processor with clients and this as delegate
                _voiceInterviewProcessor.Configure(_groqClient, _anthropicClient, this);
                DebugLogger.Shared.Log("Processor configured with clients and delegate");

                // Initialize VAD engine and WASAPI loopback capture for system audio
                DebugLogger.Shared.Log("Creating SileroVADRecorder for system audio...");
                var vadEngine = new SileroVADRecorder("SYS");
                _systemAudioCapture = new WasapiLoopbackCaptureService(vadEngine);
                DebugLogger.Shared.Log("WasapiLoopbackCaptureService created");

                StealthLogger.Shared.Log("Setting up system audio callbacks...");

                _systemAudioCapture.OnStatusChange = (status) =>
                {
                    StealthLogger.Shared.Log($"System status: {status}");
                };

                _systemAudioCapture.OnLevelUpdate = (db, isSpeaking) =>
                {
                    _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
                    {
                        _timelineManager.UpdateStatusIcon(listening: true, speaking: isSpeaking);
                    }));
                };

                _systemAudioCapture.OnSpeechSegment = (audioData) =>
                {
                    StealthLogger.Shared.Log($"System audio segment received: {audioData.Length} bytes");
                    _ = _voiceInterviewProcessor.ProcessAudioSegmentAsync(audioData, AudioSource.SystemAudio);
                };

                // Initialize microphone capture with its own VAD engine
                DebugLogger.Shared.Log("Creating SileroVADRecorder for microphone...");
                var micVadEngine = new SileroVADRecorder("MIC");
                _microphoneCapture = new WindowsAudioCapture(micVadEngine);
                DebugLogger.Shared.Log("WindowsAudioCapture (mic) created");

                _microphoneCapture.StatusChanged += (status) =>
                {
                    StealthLogger.Shared.Log($"Mic status: {status}");
                };

                _microphoneCapture.SpeechSegmentReady += (audioData) =>
                {
                    StealthLogger.Shared.Log($"Mic audio segment received: {audioData.Length} bytes");
                    _ = _voiceInterviewProcessor.ProcessAudioSegmentAsync(audioData, AudioSource.Microphone);
                };

                // Start both system audio and microphone capture in background
                Task.Run(async () =>
                {
                    try
                    {
                        StealthLogger.Shared.Log("Starting system audio capture...");
                        await _systemAudioCapture.StartCapturingAsync();
                        StealthLogger.Shared.Log("System audio capture started successfully");
                    }
                    catch (Exception ex)
                    {
                        StealthLogger.Shared.Log($"System audio capture failed: {ex.Message}");
                        await _mainWindow.Dispatcher.InvokeAsync(() =>
                        {
                            MessageBox.Show(
                                _mainWindow,
                                $"System audio capture failed.\n\nError: {ex.Message}",
                                "Audio Capture Error",
                                MessageBoxButton.OK,
                                MessageBoxImage.Warning);
                        });
                    }
                });

                Task.Run(async () =>
                {
                    try
                    {
                        StealthLogger.Shared.Log("Starting microphone capture...");
                        await _microphoneCapture.StartAsync();
                        StealthLogger.Shared.Log("Microphone capture started successfully");
                    }
                    catch (Exception ex)
                    {
                        StealthLogger.Shared.Log($"Microphone capture failed: {ex.Message}");
                        await _mainWindow.Dispatcher.InvokeAsync(() =>
                        {
                            MessageBox.Show(
                                _mainWindow,
                                $"Microphone capture failed.\n\nError: {ex.Message}",
                                "Microphone Error",
                                MessageBoxButton.OK,
                                MessageBoxImage.Warning);
                        });
                    }
                });

                _isInterviewActive = true;

                _timelineManager.UpdateNestButtonState(recording: true);
                _recordingIndicator.ShowRecordingIndicator();

                _timelineManager.AddVoiceMessage(
                    InterviewMessage.MessageType.Status,
                    "Interview started - listening for questions...",
                    null);

                StealthLogger.Shared.Log("Interview started");
            }
            catch (Exception ex)
            {
                DebugLogger.Shared.Log(DebugLogger.LogCategory.Error, $"StartInterview FAILED: {ex.Message}\n{ex.StackTrace}");
                MessageBox.Show(
                    _mainWindow,
                    $"Could not start audio recording: {ex.Message}",
                    "Audio Error",
                    MessageBoxButton.OK,
                    MessageBoxImage.Error);
            }
        }

        public void StopInterview()
        {
            _vadRecorder?.Dispose();
            _vadRecorder = null;

            // Stop microphone capture
            if (_microphoneCapture != null)
            {
                _ = Task.Run(async () =>
                {
                    await _microphoneCapture.StopAsync();
                    _microphoneCapture.Dispose();
                    await _mainWindow.Dispatcher.InvokeAsync(() =>
                    {
                        _microphoneCapture = null;
                    });
                });
            }

            // Stop system audio capture
            if (_systemAudioCapture != null)
            {
                _ = Task.Run(async () =>
                {
                    await _systemAudioCapture.StopCapturingAsync();
                    _systemAudioCapture.Dispose();
                    await _mainWindow.Dispatcher.InvokeAsync(() =>
                    {
                        _systemAudioCapture = null;
                    });
                });
            }

            _isInterviewActive = false;

            _conversationContext.Clear();
            _voiceInterviewProcessor.Reset();

            _timelineManager.HideLoading();
            _recordingIndicator.HideRecordingIndicator();
            _timelineManager.UpdateNestButtonState(recording: false);

            _voiceStatusLabel.Text = "";

            _timelineManager.AddVoiceMessage(
                InterviewMessage.MessageType.Status,
                "Interview stopped",
                null);

            _interviewExport.AutoSaveSession();

            StealthLogger.Shared.Log("Interview stopped");
        }

        // MARK: - Settings Dropdowns

        public void HandleRoleChanged(InterviewRole role)
        {
            AppSettings.Shared.Role = role;
            StealthLogger.Shared.Log($"Role changed to: {role.GetDisplayName()}");
        }

        public void HandleProgrammingLanguageChanged(ProgrammingLanguage language)
        {
            AppSettings.Shared.ProgrammingLanguage = language;
            StealthLogger.Shared.Log($"Programming language changed to: {language.GetDisplayName()}");
        }

        public void HandleSpeakingLanguageChanged(SpeakingLanguage language)
        {
            AppSettings.Shared.SpeakingLanguage = language;
            StealthLogger.Shared.Log($"Speaking language changed to: {language.GetDisplayName()}");
        }

        // MARK: - Helper Methods

        private string GetPlainText(RichTextBox richTextBox)
        {
            var textRange = new System.Windows.Documents.TextRange(
                richTextBox.Document.ContentStart,
                richTextBox.Document.ContentEnd);
            return textRange.Text ?? string.Empty;
        }

        public void Dispose()
        {
            _voiceInterviewProcessor.ShowLoading -= ProcessorShowLoading;
            _voiceInterviewProcessor.HideLoading -= ProcessorHideLoading;
            _voiceInterviewProcessor.QuestionReceived -= ProcessorDidReceiveQuestion;
            _voiceInterviewProcessor.StreamingStarted -= ProcessorDidStartStreaming;
            _voiceInterviewProcessor.AnswerChunkReceived -= ProcessorDidReceiveAnswerChunk;
            _voiceInterviewProcessor.AnswerFinished -= ProcessorDidFinishAnswer;
            _voiceInterviewProcessor.StatusUpdated -= ProcessorDidUpdateStatus;

            _vadRecorder?.Dispose();
            _microphoneCapture?.Dispose();
            _microphoneCapture = null;
            _systemAudioCapture?.Dispose();
            _systemAudioCapture = null;

            StealthLogger.Shared.Log("VoiceInterviewController disposed");
        }
    }
}
