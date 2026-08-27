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

    func processorShowLoading(_ message: String, color: NSColor, turnID: UUID) {
        showLoading(message, color: color, turnID: turnID)
    }

    func processorHideLoading(turnID: UUID) {
        hideLoading(turnID: turnID)
    }

    func processorDidReceiveQuestion(_ text: String, topic: String, messageType: InterviewMessage.MessageType, source: AudioSource, turnID: UUID, sequence: Int) {
        debugLog(.delegate, "processorDidReceiveQuestion: '\(text.prefix(50))...' topic=\(topic)")
        receiveFocusQuestion(turnID: turnID, sequence: sequence, text: text, topic: topic)
        addVoiceMessage(type: .question, content: text, topic: topic, audioSource: source, turnID: turnID, turnSequence: sequence)
    }

    func processorDidStartStreaming(messageType: InterviewMessage.MessageType, topic: String, latencyMs: Int?, turnID: UUID, sequence: Int) {
        debugLog(.delegate, "processorDidStartStreaming: type=\(messageType) topic=\(topic) cardStart=\(latencyMs ?? -1)ms")
        resetStreamingUIThrottle(turnID: turnID)
        startFocusAnswer(turnID: turnID)
        streamingMessageHandler.addStreamingMessage(type: messageType, topic: topic, latencyMs: latencyMs, turnID: turnID, turnSequence: sequence)
    }

    func processorDidReceiveAnswerChunk(_ fullContent: String, turnID: UUID) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.processorDidReceiveAnswerChunk(fullContent, turnID: turnID)
            }
            return
        }

        if fullContent.lowercased().hasPrefix("error:") {
            resetStreamingUIThrottle(turnID: turnID)
            failFocusTurn(turnID: turnID)
            streamingMessageHandler.finalizeStreamingMessage(fullContent, totalLatencyMs: nil, turnID: turnID)
            return
        }

        // Only log occasionally to avoid spam
        if fullContent.count < 50 || fullContent.count % 200 == 0 {
            debugLog(.stream, "processorDidReceiveAnswerChunk: \(fullContent.count) chars")
        }

        pendingStreamingContent[turnID] = fullContent

        if shouldFlushStreamingContent(fullContent, turnID: turnID) {
            flushPendingStreamingContent(turnID: turnID)
            return
        }

        guard streamingFlushWorkItems[turnID] == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushPendingStreamingContent(turnID: turnID)
        }
        streamingFlushWorkItems[turnID] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + streamingUIUpdateInterval, execute: workItem)
    }

    func processorDidFinishAnswer(_ fullAnswer: String, totalLatencyMs: Int?, turnID: UUID) {
        debugLog(.delegate, "processorDidFinishAnswer: \(fullAnswer.count) chars, total=\(totalLatencyMs ?? -1)ms")
        resetStreamingUIThrottle(turnID: turnID)
        finishFocusAnswer(turnID: turnID, content: fullAnswer, latencyMs: totalLatencyMs)
        streamingMessageHandler.finalizeStreamingMessage(fullAnswer, totalLatencyMs: totalLatencyMs, turnID: turnID)
    }

    func processorDidUpdateStatus(_ message: String) {
        voiceStatusLabel.stringValue = message
        if message.lowercased().hasPrefix("error:") {
            addVoiceMessage(type: .status, content: message, topic: "error")
        }
    }

    private func shouldFlushStreamingContent(_ content: String, turnID: UUID) -> Bool {
        if content.count < 80 { return true }
        if content.hasSuffix("\n") { return true }
        let lastUpdate = lastStreamingUIUpdates[turnID] ?? .distantPast
        return Date().timeIntervalSince(lastUpdate) >= streamingUIUpdateInterval
    }

    private func flushPendingStreamingContent(turnID: UUID) {
        streamingFlushWorkItems[turnID]?.cancel()
        streamingFlushWorkItems[turnID] = nil

        guard let content = pendingStreamingContent[turnID] else { return }
        pendingStreamingContent[turnID] = nil
        lastStreamingUIUpdates[turnID] = Date()
        updateFocusAnswer(turnID: turnID, content: content)
        streamingMessageHandler.updateStreamingMessage(content, turnID: turnID)
    }

    private func resetStreamingUIThrottle(turnID: UUID? = nil) {
        if let turnID {
            streamingFlushWorkItems[turnID]?.cancel()
            streamingFlushWorkItems[turnID] = nil
            pendingStreamingContent[turnID] = nil
            lastStreamingUIUpdates[turnID] = .distantPast
            return
        }

        streamingFlushWorkItems.values.forEach { $0.cancel() }
        streamingFlushWorkItems.removeAll()
        pendingStreamingContent.removeAll()
        lastStreamingUIUpdates.removeAll()
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

        // xAI Grok (preferred) or Anthropic for classify/answer
        if apiKey == nil {
            showAlert(
                title: "API Key Required",
                message: "Add XAI_API_KEY to ~/.interview-master-keys (console.x.ai), or an Anthropic key as fallback. Then restart the app."
            )
            return
        }

        // Initialize recorder and clients
        vadRecorder = SileroVADRecorder()
        systemAudioCapture = SystemAudioCapture()
        groqClient = GroqInterviewClient(apiKey: groqApiKey!)
        anthropicClient = AnthropicClient(apiKey: apiKey!, provider: interviewLLMProvider)
        debugLog("Interview LLM provider: \(interviewLLMProvider == .xai ? "xAI Grok" : "Anthropic")")

        // Configure voice interview processor with clients
        voiceInterviewProcessor.configure(groqClient: groqClient, anthropicClient: anthropicClient)

        // Mic callbacks disabled - only using system audio
        // vadRecorder?.onLevelUpdate = { ... }
        // vadRecorder?.onStatusChange = { ... }
        // vadRecorder?.onSpeechSegment = { ... }

        // Set up system audio capture (for interviewer's voice in Zoom/Teams)
        debugLog("Setting up system audio callbacks...")
        systemAudioCapture?.onStatusChange = { status in
            debugLog(.audio, "System status: \(status)")
        }

        systemAudioCapture?.onLevelUpdate = { [weak self] db, isSpeaking in
            guard let self = self, self.isInterviewActive else { return }
            DispatchQueue.main.async {
                self.updateStatusIcon(listening: true, speaking: isSpeaking)
            }
        }

        systemAudioCapture?.onSpeechPreview = { [weak self] audioData in
            guard let self = self, self.isInterviewActive else { return }
            debugLog(.audio, "System audio STT preview: \(audioData.count) bytes")
            self.voiceInterviewProcessor.prefetchTranscription(audioData, source: .systemAudio)
        }
        systemAudioCapture?.onSpeechCancelled = { [weak self] in
            guard let self, self.isInterviewActive else { return }
            self.voiceInterviewProcessor.cancelPrefetchTranscription()
        }
        systemAudioCapture?.onSpeechSegment = { [weak self] audioData in
            guard let self = self, self.isInterviewActive else { return }
            debugLog(.audio, "System audio segment received: \(audioData.count) bytes")
            self.voiceInterviewProcessor.processAudioSegment(audioData, source: .systemAudio)
        }

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
                              message: "System audio capture requires Screen Recording permission.\n\nGo to System Settings → Privacy & Security → Screen Recording and enable Interview Master. If macOS already lists an older InterviewMaster entry, remove it and enable the new Interview Master app, then restart with ./start.sh.\n\nError: \(error.localizedDescription)")
                }
            }
        }

        isInterviewActive = true
        resetInterviewFocusUI()

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
    }

    func stopInterview() {
        isInterviewActive = false
        vadRecorder?.stopListening()
        vadRecorder = nil

        // Stop system audio capture
        let captureToStop = systemAudioCapture
        systemAudioCapture = nil
        captureToStop?.onLevelUpdate = nil
        captureToStop?.onSpeechPreview = nil
        captureToStop?.onSpeechCancelled = nil
        captureToStop?.onSpeechSegment = nil
        captureToStop?.onStatusChange = nil
        Task {
            await captureToStop?.stopCapturing()
        }

        // Clear conversation context but keep timeline visible
        voiceInterviewProcessor.reset()
        conversationContext.clear()

        // Hide loading indicator
        hideLoading()
        resetStreamingUIThrottle()
        streamingMessageHandler.clearStreamingState()

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
        guard index >= 0 && index < InterviewRole.selectableCases.count else { return }
        AppSettings.shared.role = InterviewRole.selectableCases[index]
        NSLog("👤 Role changed to: \(AppSettings.shared.role.displayName)")
    }

    @objc func programmingLanguageChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0 && index < ProgrammingLanguage.allCases.count else { return }
        AppSettings.shared.programmingLanguage = ProgrammingLanguage.allCases[index]
        NSLog("💻 Programming language changed to: \(AppSettings.shared.programmingLanguage.displayName)")
    }

    @objc func listeningLanguageChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0 && index < SpeakingLanguage.allCases.count else { return }
        AppSettings.shared.listeningLanguage = SpeakingLanguage.allCases[index]
        NSLog("🎧 Listening language changed to: \(AppSettings.shared.listeningLanguage.displayName)")
    }

    @objc func responseLanguageChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0 && index < SpeakingLanguage.allCases.count else { return }
        AppSettings.shared.responseLanguage = SpeakingLanguage.allCases[index]
        NSLog("💬 Response language changed to: \(AppSettings.shared.responseLanguage.displayName)")
    }
}
