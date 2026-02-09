import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {

    @objc func captureScreenshotPlaceholder() {
        // Only allow screenshots during active interview
        guard isInterviewActive else {
            return
        }

        // Check permission first
        if !CGPreflightScreenCaptureAccess() {
            showPermissionAlert()
            return
        }

        Task {
            await captureScreenshot()
        }
    }

    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Interview Master needs Screen Recording permission to capture screenshots.\n\n1. Click 'Open Settings' below\n2. Enable 'InterviewMaster' in Screen Recording\n3. Restart the app"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Settings > Privacy & Security > Screen Recording
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }

    func captureScreenshot() async {
        let result = await screenCaptureService.captureScreen()

        switch result {
        case .success(let screenshot):
            // Generate thumbnail for timeline (larger)
            let timelineThumbnailSize = NSSize(width: 200, height: 112)
            let timelineThumbnail = screenshot.generateThumbnail(size: timelineThumbnailSize)

            // Add to screenshots array
            screenshots.append(screenshot)

            // Add thumbnail to voice timeline (main UI)
            await MainActor.run {
                addScreenshotToTimeline(thumbnail: timelineThumbnail, screenshotId: screenshot.id)
            }

        case .failure(let error):
            await MainActor.run {
                let message: String
                switch error {
                case .noDisplayFound:
                    message = "No display found"
                case .captureFailed(let underlyingError):
                    message = "Error: \(underlyingError.localizedDescription)"
                }
                showAlert(title: "Screenshot Failed", message: message)
            }
        }
    }


    func addThumbnailToUI(thumbnail: NSImage, id: UUID) {
        let thumbnailHeight: CGFloat = 35
        let thumbnailWidth: CGFloat = 62  // Proportional 16:9 to height
        let spacing: CGFloat = 10
        let xOffset = CGFloat(screenshotThumbnails.count) * (thumbnailWidth + spacing)

        let thumbnailButton = NSButton(frame: NSRect(x: xOffset, y: 0, width: thumbnailWidth, height: thumbnailHeight))
        thumbnailButton.image = thumbnail
        thumbnailButton.imageScaling = .scaleProportionallyUpOrDown
        thumbnailButton.isBordered = false
        thumbnailButton.bezelStyle = .rounded
        thumbnailButton.tag = screenshotThumbnails.count
        thumbnailButton.wantsLayer = true
        thumbnailButton.layer?.cornerRadius = 6
        thumbnailButton.layer?.borderWidth = 1.5
        thumbnailButton.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        thumbnailButton.layer?.masksToBounds = true

        screenshotThumbnailsContainer.addSubview(thumbnailButton)
        screenshotThumbnails.append(thumbnailButton)

        // Update container width
        screenshotThumbnailsContainer.frame.size.width = CGFloat(screenshotThumbnails.count) * (thumbnailWidth + spacing)
    }

    @objc func resetCodingTab() {
        // Clear all screenshots
        screenshots.removeAll()

        // Remove all thumbnail buttons from UI
        for thumbnail in screenshotThumbnails {
            thumbnail.removeFromSuperview()
        }
        screenshotThumbnails.removeAll()

        // Reset container width
        screenshotThumbnailsContainer.frame.size.width = 0

        // Clear analysis text
        analysisTextView.string = ""
    }

    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func analyzeScreenshots() {
        guard !screenshots.isEmpty else {
            showAlert(title: "No Screenshots", message: "Please capture at least one screenshot first (⌘S)")
            return
        }

        guard let apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty else {
            showAlert(title: "API Key Required", message: "Please configure your Anthropic API key in settings (⚙️ API Key)")
            return
        }

        // Check for data consent (required by App Store Guideline 5.1.2)
        if !UserDefaults.standard.bool(forKey: dataConsentKey) {
            let consentGiven = showDataConsentDialog()
            if !consentGiven {
                return
            }
            UserDefaults.standard.set(true, forKey: dataConsentKey)
        }

        Task {
            await performAnalysis(apiKey: apiKey)
        }
    }

    func showDataConsentDialog() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Data Sharing Consent"
        alert.informativeText = """
        To analyze your screenshots, Interview Master will send them to Anthropic's Claude AI service.

        What is shared:
        • Screenshot images you capture
        • Analysis prompts

        What is NOT shared:
        • Your notes
        • Personal information
        • API keys

        Anthropic processes data according to their privacy policy. Screenshots are not stored permanently.

        Do you consent to share screenshot data with Anthropic for AI analysis?
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "I Consent")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Privacy Policy")

        let response = alert.runModal()

        if response == .alertThirdButtonReturn {
            // Show Anthropic privacy policy
            if let url = URL(string: "https://www.anthropic.com/privacy") {
                NSWorkspace.shared.open(url)
            }
            // Show dialog again after viewing privacy policy
            return showDataConsentDialog()
        }

        return response == .alertFirstButtonReturn
    }

    func performAnalysis(apiKey: String) async {
        // Convert screenshots to base64
        var base64Images: [String] = []
        for screenshot in screenshots {
            if let base64 = screenshot.toBase64() {
                base64Images.append(base64)
            }
        }

        // Show loading state in pinned header
        await MainActor.run {
            setPinnedSolution("🤔 Analyzing \(screenshots.count) screenshot\(screenshots.count == 1 ? "" : "s")...")

            // If main window is hidden, show floating window with loading state (stealth mode)
            if !window.isVisible {
                floatingSolutionController.show()
            }
        }

        // Always create fresh client with current API key
        let client = AnthropicClient(apiKey: apiKey)

        // Get prompt and prefill from analysis mode
        let prompt = analysisMode.prompt
        let prefill = analysisMode.prefill

        // Collect full response for pinning
        var fullResponse = ""

        // Stream the response directly to pinned solution
        let result = await client.sendMessageStream(
            images: base64Images,
            prompt: prompt,
            prefill: prefill
        ) { [weak self] chunk in
            fullResponse += chunk
            Task { @MainActor in
                guard let self = self else { return }
                // Update pinned solution with streaming content
                self.updatePinnedSolutionContent(fullResponse)
            }
        }

        if case .failure(let error) = result {
            await MainActor.run {
                showAlert(title: "Analysis Failed", message: error.localizedDescription)
                setPinnedSolution("❌ Analysis failed: \(error.localizedDescription)")
            }
        } else {
            // Final update
            await MainActor.run {
                // Update the coding task in timeline with final content
                updatePinnedSolutionContent(fullResponse)

                // Update floating window with final content (stealth mode)
                if !window.isVisible {
                    floatingSolutionController.updateContent(fullResponse)
                }

                // Clear screenshots for next task
                screenshots.removeAll()

                // Archive old gallery so new screenshots create a fresh entry
                if let oldGallery = self.voiceTimelineContainer.subviews.first(where: { $0.identifier?.rawValue == "screenshotGallery" }) {
                    oldGallery.identifier = NSUserInterfaceItemIdentifier("screenshotGallery_archived_\(UUID().uuidString)")
                }
            }
        }
    }

    /// Update pinned solution content in timeline during streaming
    func updatePinnedSolutionContent(_ content: String) {
        currentPinnedSolution = content

        // Find existing coding task view in timeline
        guard let codingTaskView = voiceTimelineContainer.subviews.first(where: { $0.identifier?.rawValue == "codingTask" }) else {
            // No existing view, create one via setPinnedSolution
            setPinnedSolution(content)
            return
        }

        // Find the text view inside the coding task container
        guard let contentView = codingTaskView.subviews.first(where: { $0 is NSTextView }) as? NSTextView else { return }

        // Update content
        let attributedContent = messageViewFactory.formatMessageContent(content, isQuestion: false)
        contentView.textStorage?.setAttributedString(attributedContent)

        // Get actual height from layout manager
        let cardWidth = voiceTimelineContainer.frame.width - 40
        let textWidth = cardWidth - 24
        contentView.textContainer?.containerSize = NSSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude)
        contentView.layoutManager?.ensureLayout(for: contentView.textContainer!)
        let actualHeight = contentView.layoutManager?.usedRect(for: contentView.textContainer!).height ?? 30
        let newViewHeight = max(actualHeight, 30)

        // Only resize if height changed significantly
        let heightDiff = newViewHeight - codingTaskView.frame.height
        if abs(heightDiff) > 10 {
            // Update coding task view height
            codingTaskView.frame.size.height = newViewHeight

            // Update content view frame - no padding
            contentView.frame = NSRect(x: 12, y: 0, width: textWidth, height: actualHeight)

            // Update accent bar height
            if let accentBar = codingTaskView.subviews.first(where: { $0.frame.width == 3 }) {
                accentBar.frame.size.height = newViewHeight
            }

            // Shift other messages up/down
            for subview in voiceTimelineContainer.subviews {
                if subview !== codingTaskView && subview.frame.origin.y > codingTaskView.frame.origin.y {
                    subview.frame.origin.y += heightDiff
                }
            }

            // Recalculate container height
            var maxY: CGFloat = 0
            for subview in voiceTimelineContainer.subviews {
                maxY = max(maxY, subview.frame.maxY)
            }
            voiceTimelineContainer.frame.size.height = max(voiceTimelineScrollView.frame.height, maxY + 20)
        }

        // Scroll to top to show newest (Y=0 in flipped view)
        voiceTimelineScrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))

        // Sync to floating window if visible
        if floatingSolutionController.window != nil {
            floatingSolutionController.updateContent(content)
        }
    }

    /// Clear timeline messages when a new coding task is pinned
    func clearTimelineForNewTask() {
        // Remove all subviews from timeline
        for subview in voiceTimelineContainer.subviews {
            subview.removeFromSuperview()
        }
        voiceMessages.removeAll()

        // Add status message indicating new task
        addVoiceMessage(type: .status, content: "New coding task loaded\n\nAsk follow-up questions about the solution above.", topic: nil)
    }

    @objc func clearAllScreenshots() {
        screenshots.removeAll()
        screenshotThumbnails.forEach { $0.removeFromSuperview() }
        screenshotThumbnails.removeAll()
        screenshotThumbnailsContainer.frame.size.width = 100
        analysisTextView.string = "💻 AI Analysis will appear here\n\nCapture screenshots (⌘S) and press Analyze (⌘Enter)"
    }

    /// Clear screenshots from voice timeline
    func clearScreenshotsFromTimeline() {
        // Clear screenshots array
        screenshots.removeAll()

        // Remove screenshot containers from timeline
        for subview in voiceTimelineContainer.subviews {
            if let identifier = subview.identifier?.rawValue, identifier.hasPrefix("screenshot_") {
                subview.removeFromSuperview()
            }
        }

        // Remove screenshot messages from array
        voiceMessages.removeAll { $0.type == .screenshot }

        // Hide pinned solution if showing
        clearPinnedSolution()

        // Recalculate timeline height
        var maxY: CGFloat = 0
        for subview in voiceTimelineContainer.subviews {
            maxY = max(maxY, subview.frame.maxY)
        }
        voiceTimelineContainer.frame.size.height = max(voiceTimelineScrollView.frame.height, maxY + 20)
    }
}
