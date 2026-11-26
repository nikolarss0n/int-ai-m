using System;
using System.Collections.Generic;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using InterviewMasterApp;
using InterviewMasterApp.Application.UseCases;
using InterviewMasterApp.Domain.Entities;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Infrastructure.Capture;
using InterviewMasterApp.Infrastructure.Storage;
using InterviewMasterApp.Presentation;
using InterviewMasterApp.Presentation.Components;
using InterviewMasterApp.Presentation.Practice;
using InterviewMasterApp.Presentation.Settings;
using InterviewMasterApp.Presentation.Styling;
using InterviewMasterApp.Presentation.Timeline;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation.Windows
{
    public partial class MainWindow : Window, IFloatingSolutionDataSource
    {
        private readonly IScreenCaptureService _screenCaptureService;
        private readonly List<Screenshot> _screenshots = new();
        private readonly List<InterviewMessage> _voiceMessages = new();
        private readonly ConversationContext _conversationContext = new();

        private VoiceInterviewController? _voiceInterviewController;
        private InterviewFocusController? _focusController;
        private CodePanelView? _codePanel;
        private PracticeTabController? _practiceController;
        private FocusNoticeController? _noticeController;
        private AIActivityCapsuleView? _activityCapsule;
        private TimelineManager? _timelineManager;
        private ScreenshotManager? _screenshotManager;
        private RecordingIndicator? _recordingIndicator;
        private SearchController? _searchController;
        private FormattingToolbar? _formattingToolbar;
        private NotesEditor? _notesEditor;
        private MonitoringServices? _monitoringServices;
        private GhostMode? _ghostMode;
        private HotkeyManager? _hotkeyManager;
        private MenuBarSetup? _menuBarSetup;
        private TemplateSelector? _templateSelector;
        private InterviewExport? _interviewExport;
        private FloatingSolutionWindowController? _floatingSolutionController;
        private MessageViewFactory? _messageViewFactory;

        private MainTab _currentTab = MainTab.Voice;
        private bool _updatingSourceCombo;

        private enum MainTab
        {
            Notes,
            Voice,
            Coding,
            Practice
        }

        public string? CurrentPinnedSolution => _screenshotManager?.CurrentPinnedSolution;
        public List<InterviewMessage> VoiceMessages => _voiceMessages;
        public MessageViewFactory MessageViewFactory => _messageViewFactory!;

        public MainWindow()
        {
            InitializeComponent();
            _screenCaptureService = new ScreenCaptureService();

            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            LoadHeaderIcon();

            // Enable screen-capture exclusion by default on launch (parity with macOS sharingType = .none)
            SourceInitialized += (_, _) => StealthWindowHelper.SetExcludeFromCapture(this, exclude: true);

            MinimizeButton.Click += (_, _) => WindowState = WindowState.Minimized;
            CloseButton.Click += (_, _) => Close();
            TitleBar.MouseLeftButtonDown += (_, e) =>
            {
                if (IsClickInsideButton(e.OriginalSource as DependencyObject)) return;
                if (e.ClickCount == 2)
                {
                    WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;
                }
                else if (e.LeftButton == System.Windows.Input.MouseButtonState.Pressed)
                {
                    try { DragMove(); } catch { }
                }
            };

            InitializeComponents();
            WireCommandBar();
            SetupUI();
            SetupHotkeys();
            SubscribeToAppNotifications();

            _notesEditor?.LoadNotes();
            _monitoringServices?.StartFocusMonitoring();
            _monitoringServices?.StartScreenshotMonitoring();

            StealthLogger.Shared.Log("Application started");
        }

        private static bool IsClickInsideButton(DependencyObject? source)
        {
            while (source != null)
            {
                if (source is System.Windows.Controls.Primitives.ButtonBase) return true;
                source = VisualTreeHelper.GetParent(source);
            }
            return false;
        }

        private void LoadHeaderIcon()
        {
            try
            {
                var pngPath = Path.Combine(AppContext.BaseDirectory, "Resources", "icon_1024.png");
                if (File.Exists(pngPath))
                {
                    var bmp = new BitmapImage();
                    bmp.BeginInit();
                    bmp.DecodePixelWidth = 44;
                    bmp.UriSource = new Uri(pngPath, UriKind.Absolute);
                    bmp.CacheOption = BitmapCacheOption.OnLoad;
                    bmp.EndInit();
                    bmp.Freeze();
                    HeaderAppIcon.Source = bmp;
                }
            }
            catch { }
        }

        private void InitializeComponents()
        {
            var markdownRenderer = new MarkdownRenderer(MarkdownRenderer.Style.Notes);
            _messageViewFactory = new MessageViewFactory(markdownRenderer, 640);
            _floatingSolutionController = new FloatingSolutionWindowController(this);
            _recordingIndicator = new RecordingIndicator(MainPanel);

            // Header inline notices & activity capsule
            _noticeController = new FocusNoticeController();
            NoticeHost.Content = _noticeController.View;

            _activityCapsule = new AIActivityCapsuleView();
            ActivityCapsuleHost.Content = _activityCapsule;

            // Focus Live-Interview View
            _focusController = new InterviewFocusController();
            _focusController.RetryRequested += turn => _ = _voiceInterviewController?.RetryAnswerAsync(turn);
            _focusController.OpenCodeRequested += turnId =>
            {
                _codePanel?.SelectByTurnId(turnId);
                SwitchToTab(MainTab.Coding);
            };
            _focusController.CopiedNoticeRequested += msg =>
                _noticeController.Post(FeedbackNotice.Confirmation("copy", msg));
            FocusViewHost.Content = _focusController.View;

            // Full-Width Code Panel
            _codePanel = new CodePanelView();
            _codePanel.QuickActionRequested += instr => _ = _voiceInterviewController?.RequestCodeChangeAsync(instr);
            _codePanel.RetryRequested += () => _ = _voiceInterviewController?.RetryLastCodingRequestAsync();
            CodePanelHost.Content = _codePanel;

            // Practice Tab
            _practiceController = new PracticeTabController(PracticePanel);

            // Timeline & Screenshot managers
            _timelineManager = new TimelineManager(
                voiceTimelineContainer: VoiceTimelinePanel,
                voiceTimelineScrollView: VoiceTimelineScrollViewer,
                voiceMessages: _voiceMessages,
                screenshots: _screenshots,
                messageViewFactory: _messageViewFactory,
                typingDotsContainer: TypingDotsPanel,
                floatingController: _floatingSolutionController,
                showSettingsCallback: ShowSettings);

            _screenshotManager = new ScreenshotManager(
                screenCaptureService: _screenCaptureService,
                screenshots: _screenshots,
                voiceMessages: _voiceMessages,
                messageViewFactory: _messageViewFactory,
                screenshotThumbnailsContainer: ScreenshotThumbnailsPanel,
                voiceTimelineContainer: VoiceTimelinePanel,
                voiceTimelineScrollView: VoiceTimelineScrollViewer,
                mainWindow: this,
                analysisTextBox: AnalysisRichTextBox,
                floatingSolutionController: _floatingSolutionController,
                codePanel: _codePanel,
                postNotice: (n, act) => _noticeController.Post(n, act));

            _screenshotManager.ScreenshotCountChanged += count =>
            {
                ScreenshotStripScroll.Visibility = count > 0 ? Visibility.Visible : Visibility.Collapsed;
                AnalyzeButton.Content = count > 0 ? $"Analyze ({count})" : "Analyze";
            };

            // Voice processor & export
            var voiceProcessor = new VoiceInterviewProcessor();
            _interviewExport = new InterviewExport(_voiceMessages, (n, act) => _noticeController.Post(n, act));

            _voiceInterviewController = new VoiceInterviewController(
                mainWindow: this,
                notesTextBox: NotesRichTextBox,
                voiceStatusLabel: VoiceStatusLabel,
                timelineManager: _timelineManager,
                recordingIndicator: _recordingIndicator,
                conversationContext: _conversationContext,
                voiceInterviewProcessor: voiceProcessor,
                interviewExport: _interviewExport,
                getPinnedSolution: () => _screenshotManager?.CurrentPinnedSolution,
                focusController: _focusController,
                codePanel: _codePanel,
                activityCapsule: _activityCapsule,
                noticeController: _noticeController,
                showSettingsCallback: ShowSettings,
                onCodePanelRequested: () => SwitchToTab(MainTab.Coding));

            // Search + formatting toolbar + notes editor (floating overlays strictly above editor Z-index)
            var searchField = new TextBox();
            var searchResults = new TextBlock();
            var searchContainer = SearchController.CreateSearchContainer(searchField, searchResults);
            Panel.SetZIndex(searchContainer, 20);
            NotesPanel.Children.Add(searchContainer);

            _searchController = new SearchController(
                searchContainer, searchField, searchResults, NotesRichTextBox, () => _notesEditor?.RenderMarkdown());

            _formattingToolbar = new FormattingToolbar();
            _formattingToolbar.SetupFormattingToolbar(NotesPanel, NotesRichTextBox, () => _notesEditor?.RenderMarkdown());
            _notesEditor = new NotesEditor(NotesRichTextBox, AnalysisRichTextBox, _formattingToolbar);

            // Monitoring & Ghost Mode
            _monitoringServices = new MonitoringServices(this, _screenshots) { AutoHideEnabled = false };
            _ghostMode = new GhostMode(this, _floatingSolutionController, postNotice: n => _noticeController.Post(n));

            // Templates & MenuBar
            _templateSelector = new TemplateSelector(NotesRichTextBox, () => SwitchToTab(MainTab.Notes), () => _notesEditor?.RenderMarkdown());
            _menuBarSetup = new MenuBarSetup(this)
            {
                ShowSettings = ShowSettings,
                NewNote = CreateNewNote,
                CaptureScreenshot = () => _ = CaptureScreenshot(),
                AnalyzeScreenshots = () => _ = AnalyzeScreenshots(),
                ExportNotes = ExportNotes,
                ToggleSearch = () => _searchController?.ToggleSearch(),
                SwitchToVoiceTab = () => SwitchToTab(MainTab.Voice),
                SwitchToNotesTab = () => SwitchToTab(MainTab.Notes),
                SwitchToCodingTab = () => SwitchToTab(MainTab.Coding),
                SwitchToPracticeTab = () => SwitchToTab(MainTab.Practice),
                ToggleWindowVisibility = () => _ghostMode?.ToggleWindowVisibility(),
                ToggleGhostMode = ToggleGhostMode,
                ToggleMute = ToggleMute,
                HideFloatingSolution = () => _ghostMode?.HideFloatingSolution(),
                ShowTemplateSelector = () => _templateSelector?.ShowTemplateSelector(this)
            };

            var menuBar = _menuBarSetup.CreateMenuBar();
            DockPanel.SetDock(menuBar, Dock.Top);
            MainDockPanel.Children.Insert(1, menuBar);
        }

        private void WireCommandBar()
        {
            TabVoiceButton.Click += (_, _) => SwitchToTab(MainTab.Voice);
            TabCodingButton.Click += (_, _) => SwitchToTab(MainTab.Coding);
            TabNotesButton.Click += (_, _) => SwitchToTab(MainTab.Notes);
            TabPracticeButton.Click += (_, _) => SwitchToTab(MainTab.Practice);

            StartInterviewButton.Click += (_, _) =>
            {
                _voiceInterviewController?.ToggleInterview();
                UpdateInterviewButtonState();
            };

            MuteButton.Click += (_, _) => ToggleMute();
            ScreenshotButton.Click += (_, _) => _ = CaptureScreenshot();
            AnalyzeButton.Click += (_, _) => _ = AnalyzeScreenshots();
            ClearButton.Click += (_, _) => ClearScreenshots();
            GhostModeButton.Click += (_, _) => ToggleGhostMode();
            ExportButton.Click += (_, _) => ExportNotes();
            SettingsButton.Click += (_, _) => ShowSettings();

            // Audio source picker
            _updatingSourceCombo = true;
            foreach (CaptureDevice dev in Enum.GetValues<CaptureDevice>())
                AudioSourceCombo.Items.Add(new ComboBoxItem { Content = dev.GetDisplayName(), Tag = dev });
            SelectAudioSourceCombo(AppSettings.Shared.CaptureDevice);
            _updatingSourceCombo = false;

            AudioSourceCombo.SelectionChanged += (_, _) =>
            {
                if (_updatingSourceCombo) return;
                if (AudioSourceCombo.SelectedItem is ComboBoxItem item && item.Tag is CaptureDevice dev)
                    _ = _voiceInterviewController?.SwitchAudioSourceAsync(dev);
            };

            // Background transparency slider (changes window background alpha without reducing text legibility)
            TransparencySlider.Value = AppSettings.Shared.BackgroundTransparency;
            TransparencySlider.ValueChanged += (_, e) =>
            {
                AppSettings.Shared.BackgroundTransparency = e.NewValue;
                ApplyBackgroundTransparency(e.NewValue);
            };
        }

        private void SetupUI()
        {
            SwitchToTab(MainTab.Voice);
            UpdateProfileHeader();
            ApplyBackgroundTransparency(AppSettings.Shared.BackgroundTransparency);
            UpdateApiKeyStatus();
        }

        private void SetupHotkeys()
        {
            _hotkeyManager = new HotkeyManager(this)
            {
                ToggleInterviewMode = ToggleGhostMode,
                ToggleWindowVisibility = () => _ghostMode?.ToggleWindowVisibility(),
                CaptureScreenshot = () => _ = CaptureScreenshot(),
                AnalyzeScreenshots = () => _ = AnalyzeScreenshots(),
                ClearScreenshots = ClearScreenshots,
                ResetCodingTab = ClearScreenshots,
                SwitchToVoiceTab = () => SwitchToTab(MainTab.Voice),
                SwitchToNotesTab = () => SwitchToTab(MainTab.Notes),
                SwitchToCodingTab = () => SwitchToTab(MainTab.Coding),
                SwitchToPracticeTab = () => SwitchToTab(MainTab.Practice),
                ToggleSearch = () => _searchController?.ToggleSearch(),
                ToggleMute = ToggleMute,
                OpenSettings = ShowSettings,
                NewNote = CreateNewNote,
                ExportInterview = ExportNotes,
                ShowTemplates = () => _templateSelector?.ShowTemplateSelector(this),
                HideFloatingSolution = () => _ghostMode?.HideFloatingSolution(),
                MoveWindowBy = (dx, dy) => _ghostMode?.MoveWindowBy(dx, dy),
                IsWindowVisible = () => IsVisible,
                GetCurrentTab = () => (HotkeyManager.TabType)(int)_currentTab,
                IsSearchVisible = () => _searchController?.IsSearchVisible ?? false
            };
            _hotkeyManager.SetupHotkeys();
        }

        private void SubscribeToAppNotifications()
        {
            AppNotifications.ApiKeysUpdated += HandleApiKeysUpdated;
            AppNotifications.InterviewSettingsUpdated += HandleInterviewSettingsUpdated;
        }

        private void HandleApiKeysUpdated()
        {
            Dispatcher.Invoke(UpdateApiKeyStatus);
        }

        private void HandleInterviewSettingsUpdated()
        {
            Dispatcher.Invoke(() =>
            {
                UpdateProfileHeader();
                TransparencySlider.Value = AppSettings.Shared.BackgroundTransparency;
                ApplyBackgroundTransparency(AppSettings.Shared.BackgroundTransparency);
                _updatingSourceCombo = true;
                SelectAudioSourceCombo(AppSettings.Shared.CaptureDevice);
                _updatingSourceCombo = false;
            });
        }

        private void UpdateProfileHeader()
        {
            var s = AppSettings.Shared;
            ProfileHeaderLabel.Text = $"{s.RoleDisplayName} · {s.LanguageDisplayName} · {s.AnswerModel.GetDisplayName()}";
        }

        private void ApplyBackgroundTransparency(double transparency)
        {
            var alpha = (byte)Math.Clamp((int)Math.Round((1.0 - transparency) * 245), 35, 245);
            OuterWindowBorder.Background = new SolidColorBrush(Color.FromArgb(alpha, 20, 20, 24));
        }

        private void UpdateApiKeyStatus()
        {
            var anthropicKey = ApiKeyManager.Shared.GetKey(ApiKeyType.Anthropic);
            var groqKey = ApiKeyManager.Shared.GetKey(ApiKeyType.Groq);
            var hasLlm = !string.IsNullOrWhiteSpace(anthropicKey) ||
                         ApiKeyManager.Shared.HasKey(ApiKeyType.Xai) ||
                         ApiKeyManager.Shared.HasKey(ApiKeyType.OpenAi);

            // Push keys to BOTH voice controller AND screenshot manager!
            _voiceInterviewController?.SetApiKeys(groqKey, anthropicKey);
            _screenshotManager?.SetApiKey(anthropicKey);

            if (VoiceStatusLabel != null && _voiceInterviewController?.IsInterviewActive != true)
            {
                VoiceStatusLabel.Text = string.IsNullOrWhiteSpace(groqKey)
                    ? "Groq API key needed (Settings)"
                    : hasLlm ? "Ready" : "LLM API key needed (Settings)";
            }
        }

        private void UpdateInterviewButtonState()
        {
            if (_voiceInterviewController?.IsInterviewActive == true)
            {
                StartInterviewButton.Content = "■ Stop";
                StartInterviewButton.Background = new SolidColorBrush(Color.FromRgb(0xC0, 0x39, 0x2B));
            }
            else
            {
                StartInterviewButton.Content = "▶ Start";
                StartInterviewButton.Background = new SolidColorBrush(Color.FromRgb(0x2D, 0x7D, 0x3A));
            }
        }

        private void ToggleMute()
        {
            _voiceInterviewController?.ToggleMute();
            var muted = _voiceInterviewController?.IsMuted == true;
            MuteButton.Content = muted ? "Unmute" : "Mute";
            MuteButton.Background = muted ? DesignTokens.WarningWashBrush : DesignTokens.BgWidgetBrush;
            MuteButton.Foreground = muted ? DesignTokens.WarningTextBrush : DesignTokens.TextBodyBrush;
        }

        private void ToggleGhostMode()
        {
            _ghostMode?.ToggleInterviewMode();
            var on = _ghostMode?.IsInterviewModeActive == true;
            GhostModeButton.Background = on ? DesignTokens.AccentWashBrush : DesignTokens.BgWidgetBrush;
            GhostModeButton.Foreground = on ? DesignTokens.AccentTextBrush : DesignTokens.TextMutedBrush;
        }

        private void SelectAudioSourceCombo(CaptureDevice device)
        {
            foreach (ComboBoxItem item in AudioSourceCombo.Items)
            {
                if (item.Tag is CaptureDevice d && d == device)
                {
                    AudioSourceCombo.SelectedItem = item;
                    return;
                }
            }
        }

        private void SwitchToTab(MainTab tab)
        {
            _currentTab = tab;
            NotesPanel.Visibility = tab == MainTab.Notes ? Visibility.Visible : Visibility.Collapsed;
            VoicePanel.Visibility = tab == MainTab.Voice ? Visibility.Visible : Visibility.Collapsed;
            CodingPanel.Visibility = tab == MainTab.Coding ? Visibility.Visible : Visibility.Collapsed;
            PracticePanel.Visibility = tab == MainTab.Practice ? Visibility.Visible : Visibility.Collapsed;

            StyleTabButton(TabVoiceButton, tab == MainTab.Voice);
            StyleTabButton(TabCodingButton, tab == MainTab.Coding);
            StyleTabButton(TabNotesButton, tab == MainTab.Notes);
            StyleTabButton(TabPracticeButton, tab == MainTab.Practice);
        }

        private static void StyleTabButton(Button btn, bool active)
        {
            btn.Background = active ? DesignTokens.AccentWashBrush : Brushes.Transparent;
            btn.Foreground = active ? DesignTokens.AccentTextBrush : DesignTokens.TextMutedBrush;
            btn.FontWeight = active ? FontWeights.SemiBold : FontWeights.Normal;
        }

        private void CreateNewNote()
        {
            var result = MessageBox.Show(this, "Clear all notes and start fresh?", "New Note", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (result == MessageBoxResult.Yes)
            {
                NotesRichTextBox.Document.Blocks.Clear();
                _notesEditor?.SaveNotes();
            }
        }

        private async System.Threading.Tasks.Task CaptureScreenshot()
        {
            if (_screenshotManager != null)
                await _screenshotManager.CaptureScreenshotAsync();
        }

        private async System.Threading.Tasks.Task AnalyzeScreenshots()
        {
            if (_screenshotManager != null)
            {
                SwitchToTab(MainTab.Coding);
                await _screenshotManager.AnalyzeScreenshotsAsync();
            }
        }

        private void ClearScreenshots() => _screenshotManager?.ClearAllScreenshots();
        private void ExportNotes() => _interviewExport?.ExportInterview();

        private void ShowSettings()
        {
            var settingsWindow = SettingsWindowController.Create();
            settingsWindow.Owner = this;
            settingsWindow.ShowDialog();
        }

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            _notesEditor?.SaveNotes();
            _interviewExport?.AutoSaveSession();

            _hotkeyManager?.Dispose();
            _voiceInterviewController?.Dispose();
            _focusController?.Dispose();
            _codePanel?.Dispose();
            _noticeController?.Dispose();
            _notesEditor?.Dispose();
            _monitoringServices?.Dispose();
            _recordingIndicator?.Dispose();

            AppNotifications.ApiKeysUpdated -= HandleApiKeysUpdated;
            AppNotifications.InterviewSettingsUpdated -= HandleInterviewSettingsUpdated;
            base.OnClosing(e);
        }
    }
}
