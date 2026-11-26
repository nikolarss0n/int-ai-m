using System;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using InterviewMasterApp.Application;
using InterviewMasterApp.Application.UseCases;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Infrastructure;
using InterviewMasterApp.Infrastructure.API;
using InterviewMasterApp.Infrastructure.Speech;
using InterviewMasterApp.Infrastructure.Storage;
using InterviewMasterApp.Presentation.Components;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Orchestrates the live interview lifecycle, serialized audio capture via <see cref="AudioCaptureCoordinator"/>,
    /// thread-safe UI callbacks, Focus UI + Code Panel + Timeline updates, and header notices.
    /// </summary>
    public class VoiceInterviewController : IVoiceInterviewProcessorDelegate, IDisposable
    {
        private readonly Window _mainWindow;
        private readonly RichTextBox _notesTextBox;
        private readonly TextBlock _voiceStatusLabel;
        private readonly TimelineManager _timelineManager;
        private readonly RecordingIndicator _recordingIndicator;
        private readonly ConversationContext _conversationContext;
        private readonly VoiceInterviewProcessor _processor;
        private readonly InterviewExport _interviewExport;
        private readonly InterviewFocusController? _focusController;
        private readonly CodePanelView? _codePanel;
        private readonly AIActivityCapsuleView? _activityCapsule;
        private readonly FocusNoticeController? _noticeController;
        private readonly Func<string?> _getPinnedSolution;
        private readonly Action? _showSettingsCallback;
        private readonly Action? _onCodePanelRequested;

        private readonly AudioCaptureCoordinator _audioCoordinator;
        private GroqInterviewClient? _groqClient;
        private IAnthropicClient? _llmClient;

        private string? _groqApiKey;
        private string? _anthropicApiKey;
        private bool _isInterviewActive;

        public bool IsInterviewActive => _isInterviewActive;
        public bool IsMuted => _audioCoordinator.IsMuted;
        public CaptureDevice SelectedDevice => _audioCoordinator.SelectedDevice;

        // Thread-safe access to WPF RichTextBox from background processor threads!
        public string UserBackground
        {
            get
            {
                if (_notesTextBox.Dispatcher.CheckAccess())
                    return GetPlainText(_notesTextBox);
                return _notesTextBox.Dispatcher.Invoke(() => GetPlainText(_notesTextBox));
            }
        }

        public string ResumeText => ResumeStore.Shared.ExtractedText;
        public string? PinnedSolution => _getPinnedSolution();
        public ConversationContext ConversationContext => _conversationContext;

        public VoiceInterviewController(
            Window mainWindow,
            RichTextBox notesTextBox,
            TextBlock voiceStatusLabel,
            TimelineManager timelineManager,
            RecordingIndicator recordingIndicator,
            ConversationContext conversationContext,
            VoiceInterviewProcessor voiceInterviewProcessor,
            InterviewExport interviewExport,
            Func<string?>? getPinnedSolution = null,
            InterviewFocusController? focusController = null,
            CodePanelView? codePanel = null,
            AIActivityCapsuleView? activityCapsule = null,
            FocusNoticeController? noticeController = null,
            Action? showSettingsCallback = null,
            Action? onCodePanelRequested = null)
        {
            _mainWindow = mainWindow ?? throw new ArgumentNullException(nameof(mainWindow));
            _notesTextBox = notesTextBox ?? throw new ArgumentNullException(nameof(notesTextBox));
            _voiceStatusLabel = voiceStatusLabel ?? throw new ArgumentNullException(nameof(voiceStatusLabel));
            _timelineManager = timelineManager ?? throw new ArgumentNullException(nameof(timelineManager));
            _recordingIndicator = recordingIndicator ?? throw new ArgumentNullException(nameof(recordingIndicator));
            _conversationContext = conversationContext ?? throw new ArgumentNullException(nameof(conversationContext));
            _processor = voiceInterviewProcessor ?? throw new ArgumentNullException(nameof(voiceInterviewProcessor));
            _interviewExport = interviewExport ?? throw new ArgumentNullException(nameof(interviewExport));
            _getPinnedSolution = getPinnedSolution ?? (() => null);
            _focusController = focusController;
            _codePanel = codePanel;
            _activityCapsule = activityCapsule;
            _noticeController = noticeController;
            _showSettingsCallback = showSettingsCallback;
            _onCodePanelRequested = onCodePanelRequested;

            _audioCoordinator = new AudioCaptureCoordinator(AudioCaptureFactory.Create, AppSettings.Shared.CaptureDevice);
            _audioCoordinator.OnLevel += (db, speaking) =>
            {
                _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
                {
                    _activityCapsule?.SetLevel(db, speaking);
                    _timelineManager.UpdateStatusIcon(listening: _isInterviewActive, speaking: speaking);
                }));
            };
            _audioCoordinator.OnSpeechSegment += (wav, source) =>
            {
                _ = _processor.ProcessAudioSegmentAsync(wav, source);
            };
            _audioCoordinator.OnStatus += status =>
            {
                StealthLogger.Shared.Log($"Audio: {status}");
            };
            _audioCoordinator.OnPresentationChanged += pres =>
            {
                _mainWindow.Dispatcher.BeginInvoke(new Action(() => UpdateCapsuleFromPresentation(pres)));
            };

            _processor.ShowLoading += ProcessorShowLoading;
            _processor.HideLoading += ProcessorHideLoading;
            _processor.QuestionReceived += ProcessorDidReceiveQuestion;
            _processor.StreamingStarted += ProcessorDidStartStreaming;
            _processor.AnswerChunkReceived += ProcessorDidReceiveAnswerChunk;
            _processor.AnswerFinished += ProcessorDidFinishAnswer;
            _processor.StatusUpdated += ProcessorDidUpdateStatus;
            _processor.BriefingUpdated += ProcessorDidUpdateBriefing;
            _processor.CodingTaskStarted += ProcessorDidStartCodingTask;
            _processor.CodingTaskUpdated += ProcessorDidUpdateCodingTask;
            _processor.CodingTaskFinished += ProcessorDidFinishCodingTask;
        }

        public void SetApiKeys(string? groqApiKey, string? anthropicApiKey)
        {
            _groqApiKey = groqApiKey;
            _anthropicApiKey = anthropicApiKey;
        }

        public void ToggleInterview()
        {
            if (_isInterviewActive) _ = StopInterviewAsync();
            else _ = StartInterviewAsync();
        }

        public void ToggleMute()
        {
            _audioCoordinator.ToggleMute();
            UpdateCapsuleFromPresentation(_audioCoordinator.CurrentPresentation);
        }

        public async Task SwitchAudioSourceAsync(CaptureDevice device)
        {
            _processor.ResetCaptureBuffers();
            try
            {
                await _audioCoordinator.SwitchDeviceAsync(device);
                _noticeController?.Post(FeedbackNotice.Confirmation("audio", $"Audio source: {device.GetDisplayName()}"));
            }
            catch (Exception ex)
            {
                _noticeController?.Post(FeedbackNotice.Error("audio", $"Could not switch audio: {ex.Message}"));
            }
        }

        public async Task RetryAnswerAsync(FocusTurnItem turn)
        {
            if (turn.HasCode)
                await _processor.RetryLastCodingRequestAsync();
            else
                await _processor.RetryAnswerAsync(turn.TurnId, turn.Question, turn.Topic);
        }

        public Task RequestCodeChangeAsync(string instruction) => _processor.RequestCodeChangeAsync(instruction);
        public Task RetryLastCodingRequestAsync() => _processor.RetryLastCodingRequestAsync();

        public async Task StartInterviewAsync()
        {
            DebugLogger.Shared.Clear();
            var groqKey = _groqApiKey ?? ApiKeyManager.Shared.GetKey(ApiKeyType.Groq);
            if (string.IsNullOrWhiteSpace(groqKey))
            {
                _noticeController?.Post(
                    FeedbackNotice.Error("keys", "Groq API key required for speech transcription", actionTitle: FeedbackCopy.OpenSettings),
                    _showSettingsCallback);
                return;
            }

            var llmClient = AnthropicStreamingClient.CreateFromSettings();
            if (llmClient == null && !string.IsNullOrWhiteSpace(_anthropicApiKey))
                llmClient = new AnthropicStreamingClient(_anthropicApiKey!);

            if (llmClient == null)
            {
                _noticeController?.Post(
                    FeedbackNotice.Error("keys", "Add an Anthropic, xAI Grok, or OpenAI API key in Settings", actionTitle: FeedbackCopy.OpenSettings),
                    _showSettingsCallback);
                return;
            }

            try
            {
                _groqClient = new GroqInterviewClient(groqKey);
                _llmClient = llmClient;
                _processor.Configure(_groqClient, _llmClient, this, MemoryStore.Shared);

                _interviewExport.InterviewStartedAt = DateTime.Now;
                _isInterviewActive = true;
                _activityCapsule?.SetMode(ActivityCapsuleMode.Connecting);

                await _audioCoordinator.StartAsync(AppSettings.Shared.CaptureDevice);

                _recordingIndicator.ShowRecordingIndicator();
                _timelineManager.AddVoiceMessage(InterviewMessage.MessageType.Status, "Interview started — listening for questions…", null);
                _voiceStatusLabel.Text = $"Listening ({AppSettings.Shared.CaptureDevice.GetDisplayName()}) · {AppSettings.Shared.AnswerModel.GetDisplayName()}";
                UpdateCapsuleFromPresentation(_audioCoordinator.CurrentPresentation);
            }
            catch (Exception ex)
            {
                _isInterviewActive = false;
                _activityCapsule?.SetMode(ActivityCapsuleMode.NoAudio);
                _noticeController?.Post(FeedbackNotice.Error("audio", $"Could not start audio: {ex.Message}"));
            }
        }

        public async Task StopInterviewAsync()
        {
            _isInterviewActive = false;
            await _audioCoordinator.StopAsync();

            _interviewExport.AutoSaveSession(_llmClient);
            _conversationContext.Clear();
            _processor.Reset();

            _timelineManager.HideLoading();
            _recordingIndicator.HideRecordingIndicator();
            _activityCapsule?.SetMode(ActivityCapsuleMode.Hidden);
            _voiceStatusLabel.Text = "Ready";
            _timelineManager.AddVoiceMessage(InterviewMessage.MessageType.Status, "Interview stopped", null);
        }

        // MARK: - Processor Callbacks

        private void ProcessorShowLoading(object? sender, LoadingEventArgs args)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                if (args.Message.Contains("Transcribing", StringComparison.OrdinalIgnoreCase))
                    _activityCapsule?.SetMode(ActivityCapsuleMode.Transcribing);
                _timelineManager.ShowLoading(args.Message);
            }));
        }

        private void ProcessorHideLoading(object? sender, EventArgs e)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _timelineManager.HideLoading();
                if (_isInterviewActive)
                    UpdateCapsuleFromPresentation(_audioCoordinator.CurrentPresentation);
            }));
        }

        private void ProcessorDidReceiveQuestion(object? sender, QuestionReceivedEventArgs args)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _noticeController?.Resolve("pipeline");
                _focusController?.AddQuestion(args.TurnId, args.Sequence, args.Text, args.Topic);
                _timelineManager.AddVoiceMessage(args.MessageType, args.Text, args.Topic, args.Source);
            }));
        }

        private void ProcessorDidStartStreaming(object? sender, StreamingStartedEventArgs args)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _timelineManager.UpdateStreamingAnswer(string.Empty, args.Topic);
            }));
        }

        private void ProcessorDidReceiveAnswerChunk(object? sender, AnswerChunkEventArgs args)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _focusController?.UpdateAnswerChunk(args.TurnId, args.FullContent);
                _timelineManager.UpdateStreamingAnswer(args.FullContent, _conversationContext.LastTopic);
            }));
        }

        private void ProcessorDidFinishAnswer(object? sender, AnswerFinishedEventArgs args)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _focusController?.FinishAnswer(args.TurnId, args.FullAnswer, args.TotalLatencyMs);
                _timelineManager.FinalizeStreamingAnswer();
                _timelineManager.AddVoiceMessage(
                    InterviewMessage.MessageType.Answer,
                    args.FullAnswer,
                    _conversationContext.LastTopic);
            }));
        }

        private void ProcessorDidUpdateStatus(object? sender, string message)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _voiceStatusLabel.Text = message;
                var notice = FeedbackCopy.NoticeForStatus(message);
                if (notice != null)
                {
                    Action? action = notice.ActionTitle == FeedbackCopy.OpenSettings ? _showSettingsCallback : null;
                    _noticeController?.Post(notice, action);
                }
            }));
        }

        private void ProcessorDidUpdateBriefing(object? sender, InterviewBriefing briefing)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _focusController?.UpdateBriefing(briefing);
            }));
        }

        private void ProcessorDidStartCodingTask(object? sender, CodingTaskInfo info)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _focusController?.MarkTurnHasCode(info.TurnId);
                _codePanel?.StartTask(info);
                _onCodePanelRequested?.Invoke();
            }));
        }

        private void ProcessorDidUpdateCodingTask(object? sender, string stepsMarkdown)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _codePanel?.UpdateCode(stepsMarkdown);
            }));
        }

        private void ProcessorDidFinishCodingTask(object? sender, CodingTaskOutcome outcome)
        {
            _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
            {
                _codePanel?.FinishTask(outcome);
            }));
        }

        private void UpdateCapsuleFromPresentation(CapturePresentation pres)
        {
            if (_activityCapsule == null) return;
            var mode = pres.Kind switch
            {
                CapturePresentationKind.Idle => ActivityCapsuleMode.Hidden,
                CapturePresentationKind.Switching => ActivityCapsuleMode.Connecting,
                CapturePresentationKind.Muted => ActivityCapsuleMode.Muted,
                CapturePresentationKind.Unavailable => ActivityCapsuleMode.NoAudio,
                _ => ActivityCapsuleMode.Listening
            };
            _activityCapsule.SetMode(mode);
        }

        private static string GetPlainText(RichTextBox richTextBox) =>
            new TextRange(richTextBox.Document.ContentStart, richTextBox.Document.ContentEnd).Text ?? string.Empty;

        public void Dispose()
        {
            _processor.ShowLoading -= ProcessorShowLoading;
            _processor.HideLoading -= ProcessorHideLoading;
            _processor.QuestionReceived -= ProcessorDidReceiveQuestion;
            _processor.StreamingStarted -= ProcessorDidStartStreaming;
            _processor.AnswerChunkReceived -= ProcessorDidReceiveAnswerChunk;
            _processor.AnswerFinished -= ProcessorDidFinishAnswer;
            _processor.StatusUpdated -= ProcessorDidUpdateStatus;
            _processor.BriefingUpdated -= ProcessorDidUpdateBriefing;
            _processor.CodingTaskStarted -= ProcessorDidStartCodingTask;
            _processor.CodingTaskUpdated -= ProcessorDidUpdateCodingTask;
            _processor.CodingTaskFinished -= ProcessorDidFinishCodingTask;
            _audioCoordinator.Dispose();
        }
    }
}
