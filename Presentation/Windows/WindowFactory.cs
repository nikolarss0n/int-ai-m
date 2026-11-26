using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Effects;

namespace InterviewMasterApp.Presentation.Windows
{
    public sealed class StealthLogger
    {
        private static readonly Lazy<StealthLogger> _lazy = new(() => new StealthLogger());
        public static StealthLogger Shared => _lazy.Value;

        private readonly string _logFile;
        private readonly object _lock = new();

        private StealthLogger()
        {
            var dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "InterviewMaster");
            try { Directory.CreateDirectory(dir); } catch { }
            _logFile = Path.Combine(dir, "stealth_log.txt");
            try { File.WriteAllText(_logFile, "=== STEALTH LOG STARTED ===\n"); } catch { }
        }

        public void Log(string message)
        {
            var line = $"[{DateTime.Now:HH:mm:ss.fff}] {message}\n";
            lock (_lock)
            {
                try { File.AppendAllText(_logFile, line); } catch { }
            }
        }
    }

    public static class StealthWindowHelper
    {
        [DllImport("user32.dll")]
        private static extern bool SetWindowDisplayAffinity(IntPtr hwnd, uint dwAffinity);

        [DllImport("user32.dll")]
        private static extern int GetWindowLong(IntPtr hwnd, int index);

        [DllImport("user32.dll")]
        private static extern int SetWindowLong(IntPtr hwnd, int index, int newStyle);

        private const int GWL_EXSTYLE = -20;
        private const int WS_EX_NOACTIVATE = 0x08000000;
        private const uint WDA_NONE = 0x00000000;
        private const uint WDA_EXCLUDEFROMCAPTURE = 0x00000011;

        public static void SetExcludeFromCapture(Window window, bool exclude)
        {
            if (window == null) return;
            var hwnd = new WindowInteropHelper(window).Handle;
            if (hwnd == IntPtr.Zero) return;
            try
            {
                SetWindowDisplayAffinity(hwnd, exclude ? WDA_EXCLUDEFROMCAPTURE : WDA_NONE);
            }
            catch { }
        }

        public static void ApplyNoActivate(Window window)
        {
            if (window == null) return;
            var hwnd = new WindowInteropHelper(window).Handle;
            if (hwnd == IntPtr.Zero) return;
            try
            {
                var exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
                SetWindowLong(hwnd, GWL_EXSTYLE, exStyle | WS_EX_NOACTIVATE);
            }
            catch { }
        }
    }

    /// <summary>
    /// Non-activating, capture-excluded floating window for stealth overlays on Windows.
    /// Uses Win32 WS_EX_NOACTIVATE, WM_MOUSEACTIVATE (MA_NOACTIVATE), and WDA_EXCLUDEFROMCAPTURE.
    /// </summary>
    public class StealthWindow : Window
    {
        private const int WM_MOUSEACTIVATE = 0x0021;
        private const int MA_NOACTIVATE = 3;

        public StealthWindow()
        {
            ShowActivated = false;
            SourceInitialized += OnSourceInitialized;
        }

        private void OnSourceInitialized(object? sender, EventArgs e)
        {
            StealthWindowHelper.ApplyNoActivate(this);
            StealthWindowHelper.SetExcludeFromCapture(this, exclude: true);

            var hwnd = new WindowInteropHelper(this).Handle;
            var source = HwndSource.FromHwnd(hwnd);
            source?.AddHook(WndProc);
        }

        private static IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == WM_MOUSEACTIVATE)
            {
                handled = true;
                return new IntPtr(MA_NOACTIVATE);
            }
            return IntPtr.Zero;
        }
    }

    public static class WindowFactory
    {
        public static Window CreateMainWindow() => new()
        {
            Width = 1040,
            Height = 700,
            WindowStyle = WindowStyle.None,
            AllowsTransparency = true,
            Background = Brushes.Transparent,
            Title = "Interview Master",
            ShowInTaskbar = true
        };

        public static Border CreateGlassBackground(FrameworkElement parent) => new()
        {
            Background = new SolidColorBrush(Color.FromArgb(220, 27, 27, 29)),
            Effect = new BlurEffect { Radius = 8 }
        };
    }
}
