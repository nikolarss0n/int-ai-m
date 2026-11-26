using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Animation;
using InterviewMasterApp.Presentation.Styling;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Search controller for RichTextBox notes using accurate FlowDocument TextPointer run walking
    /// (fixes offset drift across multiple paragraphs).
    /// </summary>
    public class SearchController
    {
        private readonly Border _searchContainer;
        private readonly TextBox _searchField;
        private readonly TextBlock _searchResultsLabel;
        private readonly RichTextBox _textView;
        private readonly Action? _renderMarkdownCallback;

        private bool _isSearchVisible;
        private readonly List<TextRange> _searchHighlights = new();

        public bool IsSearchVisible => _isSearchVisible;

        public SearchController(
            Border searchContainer,
            TextBox searchField,
            TextBlock searchResultsLabel,
            RichTextBox textView,
            Action? renderMarkdownCallback = null)
        {
            _searchContainer = searchContainer ?? throw new ArgumentNullException(nameof(searchContainer));
            _searchField = searchField ?? throw new ArgumentNullException(nameof(searchField));
            _searchResultsLabel = searchResultsLabel ?? throw new ArgumentNullException(nameof(searchResultsLabel));
            _textView = textView ?? throw new ArgumentNullException(nameof(textView));
            _renderMarkdownCallback = renderMarkdownCallback;

            _searchField.TextChanged += (_, _) => PerformSearch();
            _searchField.PreviewKeyDown += (_, e) =>
            {
                if (e.Key == System.Windows.Input.Key.Escape)
                {
                    ToggleSearch();
                    e.Handled = true;
                }
            };
        }

        public static Border CreateSearchContainer(TextBox searchField, TextBlock searchResults)
        {
            var container = new Border
            {
                Width = 320,
                Height = 38,
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Top,
                Margin = new Thickness(0, 12, 16, 0),
                CornerRadius = new CornerRadius(10),
                Background = DesignTokens.BgWidgetBrush,
                BorderBrush = DesignTokens.BorderSubtleBrush,
                BorderThickness = new Thickness(1),
                Padding = new Thickness(10, 4, 10, 4),
                Opacity = 0,
                Visibility = Visibility.Hidden
            };

            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            searchField.Background = Brushes.Transparent;
            searchField.Foreground = DesignTokens.TextPrimaryBrush;
            searchField.CaretBrush = DesignTokens.TextPrimaryBrush;
            searchField.BorderThickness = new Thickness(0);
            searchField.VerticalContentAlignment = VerticalAlignment.Center;
            searchField.FontSize = 13;
            Grid.SetColumn(searchField, 0);
            grid.Children.Add(searchField);

            searchResults.VerticalAlignment = VerticalAlignment.Center;
            searchResults.FontSize = 12;
            searchResults.Margin = new Thickness(8, 0, 0, 0);
            Grid.SetColumn(searchResults, 1);
            grid.Children.Add(searchResults);

            container.Child = grid;
            return container;
        }

        public void ToggleSearch()
        {
            _isSearchVisible = !_isSearchVisible;
            if (_isSearchVisible)
            {
                _searchContainer.Visibility = Visibility.Visible;
                var anim = new DoubleAnimation(1.0, TimeSpan.FromMilliseconds(160));
                anim.Completed += (_, _) => { _searchField.Focus(); _searchField.SelectAll(); };
                _searchContainer.BeginAnimation(UIElement.OpacityProperty, anim);
            }
            else
            {
                var anim = new DoubleAnimation(0.0, TimeSpan.FromMilliseconds(160));
                anim.Completed += (_, _) =>
                {
                    _searchContainer.Visibility = Visibility.Hidden;
                    _searchField.Text = string.Empty;
                    _searchResultsLabel.Text = string.Empty;
                    ClearSearchHighlights();
                };
                _searchContainer.BeginAnimation(UIElement.OpacityProperty, anim);
            }
        }

        public void PerformSearch()
        {
            ClearSearchHighlights();
            var term = _searchField.Text;
            if (string.IsNullOrEmpty(term))
            {
                _searchResultsLabel.Text = string.Empty;
                return;
            }

            // Walk actual text runs in the FlowDocument so multi-paragraph offsets stay exact
            TextPointer? firstMatch = null;
            var pointer = _textView.Document.ContentStart;
            while (pointer != null && pointer.CompareTo(_textView.Document.ContentEnd) < 0)
            {
                if (pointer.GetPointerContext(LogicalDirection.Forward) == TextPointerContext.Text)
                {
                    var runText = pointer.GetTextInRun(LogicalDirection.Forward);
                    int idx = 0;
                    while ((idx = runText.IndexOf(term, idx, StringComparison.OrdinalIgnoreCase)) >= 0)
                    {
                        var start = pointer.GetPositionAtOffset(idx);
                        var end = pointer.GetPositionAtOffset(idx + term.Length);
                        if (start != null && end != null)
                        {
                            var range = new TextRange(start, end);
                            range.ApplyPropertyValue(TextElement.BackgroundProperty, DesignTokens.WarningWashBrush);
                            range.ApplyPropertyValue(TextElement.ForegroundProperty, DesignTokens.WarningTextBrush);
                            _searchHighlights.Add(range);
                            firstMatch ??= start;
                        }
                        idx += term.Length;
                    }
                }
                pointer = pointer.GetNextContextPosition(LogicalDirection.Forward);
            }

            if (_searchHighlights.Count > 0)
            {
                _searchResultsLabel.Text = $"{_searchHighlights.Count} found";
                _searchResultsLabel.Foreground = DesignTokens.SuccessTextBrush;
                try
                {
                    var rect = firstMatch!.GetCharacterRect(LogicalDirection.Forward);
                    _textView.ScrollToVerticalOffset(rect.Top);
                }
                catch { }
            }
            else
            {
                _searchResultsLabel.Text = "0 found";
                _searchResultsLabel.Foreground = DesignTokens.DangerTextBrush;
            }
        }

        public void ClearSearchHighlights()
        {
            foreach (var range in _searchHighlights)
            {
                try
                {
                    range.ApplyPropertyValue(TextElement.BackgroundProperty, Brushes.Transparent);
                    range.ApplyPropertyValue(TextElement.ForegroundProperty, DesignTokens.TextBodyBrush);
                }
                catch { }
            }
            _searchHighlights.Clear();
        }
    }
}
