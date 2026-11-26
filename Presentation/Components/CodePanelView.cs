using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Styling;

namespace InterviewMasterApp.Presentation.Components
{
    /// <summary>
    /// Full-width docked Code Panel showing:
    /// - CodeTalkStripView (one line above the code with the first talking point)
    /// - Version stepper per coding turn (< 1 / N >)
    /// - Syntax-highlighted STEP n file blocks (grouped by file with line numbers)
    /// - Skeleton loader + WaitProgress elapsed timer while writing
    /// - Quick-action follow-up chips (Try another way, Optimize, Add tests, Use other language)
    /// - Retry button if a stream stops incomplete
    /// </summary>
    public sealed class CodePanelView : Border, IDisposable
    {
        private sealed class CodeVersion
        {
            public Guid TurnId { get; init; }
            public string Request { get; set; } = string.Empty;
            public string Markdown { get; set; } = string.Empty;
            public string TalkingPoint { get; set; } = string.Empty;
            public bool AllowsChanges { get; set; }
            public bool IsIncomplete { get; set; }
            public string? IncompleteReason { get; set; }
        }

        private readonly List<CodeVersion> _versions = new();
        private int _selectedIndex = -1;
        private bool _isStreaming;
        private DateTime _streamStartedAt;
        private readonly DispatcherTimer _waitTimer;

        private readonly TextBlock _talkStripText;
        private readonly Border _talkStrip;
        private readonly TextBlock _requestSubtitle;
        private readonly TextBlock _statusLabel;
        private readonly TextBlock _versionCounter;
        private readonly Button _prevVersionBtn;
        private readonly Button _nextVersionBtn;
        private readonly Button _copyAllBtn;
        private readonly Button _retryBtn;
        private readonly WrapPanel _quickActionsPanel;
        private readonly StackPanel _filesContainer;
        private readonly SkeletonView _skeleton;
        private readonly TextBlock _emptyState;

        public event Action<string>? QuickActionRequested;
        public event Action? RetryRequested;

        public bool HasCode => _versions.Count > 0;

