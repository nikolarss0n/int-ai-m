import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    func startScreenShareMonitoring() {
        guard autoHideEnabled else { return }

        // Monitor for screen recording (simplified version)
        // In production, you'd use more sophisticated detection
        screenShareTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.autoHideEnabled else { return }

            // Check if screen is being captured
            // This is a simplified check - real implementation would monitor actual screen sharing
            if CGPreflightScreenCaptureAccess() {
                // Hide window when screen sharing detected
                if self.window.isVisible {
                    self.window.orderOut(nil)
                }
            }
        }
    }

    /// Monitor which app has focus - proves browser keeps focus during interactions
    func startFocusMonitoring() {
        var lastFrontApp = ""

        // Check frontmost app every 500ms
        focusMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                let appName = frontApp.localizedName ?? "Unknown"
                let bundleId = frontApp.bundleIdentifier ?? "?"

                // Only log when frontmost app changes
                if appName != lastFrontApp {
                    lastFrontApp = appName
                    // Note: "frontmost" = visual layer, NOT keyboard focus
                    // Our app can be frontmost without stealing keyboard focus
                    // Browser blur/visibilitychange events depend on KEYBOARD focus, not frontmost
                    StealthLogger.shared.log("🎯 FRONTMOST APP: \(appName) [\(bundleId)] (visual only, not keyboard)")
                }
            }
        }

        // This is the critical one - monitors KEYBOARD focus
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow {
                let isOurs = window is StealthWindow
                if isOurs {
                    StealthLogger.shared.log("🔴 KEYBOARD FOCUS STOLEN: \(window.title) - THIS IS BAD!")
                } else {
                    StealthLogger.shared.log("🔑 KEYBOARD FOCUS: \(window.title) (not our window - OK)")
                }
            }
        }

        StealthLogger.shared.log("👁️ Focus monitoring started")
        StealthLogger.shared.log("   📺 'FRONTMOST APP' = visual layer (OK to be us)")
        StealthLogger.shared.log("   ⌨️ 'KEYBOARD FOCUS' = what triggers browser blur (should NEVER be us)")
    }

    // MARK: - Screenshot Alert System
    func startScreenshotMonitoring() {
        // Monitor for new screenshots
        screenshotMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Check if we have new screenshots and app is not focused
            if self.screenshots.count > self.lastScreenshotCount && !self.window.isKeyWindow {
                self.showScreenshotAlert()
            }

            self.lastScreenshotCount = self.screenshots.count
        }
    }

    func showScreenshotAlert() {
        // Don't show if alert already visible
        if let existingAlert = alertWindow, existingAlert.isVisible {
            if let container = alertThumbnailsContainer {
                alertWindowManager.createThumbnails(for: screenshots, in: container)
            }
            return
        }

        // Create alert window with container
        guard let (window, container) = alertWindowManager.createWindow() else { return }

        alertWindow = window
        alertThumbnailsContainer = container

        // Populate thumbnails
        alertWindowManager.createThumbnails(for: screenshots, in: container)

        // Show with animation
        alertWindowManager.show(window)

        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            self.alertWindowManager.hide(window)
        }
    }

    func updateAlertThumbnails() {
        guard let container = alertThumbnailsContainer else { return }
        alertWindowManager.createThumbnails(for: screenshots, in: container)
    }

    func hideScreenshotAlert() {
        guard let window = alertWindow else { return }
        alertWindowManager.hide(window)
    }
}
