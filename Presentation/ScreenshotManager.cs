using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using InterviewMasterApp.Domain.Entities;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Domain.ValueObjects;
using InterviewMasterApp.Infrastructure.API;
using InterviewMasterApp.Infrastructure.Capture;
using InterviewMasterApp.Presentation.Timeline;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Screenshot capture and AI analysis manager.
    /// Ported from Swift: ScreenshotManager.swift
    /// Handles screen capture, permission checks, thumbnail display, and Claude AI analysis.
    /// </summary>
    public class ScreenshotManager
    {
        private readonly IScreenCaptureService _screenCaptureService;
        private readonly List<Screenshot> _screenshots;
        private readonly List<InterviewMessage> _voiceMessages;
        private readonly MessageViewFactory _messageViewFactory;
        private readonly Panel _screenshotThumbnailsContainer;
        private readonly Panel _voiceTimelineContainer;
        private readonly ScrollViewer _voiceTimelineScrollView;
        private readonly RichTextBox? _analysisTextBox;
        private readonly FloatingSolutionWindowController? _floatingSolutionController;
        private readonly Window _mainWindow;

        private readonly List<Border> _screenshotThumbnails = new();
        private readonly ScreenshotCaptureIndicator _captureIndicator;
        private string? _apiKey;
        private AnalysisMode _analysisMode = AnalysisMode.Smart;
        private string? _currentPinnedSolution;

        private const string DataConsentKey = "DataConsentGiven";
        private const double ThumbnailHeight = 35;
        private const double ThumbnailWidth = 62; // 16:9 aspect ratio
        private const double ThumbnailSpacing = 10;

        public string? CurrentPinnedSolution => _currentPinnedSolution;

        public ScreenshotManager(
            IScreenCaptureService screenCaptureService,
            List<Screenshot> screenshots,
            List<InterviewMessage> voiceMessages,
            MessageViewFactory messageViewFactory,
            Panel screenshotThumbnailsContainer,
            Panel voiceTimelineContainer,
            ScrollViewer voiceTimelineScrollView,
            Window mainWindow,
            RichTextBox? analysisTextBox = null,
            FloatingSolutionWindowController? floatingSolutionController = null)
        {
            _screenCaptureService = screenCaptureService ?? throw new ArgumentNullException(nameof(screenCaptureService));
            _screenshots = screenshots ?? throw new ArgumentNullException(nameof(screenshots));
            _voiceMessages = voiceMessages ?? throw new ArgumentNullException(nameof(voiceMessages));
            _messageViewFactory = messageViewFactory ?? throw new ArgumentNullException(nameof(messageViewFactory));
            _screenshotThumbnailsContainer = screenshotThumbnailsContainer ?? throw new ArgumentNullException(nameof(screenshotThumbnailsContainer));
            _voiceTimelineContainer = voiceTimelineContainer ?? throw new ArgumentNullException(nameof(voiceTimelineContainer));
            _voiceTimelineScrollView = voiceTimelineScrollView ?? throw new ArgumentNullException(nameof(voiceTimelineScrollView));
            _mainWindow = mainWindow ?? throw new ArgumentNullException(nameof(mainWindow));
            _analysisTextBox = analysisTextBox;
            _floatingSolutionController = floatingSolutionController;

            // Create capture indicator
            _captureIndicator = new ScreenshotCaptureIndicator(screenshotThumbnailsContainer);
        }

        public void SetApiKey(string apiKey)
        {
            _apiKey = apiKey;
        }

        public void SetAnalysisMode(AnalysisMode mode)
        {
            _analysisMode = mode;
        }

        /// <summary>
        /// Capture screenshot (entry point from menu/hotkey).
        /// Windows doesn't require permission like macOS - screen capture is always available.
        /// </summary>
        public async Task CaptureScreenshotAsync()
        {
            StealthLogger.Shared.Log("📸 CaptureScreenshotAsync() called");

            try
            {
                await CaptureScreenshotInternalAsync();
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"📸 Capture exception: {ex.Message}");
                ShowAlert("Screenshot Failed", $"Error: {ex.Message}");
            }
        }

        /// <summary>
        /// Internal screenshot capture with result handling.
        /// </summary>
        private async Task CaptureScreenshotInternalAsync()
        {
            StealthLogger.Shared.Log("📸 Calling screenCaptureService.CaptureScreenAsync()");

            // Show capture indicator before capture
            await _mainWindow.Dispatcher.InvokeAsync(() =>
            {
                _captureIndicator.Show();
            });

            try
            {
                var result = await _screenCaptureService.CaptureScreenAsync();

                if (result.IsSuccess)
                {
                    var screenshot = result.Screenshot;
                    StealthLogger.Shared.Log($"📸 Capture SUCCESS - id={screenshot.Id}, size={screenshot.SizeInKb:F1}KB");

                    // Generate thumbnail for timeline (200x112)
                    var timelineThumbnail = screenshot.GenerateThumbnail(200, 112);

                    // Add to screenshots array and update timeline UI on UI thread
                    await _mainWindow.Dispatcher.InvokeAsync(() =>
                    {
                        StealthLogger.Shared.Log("📸 Adding screenshot to timeline UI");
                        _screenshots.Add(screenshot);
                        StealthLogger.Shared.Log($"📸 Screenshots count: {_screenshots.Count}");
                        AddScreenshotToTimeline(timelineThumbnail, screenshot.Id);

                        // Hide indicator after successful capture
                        _captureIndicator.Hide();

                        // Visual feedback (beep)
                        System.Media.SystemSounds.Beep.Play();
                    });
                }
                else
                {
                    StealthLogger.Shared.Log($"📸 Capture FAILED: {result.Error}");

                    await _mainWindow.Dispatcher.InvokeAsync(() =>
                    {
                        // Hide indicator on error
                        _captureIndicator.Hide();

                        var message = result.Error switch
                        {
                            CaptureError.NoDisplayFound => "No display found",
                            CaptureError.CaptureFailed => $"Error: {result.ErrorMessage}",
                            _ => "Unknown error"
                        };
                        ShowAlert("Screenshot Failed", message);
                    });
                }
            }
            catch
            {
                // Hide indicator on exception
                await _mainWindow.Dispatcher.InvokeAsync(() =>
                {
                    _captureIndicator.Hide();
                });
                throw;
            }
        }

        /// <summary>
        /// Add screenshot thumbnail to the UI container.
        /// </summary>
        private void AddThumbnailToUI(BitmapImage thumbnail, Guid id)
        {
            var xOffset = _screenshotThumbnails.Count * (ThumbnailWidth + ThumbnailSpacing);

            var thumbnailBorder = new Border
            {
                Width = ThumbnailWidth,
                Height = ThumbnailHeight,
                Margin = new Thickness(xOffset, 0, 0, 0),
                CornerRadius = new CornerRadius(6),
                BorderThickness = new Thickness(1.5),
                BorderBrush = new SolidColorBrush(Color.FromArgb(77, 255, 255, 255)), // 30% white
                Background = Brushes.Black,
                ClipToBounds = true,
                Cursor = System.Windows.Input.Cursors.Hand,
                Tag = id
            };

            var image = new Image
            {
                Source = thumbnail,
                Stretch = Stretch.UniformToFill
            };

            thumbnailBorder.Child = image;
            _screenshotThumbnailsContainer.Children.Add(thumbnailBorder);
            _screenshotThumbnails.Add(thumbnailBorder);

            // Update container width
            _screenshotThumbnailsContainer.Width = _screenshotThumbnails.Count * (ThumbnailWidth + ThumbnailSpacing);
        }

        /// <summary>
        /// Add screenshot to voice timeline.
        /// </summary>
        private void AddScreenshotToTimeline(byte[] thumbnailData, Guid screenshotId)
        {
            // Create screenshot message
            var message = new InterviewMessage(
                InterviewMessage.MessageType.Screenshot,
                "Screenshot captured",
                topic: null,
                screenshotId: screenshotId
            );

            _voiceMessages.Add(message);

            // Create view for the message (this would use MessageViewFactory in a full implementation)
            // For now, add a simple thumbnail representation
            // TODO: Implement full message view creation using MessageViewFactory
        }

        /// <summary>
        /// Reset coding tab - clear screenshots and analysis.
        /// </summary>
        public void ResetCodingTab()
        {
            // Clear all screenshots
            _screenshots.Clear();

            // Remove all thumbnail buttons from UI
            foreach (var thumbnail in _screenshotThumbnails)
            {
                _screenshotThumbnailsContainer.Children.Remove(thumbnail);
            }
            _screenshotThumbnails.Clear();

            // Reset container width
            _screenshotThumbnailsContainer.Width = 100;

            // Clear analysis text
            if (_analysisTextBox != null)
            {
                _analysisTextBox.Document.Blocks.Clear();
            }
        }

        /// <summary>
        /// Show alert dialog.
        /// </summary>
        private void ShowAlert(string title, string message)
        {
            MessageBox.Show(_mainWindow, message, title, MessageBoxButton.OK, MessageBoxImage.Information);
        }

        /// <summary>
        /// Analyze screenshots with Claude AI.
        /// </summary>
        public async Task AnalyzeScreenshotsAsync()
        {
            if (_screenshots.Count == 0)
            {
                ShowAlert("No Screenshots", "Please capture at least one screenshot first (Win+S)");
                return;
            }

            if (string.IsNullOrWhiteSpace(_apiKey))
            {
                ShowAlert("API Key Required", "Please configure your Anthropic API key in settings (⚙️ API Key)");
                return;
            }

            // Check for data consent (required by App Store Guideline 5.1.2)
            var consentGiven = GetDataConsent();
            if (!consentGiven)
            {
                var userConsented = ShowDataConsentDialog();
                if (!userConsented)
                    return;

                SetDataConsent(true);
            }

            await PerformAnalysisAsync(_apiKey);
        }

        /// <summary>
        /// Show data consent dialog for AI analysis.
        /// </summary>
        private bool ShowDataConsentDialog()
        {
            var result = MessageBox.Show(
                _mainWindow,
                "To analyze your screenshots, Interview Master will send them to Anthropic's Claude AI service.\n\n" +
                "What is shared:\n" +
                "• Screenshot images you capture\n" +
                "• Analysis prompts\n\n" +
                "What is NOT shared:\n" +
                "• Your notes\n" +
                "• Personal information\n" +
                "• API keys\n\n" +
                "Anthropic processes data according to their privacy policy. Screenshots are not stored permanently.\n\n" +
                "Do you consent to share screenshot data with Anthropic for AI analysis?\n\n" +
                "Click Yes to consent, No to cancel, or Help to view privacy policy.",
                "Data Sharing Consent",
                MessageBoxButton.YesNoCancel,
                MessageBoxImage.Information,
                MessageBoxResult.No);

            if (result == MessageBoxResult.Cancel)
            {
                // Show Anthropic privacy policy
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "https://www.anthropic.com/privacy",
                        UseShellExecute = true
                    });
                }
                catch { }

                // Show dialog again after viewing privacy policy
                return ShowDataConsentDialog();
            }

            return result == MessageBoxResult.Yes;
        }

        /// <summary>
        /// Perform AI analysis with streaming.
        /// </summary>
        private async Task PerformAnalysisAsync(string apiKey)
        {
            // Convert screenshots to base64
            var base64Images = new List<string>();
            foreach (var screenshot in _screenshots)
            {
                var base64 = screenshot.ToBase64();
                if (!string.IsNullOrEmpty(base64))
                {
                    base64Images.Add(base64);
                }
            }

            // Show loading state in pinned header
            await _mainWindow.Dispatcher.InvokeAsync(() =>
            {
                SetPinnedSolution($"🤔 Analyzing {_screenshots.Count} screenshot{(_screenshots.Count == 1 ? "" : "s")}...");

                // If main window is hidden, show floating window with loading state (stealth mode)
                if (!_mainWindow.IsVisible)
                {
                    _floatingSolutionController?.Show();
                }
            });

            // Create client with current API key
            var client = new AnthropicApiClient(apiKey);

            // Get prompt and prefill from analysis mode
            var prompt = _analysisMode.Prompt();
            var prefill = _analysisMode.Prefill();

            // Collect full response for pinning
            var fullResponse = "";

            // Stream the response directly to pinned solution
            var result = await client.SendMessageStreamAsync(
                base64Images,
                prompt,
                chunk =>
                {
                    fullResponse += chunk;
                    _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
                    {
                        // Update pinned solution with streaming content
                        UpdatePinnedSolutionContent(fullResponse);
                    }));
                });

            if (!result.IsSuccess)
            {
                await _mainWindow.Dispatcher.InvokeAsync(() =>
                {
                    ShowAlert("Analysis Failed", result.ErrorMessage ?? "Unknown error");
                    SetPinnedSolution($"❌ Analysis failed: {result.ErrorMessage}");
                });
            }
            else
            {
                // Final update
                await _mainWindow.Dispatcher.InvokeAsync(() =>
                {
                    // Update the coding task in timeline with final content
                    UpdatePinnedSolutionContent(fullResponse);

                    // Update floating window with final content (stealth mode)
                    if (!_mainWindow.IsVisible)
                    {
                        _floatingSolutionController?.UpdateContent(fullResponse);
                    }

                    // Clear screenshots for next task
                    _screenshots.Clear();

                    // Archive old gallery so new screenshots create a fresh entry
                    foreach (UIElement child in _voiceTimelineContainer.Children)
                    {
                        if (child is FrameworkElement element && element.Tag?.ToString() == "screenshotGallery")
                        {
                            element.Tag = $"screenshotGallery_archived_{Guid.NewGuid()}";
                            break;
                        }
                    }
                });
            }
        }

        /// <summary>
        /// Set pinned solution content.
        /// </summary>
        private void SetPinnedSolution(string content)
        {
            _currentPinnedSolution = content;

            // Find existing coding task view or create new one
            FrameworkElement? codingTaskView = null;
            foreach (UIElement child in _voiceTimelineContainer.Children)
            {
                if (child is FrameworkElement element && element.Tag?.ToString() == "codingTask")
                {
                    codingTaskView = element;
                    break;
                }
            }

            if (codingTaskView == null)
            {
                // Create new coding task view
                // TODO: Implement full coding task view creation
                // For now, create a simple placeholder
                codingTaskView = new Border
                {
                    Tag = "codingTask",
                    Background = new SolidColorBrush(Color.FromArgb(26, 139, 92, 246)), // Purple tint
                    CornerRadius = new CornerRadius(8),
                    Padding = new Thickness(12),
                    Margin = new Thickness(0, 0, 0, 15)
                };

                var textBlock = new TextBlock
                {
                    Text = content,
                    Foreground = Brushes.White,
                    TextWrapping = TextWrapping.Wrap
                };

                ((Border)codingTaskView).Child = textBlock;
                _voiceTimelineContainer.Children.Insert(0, codingTaskView);
            }
        }

        /// <summary>
        /// Update pinned solution content during streaming.
        /// </summary>
        private void UpdatePinnedSolutionContent(string content)
        {
            _currentPinnedSolution = content;

            // Find existing coding task view
            foreach (UIElement child in _voiceTimelineContainer.Children)
            {
                if (child is FrameworkElement element && element.Tag?.ToString() == "codingTask")
                {
                    if (element is Border border && border.Child is TextBlock textBlock)
                    {
                        textBlock.Text = content;
                    }
                    break;
                }
            }

            // Scroll to top
            _voiceTimelineScrollView.ScrollToTop();

            // Sync to floating window if visible
            if (_floatingSolutionController?.IsVisible == true)
            {
                _floatingSolutionController.UpdateContent(content);
            }
        }

        /// <summary>
        /// Clear pinned solution.
        /// </summary>
        public void ClearPinnedSolution()
        {
            _currentPinnedSolution = null;

            // Remove coding task view from timeline
            UIElement? toRemove = null;
            foreach (UIElement child in _voiceTimelineContainer.Children)
            {
                if (child is FrameworkElement element && element.Tag?.ToString() == "codingTask")
                {
                    toRemove = child;
                    break;
                }
            }

            if (toRemove != null)
            {
                _voiceTimelineContainer.Children.Remove(toRemove);
            }
        }

        /// <summary>
        /// Clear all screenshots.
        /// </summary>
        public void ClearAllScreenshots()
        {
            _screenshots.Clear();
            foreach (var thumbnail in _screenshotThumbnails)
            {
                _screenshotThumbnailsContainer.Children.Remove(thumbnail);
            }
            _screenshotThumbnails.Clear();
            _screenshotThumbnailsContainer.Width = 100;

            if (_analysisTextBox != null)
            {
                var paragraph = new System.Windows.Documents.Paragraph();
                paragraph.Inlines.Add("💻 AI Analysis will appear here\n\nCapture screenshots (Win+S) and press Analyze (Win+Enter)");
                _analysisTextBox.Document.Blocks.Clear();
                _analysisTextBox.Document.Blocks.Add(paragraph);
            }
        }

        /// <summary>
        /// Clear screenshots from voice timeline.
        /// </summary>
        public void ClearScreenshotsFromTimeline()
        {
            // Clear screenshots array
            _screenshots.Clear();

            // Remove screenshot containers from timeline
            var toRemove = new List<UIElement>();
            foreach (UIElement child in _voiceTimelineContainer.Children)
            {
                if (child is FrameworkElement element && element.Tag?.ToString()?.StartsWith("screenshot_") == true)
                {
                    toRemove.Add(child);
                }
            }

            foreach (var element in toRemove)
            {
                _voiceTimelineContainer.Children.Remove(element);
            }

            // Remove screenshot messages from array
            _voiceMessages.RemoveAll(m => m.Type == InterviewMessage.MessageType.Screenshot);

            // Hide pinned solution if showing
            ClearPinnedSolution();

            // Recalculate timeline height (WPF handles this automatically with proper layout)
        }

        /// <summary>
        /// Get data consent setting.
        /// </summary>
        private bool GetDataConsent()
        {
            try
            {
                var appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                var consentFile = Path.Combine(appDataPath, "InterviewMaster", "consent.txt");
                return File.Exists(consentFile) && File.ReadAllText(consentFile) == "true";
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Set data consent setting.
        /// </summary>
        private void SetDataConsent(bool value)
        {
            try
            {
                var appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                var appFolder = Path.Combine(appDataPath, "InterviewMaster");
                Directory.CreateDirectory(appFolder);
                var consentFile = Path.Combine(appFolder, "consent.txt");
                File.WriteAllText(consentFile, value ? "true" : "false");
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"⚠️ Failed to save consent: {ex.Message}");
            }
        }
    }
}

