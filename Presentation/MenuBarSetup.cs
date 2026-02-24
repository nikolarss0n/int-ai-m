using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Shell;
using InterviewMasterApp.Presentation.Settings;
using InterviewMasterApp.Presentation.Windows;

namespace InterviewMasterApp.Presentation
{
    /// <summary>
    /// Menu bar setup for the main window.
    /// Ported from Swift: MenuBarSetup.swift
    /// Creates comprehensive menu structure with keyboard shortcuts.
    /// </summary>
    public class MenuBarSetup
    {
        private readonly Window _window;
        private Window? _settingsWindowController;

        // Delegate callbacks (to be set by the main window/controller)
        public Action? ShowAbout { get; set; }
        public Action? ShowSettings { get; set; }
        public Action? NewNote { get; set; }
        public Action? CaptureScreenshot { get; set; }
        public Action? ExportNotes { get; set; }
        public Action? ToggleSearch { get; set; }
        public Action? SwitchToNotesTab { get; set; }
        public Action? SwitchToVoiceTab { get; set; }
        public Action? ToggleWindowVisibility { get; set; }
        public Action? HideFloatingSolution { get; set; }
        public Action? ShowTemplateSelector { get; set; }
        public Action? ShowHelp { get; set; }
        public Action? ShowKeyboardShortcuts { get; set; }
        public Action? ShowPrivacyPolicy { get; set; }

        public MenuBarSetup(Window window)
        {
            _window = window ?? throw new ArgumentNullException(nameof(window));
        }

        /// <summary>
        /// Setup the complete menu bar for the main window.
        /// </summary>
        public Menu CreateMenuBar()
        {
            var menuBar = new Menu();
            WindowChrome.SetIsHitTestVisibleInChrome(menuBar, true);

            // File menu
            menuBar.Items.Add(CreateFileMenu());

            // Edit menu
            menuBar.Items.Add(CreateEditMenu());

            // View menu
            menuBar.Items.Add(CreateViewMenu());

            // Window menu
            menuBar.Items.Add(CreateWindowMenu());

            // Help menu
            menuBar.Items.Add(CreateHelpMenu());

            return menuBar;
        }

        /// <summary>
        /// Create File menu.
        /// </summary>
        private MenuItem CreateFileMenu()
        {
            var fileMenu = new MenuItem { Header = "_File" };

            // New Note - Ctrl+N
            var newNoteItem = new MenuItem { Header = "New _Note", InputGestureText = "Ctrl+N" };
            newNoteItem.Click += (s, e) => NewNote?.Invoke();
            fileMenu.Items.Add(newNoteItem);

            fileMenu.Items.Add(new Separator());

            // Capture Screenshot - Ctrl+Shift+S
            var captureItem = new MenuItem { Header = "Capture _Screenshot", InputGestureText = "Ctrl+Shift+S" };
            captureItem.Click += (s, e) => CaptureScreenshot?.Invoke();
            fileMenu.Items.Add(captureItem);

            fileMenu.Items.Add(new Separator());

            // Export Notes - Ctrl+E
            var exportItem = new MenuItem { Header = "_Export Notes...", InputGestureText = "Ctrl+E" };
            exportItem.Click += (s, e) => ExportNotes?.Invoke();
            fileMenu.Items.Add(exportItem);

            fileMenu.Items.Add(new Separator());

            // Settings - Ctrl+,
            var settingsItem = new MenuItem { Header = "_Settings...", InputGestureText = "Ctrl+," };
            settingsItem.Click += (s, e) => ShowSettingsWindow();
            fileMenu.Items.Add(settingsItem);

            fileMenu.Items.Add(new Separator());

            // Exit - Alt+F4 (Windows standard)
            var exitItem = new MenuItem { Header = "E_xit", InputGestureText = "Alt+F4" };
            exitItem.Click += (s, e) => _window.Close();
            fileMenu.Items.Add(exitItem);

            return fileMenu;
        }

