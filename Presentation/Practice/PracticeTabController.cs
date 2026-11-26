using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using InterviewMasterApp.Domain.Practice;
using InterviewMasterApp.Infrastructure.Practice;
using InterviewMasterApp.Presentation.Styling;

namespace InterviewMasterApp.Presentation.Practice
{
    /// <summary>
    /// Full Practice Mode tab for Windows WPF: supports authored 4-choice card decks
    /// (Claude Architect, AI Engineer Cards, Core ML Cards, TypeScript Cards) and free-response packs,
    /// in both Study (Active Recall) and Full Interview modes, persisted via <see cref="PracticeStore"/>.
    /// </summary>
    public sealed class PracticeTabController
    {
        private readonly Panel _host;
        private readonly PracticeBankFile _bank;
        private readonly PracticeStore _store;

        private ComboBox _rolePicker = null!;
        private ComboBox _modePicker = null!;
        private TextBlock _progressLabel = null!;
        private TextBlock _topicLabel = null!;
        private TextBlock _questionLabel = null!;
        private StackPanel _optionsPanel = null!;
        private TextBox _freeResponseBox = null!;
        private Border _feedbackCard = null!;
        private TextBlock _feedbackText = null!;
        private StackPanel _ratingRow = null!;
        private Button _helpBtn = null!;
        private Button _nextBtn = null!;
        private TextBlock _historySummary = null!;

        private List<PracticeQuestion> _sessionQuestions = new();
        private readonly List<PracticeScoredAnswer> _sessionAnswers = new();
        private string _activePackId = string.Empty;
        private string _activePackTitle = string.Empty;
        private PracticeRunMode _activeMode = PracticeRunMode.Learn;
        private int _currentIndex = -1;
        private DateTime _sessionStartedAt;
        private bool _usedHelpOnCurrent;
        private bool _currentAnswered;

        public PracticeTabController(Panel host, PracticeStore? store = null)
        {
            _host = host ?? throw new ArgumentNullException(nameof(host));
            _store = store ?? PracticeStore.Shared;
            _bank = PracticeBankLoader.Load();
            BuildUi();
            RefreshHistorySummary();
        }

        private void BuildUi()
        {
            _host.Children.Clear();
            var root = new Grid { Margin = new Thickness(16) };
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Controls bar
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // Question card
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // History footer

            // Controls bar
            var bar = new WrapPanel { Margin = new Thickness(0, 0, 0, 14) };

            _rolePicker = new ComboBox { Width = 220, Height = 30, Margin = new Thickness(0, 0, 10, 6) };
            foreach (var role in PracticeRole.All)
                _rolePicker.Items.Add(new ComboBoxItem { Content = role.Title, Tag = role });
            foreach (var pack in _bank.Packs.Where(p => PracticeRole.All.All(r => r.CardPackId != p.Id)))
                _rolePicker.Items.Add(new ComboBoxItem { Content = pack.Title, Tag = pack });
            if (_rolePicker.Items.Count > 0) _rolePicker.SelectedIndex = 0;

            _modePicker = new ComboBox { Width = 160, Height = 30, Margin = new Thickness(0, 0, 10, 6) };
            _modePicker.Items.Add(new ComboBoxItem { Content = "Study (Active Recall)", Tag = PracticeRunMode.Learn });
            _modePicker.Items.Add(new ComboBoxItem { Content = "Full Interview", Tag = PracticeRunMode.Interview });
            _modePicker.SelectedIndex = 0;

            var startBtn = MakeButton("Start Practice", StartNewSession, accent: true);
            startBtn.Margin = new Thickness(0, 0, 10, 6);

            _progressLabel = new TextBlock
            {
                Foreground = DesignTokens.TextMutedBrush,
                FontSize = DesignTokens.FontSizes.Caption,
                VerticalAlignment = VerticalAlignment.Center
            };

            bar.Children.Add(_rolePicker);
            bar.Children.Add(_modePicker);
            bar.Children.Add(startBtn);
            bar.Children.Add(_progressLabel);
            Grid.SetRow(bar, 0);
            root.Children.Add(bar);

            // Card area
            var card = new Border
            {
                Background = DesignTokens.BgCardBrush,
                CornerRadius = new CornerRadius(DesignTokens.Radii.Widget),
                BorderBrush = DesignTokens.BorderWidgetBrush,
                BorderThickness = new Thickness(1),
                Padding = new Thickness(20)
            };

            var scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
            var cardStack = new StackPanel();

            _topicLabel = new TextBlock
            {
                Text = "PRACTICE",
                Foreground = DesignTokens.AccentTextBrush,
                FontSize = DesignTokens.FontSizes.Micro,
                FontWeight = FontWeights.SemiBold,
                Margin = new Thickness(0, 0, 0, 4)
            };

            _questionLabel = new TextBlock
            {
                Text = "Pick a deck or role above and press Start Practice.",
                Foreground = DesignTokens.TextPrimaryBrush,
                FontSize = DesignTokens.FontSizes.Title,
                FontWeight = FontWeights.SemiBold,
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 16)
            };

