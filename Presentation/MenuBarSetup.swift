import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    func setupMenuBar() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        appMenu.addItem(withTitle: "About Interview Master", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        let hideItem = appMenu.addItem(withTitle: "Hide Interview Master", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hideItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        appMenu.items.last?.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Interview Master", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // File menu
        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        fileMenu.addItem(withTitle: "New Note", action: #selector(newNote), keyEquivalent: "n")
        fileMenu.addItem(NSMenuItem.separator())
        let captureItem = fileMenu.addItem(withTitle: "Capture Screenshot", action: #selector(captureScreenshotPlaceholder), keyEquivalent: "s")
        captureItem.target = self
        captureItem.keyEquivalentModifierMask = [.command]
        let analyzeItem = fileMenu.addItem(withTitle: "Analyze / Send Screenshots", action: #selector(analyzeScreenshots), keyEquivalent: "\r")
        analyzeItem.target = self
        analyzeItem.keyEquivalentModifierMask = [.command]
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Export Notes...", action: #selector(exportNotes), keyEquivalent: "e")

        // Edit menu
        let editMenu = NSMenu(title: "Edit")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        let findItem = editMenu.addItem(withTitle: "Find...", action: #selector(toggleSearch), keyEquivalent: "f")
        findItem.keyEquivalentModifierMask = [.command]

        // View menu
        let viewMenu = NSMenu(title: "View")
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        viewMenu.addItem(withTitle: "Context", action: #selector(switchToNotesTab), keyEquivalent: "1")
        viewMenu.addItem(withTitle: "Timeline", action: #selector(switchToVoiceTab), keyEquivalent: "2")
        viewMenu.addItem(withTitle: "Practice", action: #selector(switchToPracticeTab), keyEquivalent: "4")
        viewMenu.addItem(NSMenuItem.separator())
        let toggleItem = viewMenu.addItem(withTitle: "Toggle Window", action: #selector(toggleWindowVisibility), keyEquivalent: "b")
        toggleItem.keyEquivalentModifierMask = [.command]
        let hideSolutionItem = viewMenu.addItem(withTitle: "Hide Floating Solution", action: #selector(hideFloatingSolution), keyEquivalent: "\\")
        hideSolutionItem.keyEquivalentModifierMask = [.command]

        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Interview Templates...", action: #selector(showTemplateSelector), keyEquivalent: "t")

        // Window menu
        let windowMenu = NSMenu(title: "Window")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        let hideWindowItem = windowMenu.addItem(withTitle: "Hide Window", action: #selector(hideMainWindowFromMenu), keyEquivalent: "m")
        hideWindowItem.target = self
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")

        // Help menu
        let helpMenu = NSMenu(title: "Help")
        let helpMenuItem = NSMenuItem()
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        helpMenu.addItem(withTitle: "Interview Master Help", action: #selector(showHelp), keyEquivalent: "?")
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(withTitle: "Keyboard Shortcuts", action: #selector(showKeyboardShortcuts), keyEquivalent: "")
        helpMenu.addItem(withTitle: "Privacy Policy", action: #selector(showPrivacyPolicy), keyEquivalent: "")

        NSApp.mainMenu = mainMenu
        NSApp.helpMenu = helpMenu
        NSApp.windowsMenu = windowMenu
        setupStatusItem()
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "IM"
            button.toolTip = "Interview Master"
        }

        let menu = NSMenu(title: "Interview Master")

        let showItem = NSMenuItem(title: "Show Window", action: #selector(showMainWindowFromMenu), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        let hideItem = NSMenuItem(title: "Hide Window", action: #selector(hideMainWindowFromMenu), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(NSMenuItem.separator())

        let captureItem = NSMenuItem(title: "Capture Screenshot", action: #selector(captureScreenshotPlaceholder), keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)

        let analyzeItem = NSMenuItem(title: "Analyze / Send Screenshots", action: #selector(analyzeScreenshots), keyEquivalent: "")
        analyzeItem.target = self
        menu.addItem(analyzeItem)

        let interviewItem = NSMenuItem(title: "Start / Stop Interview", action: #selector(toggleInterview), keyEquivalent: "")
        interviewItem.target = self
        menu.addItem(interviewItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let shortcutsItem = NSMenuItem(title: "Keyboard Shortcuts", action: #selector(showKeyboardShortcuts), keyEquivalent: "")
        shortcutsItem.target = self
        menu.addItem(shortcutsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Interview Master", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Interview Master"
        alert.informativeText = "Version 1.0.0\n\nAI-powered interview assistant for software engineers.\n\nCapture coding problems and get instant analysis with Claude AI.\n\n© 2024 Nikolay Prosenikov"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Privacy Policy")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            showPrivacyPolicy()
        }
    }

    @objc func showPrivacyPolicy() {
        if let url = URL(string: "https://github.com/nikolayprosenikov/interview-master/blob/main/PRIVACY.md") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func newNote() {
        switchToNotesTab()
        textView.string = "# New Note\n\n"
        renderMarkdown()
        saveNotes()
    }

    @objc func exportNotes() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text, .plainText]
        savePanel.nameFieldStringValue = "interview-notes.md"
        savePanel.title = "Export Notes"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try textView.string.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                showAlert(title: "Export Failed", message: error.localizedDescription)
            }
        }
    }

    @objc func showHelp() {
        if let url = URL(string: "https://github.com/nikolayprosenikov/interview-master") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func showKeyboardShortcuts() {
        let alert = NSAlert()
        alert.messageText = "Keyboard Shortcuts"
        alert.informativeText = """
        Global (work from any app):
        ⌘B          Toggle window visibility
        ⌘S          Capture screenshot
        ⌘↩          Analyze screenshots

        Navigation:
        ⌘1          Context tab
        ⌘2          Timeline tab

        Editing:
        ⌘F          Find in notes
        ⌘G          Clear screenshots
        ⌘,          Settings

        Window:
        ⌘←↑↓→       Move window
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController.create()
        }
        settingsWindowController?.showWindow(self)
        settingsWindowController?.window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    func maskApiKey(_ key: String) -> String {
        guard key.count > 10 else { return "sk-ant-***" }
        let prefix = String(key.prefix(7))
        let suffix = String(key.suffix(3))
        return "\(prefix)***\(suffix)"
    }
}
