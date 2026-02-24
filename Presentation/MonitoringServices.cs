using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Threading;
using InterviewMasterApp.Domain.Entities;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Monitoring services for screen share detection, focus tracking, and screenshot alerts.
    /// Ported from Swift: MonitoringServices.swift
    /// Provides stealth mode capabilities and app focus monitoring.
    /// </summary>
    public class MonitoringServices : IDisposable
    {
        #region Win32 API Imports

        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        private static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        #endregion

        private readonly Window _window;
        private readonly List<Screenshot> _screenshots;
        private readonly ScreenshotAlertWindow _alertWindowManager;

        private DispatcherTimer? _screenShareTimer;
        private DispatcherTimer? _focusMonitorTimer;
        private DispatcherTimer? _screenshotMonitorTimer;

        private Window? _alertWindow;
        private int _lastScreenshotCount;
        private string _lastFrontApp = string.Empty;

        public bool AutoHideEnabled { get; set; }

        public MonitoringServices(Window window, List<Screenshot> screenshots)
        {
            _window = window ?? throw new ArgumentNullException(nameof(window));
            _screenshots = screenshots ?? throw new ArgumentNullException(nameof(screenshots));
            _alertWindowManager = new ScreenshotAlertWindow();
        }

        /// <summary>
        /// Start monitoring for screen sharing/recording.
        /// Windows doesn't have direct API to detect screen recording, so this is a best-effort implementation.
        /// </summary>
        public void StartScreenShareMonitoring()
        {
            if (!AutoHideEnabled)
                return;

            _screenShareTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(1.0)
            };

            _screenShareTimer.Tick += (s, e) =>
            {
                if (!AutoHideEnabled)
                    return;

                // Windows doesn't have a direct API like macOS's CGPreflightScreenCaptureAccess()
                // Best practice: Hide when other screen recording apps are detected
                if (IsScreenRecordingActive())
                {
                    if (_window.IsVisible)
                    {
                        _window.Hide();
                        StealthLogger.Shared.Log("🎥 Screen recording detected - hiding window");
                    }
                }
            };

            _screenShareTimer.Start();
            StealthLogger.Shared.Log("📺 Screen share monitoring started");
        }

        /// <summary>
        /// Monitor which app has focus - proves browser keeps focus during interactions.
        /// </summary>
        public void StartFocusMonitoring()
        {
            // Check frontmost app every 500ms
            _focusMonitorTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromMilliseconds(500)
            };

            _focusMonitorTimer.Tick += (s, e) =>
            {
                var (appName, processName) = GetForegroundApplication();

                // Only log when frontmost app changes
                if (appName != _lastFrontApp)
                {
                    _lastFrontApp = appName;
                    // Note: "frontmost" = visual layer, NOT keyboard focus
                    // Our app can be frontmost without stealing keyboard focus
                    // Browser blur/visibilitychange events depend on KEYBOARD focus, not frontmost
                    StealthLogger.Shared.Log($"🎯 FRONTMOST APP: {appName} [{processName}] (visual only, not keyboard)");
                }
            };

            _focusMonitorTimer.Start();

            // Monitor keyboard focus events
            _window.Activated += OnWindowActivated;
            _window.Deactivated += OnWindowDeactivated;
            _window.GotKeyboardFocus += OnWindowGotKeyboardFocus;
            _window.LostKeyboardFocus += OnWindowLostKeyboardFocus;

            StealthLogger.Shared.Log("👁️ Focus monitoring started");
            StealthLogger.Shared.Log("   📺 'FRONTMOST APP' = visual layer (OK to be us)");
            StealthLogger.Shared.Log("   ⌨️ 'KEYBOARD FOCUS' = what triggers browser blur (should NEVER be us)");
        }

        /// <summary>
        /// Start monitoring for new screenshots and show alert.
        /// </summary>
        public void StartScreenshotMonitoring()
        {
            _screenshotMonitorTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromMilliseconds(500)
            };

            _screenshotMonitorTimer.Tick += (s, e) =>
            {
                // Check if we have new screenshots and app is not focused
                if (_screenshots.Count > _lastScreenshotCount && !_window.IsActive)
                {
                    ShowScreenshotAlert();
                }

                _lastScreenshotCount = _screenshots.Count;
            };

            _screenshotMonitorTimer.Start();
            StealthLogger.Shared.Log("📸 Screenshot monitoring started");
        }

        /// <summary>
        /// Show screenshot alert window.
        /// </summary>
        public void ShowScreenshotAlert()
        {
            // Don't show if alert already visible
            if (_alertWindow != null && _alertWindow.IsVisible)
            {
                UpdateAlertThumbnails();
                return;
            }

            // Create alert window with container
            var result = _alertWindowManager.CreateWindow();
            if (result == null)
                return;

            _alertWindow = result.Value.window;

            // Populate thumbnails
            _alertWindowManager.CreateThumbnails(_screenshots);

            // Show with animation
            _alertWindowManager.Show(_alertWindow);

            // Auto-dismiss after 5 seconds
            var autoDismissTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(5.0)
            };
            autoDismissTimer.Tick += (s, e) =>
            {
                (s as DispatcherTimer)?.Stop();
                HideScreenshotAlert();
            };
            autoDismissTimer.Start();
        }

        /// <summary>
        /// Update thumbnails in alert window.
        /// </summary>
        public void UpdateAlertThumbnails()
        {
            _alertWindowManager.CreateThumbnails(_screenshots);
        }

        /// <summary>
        /// Hide screenshot alert window.
        /// </summary>
        public void HideScreenshotAlert()
        {
            if (_alertWindow == null)
                return;

            _alertWindowManager.Hide(_alertWindow);
        }

        /// <summary>
        /// Stop all monitoring services.
        /// </summary>
        public void StopAllMonitoring()
        {
            _screenShareTimer?.Stop();
            _focusMonitorTimer?.Stop();
            _screenshotMonitorTimer?.Stop();

            _window.Activated -= OnWindowActivated;
            _window.Deactivated -= OnWindowDeactivated;
            _window.GotKeyboardFocus -= OnWindowGotKeyboardFocus;
            _window.LostKeyboardFocus -= OnWindowLostKeyboardFocus;

            StealthLogger.Shared.Log("🛑 All monitoring services stopped");
        }

        /// <summary>
        /// Check if screen recording is likely active (best-effort detection).
        /// Windows doesn't provide direct API, so we check for common screen recording processes.
        /// </summary>
        private bool IsScreenRecordingActive()
        {
            try
            {
                var recordingProcesses = new[]
                {
                    "obs64", "obs32", "obs",           // OBS Studio
                    "streamlabs obs",                   // Streamlabs
                    "xsplit.core",                      // XSplit
                    "camtasia",                         // Camtasia
                    "bandicam",                         // Bandicam
                    "fraps",                            // Fraps
                    "nvidia share",                     // Nvidia ShadowPlay
                    "amd radeon software",              // AMD ReLive
                    "ms-gamebar"                        // Windows Game Bar
                };

                var processes = Process.GetProcesses();
                foreach (var process in processes)
                {
                    try
                    {
                        var processName = process.ProcessName.ToLowerInvariant();
                        if (recordingProcesses.Any(rp => processName.Contains(rp)))
                        {
                            return true;
                        }
                    }
                    catch
                    {
                        // Skip processes we can't access
                    }
                }
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"⚠️ Error checking for screen recording: {ex.Message}");
            }

            return false;
        }

        /// <summary>
        /// Get the foreground application name and process name.
        /// </summary>
        private (string appName, string processName) GetForegroundApplication()
        {
            try
            {
                var hwnd = GetForegroundWindow();
                if (hwnd == IntPtr.Zero)
                    return ("Unknown", "?");

                // Get window title
                var sb = new System.Text.StringBuilder(256);
                GetWindowText(hwnd, sb, 256);
                var title = sb.ToString();

                // Get process name
                GetWindowThreadProcessId(hwnd, out var processId);
                var process = Process.GetProcessById((int)processId);
                var processName = process.ProcessName;

                var appName = string.IsNullOrEmpty(title) ? processName : title;
                return (appName, processName);
            }
            catch
            {
                return ("Unknown", "?");
            }
        }

        #region Event Handlers

        private void OnWindowActivated(object? sender, EventArgs e)
        {
            StealthLogger.Shared.Log($"🟢 WINDOW ACTIVATED: {_window.Title}");
        }

        private void OnWindowDeactivated(object? sender, EventArgs e)
        {
            StealthLogger.Shared.Log($"⚪ WINDOW DEACTIVATED: {_window.Title}");
        }

        private void OnWindowGotKeyboardFocus(object? sender, System.Windows.Input.KeyboardFocusChangedEventArgs e)
        {
            StealthLogger.Shared.Log($"🔴 KEYBOARD FOCUS STOLEN: {_window.Title} - THIS IS BAD!");
        }

        private void OnWindowLostKeyboardFocus(object? sender, System.Windows.Input.KeyboardFocusChangedEventArgs e)
        {
            StealthLogger.Shared.Log($"🟢 KEYBOARD FOCUS LOST: {_window.Title} - OK");
        }

        #endregion

        public void Dispose()
        {
            StopAllMonitoring();

            _screenShareTimer = null;
            _focusMonitorTimer = null;
            _screenshotMonitorTimer = null;
        }
    }
}