        public CodePanelView()
        {
            Background = DesignTokens.BgCardBrush;
            CornerRadius = new CornerRadius(DesignTokens.Radii.Widget);
            BorderBrush = DesignTokens.BorderWidgetBrush;
            BorderThickness = new Thickness(1);
            Padding = new Thickness(16);

            var root = new Grid();
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Talk strip
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Header
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // Code files
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Quick-action chips

            // 1. Talking point strip (one line above the code)
            _talkStrip = new Border
            {
                Background = DesignTokens.AccentWashBrush,
                CornerRadius = new CornerRadius(10),
                Padding = new Thickness(12, 8, 12, 8),
                Margin = new Thickness(0, 0, 0, 12),
                Visibility = Visibility.Collapsed
            };
            _talkStripText = new TextBlock
            {
                Foreground = DesignTokens.AccentTextBrush,
                FontSize = DesignTokens.FontSizes.Body,
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            _talkStrip.Child = _talkStripText;
            Grid.SetRow(_talkStrip, 0);
            root.Children.Add(_talkStrip);

            // 2. Header row
            var header = new DockPanel { Margin = new Thickness(0, 0, 0, 12) };

            var rightControls = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
            _statusLabel = new TextBlock
            {
                Foreground = DesignTokens.TextMutedBrush,
                FontSize = DesignTokens.FontSizes.Caption,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 0, 10, 0)
            };
            _prevVersionBtn = MakeSmallButton("‹", () => SelectVersion(_selectedIndex - 1));
            _versionCounter = new TextBlock
            {
                Foreground = DesignTokens.TextMutedBrush,
                FontSize = DesignTokens.FontSizes.Caption,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(6, 0, 6, 0)
            };
            _nextVersionBtn = MakeSmallButton("›", () => SelectVersion(_selectedIndex + 1));
            _copyAllBtn = MakeSmallButton("Copy code", CopyCurrentCode);
            _copyAllBtn.Margin = new Thickness(8, 0, 0, 0);
            _retryBtn = MakeSmallButton("Retry", () => RetryRequested?.Invoke());
            _retryBtn.Background = DesignTokens.WarningWashBrush;
            _retryBtn.Foreground = DesignTokens.WarningTextBrush;
            _retryBtn.Margin = new Thickness(8, 0, 0, 0);
            _retryBtn.Visibility = Visibility.Collapsed;

            rightControls.Children.Add(_statusLabel);
            rightControls.Children.Add(_prevVersionBtn);
            rightControls.Children.Add(_versionCounter);
            rightControls.Children.Add(_nextVersionBtn);
            rightControls.Children.Add(_copyAllBtn);
            rightControls.Children.Add(_retryBtn);
            DockPanel.SetDock(rightControls, Dock.Right);
            header.Children.Add(rightControls);

            var titleStack = new StackPanel();
            titleStack.Children.Add(new TextBlock
            {
                Text = "CODE",
                Foreground = DesignTokens.CodeTextBrush,
                FontSize = DesignTokens.FontSizes.Micro,
                FontWeight = FontWeights.SemiBold
            });
            _requestSubtitle = new TextBlock
            {
                Text = "Live coding assistant",
                Foreground = DesignTokens.TextPrimaryBrush,
                FontSize = DesignTokens.FontSizes.Title,
                FontWeight = FontWeights.SemiBold,
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            titleStack.Children.Add(_requestSubtitle);
            header.Children.Add(titleStack);

            Grid.SetRow(header, 1);
            root.Children.Add(header);

            // 3. Scrollable files body
            var scroll = new ScrollViewer
            {
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
            };
            var bodyPanel = new StackPanel();
            _emptyState = new TextBlock
            {
                Text = "Ask a coding question or press Ctrl+Alt+S to capture a problem on screen.",
                Foreground = DesignTokens.TextMutedBrush,
                FontSize = DesignTokens.FontSizes.Body,
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 12, 0, 0)
            };
            _skeleton = new SkeletonView(codeShape: true) { Visibility = Visibility.Collapsed };
            _filesContainer = new StackPanel();

            bodyPanel.Children.Add(_emptyState);
            bodyPanel.Children.Add(_skeleton);
            bodyPanel.Children.Add(_filesContainer);
            scroll.Content = bodyPanel;
            Grid.SetRow(scroll, 2);
            root.Children.Add(scroll);

            // 4. Quick-action follow-up chips (only shown when code is present & allows changes)
            _quickActionsPanel = new WrapPanel
            {
                Margin = new Thickness(0, 12, 0, 0),
                Visibility = Visibility.Collapsed
            };
            Grid.SetRow(_quickActionsPanel, 3);
            root.Children.Add(_quickActionsPanel);

            Child = root;

            _waitTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _waitTimer.Tick += (_, _) =>
            {
                if (_isStreaming)
                    _statusLabel.Text = WaitProgress.CodeStatus((DateTime.UtcNow - _streamStartedAt).TotalSeconds);
            };

            UpdateVersionControls();
        }

        public void StartTask(CodingTaskInfo info)
        {
            _isStreaming = true;
            _streamStartedAt = DateTime.UtcNow;
            _statusLabel.Text = WaitProgress.CodeStatus(0);
            _waitTimer.Start();

            CodeVersion version;
            if (info.IsRefinement && _versions.Count > 0)
            {
                version = _versions[^1];
                version.Request = info.Request;
                version.IsIncomplete = false;
                version.IncompleteReason = null;
                _selectedIndex = _versions.Count - 1;
            }
            else
            {
                version = new CodeVersion
                {
                    TurnId = info.TurnId,
                    Request = info.Request,
                    AllowsChanges = info.AllowsChanges
                };
                _versions.Add(version);
                _selectedIndex = _versions.Count - 1;
            }

            _emptyState.Visibility = Visibility.Collapsed;
            _skeleton.Visibility = Visibility.Visible;
            _skeleton.StartShimmer();
            _retryBtn.Visibility = Visibility.Collapsed;
            RenderSelected();
        }

        public void UpdateCode(string stepsMarkdown, string? talkingPoint = null)
        {
            if (_versions.Count == 0)
            {
                StartTask(new CodingTaskInfo(Guid.NewGuid(), "Coding Solution", false, false));
            }
            var current = _versions[^1];
            current.Markdown = stepsMarkdown;
            if (!string.IsNullOrWhiteSpace(talkingPoint))
                current.TalkingPoint = talkingPoint;

            if (!string.IsNullOrWhiteSpace(stepsMarkdown))
            {
                _skeleton.StopShimmer();
                _skeleton.Visibility = Visibility.Collapsed;
            }

            _selectedIndex = _versions.Count - 1;
            RenderSelected();
        }

