using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Template selector dialog for loading interview templates.
    /// Ported from Swift: TemplateSelector.swift
    /// Provides category tabs and template cards with questions preview.
    /// </summary>
    public class TemplateSelector
    {
        private readonly RichTextBox _notesTextView;
        private readonly Action _switchToNotesTabCallback;
        private readonly Action _renderMarkdownCallback;

        public TemplateSelector(
            RichTextBox notesTextView,
            Action switchToNotesTabCallback,
            Action renderMarkdownCallback)
        {
            _notesTextView = notesTextView ?? throw new ArgumentNullException(nameof(notesTextView));
            _switchToNotesTabCallback = switchToNotesTabCallback ?? throw new ArgumentNullException(nameof(switchToNotesTabCallback));
            _renderMarkdownCallback = renderMarkdownCallback ?? throw new ArgumentNullException(nameof(renderMarkdownCallback));
        }

        /// <summary>
        /// Show template selector dialog.
        /// </summary>
        public void ShowTemplateSelector(Window owner)
        {
            var dialog = new Window
            {
                Title = "Interview Templates",
                Width = 480,
                Height = 520,
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                Owner = owner,
                WindowStyle = WindowStyle.ToolWindow,
                ResizeMode = ResizeMode.CanResize,
                Background = new SolidColorBrush(Color.FromArgb(230, 40, 40, 45))
            };

            var mainGrid = new Grid();
            mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Tab bar
            mainGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // Content

            // Category tabs
            var tabControl = new TabControl
            {
                Margin = new Thickness(20, 10, 20, 10),
                Background = Brushes.Transparent,
                BorderThickness = new Thickness(0)
            };
            Grid.SetRow(tabControl, 0);

            var categories = new[]
            {
                InterviewTemplate.Category.Behavioral,
                InterviewTemplate.Category.SystemDesign,
                InterviewTemplate.Category.Coding,
                InterviewTemplate.Category.LanguageSpecific
            };

            // Scroll view container (shared across tabs)
            var scrollViewer = new ScrollViewer
            {
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
                Margin = new Thickness(0, 0, 0, 10)
            };
            Grid.SetRow(scrollViewer, 1);

            var listContainer = new StackPanel
            {
                Margin = new Thickness(15, 10, 15, 10)
            };
            scrollViewer.Content = listContainer;

            // Create tabs
            foreach (var category in categories)
            {
                var tab = new TabItem
                {
                    Header = GetCategoryDisplayName(category),
                    Background = new SolidColorBrush(Color.FromArgb(128, 60, 60, 67)),
                    Foreground = Brushes.White,
                    FontSize = 13,
                    Padding = new Thickness(12, 6, 12, 6)
                };
                tabControl.Items.Add(tab);
            }

            // Handle tab selection changes
            tabControl.SelectionChanged += (s, e) =>
            {
                if (tabControl.SelectedIndex >= 0 && tabControl.SelectedIndex < categories.Length)
                {
                    var selectedCategory = categories[tabControl.SelectedIndex];
                    PopulateTemplateList(listContainer, selectedCategory, dialog);
                }
            };

            mainGrid.Children.Add(tabControl);
            mainGrid.Children.Add(scrollViewer);

            dialog.Content = mainGrid;

            // Populate initial category
            PopulateTemplateList(listContainer, categories[0], dialog);

            dialog.ShowDialog();
        }

        /// <summary>
        /// Populate template list for a specific category.
        /// </summary>
        private void PopulateTemplateList(StackPanel container, InterviewTemplate.Category category, Window dialog)
        {
            container.Children.Clear();

            var templates = BuiltInTemplates.TemplatesForCategory(category);

            foreach (var template in templates)
            {
                var card = CreateTemplateCard(template, dialog);
                container.Children.Add(card);
            }
        }

        /// <summary>
        /// Create a template card UI element.
        /// </summary>
        private Border CreateTemplateCard(InterviewTemplate template, Window dialog)
        {
            var cardHeight = 60 + template.Questions.Count * 28;

            var card = new Border
            {
                Background = new SolidColorBrush(Color.FromArgb(15, 255, 255, 255)), // 6% white
                CornerRadius = new CornerRadius(10),
                Margin = new Thickness(0, 0, 0, 10),
                Padding = new Thickness(15, 10, 15, 10),
                MinHeight = cardHeight
            };

            var grid = new Grid();
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Header
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Description
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // Questions

            // Header row
            var headerGrid = new Grid();
            headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            Grid.SetRow(headerGrid, 0);

            // Title
            var title = new TextBlock
            {
                Text = template.Name,
                Foreground = Brushes.White,
                FontSize = 14,
                FontWeight = FontWeights.SemiBold,
                VerticalAlignment = VerticalAlignment.Center
            };
            Grid.SetColumn(title, 0);
            headerGrid.Children.Add(title);

            // Load button
            var loadButton = new Button
            {
                Content = "Load",
                Width = 80,
                Height = 28,
                FontSize = 12,
                FontWeight = FontWeights.Medium,
                Background = new SolidColorBrush(Color.FromArgb(128, 0, 122, 255)), // Blue
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0),
                Cursor = System.Windows.Input.Cursors.Hand
            };
            loadButton.Click += (s, e) => LoadTemplate(template, dialog);
            Grid.SetColumn(loadButton, 1);
            headerGrid.Children.Add(loadButton);

            grid.Children.Add(headerGrid);

            // Description
            var description = new TextBlock
            {
                Text = template.Description,
                Foreground = new SolidColorBrush(Color.FromArgb(128, 255, 255, 255)), // 50% white
                FontSize = 11,
                Margin = new Thickness(0, 4, 0, 8)
            };
            Grid.SetRow(description, 1);
            grid.Children.Add(description);

            // Questions list
            var questionsPanel = new StackPanel
            {
                Margin = new Thickness(0, 4, 0, 0)
            };
            Grid.SetRow(questionsPanel, 2);

            foreach (var question in template.Questions)
            {
                var questionGrid = new Grid
                {
                    Margin = new Thickness(0, 0, 0, 4)
                };
                questionGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto }); // Dot
                questionGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); // Text

                // Difficulty dot
                var dot = new Ellipse
                {
                    Width = 6,
                    Height = 6,
                    Fill = GetDifficultyBrush(question.QuestionDifficulty),
                    VerticalAlignment = VerticalAlignment.Center,
                    Margin = new Thickness(5, 0, 10, 0)
                };
                Grid.SetColumn(dot, 0);
                questionGrid.Children.Add(dot);

                // Question text
                var questionText = new TextBlock
                {
                    Text = question.Text,
                    Foreground = new SolidColorBrush(Color.FromArgb(179, 255, 255, 255)), // 70% white
                    FontSize = 11,
                    TextTrimming = TextTrimming.CharacterEllipsis,
                    VerticalAlignment = VerticalAlignment.Center
                };
                Grid.SetColumn(questionText, 1);
                questionGrid.Children.Add(questionText);

                questionsPanel.Children.Add(questionGrid);
            }

            grid.Children.Add(questionsPanel);
            card.Child = grid;

            return card;
        }

        /// <summary>
        /// Load template into notes editor.
        /// </summary>
        private void LoadTemplate(InterviewTemplate template, Window dialog)
        {
            // Build markdown outline
            var markdown = $"# {template.Name}\n\n";
            markdown += $"*{template.Description}*\n\n";

            for (int i = 0; i < template.Questions.Count; i++)
            {
                var q = template.Questions[i];
                markdown += $"## {i + 1}. {q.Text}\n\n";
                markdown += $"**Topic:** {q.Topic} | **Difficulty:** {q.DifficultyDisplayName}\n\n";

                if (q.Hints.Count > 0)
                {
                    markdown += "**Hints:**\n";
                    foreach (var hint in q.Hints)
                    {
                        markdown += $"- {hint}\n";
                    }
                    markdown += "\n";
                }

                markdown += "**Your notes:**\n\n\n";
            }

            // Load into notes tab
            SetNotesText(markdown);
            _switchToNotesTabCallback?.Invoke();
            _renderMarkdownCallback?.Invoke();

            // Close the dialog
            dialog.Close();

            StealthLogger.Shared.Log($"📋 Loaded template: {template.Name}");
        }

        /// <summary>
        /// Set text in notes RichTextBox.
        /// </summary>
        private void SetNotesText(string text)
        {
            var textRange = new System.Windows.Documents.TextRange(
                _notesTextView.Document.ContentStart,
                _notesTextView.Document.ContentEnd);
            textRange.Text = text;
        }

        /// <summary>
        /// Get difficulty color brush.
        /// </summary>
        private Brush GetDifficultyBrush(TemplateQuestion.Difficulty difficulty)
        {
            return difficulty switch
            {
                TemplateQuestion.Difficulty.Easy => new SolidColorBrush(Color.FromRgb(52, 199, 89)), // Green
                TemplateQuestion.Difficulty.Medium => new SolidColorBrush(Color.FromRgb(255, 149, 0)), // Orange
                TemplateQuestion.Difficulty.Hard => new SolidColorBrush(Color.FromRgb(255, 59, 48)), // Red
                _ => Brushes.Gray
            };
        }

        /// <summary>
        /// Get category display name.
        /// </summary>
        private string GetCategoryDisplayName(InterviewTemplate.Category category)
        {
            return category switch
            {
                InterviewTemplate.Category.Behavioral => "Behavioral",
                InterviewTemplate.Category.SystemDesign => "System Design",
                InterviewTemplate.Category.Coding => "Coding",
                InterviewTemplate.Category.LanguageSpecific => "Language-Specific",
                _ => category.ToString()
            };
        }
    }
}

