import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    func showRecordingIndicator() {
        recordingStartTime = Date()
        refreshInterviewFocusUI()
        recordingPill.isHidden = false
        let shouldAnimate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        recordingPill.frame = NSRect(x: recordingPill.frame.origin.x, y: recordingPill.frame.origin.y, width: 28, height: 28)
        recordingPill.layer?.cornerRadius = 14

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = shouldAnimate ? 0.12 : 0
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            recordingPill.animator().alphaValue = 1.0
        })

        if shouldAnimate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.expandRecordingPill()
            }
        } else {
            expandRecordingPill()
        }

        if shouldAnimate {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1.0
            pulse.toValue = 0.4
            pulse.duration = LayoutConstants.Animation.pulse
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            recordingDot.layer?.add(pulse, forKey: "pulse")
        }

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRecordingTime()
        }
    }

    private func expandRecordingPill() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true

            recordingPill.frame = NSRect(
                x: recordingPill.frame.origin.x,
                y: recordingPill.frame.origin.y,
                width: 80,
                height: 28
            )
            recordingPill.layer?.cornerRadius = 14
            recordingTimeLabel.animator().alphaValue = 1.0
        })
    }

    private func updateRecordingTime() {
        guard let startTime = recordingStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        recordingTimeLabel.stringValue = String(format: "%02d:%02d", minutes, seconds)
        updateFocusElapsedTime()
    }

    func hideRecordingIndicator() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
        recordingDot.layer?.removeAnimation(forKey: "pulse")

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.allowsImplicitAnimation = true
            recordingTimeLabel.animator().alphaValue = 0
            recordingPill.frame = NSRect(
                x: recordingPill.frame.origin.x,
                y: recordingPill.frame.origin.y,
                width: 28,
                height: 28
            )
        }) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.1
                self?.recordingPill.animator().alphaValue = 0
            }) {
                self?.recordingPill.isHidden = true
                self?.refreshInterviewFocusUI()
            }
        }
    }
}
