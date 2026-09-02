import Cocoa
import ApplicationServices

@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    @objc func toggleInterviewMode() {
        isInterviewModeActive.toggle()

        if isInterviewModeActive {
            StealthLogger.shared.log("👻 GHOST MODE: ON (transparent + click-through)")

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.window.animator().alphaValue = 0.75
            })

            if let effectView = window.contentView?.subviews.first as? NSVisualEffectView {
                effectView.alphaValue = 0.4
                effectView.material = .hudWindow
            }

            window.ignoresMouseEvents = true
            window.level = .floating

            if let effectView = window.contentView?.subviews.first as? NSVisualEffectView {
                effectView.layer?.borderWidth = 2
                effectView.layer?.borderColor = NSColor.systemCyan.withAlphaComponent(0.5).cgColor
            }

        } else {
            StealthLogger.shared.log("👻 GHOST MODE: OFF (normal)")

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.window.animator().alphaValue = 1.0
            })

            if let effectView = window.contentView?.subviews.first as? NSVisualEffectView {
                effectView.alphaValue = 0.8
                effectView.material = .menu
            }

            window.ignoresMouseEvents = false

            if let effectView = window.contentView?.subviews.first as? NSVisualEffectView {
                effectView.layer?.borderWidth = 0
            }
        }
    }

    @objc func toggleWindowVisibility() {
        let trusted = AXIsProcessTrusted()
        StealthLogger.shared.log("🪟 TOGGLE WINDOW: visible=\(window.isVisible), accessibilityTrusted=\(trusted)")

        if window.isVisible {
            if !trusted {
                StealthLogger.shared.log("🪟 TOGGLE WINDOW: hide ignored in fallback hotkey mode; use IM menu -> Hide Window")
                return
            }

            hideMainWindow(animated: true)
        } else {
            showMainWindow(animated: true)
        }
    }

    @objc func showMainWindowFromMenu() {
        showMainWindow(animated: false)
    }

    @objc func hideMainWindowFromMenu() {
        hideMainWindow(animated: false)
    }

    func showMainWindow(animated: Bool) {
        StealthLogger.shared.log("🪟 SHOW WINDOW: animated=\(animated), miniaturized=\(window.isMiniaturized)")
        NSApp.setActivationPolicy(.accessory)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.ignoresMouseEvents = false
        if isInterviewModeActive {
            isInterviewModeActive = false
        }

        hideScreenshotAlert()

        if animated {
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.window.animator().alphaValue = 1
            }
        } else {
            window.alphaValue = 1
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
        if currentTab == .practice {
            (window as? StealthWindow)?.beginPracticeInteraction()
            practiceTabController.activate()
        }
    }

    func hideMainWindow(animated: Bool) {
        StealthLogger.shared.log("🪟 HIDE WINDOW: animated=\(animated)")

        if currentTab == .practice {
            practiceTabController.deactivate()
            (window as? StealthWindow)?.endPracticeInteraction()
        }

        let finish = {
            self.window.orderOut(nil)
            self.window.alphaValue = 1
            NSApp.setActivationPolicy(.accessory)

            if self.isInterviewModeActive {
                self.isInterviewModeActive = false
                self.window.ignoresMouseEvents = false
            }
        }

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                self.window.animator().alphaValue = 0
            }, completionHandler: finish)
        } else {
            finish()
        }
    }

    @objc func hideFloatingSolution() {
        floatingSolutionController.dismiss()
    }

    func updateFloatingQA() {
        floatingSolutionController.updateQA()
    }
}
