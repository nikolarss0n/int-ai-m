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
    /// Global Win32 hotkeys (Ctrl+Alt+... + Ctrl+Shift+M) and local WPF keyboard shortcuts.
    /// </summary>
    public class HotkeyManager : IDisposable
    {
        [DllImport("user32.dll")]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll")]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

        private const uint MOD_ALT = 0x0001;
        private const uint MOD_CONTROL = 0x0002;
        private const uint MOD_SHIFT = 0x0004;
        private const uint MOD_NOREPEAT = 0x4000;

        private const uint VK_RETURN = 0x0D;
        private const uint VK_LEFT = 0x25;
        private const uint VK_UP = 0x26;
        private const uint VK_RIGHT = 0x27;
        private const uint VK_DOWN = 0x28;
        private const int WM_HOTKEY = 0x0312;

        private const int HOTKEY_GHOST_MODE = 1;      // Ctrl+Alt+I
        private const int HOTKEY_TOGGLE_WINDOW = 2;   // Ctrl+Alt+B
        private const int HOTKEY_SCREENSHOT = 3;      // Ctrl+Alt+S
        private const int HOTKEY_ANALYZE = 4;         // Ctrl+Alt+Enter
        private const int HOTKEY_CLEAR = 5;           // Ctrl+Alt+G
        private const int HOTKEY_VOICE_TAB = 6;       // Ctrl+Alt+1
        private const int HOTKEY_NOTES_TAB = 7;       // Ctrl+Alt+2
        private const int HOTKEY_CODING_TAB = 8;      // Ctrl+Alt+3
        private const int HOTKEY_PRACTICE_TAB = 9;    // Ctrl+Alt+4
        private const int HOTKEY_SEARCH = 10;         // Ctrl+Alt+F
        private const int HOTKEY_MUTE = 11;           // Ctrl+Shift+M
        private const int HOTKEY_MOVE_UP = 12;        // Ctrl+Alt+Up
        private const int HOTKEY_MOVE_DOWN = 13;      // Ctrl+Alt+Down
        private const int HOTKEY_MOVE_LEFT = 14;      // Ctrl+Alt+Left
        private const int HOTKEY_MOVE_RIGHT = 15;     // Ctrl+Alt+Right

        private readonly Window _window;
        private IntPtr _windowHandle;
        private HwndSource? _hwndSource;
        private readonly Dictionary<int, Action> _hotkeyActions = new();

        public Action? ToggleInterviewMode { get; set; }
        public Action? ToggleWindowVisibility { get; set; }
        public Action? CaptureScreenshot { get; set; }
        public Action? AnalyzeScreenshots { get; set; }
        public Action? ClearScreenshots { get; set; }
        public Action? SwitchToVoiceTab { get; set; }
        public Action? SwitchToNotesTab { get; set; }
        public Action? SwitchToCodingTab { get; set; }
        public Action? SwitchToPracticeTab { get; set; }
        public Action? ToggleSearch { get; set; }
        public Action? ToggleMute { get; set; }
        public Action? OpenSettings { get; set; }
        public Action? NewNote { get; set; }
        public Action? ExportInterview { get; set; }
        public Action? ShowTemplates { get; set; }
        public Action? HideFloatingSolution { get; set; }
        public Action<double, double>? MoveWindowBy { get; set; }
        public Action? ResetCodingTab { get; set; }
        public Func<bool>? IsWindowVisible { get; set; }
        public Func<TabType>? GetCurrentTab { get; set; }
        public Func<bool>? IsSearchVisible { get; set; }

        public enum TabType
        {
            Notes,
            Voice,
            Coding,
            Practice
        }

        public HotkeyManager(Window window)
        {
            _window = window ?? throw new ArgumentNullException(nameof(window));
        }

        public void SetupHotkeys()
        {
            if (!_window.IsLoaded)
                _window.Loaded += (_, _) => RegisterGlobalHotkeys();
            else
                RegisterGlobalHotkeys();

            SetupLocalKeyboardHandlers();
        }

        private void RegisterGlobalHotkeys()
        {
            try
            {
                _windowHandle = new WindowInteropHelper(_window).Handle;
                _hwndSource = HwndSource.FromHwnd(_windowHandle);
                if (_hwndSource == null) return;
                _hwndSource.AddHook(WndProc);

                var ctrlAlt = MOD_CONTROL | MOD_ALT | MOD_NOREPEAT;
                var ctrlShift = MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT;

                Bind(HOTKEY_GHOST_MODE, ctrlAlt, (uint)KeyInterop.VirtualKeyFromKey(Key.I), () => ToggleInterviewMode?.Invoke());
                Bind(HOTKEY_TOGGLE_WINDOW, ctrlAlt, (uint)KeyInterop.VirtualKeyFromKey(Key.B), () => ToggleWindowVisibility?.Invoke());
                Bind(HOTKEY_SCREENSHOT, ctrlAlt, (uint)KeyInterop.VirtualKeyFromKey(Key.S), () => CaptureScreenshot?.Invoke());
                Bind(HOTKEY_ANALYZE, ctrlAlt, VK_RETURN, () => AnalyzeScreenshots?.Invoke());
                Bind(HOTKEY_CLEAR, ctrlAlt, (uint)KeyInterop.VirtualKeyFromKey(Key.G), () =>
                {
                    if (IsWindowVisible?.Invoke() != true) return;
                    if (GetCurrentTab?.Invoke() == TabType.Coding) ResetCodingTab?.Invoke();
                    else ClearScreenshots?.Invoke();
                });
                Bind(HOTKEY_VOICE_TAB, ctrlAlt, (uint)KeyInterop.VirtualKeyFromKey(Key.D1), () => SwitchToVoiceTab?.Invoke());
                Bind(HOTKEY_NOTES_TAB, ctrlAlt, (uint)KeyInterop.VirtualKeyFromKey(Key.D2), () => SwitchToNotesTab?.Invoke());
                Bind(HOTKEY_CODING_TAB, ctrlAlt, (uint)KeyInterop.VirtualKeyFromKey(Key.D3), () => SwitchToCodingTab?.Invoke());
                Bind(HOTKEY_PRACTICE_TAB, ctrlAlt, (uint)KeyInterop.VirtualKeyFromKey(Key.D4), () => SwitchToPracticeTab?.Invoke());
                Bind(HOTKEY_SEARCH, ctrlAlt, (uint)KeyInterop.VirtualKeyFromKey(Key.F), () =>
                {
                    if (IsWindowVisible?.Invoke() == true && GetCurrentTab?.Invoke() == TabType.Notes)
                        ToggleSearch?.Invoke();
                });
                Bind(HOTKEY_MUTE, ctrlShift, (uint)KeyInterop.VirtualKeyFromKey(Key.M), () => ToggleMute?.Invoke());

                // Keyboard window movement (works even while click-through Ghost Mode is ON)
                const double step = 48;
                Bind(HOTKEY_MOVE_UP, MOD_CONTROL | MOD_ALT, VK_UP, () => MoveWindowBy?.Invoke(0, -step));
                Bind(HOTKEY_MOVE_DOWN, MOD_CONTROL | MOD_ALT, VK_DOWN, () => MoveWindowBy?.Invoke(0, step));
                Bind(HOTKEY_MOVE_LEFT, MOD_CONTROL | MOD_ALT, VK_LEFT, () => MoveWindowBy?.Invoke(-step, 0));
                Bind(HOTKEY_MOVE_RIGHT, MOD_CONTROL | MOD_ALT, VK_RIGHT, () => MoveWindowBy?.Invoke(step, 0));
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"Exception in RegisterGlobalHotkeys: {ex.Message}");
            }
        }

        private void Bind(int id, uint modifiers, uint vk, Action action)
        {
            RegisterHotKey(_windowHandle, id, modifiers, vk);
            _hotkeyActions[id] = action;
        }

        private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == WM_HOTKEY)
            {
                int id = wParam.ToInt32();
                if (_hotkeyActions.TryGetValue(id, out var action))
                {
                    _window.Dispatcher.BeginInvoke(action);
                    handled = true;
                }
            }
            return IntPtr.Zero;
        }

        private void SetupLocalKeyboardHandlers()
        {
            _window.PreviewKeyDown += (_, e) =>
            {
                var mods = Keyboard.Modifiers;
                if (e.Key == Key.Escape && IsSearchVisible?.Invoke() == true)
                {
                    ToggleSearch?.Invoke();
                    e.Handled = true;
                    return;
                }

                if (mods == ModifierKeys.Control)
                {
                    switch (e.Key)
                    {
                        case Key.OemComma:
                            OpenSettings?.Invoke();
                            e.Handled = true;
                            break;
                        case Key.N:
                            NewNote?.Invoke();
                            e.Handled = true;
                            break;
                        case Key.E:
                            ExportInterview?.Invoke();
                            e.Handled = true;
                            break;
                        case Key.T:
                            ShowTemplates?.Invoke();
                            e.Handled = true;
                            break;
                        case Key.F:
                            if (GetCurrentTab?.Invoke() == TabType.Notes)
                            {
                                ToggleSearch?.Invoke();
                                e.Handled = true;
                            }
                            break;
                        case Key.OemPipe:
                            HideFloatingSolution?.Invoke();
                            e.Handled = true;
                            break;
                        case Key.D1:
                            SwitchToVoiceTab?.Invoke();
                            e.Handled = true;
                            break;
                        case Key.D2:
                            SwitchToNotesTab?.Invoke();
                            e.Handled = true;
                            break;
                        case Key.D3:
                            SwitchToCodingTab?.Invoke();
                            e.Handled = true;
                            break;
                        case Key.D4:
                            SwitchToPracticeTab?.Invoke();
                            e.Handled = true;
                            break;
                    }
                }
            };
        }

        public void Dispose()
        {
            if (_windowHandle != IntPtr.Zero)
            {
                foreach (var id in _hotkeyActions.Keys)
                    UnregisterHotKey(_windowHandle, id);
            }
            if (_hwndSource != null)
            {
                _hwndSource.RemoveHook(WndProc);
                _hwndSource = null;
            }
        }
    }
}
