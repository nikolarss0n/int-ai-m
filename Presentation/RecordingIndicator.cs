using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using System.Windows.Threading;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Recording indicator - animated pill with pulsing dot and elapsed time.
    /// Ported from Swift: RecordingIndicator.swift
    /// Shows visual feedback during audio recording with smooth animations.
    /// </summary>
    public class RecordingIndicator
    {
        private readonly Border _recordingPill;
        private readonly Ellipse _recordingDot;
        private readonly TextBlock _recordingTimeLabel;
        private readonly Panel _parentContainer;

        private DateTime? _recordingStartTime;
        private DispatcherTimer? _recordingTimer;
        private Storyboard? _pulseStoryboard;

        private const double CollapsedWidth = 28;
        private const double CollapsedHeight = 28;
        private const double ExpandedWidth = 80;
        private const double ExpandedHeight = 28;
        private const double CornerRadius = 14;

        public RecordingIndicator(Panel parentContainer)
        {
            _parentContainer = parentContainer ?? throw new ArgumentNullException(nameof(parentContainer));

            // Create recording pill container
            _recordingPill = new Border
            {
                Width = CollapsedWidth,
                Height = CollapsedHeight,
                CornerRadius = new CornerRadius(CornerRadius),
                Background = new SolidColorBrush(Color.FromArgb(230, 220, 38, 38)), // Red background
                HorizontalAlignment = HorizontalAlignment.Left,
                VerticalAlignment = VerticalAlignment.Top,
                Margin = new Thickness(10, 10, 0, 0),
                Opacity = 0,
                Visibility = Visibility.Hidden
            };

            // Create grid for layout
            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(28) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            // Create recording dot (pulsing red dot)
            _recordingDot = new Ellipse
            {
                Width = 8,
                Height = 8,
                Fill = Brushes.White,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
            Grid.SetColumn(_recordingDot, 0);
            grid.Children.Add(_recordingDot);

            // Create time label
            _recordingTimeLabel = new TextBlock
            {
                Text = "00:00",
                Foreground = Brushes.White,
                FontSize = 12,
                FontWeight = FontWeights.Medium,
                VerticalAlignment = VerticalAlignment.Center,
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(4, 0, 8, 0),
                Opacity = 0
            };
            Grid.SetColumn(_recordingTimeLabel, 1);
            grid.Children.Add(_recordingTimeLabel);

            _recordingPill.Child = grid;
            _parentContainer.Children.Add(_recordingPill);
        }

        /// <summary>
        /// Show recording indicator with animations.
        /// </summary>
        public void ShowRecordingIndicator()
        {
            _recordingStartTime = DateTime.Now;
            _recordingPill.Visibility = Visibility.Visible;

            // Check if animations should be reduced (accessibility)
            var shouldAnimate = !SystemParameters.MinimizeAnimation; // Best-effort check for reduced motion

            // Reset to collapsed state
            _recordingPill.Width = CollapsedWidth;
            _recordingPill.Height = CollapsedHeight;

            // Fade in
            var fadeInDuration = shouldAnimate ? TimeSpan.FromSeconds(0.12) : TimeSpan.Zero;
            var fadeIn = new DoubleAnimation(0, 1.0, fadeInDuration)
            {
                EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
            };
            _recordingPill.BeginAnimation(UIElement.OpacityProperty, fadeIn);

            // Expand after fade in
            if (shouldAnimate)
            {
                var expandTimer = new DispatcherTimer
                {
                    Interval = TimeSpan.FromMilliseconds(150)
                };
                expandTimer.Tick += (s, e) =>
                {
                    (s as DispatcherTimer)?.Stop();
                    ExpandRecordingPill();
                };
                expandTimer.Start();
            }
            else
            {
                ExpandRecordingPill();
            }

            // Start pulsing animation on dot
            if (shouldAnimate)
            {
                StartPulseAnimation();
            }

            // Start timer to update elapsed time
            _recordingTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(1.0)
            };
            _recordingTimer.Tick += (s, e) => UpdateRecordingTime();
            _recordingTimer.Start();

            StealthLogger.Shared.Log("🔴 Recording indicator shown");
        }

        /// <summary>
        /// Expand the recording pill to show time.
        /// </summary>
        private void ExpandRecordingPill()
        {
            var expandDuration = TimeSpan.FromSeconds(0.15);

            // Animate width
            var widthAnimation = new DoubleAnimation(CollapsedWidth, ExpandedWidth, expandDuration)
            {
                EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
            };
            _recordingPill.BeginAnimation(Border.WidthProperty, widthAnimation);

            // Fade in time label
            var fadeInLabel = new DoubleAnimation(0, 1.0, expandDuration)
            {
                EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
            };
            _recordingTimeLabel.BeginAnimation(UIElement.OpacityProperty, fadeInLabel);
        }

        /// <summary>
        /// Update recording time label.
        /// </summary>
        private void UpdateRecordingTime()
        {
            if (_recordingStartTime == null)
                return;

            var elapsed = (int)(DateTime.Now - _recordingStartTime.Value).TotalSeconds;
            var minutes = elapsed / 60;
            var seconds = elapsed % 60;
            _recordingTimeLabel.Text = string.Format("{0:D2}:{1:D2}", minutes, seconds);
        }

        /// <summary>
        /// Start pulsing animation on the recording dot.
        /// </summary>
        private void StartPulseAnimation()
        {
            var pulseAnimation = new DoubleAnimation
            {
                From = 1.0,
                To = 0.4,
                Duration = TimeSpan.FromSeconds(LayoutConstants.Animation.Pulse),
                AutoReverse = true,
                RepeatBehavior = RepeatBehavior.Forever
            };

            _pulseStoryboard = new Storyboard();
            _pulseStoryboard.Children.Add(pulseAnimation);
            Storyboard.SetTarget(pulseAnimation, _recordingDot);
            Storyboard.SetTargetProperty(pulseAnimation, new PropertyPath(UIElement.OpacityProperty));
            _pulseStoryboard.Begin();
        }

        /// <summary>
        /// Stop pulsing animation.
        /// </summary>
        private void StopPulseAnimation()
        {
            _pulseStoryboard?.Stop();
            _pulseStoryboard = null;

            // Reset dot opacity
            _recordingDot.Opacity = 1.0;
        }

        /// <summary>
        /// Hide recording indicator with animations.
        /// </summary>
        public void HideRecordingIndicator()
        {
            // Stop timer
            _recordingTimer?.Stop();
            _recordingTimer = null;

            // Stop pulse animation
            StopPulseAnimation();

            // Collapse pill first (fade out label and shrink)
            var collapseDuration = TimeSpan.FromSeconds(0.1);

            // Fade out time label
            var fadeOutLabel = new DoubleAnimation(1.0, 0, collapseDuration);
            _recordingTimeLabel.BeginAnimation(UIElement.OpacityProperty, fadeOutLabel);

            // Animate width back to collapsed
            var shrinkAnimation = new DoubleAnimation(ExpandedWidth, CollapsedWidth, collapseDuration);
            shrinkAnimation.Completed += (s, e) =>
            {
                // Then fade out the entire pill
                var fadeOutDuration = TimeSpan.FromSeconds(0.1);
                var fadeOut = new DoubleAnimation(1.0, 0, fadeOutDuration);
                fadeOut.Completed += (s2, e2) =>
                {
                    _recordingPill.Visibility = Visibility.Hidden;
                    StealthLogger.Shared.Log("⚪ Recording indicator hidden");
                };
                _recordingPill.BeginAnimation(UIElement.OpacityProperty, fadeOut);
            };
            _recordingPill.BeginAnimation(Border.WidthProperty, shrinkAnimation);
        }

        /// <summary>
        /// Cleanup resources.
        /// </summary>
        public void Dispose()
        {
            _recordingTimer?.Stop();
            _recordingTimer = null;
            StopPulseAnimation();
        }
    }
}

