import Cocoa

/// Claude Code ASCII logo using block characters
class ClaudeLogoView: NSView {
    private var label: NSTextField!

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupLogo()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLogo()
    }

    private func setupLogo() {
        wantsLayer = true

        // Claude Code logo using Unicode block characters
        let logoText = "▐▛███▜▌\n▝▜█████▛▘\n ▘▘ ▝▝"

        label = NSTextField(labelWithString: logoText)
        label.font = NSFont.monospacedSystemFont(ofSize: 6, weight: .regular)
        label.textColor = NSColor.claudeCoral
        label.alignment = .center
        label.maximumNumberOfLines = 3
        label.lineBreakMode = .byClipping
        label.frame = bounds
        label.autoresizingMask = [.width, .height]
        addSubview(label)
    }

    func setColor(_ color: NSColor) {
        label.textColor = color
    }

    func setAlpha(_ alpha: CGFloat) {
        label.alphaValue = alpha
    }
}
