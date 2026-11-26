using System;
using System.IO;
using System.Runtime.CompilerServices;

namespace InterviewMasterApp.Infrastructure
{
    public sealed class DebugLogger
    {
        private static readonly Lazy<DebugLogger> _shared = new(() => new DebugLogger());
        public static DebugLogger Shared => _shared.Value;

        private readonly string _logFilePath;
        private readonly string _timeFormat = "HH:mm:ss.fff";
        private readonly object _fileLock = new();

        public string LogFilePath => _logFilePath;

        private DebugLogger()
        {
            var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            var logDir = Path.Combine(localAppData, "InterviewMaster");
            try { Directory.CreateDirectory(logDir); } catch { }
            _logFilePath = Path.Combine(logDir, "interview_debug.log");
        }

        public void Clear()
        {
            lock (_fileLock)
            {
                try { File.WriteAllText(_logFilePath, string.Empty); } catch { }
            }
            Log("=== Interview Master Started ===");
        }

        public void Log(string message, [CallerFilePath] string file = "", [CallerMemberName] string function = "", [CallerLineNumber] int line = 0)
        {
            var timestamp = DateTime.Now.ToString(_timeFormat);
            var fileName = string.Empty;
            try { fileName = Path.GetFileNameWithoutExtension(file); } catch { fileName = file; }
            var entry = $"[{timestamp}] [{fileName}:{line}] {message}{Environment.NewLine}";

            lock (_fileLock)
            {
                try
                {
                    File.AppendAllText(_logFilePath, entry);
                }
                catch
                {
                    try { File.WriteAllText(_logFilePath, entry); } catch { }
                }
            }

            System.Diagnostics.Debug.WriteLine(entry.TrimEnd());
        }

        public void Log(LogCategory category, string message, [CallerFilePath] string file = "", [CallerMemberName] string function = "", [CallerLineNumber] int line = 0)
        {
            Log($"{category.GetPrefix()} {message}", file, function, line);
        }

        public enum LogCategory
        {
            Audio,
            Transcription,
            Classification,
            Answer,
            Stream,
            Error,
            Delegate
        }
    }

    public static class DebugLoggerExtensions
    {
        public static string GetPrefix(this DebugLogger.LogCategory cat) => cat switch
        {
            DebugLogger.LogCategory.Audio => "AUDIO:",
            DebugLogger.LogCategory.Transcription => "STT:",
            DebugLogger.LogCategory.Classification => "CLASSIFY:",
            DebugLogger.LogCategory.Answer => "ANSWER:",
            DebugLogger.LogCategory.Stream => "STREAM:",
            DebugLogger.LogCategory.Error => "ERROR:",
            DebugLogger.LogCategory.Delegate => "DELEGATE:",
            _ => "LOG:"
        };
    }
}
