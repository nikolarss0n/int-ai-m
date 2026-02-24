using System;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Screenshot capture indicator - shows visual feedback during screen capture.
    /// Ported from Swift: screenshot-indicator-fix.swift
    /// Displays a red "🔴 Capturing Screen" indicator with pulse animation.
    /// </summary>
    public class ScreenshotCaptureIndicator
    {
        private readonly Border _indicator;
        private readonly Panel _parentContainer;
        private readonly DoubleAnimation _pulseAnimation;
        private readonly DoubleAnimation _fadeOutAnimation;

        /// <summary>
        /// Create a screenshot capture indicator.
        /// </summary>
        /// <param name="parentContainer">The container to add the indicator to (e.g., CodingPanel)</param>
        public ScreenshotCaptureIndicator(Panel parentContainer)
        {
            _parentContainer = parentContainer ?? throw new ArgumentNullException(nameof(parentContainer));

            // Create indicator
            _indicator = CreateIndicator();
            _parentContainer.Children.Add(_indicator);

            // Create animations
            _pulseAnimation = CreatePulseAnimation();
            _fadeOutAnimation = CreateFadeOutAnimation();
        }

        /// <summary>
        /// Create the indicator UI element.
        /// </summary>
        private Border CreateIndicator()
        {
            var indicator = new Border
            {
                Width = 150,
                Height = 30,
                Background = new SolidColorBrush(Color.FromArgb(230, 255, 59, 48)), // Red with 90% opacity
                CornerRadius = new CornerRadius(8),
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Top,
                Margin = new Thickness(0, 60, 0, 0),
                Visibility = Visibility.Hidden,
                RenderTransformOrigin = new Point(0.5, 0.5)
            };

            // Add scale transform for pulse animation
            indicator.RenderTransform = new ScaleTransform(1.0, 1.0);

            // Text
            var textBlock = new TextBlock
            {
                Text = "🔴 Capturing Screen",
                Foreground = Brushes.White,
                FontSize = 13,
                FontWeight = FontWeights.Bold,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };

            indicator.Child = textBlock;

            return indicator;
        }

        /// <summary>
        /// Create pulse animation (scale 1.0 -> 1.1).
        /// </summary>
        private DoubleAnimation CreatePulseAnimation()
        {
            return new DoubleAnimation
            {
                From = 1.0,
                To = 1.1,
                Duration = TimeSpan.FromMilliseconds(300),
                EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
            };
        }

        /// <summary>
        /// Create fade out animation (scale 1.1 -> 1.0).
        /// </summary>
        private DoubleAnimation CreateFadeOutAnimation()
        {
            return new DoubleAnimation
            {
                From = 1.1,
                To = 1.0,
                Duration = TimeSpan.FromMilliseconds(200),
                EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseIn }
            };
        }

        /// <summary>
        /// Show the indicator with pulse animation.
        /// </summary>
        public void Show()
        {
            _indicator.Visibility = Visibility.Visible;

            // Start pulse animation
            var scaleTransform = _indicator.RenderTransform as ScaleTransform;
            if (scaleTransform != null)
            {
                scaleTransform.BeginAnimation(ScaleTransform.ScaleXProperty, _pulseAnimation);
                scaleTransform.BeginAnimation(ScaleTransform.ScaleYProperty, _pulseAnimation);
            }

            StealthLogger.Shared.Log("📸 Screenshot capture indicator shown");
        }

        /// <summary>
        /// Hide the indicator with fade animation.
        /// </summary>
        public void Hide()
        {
            var scaleTransform = _indicator.RenderTransform as ScaleTransform;
            if (scaleTransform != null)
            {
                // Clone animations to avoid reuse issues
                var fadeOutX = _fadeOutAnimation.Clone();
                var fadeOutY = _fadeOutAnimation.Clone();

                fadeOutX.Completed += (s, e) =>
                {
                    _indicator.Visibility = Visibility.Hidden;
                };

                scaleTransform.BeginAnimation(ScaleTransform.ScaleXProperty, fadeOutX);
                scaleTransform.BeginAnimation(ScaleTransform.ScaleYProperty, fadeOutY);
            }
            else
            {
                _indicator.Visibility = Visibility.Hidden;
            }

            StealthLogger.Shared.Log("📸 Screenshot capture indicator hidden");
        }

        /// <summary>
        /// Show indicator, execute async action, then hide indicator.
        /// Handles errors gracefully.
        /// </summary>
        public async Task ShowDuringAsync(Func<Task> action)
        {
            try
            {
                Show();
                await action();
                Hide();
            }
            catch (Exception ex)
            {
                Hide();
                StealthLogger.Shared.Log($"❌ Error during screenshot capture: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Simple version without animation.
        /// </summary>
        public void ShowSimple()
        {
            _indicator.Visibility = Visibility.Visible;
        }

        /// <summary>
        /// Simple hide without animation.
        /// </summary>
        public void HideSimple()
        {
            _indicator.Visibility = Visibility.Hidden;
        }
    }
}