        /// <summary>
        /// Create Edit menu.
        /// </summary>
        private MenuItem CreateEditMenu()
        {
            var editMenu = new MenuItem { Header = "_Edit" };

            // Undo - Ctrl+Z
            var undoItem = new MenuItem { Header = "_Undo", InputGestureText = "Ctrl+Z" };
            undoItem.Command = ApplicationCommands.Undo;
            editMenu.Items.Add(undoItem);

            // Redo - Ctrl+Y (Windows) or Ctrl+Shift+Z
            var redoItem = new MenuItem { Header = "_Redo", InputGestureText = "Ctrl+Y" };
            redoItem.Command = ApplicationCommands.Redo;
            editMenu.Items.Add(redoItem);

            editMenu.Items.Add(new Separator());

            // Cut - Ctrl+X
            var cutItem = new MenuItem { Header = "Cu_t", InputGestureText = "Ctrl+X" };
            cutItem.Command = ApplicationCommands.Cut;
            editMenu.Items.Add(cutItem);

            // Copy - Ctrl+C
            var copyItem = new MenuItem { Header = "_Copy", InputGestureText = "Ctrl+C" };
            copyItem.Command = ApplicationCommands.Copy;
            editMenu.Items.Add(copyItem);

            // Paste - Ctrl+V
            var pasteItem = new MenuItem { Header = "_Paste", InputGestureText = "Ctrl+V" };
            pasteItem.Command = ApplicationCommands.Paste;
            editMenu.Items.Add(pasteItem);

            // Select All - Ctrl+A
            var selectAllItem = new MenuItem { Header = "Select _All", InputGestureText = "Ctrl+A" };
            selectAllItem.Command = ApplicationCommands.SelectAll;
            editMenu.Items.Add(selectAllItem);

            editMenu.Items.Add(new Separator());

            // Find - Ctrl+F
            var findItem = new MenuItem { Header = "_Find...", InputGestureText = "Ctrl+F" };
            findItem.Click += (s, e) => ToggleSearch?.Invoke();
            editMenu.Items.Add(findItem);

            return editMenu;
        }

        /// <summary>
        /// Create View menu.
        /// </summary>
        private MenuItem CreateViewMenu()
        {
            var viewMenu = new MenuItem { Header = "_View" };

            // Context tab - Ctrl+1
            var contextItem = new MenuItem { Header = "_Context", InputGestureText = "Ctrl+1" };
            contextItem.Click += (s, e) => SwitchToNotesTab?.Invoke();
            viewMenu.Items.Add(contextItem);

            // Timeline tab - Ctrl+2
            var timelineItem = new MenuItem { Header = "_Timeline", InputGestureText = "Ctrl+2" };
            timelineItem.Click += (s, e) => SwitchToVoiceTab?.Invoke();
            viewMenu.Items.Add(timelineItem);

            viewMenu.Items.Add(new Separator());

            // Toggle Window - Ctrl+B
            var toggleItem = new MenuItem { Header = "Toggle _Window", InputGestureText = "Ctrl+B" };
            toggleItem.Click += (s, e) => ToggleWindowVisibility?.Invoke();
            viewMenu.Items.Add(toggleItem);

            // Hide Floating Solution - Ctrl+\
            var hideSolutionItem = new MenuItem { Header = "Hide _Floating Solution", InputGestureText = "Ctrl+\\" };
            hideSolutionItem.Click += (s, e) => HideFloatingSolution?.Invoke();
            viewMenu.Items.Add(hideSolutionItem);

            viewMenu.Items.Add(new Separator());

            // Interview Templates - Ctrl+T
            var templatesItem = new MenuItem { Header = "Interview _Templates...", InputGestureText = "Ctrl+T" };
            templatesItem.Click += (s, e) => ShowTemplateSelector?.Invoke();
            viewMenu.Items.Add(templatesItem);

            return viewMenu;
        }

        /// <summary>
        /// Create Window menu.
        /// </summary>
        private MenuItem CreateWindowMenu()
        {
            var windowMenu = new MenuItem { Header = "_Window" };

            // Minimize - Windows standard
            var minimizeItem = new MenuItem { Header = "Mi_nimize" };
            minimizeItem.Click += (s, e) => _window.WindowState = WindowState.Minimized;
            windowMenu.Items.Add(minimizeItem);

            // Maximize/Restore
            var maximizeItem = new MenuItem { Header = "Ma_ximize" };
            maximizeItem.Click += (s, e) =>
            {
                _window.WindowState = _window.WindowState == WindowState.Maximized
                    ? WindowState.Normal
                    : WindowState.Maximized;
            };
            windowMenu.Items.Add(maximizeItem);

            windowMenu.Items.Add(new Separator());

            // Always on Top
            var alwaysOnTopItem = new MenuItem { Header = "Always on _Top", IsCheckable = true };
            alwaysOnTopItem.Click += (s, e) =>
            {
                _window.Topmost = alwaysOnTopItem.IsChecked;
            };
            windowMenu.Items.Add(alwaysOnTopItem);

            return windowMenu;
        }

