import Cocoa
import Carbon

@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    func setupHotkey() {
        StealthLogger.shared.log("🔧 setupHotkey() called")

        // Request accessibility permission (shows system dialog if not granted)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        StealthLogger.shared.log("🔧 AXIsProcessTrusted = \(trusted)")

        if trusted {
            // Permission granted - set up event tap immediately
            setupEventTap()
        } else {
            // Permission not yet granted - poll until user grants it
            StealthLogger.shared.log("🔧 Waiting for Accessibility permission...")
            setupFallbackHotkeys()
            startAccessibilityPermissionPolling()
        }

        // Local hotkey for when app is active (still needed for some actions)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // ESC = Close search
            if event.keyCode == 53 && self.isSearchVisible {
                self.toggleSearch()
                return nil
            }

            // ⌘+Arrow Keys = Move window (only when app is focused)
            if event.modifierFlags.contains(.command) {
                let moveDistance: CGFloat = 20
                var newOrigin = self.window.frame.origin

                switch event.keyCode {
                case 123: // Left arrow
                    newOrigin.x -= moveDistance
                    self.window.setFrameOrigin(newOrigin)
                    return nil
                case 124: // Right arrow
                    newOrigin.x += moveDistance
                    self.window.setFrameOrigin(newOrigin)
                    return nil
                case 125: // Down arrow
                    newOrigin.y -= moveDistance
                    self.window.setFrameOrigin(newOrigin)
                    return nil
                case 126: // Up arrow
                    newOrigin.y += moveDistance
                    self.window.setFrameOrigin(newOrigin)
                    return nil
                default:
                    break
                }
            }

            return event
        }
    }

    /// Set up CGEvent tap to intercept and consume global hotkeys
    /// This prevents shortcuts from reaching VSCode, browsers, etc.
    func setupEventTap() {
        StealthLogger.shared.log("🔧 setupEventTap() called")

        // Event mask for key down events
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        StealthLogger.shared.log("🔧 Event mask: \(eventMask)")

        // Create event tap - intercepts at session level
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                // Get self reference from refcon
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let delegate = Unmanaged<InterviewMasterDelegate>.fromOpaque(refcon).takeUnretainedValue()

                // Handle the event
                return delegate.handleGlobalKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            StealthLogger.shared.log("❌ Failed to create event tap - need Accessibility permission")
            // Fall back to NSEvent monitor (won't block shortcuts)
            setupFallbackHotkeys()
            return
        }

        self.eventTap = tap

        // Add to run loop
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        self.runLoopSource = runLoopSource

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)

        let isEnabled = CGEvent.tapIsEnabled(tap: tap)
        StealthLogger.shared.log("✅ CGEvent tap installed - enabled=\(isEnabled)")
    }

    /// Handle global key events - return nil to consume, return event to pass through
    func handleGlobalKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if macOS disabled it (timeout or user input)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = self.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                StealthLogger.shared.log("⚠️ Event tap was disabled by macOS, re-enabled")
            }
            return Unmanaged.passRetained(event)
        }

        // Check if it's a key event
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let hasCommand = flags.contains(.maskCommand)
        let hasShift = flags.contains(.maskShift)
        let hasControl = flags.contains(.maskControl)
        let hasOption = flags.contains(.maskAlternate)

        // Log all ⌘ key events for debugging
        if hasCommand {
            var mods = "⌘"
            if hasShift { mods += "⇧" }
            if hasControl { mods += "⌃" }
            if hasOption { mods += "⌥" }
            StealthLogger.shared.log("⌨️ KEY: \(mods)+keyCode=\(keyCode)")
        }

        // Only intercept ⌘ combinations
        guard hasCommand else {
            return Unmanaged.passRetained(event)
        }

        // ⌘+I = Toggle ghost mode (transparent + click-through) - does NOT start/stop interview
        if keyCode == 34 && !hasShift { // 'I' key
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+I (ghost mode) - CONSUMED")
            DispatchQueue.main.async { [weak self] in self?.toggleInterviewMode() }
            return nil // Consume - don't pass to other apps
        }

        // ⌘+B = Toggle window visibility
        if keyCode == 11 && !hasShift { // 'B' key
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+B (toggle window) - CONSUMED")
            DispatchQueue.main.async { [weak self] in self?.toggleWindowVisibility() }
            return nil // Consume
        }

        // ⌘+S = Capture screenshot (GLOBAL)
        if keyCode == 1 && !hasShift { // 'S' key
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+S (screenshot) - CONSUMED")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.currentTab != .voice {
                    self.switchToVoiceTab()
                }
                self.captureScreenshotPlaceholder()
            }
            return nil // Consume
        }

        // ⌘+Enter = Analyze screenshots (GLOBAL)
        if keyCode == 36 && !hasShift { // Enter key
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+Enter (analyze) - CONSUMED")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.window.isVisible && self.currentTab != .voice {
                    self.switchToVoiceTab()
                }
                self.analyzeScreenshots()
            }
            return nil // Consume
        }

        // ⌘+G = Clear/Reset (when visible)
        if keyCode == 5 && !hasShift && self.window.isVisible { // 'G' key
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+G (clear) - CONSUMED")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.currentTab == .voice {
                    self.clearScreenshotsFromTimeline()
                } else if self.currentTab == .coding {
                    self.resetCodingTab()
                }
            }
            return nil // Consume
        }

        // ⌘+1 = Notes tab (when visible)
        if keyCode == 18 && !hasShift && self.window.isVisible {
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+1 (notes) - CONSUMED")
            DispatchQueue.main.async { [weak self] in self?.switchToNotesTab() }
            return nil
        }

        // ⌘+2 = Voice tab (when visible)
        if keyCode == 19 && !hasShift && self.window.isVisible {
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+2 (voice) - CONSUMED")
            DispatchQueue.main.async { [weak self] in self?.switchToVoiceTab() }
            return nil
        }

        // ⌘+F = Search (when visible in notes)
        if keyCode == 3 && !hasShift && self.window.isVisible && self.currentTab == .notes {
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+F (search) - CONSUMED")
            DispatchQueue.main.async { [weak self] in self?.toggleSearch() }
            return nil
        }

        // Pass through all other shortcuts
        return Unmanaged.passRetained(event)
    }

    /// Poll for Accessibility permission and set up event tap when granted
    func startAccessibilityPermissionPolling() {
        accessibilityPermissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if AXIsProcessTrusted() {
                StealthLogger.shared.log("✅ Accessibility permission granted - setting up event tap")
                timer.invalidate()
                self.accessibilityPermissionTimer = nil

                // Remove fallback monitor before installing event tap
                if let monitor = self.eventMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.eventMonitor = nil
                }

                self.setupEventTap()
            }
        }
    }

    /// Fallback to NSEvent monitor if CGEvent tap fails (no accessibility permission)
    func setupFallbackHotkeys() {
        StealthLogger.shared.log("⚠️ Using FALLBACK hotkeys (NSEvent monitor - cannot intercept)")
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }

            guard event.modifierFlags.contains(.command) else { return }

            StealthLogger.shared.log("⌨️ FALLBACK: ⌘+keyCode=\(event.keyCode)")

            switch event.keyCode {
            case 34: // I - ghost mode only (no interview start/stop)
                StealthLogger.shared.log("⌨️ FALLBACK: ⌘+I (ghost mode)")
                self.toggleInterviewMode()
            case 11: // B
                StealthLogger.shared.log("⌨️ FALLBACK: ⌘+B (toggle window)")
                self.toggleWindowVisibility()
            case 1: // S
                StealthLogger.shared.log("⌨️ FALLBACK: ⌘+S (screenshot)")
                if self.currentTab != .voice { self.switchToVoiceTab() }
                self.captureScreenshotPlaceholder()
            case 36: // Enter
                StealthLogger.shared.log("⌨️ FALLBACK: ⌘+Enter (analyze)")
                if self.window.isVisible && self.currentTab != .voice { self.switchToVoiceTab() }
                self.analyzeScreenshots()
            default:
                break
            }
        }
    }
}
