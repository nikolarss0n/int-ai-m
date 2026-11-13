import Cocoa
import Carbon

/// Shortcuts registered with the system itself. They need no Accessibility permission, so they are what
/// the app has left when the event tap cannot be created. A registered key is taken from every app, so
/// each one is registered only while it has something to do.
final class SystemHotkeys {
    static let shared = SystemHotkeys()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var installed = false
    private static let signature: OSType = 0x494D4853 // "IMHS"

    private func installHandler() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &id
            )
            guard status == noErr else { return status }
            DispatchQueue.main.async { SystemHotkeys.shared.actions[id.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// Registers the key while `enabled`, and gives it back to the other apps otherwise.
    func set(_ id: UInt32, keyCode: Int, modifiers: Int, enabled: Bool, action: @escaping () -> Void) {
        if enabled {
            actions[id] = action
            guard refs[id] == nil else { return }
            installHandler()
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: Self.signature, id: id),
                GetApplicationEventTarget(), 0, &ref
            )
            if status == noErr, let ref {
                refs[id] = ref
            } else {
                StealthLogger.shared.log("⚠️ SYSTEM HOTKEY \(id) not registered (status \(status))")
            }
        } else if let ref = refs.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
            actions[id] = nil
        }
    }

    func removeAll() {
        refs.values.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actions.removeAll()
    }

    var registeredIDs: [UInt32] { refs.keys.sorted() }
}

