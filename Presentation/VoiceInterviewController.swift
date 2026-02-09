import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {

    // MARK: - VoiceInterviewProcessorDelegate

    var userBackground: String {
        return textView.string
    }

    var pinnedSolution: String? {
        return currentPinnedSolution
    }

    func processorShowLoading(_ message: String, color: NSColor) {
        showLoading(message, color: color)
    }

    func processorHideLoading() {
        hideLoading()
    }

    func processorDidReceiveQuestion(_ text: String, topic: String, messageType: InterviewMessage.MessageType, source: AudioSource) {
        debugLog(.delegate, "processorDidReceiveQuestion: '\(text.prefix(50))...' topic=\(topic)")
        addVoiceMessage(type: .question, content: text, topic: topic, audioSource: source)
    }

    func processorDidStartStreaming(messageType: InterviewMessage.MessageType, topic: String, latencyMs: Int?) {
        debugLog(.delegate, "processorDidStartStreaming: type=\(messageType) topic=\(topic) latency=\(latencyMs ?? -1)ms")
        streamingMessageHandler.addStreamingMessage(type: messageType, topic: topic, latencyMs: latencyMs)
    }

    func processorDidReceiveAnswerChunk(_ fullContent: String) {
        // Only log occasionally to avoid spam
        if fullContent.count < 50 || fullContent.count % 200 == 0 {
            debugLog(.stream, "processorDidReceiveAnswerChunk: \(fullContent.count) chars")
        }
        streamingMessageHandler.updateStreamingMessage(fullContent)
    }

    func processorDidFinishAnswer(_ fullAnswer: String) {
        debugLog(.delegate, "processorDidFinishAnswer: \(fullAnswer.count) chars")
        streamingMessageHandler.finalizeStreamingMessage(fullAnswer)
    }

    func processorDidUpdateStatus(_ message: String) {
        voiceStatusLabel.stringValue = message
    }

    // MARK: - Voice Interview Methods

    @objc func toggleInterview() {
        if isInterviewActive {
            stopInterview()
        } else {
            startInterview()
        }
    }

    func startInterview() {
        // Check for Groq API key
        if groqApiKey == nil {
            promptForGroqApiKey()
            return
        }

        // Check for Anthropic API key (needed for Haiku answers)
        if apiKey == nil {
            showAlert(title: "API Key Required", message: "Please configure your Anthropic API key in Settings (⌘,)")
            return
        }

        // Initialize recorder and clients
        vadRecorder = SileroVADRecorder()
        systemAudioCapture = SystemAudioCapture()
        groqClient = GroqInterviewClient(apiKey: groqApiKey!)
        anthropicClient = AnthropicClient(apiKey: apiKey!)

        // Configure voice interview processor with clients
        voiceInterviewProcessor.configure(groqClient: groqClient, anthropicClient: anthropicClient)

        // Mic callbacks disabled - only using system audio
        // vadRecorder?.onLevelUpdate = { ... }
        // vadRecorder?.onStatusChange = { ... }
        // vadRecorder?.onSpeechSegment = { ... }

        // Set up system audio capture (for interviewer's voice in Zoom/Teams)
        debugLog("Setting up system audio callbacks...")
        systemAudioCapture?.onStatusChange = { [weak self] status in
            guard let self = self else { return }
            debugLog(.audio, "System status: \(status)")
        }

        systemAudioCapture?.onLevelUpdate = { [weak self] db, isSpeaking in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.updateStatusIcon(listening: true, speaking: isSpeaking)
            }
        }

        systemAudioCapture?.onSpeechSegment = { [weak self] audioData in
            guard let self = self else { return }
            debugLog(.audio, "System audio segment received: \(audioData.count) bytes")
            self.voiceInterviewProcessor.processAudioSegment(audioData, source: .systemAudio)
        }

        // Start listening
        do {
            // Mic disabled - only using system audio (Zoom/Teams)
            // try vadRecorder?.startListening()

            // Start system audio capture in background
            Task {
                do {
                    debugLog(.audio, "Starting system audio capture...")
                    try await systemAudioCapture?.startCapturing()
                    debugLog(.audio, "System audio capture started successfully")
                } catch {
                    debugLog(.error, "System audio capture failed: \(error.localizedDescription)")
                    await MainActor.run {
                        showAlert(title: "Screen Recording Permission Required",
                                  message: "System audio capture requires Screen Recording permission.\n\nGo to System Settings → Privacy & Security → Screen Recording and enable this app.\n\nError: \(error.localizedDescription)")
                    }
                }
            }

            isInterviewActive = true

            // Clear screenshots array for new session
            screenshots.removeAll()
            // Rename old gallery so new screenshots create a fresh one (old gallery stays visible)
            if let oldGallery = voiceTimelineContainer.subviews.first(where: { $0.identifier?.rawValue == "screenshotGallery" }) {
                oldGallery.identifier = NSUserInterfaceItemIdentifier("screenshotGallery_archived")
            }

            // Update Nest button to recording state
            updateNestButtonState(recording: true)

            // Show recording indicator (Dynamic Island style)
            showRecordingIndicator()

            addVoiceMessage(type: .status, content: "Interview started - listening for questions...", topic: nil)

        } catch {
            showAlert(title: "Audio Error", message: "Could not start audio recording: \(error.localizedDescription)")
        }
    }

    func stopInterview() {
        vadRecorder?.stopListening()
        vadRecorder = nil

        // Stop system audio capture
        Task {
            await systemAudioCapture?.stopCapturing()
            await MainActor.run {
                systemAudioCapture = nil
            }
        }

        isInterviewActive = false

        // Clear conversation context but keep timeline visible
        conversationContext.clear()
        voiceInterviewProcessor.reset()

        // Hide loading indicator
        hideLoading()

        // Hide recording indicator
        hideRecordingIndicator()

        // Update Nest button to idle state
        updateNestButtonState(recording: false)

        voiceStatusLabel.stringValue = ""
        // Reset waveform bars to dim state
        for bar in systemWaveformBars {
            bar.layer?.backgroundColor = NSColor.appleGold.withAlphaComponent(0.5).cgColor
        }

        // Add status to timeline (preserved)
        addVoiceMessage(type: .status, content: "Interview stopped", topic: nil)

        // Auto-save session as JSON
        autoSaveSession()
    }

    // MARK: - Settings Dropdowns

    @objc func roleChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0 && index < InterviewRole.allCases.count else { return }
        AppSettings.shared.role = InterviewRole.allCases[index]
        NSLog("👤 Role changed to: \(AppSettings.shared.role.displayName)")
    }

    @objc func programmingLanguageChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0 && index < ProgrammingLanguage.allCases.count else { return }
        AppSettings.shared.programmingLanguage = ProgrammingLanguage.allCases[index]
        NSLog("💻 Programming language changed to: \(AppSettings.shared.programmingLanguage.displayName)")
    }

    @objc func speakingLanguageChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0 && index < SpeakingLanguage.allCases.count else { return }
        AppSettings.shared.speakingLanguage = SpeakingLanguage.allCases[index]
        NSLog("🌐 Speaking language changed to: \(AppSettings.shared.speakingLanguage.displayName)")
    }
}