        public void FinishTask(CodingTaskOutcome outcome)
        {
            _isStreaming = false;
            _waitTimer.Stop();
            _skeleton.StopShimmer();
            _skeleton.Visibility = Visibility.Collapsed;

            if (_versions.Count > 0)
            {
                var current = _versions[^1];
                current.IsIncomplete = !outcome.IsComplete;
                current.IncompleteReason = outcome.IncompleteReason;
            }

            _statusLabel.Text = outcome.IsComplete ? "Ready" : "Incomplete";
            RenderSelected();
        }

        public void SelectByTurnId(Guid turnId)
        {
            var idx = _versions.FindIndex(v => v.TurnId == turnId);
            if (idx >= 0) SelectVersion(idx);
        }

        public void Clear()
        {
            _isStreaming = false;
            _waitTimer.Stop();
            _versions.Clear();
            _selectedIndex = -1;
            _filesContainer.Children.Clear();
            _talkStrip.Visibility = Visibility.Collapsed;
            _quickActionsPanel.Visibility = Visibility.Collapsed;
            _retryBtn.Visibility = Visibility.Collapsed;
            _skeleton.StopShimmer();
            _skeleton.Visibility = Visibility.Collapsed;
            _emptyState.Visibility = Visibility.Visible;
            _requestSubtitle.Text = "Live coding assistant";
            _statusLabel.Text = string.Empty;
            UpdateVersionControls();
        }

        private void SelectVersion(int index)
        {
            if (index < 0 || index >= _versions.Count) return;
            _selectedIndex = index;
            RenderSelected();
        }

        private void RenderSelected()
        {
            UpdateVersionControls();
            _filesContainer.Children.Clear();
            if (_selectedIndex < 0 || _selectedIndex >= _versions.Count) return;

            var v = _versions[_selectedIndex];
            _requestSubtitle.Text = string.IsNullOrWhiteSpace(v.Request) ? "Coding Solution" : v.Request;
            _requestSubtitle.ToolTip = v.Request;

            if (!string.IsNullOrWhiteSpace(v.TalkingPoint))
            {
                _talkStripText.Text = v.TalkingPoint;
                _talkStripText.ToolTip = v.TalkingPoint;
                _talkStrip.Visibility = Visibility.Visible;
            }
            else
            {
                _talkStrip.Visibility = Visibility.Collapsed;
            }

            _retryBtn.Visibility = v.IsIncomplete ? Visibility.Visible : Visibility.Collapsed;

            var progress = CodingInterviewStepsHelper.ParseStepsStreaming(v.Markdown);
            var sections = CodeFileSectionsHelper.GroupCodeSteps(progress.Steps);

            if (sections.Count > 0)
            {
                foreach (var sec in sections)
                    _filesContainer.Children.Add(BuildFileCard(sec));
            }
            else if (!string.IsNullOrWhiteSpace(v.Markdown))
            {
                // Fallback for non-STEP raw markdown (e.g. screenshot analysis)
                var rtb = new RichTextBox
                {
                    Document = FlowDocumentMarkdownRenderer.Render(v.Markdown, DesignTokens.FontSizes.Body),
                    Background = Brushes.Transparent,
                    BorderThickness = new Thickness(0),
                    IsReadOnly = true
                };
                _filesContainer.Children.Add(rtb);
            }

            // Rebuild quick-action chips
            _quickActionsPanel.Children.Clear();
            if (v.AllowsChanges && !_isStreaming && !string.IsNullOrWhiteSpace(v.Markdown))
            {
                var currentLang = sections.FirstOrDefault()?.Language;
                var displayLang = CodingInterviewStepsHelper.LanguageDisplayName(currentLang);
                foreach (CodeQuickAction act in Enum.GetValues<CodeQuickAction>())
                {
                    var chip = MakeSmallButton(act.GetTitle(displayLang), () => QuickActionRequested?.Invoke(act.GetInstruction(displayLang)));
                    chip.Margin = new Thickness(0, 0, 8, 6);
                    _quickActionsPanel.Children.Add(chip);
                }
                _quickActionsPanel.Visibility = Visibility.Visible;
            }
            else
            {
                _quickActionsPanel.Visibility = Visibility.Collapsed;
            }
        }

