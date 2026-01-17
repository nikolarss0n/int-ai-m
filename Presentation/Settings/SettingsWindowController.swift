import Cocoa

/// Settings window for API keys and interview configuration
class SettingsWindowController: NSWindowController {

    // API Keys
    private var anthropicField: NSSecureTextField!
    private var groqField: NSSecureTextField!

    // Interview Settings
    private var roleDropdown: NSPopUpButton!
    private var programmingLanguageDropdown: NSPopUpButton!
    private var speakingLanguageDropdown: NSPopUpButton!
    private var frameworksField: NSTextField!

    static func create() -> SettingsWindowController {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()

        let controller = SettingsWindowController(window: window)
        controller.setupUI()
        return controller
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        let padding: CGFloat = 20
        let labelWidth: CGFloat = 140
        let fieldX: CGFloat = 165
        let fieldWidth: CGFloat = 310
        var y: CGFloat = 370

        // ========== INTERVIEW SETTINGS SECTION ==========
        let interviewHeader = createSectionHeader("Interview Settings")
        interviewHeader.frame = NSRect(x: padding, y: y, width: 200, height: 20)
        contentView.addSubview(interviewHeader)

        y -= 35

        // Role
        let roleLabel = NSTextField(labelWithString: "Position/Role:")
        roleLabel.frame = NSRect(x: padding, y: y, width: labelWidth, height: 20)
        contentView.addSubview(roleLabel)

        roleDropdown = NSPopUpButton(frame: NSRect(x: fieldX, y: y - 2, width: fieldWidth, height: 26), pullsDown: false)
        for role in InterviewRole.allCases {
            roleDropdown.addItem(withTitle: role.displayName)
        }
        selectDropdownItem(roleDropdown, matching: AppSettings.shared.role.displayName)
        contentView.addSubview(roleDropdown)

        y -= 35

        // Programming Language
        let progLangLabel = NSTextField(labelWithString: "Programming Language:")
        progLangLabel.frame = NSRect(x: padding, y: y, width: labelWidth, height: 20)
        contentView.addSubview(progLangLabel)

        programmingLanguageDropdown = NSPopUpButton(frame: NSRect(x: fieldX, y: y - 2, width: fieldWidth, height: 26), pullsDown: false)
        for lang in ProgrammingLanguage.allCases {
            programmingLanguageDropdown.addItem(withTitle: lang.displayName)
        }
        selectDropdownItem(programmingLanguageDropdown, matching: AppSettings.shared.programmingLanguage.displayName)
        contentView.addSubview(programmingLanguageDropdown)

        y -= 35

        // Speaking Language
        let speakingLabel = NSTextField(labelWithString: "Response Language:")
        speakingLabel.frame = NSRect(x: padding, y: y, width: labelWidth, height: 20)
        contentView.addSubview(speakingLabel)

        speakingLanguageDropdown = NSPopUpButton(frame: NSRect(x: fieldX, y: y - 2, width: fieldWidth, height: 26), pullsDown: false)
        for lang in SpeakingLanguage.allCases {
            speakingLanguageDropdown.addItem(withTitle: lang.displayName)
        }
        selectDropdownItem(speakingLanguageDropdown, matching: AppSettings.shared.speakingLanguage.displayName)
        contentView.addSubview(speakingLanguageDropdown)

        y -= 35

        // Frameworks/Tech Stack
        let frameworksLabel = NSTextField(labelWithString: "Tech Stack:")
        frameworksLabel.frame = NSRect(x: padding, y: y, width: labelWidth, height: 20)
        contentView.addSubview(frameworksLabel)

        frameworksField = NSTextField(frame: NSRect(x: fieldX, y: y - 2, width: fieldWidth, height: 24))
        frameworksField.placeholderString = "Playwright, Pytest, AWS, React..."
        frameworksField.stringValue = AppSettings.shared.frameworks
        contentView.addSubview(frameworksField)

        y -= 20

        // Help text for frameworks
        let frameworksHelp = NSTextField(labelWithString: "Comma-separated list of frameworks and tools you use")
        frameworksHelp.frame = NSRect(x: fieldX, y: y, width: fieldWidth, height: 16)
        frameworksHelp.textColor = .secondaryLabelColor
        frameworksHelp.font = NSFont.systemFont(ofSize: 10)
        contentView.addSubview(frameworksHelp)

        y -= 35

        // Divider
        let divider = NSBox(frame: NSRect(x: padding, y: y, width: 460, height: 1))
        divider.boxType = .separator
        contentView.addSubview(divider)

        y -= 25

        // ========== API KEYS SECTION ==========
        let apiHeader = createSectionHeader("API Keys")
        apiHeader.frame = NSRect(x: padding, y: y, width: 200, height: 20)
        contentView.addSubview(apiHeader)

        y -= 35

        // Anthropic API Key
        let anthropicLabel = NSTextField(labelWithString: "Anthropic API Key:")
        anthropicLabel.frame = NSRect(x: padding, y: y, width: labelWidth, height: 20)
        contentView.addSubview(anthropicLabel)

        anthropicField = NSSecureTextField(frame: NSRect(x: fieldX, y: y - 2, width: fieldWidth, height: 24))
        anthropicField.placeholderString = "sk-ant-..."
        if let key = ApiKeyManager.shared.getKey(.anthropic) {
            anthropicField.stringValue = key
        }
        contentView.addSubview(anthropicField)

        y -= 35

        // Groq API Key
        let groqLabel = NSTextField(labelWithString: "Groq API Key:")
        groqLabel.frame = NSRect(x: padding, y: y, width: labelWidth, height: 20)
        contentView.addSubview(groqLabel)

        groqField = NSSecureTextField(frame: NSRect(x: fieldX, y: y - 2, width: fieldWidth, height: 24))
        groqField.placeholderString = "gsk_..."
        if let key = ApiKeyManager.shared.getKey(.groq) {
            groqField.stringValue = key
        }
        contentView.addSubview(groqField)

        y -= 30

        // Help text
        let helpText = NSTextField(wrappingLabelWithString: "API keys are stored securely in your macOS Keychain.")
        helpText.frame = NSRect(x: padding, y: y, width: 460, height: 20)
        helpText.textColor = .secondaryLabelColor
        helpText.font = NSFont.systemFont(ofSize: 11)
        contentView.addSubview(helpText)

        // ========== BUTTONS ==========
        // Save button
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        saveButton.bezelStyle = .rounded
        saveButton.frame = NSRect(x: 395, y: 15, width: 80, height: 30)
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)

