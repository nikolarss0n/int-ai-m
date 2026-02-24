using System;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using InterviewMasterApp.Presentation.Styling;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Notes editor functionality - markdown rendering, auto-save, and list continuation.
    /// Ported from Swift: NotesEditor.swift
    /// Handles real-time markdown rendering with debouncing and smart list formatting.
    /// </summary>
    public class NotesEditor : IDisposable
    {
        private readonly RichTextBox _notesTextBox;
        private readonly RichTextBox? _analysisTextBox;
        private readonly MarkdownRenderer _notesMarkdownRenderer;
        private readonly MarkdownRenderer _analysisMarkdownRenderer;
        private readonly FormattingToolbar? _formattingToolbar;

        private DispatcherTimer? _renderTimer;
        private int _lastTextLength;
        private string _notesFilePath;

        public NotesEditor(RichTextBox notesTextBox, RichTextBox? analysisTextBox = null, FormattingToolbar? formattingToolbar = null)
        {
            _notesTextBox = notesTextBox ?? throw new ArgumentNullException(nameof(notesTextBox));
            _analysisTextBox = analysisTextBox;
            _formattingToolbar = formattingToolbar;

            _notesMarkdownRenderer = new MarkdownRenderer(MarkdownRenderer.Style.Notes);
            _analysisMarkdownRenderer = new MarkdownRenderer(MarkdownRenderer.Style.Analysis);

            // Setup auto-save file path
            var appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            var appFolder = Path.Combine(appDataPath, "InterviewMaster");
            Directory.CreateDirectory(appFolder);
            _notesFilePath = Path.Combine(appFolder, "notes.txt");

            // Setup event handlers
            _notesTextBox.TextChanged += OnTextChanged;
            _notesTextBox.SelectionChanged += OnSelectionChanged;

            // Load saved notes
            LoadNotes();
        }

        /// <summary>
        /// Render markdown in the notes text box.
        /// </summary>
        public void RenderMarkdown()
        {
            try
            {
                var plainText = GetPlainText(_notesTextBox);
                var styledText = _notesMarkdownRenderer.Render(plainText);
                ApplyStyledText(_notesTextBox, styledText, plainText);
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"❌ Error rendering notes markdown: {ex.Message}");
            }
        }

        /// <summary>
        /// Render markdown in the analysis text box.
        /// </summary>
        public void RenderAnalysisMarkdown()
        {
            if (_analysisTextBox == null)
                return;

            try
            {
                var plainText = GetPlainText(_analysisTextBox);
                var styledText = _analysisMarkdownRenderer.Render(plainText);
                ApplyStyledText(_analysisTextBox, styledText, plainText);
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"❌ Error rendering analysis markdown: {ex.Message}");
            }
        }

        /// <summary>
        /// Handle text changed event with debounced markdown rendering.
        /// </summary>
        private void OnTextChanged(object sender, TextChangedEventArgs e)
        {
            if (sender != _notesTextBox)
                return;

            var plainText = GetPlainText(_notesTextBox);
            var currentLength = plainText.Length;
            var textGrew = currentLength > _lastTextLength;

            // Only auto-continue lists when text grew (not when deleting)
            if (textGrew)
            {
                HandleListAutoContinuation();
            }

            _lastTextLength = currentLength;

            // Auto-save notes
            SaveNotes();

            // Debounced markdown rendering (300ms delay)
            _renderTimer?.Stop();
            _renderTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromMilliseconds(300)
            };
            _renderTimer.Tick += (s, args) =>
            {
                _renderTimer?.Stop();
                RenderMarkdown();
            };
            _renderTimer.Start();
        }

        /// <summary>
        /// Handle selection changed event - show formatting toolbar.
        /// </summary>
        private void OnSelectionChanged(object sender, RoutedEventArgs e)
        {
            if (sender != _notesTextBox)
                return;

            // Show toolbar when editing notes
            _formattingToolbar?.ShowFormattingToolbar();
        }

        /// <summary>
        /// Save notes to local storage.
        /// </summary>
        public void SaveNotes()
        {
            try
            {
                var plainText = GetPlainText(_notesTextBox);
                File.WriteAllText(_notesFilePath, plainText);
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"⚠️ Failed to save notes: {ex.Message}");
            }
        }

        /// <summary>
        /// Load notes from local storage.
        /// </summary>
        public void LoadNotes()
        {
            try
            {
                if (File.Exists(_notesFilePath))
                {
                    var savedNotes = File.ReadAllText(_notesFilePath);
                    SetPlainText(_notesTextBox, savedNotes);
                    _lastTextLength = savedNotes.Length;
                    RenderMarkdown();
                }
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"⚠️ Failed to load notes: {ex.Message}");
            }
        }

        /// <summary>
        /// Handle automatic list continuation (adds "- " when Enter is pressed in a list).
        /// </summary>
        private void HandleListAutoContinuation()
        {
            try
            {
                var plainText = GetPlainText(_notesTextBox);
                var caretPosition = _notesTextBox.CaretPosition;

                // Get the text before cursor
                var textRange = new TextRange(_notesTextBox.Document.ContentStart, caretPosition);
                var textBeforeCursor = textRange.Text;

                if (string.IsNullOrEmpty(textBeforeCursor) || textBeforeCursor.Length < 2)
                    return;

                // Check if user just pressed Enter (newline at cursor-1)
                if (!textBeforeCursor.EndsWith("\r\n") && !textBeforeCursor.EndsWith("\n"))
                    return;

                // Find the start of the previous line
                var lines = textBeforeCursor.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None);
                if (lines.Length < 2)
                    return;

                var previousLine = lines[lines.Length - 2]; // -2 because last element is empty after newline

                // Check if previous line starts with "- " or is just "- "
                if (previousLine.StartsWith("- "))
                {
                    var content = previousLine.Substring(2).Trim();

                    if (string.IsNullOrEmpty(content))
                    {
                        // Previous line was just "- " (empty bullet), remove it and stop list
                        // This requires more complex editing - for now, just don't add new bullet
                        // TODO: Implement removal of empty bullet line
                    }
                    else
                    {
                        // Add new bullet for next item
                        _notesTextBox.CaretPosition.InsertTextInRun("- ");
                    }
                }
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"⚠️ Error in list auto-continuation: {ex.Message}");
            }
        }

        /// <summary>
        /// Get plain text from RichTextBox.
        /// </summary>
        private string GetPlainText(RichTextBox richTextBox)
        {
            var textRange = new TextRange(richTextBox.Document.ContentStart, richTextBox.Document.ContentEnd);
            return textRange.Text;
        }

        /// <summary>
        /// Set plain text in RichTextBox.
        /// </summary>
        private void SetPlainText(RichTextBox richTextBox, string text)
        {
            var textRange = new TextRange(richTextBox.Document.ContentStart, richTextBox.Document.ContentEnd);
            textRange.Text = text;
        }

        /// <summary>
        /// Apply styled text to RichTextBox.
        /// Note: This is a simplified implementation. For full markdown rendering,
        /// you would need to parse the StyledText runs and apply formatting.
        /// </summary>
        private void ApplyStyledText(RichTextBox richTextBox, StyledText styledText, string plainText)
        {
            // For WPF, we need to apply formatting to the FlowDocument
            // This is complex in RichTextBox - for now, we'll just keep the plain text
            // A full implementation would:
            // 1. Clear existing formatting
            // 2. Parse StyledText runs
            // 3. Apply TextElement formatting (Bold, Italic, Foreground, Background, FontSize, etc.)
            // 4. Handle code blocks with different font family

            // Simplified: Just ensure text is present
            // TODO: Implement full styled text rendering using FlowDocument formatting

            // For now, at least apply some basic markdown-style formatting
            ApplyBasicMarkdownFormatting(richTextBox);
        }

        /// <summary>
        /// Apply basic markdown formatting to RichTextBox (simplified approach).
        /// </summary>
        private void ApplyBasicMarkdownFormatting(RichTextBox richTextBox)
        {
            // This is a placeholder for basic formatting
            // Full implementation would parse markdown and apply TextElement properties
            // For production use, consider using a markdown rendering library or
            // rendering to HTML and displaying in a WebView control
        }

        public void Dispose()
        {
            _renderTimer?.Stop();
            _renderTimer = null;

            if (_notesTextBox != null)
            {
                _notesTextBox.TextChanged -= OnTextChanged;
                _notesTextBox.SelectionChanged -= OnSelectionChanged;
            }
        }
    }
}

