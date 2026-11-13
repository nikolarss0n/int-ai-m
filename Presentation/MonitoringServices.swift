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
        // The front app changes a few times an hour, so it is observed, not polled twice a second.
        // Note: "frontmost" = visual layer, NOT keyboard focus. Our app can be frontmost without
        // stealing keyboard focus; browser blur/visibilitychange events depend on KEYBOARD focus.
        func logFrontApp(_ app: NSRunningApplication?) {
            guard let app else { return }
            StealthLogger.shared.log("🎯 FRONTMOST APP: \(app.localizedName ?? "Unknown") [\(app.bundleIdentifier ?? "?")] (visual only, not keyboard)")
        }
        logFrontApp(NSWorkspace.shared.frontmostApplication)
        _ = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { notification in
            logFrontApp(notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
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
        screenshotAlertsEnabled = true
    }

    /// A screenshot taken while another app has the keyboard shows its thumbnail for a moment. Called
    /// when the list changes, so nothing has to poll it.
    func screenshotsDidChange(previousCount: Int) {
        guard screenshotAlertsEnabled, screenshots.count > previousCount else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.window.isKeyWindow else { return }
            self.showScreenshotAlert()
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
