using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using System.Windows.Threading;
using InterviewMasterApp.Domain.Entities;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Timeline;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Timeline manager - handles loading indicators, animations, and message management.
    /// Uses WPF StackPanel layout: newest messages are inserted at index 0 (top).
    /// The StackPanel auto-sizes inside the ScrollViewer for proper scrolling.
    /// </summary>
    public class TimelineManager
    {
        private readonly Panel _voiceTimelineContainer;
        private readonly ScrollViewer _voiceTimelineScrollView;
        private readonly List<InterviewMessage> _voiceMessages;
        private readonly List<Screenshot> _screenshots;
        private readonly MessageViewFactory _messageViewFactory;
        private readonly FloatingSolutionWindowController? _floatingController;
        private readonly Action? _showSettingsCallback;

        // UI elements for animations
        private readonly Panel _typingDotsContainer;
        private readonly List<Ellipse> _typingDots = new();
        private readonly List<Rectangle> _waveformBars = new();
        private readonly Image? _statusIconView;
        private readonly Border? _statusIconContainer;
        private readonly Image? _nestIconView;
        private readonly Border? _nestButtonInner;
        private readonly Button? _voiceToggleButton;

        private string? _currentPinnedSolution;
        private readonly List<Storyboard> _activeAnimations = new();

        private const double MessageSpacing = 8;
        private const double MessagePadding = 10;

        // Track the index of the most recently inserted "new topic" so answers go below it
        private int _lastTopicIndex = -1;

        public string? CurrentPinnedSolution => _currentPinnedSolution;

        public TimelineManager(
            Panel voiceTimelineContainer,
            ScrollViewer voiceTimelineScrollView,
            List<InterviewMessage> voiceMessages,
            List<Screenshot> screenshots,
            MessageViewFactory messageViewFactory,
            Panel typingDotsContainer,
            FloatingSolutionWindowController? floatingController = null,
            Image? statusIconView = null,
            Border? statusIconContainer = null,
            Image? nestIconView = null,
            Border? nestButtonInner = null,
            Button? voiceToggleButton = null,
            Action? showSettingsCallback = null)
        {
            _voiceTimelineContainer = voiceTimelineContainer ?? throw new ArgumentNullException(nameof(voiceTimelineContainer));
            _voiceTimelineScrollView = voiceTimelineScrollView ?? throw new ArgumentNullException(nameof(voiceTimelineScrollView));
            _voiceMessages = voiceMessages ?? throw new ArgumentNullException(nameof(voiceMessages));
            _screenshots = screenshots ?? throw new ArgumentNullException(nameof(screenshots));
            _messageViewFactory = messageViewFactory ?? throw new ArgumentNullException(nameof(messageViewFactory));
            _typingDotsContainer = typingDotsContainer ?? throw new ArgumentNullException(nameof(typingDotsContainer));
            _floatingController = floatingController;
            _statusIconView = statusIconView;
            _statusIconContainer = statusIconContainer;
            _nestIconView = nestIconView;
            _nestButtonInner = nestButtonInner;
            _voiceToggleButton = voiceToggleButton;
            _showSettingsCallback = showSettingsCallback;

            // Don't set explicit Height on the StackPanel - let it auto-size for ScrollViewer
            _voiceTimelineContainer.ClearValue(FrameworkElement.HeightProperty);

            InitializeTypingDots();
        }

        /// <summary>
        /// Initialize typing dots for loading animation.
        /// </summary>
        private void InitializeTypingDots()
        {
            for (int i = 0; i < 3; i++)
            {
                var dot = new Ellipse
                {
                    Width = 6,
                    Height = 6,
                    Fill = new SolidColorBrush(Color.FromRgb(0, 122, 255)),
                    Margin = new Thickness(i * 10, 0, 0, 0)
                };
                _typingDots.Add(dot);
                _typingDotsContainer.Children.Add(dot);
            }
            _typingDotsContainer.Visibility = Visibility.Hidden;
        }

        // MARK: - Loading Indicator

        /// <summary>
        /// Show loading indicator with typing dots animation.
        /// </summary>
        public void ShowLoading(string text = "", Color? color = null)
        {
            _voiceTimelineContainer.Dispatcher.BeginInvoke(new Action(() =>
            {
                StartTypingDotsAnimation();
                _floatingController?.ShowLoading();
            }));
        }

        /// <summary>
        /// Hide loading indicator.
        /// </summary>
        public void HideLoading()
        {
            _voiceTimelineContainer.Dispatcher.BeginInvoke(new Action(() =>
            {
                StopTypingDotsAnimation();
                _floatingController?.HideLoading();
            }));
        }

        /// <summary>
        /// Animate waveform bars based on speaking state and dB level.
        /// </summary>
        public void AnimateWaveform(List<Rectangle> bars, Color color, bool isSpeaking, float db)
        {
            const double barMaxHeight = 14;
            const double barMinHeight = 3;
            double[] waveMultipliers = { 0.5, 0.8, 1.0, 0.8, 0.5 };

            var duration = isSpeaking ? TimeSpan.FromMilliseconds(60) : TimeSpan.FromMilliseconds(250);

            for (int index = 0; index < bars.Count; index++)
            {
                var bar = bars[index];
                double targetHeight;
                double alpha;
                var waveMultiplier = index < waveMultipliers.Length ? waveMultipliers[index] : 0.7;

                if (isSpeaking)
                {
                    var normalizedDb = Math.Max(0, Math.Min(1, (db + 60) / 40.0));
                    var random = new Random();
                    var variation = 0.7 + random.NextDouble() * 0.3;
                    var baseHeight = barMinHeight + (barMaxHeight - barMinHeight) * normalizedDb;
                    targetHeight = baseHeight * waveMultiplier * variation;
                    targetHeight = Math.Max(barMinHeight, targetHeight);
                    alpha = 0.6 + normalizedDb * 0.4;
                }
                else
                {
                    targetHeight = barMinHeight + (barMaxHeight - barMinHeight) * 0.2 * waveMultiplier;
                    alpha = 0.35;
                }

                var heightAnimation = new DoubleAnimation(targetHeight, duration)
                {
                    EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
                };
                bar.BeginAnimation(FrameworkElement.HeightProperty, heightAnimation);

                var colorWithAlpha = Color.FromArgb((byte)(alpha * 255), color.R, color.G, color.B);
                var colorAnimation = new ColorAnimation(colorWithAlpha, duration);
                var brushAnim = new SolidColorBrush();
                brushAnim.BeginAnimation(SolidColorBrush.ColorProperty, colorAnimation);
                bar.Fill = brushAnim;
            }
        }

        /// <summary>
        /// Start typing dots animation - iMessage style bounce.
        /// </summary>
        public void StartTypingDotsAnimation()
        {
            _typingDotsContainer.Visibility = Visibility.Visible;

            for (int index = 0; index < _typingDots.Count; index++)
            {
                var dot = _typingDots[index];

                var bounceAnimation = new DoubleAnimationUsingKeyFrames
                {
                    Duration = TimeSpan.FromMilliseconds(500),
                    RepeatBehavior = RepeatBehavior.Forever
                };
                bounceAnimation.KeyFrames.Add(new LinearDoubleKeyFrame(0, KeyTime.FromPercent(0)));
                bounceAnimation.KeyFrames.Add(new EasingDoubleKeyFrame(-6, KeyTime.FromPercent(0.4), new QuadraticEase { EasingMode = EasingMode.EaseOut }));
                bounceAnimation.KeyFrames.Add(new EasingDoubleKeyFrame(0, KeyTime.FromPercent(1.0), new QuadraticEase { EasingMode = EasingMode.EaseIn }));
                bounceAnimation.BeginTime = TimeSpan.FromMilliseconds(index * 150);

                var translateTransform = new TranslateTransform();
                dot.RenderTransform = translateTransform;
                translateTransform.BeginAnimation(TranslateTransform.YProperty, bounceAnimation);

                var opacityAnimation = new DoubleAnimationUsingKeyFrames
                {
                    Duration = TimeSpan.FromMilliseconds(500),
                    RepeatBehavior = RepeatBehavior.Forever
                };
                opacityAnimation.KeyFrames.Add(new LinearDoubleKeyFrame(0.4, KeyTime.FromPercent(0)));
                opacityAnimation.KeyFrames.Add(new LinearDoubleKeyFrame(1.0, KeyTime.FromPercent(0.4)));
                opacityAnimation.KeyFrames.Add(new LinearDoubleKeyFrame(0.4, KeyTime.FromPercent(1.0)));
                opacityAnimation.BeginTime = TimeSpan.FromMilliseconds(index * 150);

                dot.BeginAnimation(UIElement.OpacityProperty, opacityAnimation);
            }
        }

        /// <summary>
        /// Stop typing dots animation.
        /// </summary>
        public void StopTypingDotsAnimation()
        {
            foreach (var dot in _typingDots)
            {
                dot.BeginAnimation(UIElement.OpacityProperty, null);
                if (dot.RenderTransform is TranslateTransform transform)
                {
                    transform.BeginAnimation(TranslateTransform.YProperty, null);
                }
                dot.Opacity = 1.0;
            }
            _typingDotsContainer.Visibility = Visibility.Hidden;
        }

        // MARK: - Toolbar Button Updates

        /// <summary>
        /// Update play/stop button state.
        /// </summary>
        public void UpdateNestButtonState(bool recording)
        {
            if (_nestIconView == null || _nestButtonInner == null || _voiceToggleButton == null)
                return;

            var iconName = recording ? "■" : "▶";
            var accentColor = recording ? Color.FromRgb(255, 59, 48) : Color.FromRgb(52, 199, 89);

            if (_nestIconView.Parent is ContentControl control)
            {
                control.Content = iconName;
            }

            _voiceToggleButton.ToolTip = recording ? "Stop Interview" : "Start Interview";

            var colorAnimation = new ColorAnimation(
                Color.FromArgb((byte)(LayoutConstants.Alpha.ActiveBackground * 255), accentColor.R, accentColor.G, accentColor.B),
                TimeSpan.FromSeconds(LayoutConstants.Animation.Normal))
            {
                EasingFunction = new QuadraticEase()
            };
            var brush = new SolidColorBrush();
            brush.BeginAnimation(SolidColorBrush.ColorProperty, colorAnimation);
            _nestButtonInner.Background = brush;

            UpdateStatusIcon(recording, false);
        }

        /// <summary>
        /// Update status icon based on current state.
        /// </summary>
        public void UpdateStatusIcon(bool listening, bool speaking)
        {
            if (_statusIconView == null || _statusIconContainer == null)
                return;

            string iconName;
            Color bgColor;

            if (speaking)
            {
                iconName = "~";
                bgColor = Color.FromArgb((byte)(0.15 * 255), 255, 204, 0);
            }
            else if (listening)
            {
                iconName = "👂";
                bgColor = Color.FromArgb((byte)(0.15 * 255), 52, 199, 89);
            }
            else
            {
                iconName = "🎤";
                bgColor = Color.FromArgb((byte)(0.08 * 255), 255, 255, 255);
            }

            if (_statusIconView.Parent is ContentControl control)
            {
                control.Content = iconName;
            }

            _statusIconContainer.Background = new SolidColorBrush(bgColor);
        }

        /// <summary>
        /// Clear all messages from timeline.
        /// </summary>
        public void ClearTimeline()
        {
            _voiceMessages.Clear();
            _voiceTimelineContainer.Children.Clear();
            _lastTopicIndex = -1;
        }

        /// <summary>
        /// Prompt for Groq API key.
        /// </summary>
        public void PromptForGroqApiKey(Window owner)
        {
            var result = MessageBox.Show(
                owner,
                "Please configure your Groq API key in Settings to use voice transcription.\n\n" +
                "You can get a key at console.groq.com",
                "Groq API Key Required",
                MessageBoxButton.OKCancel,
                MessageBoxImage.Information);

            if (result == MessageBoxResult.OK)
            {
                _showSettingsCallback?.Invoke();
            }
        }

        // MARK: - Timeline Insertion (StackPanel-based)

        /// <summary>
        /// Insert a view at the top of the timeline (index 0 in the StackPanel).
        /// </summary>
        public void InsertTimelineItemAtTop(FrameworkElement view)
        {
            view.Margin = new Thickness(20, MessagePadding, 20, MessageSpacing);
            _voiceTimelineContainer.Children.Insert(0, view);
            _lastTopicIndex = 0;
            ScrollTimelineToTop();
        }

        /// <summary>
        /// Scroll timeline to show the top (newest) message.
        /// </summary>
        public void ScrollTimelineToTop()
        {
            _voiceTimelineScrollView.ScrollToTop();
        }

        /// <summary>
        /// Add voice message to timeline.
        /// </summary>
        public void AddVoiceMessage(InterviewMessage.MessageType type, string content, string? topic, AudioSource? audioSource = null)
        {
            var message = new InterviewMessage(type, content, topic, audioSource: audioSource);
            _voiceMessages.Add(message);

            var messageView = CreateMessageView(message);
            var isNewTopic = (type == InterviewMessage.MessageType.Question ||
                            type == InterviewMessage.MessageType.Status ||
                            type == InterviewMessage.MessageType.CodingTask ||
                            type == InterviewMessage.MessageType.Screenshot);

            if (isNewTopic)
            {
                InsertTimelineItemAtTop(messageView);
            }
            else
            {
                // Answer/follow-up: insert right after the most recent topic (index 1)
                var insertIndex = Math.Min(_lastTopicIndex + 1, _voiceTimelineContainer.Children.Count);
                messageView.Margin = new Thickness(20, 0, 20, MessageSpacing);
                _voiceTimelineContainer.Children.Insert(insertIndex, messageView);
                ScrollTimelineToTop();
            }

            // Update floating window Q&A if visible
            if (_floatingController?.IsVisible == true &&
                (type == InterviewMessage.MessageType.Question ||
                 type == InterviewMessage.MessageType.Answer ||
                 type == InterviewMessage.MessageType.FollowUp))
            {
                _floatingController.UpdateQA();
            }
        }

        /// <summary>
        /// Update the content of the most recent streaming message (answer being generated).
        /// If no streaming message exists yet, creates one.
        /// </summary>
        public void UpdateStreamingAnswer(string content, string? topic)
        {
            // Find existing streaming answer view (tagged "streaming_answer")
            FrameworkElement? existingView = null;
            int existingIndex = -1;
            for (int i = 0; i < _voiceTimelineContainer.Children.Count; i++)
            {
                if (_voiceTimelineContainer.Children[i] is FrameworkElement fe && fe.Tag?.ToString() == "streaming_answer")
                {
                    existingView = fe;
                    existingIndex = i;
                    break;
                }
            }

            if (existingView != null)
            {
                // Update existing streaming view's text
                if (existingView is Border border && border.Child is TextBlock textBlock)
                {
                    textBlock.Text = content + " ▌";
                }
            }
            else
            {
                // Create a new streaming answer view right after the topic
                var streamView = CreateStreamingAnswerView(content + " ▌");
                var insertIndex = Math.Min(_lastTopicIndex + 1, _voiceTimelineContainer.Children.Count);
                _voiceTimelineContainer.Children.Insert(insertIndex, streamView);
            }

            ScrollTimelineToTop();
        }

        /// <summary>
        /// Finalize streaming: remove the streaming placeholder (the real answer will be added via AddVoiceMessage).
        /// </summary>
        public void FinalizeStreamingAnswer()
        {
            for (int i = _voiceTimelineContainer.Children.Count - 1; i >= 0; i--)
            {
                if (_voiceTimelineContainer.Children[i] is FrameworkElement fe && fe.Tag?.ToString() == "streaming_answer")
                {
                    _voiceTimelineContainer.Children.RemoveAt(i);
                    break;
                }
            }
        }

        /// <summary>
        /// Create a streaming answer view (temporary, replaced when answer completes).
        /// </summary>
        private Border CreateStreamingAnswerView(string content)
        {
            var border = new Border
            {
                Background = new SolidColorBrush(Color.FromArgb(20, 52, 199, 89)),
                CornerRadius = new CornerRadius(8),
                Padding = new Thickness(12),
                Margin = new Thickness(20, 0, 20, MessageSpacing),
                MinHeight = 40,
                Tag = "streaming_answer"
            };

            var textBlock = new TextBlock
            {
                Text = content,
                Foreground = new SolidColorBrush(Color.FromRgb(200, 255, 200)),
                TextWrapping = TextWrapping.Wrap,
                FontSize = 13
            };

            border.Child = textBlock;
            return border;
        }

        /// <summary>
        /// Create a styled message view for the timeline.
        /// </summary>
        private Border CreateMessageView(InterviewMessage message)
        {
            // Choose style based on message type
            Color bgColor;
            Color textColor;
            string prefix = "";

            switch (message.Type)
            {
                case InterviewMessage.MessageType.Question:
                    bgColor = Color.FromArgb(30, 0, 122, 255);    // Blue tint
                    textColor = Color.FromRgb(180, 210, 255);
                    prefix = "Q: ";
                    break;
                case InterviewMessage.MessageType.Answer:
                case InterviewMessage.MessageType.FollowUp:
                    bgColor = Color.FromArgb(20, 52, 199, 89);    // Green tint
                    textColor = Color.FromRgb(200, 255, 200);
                    prefix = "A: ";
                    break;
                case InterviewMessage.MessageType.Status:
                    bgColor = Color.FromArgb(15, 255, 255, 255);  // Subtle
                    textColor = Color.FromArgb(180, 255, 255, 255);
                    break;
                case InterviewMessage.MessageType.CodingTask:
                    bgColor = Color.FromArgb(25, 175, 82, 222);   // Purple tint
                    textColor = Color.FromRgb(220, 200, 255);
                    break;
                default:
                    bgColor = Color.FromArgb(26, 255, 255, 255);
                    textColor = Colors.White;
                    break;
            }

            var border = new Border
            {
                Background = new SolidColorBrush(bgColor),
                CornerRadius = new CornerRadius(8),
                Padding = new Thickness(12),
                Margin = new Thickness(20, 0, 20, MessageSpacing),
                MinHeight = 40
            };

            var stackPanel = new StackPanel();

            // Header with type badge and timestamp
            var headerPanel = new DockPanel { Margin = new Thickness(0, 0, 0, 4) };

            if (message.Type != InterviewMessage.MessageType.Status)
            {
                var typeBadge = new TextBlock
                {
                    Text = prefix.TrimEnd(' ', ':'),
                    Foreground = new SolidColorBrush(textColor),
                    FontSize = 11,
                    FontWeight = FontWeights.Bold,
                    Margin = new Thickness(0, 0, 8, 0)
                };
                headerPanel.Children.Add(typeBadge);
            }

            var timeLabel = new TextBlock
            {
                Text = message.DisplayTime,
                Foreground = new SolidColorBrush(Color.FromArgb(100, 255, 255, 255)),
                FontSize = 10,
                HorizontalAlignment = HorizontalAlignment.Right
            };
            DockPanel.SetDock(timeLabel, Dock.Right);
            headerPanel.Children.Add(timeLabel);

            if (!string.IsNullOrEmpty(message.Topic))
            {
                var topicLabel = new TextBlock
                {
                    Text = message.Topic,
                    Foreground = new SolidColorBrush(Color.FromArgb(120, 255, 255, 255)),
                    FontSize = 10,
                    FontStyle = FontStyles.Italic
                };
                headerPanel.Children.Add(topicLabel);
            }

            stackPanel.Children.Add(headerPanel);

            // Content
            var textBlock = new TextBlock
            {
                Text = message.Content,
                Foreground = new SolidColorBrush(textColor),
                TextWrapping = TextWrapping.Wrap,
                FontSize = 13
            };
            stackPanel.Children.Add(textBlock);

            // Latency badge for answers
            if (message.DisplayLatency != null)
            {
                var latencyLabel = new TextBlock
                {
                    Text = $"⚡ {message.DisplayLatency}",
                    Foreground = new SolidColorBrush(Color.FromArgb(100, 255, 255, 255)),
                    FontSize = 10,
                    Margin = new Thickness(0, 4, 0, 0)
                };
                stackPanel.Children.Add(latencyLabel);
            }

            border.Child = stackPanel;
            border.Tag = $"message_{message.Id}";

            return border;
        }

        /// <summary>
        /// Add user response message (collapsed by default, expandable).
        /// </summary>
        public void AddUserResponseMessage(string content, string? topic)
        {
            var message = new InterviewMessage(InterviewMessage.MessageType.UserResponse, content, topic, audioSource: AudioSource.Microphone)
            {
                IsCollapsed = true
            };
            _voiceMessages.Add(message);

            var messageView = CreateCollapsedUserResponseView(message);
            InsertTimelineItemAtTop(messageView);
        }

        /// <summary>
        /// Create a collapsed user response view (click to expand).
        /// </summary>
        private Border CreateCollapsedUserResponseView(InterviewMessage message)
        {
            const double collapsedHeight = 36;

            var container = new Border
            {
                Height = collapsedHeight,
                Margin = new Thickness(20, 0, 20, MessageSpacing),
                Tag = $"userResponse_{message.Id}"
            };

            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(3) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var line = new Border
            {
                Width = 3,
                Background = new SolidColorBrush(Color.FromRgb(0, 122, 255))
            };
            Grid.SetColumn(line, 0);
            grid.Children.Add(line);

            var timeLabel = new TextBlock
            {
                Text = message.DisplayTime,
                Foreground = new SolidColorBrush(Color.FromArgb(128, 255, 255, 255)),
                FontSize = 11,
                FontWeight = FontWeights.Medium,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(15, 0, 10, 0)
            };
            Grid.SetColumn(timeLabel, 1);
            grid.Children.Add(timeLabel);

            var youSaidLabel = new TextBlock
            {
                Text = "🎤 You said:",
                Foreground = new SolidColorBrush(Color.FromRgb(0, 122, 255)),
                FontSize = 12,
                FontWeight = FontWeights.SemiBold,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 0, 10, 0)
            };
            Grid.SetColumn(youSaidLabel, 2);
            grid.Children.Add(youSaidLabel);

            var preview = message.Content.Length > 40 ? message.Content.Substring(0, 40) + "..." : message.Content;
            var previewLabel = new TextBlock
            {
                Text = preview,
                Foreground = new SolidColorBrush(Color.FromArgb(153, 255, 255, 255)),
                FontSize = 12,
                TextTrimming = TextTrimming.CharacterEllipsis,
                VerticalAlignment = VerticalAlignment.Center
            };
            Grid.SetColumn(previewLabel, 3);
            grid.Children.Add(previewLabel);

            var expandButton = new Button
            {
                Content = "▶",
                Width = 40,
                Height = 24,
                Background = Brushes.Transparent,
                Foreground = new SolidColorBrush(Color.FromRgb(0, 122, 255)),
                BorderThickness = new Thickness(0),
                FontSize = 10,
                VerticalAlignment = VerticalAlignment.Center,
                Tag = message.Id.ToString()
            };
            expandButton.Click += ToggleUserResponseExpand;
            Grid.SetColumn(expandButton, 4);
            grid.Children.Add(expandButton);

            container.Child = grid;
            container.ToolTip = message.Content;

            return container;
        }

        /// <summary>
        /// Toggle user response expand/collapse.
        /// </summary>
        private void ToggleUserResponseExpand(object sender, RoutedEventArgs e)
        {
            if (sender is not Button button || button.Tag is not string messageId)
                return;

            Border? container = null;
            foreach (UIElement child in _voiceTimelineContainer.Children)
            {
                if (child is Border border && border.Tag?.ToString() == $"userResponse_{messageId}")
                {
                    container = border;
                    break;
                }
            }

            if (container == null)
                return;

            var fullContent = container.ToolTip?.ToString() ?? "";
            var isExpanded = container.Height > 50;

            if (isExpanded)
            {
                // Collapse
                button.Content = "▶";

                if (container.Child is Grid grid)
                {
                    var scrollViewer = grid.Children.OfType<ScrollViewer>().FirstOrDefault();
                    if (scrollViewer != null)
                    {
                        grid.Children.Remove(scrollViewer);
                    }
                }

                container.Height = 36;
            }
            else
            {
                // Expand
                var expandedHeight = Math.Max(80, _messageViewFactory.EstimateTextHeight(fullContent, container.ActualWidth - 30) + 45);
                button.Content = "▼";
                container.Height = expandedHeight;

                if (container.Child is Grid grid)
                {
                    var scrollViewer = new ScrollViewer
                    {
                        VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                        HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
                        MaxHeight = expandedHeight - 40,
                        Margin = new Thickness(15, 35, 15, 5)
                    };

                    var contentText = new TextBlock
                    {
                        Text = fullContent,
                        Foreground = new SolidColorBrush(Color.FromArgb(204, 255, 255, 255)),
                        FontSize = 12,
                        TextWrapping = TextWrapping.Wrap
                    };

                    scrollViewer.Content = contentText;
                    Grid.SetColumnSpan(scrollViewer, 5);
                    grid.Children.Add(scrollViewer);
                }
            }
            // StackPanel auto-adjusts layout - no manual recalculation needed
        }

        /// <summary>
        /// Add screenshot thumbnail to the voice timeline (gallery style).
        /// </summary>
        public void AddScreenshotToTimeline(byte[] thumbnailData, Guid screenshotId)
        {
            var message = new InterviewMessage(InterviewMessage.MessageType.Screenshot, "Screenshot", null, screenshotId: screenshotId);
            _voiceMessages.Add(message);

            Border? existingGallery = null;
            foreach (UIElement child in _voiceTimelineContainer.Children)
            {
                if (child is Border border && border.Tag?.ToString() == "screenshotGallery")
                {
                    existingGallery = border;
                    break;
                }
            }

            if (existingGallery != null)
            {
                StealthLogger.Shared.Log("Adding to existing screenshot gallery");
            }
            else
            {
                var gallery = CreateScreenshotGallery(thumbnailData, screenshotId, 80, 50);
                InsertTimelineItemAtTop(gallery);
            }
        }

        /// <summary>
        /// Create screenshot gallery container.
        /// </summary>
        private Border CreateScreenshotGallery(byte[] thumbnailData, Guid screenshotId, double thumbWidth, double thumbHeight)
        {
            var container = new Border
            {
                MinHeight = 80,
                Tag = "screenshotGallery",
                Margin = new Thickness(20, MessagePadding, 20, MessageSpacing)
            };

            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(30) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var badge = new Border
            {
                Width = 22,
                Height = 22,
                CornerRadius = new CornerRadius(11),
                Background = new SolidColorBrush(Color.FromArgb(38, 175, 82, 222)),
                VerticalAlignment = VerticalAlignment.Top,
                Margin = new Thickness(0, 4, 8, 0)
            };

            var badgeText = new TextBlock
            {
                Text = "S",
                Foreground = new SolidColorBrush(Color.FromRgb(175, 82, 222)),
                FontSize = 11,
                FontWeight = FontWeights.Bold,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };

            badge.Child = badgeText;
            Grid.SetColumn(badge, 0);
            grid.Children.Add(badge);

            var card = new Border
            {
                Background = new SolidColorBrush(Color.FromArgb(15, 175, 82, 222)),
                CornerRadius = new CornerRadius(12)
            };
            Grid.SetColumn(card, 1);
            grid.Children.Add(card);

            var cardContent = new TextBlock
            {
                Text = "📸 Screenshot Gallery",
                Foreground = Brushes.White,
                Margin = new Thickness(15),
                FontSize = 12
            };
            card.Child = cardContent;

            container.Child = grid;

            return container;
        }

        /// <summary>
        /// Pin a coding task solution in the timeline.
        /// </summary>
        public void SetPinnedSolution(string solution)
        {
            _currentPinnedSolution = solution;

            // Remove existing coding task
            for (int i = _voiceTimelineContainer.Children.Count - 1; i >= 0; i--)
            {
                if (_voiceTimelineContainer.Children[i] is FrameworkElement element && element.Tag?.ToString() == "codingTask")
                {
                    _voiceTimelineContainer.Children.RemoveAt(i);
                    break;
                }
            }

            // Add coding task at top
            var message = new InterviewMessage(InterviewMessage.MessageType.CodingTask, solution, "solution");
            var messageView = CreateMessageView(message);
            messageView.Tag = "codingTask";

            InsertTimelineItemAtTop(messageView);
        }

        /// <summary>
        /// Clear the pinned solution from timeline.
        /// </summary>
        public void ClearPinnedSolution()
        {
            _currentPinnedSolution = null;

            for (int i = _voiceTimelineContainer.Children.Count - 1; i >= 0; i--)
            {
                if (_voiceTimelineContainer.Children[i] is FrameworkElement element && element.Tag?.ToString() == "codingTask")
                {
                    _voiceTimelineContainer.Children.RemoveAt(i);
                    break;
                }
            }
        }
    }
}
