using System;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shell;
using InterviewMasterApp.Presentation.Settings;
using InterviewMasterApp.Presentation.Styling;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    public class MenuBarSetup
    {
        private readonly Window _window;

        public Action? ShowSettings { get; set; }
        public Action? NewNote { get; set; }
        public Action? CaptureScreenshot { get; set; }
        public Action? AnalyzeScreenshots { get; set; }
        public Action? ExportNotes { get; set; }
        public Action? ToggleSearch { get; set; }
        public Action? SwitchToVoiceTab { get; set; }
        public Action? SwitchToNotesTab { get; set; }
        public Action? SwitchToCodingTab { get; set; }
        public Action? SwitchToPracticeTab { get; set; }
        public Action? ToggleWindowVisibility { get; set; }
        public Action? ToggleGhostMode { get; set; }
        public Action? ToggleMute { get; set; }
        public Action? HideFloatingSolution { get; set; }
        public Action? ShowTemplateSelector { get; set; }

        public MenuBarSetup(Window window)
        {
            _window = window ?? throw new ArgumentNullException(nameof(window));
        }

        public Menu CreateMenuBar()
        {
            var menuBar = new Menu
            {
                Background = DesignTokens.BgCardBrush,
                Foreground = DesignTokens.TextBodyBrush,
                BorderThickness = new Thickness(0, 0, 0, 1),
                BorderBrush = DesignTokens.BorderWidgetBrush
            };
            WindowChrome.SetIsHitTestVisibleInChrome(menuBar, true);

            menuBar.Items.Add(CreateFileMenu());
            menuBar.Items.Add(CreateEditMenu());
            menuBar.Items.Add(CreateViewMenu());
            menuBar.Items.Add(CreateWindowMenu());
            menuBar.Items.Add(CreateHelpMenu());
            return menuBar;
        }

        private MenuItem CreateFileMenu()
        {
            var menu = new MenuItem { Header = "_File" };
            menu.Items.Add(Item("New _Note", "Ctrl+N", () => NewNote?.Invoke()));
            menu.Items.Add(new Separator());
            menu.Items.Add(Item("Capture _Screenshot", "Ctrl+Alt+S", () => CaptureScreenshot?.Invoke()));
            menu.Items.Add(Item("_Analyze Screenshots", "Ctrl+Alt+Enter", () => AnalyzeScreenshots?.Invoke()));
            menu.Items.Add(new Separator());
            menu.Items.Add(Item("_Export Interview…", "Ctrl+E", () => ExportNotes?.Invoke()));
            menu.Items.Add(new Separator());
            menu.Items.Add(Item("_Settings…", "Ctrl+,", OpenSettingsFresh));
            menu.Items.Add(new Separator());
            menu.Items.Add(Item("E_xit", "Alt+F4", () => _window.Close()));
            return menu;
        }

        private MenuItem CreateEditMenu()
        {
            var menu = new MenuItem { Header = "_Edit" };
            menu.Items.Add(new MenuItem { Header = "_Undo", InputGestureText = "Ctrl+Z", Command = ApplicationCommands.Undo });
            menu.Items.Add(new MenuItem { Header = "_Redo", InputGestureText = "Ctrl+Y", Command = ApplicationCommands.Redo });
            menu.Items.Add(new Separator());
            menu.Items.Add(new MenuItem { Header = "Cu_t", InputGestureText = "Ctrl+X", Command = ApplicationCommands.Cut });
            menu.Items.Add(new MenuItem { Header = "_Copy", InputGestureText = "Ctrl+C", Command = ApplicationCommands.Copy });
            menu.Items.Add(new MenuItem { Header = "_Paste", InputGestureText = "Ctrl+V", Command = ApplicationCommands.Paste });
            menu.Items.Add(new MenuItem { Header = "Select _All", InputGestureText = "Ctrl+A", Command = ApplicationCommands.SelectAll });
            menu.Items.Add(new Separator());
            menu.Items.Add(Item("_Find in Notes…", "Ctrl+F", () => ToggleSearch?.Invoke()));
            return menu;
        }

        private MenuItem CreateViewMenu()
        {
            var menu = new MenuItem { Header = "_View" };
            menu.Items.Add(Item("_Live Interview", "Ctrl+1", () => SwitchToVoiceTab?.Invoke()));
            menu.Items.Add(Item("_Notes & CV", "Ctrl+2", () => SwitchToNotesTab?.Invoke()));
            menu.Items.Add(Item("_Code Panel", "Ctrl+3", () => SwitchToCodingTab?.Invoke()));
            menu.Items.Add(Item("_Practice", "Ctrl+4", () => SwitchToPracticeTab?.Invoke()));
            menu.Items.Add(new Separator());
            menu.Items.Add(Item("Toggle _Mute", "Ctrl+Shift+M", () => ToggleMute?.Invoke()));
            menu.Items.Add(Item("Toggle _Ghost Mode", "Ctrl+Alt+I", () => ToggleGhostMode?.Invoke()));
            menu.Items.Add(Item("Toggle _Window", "Ctrl+Alt+B", () => ToggleWindowVisibility?.Invoke()));
            menu.Items.Add(Item("Hide _Floating Solution", "Ctrl+\\", () => HideFloatingSolution?.Invoke()));
            menu.Items.Add(new Separator());
            menu.Items.Add(Item("Interview _Templates…", "Ctrl+T", () => ShowTemplateSelector?.Invoke()));
            return menu;
        }

        private MenuItem CreateWindowMenu()
        {
            var menu = new MenuItem { Header = "_Window" };
            menu.Items.Add(Item("Mi_nimize", string.Empty, () => _window.WindowState = WindowState.Minimized));
            menu.Items.Add(Item("Ma_ximize / Restore", string.Empty, () =>
                _window.WindowState = _window.WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized));
            menu.Items.Add(new Separator());
            var alwaysOnTop = new MenuItem { Header = "Always on _Top", IsCheckable = true };
            alwaysOnTop.Click += (_, _) => _window.Topmost = alwaysOnTop.IsChecked;
            menu.Items.Add(alwaysOnTop);
            return menu;
        }

        private MenuItem CreateHelpMenu()
        {
            var menu = new MenuItem { Header = "_Help" };
            menu.Items.Add(Item("_Keyboard Shortcuts", string.Empty, ShowKeyboardShortcutsDialog));
            menu.Items.Add(Item("_About Interview Master", string.Empty, ShowAboutDialog));
            return menu;
        }

        private static MenuItem Item(string header, string gesture, Action onClick)
        {
            var mi = new MenuItem { Header = header, InputGestureText = gesture };
            mi.Click += (_, _) => onClick();
            return mi;
        }

        private void OpenSettingsFresh()
        {
            if (ShowSettings != null)
            {
                ShowSettings.Invoke();
                return;
            }
            // Always create a new WPF Window — closed Windows cannot call ShowDialog() a second time.
            var win = SettingsWindowController.Create();
            win.Owner = _window;
            win.ShowDialog();
        }

        private void ShowKeyboardShortcutsDialog()
        {
            MessageBox.Show(
                _window,
                "Global (work from any app):\n" +
                "Ctrl+Alt+I       Toggle Ghost Mode (click-through + capture hidden)\n" +
                "Ctrl+Alt+B       Show / hide window\n" +
                "Ctrl+Alt+S       Capture screenshot\n" +
                "Ctrl+Alt+Enter   Analyze screenshots\n" +
                "Ctrl+Alt+G       Clear screenshots / code\n" +
                "Ctrl+Alt+Arrows  Move window by keyboard\n" +
                "Ctrl+Shift+M     Mute / unmute audio capture\n\n" +
                "Tabs:\n" +
                "Ctrl+1 / Ctrl+Alt+1   Live Interview\n" +
                "Ctrl+2 / Ctrl+Alt+2   Notes & CV\n" +
                "Ctrl+3 / Ctrl+Alt+3   Code Panel\n" +
                "Ctrl+4 / Ctrl+Alt+4   Practice\n\n" +
                "Local:\n" +
                "Ctrl+,           Settings\n" +
                "Ctrl+E           Export interview\n" +
                "Ctrl+T           Templates\n" +
                "Ctrl+F           Find in notes",
                "Keyboard Shortcuts",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
        }

        private void ShowAboutDialog()
        {
            MessageBox.Show(
                _window,
                "Interview Master for Windows\n\nAI-powered live interview assistant with speech detection, cue-card answers, live coding steps, and practice decks.",
                "About Interview Master",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
        }

        public static string MaskApiKey(string key)
        {
            if (string.IsNullOrEmpty(key) || key.Length <= 10) return "sk-***";
            return $"{key[..7]}***{key[^3..]}";
        }
    }
}
