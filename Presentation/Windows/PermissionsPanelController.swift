import Cocoa

/// Protocol for permissions panel callbacks
protocol PermissionsPanelDelegate: AnyObject {
    var dataConsentKey: String { get }
}

/// Controller for the permissions setup panel
class PermissionsPanelController {
    private weak var delegate: PermissionsPanelDelegate?

    // UI Elements
    private(set) var panel: NSView?
    private var screenRecordingStatusLabel: NSTextField?
    private var dataConsentStatusLabel: NSTextField?
    private var permissionCheckTimer: Timer?

    init(delegate: PermissionsPanelDelegate) {
        self.delegate = delegate
    }

    deinit {
        stopMonitoring()
    }

    /// Setup the permissions panel in the parent view
    func setup(in parentView: NSView) {
        // Center the panel vertically and horizontally
        let panelWidth: CGFloat = 560
        let panelHeight: CGFloat = 360
        let panel = NSVisualEffectView(frame: NSRect(
            x: (parentView.frame.width - panelWidth) / 2,
            y: (parentView.frame.height - panelHeight) / 2,
            width: panelWidth,
            height: panelHeight
        ))
        panel.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        panel.blendingMode = .withinWindow
        panel.material = .hudWindow
        panel.state = .active
        panel.alphaValue = 0.96
        panel.wantsLayer = true
        panel.layer?.cornerRadius = 20
        panel.layer?.borderWidth = 2.0
        panel.layer?.borderColor = NSColor.appleGold.withAlphaComponent(0.6).cgColor
        parentView.addSubview(panel)
        self.panel = panel

        // Title
        let title = NSTextField(labelWithString: "🔐 Setup Required")
        title.frame = NSRect(x: 40, y: panel.frame.height - 60, width: panel.frame.width - 80, height: 35)
        title.font = .systemFont(ofSize: 26, weight: .bold)
        title.textColor = .white
        title.alignment = .center
        panel.addSubview(title)

        // Subtitle
        let subtitle = NSTextField(labelWithString: "Complete the following steps to use Interview Master")
        subtitle.frame = NSRect(x: 40, y: panel.frame.height - 88, width: panel.frame.width - 80, height: 20)
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = NSColor.white.withAlphaComponent(0.75)
        subtitle.alignment = .center
        panel.addSubview(subtitle)

        // Screen Recording Permission (top row)
        createPermissionRow(
            in: panel,
            yOffset: panel.frame.height - 175,
            icon: "📸",
            title: "Screen Recording",
            description: "Capture coding problems during interviews",
            buttonTitle: "Open Settings",
            action: #selector(openScreenRecordingSettings),
            isScreenRecording: true
        )

        // Anthropic Data Consent (bottom row)
        createPermissionRow(
            in: panel,
            yOffset: panel.frame.height - 260,
            icon: "🤖",
            title: "AI Data Sharing",
            description: "Send screenshots to Anthropic Claude for analysis",
            buttonTitle: "I Consent",
            action: #selector(grantDataConsent),
            isScreenRecording: false
        )

        // Hint text at bottom
        let hint = NSTextField(labelWithString: "Global shortcuts (⌘B, ⌘S, ⌘Enter) work from any app")
        hint.frame = NSRect(x: 40, y: 20, width: panel.frame.width - 80, height: 16)
        hint.font = .systemFont(ofSize: 11, weight: .regular)
        hint.textColor = NSColor.white.withAlphaComponent(0.5)
        hint.alignment = .center
        panel.addSubview(hint)

        // Check permissions and update UI
        updateStatus()
        startMonitoring()
    }

    private func createPermissionRow(in panel: NSView, yOffset: CGFloat, icon: String, title: String, description: String, buttonTitle: String, action: Selector, isScreenRecording: Bool) {
        // Container
        let container = NSView(frame: NSRect(x: 40, y: yOffset, width: panel.frame.width - 80, height: 70))
        panel.addSubview(container)

        // Icon
        let iconLabel = NSTextField(labelWithString: icon)
        iconLabel.frame = NSRect(x: 0, y: 20, width: 40, height: 30)
        iconLabel.font = .systemFont(ofSize: 28)
        iconLabel.alignment = .center
        container.addSubview(iconLabel)

        // Title & Description
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.frame = NSRect(x: 50, y: 38, width: 200, height: 20)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        container.addSubview(titleLabel)

        let descLabel = NSTextField(labelWithString: description)
        descLabel.frame = NSRect(x: 50, y: 18, width: 300, height: 18)
        descLabel.font = .systemFont(ofSize: 12, weight: .regular)
        descLabel.textColor = NSColor.white
        container.addSubview(descLabel)

        // Status indicator
        let statusLabel = NSTextField(labelWithString: "⚠️ Required")
        statusLabel.frame = NSRect(x: container.frame.width - 180, y: 42, width: 120, height: 18)
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .systemOrange
        statusLabel.alignment = .right
        container.addSubview(statusLabel)

        // Store reference based on type
        if isScreenRecording {
            screenRecordingStatusLabel = statusLabel
        } else {
            dataConsentStatusLabel = statusLabel
        }

        // Action button
        let button = NSButton(frame: NSRect(x: container.frame.width - 120, y: 12, width: 120, height: 28))
        button.title = buttonTitle
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        button.font = .systemFont(ofSize: 12, weight: .medium)
        container.addSubview(button)
    }

    @objc func openScreenRecordingSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    @objc func grantDataConsent() {
        guard let key = delegate?.dataConsentKey else { return }
        UserDefaults.standard.set(true, forKey: key)
        updateStatus()
    }

    func updateStatus() {
        guard let key = delegate?.dataConsentKey else { return }

        let hasScreenRecording = CGPreflightScreenCaptureAccess()
        let hasDataConsent = UserDefaults.standard.bool(forKey: key)

        screenRecordingStatusLabel?.stringValue = hasScreenRecording ? "✅ Enabled" : "⚠️ Required"
        screenRecordingStatusLabel?.textColor = hasScreenRecording ? .appleGreen : .systemOrange

        dataConsentStatusLabel?.stringValue = hasDataConsent ? "✅ Granted" : "⚠️ Required"
        dataConsentStatusLabel?.textColor = hasDataConsent ? .appleGreen : .systemOrange

        // Hide panel if both permissions granted
        if hasScreenRecording && hasDataConsent {
            panel?.isHidden = true
            stopMonitoring()
        } else {
            panel?.isHidden = false
        }
    }

    func startMonitoring() {
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    func stopMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
}