        private UIElement BuildFileCard(CodeFileSection section)
        {
            var card = new Border
            {
                Background = DesignTokens.Brush(DesignTokens.Colors.BgInset),
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(14),
                Margin = new Thickness(0, 0, 0, 12)
            };

            var stack = new StackPanel();
            var header = new DockPanel { Margin = new Thickness(0, 0, 0, 8) };
            var copyBtn = MakeSmallButton("Copy file", () => CopyToClipboard(section.Code));
            DockPanel.SetDock(copyBtn, Dock.Right);
            header.Children.Add(copyBtn);

            header.Children.Add(new TextBlock
            {
                Text = section.FileName,
                FontFamily = DesignTokens.MonoFont,
                FontSize = DesignTokens.FontSizes.Caption,
                FontWeight = FontWeights.SemiBold,
                Foreground = DesignTokens.CodeTextBrush,
                VerticalAlignment = VerticalAlignment.Center
            });
            stack.Children.Add(header);

            foreach (var chunk in section.Chunks)
            {
                if (!string.IsNullOrWhiteSpace(chunk.Why))
                {
                    stack.Children.Add(new TextBlock
                    {
                        Text = $"Step {chunk.Number}: {chunk.Why}",
                        Foreground = DesignTokens.TextMutedBrush,
                        FontSize = DesignTokens.FontSizes.Caption,
                        TextWrapping = TextWrapping.Wrap,
                        Margin = new Thickness(0, 2, 0, 6)
                    });
                }

                if (!string.IsNullOrEmpty(chunk.Code))
                {
                    var codeBox = new Border
                    {
                        Background = DesignTokens.BgCodeBrush,
                        CornerRadius = new CornerRadius(DesignTokens.Radii.Sm),
                        Padding = new Thickness(12, 8, 12, 8),
                        Margin = new Thickness(0, 0, 0, 8)
                    };
                    var tb = new TextBlock
                    {
                        FontFamily = DesignTokens.MonoFont,
                        FontSize = DesignTokens.FontSizes.Code,
                        TextWrapping = TextWrapping.Wrap
                    };
                    FlowDocumentMarkdownRenderer.AppendHighlightedCode(tb.Inlines, chunk.Code);
                    codeBox.Child = tb;
                    stack.Children.Add(codeBox);
                }
            }

            card.Child = stack;
            return card;
        }

        private void UpdateVersionControls()
        {
            var hasMultiple = _versions.Count > 1;
            _prevVersionBtn.Visibility = hasMultiple ? Visibility.Visible : Visibility.Collapsed;
            _nextVersionBtn.Visibility = hasMultiple ? Visibility.Visible : Visibility.Collapsed;
            _versionCounter.Visibility = hasMultiple ? Visibility.Visible : Visibility.Collapsed;
            if (hasMultiple)
            {
                _versionCounter.Text = $"{_selectedIndex + 1} / {_versions.Count}";
                _prevVersionBtn.IsEnabled = _selectedIndex > 0;
                _nextVersionBtn.IsEnabled = _selectedIndex < _versions.Count - 1;
            }
            _copyAllBtn.IsEnabled = _selectedIndex >= 0 && _selectedIndex < _versions.Count && !string.IsNullOrWhiteSpace(_versions[_selectedIndex].Markdown);
        }

        private void CopyCurrentCode()
        {
            if (_selectedIndex < 0 || _selectedIndex >= _versions.Count) return;
            var md = _versions[_selectedIndex].Markdown;
            var progress = CodingInterviewStepsHelper.ParseStepsStreaming(md);
            var text = progress.Steps.Count > 0
                ? string.Join("\n\n", CodeFileSectionsHelper.GroupCodeSteps(progress.Steps).Select(s => s.Code))
                : md;
            CopyToClipboard(text);
        }

        private static void CopyToClipboard(string text)
        {
            try { if (!string.IsNullOrEmpty(text)) Clipboard.SetText(text); } catch { }
        }

        private static Button MakeSmallButton(string label, Action onClick)
        {
            var btn = new Button
            {
                Content = label,
                Padding = new Thickness(10, 4, 10, 4),
                FontSize = DesignTokens.FontSizes.Caption,
                Background = DesignTokens.BgWidgetBrush,
                Foreground = DesignTokens.TextStrongBrush,
                BorderThickness = new Thickness(0),
                Cursor = System.Windows.Input.Cursors.Hand
            };
            btn.Click += (_, _) => onClick();
            return btn;
        }

        public void Dispose() => _waitTimer.Stop();
    }
}