            _optionsPanel = new StackPanel { Margin = new Thickness(0, 0, 0, 12) };

            _freeResponseBox = new TextBox
            {
                AcceptsReturn = true,
                TextWrapping = TextWrapping.Wrap,
                MinHeight = 90,
                Background = DesignTokens.BgWidgetBrush,
                Foreground = DesignTokens.TextPrimaryBrush,
                CaretBrush = DesignTokens.TextPrimaryBrush,
                BorderBrush = DesignTokens.BorderSubtleBrush,
                Padding = new Thickness(10),
                FontSize = DesignTokens.FontSizes.Body,
                Margin = new Thickness(0, 0, 0, 10),
                Visibility = Visibility.Collapsed
            };

            var actionRow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 4, 0, 10) };
            _helpBtn = MakeButton("Reveal Answer", RevealHelp, accent: false);
            _helpBtn.Margin = new Thickness(0, 0, 8, 0);
            _helpBtn.Visibility = Visibility.Collapsed;

            _nextBtn = MakeButton("Next →", AdvanceQuestion, accent: true);
            _nextBtn.Visibility = Visibility.Collapsed;

            actionRow.Children.Add(_helpBtn);
            actionRow.Children.Add(_nextBtn);

            _ratingRow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 4, 0, 10), Visibility = Visibility.Collapsed };
            _ratingRow.Children.Add(MakeButton("Again (5m)", () => RateFreeResponse(PracticeRecallRating.Again), accent: false));
            var hardBtn = MakeButton("Hard (1d)", () => RateFreeResponse(PracticeRecallRating.Hard), accent: false);
            hardBtn.Margin = new Thickness(8, 0, 8, 0);
            _ratingRow.Children.Add(hardBtn);
            _ratingRow.Children.Add(MakeButton("Got it (3d)", () => RateFreeResponse(PracticeRecallRating.GotIt), accent: true));

            _feedbackCard = new Border
            {
                Background = DesignTokens.BgWidgetBrush,
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(14),
                Margin = new Thickness(0, 6, 0, 8),
                Visibility = Visibility.Collapsed
            };
            _feedbackText = new TextBlock
            {
                Foreground = DesignTokens.TextBodyBrush,
                FontSize = DesignTokens.FontSizes.Body,
                TextWrapping = TextWrapping.Wrap
            };
            _feedbackCard.Child = _feedbackText;

            cardStack.Children.Add(_topicLabel);
            cardStack.Children.Add(_questionLabel);
            cardStack.Children.Add(_optionsPanel);
            cardStack.Children.Add(_freeResponseBox);
            cardStack.Children.Add(actionRow);
            cardStack.Children.Add(_ratingRow);
            cardStack.Children.Add(_feedbackCard);
            scroll.Content = cardStack;
            card.Child = scroll;

            Grid.SetRow(card, 1);
            root.Children.Add(card);

            _historySummary = new TextBlock
            {
                Foreground = DesignTokens.TextMutedBrush,
                FontSize = DesignTokens.FontSizes.Caption,
                Margin = new Thickness(4, 10, 0, 0)
            };
            Grid.SetRow(_historySummary, 2);
            root.Children.Add(_historySummary);

            _host.Children.Add(root);
        }

        private void StartNewSession()
        {
            _activeMode = (_modePicker.SelectedItem as ComboBoxItem)?.Tag is PracticeRunMode m ? m : PracticeRunMode.Learn;
            var tag = (_rolePicker.SelectedItem as ComboBoxItem)?.Tag;

            List<PracticeQuestion> pool;
            if (tag is PracticeRole role)
            {
                _activePackId = role.CardPackId ?? role.Id;
                _activePackTitle = role.Title;
                if (!string.IsNullOrEmpty(role.CardPackId))
                {
                    var cardPack = _bank.Packs.FirstOrDefault(p => p.Id == role.CardPackId);
                    pool = cardPack != null ? PracticeLogic.CurriculumOrdered(cardPack.Questions) : new();
                }
                else
                {
                    var allowed = new HashSet<string>(role.GroupIds, StringComparer.OrdinalIgnoreCase);
                    var matching = _bank.Packs.SelectMany(p => p.Questions).Where(q => allowed.Contains(q.GroupId)).ToList();
                    pool = PracticeLogic.BalancedSelection(matching, 15, q => string.IsNullOrEmpty(q.GroupId) ? q.PackId : q.GroupId);
                }
            }
            else if (tag is PracticeTopicPack pack)
            {
                _activePackId = pack.Id;
                _activePackTitle = pack.Title;
                pool = PracticeLogic.BalancedSelection(pack.Questions, 15, q => string.IsNullOrEmpty(q.GroupId) ? q.PackId : q.GroupId);
            }
            else
            {
                pool = _bank.Packs.SelectMany(p => p.Questions).Take(10).ToList();
            }

            if (pool.Count == 0)
            {
                _questionLabel.Text = "No questions found in this pack.";
                return;
            }

            _sessionQuestions = pool;
            _sessionAnswers.Clear();
            _currentIndex = 0;
            _sessionStartedAt = DateTime.UtcNow;
            RenderCurrentQuestion();
        }

        private void RenderCurrentQuestion()
        {
            if (_currentIndex < 0 || _currentIndex >= _sessionQuestions.Count)
            {
                FinishSession();
                return;
            }

            var q = _sessionQuestions[_currentIndex];
            _usedHelpOnCurrent = false;
            _currentAnswered = false;

            _progressLabel.Text = $"{_activePackTitle} · Question {_currentIndex + 1} of {_sessionQuestions.Count}";
            _topicLabel.Text = (string.IsNullOrEmpty(q.TopicTitle) ? q.GroupId : q.TopicTitle).ToUpperInvariant();
            _questionLabel.Text = PracticeLogic.NormalizeQuestionText(q.Text);
            _optionsPanel.Children.Clear();
            _feedbackCard.Visibility = Visibility.Collapsed;
            _nextBtn.Visibility = Visibility.Collapsed;

            if (q.Card != null && q.Card.IsValid)
            {
                _freeResponseBox.Visibility = Visibility.Collapsed;
                _ratingRow.Visibility = Visibility.Collapsed;
                _helpBtn.Visibility = Visibility.Collapsed;

                foreach (var opt in q.Card.Options)
                {
                    var btn = new Button
                    {
                        HorizontalContentAlignment = HorizontalAlignment.Left,
                        Padding = new Thickness(14, 10, 14, 10),
                        Margin = new Thickness(0, 0, 0, 8),
                        Background = DesignTokens.BgWidgetBrush,
                        Foreground = DesignTokens.TextPrimaryBrush,
                        BorderBrush = DesignTokens.BorderSubtleBrush,
                        BorderThickness = new Thickness(1),
                        Cursor = System.Windows.Input.Cursors.Hand,
                        Tag = opt.Id,
                        Content = new TextBlock { Text = opt.Text, TextWrapping = TextWrapping.Wrap, FontSize = DesignTokens.FontSizes.Body }
                    };
                    btn.Click += (_, _) => OnCardOptionSelected(q, opt.Id, btn);
                    _optionsPanel.Children.Add(btn);
                }
            }
            else
            {
                _freeResponseBox.Text = string.Empty;
                _freeResponseBox.Visibility = Visibility.Visible;
                _helpBtn.Visibility = PracticeLogic.HelpAllowed(_activeMode) ? Visibility.Visible : Visibility.Collapsed;
                _ratingRow.Visibility = Visibility.Visible;
            }
        }

        private void OnCardOptionSelected(PracticeQuestion q, string selectedId, Button clickedBtn)
        {
            if (_currentAnswered || q.Card == null) return;
            _currentAnswered = true;

            var result = PracticeLogic.EvaluateCardChoice(q, selectedId);
            var rawScore = PracticeLogic.ScoreCardChoice(q, selectedId);
            var isCorrect = rawScore >= 1.0;

            foreach (Button b in _optionsPanel.Children.OfType<Button>())
            {
                var id = b.Tag?.ToString();
                if (id == q.Card.CorrectOptionId)
                    b.Background = DesignTokens.SuccessWashBrush;
                else if (id == selectedId && !isCorrect)
                    b.Background = DesignTokens.DangerWashBrush;
                b.IsEnabled = false;
            }

            var chosenOpt = q.Card.Options.FirstOrDefault(o => o.Id == selectedId);
            _feedbackText.Text = $"{(isCorrect ? "Correct!" : "Not quite.")}\n\n{chosenOpt?.Rationale}\n\n{result.Explanation}";
            _feedbackCard.Visibility = Visibility.Visible;
            _nextBtn.Visibility = Visibility.Visible;

            _sessionAnswers.Add(new PracticeScoredAnswer
            {
                QuestionId = q.Id,
                QuestionText = q.Text,
                Answer = chosenOpt?.Text ?? string.Empty,
                RawScore = rawScore,
                FinalScore = rawScore,
                CardResult = result,
                AnsweredAt = DateTime.UtcNow
            });
        }

        private void RevealHelp()
        {
            if (_currentIndex < 0 || _currentIndex >= _sessionQuestions.Count) return;
            var q = _sessionQuestions[_currentIndex];
            _usedHelpOnCurrent = true;
            _feedbackText.Text = PracticeLogic.HelpText(q) ?? "No prepared answer available for this question.";
            _feedbackCard.Visibility = Visibility.Visible;
        }

        private void RateFreeResponse(PracticeRecallRating rating)
        {
            if (_currentIndex < 0 || _currentIndex >= _sessionQuestions.Count) return;
            var q = _sessionQuestions[_currentIndex];
            var raw = rating switch
            {
                PracticeRecallRating.Again => 0.25,
                PracticeRecallRating.Hard => 0.65,
                _ => 1.0
            };
            var scored = PracticeLogic.ApplyHelpPenalty(raw, _usedHelpOnCurrent);

            _sessionAnswers.Add(new PracticeScoredAnswer
            {
                QuestionId = q.Id,
                QuestionText = q.Text,
                Answer = _freeResponseBox.Text.Trim(),
                RawScore = scored.RawScore,
                FinalScore = scored.FinalScore,
                UsedHelp = scored.UsedHelp,
                Mark = scored.Mark,
                RecallRating = rating,
                AnsweredAt = DateTime.UtcNow,
                NextReviewAt = PracticeLogic.NextReviewDate(rating)
            });

            AdvanceQuestion();
        }

        private void AdvanceQuestion()
        {
            _currentIndex++;
            RenderCurrentQuestion();
        }

        private void FinishSession()
        {
            var avg = _sessionAnswers.Count > 0 ? _sessionAnswers.Average(a => a.FinalScore) : 0.0;
            var record = new PracticeRunRecord
            {
                PackId = _activePackId,
                PackTitle = _activePackTitle,
                Mode = _activeMode,
                StartedAt = _sessionStartedAt,
                FinishedAt = DateTime.UtcNow,
                OverallScore = avg,
                Answers = _sessionAnswers.ToList()
            };
            _store.Append(record);
            _store.ClearInProgressSession();

            _topicLabel.Text = "SESSION COMPLETE";
            _questionLabel.Text = $"Score: {avg * 100:0}% ({_sessionAnswers.Count} questions)";
            _optionsPanel.Children.Clear();
            _freeResponseBox.Visibility = Visibility.Collapsed;
            _ratingRow.Visibility = Visibility.Collapsed;
            _helpBtn.Visibility = Visibility.Collapsed;
            _nextBtn.Visibility = Visibility.Collapsed;
            _feedbackCard.Visibility = Visibility.Collapsed;
            RefreshHistorySummary();
        }

        private void RefreshHistorySummary()
        {
            var runs = _store.AllRuns();
            if (runs.Count == 0)
            {
                _historySummary.Text = $"Loaded {_bank.Packs.Count} practice packs ({_bank.Packs.Sum(p => p.Questions.Count)} questions).";
                return;
            }
            var avg = runs.Average(r => r.OverallScore) * 100;
            _historySummary.Text = $"{runs.Count} completed practice runs · Average score: {avg:0}% · {_bank.Packs.Sum(p => p.Questions.Count)} questions in bank";
        }

        private static Button MakeButton(string text, Action onClick, bool accent)
        {
            var btn = new Button
            {
                Content = text,
                Padding = new Thickness(14, 6, 14, 6),
                Background = accent ? DesignTokens.AccentWashBrush : DesignTokens.BgWidgetBrush,
                Foreground = accent ? DesignTokens.AccentTextBrush : DesignTokens.TextStrongBrush,
                BorderThickness = new Thickness(0),
                FontSize = DesignTokens.FontSizes.Caption,
                FontWeight = FontWeights.SemiBold,
                Cursor = System.Windows.Input.Cursors.Hand
            };
            btn.Click += (_, _) => onClick();
            return btn;
        }
    }
}
