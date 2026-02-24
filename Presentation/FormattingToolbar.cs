using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using Microsoft.Windows.Themes;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Floating formatting toolbar for markdown text editing.
    /// Ported from Swift: FormattingToolbar.swift
    /// Provides quick access to markdown formatting commands (heading, bold, italic, code, lists, links).
    /// </summary>
    public class FormattingToolbar
    {
        private Border? _toolbarContainer;
        private bool _isVisible;
        private TextBox? _textBox;
        private Action? _renderMarkdownCallback;

        /// <summary>
        /// Setup the formatting toolbar in the parent container.
        /// </summary>
        public void SetupFormattingToolbar(Panel parentView, Control textBox, Action renderMarkdownCallback)
        {
            _textBox = textBox as TextBox; // Only TextBox supports formatting operations
            _renderMarkdownCallback = renderMarkdownCallback;

            // Floating toolbar container - similar to visionOS style
            _toolbarContainer = new Border
            {
                Width = 360,
                Height = 44,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Top,
                Margin = new Thickness(0, 60, 0, 0),
                CornerRadius = new CornerRadius(12),
                BorderThickness = new Thickness(1.5),
                BorderBrush = new SolidColorBrush(Color.FromArgb(77, 255, 255, 255)), // 30% opacity white
                Background = new SolidColorBrush(Color.FromArgb(160, 30, 30, 30)), // Semi-transparent dark
                Opacity = 0,
                Visibility = Visibility.Hidden
            };

            // Use a StackPanel for buttons
            var buttonPanel = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                Margin = new Thickness(8, 7, 8, 7),
                HorizontalAlignment = HorizontalAlignment.Center
            };

            const double spacing = 4;

            // Create formatting buttons
            buttonPanel.Children.Add(CreateFormattingButton("A", "Heading (##)", InsertHeading, spacing));
            buttonPanel.Children.Add(CreateFormattingButton("B", "Bold (**)", InsertBold, spacing));
            buttonPanel.Children.Add(CreateFormattingButton("I", "Italic (*)", InsertItalic, spacing));
            buttonPanel.Children.Add(CreateFormattingButton("</>", "Code (`)", InsertCode, spacing));
            buttonPanel.Children.Add(CreateFormattingButton("{ }", "Code Block (```)", InsertCodeBlock, spacing));
            buttonPanel.Children.Add(CreateFormattingButton("•", "Bullet List", InsertList, spacing));
            buttonPanel.Children.Add(CreateFormattingButton("🔗", "Link", InsertLink, spacing));
            buttonPanel.Children.Add(CreateFormattingButton("—", "Divider (---)", InsertDivider, spacing));

            _toolbarContainer.Child = buttonPanel;
            parentView.Children.Add(_toolbarContainer);
        }

        private Button CreateFormattingButton(string label, string tooltip, RoutedEventHandler action, double marginRight)
        {
            var button = new Button
            {
                Width = 40,
                Height = 30,
                Content = label,
                ToolTip = tooltip,
                Margin = new Thickness(0, 0, marginRight, 0),
                Background = Brushes.Transparent,
                BorderBrush = Brushes.Transparent,
                Foreground = Brushes.White,
                FontSize = 14,
                FontWeight = FontWeights.Medium,
                Cursor = System.Windows.Input.Cursors.Hand
            };

            button.Click += action;

            // Add hover effect
            button.MouseEnter += (s, e) =>
            {
                button.Background = new SolidColorBrush(Color.FromArgb(51, 255, 255, 255));
            };
            button.MouseLeave += (s, e) =>
            {
                button.Background = Brushes.Transparent;
            };

            return button;
        }

        public void ShowFormattingToolbar()
        {
            if (_toolbarContainer == null || _isVisible)
                return;

            _isVisible = true;
            _toolbarContainer.Visibility = Visibility.Visible;

            var fadeIn = new DoubleAnimation(0, 0.95, TimeSpan.FromMilliseconds(200));
            _toolbarContainer.BeginAnimation(UIElement.OpacityProperty, fadeIn);
        }

        public void HideFormattingToolbar()
        {
            if (_toolbarContainer == null || !_isVisible)
                return;

            _isVisible = false;

            var fadeOut = new DoubleAnimation(0.95, 0, TimeSpan.FromMilliseconds(200));
            fadeOut.Completed += (s, e) =>
            {
                _toolbarContainer.Visibility = Visibility.Hidden;
            };
            _toolbarContainer.BeginAnimation(UIElement.OpacityProperty, fadeOut);
        }

        // MARK: - Formatting Actions

        private void InsertHeading(object sender, RoutedEventArgs e)
        {
            InsertMarkdownWrapper("## ", "", "Heading");
        }

        private void InsertBold(object sender, RoutedEventArgs e)
        {
            InsertMarkdownWrapper("**", "**", "bold text");
        }

        private void InsertItalic(object sender, RoutedEventArgs e)
        {
            InsertMarkdownWrapper("*", "*", "italic text");
        }

        private void InsertCode(object sender, RoutedEventArgs e)
        {
            InsertMarkdownWrapper("`", "`", "code");
        }

        private void InsertCodeBlock(object sender, RoutedEventArgs e)
        {
            InsertMarkdownWrapper("```\n", "\n```", "code block");
        }

        private void InsertList(object sender, RoutedEventArgs e)
        {
            if (_textBox == null)
                return;

            var selectionStart = _textBox.SelectionStart;
            var selectionLength = _textBox.SelectionLength;
            var selectedText = _textBox.SelectedText;

            if (string.IsNullOrEmpty(selectedText))
                return;

            // Split by lines and add bullet to each line
            var lines = selectedText.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None);
            var bulletedText = string.Join("\n", lines.Select(line =>
                string.IsNullOrEmpty(line) ? "" : $"- {line}"
            ));

            _textBox.SelectedText = bulletedText;

            // Force re-render markdown
            _textBox.Dispatcher.BeginInvoke(DispatcherPriority.Background, new Action(() =>
            {
                _renderMarkdownCallback?.Invoke();
            }));
        }

        private void InsertLink(object sender, RoutedEventArgs e)
        {
            InsertMarkdownWrapper("[", "](url)", "link text");
        }

        private void InsertDivider(object sender, RoutedEventArgs e)
        {
            if (_textBox == null)
                return;

            _textBox.SelectedText = "\n\n---\n\n";
            _renderMarkdownCallback?.Invoke();
        }

        private void InsertMarkdownWrapper(string prefix, string suffix, string placeholder)
        {
            if (_textBox == null)
                return;

            var selectedText = _textBox.SelectedText;

            // Only format if there's selected text
            if (string.IsNullOrEmpty(selectedText))
                return;

            var textToInsert = prefix + selectedText + suffix;
            _textBox.SelectedText = textToInsert;

            // Force re-render markdown
            _textBox.Dispatcher.BeginInvoke(DispatcherPriority.Background, new Action(() =>
            {
                _renderMarkdownCallback?.Invoke();
            }));
        }
    }
}

