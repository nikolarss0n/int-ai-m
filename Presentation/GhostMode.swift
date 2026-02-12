import Cocoa

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
        if window.isVisible {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                self.window.animator().alphaValue = 0
            }, completionHandler: {
                self.window.orderOut(nil)
                self.window.alphaValue = 1

                NSApp.setActivationPolicy(.accessory)

                if self.isInterviewModeActive {
                    self.isInterviewModeActive = false
                    self.window.ignoresMouseEvents = false
                }
            })
        } else {
            window.alphaValue = 0
            window.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            hideScreenshotAlert()

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                self.window.animator().alphaValue = 1
            })
        }
    }

    @objc func hideFloatingSolution() {
        floatingSolutionController.dismiss()
    }

    func updateFloatingQA() {
        floatingSolutionController.updateQA()
    }
}
