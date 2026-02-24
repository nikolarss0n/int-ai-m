using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Windows;
using Microsoft.Win32;
using InterviewMasterApp.Application.UseCases;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Interview export functionality - save interview transcripts to Markdown or JSON.
    /// Ported from Swift: InterviewExport.swift
    /// Provides export dialog with format selection and auto-save capability.
    /// </summary>
    public class InterviewExport
    {
        private readonly List<InterviewMessage> _voiceMessages;

        public InterviewExport(List<InterviewMessage> voiceMessages)
        {
            _voiceMessages = voiceMessages ?? throw new ArgumentNullException(nameof(voiceMessages));
        }

        /// <summary>
        /// Export interview to file with user-selected format and location.
        /// </summary>
        public void ExportInterview()
        {
            var exportableMessages = _voiceMessages.Where(msg =>
                msg.Type == InterviewMessage.MessageType.Question ||
                msg.Type == InterviewMessage.MessageType.Answer ||
                msg.Type == InterviewMessage.MessageType.FollowUp ||
                msg.Type == InterviewMessage.MessageType.CodingTask
            ).ToList();

            if (exportableMessages.Count == 0)
            {
                MessageBox.Show(
                    "Start an interview and have some Q&A before exporting.",
                    "Nothing to Export",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
                return;
            }

            var saveDialog = new SaveFileDialog
            {
                Title = "Export Interview",
                FileName = $"interview_{FormattedDateForFilename()}.md",
                Filter = "Markdown files (*.md)|*.md|JSON files (*.json)|*.json",
                FilterIndex = 1,
                AddExtension = true
            };

            if (saveDialog.ShowDialog() == true)
            {
                try
                {
                    // Determine format from file extension
                    var format = saveDialog.FileName.EndsWith(".json", StringComparison.OrdinalIgnoreCase)
                        ? ExportFormat.Json
                        : ExportFormat.Markdown;

                    var useCase = new ExportInterviewUseCase();
                    var content = useCase.Execute(exportableMessages, format);

                    File.WriteAllText(saveDialog.FileName, content);

                    // Open containing folder and select the file
                    System.Diagnostics.Process.Start("explorer.exe", $"/select,\"{saveDialog.FileName}\"");

                    StealthLogger.Shared.Log($"📁 Exported interview to {saveDialog.FileName}");
                }
                catch (Exception ex)
                {
                    MessageBox.Show(
                        ex.Message,
                        "Export Failed",
                        MessageBoxButton.OK,
                        MessageBoxImage.Error);

                    StealthLogger.Shared.Log($"❌ Export failed: {ex.Message}");
                }
            }
        }

        /// <summary>
        /// Auto-save session to Documents folder in JSON format.
        /// Called periodically during interview or when significant events occur.
        /// </summary>
        public void AutoSaveSession()
        {
            var exportableMessages = _voiceMessages.Where(msg =>
                msg.Type == InterviewMessage.MessageType.Question ||
                msg.Type == InterviewMessage.MessageType.Answer ||
                msg.Type == InterviewMessage.MessageType.FollowUp ||
                msg.Type == InterviewMessage.MessageType.CodingTask
            ).ToList();

            if (exportableMessages.Count == 0)
                return;

            try
            {
                // Create auto-save directory in Documents
                var documentsPath = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
                var sessionDir = Path.Combine(documentsPath, "InterviewMaster", "sessions");
                Directory.CreateDirectory(sessionDir);

                var useCase = new ExportInterviewUseCase();
                var json = useCase.Execute(exportableMessages, ExportFormat.Json);

                var filename = $"session_{FormattedDateForFilename()}.json";
                var filePath = Path.Combine(sessionDir, filename);

                File.WriteAllText(filePath, json);

                StealthLogger.Shared.Log($"📁 Auto-saved session to {filePath}");
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"⚠️ Auto-save failed: {ex.Message}");
                // Silent fail for auto-save - don't interrupt user
            }
        }

        /// <summary>
        /// Clean user response text from common ASR hallucinations and noise.
        /// Removes garbage prefixes, non-ASCII characters, and detects sentence boundaries.
        /// </summary>
        public static string CleanUserResponse(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
                return string.Empty;

            var cleaned = text;

            // Remove leading non-ASCII or control characters
            while (cleaned.Length > 0)
            {
                var firstChar = cleaned[0];
                if (firstChar >= 32 && firstChar < 127)
                    break;
                cleaned = cleaned.Substring(1);
            }

            // Remove common ASR hallucination prefixes
            var hallucinationPrefixes = new[]
            {
                "tabii,", "tabii", "tabibi", "merci beaucoup", "merci", "gracias",
                "thank you for watching", "thanks for watching", "subscribe",
                "reunited with", "accidental", "nexus,", "nexus"
            };

            var lowerCleaned = cleaned.ToLowerInvariant();
            foreach (var prefix in hallucinationPrefixes)
            {
                if (lowerCleaned.StartsWith(prefix))
                {
                    cleaned = cleaned.Substring(prefix.Length).TrimStart();
                    break;
                }
            }

            // If first character is lowercase, try to find the actual sentence start
            if (cleaned.Length > 0 && char.IsLower(cleaned[0]))
            {
                var words = cleaned.Split(new[] { ' ' }, 11, StringSplitOptions.RemoveEmptyEntries);
                for (int i = 0; i < words.Length; i++)
                {
                    if (words[i].Length > 0 && char.IsUpper(words[i][0]) && i > 0)
                    {
                        var restOfSentence = string.Join(" ", words.Skip(i));
                        if (restOfSentence.Length > 10)
                        {
                            cleaned = restOfSentence;
                            break;
                        }
                    }
                }
            }

            return cleaned.Trim();
        }

        /// <summary>
        /// Format current date/time for filename (yyyy-MM-dd_HHmm).
        /// </summary>
        private string FormattedDateForFilename()
        {
            return DateTime.Now.ToString("yyyy-MM-dd_HHmm", CultureInfo.InvariantCulture);
        }
    }
}

