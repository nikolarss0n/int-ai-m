using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Ghost Mode (Interview Mode) - transparent, click-through mode using Win32 WS_EX_TRANSPARENT.
    /// </summary>
    public class GhostMode
    {
        [DllImport("user32.dll")]
        private static extern int GetWindowLong(IntPtr hwnd, int index);

        [DllImport("user32.dll")]
        private static extern int SetWindowLong(IntPtr hwnd, int index, int newStyle);

        [DllImport("user32.dll")]
        private static extern bool SetWindowDisplayAffinity(IntPtr hwnd, uint dwAffinity);

        private const int GWL_EXSTYLE = -20;
        private const int WS_EX_TRANSPARENT = 0x00000020;
        private const uint WDA_NONE = 0x00000000;
        private const uint WDA_EXCLUDEFROMCAPTURE = 0x00000011;

        private readonly Window _window;
        private readonly FloatingSolutionWindowController? _floatingSolutionController;
        private readonly ScreenshotAlertWindow? _screenshotAlertWindow;
        private bool _isInterviewModeActive;
        private int _originalExStyle;

        public bool IsInterviewModeActive => _isInterviewModeActive;

        public GhostMode(Window window, FloatingSolutionWindowController? floatingController = null, ScreenshotAlertWindow? screenshotAlert = null)
        {
            _window = window ?? throw new ArgumentNullException(nameof(window));
            _floatingSolutionController = floatingController;
            _screenshotAlertWindow = screenshotAlert;
        }

        /// <summary>
        /// Toggle interview mode (ghost mode) - makes window transparent and click-through using Win32 API.
        /// </summary>
        public void ToggleInterviewMode()
        {
            _isInterviewModeActive = !_isInterviewModeActive;

            var hwnd = new WindowInteropHelper(_window).Handle;

            if (_isInterviewModeActive)
            {
                StealthLogger.Shared.Log("GHOST MODE: ON (transparent + click-through)");

                // Keep window on top
                _window.Topmost = true;

                // Clear any held animation on Opacity (WPF animations block direct property sets)
                _window.BeginAnimation(UIElement.OpacityProperty, null);
                _window.Opacity = 0.65;

                if (hwnd != IntPtr.Zero)
                {
                    // Save original style and add WS_EX_TRANSPARENT for click-through
                    _originalExStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
                    SetWindowLong(hwnd, GWL_EXSTYLE, _originalExStyle | WS_EX_TRANSPARENT);

                    // Hide from screen sharing, screenshots, and recordings
                    SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE);
                }

                _window.Title = "Interview Master [GHOST MODE]";
            }
            else
            {
                StealthLogger.Shared.Log("GHOST MODE: OFF (normal)");

                // Clear animation hold and restore full opacity
                _window.BeginAnimation(UIElement.OpacityProperty, null);
                _window.Opacity = 1.0;

                if (hwnd != IntPtr.Zero)
                {
                    // Restore original extended style (removes TRANSPARENT)
                    SetWindowLong(hwnd, GWL_EXSTYLE, _originalExStyle);

                    // Make window visible in screen sharing again
                    SetWindowDisplayAffinity(hwnd, WDA_NONE);
                }

                _window.Topmost = false;
                _window.Title = "Interview Master";
            }
        }

        /// <summary>
        /// Toggle window visibility with fade animation.
        /// </summary>
        public void ToggleWindowVisibility()
        {
            if (_window.IsVisible)
            {
                var fadeOut = new DoubleAnimation(1.0, 0.0, TimeSpan.FromMilliseconds(200));
                fadeOut.Completed += (s, e) =>
                {
                    _window.Hide();
                    _window.Opacity = 1.0;
                    _window.ShowInTaskbar = false;

                    if (_isInterviewModeActive)
                    {
                        _isInterviewModeActive = false;
                        var hwnd = new WindowInteropHelper(_window).Handle;
                        if (hwnd != IntPtr.Zero)
                        {
                            SetWindowLong(hwnd, GWL_EXSTYLE, _originalExStyle);
                        }
                        _window.Title = "Interview Master";
                    }
                };
                _window.BeginAnimation(UIElement.OpacityProperty, fadeOut);
            }
            else
            {
                _window.Opacity = 0;
                _window.Show();
                _window.ShowInTaskbar = true;
                _window.Activate();

                HideScreenshotAlert();

                var fadeIn = new DoubleAnimation(0.0, 1.0, TimeSpan.FromMilliseconds(200));
                _window.BeginAnimation(UIElement.OpacityProperty, fadeIn);
            }
        }

        public void HideFloatingSolution()
        {
            _floatingSolutionController?.Dismiss();
        }

        public void UpdateFloatingQA()
        {
            _floatingSolutionController?.UpdateQA();
        }

        private void HideScreenshotAlert()
        {
            if (_screenshotAlertWindow != null && _screenshotAlertWindow.IsVisible)
            {
                _screenshotAlertWindow.Hide();
            }
        }
    }
}
