import Cocoa
import AVFoundation

@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    var isSelfSpeechMuted: Bool { pushToTalkState.isMuted }

    var audioCapturePresentation: CapturePresentation {
        qaAudioPresentation ?? capturePresentation(active: audioCaptureCoordinator.activeDevice,
                                                    sessionActive: isInterviewActive,
                                                    switching: audioCaptureCoordinator.isSwitching,
                                                    muted: isSelfSpeechMuted, speaking: focusIsSpeaking)
    }

    func makeAudioCaptureCoordinator() -> AudioCaptureCoordinator {
        let initial = resolveStartupCaptureDevice(preferred: AppSettings.shared.captureDevice,
                                                 microphoneAllowed: AudioCaptureFactory.hasPermission(.microphone))
        let coordinator = AudioCaptureCoordinator(reservations: microphoneReservations,
                                                   initialDevice: initial,
                                                   make: { AudioCaptureFactory.make($0) },
                                                   preflight: { try await AudioCaptureFactory.preflight($0, allowPrompt: $1) })
        coordinator.onResetBuffers = { [weak self] in self?.voiceInterviewProcessor?.resetCaptureBuffers() }
        coordinator.onStateChange = { [weak self] in
            guard let self else { return }
            if self.audioCaptureCoordinator.activeDevice == nil || self.isSelfSpeechMuted { self.focusIsSpeaking = false }
            self.syncAudioSourceUI()
            self.refreshInterviewFocusUI()
        }
        coordinator.onLevel = { [weak self] _, speaking in
            self?.updateStatusIcon(listening: true, speaking: speaking)
        }
        coordinator.onPreview = { [weak self] data, device in
            self?.voiceInterviewProcessor?.prefetchTranscription(data, source: device)
        }
        coordinator.onCancelled = { [weak self] in self?.voiceInterviewProcessor?.cancelPrefetchTranscription() }
        coordinator.onSegment = { [weak self] data, device in
            self?.voiceInterviewProcessor?.processAudioSegment(data, source: device)
        }
        coordinator.onStatus = { status in debugLog(.audio, status) }
        coordinator.onCommitted = { [weak self] device, explicit in
            guard let self else { return }
            if explicit { AppSettings.shared.captureDevice = device }
            if self.isInterviewActive {
                debugLog(.audio, "AUDIO_SOURCE: \(device.rawValue)")
                self.addVoiceMessage(type: .status, content: "Audio source: \(device.displayName)", topic: nil)
            }
        }
        coordinator.onProblem = { [weak self] device, error in
            guard self != nil else { return }
            let alert = NSAlert()
            alert.messageText = "\(device.displayName) unavailable"
            alert.informativeText = error.localizedDescription
            let micDenied = device == .microphone && [.denied, .restricted].contains(AVCaptureDevice.authorizationStatus(for: .audio))
            alert.addButton(withTitle: micDenied ? "Open Settings" : "OK")
            if micDenied { alert.addButton(withTitle: "Cancel") }
            if alert.runModal() == .alertFirstButtonReturn, micDenied,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
        return coordinator
    }

    func beginAudioSession() {
        let override = ProcessInfo.processInfo.environment["IM_CAPTURE_DEVICE"].flatMap(CaptureDevice.init(rawValue:))
        let device = override ?? resolveStartupCaptureDevice(preferred: AppSettings.shared.captureDevice,
                                                            microphoneAllowed: AudioCaptureFactory.hasPermission(.microphone))
        audioCaptureCoordinator.startSession(device: device)
    }

    func endAudioSession() {
        audioCaptureCoordinator.stopSession()
        pushToTalkState = PushToTalkState()
        pushToTalkWatchdog?.cancel()
        pushToTalkWatchdog = nil
        focusIsSpeaking = false
        syncAudioSourceUI()
    }

    @objc func audioSourceChanged(_ sender: NSSegmentedControl) {
        selectAudioSource(sender.selectedSegment == 1 ? .microphone : .systemAudio)
    }

    @objc func toggleMicrophoneSource() {
        selectAudioSource(audioCaptureCoordinator.selectedDevice == .microphone ? .systemAudio : .microphone)
    }

    private func selectAudioSource(_ device: CaptureDevice) {
        guard !audioCaptureCoordinator.isSwitching else { syncAudioSourceUI(); return }
        if device == .microphone, !UserDefaults.standard.bool(forKey: "InterviewMaster.MicrophoneDisclosureShown") {
            let alert = NSAlert()
            alert.messageText = "Use the microphone for the interviewer"
            alert.informativeText = "macOS shows its microphone indicator while this is on. Press ⌘⇧M to mute while you speak. Microphone sensitivity is a first estimate until it is calibrated for an interviewer across the table."
            alert.addButton(withTitle: "Use Microphone")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { syncAudioSourceUI(); return }
            UserDefaults.standard.set(true, forKey: "InterviewMaster.MicrophoneDisclosureShown")
        }
        audioCaptureCoordinator.select(device)
        syncAudioSourceUI()
    }

    @objc func toggleAudioMute() {
        guard isInterviewActive else { return }
        pushToTalkState.toggleLatch()
        pushToTalkWatchdog?.cancel()
        pushToTalkWatchdog = nil
        audioCaptureCoordinator.setMuted(pushToTalkState.isMuted)
    }

    /// Called before modifier/modal guards so releasing Command before M cannot leave capture muted.
    func handlePushToTalkKey(keyCode: Int, isDown: Bool, command: Bool, shift: Bool,
                            control: Bool, option: Bool, isRepeat: Bool) -> Bool {
        guard keyCode == 46 else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        if !isDown {
            guard pushToTalkState.keyUp(at: now) else { return false }
            pushToTalkWatchdog?.cancel()
            pushToTalkWatchdog = nil
            audioCaptureCoordinator.setMuted(pushToTalkState.isMuted)
            return true
        }
        guard isInterviewActive, command, shift, !control, !option else { return false }
        guard NSApp.modalWindow == nil, window?.attachedSheet == nil else { return false }
        if let id = pushToTalkState.keyDown(at: now, isRepeat: isRepeat) {
            pushToTalkWatchdog?.cancel()
            let watchdog = DispatchWorkItem { [weak self] in
                guard let self, self.pushToTalkState.expire(id) else { return }
                self.audioCaptureCoordinator.setMuted(self.pushToTalkState.isMuted)
                self.addVoiceMessage(type: .status, content: "Mute released after a missed key release.", topic: nil)
            }
            pushToTalkWatchdog = watchdog
            DispatchQueue.main.asyncAfter(deadline: .now() + 120, execute: watchdog)
            audioCaptureCoordinator.setMuted(pushToTalkState.isMuted)
        }
        return true
    }

    func syncAudioSourceUI() {
        let state = audioCapturePresentation
        audioSourceControl?.selectedSegment = audioCaptureCoordinator.selectedDevice == .microphone ? 1 : 0
        audioSourceControl?.isEnabled = !audioCaptureCoordinator.isSwitching
        audioSourceControl?.setToolTip("Microphone (sensitivity calibration pending)", forSegment: 1)
        audioMuteButton?.image = NSImage(systemSymbolName: state.symbol, accessibilityDescription: state.label)
        audioMuteButton?.toolTip = state.label
        audioMuteButton?.setAccessibilityLabel(state.label)
        audioMuteButton?.setAccessibilityValue(isSelfSpeechMuted ? "Muted" : "Unmuted")
        audioMuteButton?.isEnabled = isInterviewActive
        // A control that cannot be used yet is noise: mute appears with the interview.
        audioMuteButton?.isHidden = !isInterviewActive
        audioMuteButton?.contentTintColor = isSelfSpeechMuted
            ? Token.Hue.warning.text
            : (audioCaptureCoordinator.activeDevice == nil ? Token.Color.textMuted : Token.Hue.success.text)
        audioSourceMenuItem?.state = audioCaptureCoordinator.selectedDevice == .microphone ? .on : .off
        audioSourceMenuItem?.isEnabled = !audioCaptureCoordinator.isSwitching
    }
}
