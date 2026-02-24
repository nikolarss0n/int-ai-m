using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Timeline;

namespace InterviewMasterApp.Presentation.Windows
{
    /// <summary>
    /// Data source for the floating solution window.
    /// Ported from Swift: FloatingSolutionDataSource
    /// </summary>
    public interface IFloatingSolutionDataSource
    {
        string? CurrentPinnedSolution { get; }
        List<InterviewMessage> VoiceMessages { get; }
        MessageViewFactory MessageViewFactory { get; }
    }

    /// <summary>
    /// Floating solution window controller (WPF). UI-agnostic logic + simple WPF view.
    /// </summary>
    public class FloatingSolutionWindowController
    {
        private readonly IFloatingSolutionDataSource _dataSource;
        private Window? _window;
        private TextBox? _solutionText;
        private ScrollViewer? _solutionScroll;
        private Border? _loadingIndicator;
        private StackPanel? _qaContainer;

        public bool IsVisible => _window?.IsVisible ?? false;

        public FloatingSolutionWindowController(IFloatingSolutionDataSource dataSource)
        {
            _dataSource = dataSource ?? throw new ArgumentNullException(nameof(dataSource));
        }

        public void Show()
        {
            var solution = _dataSource.CurrentPinnedSolution;
            if (string.IsNullOrWhiteSpace(solution)) return;

            Dismiss();

            var screen = SystemParameters.WorkArea;
            var windowWidth = 500.0;
            var windowHeight = Math.Min(750.0, screen.Height * 0.8);

            var win = new StealthWindow
            {
                Width = windowWidth,
                Height = windowHeight,
                Top = screen.Top + 20,
                Left = screen.Right - windowWidth - 20,
                Topmost = true,
                WindowStyle = WindowStyle.None,
                AllowsTransparency = true,
                Background = Brushes.Transparent,
                ShowInTaskbar = false
            };

            var root = new Border
            {
                CornerRadius = new CornerRadius(12),
                Background = new SolidColorBrush(Color.FromArgb(230, 20, 20, 25)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(180, 140, 80, 200)),
                BorderThickness = new Thickness(1),
                Padding = new Thickness(8)
            };

            var grid = new Grid();
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            var header = new TextBlock
            {
                Text = "Floating Solution",
                Foreground = Brushes.Gray,
                FontSize = 10,
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 0, 0, 6)
            };
            Grid.SetRow(header, 0);
            grid.Children.Add(header);

            _loadingIndicator = new Border
            {
                Background = new SolidColorBrush(Color.FromArgb(120, 80, 200, 120)),
                Width = 24,
                Height = 24,
                CornerRadius = new CornerRadius(12),
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                Visibility = Visibility.Collapsed,
                Margin = new Thickness(0, 2, 0, 6)
            };
            Grid.SetRow(_loadingIndicator, 1);
            grid.Children.Add(_loadingIndicator);

            _solutionText = new TextBox
            {
                Text = solution,
                Foreground = Brushes.White,
                Background = Brushes.Transparent,
                BorderThickness = new Thickness(0),
                TextWrapping = TextWrapping.Wrap,
                IsReadOnly = true
            };

            _solutionScroll = new ScrollViewer
            {
                Content = _solutionText,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
            };

            Grid.SetRow(_solutionScroll, 2);
            grid.Children.Add(_solutionScroll);

            _qaContainer = new StackPanel { Orientation = Orientation.Vertical, Margin = new Thickness(0, 6, 0, 0) };
            Grid.SetRow(_qaContainer, 3);
            grid.Children.Add(_qaContainer);

            root.Child = grid;
            win.Content = root;

            win.KeyDown += OnWindowKeyDown;

            _window = win;
            UpdateQA();
            win.Show();
        }

        public void Dismiss()
        {
            if (_window != null)
            {
                _window.Close();
                _window = null;
                _solutionText = null;
                _solutionScroll = null;
                _qaContainer = null;
                _loadingIndicator = null;
            }
        }

        public void ScrollBy(double delta)
        {
            if (_solutionScroll == null) return;
            _solutionScroll.ScrollToVerticalOffset(_solutionScroll.VerticalOffset - delta);
        }

        public void ShowLoading()
        {
            if (_loadingIndicator != null)
                _loadingIndicator.Visibility = Visibility.Visible;
        }

        public void HideLoading()
        {
            if (_loadingIndicator != null)
                _loadingIndicator.Visibility = Visibility.Collapsed;
        }

        public void UpdateContent(string content)
        {
            if (_solutionText == null) return;
            _solutionText.Dispatcher.Invoke(() => _solutionText.Text = content ?? string.Empty);
        }

        public void UpdateQA()
        {
            if (_qaContainer == null) return;

            _qaContainer.Children.Clear();
            var qa = GetLastQuestionAnswer();
            if (qa == null) return;

            var (question, answer) = qa.Value;
            _qaContainer.Children.Add(new TextBlock
            {
                Text = "Q: " + question,
                Foreground = Brushes.LightGray,
                FontSize = 11,
                TextWrapping = TextWrapping.Wrap
            });

            _qaContainer.Children.Add(new TextBlock
            {
                Text = "A: " + answer,
                Foreground = Brushes.White,
                FontSize = 11,
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 4, 0, 0)
            });
        }

        private (string question, string answer)? GetLastQuestionAnswer()
        {
            var messages = _dataSource.VoiceMessages;
            if (messages == null || messages.Count == 0) return null;

            InterviewMessage? lastQ = null;
            InterviewMessage? lastA = null;

            for (int i = messages.Count - 1; i >= 0; i--)
            {
                var msg = messages[i];
                if (lastA == null && msg.Type is InterviewMessage.MessageType.Answer or InterviewMessage.MessageType.FollowUp)
                {
                    lastA = msg;
                    continue;
                }
                if (lastA != null && msg.Type == InterviewMessage.MessageType.Question)
                {
                    lastQ = msg;
                    break;
                }
            }

            if (lastQ == null || lastA == null) return null;
            return (lastQ.Content, lastA.Content);
        }

        private void OnWindowKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
        {
            // Local shortcuts when window has focus
            if (e.Key == System.Windows.Input.Key.J) ScrollBy(-50);
            if (e.Key == System.Windows.Input.Key.K) ScrollBy(50);
            if (_window == null) return;

            if (e.Key == System.Windows.Input.Key.Up) _window.Top -= 30;
            if (e.Key == System.Windows.Input.Key.Down) _window.Top += 30;
            if (e.Key == System.Windows.Input.Key.Left) _window.Left -= 30;
            if (e.Key == System.Windows.Input.Key.Right) _window.Left += 30;
        }
    }
}

