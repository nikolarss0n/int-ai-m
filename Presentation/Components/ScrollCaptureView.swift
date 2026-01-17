import Cocoa

/// Custom view that captures scroll events for its child scroll view
class ScrollCaptureView: NSView {
    var scrollView: NSScrollView?

    override func scrollWheel(with event: NSEvent) {
        // Forward scroll events to the embedded scroll view
        if let scrollView = scrollView {
            scrollView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Ensure this view blocks events from passing through to views behind it
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, frame.contains(point) else { return nil }
        // Check subviews first (including scroll view)
        if let hit = super.hitTest(point) {
            return hit
        }
        // If no subview handles it, this view handles it (blocks pass-through)
        return self
    }
}
