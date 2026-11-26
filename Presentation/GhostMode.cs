using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media.Animation;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Ghost Mode (click-through + screen-capture exclusion), visibility fade, and keyboard window movement.
    /// </summary>
    public class GhostMode
    {
        [DllImport("user32.dll")]
        private static extern int GetWindowLong(IntPtr hwnd, int index);

        [DllImport("user32.dll")]
        private static extern int SetWindowLong(IntPtr hwnd, int index, int newStyle);

        private const int GWL_EXSTYLE = -20;
        private const int WS_EX_TRANSPARENT = 0x00000020;

        private readonly Window _window;
        private readonly FloatingSolutionWindowController? _floatingSolutionController;
        private readonly ScreenshotAlertWindow? _screenshotAlertWindow;
        private readonly Action<FeedbackNotice>? _postNotice;

        private bool _isInterviewModeActive;
        private int _originalExStyle;
        private bool _hasSavedExStyle;

        public bool IsInterviewModeActive => _isInterviewModeActive;

        public GhostMode(
            Window window,
            FloatingSolutionWindowController? floatingController = null,
            ScreenshotAlertWindow? screenshotAlert = null,
            Action<FeedbackNotice>? postNotice = null)
        {
            _window = window ?? throw new ArgumentNullException(nameof(window));
            _floatingSolutionController = floatingController;
            _screenshotAlertWindow = screenshotAlert;
            _postNotice = postNotice;
        }

        public void ToggleInterviewMode()
        {
            _isInterviewModeActive = !_isInterviewModeActive;
            var hwnd = new WindowInteropHelper(_window).Handle;

            if (_isInterviewModeActive)
            {
                StealthLogger.Shared.Log("GHOST MODE: ON (transparent + click-through + capture-excluded)");
                _window.Topmost = true;
                _window.BeginAnimation(UIElement.OpacityProperty, null);
                _window.Opacity = 0.72;

                if (hwnd != IntPtr.Zero)
                {
                    _originalExStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
                    _hasSavedExStyle = true;
                    SetWindowLong(hwnd, GWL_EXSTYLE, _originalExStyle | WS_EX_TRANSPARENT);
                    StealthWindowHelper.SetExcludeFromCapture(_window, true);
                }

                _window.Title = "Interview Master [Ghost Mode]";
                _postNotice?.Invoke(FeedbackCopy.ClickThroughOn);
            }
            else
            {
                DisableGhostModeState();
            }
        }

        private void DisableGhostModeState()
        {
            StealthLogger.Shared.Log("GHOST MODE: OFF (normal)");
            _isInterviewModeActive = false;
            _window.BeginAnimation(UIElement.OpacityProperty, null);
            _window.Opacity = 1.0;

            var hwnd = new WindowInteropHelper(_window).Handle;
            if (hwnd != IntPtr.Zero && _hasSavedExStyle)
            {
                SetWindowLong(hwnd, GWL_EXSTYLE, _originalExStyle);
            }
            StealthWindowHelper.SetExcludeFromCapture(_window, false);

            _window.Topmost = false;
            _window.Title = "Interview Master";
        }

        public void ToggleWindowVisibility()
        {
            if (_window.IsVisible)
            {
                var currentOpacity = _window.Opacity;
                var fadeOut = new DoubleAnimation(currentOpacity, 0.0, TimeSpan.FromMilliseconds(180));
                fadeOut.Completed += (_, _) =>
                {
                    _window.Hide();
                    _window.ShowInTaskbar = false;
                    if (_isInterviewModeActive)
                    {
                        // Cleanly restore WS_EX_TRANSPARENT, WDA_NONE, and Topmost
                        DisableGhostModeState();
                    }
                    else
                    {
                        _window.BeginAnimation(UIElement.OpacityProperty, null);
                        _window.Opacity = 1.0;
                    }
                };
                _window.BeginAnimation(UIElement.OpacityProperty, fadeOut);
            }
            else
            {
                _window.BeginAnimation(UIElement.OpacityProperty, null);
                _window.Opacity = 0;
                _window.Show();
                _window.ShowInTaskbar = true;
                _window.Activate();
                HideScreenshotAlert();

                var fadeIn = new DoubleAnimation(0.0, 1.0, TimeSpan.FromMilliseconds(180));
                fadeIn.Completed += (_, _) =>
                {
                    _window.BeginAnimation(UIElement.OpacityProperty, null);
                    _window.Opacity = 1.0;
                };
                _window.BeginAnimation(UIElement.OpacityProperty, fadeIn);
            }
        }

        public void MoveWindowBy(double dx, double dy)
        {
            if (_window.WindowState == WindowState.Maximized)
                _window.WindowState = WindowState.Normal;
            _window.Left += dx;
            _window.Top += dy;
        }

        public void HideFloatingSolution() => _floatingSolutionController?.Dismiss();
        public void UpdateFloatingQA() => _floatingSolutionController?.UpdateQA();

        private void HideScreenshotAlert()
        {
            if (_screenshotAlertWindow != null && _screenshotAlertWindow.IsVisible)
                _screenshotAlertWindow.Hide();
        }
    }
}
