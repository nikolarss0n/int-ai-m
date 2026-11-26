using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Components;
using InterviewMasterApp.Presentation.Styling;

namespace InterviewMasterApp.Presentation
{
    public enum TurnPhase
    {
        Queued,
        Generating,
        Answering,
        Ready,
        Failed
    }

    public sealed class FocusTurnItem
    {
        public Guid TurnId { get; init; }
        public int Sequence { get; init; }
        public string Question { get; set; } = string.Empty;
        public string Topic { get; set; } = "unknown";
        public string Answer { get; set; } = string.Empty;
        public TurnPhase Phase { get; set; } = TurnPhase.Generating;
        public DateTime StartedAt { get; init; } = DateTime.UtcNow;
        public int? LatencyMs { get; set; }
        public bool HasCode { get; set; }
    }

    /// <summary>
    /// Focus Live-Interview surface:
    /// - Primary Answer Card (topic overline, 17pt question title, rich FlowDocument Markdown bullets,
    ///   SkeletonView + WaitProgress timer, Copy, Retry, Open Code buttons)
    /// - Question Burst strip (selectable turns with phase pills & Calendar-style leading accent bar)
    /// - CV Briefing strip (digest + matching resume talking points)
    /// </summary>
    public sealed class InterviewFocusController : IDisposable
    {
        private readonly Grid _root;
        private readonly List<FocusTurnItem> _turns = new();
        private Guid? _selectedTurnId;
        private readonly DispatcherTimer _waitTimer;

        // Answer Card controls
        private readonly TextBlock _topicOverline;
        private readonly TextBlock _cardStatus;
        private readonly TextBlock _questionTitle;
        private readonly Button _copyAnswerBtn;
        private readonly Button _retryAnswerBtn;
        private readonly Button _openCodeBtn;
        private readonly SkeletonView _skeleton;
        private readonly RichTextBox _answerBody;

        // Question Burst strip
        private readonly Border _burstCard;
        private readonly StackPanel _burstRows;

        // CV Briefing strip
        private readonly Border _briefingCard;
        private readonly TextBlock _briefingDigest;
        private readonly StackPanel _briefingPoints;

        public UIElement View => _root;
        public event Action<FocusTurnItem>? RetryRequested;
        public event Action<Guid>? OpenCodeRequested;
        public event Action<string>? CopiedNoticeRequested;

