using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Animation;
using InterviewMasterApp.Presentation.Styling;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Floating formatting toolbar supporting both WPF RichTextBox and TextBox.
    /// </summary>
    public class FormattingToolbar
    {
        private Border? _toolbarContainer;
        private bool _isVisible;
        private RichTextBox? _richTextBox;
        private TextBox? _textBox;
        private Action? _renderMarkdownCallback;

        public void SetupFormattingToolbar(Panel parentView, Control editor, Action renderMarkdownCallback)
        {
            _richTextBox = editor as RichTextBox;
            _textBox = editor as TextBox;
            _renderMarkdownCallback = renderMarkdownCallback;

            _toolbarContainer = new Border
            {
                Height = 40,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Top,
                Margin = new Thickness(0, 12, 0, 0),
                CornerRadius = new CornerRadius(12),
                BorderThickness = new Thickness(1),
                BorderBrush = DesignTokens.BorderSubtleBrush,
                Background = DesignTokens.BgWidgetBrush,
                Padding = new Thickness(6, 4, 6, 4),
                Opacity = 0,
                Visibility = Visibility.Hidden
            };

            var panel = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center };
            panel.Children.Add(MakeBtn("H2", "Heading (##)", (_, _) => InsertPrefix("## ")));
            panel.Children.Add(MakeBtn("B", "Bold (**)", (_, _) => Wrap("**", "**", "bold")));
            panel.Children.Add(MakeBtn("I", "Italic (*)", (_, _) => Wrap("*", "*", "italic")));
            panel.Children.Add(MakeBtn("</>", "Inline Code (`)", (_, _) => Wrap("`", "`", "code")));
            panel.Children.Add(MakeBtn("{ }", "Code Block (```)", (_, _) => Wrap("\n```\n", "\n```\n", "code")));
            panel.Children.Add(MakeBtn("•", "Bullet List", (_, _) => InsertPrefix("- ")));
            panel.Children.Add(MakeBtn("Link", "Markdown Link", (_, _) => Wrap("[", "](url)", "link")));
            panel.Children.Add(MakeBtn("—", "Divider", (_, _) => InsertPrefix("\n---\n")));

            _toolbarContainer.Child = panel;
            parentView.Children.Add(_toolbarContainer);
        }

        private static Button MakeBtn(string label, string tooltip, RoutedEventHandler onClick)
        {
            var btn = new Button
            {
                MinWidth = 34,
                Height = 28,
                Padding = new Thickness(8, 0, 8, 0),
                Margin = new Thickness(2, 0, 2, 0),
                Content = label,
                ToolTip = tooltip,
                Background = Brushes.Transparent,
                Foreground = DesignTokens.TextStrongBrush,
                BorderThickness = new Thickness(0),
                FontSize = 12,
                Cursor = System.Windows.Input.Cursors.Hand
            };
            btn.Click += onClick;
            return btn;
        }

        public void ShowToolbar()
        {
            if (_toolbarContainer == null || _isVisible) return;
            _isVisible = true;
            _toolbarContainer.Visibility = Visibility.Visible;
            _toolbarContainer.BeginAnimation(UIElement.OpacityProperty, new DoubleAnimation(1.0, TimeSpan.FromMilliseconds(150)));
        }

        public void HideToolbar()
        {
            if (_toolbarContainer == null || !_isVisible) return;
            _isVisible = false;
            var anim = new DoubleAnimation(0.0, TimeSpan.FromMilliseconds(150));
            anim.Completed += (_, _) => { if (!_isVisible) _toolbarContainer.Visibility = Visibility.Hidden; };
            _toolbarContainer.BeginAnimation(UIElement.OpacityProperty, anim);
        }

        private void Wrap(string prefix, string suffix, string placeholder)
        {
            if (_richTextBox != null)
            {
                var sel = _richTextBox.Selection;
                var selected = string.IsNullOrEmpty(sel.Text) ? placeholder : sel.Text;
                sel.Text = $"{prefix}{selected}{suffix}";
                _renderMarkdownCallback?.Invoke();
                return;
            }
            if (_textBox != null)
            {
                var start = _textBox.SelectionStart;
                var selected = string.IsNullOrEmpty(_textBox.SelectedText) ? placeholder : _textBox.SelectedText;
                _textBox.SelectedText = $"{prefix}{selected}{suffix}";
                _textBox.SelectionStart = start + prefix.Length;
                _textBox.SelectionLength = selected.Length;
                _renderMarkdownCallback?.Invoke();
            }
        }

        private void InsertPrefix(string prefix)
        {
            if (_richTextBox != null)
            {
                _richTextBox.Selection.Text = prefix + _richTextBox.Selection.Text;
                _renderMarkdownCallback?.Invoke();
                return;
            }
            if (_textBox != null)
            {
                _textBox.SelectedText = prefix + _textBox.SelectedText;
                _renderMarkdownCallback?.Invoke();
            }
        }
    }
}
