import Cocoa

/// Stealth logging for debugging focus behavior
class StealthLogger {
    static let shared = StealthLogger()
    private let logFile: URL
    private let dateFormatter: DateFormatter

    private init() {
        logFile = URL(fileURLWithPath: "/tmp/stealth_log.txt")
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        // Clear log on start
        try? "=== STEALTH LOG STARTED ===\n".write(to: logFile, atomically: true, encoding: .utf8)
        log("🚀 App started - logging all interactions")
    }

    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        print(line, terminator: "") // Console

        // Append to file
        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        }
    }
}

/// Non-activating window - clicks work but don't steal focus from other apps
/// Perfect for stealth mode during proctored assessments
class StealthWindow: NSWindow {
    override var canBecomeKey: Bool {
        return false
    }
    override var canBecomeMain: Bool {
        return false
    }

    override func mouseDown(with event: NSEvent) {
        StealthLogger.shared.log("🖱️ CLICK at (\(Int(event.locationInWindow.x)), \(Int(event.locationInWindow.y))) - canBecomeKey=\(canBecomeKey)")
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
    }

    override func setFrameOrigin(_ point: NSPoint) {
        super.setFrameOrigin(point)
    }

    override func makeKey() {
        StealthLogger.shared.log("🔴 makeKey() called - BLOCKED (would steal focus)")
        // Don't call super - block it
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        StealthLogger.shared.log("🔴 makeKeyAndOrderFront() called - converting to orderFront()")
        orderFront(sender) // Show without taking focus
    }

    override func orderFront(_ sender: Any?) {
        StealthLogger.shared.log("✅ orderFront() - showing window WITHOUT stealing focus")
        super.orderFront(sender)
    }

    override func becomeKey() {
        StealthLogger.shared.log("🔴 becomeKey() called - BLOCKED")
        // Don't call super - block it
    }

    override func resignKey() {
        StealthLogger.shared.log("ℹ️ resignKey() - window resigned key status")
        super.resignKey()
    }
}

/// Presentation: Window Factory
/// Creates and configures application windows
class WindowFactory {

    /// Create the main application window with privacy settings
    static func createMainWindow() -> NSWindow {
        let window = StealthWindow(
            contentRect: NSRect(x: 100, y: 100, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // ⭐ CORE LOGIC: Hidden from screen sharing (DON'T TOUCH!)
        window.sharingType = .none

        // Glass effect settings
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.title = "🔒 Interview Master"

        // Transparent background for glass effect
        window.backgroundColor = .clear
        window.isOpaque = false

        // Start as floating window
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        return window
    }

    /// Create a glass background view
    static func createGlassBackground(for view: NSView) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView(frame: view.bounds)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.material = .menu  // Balanced material - transparent but readable
        visualEffectView.alphaValue = 0.8  // More opaque for blur effect
        return visualEffectView
    }
}
