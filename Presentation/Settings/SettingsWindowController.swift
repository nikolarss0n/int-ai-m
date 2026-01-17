import Cocoa

/// Settings window for API key configuration
class SettingsWindowController: NSWindowController {

    private var anthropicField: NSSecureTextField!
    private var groqField: NSSecureTextField!

    static func create() -> SettingsWindowController {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 220),
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
        var y: CGFloat = 160

        // Anthropic API Key
        let anthropicLabel = NSTextField(labelWithString: "Anthropic API Key:")
        anthropicLabel.frame = NSRect(x: padding, y: y, width: 130, height: 20)
        contentView.addSubview(anthropicLabel)

        anthropicField = NSSecureTextField(frame: NSRect(x: 155, y: y, width: 270, height: 24))
        anthropicField.placeholderString = "sk-ant-..."
        if let key = ApiKeyManager.shared.getKey(.anthropic) {
            anthropicField.stringValue = key
        }
        contentView.addSubview(anthropicField)

        y -= 50

        // Groq API Key
        let groqLabel = NSTextField(labelWithString: "Groq API Key:")
        groqLabel.frame = NSRect(x: padding, y: y, width: 130, height: 20)
        contentView.addSubview(groqLabel)

        groqField = NSSecureTextField(frame: NSRect(x: 155, y: y, width: 270, height: 24))
        groqField.placeholderString = "gsk_..."
        if let key = ApiKeyManager.shared.getKey(.groq) {
            groqField.stringValue = key
        }
        contentView.addSubview(groqField)

        y -= 50

        // Help text
        let helpText = NSTextField(wrappingLabelWithString: "API keys are stored securely in your macOS Keychain.")
        helpText.frame = NSRect(x: padding, y: y, width: 410, height: 30)
        helpText.textColor = .secondaryLabelColor
        helpText.font = NSFont.systemFont(ofSize: 11)
        contentView.addSubview(helpText)

        // Save button
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveKeys))
        saveButton.bezelStyle = .rounded
        saveButton.frame = NSRect(x: 350, y: 15, width: 80, height: 30)
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)

        // Cancel button
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelSettings))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: 260, y: 15, width: 80, height: 30)
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)
    }

    @objc private func saveKeys() {
        let anthropicKey = anthropicField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let groqKey = groqField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if !anthropicKey.isEmpty {
            _ = ApiKeyManager.shared.setKey(anthropicKey, for: .anthropic)
        }

        if !groqKey.isEmpty {
            _ = ApiKeyManager.shared.setKey(groqKey, for: .groq)
        }

        NotificationCenter.default.post(name: .apiKeysUpdated, object: nil)
        window?.close()
    }

    @objc private func cancelSettings() {
        window?.close()
    }
}
