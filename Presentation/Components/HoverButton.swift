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
        animateToHoverState()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        animateToNormalState()
    }

    override func mouseDown(with event: NSEvent) {
        animateToPressState()
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if isHovered {
            animateToHoverState()
        } else {
            animateToNormalState()
        }
        super.mouseUp(with: event)
    }

    private func animateToHoverState() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().layer?.backgroundColor = hoverBackgroundColor.cgColor
            self.animator().layer?.borderColor = hoverBorderColor.cgColor
            self.animator().layer?.transform = CATransform3DMakeScale(1.02, 1.02, 1.0)
        }
    }

    private func animateToNormalState() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().layer?.backgroundColor = normalBackgroundColor.cgColor
            self.animator().layer?.borderColor = normalBorderColor.cgColor
            self.animator().layer?.transform = CATransform3DIdentity
        }
    }

    private func animateToPressState() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().layer?.backgroundColor = pressBackgroundColor.cgColor
            self.animator().layer?.transform = CATransform3DMakeScale(0.97, 0.97, 1.0)
        }
    }

    func configureHoverColors(accent: NSColor) {
        normalBackgroundColor = accent.withAlphaComponent(0.15)
        hoverBackgroundColor = accent.withAlphaComponent(0.25)
        pressBackgroundColor = accent.withAlphaComponent(0.35)
        normalBorderColor = accent.withAlphaComponent(0.3)
        hoverBorderColor = accent.withAlphaComponent(0.5)

        layer?.backgroundColor = normalBackgroundColor.cgColor
        layer?.borderColor = normalBorderColor.cgColor
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
    }
}