@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    private func hasBlockingModalUI() -> Bool {
        NSApp.modalWindow != nil || window?.attachedSheet != nil
    }

    /// Moves the window one step in the arrow's direction. It can cross to another display but not leave them all.
    func nudgeWindow(keyCode: Int) {
        let step: CGFloat = 40
        var origin = window.frame.origin
        switch keyCode {
        case 123: origin.x -= step
        case 124: origin.x += step
        case 125: origin.y -= step
        case 126: origin.y += step
        default: return
        }
        let screens = NSScreen.screens.map(\.visibleFrame)
        if let first = screens.first {
            let visible = screens.dropFirst().reduce(first) { $0.union($1) }
            origin.x = min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - window.frame.width))
            origin.y = min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - window.frame.height))
        }
        window.setFrameOrigin(origin)
    }

    private func isApplicationHotkey(_ keyCode: Int64) -> Bool {
        switch keyCode {
        case 1, 3, 5, 11, 18, 19, 20, 21, 34, 36, 76, 123, 124, 125, 126:
            return true
        default:
            return false
        }
    }

    private func practiceShouldConsumeReservedShortcuts() -> Bool {
        guard currentTab == .practice,
              window?.isVisible == true,
              let stealthWindow = window as? StealthWindow else { return false }
        return stealthWindow.isPracticeInteractionEnabled
    }

    private func practiceOwnsKeyboard() -> Bool {
        guard practiceShouldConsumeReservedShortcuts(),
              NSApp.modalWindow == nil,
              window?.attachedSheet == nil else { return false }
        return true
    }

    private var pushToTalkEventTapIsActive: Bool {
        eventTap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
    }

    private func handleFallbackPushToTalk(_ event: NSEvent) -> Bool {
        guard !pushToTalkEventTapIsActive else { return false }
        return handlePushToTalkKey(
            keyCode: Int(event.keyCode), isDown: event.type == .keyDown,
            command: event.modifierFlags.contains(.command),
            shift: event.modifierFlags.contains(.shift),
            control: event.modifierFlags.contains(.control),
            option: event.modifierFlags.contains(.option), isRepeat: event.isARepeat
        )
    }

    func setupHotkey() {
        StealthLogger.shared.log("🔧 setupHotkey() called")

        // Check quietly on startup. The app's permissions panel owns the user-driven
        // path to System Settings; startup should not trigger Apple's prompt every run.
        let trusted = AXIsProcessTrusted()
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
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return event }

            // Releases belong to the tracked gesture even after modifiers/focus change.
            if self.handleFallbackPushToTalk(event) { return nil }
            guard event.type == .keyDown else { return event }

            if event.modifierFlags.contains(.command),
               self.hasBlockingModalUI(),
               self.isApplicationHotkey(Int64(event.keyCode)) {
                return nil
            }

            // ESC = Close search
            if event.keyCode == 53 && self.isSearchVisible {
                self.toggleSearch()
                return nil
            }

            // Practice owns its primary action and typing-oriented shortcuts.
            // Handle them locally when Accessibility permission is unavailable;
            // the CGEvent tap handles the same keys when it is installed.
            if self.practiceShouldConsumeReservedShortcuts(),
               event.modifierFlags.contains(.command),
               !event.modifierFlags.contains(.shift) {
                if event.isARepeat { return nil }
                let mayPerformAction = self.practiceOwnsKeyboard()
                switch event.keyCode {
                case 36, 76: // Return or keypad Enter
                    guard mayPerformAction else { return nil }
                    StealthLogger.shared.log("⌨️ PRACTICE: ⌘+Enter (primary action) - CONSUMED")
                    self.practiceTabController.performPrimaryAction()
                    return nil
                case 1, 5: // S or G
                    StealthLogger.shared.log("⌨️ PRACTICE: global shortcut suspended - CONSUMED")
                    return nil
                default:
                    break
                }
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

        // Push-to-talk must receive the matching release, including modifier-free key-up.
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
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
        SystemHotkeys.shared.removeAll()

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
        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let hasCommand = flags.contains(.maskCommand)
        let hasShift = flags.contains(.maskShift)
        let hasControl = flags.contains(.maskControl)
        let hasOption = flags.contains(.maskAlternate)

        if handlePushToTalkKey(
            keyCode: Int(keyCode), isDown: type == .keyDown,
            command: hasCommand, shift: hasShift, control: hasControl, option: hasOption,
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        ) { return nil }
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

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

        if hasBlockingModalUI(), isApplicationHotkey(keyCode) {
            StealthLogger.shared.log("⌨️ HOTKEY: app shortcut suspended while a modal is open - CONSUMED")
            return nil
        }

        // Practice must retain keyboard ownership. These commands otherwise
        // switch to Timeline/Coding and interrupt the learner's response.
        if practiceShouldConsumeReservedShortcuts() && !hasShift {
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return nil }
            let mayPerformAction = practiceOwnsKeyboard()
            switch keyCode {
            case 36, 76: // Return or keypad Enter
                guard mayPerformAction else { return nil }
                StealthLogger.shared.log("⌨️ PRACTICE: ⌘+Enter (primary action) - CONSUMED")
                DispatchQueue.main.async { [weak self] in
                    self?.practiceTabController.performPrimaryAction()
                }
                return nil
            case 1, 5: // S or G
                StealthLogger.shared.log("⌨️ PRACTICE: global shortcut suspended - CONSUMED")
                return nil
            default:
                break
            }
        }

        // ⌘⌃ arrows = Move the window, from any app: the window never takes the keyboard, so a shortcut
        // that needs it focused would never fire. Holding the key keeps it moving.
        if hasControl && !hasOption && !hasShift && self.window.isVisible, (123...126).contains(keyCode) {
            DispatchQueue.main.async { [weak self] in self?.nudgeWindow(keyCode: Int(keyCode)) }
            return nil
        }

        // ⌘⌥↑ / ⌘⌥↓ = Previous or next question, ⌘⌥← / ⌘⌥→ = Previous or next step of the code, ⌘⌥C = Copy the code on screen, ⌘⌥A = Answer over the
        // code and back. Only during a visible interview: at any other time these keys belong to the app
        // in front.
        if hasOption && !hasShift && !hasControl && self.isInterviewActive && self.window.isVisible {
            switch keyCode {
            case 126, 125:
                StealthLogger.shared.log("⌨️ HOTKEY: ⌘⌥ arrow (question) - CONSUMED")
                DispatchQueue.main.async { [weak self] in self?.moveQuestionSelection(newer: keyCode == 126) }
                return nil
            case 123 where self.canStepFocusCode, 124 where self.canStepFocusCode:
                // Only while code in several steps is up; otherwise the editor keeps its tab switching.
                StealthLogger.shared.log("⌨️ HOTKEY: ⌘⌥ arrow (code step) - CONSUMED")
                DispatchQueue.main.async { [weak self] in self?.focusCodePanel?.moveStep(forward: keyCode == 124) }
                return nil
            case 8:
                StealthLogger.shared.log("⌨️ HOTKEY: ⌘⌥C (copy code) - CONSUMED")
                DispatchQueue.main.async { [weak self] in self?.copyFocusCode() }
                return nil
            case 0 where self.focusCodeOpen:
                StealthLogger.shared.log("⌨️ HOTKEY: ⌘⌥A (answer over code) - CONSUMED")
                DispatchQueue.main.async { [weak self] in self?.toggleFocusAnswerOverCode() }
                return nil
            default:
                break
            }
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

        // ⌘+Enter / ⌘+Return = Analyze screenshots (GLOBAL)
        if (keyCode == 36 || keyCode == 76) && !hasShift { // Return or keypad Enter
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

        // ⌘+3 = Show or hide the code panel (when visible)
        if keyCode == 20 && !hasShift && self.window.isVisible {
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+3 (code panel) - CONSUMED")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.currentTab != .voice { self.switchToVoiceTab() }
                self.toggleFocusCodePanel()
            }
            return nil
        }

        // ⌘+4 = Practice tab (when visible)
        if keyCode == 21 && !hasShift && self.window.isVisible {
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+4 (practice) - CONSUMED")
            DispatchQueue.main.async { [weak self] in self?.switchToPracticeTab() }
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

    /// Code in several steps is on screen, so ⌘⌥← and ⌘⌥→ step through it instead of reaching the editor.
    var canStepFocusCode: Bool {
        focusCodeOpen && !focusAnswerOverCode && (focusCodePanel?.canStep ?? false)
    }

    /// Without the event tap, the keys that are pressed while another app is in front are registered with
    /// the system instead. Called whenever what they would do changes; it does nothing once the tap works.
    func refreshSystemHotkeys() {
        guard eventTap == nil, window != nil else {
            if !SystemHotkeys.shared.registeredIDs.isEmpty { SystemHotkeys.shared.removeAll() }
            return
        }
        let before = SystemHotkeys.shared.registeredIDs
        let visible = window.isVisible
        let live = visible && isInterviewActive
        let stepping = live && canStepFocusCode
        let commandOption = cmdKey | optionKey
        let commandControl = cmdKey | controlKey
        let hotkeys = SystemHotkeys.shared
        hotkeys.set(1, keyCode: 124, modifiers: commandOption, enabled: stepping) { [weak self] in self?.focusCodePanel?.moveStep(forward: true) }
        hotkeys.set(2, keyCode: 123, modifiers: commandOption, enabled: stepping) { [weak self] in self?.focusCodePanel?.moveStep(forward: false) }
        hotkeys.set(3, keyCode: 126, modifiers: commandOption, enabled: live) { [weak self] in self?.moveQuestionSelection(newer: true) }
        hotkeys.set(4, keyCode: 125, modifiers: commandOption, enabled: live) { [weak self] in self?.moveQuestionSelection(newer: false) }
        hotkeys.set(5, keyCode: 0, modifiers: commandOption, enabled: live && focusCodeOpen) { [weak self] in self?.toggleFocusAnswerOverCode() }
        hotkeys.set(6, keyCode: 8, modifiers: commandOption, enabled: live && focusCodeOpen) { [weak self] in self?.copyFocusCode() }
        for (id, keyCode) in [(7, 123), (8, 124), (9, 125), (10, 126)] {
            hotkeys.set(UInt32(id), keyCode: keyCode, modifiers: commandControl, enabled: visible) { [weak self] in self?.nudgeWindow(keyCode: keyCode) }
        }
        let after = hotkeys.registeredIDs
        if after != before { StealthLogger.shared.log("⌨️ SYSTEM HOTKEYS registered: \(after)") }
    }

    /// Fallback to NSEvent monitor if CGEvent tap fails (no accessibility permission)
    func setupFallbackHotkeys() {
        StealthLogger.shared.log("⚠️ Using FALLBACK hotkeys (NSEvent monitor - cannot intercept)")
        refreshSystemHotkeys()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return }

            if self.handleFallbackPushToTalk(event) { return }
            guard event.type == .keyDown else { return }

            guard event.modifierFlags.contains(.command) else { return }

            if self.hasBlockingModalUI(), self.isApplicationHotkey(Int64(event.keyCode)) {
                return
            }

            switch event.keyCode {
            case 34: // I - ghost mode only (no interview start/stop)
                StealthLogger.shared.log("⌨️ FALLBACK: ⌘+I (ghost mode)")
                self.toggleInterviewMode()
            case 11: // B
                StealthLogger.shared.log("⌨️ FALLBACK: ⌘+B (toggle window)")
                self.toggleWindowVisibility()
            case 1: // S
                StealthLogger.shared.log("⌨️ FALLBACK: ⌘+S (screenshot)")
                if self.practiceShouldConsumeReservedShortcuts() { return }
                if self.currentTab != .voice { self.switchToVoiceTab() }
                self.captureScreenshotPlaceholder()
            case 5: // G
                if self.practiceShouldConsumeReservedShortcuts() { return }
            case 20: // 3 - code panel
                StealthLogger.shared.log("⌨️ FALLBACK: ⌘+3 (code panel)")
                if self.window.isVisible {
                    if self.currentTab != .voice { self.switchToVoiceTab() }
                    self.toggleFocusCodePanel()
                }
            case 36, 76: // Return or keypad Enter
                StealthLogger.shared.log("⌨️ FALLBACK: ⌘+Enter (analyze)")
                if self.practiceShouldConsumeReservedShortcuts() {
                    if event.isARepeat { return }
                    if self.practiceOwnsKeyboard() {
                        self.practiceTabController.performPrimaryAction()
                    }
                    return
                }
                if self.window.isVisible && self.currentTab != .voice { self.switchToVoiceTab() }
                self.analyzeScreenshots()
            default:
                break
            }
        }
    }
}
