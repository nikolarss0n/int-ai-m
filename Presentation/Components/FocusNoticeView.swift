import Cocoa

/// Says something to VoiceOver without moving focus: an error at once, anything else without cutting off
/// what is being read. Sighted feedback (a checkmark, a notice) needs this to reach everyone.
func announceForAccessibility(_ text: String, urgent: Bool = false) {
    let priority: NSAccessibilityPriorityLevel = urgent ? .high : .low
    NSAccessibility.post(
        element: NSApp as Any, notification: .announcementRequested,
        userInfo: [.announcement: text, .priority: priority.rawValue]
    )
}

/// One line of feedback in the header's title row: an icon, the message, and what can be done about
/// it. A confirmation goes by itself; an error has a close button and stays until it is dismissed or
/// the thing it is about goes right. The words carry the meaning, so the hue only backs them up.
final class FocusNoticeView: NSView {
    var onAction: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let pill = NSView()
    private let icon = NSImageView()
    private let messageLabel = NSTextField(labelWithString: "")
    private let actionButton = HoverButton(frame: .zero)
    private let dismissButton = HoverButton(frame: .zero)
    private(set) var notice: FeedbackNotice?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isHidden = true
        pill.wantsLayer = true
        addSubview(pill)

        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.symbolConfiguration = Token.Font.symbol(.caption)
        pill.addSubview(icon)

        // Counts change ("Screenshot 2 captured"), so the digits are tabular.
        messageLabel.font = Token.Font.digits(.caption, .semibold)
        messageLabel.lineBreakMode = .byTruncatingTail
        pill.addSubview(messageLabel)

        actionButton.imagePosition = .noImage
        actionButton.isBordered = false
        actionButton.wantsLayer = true
        actionButton.layer?.cornerRadius = Token.Radius.full(Token.Sizing.badge)
        actionButton.layer?.cornerCurve = .continuous
        actionButton.target = self
        actionButton.action = #selector(actionClicked)
        pill.addSubview(actionButton)

        dismissButton.title = ""
        dismissButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Dismiss")
        dismissButton.imagePosition = .imageOnly
        dismissButton.symbolConfiguration = Token.Font.symbol(.micro)
        dismissButton.isBordered = false
        dismissButton.wantsLayer = true
        dismissButton.layer?.cornerRadius = Token.Radius.full(Token.Sizing.badgeSmall)
        dismissButton.apply(.ghost)
        dismissButton.target = self
        dismissButton.action = #selector(dismissClicked)
        dismissButton.toolTip = "Dismiss"
        dismissButton.setAccessibilityLabel("Dismiss")
        pill.addSubview(dismissButton)

        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isShowing: Bool { notice != nil }

    /// Shows a notice, or nothing. A new one fades in; Reduce Motion gets it at once.
    func show(_ next: FeedbackNotice?) {
        let appearing = notice == nil && next != nil
        notice = next
        guard let next else {
            isHidden = true
            return
        }
        let hue = Self.hue(for: next.kind)
        let text = next.kind == .info ? Token.Color.textBody : hue.text
        pill.applySurface(.notice(hue))
        icon.image = NSImage(systemSymbolName: Self.symbol(for: next.kind), accessibilityDescription: nil)
        icon.contentTintColor = text
        messageLabel.stringValue = next.message
        messageLabel.textColor = text
        messageLabel.toolTip = next.detail ?? next.message
        pill.toolTip = next.detail
        actionButton.isHidden = next.actionTitle == nil
        if let title = next.actionTitle {
            actionButton.title = title
            actionButton.attributedTitle = NSAttributedString(string: title, attributes: [
                .font: Token.Font.text(.caption, .semibold),
                .foregroundColor: text
            ])
            actionButton.apply(.noticeAction(hue))
            actionButton.setAccessibilityLabel(title)
            actionButton.toolTip = next.detail
        }
        // A notice that goes by itself needs no close button; one that stays does.
        dismissButton.isHidden = next.lasts != nil
        setAccessibilityLabel([next.message, next.detail].compactMap { $0 }.joined(separator: ". "))
        isHidden = false
        needsLayout = true
        layoutSubtreeIfNeeded()
        if appearing, !Token.Motion.reducesMotion(), let layer = pill.layer {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = Token.Motion.fadeIn
            layer.add(fade, forKey: "fadeIn")
        }
    }

    static func hue(for kind: FeedbackKind) -> Token.Hue {
        switch kind {
        case .info: return .neutral
        case .success: return .success
        case .warning: return .warning
        case .error: return .danger
        }
    }

    static func symbol(for kind: FeedbackKind) -> String {
        switch kind {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "exclamationmark.octagon.fill"
        }
    }

    override func layout() {
        super.layout()
        guard notice != nil else { return }
        let height = Token.Sizing.notice
        let edge = Token.Space.md
        let iconSize: CGFloat = 14
        let messageX = edge + iconSize + Token.Space.sm
        var trailing = edge
        var actionWidth: CGFloat = 0
        if !actionButton.isHidden {
            actionWidth = ceil(actionButton.attributedTitle.size().width) + 20
            trailing += actionWidth + Token.Space.sm
        }
        let dismissSize = Token.Sizing.badgeSmall
        if !dismissButton.isHidden { trailing += dismissSize + Token.Space.xs }
        let wanted = ceil(messageLabel.attributedStringValue.size().width) + 4
        let messageWidth = max(40, min(wanted, bounds.width - messageX - trailing))
        let pillWidth = min(bounds.width, messageX + messageWidth + trailing)
        pill.frame = NSRect(x: 0, y: (bounds.height - height) / 2, width: pillWidth, height: height)
        icon.frame = NSRect(x: edge, y: (height - iconSize) / 2, width: iconSize, height: iconSize)
        messageLabel.frame = NSRect(x: messageX, y: (height - 18) / 2, width: messageWidth, height: 18)
        var x = messageX + messageWidth + Token.Space.sm
        if actionWidth > 0 {
            actionButton.frame = NSRect(x: x, y: (height - Token.Sizing.badge) / 2, width: actionWidth, height: Token.Sizing.badge)
            x += actionWidth
        }
        if !dismissButton.isHidden {
            dismissButton.frame = NSRect(x: pillWidth - edge - dismissSize + Token.Space.xs, y: (height - dismissSize) / 2, width: dismissSize, height: dismissSize)
        }
    }

    @objc private func actionClicked() { onAction?() }
    @objc private func dismissClicked() { onDismiss?() }
}