        public InterviewFocusController()
        {
            _root = new Grid { Margin = new Thickness(16, 8, 16, 8) };
            _root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star), MinHeight = 180 }); // Answer card
            _root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Question burst
            _root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // CV Briefing

            // 1. Primary Answer Card
            var answerCard = new Border
            {
                Background = DesignTokens.BgCardBrush,
                CornerRadius = new CornerRadius(DesignTokens.Radii.Widget),
                BorderBrush = DesignTokens.BorderWidgetBrush,
                BorderThickness = new Thickness(1),
                Padding = new Thickness(18)
            };

            var cardGrid = new Grid();
            cardGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Overline + status + actions
            cardGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Question title
            cardGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // Answer body / skeleton

            var topBar = new DockPanel { Margin = new Thickness(0, 0, 0, 6) };
            var actions = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
            _cardStatus = new TextBlock
            {
                Foreground = DesignTokens.TextMutedBrush,
                FontSize = DesignTokens.FontSizes.Caption,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 0, 10, 0)
            };
            _openCodeBtn = SmallAction("View code", () =>
            {
                if (_selectedTurnId.HasValue) OpenCodeRequested?.Invoke(_selectedTurnId.Value);
            });
            _openCodeBtn.Background = DesignTokens.CodeWashBrush;
            _openCodeBtn.Foreground = DesignTokens.CodeTextBrush;
            _openCodeBtn.Margin = new Thickness(0, 0, 6, 0);
            _openCodeBtn.Visibility = Visibility.Collapsed;

            _retryAnswerBtn = SmallAction("Try again", () =>
            {
                var t = SelectedTurn();
                if (t != null) RetryRequested?.Invoke(t);
            });
            _retryAnswerBtn.Background = DesignTokens.WarningWashBrush;
            _retryAnswerBtn.Foreground = DesignTokens.WarningTextBrush;
            _retryAnswerBtn.Margin = new Thickness(0, 0, 6, 0);
            _retryAnswerBtn.Visibility = Visibility.Collapsed;

            _copyAnswerBtn = SmallAction("Copy", CopySelectedAnswer);
            _copyAnswerBtn.Visibility = Visibility.Collapsed;

            actions.Children.Add(_cardStatus);
            actions.Children.Add(_openCodeBtn);
            actions.Children.Add(_retryAnswerBtn);
            actions.Children.Add(_copyAnswerBtn);
            DockPanel.SetDock(actions, Dock.Right);
            topBar.Children.Add(actions);

            _topicOverline = new TextBlock
            {
                Text = "LIVE ANSWER",
                Foreground = DesignTokens.AccentTextBrush,
                FontSize = DesignTokens.FontSizes.Micro,
                FontWeight = FontWeights.SemiBold,
                VerticalAlignment = VerticalAlignment.Center
            };
            topBar.Children.Add(_topicOverline);
            Grid.SetRow(topBar, 0);
            cardGrid.Children.Add(topBar);

            _questionTitle = new TextBlock
            {
                Text = "Start an interview to get real-time cue-card answers.",
                Foreground = DesignTokens.TextPrimaryBrush,
                FontSize = DesignTokens.FontSizes.Title,
                FontWeight = FontWeights.SemiBold,
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 12)
            };
            Grid.SetRow(_questionTitle, 1);
            cardGrid.Children.Add(_questionTitle);

            var bodyHost = new Grid();
            _skeleton = new SkeletonView(codeShape: false) { Visibility = Visibility.Collapsed };
            _answerBody = new RichTextBox
            {
                Background = Brushes.Transparent,
                Foreground = DesignTokens.TextBodyBrush,
                BorderThickness = new Thickness(0),
                IsReadOnly = true,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
            };
            bodyHost.Children.Add(_skeleton);
            bodyHost.Children.Add(_answerBody);
            Grid.SetRow(bodyHost, 2);
            cardGrid.Children.Add(bodyHost);

            answerCard.Child = cardGrid;
            Grid.SetRow(answerCard, 0);
            _root.Children.Add(answerCard);

            // 2. Question Burst strip (hidden until first question)
            _burstCard = new Border
            {
                Background = DesignTokens.BgWidgetBrush,
                CornerRadius = new CornerRadius(DesignTokens.Radii.Widget),
                BorderBrush = DesignTokens.BorderWidgetBrush,
                BorderThickness = new Thickness(1),
                Padding = new Thickness(12, 10, 12, 10),
                Margin = new Thickness(0, 12, 0, 0),
                Visibility = Visibility.Collapsed,
                MaxHeight = 165
            };
            var burstScroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
            _burstRows = new StackPanel();
            burstScroll.Content = _burstRows;
            _burstCard.Child = burstScroll;
            Grid.SetRow(_burstCard, 1);
            _root.Children.Add(_burstCard);

            // 3. CV Briefing strip (hidden until matching thread arrives)
            _briefingCard = new Border
            {
                Background = DesignTokens.BgWidgetBrush,
                CornerRadius = new CornerRadius(DesignTokens.Radii.Widget),
                BorderBrush = DesignTokens.BorderWidgetBrush,
                BorderThickness = new Thickness(1),
                Padding = new Thickness(14, 10, 14, 10),
                Margin = new Thickness(0, 12, 0, 0),
                Visibility = Visibility.Collapsed
            };
            var briefStack = new StackPanel();
            briefStack.Children.Add(new TextBlock
            {
                Text = "RESUME BRIEFING",
                Foreground = DesignTokens.CodeTextBrush,
                FontSize = DesignTokens.FontSizes.Micro,
                FontWeight = FontWeights.SemiBold,
                Margin = new Thickness(0, 0, 0, 4)
            });
            _briefingDigest = new TextBlock
            {
                Foreground = DesignTokens.TextStrongBrush,
                FontSize = DesignTokens.FontSizes.Body,
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 4)
            };
            _briefingPoints = new StackPanel();
            briefStack.Children.Add(_briefingDigest);
            briefStack.Children.Add(_briefingPoints);
            _briefingCard.Child = briefStack;
            Grid.SetRow(_briefingCard, 2);
            _root.Children.Add(_briefingCard);

            _waitTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _waitTimer.Tick += (_, _) => UpdateWaitClock();
            _waitTimer.Start();
        }

        public void AddQuestion(Guid turnId, int sequence, string question, string topic)
        {
            var existing = _turns.FirstOrDefault(t => t.TurnId == turnId);
            if (existing != null)
            {
                existing.Question = question;
                existing.Topic = topic;
            }
            else
            {
                _turns.Insert(0, new FocusTurnItem
                {
                    TurnId = turnId,
                    Sequence = sequence,
                    Question = question,
                    Topic = topic,
                    Phase = TurnPhase.Generating,
                    StartedAt = DateTime.UtcNow
                });
                if (_turns.Count > 25) _turns.RemoveAt(_turns.Count - 1);
            }

            _selectedTurnId = turnId;
            RenderAll();
        }

        public void UpdateAnswerChunk(Guid turnId, string fullAnswer)
        {
            var turn = _turns.FirstOrDefault(t => t.TurnId == turnId);
            if (turn == null) return;
            turn.Answer = fullAnswer;
            if (!string.IsNullOrWhiteSpace(fullAnswer) && turn.Phase == TurnPhase.Generating)
                turn.Phase = TurnPhase.Answering;
            RenderAll();
        }

        public void FinishAnswer(Guid turnId, string fullAnswer, int? totalLatencyMs)
        {
            var turn = _turns.FirstOrDefault(t => t.TurnId == turnId);
            if (turn == null) return;
            turn.Answer = fullAnswer;
            turn.LatencyMs = totalLatencyMs;
            turn.Phase = fullAnswer.StartsWith("Error:", StringComparison.OrdinalIgnoreCase)
                ? TurnPhase.Failed
                : TurnPhase.Ready;
            RenderAll();
        }

        public void MarkTurnHasCode(Guid turnId)
        {
            var turn = _turns.FirstOrDefault(t => t.TurnId == turnId);
            if (turn != null)
            {
                turn.HasCode = true;
                RenderAll();
            }
        }

        public void UpdateBriefing(InterviewBriefing briefing)
        {
            _briefingDigest.Text = briefing.Digest;
            _briefingPoints.Children.Clear();
            foreach (var p in briefing.TalkingPoints)
            {
                _briefingPoints.Children.Add(new TextBlock
                {
                    Text = $"• [CV] {p}",
                    Foreground = DesignTokens.TextMutedBrush,
                    FontSize = DesignTokens.FontSizes.Caption,
                    TextWrapping = TextWrapping.Wrap,
                    Margin = new Thickness(0, 2, 0, 0)
                });
            }
            _briefingCard.Visibility = Visibility.Visible;
        }

        public void Clear()
        {
            _turns.Clear();
            _selectedTurnId = null;
            _burstRows.Children.Clear();
            _burstCard.Visibility = Visibility.Collapsed;
            _briefingCard.Visibility = Visibility.Collapsed;
            _topicOverline.Text = "LIVE ANSWER";
            _questionTitle.Text = "Start an interview to get real-time cue-card answers.";
            _cardStatus.Text = string.Empty;
            _answerBody.Document = new System.Windows.Documents.FlowDocument();
            _skeleton.StopShimmer();
            _skeleton.Visibility = Visibility.Collapsed;
            _copyAnswerBtn.Visibility = Visibility.Collapsed;
            _retryAnswerBtn.Visibility = Visibility.Collapsed;
            _openCodeBtn.Visibility = Visibility.Collapsed;
        }

        private FocusTurnItem? SelectedTurn() =>
            _turns.FirstOrDefault(t => t.TurnId == _selectedTurnId) ?? _turns.FirstOrDefault();

        private void RenderAll()
        {
            RenderSelectedCard();
            RenderBurstStrip();
        }

        private void RenderSelectedCard()
        {
            var turn = SelectedTurn();
            if (turn == null) return;

            _topicOverline.Text = TopicTitle.Display(turn.Topic).ToUpperInvariant();
            _questionTitle.Text = turn.Question;
            _questionTitle.ToolTip = turn.Question;

            _openCodeBtn.Visibility = turn.HasCode ? Visibility.Visible : Visibility.Collapsed;
            _retryAnswerBtn.Visibility = turn.Phase == TurnPhase.Failed ? Visibility.Visible : Visibility.Collapsed;
            _copyAnswerBtn.Visibility = !string.IsNullOrWhiteSpace(turn.Answer) && turn.Phase != TurnPhase.Failed
                ? Visibility.Visible
                : Visibility.Collapsed;

            if (turn.Phase == TurnPhase.Generating && string.IsNullOrWhiteSpace(turn.Answer))
            {
                _skeleton.Visibility = Visibility.Visible;
                _skeleton.StartShimmer();
                _answerBody.Visibility = Visibility.Collapsed;
            }
            else
            {
                _skeleton.StopShimmer();
                _skeleton.Visibility = Visibility.Collapsed;
                _answerBody.Visibility = Visibility.Visible;
                var display = turn.Phase == TurnPhase.Failed
                    ? FeedbackCopy.FailureReason(turn.Answer)
                    : turn.Answer;
                _answerBody.Document = FlowDocumentMarkdownRenderer.Render(display, DesignTokens.FontSizes.Lead);
            }

            UpdateWaitClock();
        }

        private void UpdateWaitClock()
        {
            var turn = SelectedTurn();
            if (turn == null) { _cardStatus.Text = string.Empty; return; }
            var elapsed = (DateTime.UtcNow - turn.StartedAt).TotalSeconds;
            _cardStatus.Text = turn.Phase switch
            {
                TurnPhase.Queued => WaitProgress.AnswerStatus(queued: true, elapsed),
                TurnPhase.Generating => WaitProgress.AnswerStatus(queued: false, elapsed),
                TurnPhase.Answering => "Answering",
                TurnPhase.Ready => turn.LatencyMs.HasValue
                    ? $"Ready · {InterviewMessage.FormatLatency(turn.LatencyMs.Value)}"
                    : "Ready",
                TurnPhase.Failed => "Failed",
                _ => string.Empty
            };
        }

        private void RenderBurstStrip()
        {
            _burstRows.Children.Clear();
            if (_turns.Count == 0)
            {
                _burstCard.Visibility = Visibility.Collapsed;
                return;
            }

            _burstCard.Visibility = Visibility.Visible;
            foreach (var turn in _turns.Take(6))
            {
                var isSelected = turn.TurnId == _selectedTurnId;
                var row = new Border
                {
                    CornerRadius = new CornerRadius(10),
                    Background = isSelected ? DesignTokens.AccentWashBrush : Brushes.Transparent,
                    Padding = new Thickness(6, 5, 10, 5),
                    Margin = new Thickness(0, 1, 0, 1),
                    Cursor = System.Windows.Input.Cursors.Hand
                };
                row.MouseLeftButtonUp += (_, _) =>
                {
                    _selectedTurnId = turn.TurnId;
                    RenderAll();
                    if (turn.HasCode) OpenCodeRequested?.Invoke(turn.TurnId);
                };

                var grid = new Grid();
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(6) });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                // Calendar-style leading accent bar on selected turn
                var bar = new Border
                {
                    Width = 3,
                    Height = 18,
                    CornerRadius = new CornerRadius(1.5),
                    Background = isSelected ? DesignTokens.AccentTextBrush : Brushes.Transparent,
                    VerticalAlignment = VerticalAlignment.Center
                };
                Grid.SetColumn(bar, 0);
                grid.Children.Add(bar);

                var qText = new TextBlock
                {
                    Text = turn.Question,
                    ToolTip = turn.Question,
                    Foreground = isSelected ? DesignTokens.TextPrimaryBrush : DesignTokens.TextBodyBrush,
                    FontSize = DesignTokens.FontSizes.Caption,
                    FontWeight = isSelected ? FontWeights.SemiBold : FontWeights.Normal,
                    TextTrimming = TextTrimming.CharacterEllipsis,
                    VerticalAlignment = VerticalAlignment.Center,
                    Margin = new Thickness(6, 0, 10, 0)
                };
                Grid.SetColumn(qText, 1);
                grid.Children.Add(qText);

                var (pillText, pillBg, pillFg) = turn.Phase switch
                {
                    TurnPhase.Generating => ("Generating", DesignTokens.WarningWashBrush, DesignTokens.WarningTextBrush),
                    TurnPhase.Answering => ("Answering", DesignTokens.AccentWashBrush, DesignTokens.AccentTextBrush),
                    TurnPhase.Failed => ("Failed", DesignTokens.DangerWashBrush, DesignTokens.DangerTextBrush),
                    TurnPhase.Queued => ("Queued", DesignTokens.BgWidgetBrush, DesignTokens.TextMutedBrush),
                    _ => (turn.HasCode ? "Code" : "Ready", turn.HasCode ? DesignTokens.CodeWashBrush : DesignTokens.SuccessWashBrush, turn.HasCode ? DesignTokens.CodeTextBrush : DesignTokens.SuccessTextBrush)
                };

                var pill = new Border
                {
                    Background = pillBg,
                    CornerRadius = new CornerRadius(8),
                    Padding = new Thickness(8, 2, 8, 2),
                    VerticalAlignment = VerticalAlignment.Center,
                    Child = new TextBlock { Text = pillText, Foreground = pillFg, FontSize = 11, FontWeight = FontWeights.Medium }
                };
                Grid.SetColumn(pill, 2);
                grid.Children.Add(pill);

                row.Child = grid;
                _burstRows.Children.Add(row);
            }
        }

        private void CopySelectedAnswer()
        {
            var turn = SelectedTurn();
            if (turn == null || string.IsNullOrWhiteSpace(turn.Answer)) return;
            try
            {
                Clipboard.SetText(turn.Answer);
                CopiedNoticeRequested?.Invoke("Answer copied");
            }
            catch { }
        }

        private static Button SmallAction(string text, Action onClick)
        {
            var b = new Button
            {
                Content = text,
                Padding = new Thickness(10, 4, 10, 4),
                FontSize = DesignTokens.FontSizes.Caption,
                Background = DesignTokens.BgWidgetBrush,
                Foreground = DesignTokens.TextStrongBrush,
                BorderThickness = new Thickness(0),
                Cursor = System.Windows.Input.Cursors.Hand
            };
            b.Click += (_, _) => onClick();
            return b;
        }

        public void Dispose() => _waitTimer.Stop();
    }
}
