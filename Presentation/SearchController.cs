using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Search controller for finding text in notes with highlighting.
    /// Ported from Swift: SearchController.swift
    /// Provides incremental search with visual feedback and result highlighting.
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

        // Colors for search results
        private static readonly Color AppleGreen = Color.FromRgb(52, 199, 89);
        private static readonly Color AppleRed = Color.FromRgb(255, 59, 48);
        private static readonly Color AppleGold = Color.FromRgb(255, 204, 0);

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

            // Setup search field event handler
            _searchField.TextChanged += (s, e) => PerformSearch();

            // Setup keyboard handler for ESC key
            _searchField.PreviewKeyDown += (s, e) =>
            {
                if (e.Key == System.Windows.Input.Key.Escape)
                {
                    ToggleSearch();
                    e.Handled = true;
                }
            };
        }

        /// <summary>
        /// Toggle search visibility.
        /// </summary>
        public void ToggleSearch()
        {
            _isSearchVisible = !_isSearchVisible;

            if (_isSearchVisible)
            {
                // Show search container
                _searchContainer.Visibility = Visibility.Visible;

                // Fade in animation
                var fadeIn = new DoubleAnimation(0, 1.0, TimeSpan.FromMilliseconds(200))
                {
                    EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
                };
                fadeIn.Completed += (s, e) =>
                {
                    // Focus search field after animation
                    _searchField.Focus();
                    _searchField.SelectAll();
                };
                _searchContainer.BeginAnimation(UIElement.OpacityProperty, fadeIn);

                StealthLogger.Shared.Log("🔍 Search shown");
            }
            else
            {
                // Fade out animation
                var fadeOut = new DoubleAnimation(1.0, 0, TimeSpan.FromMilliseconds(200))
                {
                    EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseIn }
                };
                fadeOut.Completed += (s, e) =>
                {
                    _searchContainer.Visibility = Visibility.Hidden;
                    _searchField.Text = string.Empty;
                    _searchResultsLabel.Text = string.Empty;
                    ClearSearchHighlights();
                };
                _searchContainer.BeginAnimation(UIElement.OpacityProperty, fadeOut);

                StealthLogger.Shared.Log("🔍 Search hidden");
            }
        }

        /// <summary>
        /// Perform search and update results.
        /// </summary>
        public void PerformSearch()
        {
            var searchTerm = _searchField.Text.ToLowerInvariant();

            if (string.IsNullOrEmpty(searchTerm))
            {
                ClearSearchHighlights();
                _searchResultsLabel.Text = string.Empty;
                return;
            }

            var text = GetPlainText(_textView).ToLowerInvariant();
            var matchCount = CountMatches(text, searchTerm);

            if (matchCount > 0)
            {
                _searchResultsLabel.Text = $"✓ {matchCount}";
                _searchResultsLabel.Foreground = new SolidColorBrush(AppleGreen);
                HighlightSearchResults(searchTerm);
            }
            else
            {
                _searchResultsLabel.Text = "✗ 0";
                _searchResultsLabel.Foreground = new SolidColorBrush(AppleRed);
                ClearSearchHighlights();
            }
        }

        /// <summary>
        /// Count matches in text.
        /// </summary>
        private int CountMatches(string text, string searchTerm)
        {
            var count = 0;
            var index = 0;

            while ((index = text.IndexOf(searchTerm, index, StringComparison.OrdinalIgnoreCase)) != -1)
            {
                count++;
                index += searchTerm.Length;
            }

            return count;
        }

        /// <summary>
        /// Highlight all search results in the text view.
        /// </summary>
        private void HighlightSearchResults(string searchTerm)
        {
            ClearSearchHighlights();

            var document = _textView.Document;
            var plainText = GetPlainText(_textView);
            var lowercasedText = plainText.ToLowerInvariant();

            var index = 0;
            TextPointer? firstMatchStart = null;

            while ((index = lowercasedText.IndexOf(searchTerm, index, StringComparison.OrdinalIgnoreCase)) != -1)
            {
                // Get TextPointers for this match
                var start = document.ContentStart.GetPositionAtOffset(index + 2); // +2 for document structure
                var end = start?.GetPositionAtOffset(searchTerm.Length);

                if (start != null && end != null)
                {
                    var textRange = new TextRange(start, end);

                    // Apply highlighting
                    textRange.ApplyPropertyValue(TextElement.BackgroundProperty, new SolidColorBrush(Color.FromArgb(128, AppleGold.R, AppleGold.G, AppleGold.B)));
                    textRange.ApplyPropertyValue(TextElement.ForegroundProperty, Brushes.Black);

                    _searchHighlights.Add(textRange);

                    // Remember first match for scrolling
                    if (firstMatchStart == null)
                    {
                        firstMatchStart = start;
                    }
                }

                index += searchTerm.Length;
            }

            // Scroll to first match after a short delay
            if (firstMatchStart != null)
            {
                var timer = new DispatcherTimer
                {
                    Interval = TimeSpan.FromMilliseconds(100)
                };
                timer.Tick += (s, e) =>
                {
                    (s as DispatcherTimer)?.Stop();
                    ScrollToPosition(firstMatchStart);
                };
                timer.Start();
            }
        }

        /// <summary>
        /// Scroll to specific position in the text view.
        /// </summary>
        private void ScrollToPosition(TextPointer position)
        {
            try
            {
                // Get the bounding rectangle of the position
                var rect = position.GetCharacterRect(LogicalDirection.Forward);

                // Scroll to make the position visible
                _textView.ScrollToVerticalOffset(rect.Top);

                // Set selection to highlight the match
                _textView.Selection.Select(position, position.GetPositionAtOffset(1));

                // Bring the text view into view
                _textView.BringIntoView(rect);
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"⚠️ Error scrolling to search result: {ex.Message}");
            }
        }

        /// <summary>
        /// Clear all search highlights.
        /// </summary>
        public void ClearSearchHighlights()
        {
            // Clear highlights by removing the applied formatting
            foreach (var range in _searchHighlights)
            {
                try
                {
                    range.ClearAllProperties();
                }
                catch
                {
                    // Range may be invalid if document changed
                }
            }

            _searchHighlights.Clear();

            // Re-render markdown to restore original formatting
            _renderMarkdownCallback?.Invoke();
        }

        /// <summary>
        /// Get plain text from RichTextBox.
        /// </summary>
        private string GetPlainText(RichTextBox richTextBox)
        {
            var textRange = new TextRange(richTextBox.Document.ContentStart, richTextBox.Document.ContentEnd);
            return textRange.Text ?? string.Empty;
        }

        /// <summary>
        /// Setup search UI container (call this in UI initialization).
        /// </summary>
        public static Border CreateSearchContainer(TextBox searchField, TextBlock resultsLabel)
        {
            var container = new Border
            {
                Background = new SolidColorBrush(Color.FromArgb(230, 40, 40, 45)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(128, 255, 255, 255)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(8),
                Padding = new Thickness(12, 8, 12, 8),
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Top,
                Margin = new Thickness(0, 10, 0, 0),
                Opacity = 0,
                Visibility = Visibility.Hidden
            };

            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(200) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            // Search field
            searchField.Width = 200;
            searchField.Background = new SolidColorBrush(Color.FromArgb(128, 60, 60, 67));
            searchField.Foreground = Brushes.White;
            searchField.BorderThickness = new Thickness(0);
            searchField.Padding = new Thickness(8, 4, 8, 4);
            searchField.FontSize = 14;
            Grid.SetColumn(searchField, 0);
            grid.Children.Add(searchField);

            // Results label
            resultsLabel.Foreground = Brushes.White;
            resultsLabel.FontSize = 14;
            resultsLabel.FontWeight = FontWeights.Medium;
            resultsLabel.Margin = new Thickness(10, 0, 0, 0);
            resultsLabel.VerticalAlignment = VerticalAlignment.Center;
            Grid.SetColumn(resultsLabel, 1);
            grid.Children.Add(resultsLabel);

            container.Child = grid;

            return container;
        }
    }
}

