using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Styling;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Inline single-line header notice bar backed by <see cref="NoticeBoard"/>.
    /// Confirmations auto-dismiss; errors persist until resolved or dismissed.
    /// </summary>
    public sealed class FocusNoticeController : IDisposable
    {
        private readonly NoticeBoard _board = new();
        private readonly Border _container;
        private readonly TextBlock _iconBlock;
        private readonly TextBlock _messageBlock;
        private readonly Button _actionButton;
        private readonly Button _closeButton;
        private readonly DispatcherTimer _expiryTimer;
        private Action? _currentAction;

        public UIElement View => _container;

        public FocusNoticeController()
        {
            _container = new Border
            {
                Height = 28,
                CornerRadius = new CornerRadius(14),
                Padding = new Thickness(10, 0, 8, 0),
                VerticalAlignment = VerticalAlignment.Center,
                Visibility = Visibility.Collapsed
            };

            var stack = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };

            _iconBlock = new TextBlock
            {
                FontSize = 12,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 0, 6, 0)
            };

            _messageBlock = new TextBlock
            {
                FontSize = DesignTokens.FontSizes.Caption,
                VerticalAlignment = VerticalAlignment.Center,
                TextTrimming = TextTrimming.CharacterEllipsis,
                MaxWidth = 380
            };

            _actionButton = new Button
            {
                FontSize = DesignTokens.FontSizes.Caption,
                FontWeight = FontWeights.SemiBold,
                Padding = new Thickness(8, 2, 8, 2),
                Margin = new Thickness(8, 0, 0, 0),
                BorderThickness = new Thickness(0),
                Background = DesignTokens.Tint(DesignTokens.Colors.White, 0.12),
                Foreground = DesignTokens.TextPrimaryBrush,
                Cursor = System.Windows.Input.Cursors.Hand,
                Visibility = Visibility.Collapsed
            };
            _actionButton.Click += (_, _) =>
            {
                var action = _currentAction;
                Dismiss();
                action?.Invoke();
            };

            _closeButton = new Button
            {
                Content = "×",
                FontSize = 13,
                Padding = new Thickness(6, 0, 4, 0),
                Margin = new Thickness(4, 0, 0, 0),
                BorderThickness = new Thickness(0),
                Background = Brushes.Transparent,
                Foreground = DesignTokens.TextMutedBrush,
                Cursor = System.Windows.Input.Cursors.Hand,
                Visibility = Visibility.Collapsed
            };
            _closeButton.Click += (_, _) => Dismiss();

            stack.Children.Add(_iconBlock);
            stack.Children.Add(_messageBlock);
            stack.Children.Add(_actionButton);
            stack.Children.Add(_closeButton);
            _container.Child = stack;

            _expiryTimer = new DispatcherTimer();
            _expiryTimer.Tick += (_, _) =>
            {
                _expiryTimer.Stop();
                _board.Expire(DateTime.UtcNow);
                Render();
            };
        }

        public void Post(FeedbackNotice notice, Action? action = null)
        {
            if (!_board.Show(notice, DateTime.UtcNow)) return;
            _currentAction = action;
            Render();
            ScheduleExpiry();
        }

        public void Resolve(string key)
        {
            _board.Resolve(key);
            if (_board.Current == null) _currentAction = null;
            Render();
        }

        public void Dismiss()
        {
            _expiryTimer.Stop();
            _board.Dismiss();
            _currentAction = null;
            Render();
        }

        private void ScheduleExpiry()
        {
            _expiryTimer.Stop();
            var exp = _board.Expiry;
            if (!exp.HasValue) return;
            var delay = exp.Value - DateTime.UtcNow;
            if (delay <= TimeSpan.Zero)
            {
                _board.Expire(DateTime.UtcNow);
                Render();
                return;
            }
            _expiryTimer.Interval = delay;
            _expiryTimer.Start();
        }

        private void Render()
        {
            var current = _board.Current;
            if (current == null)
            {
                _container.Visibility = Visibility.Collapsed;
                return;
            }

            (SolidColorBrush bg, SolidColorBrush fg, string icon) = current.Kind switch
            {
                FeedbackKind.Success => (DesignTokens.SuccessWashBrush, DesignTokens.SuccessTextBrush, "✓"),
                FeedbackKind.Warning => (DesignTokens.WarningWashBrush, DesignTokens.WarningTextBrush, "⚠"),
                FeedbackKind.Error => (DesignTokens.DangerWashBrush, DesignTokens.DangerTextBrush, "✕"),
                _ => (DesignTokens.AccentWashBrush, DesignTokens.AccentTextBrush, "ℹ")
            };

            _container.Background = bg;
            _iconBlock.Text = icon;
            _iconBlock.Foreground = fg;
            _messageBlock.Text = current.Message;
            _messageBlock.Foreground = fg;
            _container.ToolTip = string.IsNullOrEmpty(current.Detail) ? current.Message : $"{current.Message}\n{current.Detail}";

            if (!string.IsNullOrEmpty(current.ActionTitle) && _currentAction != null)
            {
                _actionButton.Content = current.ActionTitle;
                _actionButton.Visibility = Visibility.Visible;
            }
            else
            {
                _actionButton.Visibility = Visibility.Collapsed;
            }

            // Confirmations auto-dismiss (no close button); errors/persistent notices carry a close button.
            _closeButton.Visibility = current.LastsSeconds == null ? Visibility.Visible : Visibility.Collapsed;
            _container.Visibility = Visibility.Visible;
        }

        public void Dispose() => _expiryTimer.Stop();
    }
}
