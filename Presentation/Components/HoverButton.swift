import Cocoa

/// Custom button with hover and press state animations
@available(macOS 14.0, *)
class HoverButton: NSButton {
    var normalBackgroundColor: NSColor = .clear
    var hoverBackgroundColor: NSColor = .clear
    var pressBackgroundColor: NSColor = .clear
    var normalBorderColor: NSColor = .clear
    var hoverBorderColor: NSColor = .clear

    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isKeyboardFocused = false
    private var focusOutlineLayer: CAShapeLayer?
    private var displayOptionsObserver: NSObjectProtocol?

    override var acceptsFirstResponder: Bool { isEnabled && !isHidden }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        if let displayOptionsObserver {
            NotificationCenter.default.removeObserver(displayOptionsObserver)
        }
    }

    private func commonInit() {
        focusRingType = .none
        displayOptionsObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyVisualState(animated: false)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        ensureFocusOutline()
        applyVisualState(animated: false)
    }

    override func layout() {
        super.layout()
        updateFocusOutlineGeometry()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        applyVisualState(animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyVisualState(animated: true)
    }

    override func mouseDown(with event: NSEvent) {
        applyPressState(animated: true)
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        applyVisualState(animated: true)
        super.mouseUp(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            isKeyboardFocused = true
            applyVisualState(animated: true)
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            isKeyboardFocused = false
            applyVisualState(animated: true)
        }
        return resigned
    }

    override func keyDown(with event: NSEvent) {
        let activates = event.keyCode == 36 || event.keyCode == 49 || event.keyCode == 76
        if activates { applyPressState(animated: true) }
        super.keyDown(with: event)
        if activates { applyVisualState(animated: true) }
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func applyVisualState(animated: Bool) {
        let background = isHovered ? hoverBackgroundColor : normalBackgroundColor
        let border = isKeyboardFocused ? NSColor.keyboardFocusIndicatorColor : (isHovered ? hoverBorderColor : normalBorderColor)
        let transform = reduceMotion || !isHovered ? CATransform3DIdentity : CATransform3DMakeScale(1.02, 1.02, 1.0)
        apply(background: background, border: border, transform: transform, duration: 0.15, animated: animated)
        updateFocusOutlineVisibility()
    }

    private func applyPressState(animated: Bool) {
        let transform = reduceMotion ? CATransform3DIdentity : CATransform3DMakeScale(0.97, 0.97, 1.0)
        let border = isKeyboardFocused ? NSColor.keyboardFocusIndicatorColor : hoverBorderColor
        apply(background: pressBackgroundColor, border: border, transform: transform, duration: 0.08, animated: animated)
    }

    private func apply(
        background: NSColor,
        border: NSColor,
        transform: CATransform3D,
        duration: TimeInterval,
        animated: Bool
    ) {
        guard let layer else { return }
        if reduceMotion || !animated {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.backgroundColor = background.cgColor
            layer.borderColor = border.cgColor
            layer.transform = CATransform3DIdentity
            CATransaction.commit()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().layer?.backgroundColor = background.cgColor
            self.animator().layer?.borderColor = border.cgColor
            self.animator().layer?.transform = transform
        }
    }

    private func ensureFocusOutline() {
        guard let layer else { return }
        if focusOutlineLayer == nil {
            let outline = CAShapeLayer()
            outline.fillColor = NSColor.clear.cgColor
            outline.strokeColor = NSColor.keyboardFocusIndicatorColor.cgColor
            outline.lineWidth = 2
            outline.isHidden = true
            layer.addSublayer(outline)
            focusOutlineLayer = outline
        }
        updateFocusOutlineGeometry()
        updateFocusOutlineVisibility()
    }

    private func updateFocusOutlineGeometry() {
        guard let outline = focusOutlineLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outline.frame = bounds
        let radius = max(4, (layer?.cornerRadius ?? 8) + 2)
        outline.path = CGPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), cornerWidth: radius, cornerHeight: radius, transform: nil)
        CATransaction.commit()
    }

    private func updateFocusOutlineVisibility() {
        ensureFocusOutlineIfNeeded()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        focusOutlineLayer?.isHidden = !isKeyboardFocused
        CATransaction.commit()
    }

    private func ensureFocusOutlineIfNeeded() {
        guard focusOutlineLayer == nil, layer != nil else { return }
        ensureFocusOutline()
    }

    func configureHoverColors(accent: NSColor) {
        normalBackgroundColor = accent.withAlphaComponent(0.15)
        hoverBackgroundColor = accent.withAlphaComponent(0.25)
        pressBackgroundColor = accent.withAlphaComponent(0.35)
        normalBorderColor = accent.withAlphaComponent(0.3)
        hoverBorderColor = accent.withAlphaComponent(0.5)

        layer?.backgroundColor = normalBackgroundColor.cgColor
        layer?.borderColor = normalBorderColor.cgColor
        applyVisualState(animated: false)
    }

    func configureHoverColors(
        normalBackground: NSColor,
        hoverBackground: NSColor,
        pressBackground: NSColor,
        normalBorder: NSColor,
        hoverBorder: NSColor
    ) {
        normalBackgroundColor = normalBackground
        hoverBackgroundColor = hoverBackground
        pressBackgroundColor = pressBackground
        normalBorderColor = normalBorder
        hoverBorderColor = hoverBorder

        layer?.backgroundColor = normalBackground.cgColor
        layer?.borderColor = normalBorder.cgColor
        applyVisualState(animated: false)
    }
}
