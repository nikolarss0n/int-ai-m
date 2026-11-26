using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using Microsoft.Win32;
using InterviewMasterApp.Application;
using InterviewMasterApp.Application.UseCases;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Infrastructure.Storage;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Handles interview transcript export and auto-save scoped to the latest interview (<see cref="InterviewStartedAt"/>),
    /// plus background session memory analysis via <see cref="SessionAnalysisUseCase"/>.
    /// </summary>
    public class InterviewExport
    {
        private readonly List<InterviewMessage> _voiceMessages;
        private readonly Action<FeedbackNotice, Action?>? _postNotice;

        public DateTime? InterviewStartedAt { get; set; }

        public InterviewExport(List<InterviewMessage> voiceMessages, Action<FeedbackNotice, Action?>? postNotice = null)
        {
            _voiceMessages = voiceMessages ?? throw new ArgumentNullException(nameof(voiceMessages));
            _postNotice = postNotice;
        }

        public void ExportInterview()
        {
            var scoped = ExportInterviewUseCase.MessagesOfInterviewStartedAt(_voiceMessages, InterviewStartedAt);
            var exportable = scoped.Where(IsExportable).ToList();
            if (exportable.Count == 0)
            {
                if (_postNotice != null) _postNotice(FeedbackCopy.NothingToExport, null);
                else MessageBox.Show("Start an interview and have some Q&A before exporting.", "Nothing to Export", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var dlg = new SaveFileDialog
            {
                Title = "Export Interview",
                FileName = $"interview_{FormattedDateForFilename()}.md",
                Filter = "Markdown files (*.md)|*.md|JSON files (*.json)|*.json",
                FilterIndex = 1,
                AddExtension = true
            };

            if (dlg.ShowDialog() != true) return;

            try
            {
                var format = dlg.FileName.EndsWith(".json", StringComparison.OrdinalIgnoreCase)
                    ? ExportFormat.Json
                    : ExportFormat.Markdown;
                var content = new ExportInterviewUseCase().Execute(_voiceMessages, format, InterviewStartedAt);
                File.WriteAllText(dlg.FileName, content);

                var path = dlg.FileName;
                _postNotice?.Invoke(FeedbackCopy.Exported(Path.GetFileName(path), path), () => RevealInExplorer(path));
                StealthLogger.Shared.Log($"Exported interview to {path}");
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "Export Failed", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        public void AutoSaveSession(IAnthropicClient? llmClientForMemory = null)
        {
            var scoped = ExportInterviewUseCase.MessagesOfInterviewStartedAt(_voiceMessages, InterviewStartedAt);
            var exportable = scoped.Where(IsExportable).ToList();
            if (exportable.Count == 0) return;

            try
            {
                var docs = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
                var sessionDir = Path.Combine(docs, "InterviewMaster", "sessions");
                Directory.CreateDirectory(sessionDir);

                var json = new ExportInterviewUseCase().Execute(_voiceMessages, ExportFormat.Json, InterviewStartedAt);
                var fileName = $"session_{FormattedDateForFilename()}.json";
                var filePath = Path.Combine(sessionDir, fileName);
                File.WriteAllText(filePath, json);

                _postNotice?.Invoke(FeedbackCopy.SessionSaved(filePath), () => RevealInExplorer(filePath));
                StealthLogger.Shared.Log($"Auto-saved session to {filePath}");

                if (llmClientForMemory != null)
                {
                    var snapshot = exportable.ToList();
                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            var analyzer = new SessionAnalysisUseCase(MemoryStore.Shared);
                            await analyzer.AnalyzeAsync(snapshot, fileName, llmClientForMemory).ConfigureAwait(false);
                        }
                        catch { }
                    });
                }
            }
            catch (Exception ex)
            {
                _postNotice?.Invoke(FeedbackCopy.SessionNotSaved(ex.Message), ExportInterview);
            }
        }

        private static bool IsExportable(InterviewMessage msg) =>
            msg.Type is InterviewMessage.MessageType.Question
                or InterviewMessage.MessageType.Answer
                or InterviewMessage.MessageType.FollowUp
                or InterviewMessage.MessageType.CodingTask
                or InterviewMessage.MessageType.Briefing;

        private static void RevealInExplorer(string path)
        {
            try { Process.Start("explorer.exe", $"/select,\"{path}\""); } catch { }
        }

        private static string FormattedDateForFilename() =>
            DateTime.Now.ToString("yyyy-MM-dd_HHmm", CultureInfo.InvariantCulture);
    }
}
