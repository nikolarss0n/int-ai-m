import Cocoa

// MARK: - Apple HIG Colors
extension NSColor {
    /// Apple HIG Green (52, 199, 89)
    static let appleGreen = NSColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1.0)
    /// Apple HIG Red (255, 59, 48)
    static let appleRed = NSColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1.0)
    /// Apple HIG Purple (175, 82, 222)
    static let applePurple = NSColor(red: 0.686, green: 0.322, blue: 0.871, alpha: 1.0)
    /// Apple Gold (255, 214, 0) - matches our active tab color
    static let appleGold = NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)

    /// Claude brand colors - warm coral/terracotta gradient
    static let claudeCoral = NSColor(red: 0.85, green: 0.467, blue: 0.341, alpha: 1.0)      // #D97757
    static let claudeOrange = NSColor(red: 0.914, green: 0.545, blue: 0.396, alpha: 1.0)    // #E98B65
    static let claudePeach = NSColor(red: 0.957, green: 0.643, blue: 0.525, alpha: 1.0)     // #F4A486
    static let claudeSand = NSColor(red: 0.878, green: 0.698, blue: 0.565, alpha: 1.0)      // #E0B290
}

// MARK: - NSBezierPath CGPath Extension
extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath: path.closeSubpath()
            case .cubicCurveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo: path.addQuadCurve(to: points[1], control: points[0])
            @unknown default: break
            }
        }
        return path
    }
}

// MARK: - Design Helpers
extension NSView {
    /// Add subtle drop shadow to view
    func addDropShadow(opacity: Float = 0.3, radius: CGFloat = 8, offset: CGSize = CGSize(width: 0, height: -2)) {
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = opacity
        layer?.shadowRadius = radius
        layer?.shadowOffset = offset
        layer?.masksToBounds = false
    }

    /// Add glassmorphism effect (frosted glass)
    func addGlassEffect() {
        wantsLayer = true
        if let visualEffectView = self as? NSVisualEffectView {
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
        }
    }
}

extension NSButton {
    /// Add hover effect tracking
    func addHoverEffect() {
        wantsLayer = true
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["hoverButton": true]
        )
        addTrackingArea(trackingArea)
    }
}
