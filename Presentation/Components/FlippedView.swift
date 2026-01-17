import Cocoa

/// Flipped view where Y=0 is at the top (like iOS)
/// Used for timeline so newest messages appear at top
class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
