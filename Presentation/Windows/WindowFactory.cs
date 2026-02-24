using System;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Effects;

namespace InterviewMasterApp.Presentation.Windows
{
    public sealed class StealthLogger
    {
        private static readonly Lazy<StealthLogger> _lazy = new(() => new StealthLogger());
        public static StealthLogger Shared => _lazy.Value;

        private readonly string _logFile;

        private StealthLogger()
        {
            _logFile = Path.Combine(Path.GetTempPath(), "stealth_log.txt");
            try { File.WriteAllText(_logFile, "=== STEALTH LOG STARTED ===\n"); } catch { }
            Log("App started - logging interactions");
        }

        public void Log(string message)
        {
            var line = $"[{DateTime.Now:HH:mm:ss.fff}] {message}\n";
            try
            {
                File.AppendAllText(_logFile, line);
            }
            catch { }
        }
    }

    /// <summary>
    /// Non-activating window (best-effort for WPF).
    /// </summary>
    public class StealthWindow : Window
    {
        public StealthWindow()
        {
            ShowActivated = false; // best-effort
        }

        protected override void OnActivated(EventArgs e)
        {
            base.OnActivated(e);
            // Avoid stealing focus (best-effort)
            StealthLogger.Shared.Log("Activated (focus may have been requested)");
        }
    }

    public static class WindowFactory
    {
        public static Window CreateMainWindow()
        {
            var win = new Window
            {
                Width = 700,
                Height = 500,
                WindowStyle = WindowStyle.SingleBorderWindow,
                Title = "Interview Master",
                ShowInTaskbar = true
            };
            return win;
        }

        /// <summary>
        /// Create a glass-like background view for a WPF container.
        /// </summary>
        public static Border CreateGlassBackground(FrameworkElement parent)
        {
            var border = new Border
            {
                Width = parent.ActualWidth,
                Height = parent.ActualHeight,
                Background = new SolidColorBrush(Color.FromArgb(200, 25, 25, 30)),
                Effect = new BlurEffect { Radius = 8 }
            };
            return border;
        }
    }
}
