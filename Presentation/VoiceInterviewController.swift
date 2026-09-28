import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {

    // MARK: - VoiceInterviewProcessorDelegate

    var userBackground: String {
        return ResumeStore.shared.extractedText
    }

    func processorDidUpdateBriefing(_ briefing: InterviewBriefing) {
        if briefing.talkingPoints.isEmpty {
            focusBriefingView?.update(nil)
        } else {
            upsertBriefingOnTimeline(briefing)
            focusBriefingView?.update(briefing)
        }
        refreshFocusBodyLayout()
    }

    func processorDidUpdateCodingTask(_ content: String) {
        if currentPinnedSolution == nil {
            setPinnedSolution(content)
        } else {
            updatePinnedSolutionContent(content)
        }
        if shouldPresentScreenshotAnalysisOverlay(mainWindowVisible: window.isVisible) {
            if floatingSolutionController.window == nil {
                floatingSolutionController.show()
            }
            floatingSolutionController.updateContent(content)
        }
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

    func processorDidReceiveQuestion(_ text: String, topic: String, messageType: InterviewMessage.MessageType, source: CaptureDevice, turnID: UUID, sequence: Int) {
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

        groqClient = GroqInterviewClient(apiKey: groqApiKey!)
        anthropicClient = AnthropicClient(apiKey: apiKey!, provider: interviewLLMProvider)
        anthropicClient?.jevDecisionClient = JevDecisionClient.configured()
        voiceInterviewProcessor.configure(groqClient: groqClient, anthropicClient: anthropicClient)

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
        beginAudioSession()
    }

    func stopInterview() {
        isInterviewActive = false
        endAudioSession()

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
