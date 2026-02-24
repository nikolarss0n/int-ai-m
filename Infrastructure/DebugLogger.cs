using System;
using System.IO;
using System.Runtime.CompilerServices;
using System.Threading;

namespace InterviewMasterApp.Infrastructure
{
    /// <summary>
    /// Simple file logger for debugging main functionality
    /// Log file is cleared on each app start
    /// </summary>
    public sealed class DebugLogger
    {
        private static readonly Lazy<DebugLogger> _shared = new(() => new DebugLogger());
        public static DebugLogger Shared => _shared.Value;

        private readonly string _logFilePath;
        private readonly string _timeFormat = "HH:mm:ss.fff";
        private readonly object _fileLock = new();

        private DebugLogger()
        {
            var cwd = Directory.GetCurrentDirectory();
            _logFilePath = Path.Combine(cwd, "interview_debug.log");
        }

        /// <summary>
        /// Clear the log file (call on app start)
        /// </summary>
        public void Clear()
        {
            lock (_fileLock)
            {
                try
                {
                    File.WriteAllText(_logFilePath, string.Empty);
                }
                catch
                {
                    // ignore
                }
            }

            Log("=== Interview Master Started ===");
        }

        /// <summary>
        /// Log a message with timestamp and caller info
        /// </summary>
        public void Log(string message, [CallerFilePath] string file = "", [CallerMemberName] string function = "", [CallerLineNumber] int line = 0)
        {
            var timestamp = DateTime.Now.ToString(_timeFormat);
            var fileName = string.Empty;
            try
            {
                fileName = Path.GetFileNameWithoutExtension(file);
            }
            catch
            {
                fileName = file;
            }

            var entry = $"[{timestamp}] [{fileName}:{line}] {message}{Environment.NewLine}";

            // Async-safe append using a lock to preserve ordering
            lock (_fileLock)
            {
                try
                {
                    File.AppendAllText(_logFilePath, entry);
                }
                catch
                {
                    // If append fails, try to create the file
                    try
                    {
                        File.WriteAllText(_logFilePath, entry);
                    }
                    catch
                    {
                        // swallow
                    }
                }
            }

            // Also print to console for immediate feedback
            try
            {
                Console.WriteLine($"📝 {message}");
            }
            catch
            {
            }
        }

        /// <summary>
        /// Log with category prefix
        /// </summary>
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
            DebugLogger.LogCategory.Audio => "🎤 AUDIO:",
            DebugLogger.LogCategory.Transcription => "📝 TRANSCRIBE:",
            DebugLogger.LogCategory.Classification => "🏷️ CLASSIFY:",
            DebugLogger.LogCategory.Answer => "💬 ANSWER:",
            DebugLogger.LogCategory.Stream => "📡 STREAM:",
            DebugLogger.LogCategory.Error => "❌ ERROR:",
            DebugLogger.LogCategory.Delegate => "📤 DELEGATE:",
            _ => string.Empty,
        };

        // Convenience helpers to mimic the Swift global functions
        public static void DebugLog(string message, [CallerFilePath] string file = "", [CallerMemberName] string function = "", [CallerLineNumber] int line = 0)
        {
            DebugLogger.Shared.Log(message, file, function, line);
        }

        public static void DebugLog(DebugLogger.LogCategory category, string message, [CallerFilePath] string file = "", [CallerMemberName] string function = "", [CallerLineNumber] int line = 0)
        {
            DebugLogger.Shared.Log(category, message, file, function, line);
        }
    }
}

