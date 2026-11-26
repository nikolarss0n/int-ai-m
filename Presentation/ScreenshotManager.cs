using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using InterviewMasterApp.Domain.Entities;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Domain.ValueObjects;
using InterviewMasterApp.Infrastructure.API;
using InterviewMasterApp.Infrastructure.Capture;
using InterviewMasterApp.Presentation.Components;
using InterviewMasterApp.Presentation.Styling;
using InterviewMasterApp.Presentation.Timeline;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
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
        private readonly CodePanelView? _codePanel;
        private readonly Window _mainWindow;
        private readonly Action<FeedbackNotice, Action?>? _postNotice;

        private readonly List<Border> _screenshotThumbnails = new();
        private readonly ScreenshotCaptureIndicator _captureIndicator;
        private string? _apiKey;
        private AnalysisMode _analysisMode = AnalysisMode.Smart;
        private string? _currentPinnedSolution;

        // Undo snapshot
        private List<Screenshot>? _undoScreenshots;
        private string? _undoPinnedSolution;

        public string? CurrentPinnedSolution => _currentPinnedSolution;
        public int ScreenshotCount => _screenshots.Count;

        public event Action<int>? ScreenshotCountChanged;

        public static string ConsentFilePath =>
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "InterviewMaster", "consent.txt");

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
            FloatingSolutionWindowController? floatingSolutionController = null,
            CodePanelView? codePanel = null,
            Action<FeedbackNotice, Action?>? postNotice = null)
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
            _codePanel = codePanel;
            _postNotice = postNotice;

            _captureIndicator = new ScreenshotCaptureIndicator(screenshotThumbnailsContainer);
        }

        public void SetApiKey(string? apiKey) => _apiKey = apiKey;
        public void SetAnalysisMode(AnalysisMode mode) => _analysisMode = mode;

        public async Task CaptureScreenshotAsync()
        {
            await _mainWindow.Dispatcher.InvokeAsync(() => _captureIndicator.Show());
            try
            {
                var result = await _screenCaptureService.CaptureScreenAsync().ConfigureAwait(false);
                if (result.IsSuccess && result.Screenshot != null)
                {
                    var shot = result.Screenshot;
                    var thumbBytes = shot.GenerateThumbnail(200, 112);

                    await _mainWindow.Dispatcher.InvokeAsync(() =>
                    {
                        _screenshots.Add(shot);
                        AddThumbnailToStrip(thumbBytes, shot.Id);
                        AddScreenshotMessage(shot.Id);
                        _captureIndicator.Hide();
                        ScreenshotCountChanged?.Invoke(_screenshots.Count);
                        _postNotice?.Invoke(
                            FeedbackNotice.Confirmation("screenshot", $"Screenshot captured ({_screenshots.Count})",
                                ScreenshotPresentation.LiveScreenshotStatusText(_screenshots.Count)),
                            null);
                    });
                }
                else
                {
                    await _mainWindow.Dispatcher.InvokeAsync(() =>
                    {
                        _captureIndicator.Hide();
                        _postNotice?.Invoke(
                            FeedbackCopy.ScreenshotFailed(result.ErrorMessage ?? result.Error.ToString()),
                            () => _ = CaptureScreenshotAsync());
                    });
                }
            }
            catch (Exception ex)
            {
                await _mainWindow.Dispatcher.InvokeAsync(() =>
                {
                    _captureIndicator.Hide();
                    _postNotice?.Invoke(FeedbackCopy.ScreenshotFailed(ex.Message), () => _ = CaptureScreenshotAsync());
                });
            }
        }

        private void AddThumbnailToStrip(byte[] thumbBytes, Guid id)
        {
            var bmp = BytesToBitmapImage(thumbBytes);
            var border = new Border
            {
                Width = 72,
                Height = 40,
                Margin = new Thickness(0, 0, 8, 0),
                CornerRadius = new CornerRadius(6),
                BorderThickness = new Thickness(1),
                BorderBrush = DesignTokens.BorderSubtleBrush,
                Background = Brushes.Black,
                ClipToBounds = true,
                Tag = id,
                Child = new Image { Source = bmp, Stretch = Stretch.UniformToFill }
            };
            _screenshotThumbnailsContainer.Children.Add(border);
            _screenshotThumbnails.Add(border);
        }

        private void AddScreenshotMessage(Guid screenshotId)
        {
            _voiceMessages.Add(new InterviewMessage(
                InterviewMessage.MessageType.Screenshot,
                "Screenshot captured",
                topic: null,
                screenshotId: screenshotId));
        }

        public async Task AnalyzeScreenshotsAsync()
        {
            if (_screenshots.Count == 0)
            {
                _postNotice?.Invoke(FeedbackCopy.NothingToAnalyze, null);
                return;
            }

            if (string.IsNullOrWhiteSpace(_apiKey))
            {
                _postNotice?.Invoke(
                    FeedbackNotice.Error("screenshot", "Anthropic API key required for screenshot analysis",
                        "Add your Anthropic key in Settings (Ctrl+,).", FeedbackCopy.OpenSettings),
                    null);
                return;
            }

            if (!GetDataConsent())
            {
                if (!ShowDataConsentDialog()) return;
                SetDataConsent(true);
            }

            await PerformAnalysisAsync(_apiKey!).ConfigureAwait(false);
        }

        private async Task PerformAnalysisAsync(string apiKey)
        {
            var base64Images = _screenshots.Select(s => s.ToBase64()).Where(b => !string.IsNullOrEmpty(b)).ToList();
            var taskTurnId = Guid.NewGuid();

            await _mainWindow.Dispatcher.InvokeAsync(() =>
            {
                _currentPinnedSolution = $"Analyzing {_screenshots.Count} screenshot{(_screenshots.Count == 1 ? "" : "s")}…";
                _codePanel?.StartTask(new CodingTaskInfo(taskTurnId, $"Screenshot Analysis ({_screenshots.Count})", false, AllowsChanges: false));
                if (!_mainWindow.IsVisible)
                    _floatingSolutionController?.Show();
            });

            var client = new AnthropicApiClient(apiKey);
            var prompt = _analysisMode.Prompt();
            var fullResponse = string.Empty;

            var result = await client.SendMessageStreamAsync(base64Images, prompt, chunk =>
            {
                fullResponse += chunk;
                _mainWindow.Dispatcher.BeginInvoke(new Action(() =>
                {
                    _currentPinnedSolution = fullResponse;
                    _codePanel?.UpdateCode(fullResponse);
                    if (_analysisTextBox != null)
                        _analysisTextBox.Document = FlowDocumentMarkdownRenderer.Render(fullResponse, DesignTokens.FontSizes.Body);
                    if (_floatingSolutionController?.IsVisible == true)
                        _floatingSolutionController.UpdateContent(fullResponse);
                }));
            }).ConfigureAwait(false);

            await _mainWindow.Dispatcher.InvokeAsync(() =>
            {
                if (!result.IsSuccess)
                {
                    var err = result.ErrorMessage ?? "Analysis failed";
                    _codePanel?.FinishTask(CodingTaskOutcome.Incomplete(err));
                    _postNotice?.Invoke(FeedbackNotice.Error("screenshot", $"Analysis failed: {err}", actionTitle: FeedbackCopy.TryAgain), () => _ = AnalyzeScreenshotsAsync());
                    return;
                }

                _currentPinnedSolution = fullResponse;
                _codePanel?.UpdateCode(fullResponse);
                _codePanel?.FinishTask(CodingTaskOutcome.Complete());
                if (_analysisTextBox != null)
                    _analysisTextBox.Document = FlowDocumentMarkdownRenderer.Render(fullResponse, DesignTokens.FontSizes.Body);
                if (!_mainWindow.IsVisible)
                    _floatingSolutionController?.UpdateContent(fullResponse);

                _voiceMessages.Add(new InterviewMessage(InterviewMessage.MessageType.CodingTask, fullResponse, "coding"));
                _screenshots.Clear();
                ClearThumbnailVisuals();
                ScreenshotCountChanged?.Invoke(0);
            });
        }

        public void ClearAllScreenshots()
        {
            var hadShots = _screenshots.Count;
            var hadCode = !string.IsNullOrWhiteSpace(_currentPinnedSolution) || (_codePanel?.HasCode == true);
            var summary = FeedbackCopy.Cleared(hadShots, hadCode);
            if (summary == null) return;

            // Save snapshot for Undo
            _undoScreenshots = _screenshots.ToList();
            _undoPinnedSolution = _currentPinnedSolution;

            _screenshots.Clear();
            ClearThumbnailVisuals();
            _currentPinnedSolution = null;
            _codePanel?.Clear();
            _analysisTextBox?.Document.Blocks.Clear();
            ScreenshotCountChanged?.Invoke(0);

            _postNotice?.Invoke(
                FeedbackNotice.Info("clear", summary, actionTitle: "Undo"),
                UndoClear);
        }

        private void UndoClear()
        {
            if (_undoScreenshots != null)
            {
                foreach (var s in _undoScreenshots)
                {
                    _screenshots.Add(s);
                    AddThumbnailToStrip(s.GenerateThumbnail(200, 112), s.Id);
                }
            }
            if (!string.IsNullOrWhiteSpace(_undoPinnedSolution))
            {
                _currentPinnedSolution = _undoPinnedSolution;
                _codePanel?.UpdateCode(_undoPinnedSolution);
                if (_analysisTextBox != null)
                    _analysisTextBox.Document = FlowDocumentMarkdownRenderer.Render(_undoPinnedSolution, DesignTokens.FontSizes.Body);
            }

            var restored = FeedbackCopy.Restored(_undoScreenshots?.Count ?? 0, !string.IsNullOrWhiteSpace(_undoPinnedSolution));
            _undoScreenshots = null;
            _undoPinnedSolution = null;
            ScreenshotCountChanged?.Invoke(_screenshots.Count);
            if (restored != null)
                _postNotice?.Invoke(FeedbackNotice.Confirmation("clear", restored), null);
        }

        public void ResetCodingTab() => ClearAllScreenshots();

        private void ClearThumbnailVisuals()
        {
            foreach (var thumb in _screenshotThumbnails)
                _screenshotThumbnailsContainer.Children.Remove(thumb);
            _screenshotThumbnails.Clear();
        }

        private bool ShowDataConsentDialog()
        {
            var res = MessageBox.Show(
                _mainWindow,
                "To analyze your screenshots, Interview Master sends captured screenshot images to Anthropic's Claude API.\n\nDo you consent to share screenshot images with Anthropic for analysis?",
                "Data Sharing Consent",
                MessageBoxButton.YesNo,
                MessageBoxImage.Information);
            return res == MessageBoxResult.Yes;
        }

        public static bool GetDataConsent()
        {
            try { return File.Exists(ConsentFilePath) && File.ReadAllText(ConsentFilePath).Trim() == "true"; }
            catch { return false; }
        }

        public static void SetDataConsent(bool value)
        {
            try
            {
                var dir = Path.GetDirectoryName(ConsentFilePath);
                if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
                File.WriteAllText(ConsentFilePath, value ? "true" : "false");
            }
            catch { }
        }

        private static BitmapImage BytesToBitmapImage(byte[] bytes)
        {
            var bmp = new BitmapImage();
            using var ms = new MemoryStream(bytes);
            bmp.BeginInit();
            bmp.CacheOption = BitmapCacheOption.OnLoad;
            bmp.StreamSource = ms;
            bmp.EndInit();
            bmp.Freeze();
            return bmp;
        }
    }
}