        /// <summary>
        /// Create Help menu.
        /// </summary>
        private MenuItem CreateHelpMenu()
        {
            var helpMenu = new MenuItem { Header = "_Help" };

            // Interview Master Help - F1
            var helpItem = new MenuItem { Header = "Interview Master _Help", InputGestureText = "F1" };
            helpItem.Click += (s, e) => ShowHelpPage();
            helpMenu.Items.Add(helpItem);

            helpMenu.Items.Add(new Separator());

            // Keyboard Shortcuts
            var shortcutsItem = new MenuItem { Header = "_Keyboard Shortcuts" };
            shortcutsItem.Click += (s, e) => ShowKeyboardShortcutsDialog();
            helpMenu.Items.Add(shortcutsItem);

            // Privacy Policy
            var privacyItem = new MenuItem { Header = "_Privacy Policy" };
            privacyItem.Click += (s, e) => ShowPrivacyPolicyPage();
            helpMenu.Items.Add(privacyItem);

            helpMenu.Items.Add(new Separator());

            // About
            var aboutItem = new MenuItem { Header = "_About Interview Master" };
            aboutItem.Click += (s, e) => ShowAboutDialog();
            helpMenu.Items.Add(aboutItem);

            return helpMenu;
        }

        /// <summary>
        /// Show About dialog.
        /// </summary>
        private void ShowAboutDialog()
        {
            var result = MessageBox.Show(
                _window,
                "Version 1.0.0\n\n" +
                "AI-powered interview assistant for software engineers.\n\n" +
                "Capture coding problems and get instant analysis with Claude AI.\n\n" +
                "© 2024 Nikolay Prosenikov\n\n" +
                "Click OK to view Privacy Policy, or Cancel to close.",
                "About Interview Master",
                MessageBoxButton.OKCancel,
                MessageBoxImage.Information);

            if (result == MessageBoxResult.OK)
            {
                ShowPrivacyPolicyPage();
            }
        }

        /// <summary>
        /// Show Privacy Policy in browser.
        /// </summary>
        private void ShowPrivacyPolicyPage()
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "https://github.com/nikolayprosenikov/interview-master/blob/main/PRIVACY.md",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"Failed to open privacy policy: {ex.Message}");
            }
        }

        /// <summary>
        /// Show Help page in browser.
        /// </summary>
        private void ShowHelpPage()
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "https://github.com/nikolayprosenikov/interview-master",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                StealthLogger.Shared.Log($"Failed to open help: {ex.Message}");
            }
        }

        /// <summary>
        /// Show Keyboard Shortcuts dialog.
        /// </summary>
        private void ShowKeyboardShortcutsDialog()
        {
            MessageBox.Show(
                _window,
                "Global (work from any app):\n" +
                "Win+B          Toggle window visibility\n" +
                "Win+S          Capture screenshot\n" +
                "Win+Enter      Analyze screenshots\n\n" +
                "Navigation:\n" +
                "Ctrl+1         Context tab\n" +
                "Ctrl+2         Timeline tab\n\n" +
                "Editing:\n" +
                "Ctrl+F         Find in notes\n" +
                "Ctrl+G         Clear screenshots\n" +
                "Ctrl+,         Settings\n\n" +
                "Window:\n" +
                "Win+Arrow      Move window\n\n" +
                "Note: Windows key (Win) is used instead of Command (⌘) on macOS.",
                "Keyboard Shortcuts",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
        }

        /// <summary>
        /// Show Settings window.
        /// </summary>
        private void ShowSettingsWindow()
        {
            if (_settingsWindowController == null)
            {
                _settingsWindowController = SettingsWindowController.Create();
            }

            _settingsWindowController.Owner = _window;
            _settingsWindowController.ShowDialog();
        }

        /// <summary>
        /// Mask API key for display (show first 7 and last 3 characters).
        /// </summary>
        public static string MaskApiKey(string key)
        {
            if (string.IsNullOrEmpty(key) || key.Length <= 10)
                return "sk-ant-***";

            var prefix = key.Substring(0, 7);
            var suffix = key.Substring(key.Length - 3);
            return $"{prefix}***{suffix}";
        }
    }
}

