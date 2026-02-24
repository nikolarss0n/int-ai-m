using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Global hotkey manager using Win32 RegisterHotKey API.
    /// Uses Ctrl+Alt modifiers to avoid conflicts with Windows 11 system shortcuts.
    /// </summary>
    public class HotkeyManager : IDisposable
    {
        #region Win32 API Imports

        [DllImport("user32.dll")]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll")]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

        private const uint MOD_ALT = 0x0001;
        private const uint MOD_CONTROL = 0x0002;
        private const uint MOD_NOREPEAT = 0x4000;

        private const uint VK_RETURN = 0x0D;
        private const int WM_HOTKEY = 0x0312;

        #endregion

        // Hotkey IDs
        private const int HOTKEY_GHOST_MODE = 1;      // Ctrl+Alt+I
        private const int HOTKEY_TOGGLE_WINDOW = 2;   // Ctrl+Alt+B
        private const int HOTKEY_SCREENSHOT = 3;      // Ctrl+Alt+S
        private const int HOTKEY_ANALYZE = 4;         // Ctrl+Alt+Enter
        private const int HOTKEY_CLEAR = 5;           // Ctrl+Alt+G
        private const int HOTKEY_NOTES_TAB = 6;       // Ctrl+Alt+1
        private const int HOTKEY_VOICE_TAB = 7;       // Ctrl+Alt+2
        private const int HOTKEY_SEARCH = 8;          // Ctrl+Alt+F

        private readonly Window _window;
        private IntPtr _windowHandle;
        private HwndSource? _hwndSource;
        private bool _hotkeyRegistrationFailed;
        private readonly Dictionary<int, Action> _hotkeyActions = new();

        // Delegate callbacks
        public Action? ToggleInterviewMode { get; set; }
        public Action? ToggleWindowVisibility { get; set; }
        public Action? CaptureScreenshot { get; set; }
        public Action? AnalyzeScreenshots { get; set; }
        public Action? ClearScreenshots { get; set; }
        public Action? SwitchToNotesTab { get; set; }
        public Action? SwitchToVoiceTab { get; set; }
        public Action? ToggleSearch { get; set; }
        public Action? ResetCodingTab { get; set; }
        public Func<bool>? IsWindowVisible { get; set; }
        public Func<TabType>? GetCurrentTab { get; set; }
        public Func<bool>? IsSearchVisible { get; set; }

        public enum TabType
        {
            Notes,
            Voice,
            Coding
        }

        public HotkeyManager(Window window)
        {
            _window = window ?? throw new ArgumentNullException(nameof(window));
        }

        public void SetupHotkeys()
        {
            StealthLogger.Shared.Log("SetupHotkeys() called");

            if (!_window.IsLoaded)
            {
                _window.Loaded += (s, e) => RegisterGlobalHotkeys();
            }
            else
            {
                RegisterGlobalHotkeys();
            }

            SetupLocalKeyboardHandlers();
        }

        /// <summary>
        /// Register global hotkeys using Ctrl+Alt modifier to avoid Windows 11 conflicts.
        /// </summary>
        private void RegisterGlobalHotkeys()
        {
            try
            {
                _windowHandle = new WindowInteropHelper(_window).Handle;
                _hwndSource = HwndSource.FromHwnd(_windowHandle);

                if (_hwndSource == null)
                {
                    StealthLogger.Shared.Log("Failed to get HwndSource");
                    return;
                }

                _hwndSource.AddHook(WndProc);

                var mod = MOD_CONTROL | MOD_ALT | MOD_NOREPEAT;

                // Ctrl+Alt+I = Toggle ghost mode
                if (!RegisterHotkey(HOTKEY_GHOST_MODE, mod, (uint)KeyInterop.VirtualKeyFromKey(Key.I)))
                    _hotkeyRegistrationFailed = true;
                _hotkeyActions[HOTKEY_GHOST_MODE] = () => ToggleInterviewMode?.Invoke();

                // Ctrl+Alt+B = Toggle window visibility
                if (!RegisterHotkey(HOTKEY_TOGGLE_WINDOW, mod, (uint)KeyInterop.VirtualKeyFromKey(Key.B)))
                    _hotkeyRegistrationFailed = true;
                _hotkeyActions[HOTKEY_TOGGLE_WINDOW] = () => ToggleWindowVisibility?.Invoke();

                // Ctrl+Alt+S = Capture screenshot
                if (!RegisterHotkey(HOTKEY_SCREENSHOT, mod, (uint)KeyInterop.VirtualKeyFromKey(Key.S)))
                    _hotkeyRegistrationFailed = true;
                _hotkeyActions[HOTKEY_SCREENSHOT] = () =>
                {
                    if (GetCurrentTab?.Invoke() != TabType.Voice)
                        SwitchToVoiceTab?.Invoke();
                    CaptureScreenshot?.Invoke();
                };

                // Ctrl+Alt+Enter = Analyze screenshots
                if (!RegisterHotkey(HOTKEY_ANALYZE, mod, VK_RETURN))
                    _hotkeyRegistrationFailed = true;
                _hotkeyActions[HOTKEY_ANALYZE] = () =>
                {
                    if (IsWindowVisible?.Invoke() == true && GetCurrentTab?.Invoke() != TabType.Voice)
                        SwitchToVoiceTab?.Invoke();
                    AnalyzeScreenshots?.Invoke();
                };

                // Ctrl+Alt+G = Clear/Reset
                if (!RegisterHotkey(HOTKEY_CLEAR, mod, (uint)KeyInterop.VirtualKeyFromKey(Key.G)))
                    _hotkeyRegistrationFailed = true;
                _hotkeyActions[HOTKEY_CLEAR] = () =>
                {
                    if (IsWindowVisible?.Invoke() != true) return;
                    var currentTab = GetCurrentTab?.Invoke();
                    if (currentTab == TabType.Voice)
                        ClearScreenshots?.Invoke();
                    else if (currentTab == TabType.Coding)
                        ResetCodingTab?.Invoke();
                };

                // Ctrl+Alt+1 = Notes tab
                if (!RegisterHotkey(HOTKEY_NOTES_TAB, mod, (uint)KeyInterop.VirtualKeyFromKey(Key.D1)))
                    _hotkeyRegistrationFailed = true;
                _hotkeyActions[HOTKEY_NOTES_TAB] = () =>
                {
                    if (IsWindowVisible?.Invoke() != true) return;
                    SwitchToNotesTab?.Invoke();
                };

                // Ctrl+Alt+2 = Voice tab
                if (!RegisterHotkey(HOTKEY_VOICE_TAB, mod, (uint)KeyInterop.VirtualKeyFromKey(Key.D2)))
                    _hotkeyRegistrationFailed = true;
                _hotkeyActions[HOTKEY_VOICE_TAB] = () =>
                {
                    if (IsWindowVisible?.Invoke() != true) return;
                    SwitchToVoiceTab?.Invoke();
                };

                // Ctrl+Alt+F = Search
                if (!RegisterHotkey(HOTKEY_SEARCH, mod, (uint)KeyInterop.VirtualKeyFromKey(Key.F)))
                    _hotkeyRegistrationFailed = true;
                _hotkeyActions[HOTKEY_SEARCH] = () =>
                {
                    if (IsWindowVisible?.Invoke() != true || GetCurrentTab?.Invoke() != TabType.Notes) return;
                    ToggleSearch?.Invoke();
                };

                if (_hotkeyRegistrationFailed)
                {
                    StealthLogger.Shared.Log("Some hotkeys failed to register (may conflict with other apps)");
                }
                else
                {
                    StealthLogger.Shared.Log("All global hotkeys registered (Ctrl+Alt+...)");
                }
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"Exception in RegisterGlobalHotkeys: {ex.Message}");
            }
        }

        private bool RegisterHotkey(int id, uint modifiers, uint vk)
        {
            return RegisterHotKey(_windowHandle, id, modifiers, vk);
        }

        private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == WM_HOTKEY)
            {
                int hotkeyId = wParam.ToInt32();
                if (_hotkeyActions.TryGetValue(hotkeyId, out var action))
                {
                    _window.Dispatcher.BeginInvoke(action);
                    handled = true;
                }
            }
            return IntPtr.Zero;
        }

        private void SetupLocalKeyboardHandlers()
        {
            _window.PreviewKeyDown += (s, e) =>
            {
                if (e.Key == Key.Escape && IsSearchVisible?.Invoke() == true)
                {
                    ToggleSearch?.Invoke();
                    e.Handled = true;
                }
            };

            StealthLogger.Shared.Log("Local keyboard handlers installed");
        }

        public void Dispose()
        {
            if (_windowHandle != IntPtr.Zero)
            {
                for (int i = HOTKEY_GHOST_MODE; i <= HOTKEY_SEARCH; i++)
                {
                    UnregisterHotKey(_windowHandle, i);
                }
                StealthLogger.Shared.Log("All hotkeys unregistered");
            }

            if (_hwndSource != null)
            {
                _hwndSource.RemoveHook(WndProc);
                _hwndSource = null;
            }
        }
    }
}