        // Cancel button
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelSettings))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: 305, y: 15, width: 80, height: 30)
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)
    }

    private func createSectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.textColor = .labelColor
        return label
    }

    private func selectDropdownItem(_ dropdown: NSPopUpButton, matching title: String) {
        for i in 0..<dropdown.numberOfItems {
            if dropdown.item(at: i)?.title == title {
                dropdown.selectItem(at: i)
                return
            }
        }
    }

    @objc private func saveSettings() {
        // Save Interview Settings
        if let selectedRole = roleDropdown.selectedItem?.title,
           let role = InterviewRole.allCases.first(where: { $0.displayName == selectedRole }) {
            AppSettings.shared.role = role
        }

        if let selectedLang = programmingLanguageDropdown.selectedItem?.title,
           let lang = ProgrammingLanguage.allCases.first(where: { $0.displayName == selectedLang }) {
            AppSettings.shared.programmingLanguage = lang
        }

        if let selectedSpeaking = speakingLanguageDropdown.selectedItem?.title,
           let lang = SpeakingLanguage.allCases.first(where: { $0.displayName == selectedSpeaking }) {
            AppSettings.shared.speakingLanguage = lang
        }

        AppSettings.shared.frameworks = frameworksField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // Save API Keys
        let anthropicKey = anthropicField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let groqKey = groqField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if !anthropicKey.isEmpty {
            _ = ApiKeyManager.shared.setKey(anthropicKey, for: .anthropic)
        }

        if !groqKey.isEmpty {
            _ = ApiKeyManager.shared.setKey(groqKey, for: .groq)
        }

        NotificationCenter.default.post(name: .apiKeysUpdated, object: nil)
        NotificationCenter.default.post(name: .interviewSettingsUpdated, object: nil)
        window?.close()
    }

    @objc private func cancelSettings() {
        window?.close()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let interviewSettingsUpdated = Notification.Name("InterviewSettingsUpdated")
}
