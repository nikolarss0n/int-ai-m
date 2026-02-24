using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using InterviewMasterApp;
using InterviewMasterApp.Application;
using InterviewMasterApp.Application.UseCases;
using InterviewMasterApp.Domain.Entities;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Infrastructure.API;
using InterviewMasterApp.Infrastructure.Capture;
using InterviewMasterApp.Infrastructure.Storage;
using InterviewMasterApp.Presentation;
using InterviewMasterApp.Presentation.Settings;
using InterviewMasterApp.Presentation.Timeline;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation.Windows
{
    /// <summary>
    /// Main application window and controller.
    /// Ported from Swift: interview_master.swift (InterviewMasterDelegate)
    /// Integrates all presentation components and orchestrates the interview application.
    /// </summary>
    public partial class MainWindow : Window, IFloatingSolutionDataSource
    {
        // Infrastructure services
        private readonly IScreenCaptureService _screenCaptureService;

        // Domain models
        private readonly List<Screenshot> _screenshots = new();
        private readonly List<InterviewMessage> _voiceMessages = new();
        private readonly ConversationContext _conversationContext = new();

        // Presentation components
        private VoiceInterviewController? _voiceInterviewController;
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

        // Current state
        private MainTab _currentTab = MainTab.Voice;

        private enum MainTab
        {
            Notes,
            Voice,
            Coding
        }

        // IFloatingSolutionDataSource implementation
        public string? CurrentPinnedSolution => _screenshotManager?.CurrentPinnedSolution;
        public List<InterviewMessage> VoiceMessages => _voiceMessages;
        public MessageViewFactory MessageViewFactory => _messageViewFactory!;

        public MainWindow()
        {
            InitializeComponent();

            // Initialize infrastructure
            _screenCaptureService = new ScreenCaptureService();

            // Setup window properties
            Title = "Interview Master";
            Width = 1000;
            Height = 720;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;

            // Wire up custom title bar buttons
            MinimizeButton.Click += (s, e) => WindowState = WindowState.Minimized;
            CloseButton.Click += (s, e) => Close();

            // Enable window dragging from title bar
            TitleBar.MouseLeftButtonDown += (s, e) =>
            {
                if (e.ClickCount == 2)
                {
                    WindowState = WindowState == WindowState.Maximized
                        ? WindowState.Normal
                        : WindowState.Maximized;
                }
                else
                {
                    DragMove();
                }
            };

            // Initialize components
            InitializeComponents();

            // Wire Start Interview button
            StartInterviewButton.Click += (s, e) =>
            {
                _voiceInterviewController?.ToggleInterview();
                UpdateInterviewButtonState();
            };

            // Setup UI
            SetupUI();

            // Setup hotkeys
            SetupHotkeys();

            // Subscribe to app notifications
            SubscribeToAppNotifications();

            // Load saved notes
            _notesEditor?.LoadNotes();

            StealthLogger.Shared.Log("🚀 Application started");
        }

        private void InitializeComponents()
        {
            // Create message view factory
            var markdownRenderer = new Presentation.Styling.MarkdownRenderer(
                Presentation.Styling.MarkdownRenderer.Style.Notes);
            _messageViewFactory = new MessageViewFactory(markdownRenderer, ActualWidth - 100);

            // Create floating solution controller
            _floatingSolutionController = new FloatingSolutionWindowController(this);

            // Create recording indicator
            _recordingIndicator = new RecordingIndicator(MainPanel);

            // Create timeline manager
            _timelineManager = new TimelineManager(
                voiceTimelineContainer: VoiceTimelinePanel,
                voiceTimelineScrollView: VoiceTimelineScrollViewer,
                voiceMessages: _voiceMessages,
                screenshots: _screenshots,
                messageViewFactory: _messageViewFactory,
                typingDotsContainer: TypingDotsPanel,
                floatingController: _floatingSolutionController,
                showSettingsCallback: () => ShowSettings()
            );

            // Create screenshot manager
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
                floatingSolutionController: _floatingSolutionController
            );

            // Create voice interview processor
            var voiceProcessor = new VoiceInterviewProcessor();

            // Create interview export
            _interviewExport = new InterviewExport(_voiceMessages);

            // Create voice interview controller
            _voiceInterviewController = new VoiceInterviewController(
                mainWindow: this,
                notesTextBox: NotesRichTextBox,
                voiceStatusLabel: VoiceStatusLabel,
                timelineManager: _timelineManager,
                recordingIndicator: _recordingIndicator,
                conversationContext: _conversationContext,
                voiceInterviewProcessor: voiceProcessor,
                interviewExport: _interviewExport,
                showSettingsCallback: () => ShowSettings()
            );

            // Create search controller
            var searchField = new TextBox();
            var searchResults = new TextBlock();
            var searchContainer = SearchController.CreateSearchContainer(searchField, searchResults);
            MainPanel.Children.Add(searchContainer);

            _searchController = new SearchController(
                searchContainer: searchContainer,
                searchField: searchField,
                searchResultsLabel: searchResults,
                textView: NotesRichTextBox,
                renderMarkdownCallback: () => _notesEditor?.RenderMarkdown()
            );

            // Create formatting toolbar
            _formattingToolbar = new FormattingToolbar();
            _formattingToolbar.SetupFormattingToolbar(
                MainPanel,
                NotesRichTextBox,
                () => _notesEditor?.RenderMarkdown()
            );

            // Create notes editor
            _notesEditor = new NotesEditor(
                notesTextBox: NotesRichTextBox,
                analysisTextBox: AnalysisRichTextBox,
                formattingToolbar: _formattingToolbar
            );

            // Create monitoring services
            _monitoringServices = new MonitoringServices(this, _screenshots);
            _monitoringServices.AutoHideEnabled = false;

            // Create ghost mode
            _ghostMode = new GhostMode(
                window: this,
                floatingController: _floatingSolutionController
            );

            // Create template selector
            _templateSelector = new TemplateSelector(
                notesTextView: NotesRichTextBox,
                switchToNotesTabCallback: () => SwitchToTab(MainTab.Notes),
                renderMarkdownCallback: () => _notesEditor?.RenderMarkdown()
            );

            // Create menu bar
            _menuBarSetup = new MenuBarSetup(this);
            _menuBarSetup.NewNote = () => CreateNewNote();
            _menuBarSetup.CaptureScreenshot = async () => await CaptureScreenshot();
            _menuBarSetup.ExportNotes = () => ExportNotes();
            _menuBarSetup.ToggleSearch = () => _searchController?.ToggleSearch();
            _menuBarSetup.SwitchToNotesTab = () => SwitchToTab(MainTab.Notes);
            _menuBarSetup.SwitchToVoiceTab = () => SwitchToTab(MainTab.Voice);
            _menuBarSetup.ToggleWindowVisibility = () => _ghostMode?.ToggleWindowVisibility();
            _menuBarSetup.HideFloatingSolution = () => _ghostMode?.HideFloatingSolution();
            _menuBarSetup.ShowTemplateSelector = () => _templateSelector?.ShowTemplateSelector(this);

            var menuBar = _menuBarSetup.CreateMenuBar();
            DockPanel.SetDock(menuBar, Dock.Top);
            MainDockPanel.Children.Insert(0, menuBar);
        }

        private void SetupUI()
        {
            // Start in Voice tab
            SwitchToTab(MainTab.Voice);

            // Update API key status
            UpdateApiKeyStatus();
        }

        private void SetupHotkeys()
        {
            _hotkeyManager = new HotkeyManager(this);
            _hotkeyManager.ToggleInterviewMode = () => _ghostMode?.ToggleInterviewMode();
            _hotkeyManager.ToggleWindowVisibility = () => _ghostMode?.ToggleWindowVisibility();
            _hotkeyManager.CaptureScreenshot = async () => await CaptureScreenshot();
            _hotkeyManager.AnalyzeScreenshots = async () => await AnalyzeScreenshots();
            _hotkeyManager.ClearScreenshots = () => ClearScreenshots();
            _hotkeyManager.SwitchToNotesTab = () => SwitchToTab(MainTab.Notes);
            _hotkeyManager.SwitchToVoiceTab = () => SwitchToTab(MainTab.Voice);
            _hotkeyManager.ToggleSearch = () => _searchController?.ToggleSearch();
            _hotkeyManager.IsWindowVisible = () => IsVisible;
            _hotkeyManager.GetCurrentTab = () => (HotkeyManager.TabType)(int)_currentTab;
            _hotkeyManager.ResetCodingTab = () => ClearScreenshots();
            _hotkeyManager.IsSearchVisible = () => _searchController?.IsSearchVisible ?? false;

            _hotkeyManager.SetupHotkeys();
        }

        private void SubscribeToAppNotifications()
        {
            AppNotifications.ApiKeysUpdated += HandleApiKeysUpdated;
            AppNotifications.InterviewSettingsUpdated += HandleInterviewSettingsUpdated;
        }

        private void HandleApiKeysUpdated()
        {
            Dispatcher.Invoke(() =>
            {
                UpdateApiKeyStatus();

                // Update voice interview controller with new keys
                var anthropicKey = ApiKeyManager.Shared.GetKey(ApiKeyType.Anthropic);
                var groqKey = ApiKeyManager.Shared.GetKey(ApiKeyType.Groq);
                _voiceInterviewController?.SetApiKeys(groqKey, anthropicKey);

                StealthLogger.Shared.Log("✅ API keys updated");
            });
        }

        private void HandleInterviewSettingsUpdated()
        {
            Dispatcher.Invoke(() =>
            {
                // Sync settings to UI dropdowns if needed
                StealthLogger.Shared.Log("✅ Interview settings updated");
            });
        }

        private void UpdateApiKeyStatus()
        {
            var hasAnthropic = ApiKeyManager.Shared.HasKey(ApiKeyType.Anthropic);
            var hasGroq = ApiKeyManager.Shared.HasKey(ApiKeyType.Groq);

            // Update status indicators
            if (VoiceStatusLabel != null)
            {
                VoiceStatusLabel.Text = hasGroq ? "✓ Groq API ready" : "⚠️ Groq API key needed";
            }

            // Always push current keys to the voice controller
            var anthropicKey = ApiKeyManager.Shared.GetKey(ApiKeyType.Anthropic);
            var groqKey = ApiKeyManager.Shared.GetKey(ApiKeyType.Groq);
            _voiceInterviewController?.SetApiKeys(groqKey, anthropicKey);

            StealthLogger.Shared.Log($"API key status: Anthropic={hasAnthropic}, Groq={hasGroq}");
        }

        private void UpdateInterviewButtonState()
        {
            if (_voiceInterviewController?.IsInterviewActive == true)
            {
                StartInterviewButton.Content = "■ Stop Interview";
                StartInterviewButton.Background = new System.Windows.Media.SolidColorBrush(
                    System.Windows.Media.Color.FromRgb(0xC0, 0x39, 0x2B));
            }
            else
            {
                StartInterviewButton.Content = "▶ Start Interview";
                StartInterviewButton.Background = new System.Windows.Media.SolidColorBrush(
                    System.Windows.Media.Color.FromRgb(0x2D, 0x7D, 0x3A));
            }
        }

        // MARK: - Tab Switching

        private void SwitchToTab(MainTab tab)
        {
            _currentTab = tab;

            // Hide all tab content
            NotesPanel.Visibility = Visibility.Collapsed;
            VoicePanel.Visibility = Visibility.Collapsed;
            CodingPanel.Visibility = Visibility.Collapsed;

            // Show selected tab
            switch (tab)
            {
                case MainTab.Notes:
                    NotesPanel.Visibility = Visibility.Visible;
                    break;
                case MainTab.Voice:
                    VoicePanel.Visibility = Visibility.Visible;
                    break;
                case MainTab.Coding:
                    CodingPanel.Visibility = Visibility.Visible;
                    break;
            }
        }

        // MARK: - Actions

        private void CreateNewNote()
        {
            var result = MessageBox.Show(
                this,
                "Clear all notes and start fresh?",
                "New Note",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (result == MessageBoxResult.Yes)
            {
                NotesRichTextBox.Document.Blocks.Clear();
                _notesEditor?.SaveNotes();
            }
        }

        private async System.Threading.Tasks.Task CaptureScreenshot()
        {
            if (_screenshotManager != null)
            {
                await _screenshotManager.CaptureScreenshotAsync();
            }
        }

        private async System.Threading.Tasks.Task AnalyzeScreenshots()
        {
            if (_screenshotManager != null)
            {
                await _screenshotManager.AnalyzeScreenshotsAsync();
            }
        }

        private void ClearScreenshots()
        {
            _screenshotManager?.ClearAllScreenshots();
        }

        private void ExportNotes()
        {
            _interviewExport?.ExportInterview();
        }

        private void ShowSettings()
        {
            var settingsWindow = SettingsWindowController.Create();
            settingsWindow.Owner = this;
            settingsWindow.ShowDialog();
        }

        // MARK: - Window Events

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            // Auto-save before closing
            _notesEditor?.SaveNotes();
            _interviewExport?.AutoSaveSession();

            // Cleanup
            _hotkeyManager?.Dispose();
            _voiceInterviewController?.Dispose();
            _notesEditor?.Dispose();
            _monitoringServices?.Dispose();
            _recordingIndicator?.Dispose();

            // Unsubscribe from notifications
            AppNotifications.ApiKeysUpdated -= HandleApiKeysUpdated;
            AppNotifications.InterviewSettingsUpdated -= HandleInterviewSettingsUpdated;

            StealthLogger.Shared.Log("👋 Application closing");

            base.OnClosing(e);
        }

        protected override void OnActivated(EventArgs e)
        {
            base.OnActivated(e);
            StealthLogger.Shared.Log("🟢 Window activated");
        }

        protected override void OnDeactivated(EventArgs e)
        {
            base.OnDeactivated(e);
            StealthLogger.Shared.Log("⚪ Window deactivated");
        }
    }

}

