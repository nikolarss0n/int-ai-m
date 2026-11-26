using System;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Threading;
using InterviewMasterApp.Presentation.Styling;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    public class NotesEditor : IDisposable
    {
        private readonly RichTextBox _notesTextBox;
        private readonly RichTextBox? _analysisTextBox;
        private readonly FormattingToolbar? _formattingToolbar;
        private DispatcherTimer? _saveTimer;
        private bool _isUpdating;

        private static string NotesFilePath =>
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "InterviewMaster", "notes.md");

        public string CachedPlainText { get; private set; } = string.Empty;

        public NotesEditor(RichTextBox notesTextBox, RichTextBox? analysisTextBox = null, FormattingToolbar? formattingToolbar = null)
        {
            _notesTextBox = notesTextBox ?? throw new ArgumentNullException(nameof(notesTextBox));
            _analysisTextBox = analysisTextBox;
            _formattingToolbar = formattingToolbar;

            _notesTextBox.TextChanged += OnTextChanged;
            _notesTextBox.SelectionChanged += OnSelectionChanged;
        }

        public void LoadNotes()
        {
            try
            {
                if (File.Exists(NotesFilePath))
                {
                    var text = File.ReadAllText(NotesFilePath);
                    SetPlainText(_notesTextBox, text);
                    CachedPlainText = text;
                }
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"Failed to load notes: {ex.Message}");
            }
        }

        public void SaveNotes()
        {
            try
            {
                var text = GetPlainText(_notesTextBox);
                CachedPlainText = text;
                var dir = Path.GetDirectoryName(NotesFilePath);
                if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
                File.WriteAllText(NotesFilePath, text);
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"Failed to save notes: {ex.Message}");
            }
        }

        public void RenderMarkdown()
        {
            // Keep editable plain text synced; full formatted rendering is available in preview/analysis boxes.
            CachedPlainText = GetPlainText(_notesTextBox);
        }

        public void RenderAnalysisMarkdown(string markdown)
        {
            if (_analysisTextBox == null) return;
            _analysisTextBox.Document = FlowDocumentMarkdownRenderer.Render(markdown, DesignTokens.FontSizes.Body);
        }

        private void OnTextChanged(object sender, TextChangedEventArgs e)
        {
            if (_isUpdating) return;
            CachedPlainText = GetPlainText(_notesTextBox);
            HandleListAutoContinuation();

            _saveTimer?.Stop();
            _saveTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1.2) };
            _saveTimer.Tick += (_, _) => { _saveTimer?.Stop(); SaveNotes(); };
            _saveTimer.Start();
        }

        private void OnSelectionChanged(object sender, RoutedEventArgs e)
        {
            if (_formattingToolbar == null) return;
            if (!_notesTextBox.Selection.IsEmpty) _formattingToolbar.ShowToolbar();
            else _formattingToolbar.HideToolbar();
        }

        private void HandleListAutoContinuation()
        {
            try
            {
                var caret = _notesTextBox.CaretPosition;
                var before = new TextRange(_notesTextBox.Document.ContentStart, caret).Text;
                if (string.IsNullOrEmpty(before) || (!before.EndsWith("\r\n") && !before.EndsWith("\n"))) return;

                var lines = before.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None);
                if (lines.Length < 2) return;
                var prev = lines[^2];
                if (!prev.StartsWith("- ", StringComparison.Ordinal)) return;

                _isUpdating = true;
                try
                {
                    if (string.IsNullOrWhiteSpace(prev[2..]))
                    {
                        // Remove the empty "- " bullet paragraph cleanly
                        var prevPara = caret.Paragraph?.PreviousBlock as Paragraph;
                        if (prevPara != null) prevPara.Inlines.Clear();
                    }
                    else
                    {
                        caret.InsertTextInRun("- ");
                    }
                }
                finally { _isUpdating = false; }
            }
            catch { }
        }

        private static string GetPlainText(RichTextBox rtb) =>
            new TextRange(rtb.Document.ContentStart, rtb.Document.ContentEnd).Text ?? string.Empty;

        private static void SetPlainText(RichTextBox rtb, string text)
        {
            rtb.Document.Blocks.Clear();
            rtb.Document.Blocks.Add(new Paragraph(new Run(text ?? string.Empty)));
        }

        public void Dispose()
        {
            _saveTimer?.Stop();
            _saveTimer = null;
            _notesTextBox.TextChanged -= OnTextChanged;
            _notesTextBox.SelectionChanged -= OnSelectionChanged;
        }
    }
}
