import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {

    // MARK: - Loading Indicator

    func showLoading(_ text: String = "", color: NSColor = .systemCyan, turnID: UUID) {
        DispatchQueue.main.async {
            self.startTypingDotsAnimation()
            let normalized = text.lowercased()
            if normalized.contains("analyz") || normalized.contains("generating") {
                self.beginFocusAIWork(turnID: turnID)
            }

            // Also show on floating window if visible
            if self.floatingSolutionController.window != nil {
                self.floatingSolutionController.showLoading()
            }
        }
    }

    func hideLoading(turnID: UUID) {
        DispatchQueue.main.async {
            self.stopTypingDotsAnimation()
            self.endFocusAIWork(turnID: turnID)

            // Also hide on floating window
            if self.questionBurstState.isAIWorking {
                self.floatingSolutionController.showLoading()
            } else {
                self.floatingSolutionController.hideLoading()
            }
        }
    }

    func hideLoading() {
        DispatchQueue.main.async {
            self.stopTypingDotsAnimation()
            self.endAllFocusAIWork()
            self.floatingSolutionController.hideLoading()
        }
    }

    /// Animate waveform bars based on speaking state and dB level
    func animateWaveform(bars: [NSView], color: NSColor, isSpeaking: Bool, db: Float) {
        let barMaxHeight: CGFloat = 14
        let barMinHeight: CGFloat = 3
        // Wave pattern for 5 bars: outer bars smaller, center bar tallest
        let waveMultipliers: [CGFloat] = [0.5, 0.8, 1.0, 0.8, 0.5]

        // When speaking, animate bars to varying heights based on volume
        // When silent, shrink all bars to minimum with wave pattern
        NSAnimationContext.runAnimationGroup { context in
            context.duration = isSpeaking ? 0.06 : 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)

            for (index, bar) in bars.enumerated() {
                var targetHeight: CGFloat
                var alpha: CGFloat
                let waveMultiplier = index < waveMultipliers.count ? waveMultipliers[index] : 0.7

                if isSpeaking {
                    // Map dB to height: -60dB = min, -20dB = max
                    let normalizedDb = max(0, min(1, (db + 60) / 40))
                    // Add variation per bar for organic waveform effect
                    let variation = CGFloat.random(in: 0.7...1.0)
                    let baseHeight = barMinHeight + (barMaxHeight - barMinHeight) * CGFloat(normalizedDb)
                    targetHeight = baseHeight * waveMultiplier * variation
                    targetHeight = max(barMinHeight, targetHeight) // Ensure minimum
                    alpha = 0.6 + CGFloat(normalizedDb) * 0.4
                } else {
                    // Resting state with gentle wave pattern
                    targetHeight = barMinHeight + (barMaxHeight - barMinHeight) * 0.2 * waveMultiplier
                    alpha = 0.35
                }

                // Update bar frame (animate height from center)
                var frame = bar.frame
                let centerY = frame.midY
                frame.size.height = targetHeight
                frame.origin.y = centerY - targetHeight / 2
                bar.animator().frame = frame

                // Update color with smooth transition
                bar.animator().layer?.backgroundColor = color.withAlphaComponent(alpha).cgColor
            }
        }
    }

    /// Start typing dots animation - iMessage style bounce
    func startTypingDotsAnimation() {
        typingDotsView.isHidden = false

        for (index, dot) in typingDots.enumerated() {
            dot.removeAllAnimations()

            // Bounce animation
            let bounce = CAKeyframeAnimation(keyPath: "transform.translateY")
            bounce.values = [0, -6, 0]
            bounce.keyTimes = [0, 0.4, 1.0]
            bounce.duration = 0.5
            bounce.beginTime = CACurrentMediaTime() + Double(index) * 0.15
            bounce.repeatCount = .infinity
            bounce.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeIn)
            ]

            // Opacity pulse for extra polish
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0.4, 1.0, 0.4]
            opacity.keyTimes = [0, 0.4, 1.0]
            opacity.duration = 0.5
            opacity.beginTime = CACurrentMediaTime() + Double(index) * 0.15
            opacity.repeatCount = .infinity

            dot.add(bounce, forKey: "bounce")
            dot.add(opacity, forKey: "opacity")
        }
    }

    /// Stop typing dots animation
    func stopTypingDotsAnimation() {
        for dot in typingDots {
            dot.removeAllAnimations()
            dot.opacity = 1.0
        }
        typingDotsView.isHidden = true
    }

    /// Set loading indicator to inactive state (not used for spinning arc)
    func setWaveformInactiveState() {
        // No-op for spinning arc - just hide when not loading
    }

    // MARK: - Toolbar Button Updates

    /// Update play/stop button state
    func updateNestButtonState(recording: Bool) {
        let iconName = recording ? "stop.fill" : "play.fill"
        let accentColor = recording ? NSColor.appleRed : NSColor.appleGreen

        nestIconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: recording ? "Stop" : "Start")
        nestIconView.contentTintColor = accentColor
        voiceToggleButton.setAccessibilityLabel(recording ? "Stop Interview" : "Start Interview")

        CATransaction.begin()
        CATransaction.setAnimationDuration(LayoutConstants.Animation.normal)
        nestButtonInner.backgroundColor = accentColor.withAlphaComponent(LayoutConstants.Alpha.activeBackground).cgColor
        CATransaction.commit()

        updateStatusIcon(listening: recording, speaking: false)
    }

    /// Update status icon based on current state
    func updateStatusIcon(listening: Bool, speaking: Bool) {
        let iconName: String
        let iconColor: NSColor
        let bgColor: NSColor

        if speaking {
            iconName = "waveform"
            iconColor = NSColor.appleGold
            bgColor = NSColor.appleGold.withAlphaComponent(0.15)
        } else if listening {
            iconName = "ear"
            iconColor = NSColor.appleGreen
            bgColor = NSColor.appleGreen.withAlphaComponent(0.15)
        } else {
            iconName = "mic.slash"
            iconColor = NSColor.white.withAlphaComponent(0.4)
            bgColor = NSColor.white.withAlphaComponent(0.08)
        }

        statusIconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        statusIconView.contentTintColor = iconColor
        statusIconContainer.layer?.backgroundColor = bgColor.cgColor
        updateFocusSpeaking(speaking)
    }

    func clearTimeline() {
        voiceMessages.removeAll()
        for subview in voiceTimelineContainer.subviews {
            subview.removeFromSuperview()
        }
        resetInterviewFocusUI()
    }

    func promptForGroqApiKey() {
        let alert = NSAlert()
        alert.messageText = "Groq API Key Required"
        alert.informativeText = "Please configure your Groq API key in Settings to use voice transcription.\n\nYou can get a key at console.groq.com"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            showSettings()
        }
    }

    // MARK: - Timeline Insertion Helpers

    /// Insert a view at the top of the timeline, pushing existing messages down
    func insertTimelineItemAtTop(_ view: NSView) {
        let spacing = LayoutConstants.Timeline.messageSpacing
        let padding = LayoutConstants.Timeline.messagePadding
        let newMessageHeight = view.frame.height + spacing
        for subview in voiceTimelineContainer.subviews {
            subview.frame.origin.y += newMessageHeight
        }
        view.frame.origin.y = padding
        voiceTimelineContainer.addSubview(view)
        recalculateTimelineHeight()
        scrollTimelineToTop()
    }

    /// Insert a reply directly below the newest timeline item, keeping the current Q/A pair together.
    private func insertTimelineReplyBelowNewest(_ view: NSView) {
        let spacing = LayoutConstants.Timeline.messageSpacing
        let insertionY = replyInsertionYBelowNewestItem()
        let newMessageHeight = view.frame.height + spacing

        for subview in voiceTimelineContainer.subviews where subview.frame.origin.y >= insertionY {
            subview.frame.origin.y += newMessageHeight
        }

        view.frame.origin.y = insertionY
        voiceTimelineContainer.addSubview(view)
        recalculateTimelineHeight()
        scrollTimelineToTop()
    }

    private func replyInsertionYBelowNewestItem() -> CGFloat {
        guard let newestItem = voiceTimelineContainer.subviews.min(by: { $0.frame.origin.y < $1.frame.origin.y }) else {
            return LayoutConstants.Timeline.messagePadding
        }
        return newestItem.frame.maxY + LayoutConstants.Timeline.messageSpacing
    }

    /// Recalculate the timeline container height based on subview positions
    func recalculateTimelineHeight() {
        var maxY: CGFloat = 0
        for subview in voiceTimelineContainer.subviews {
            maxY = max(maxY, subview.frame.maxY)
        }
        voiceTimelineContainer.frame.size.height = max(voiceTimelineScrollView.frame.height, maxY + 20)
    }

    /// Scroll timeline to show the top (newest) message
    func scrollTimelineToTop() {
        voiceTimelineScrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
    }

    func addVoiceMessage(type: InterviewMessage.MessageType, content: String, topic: String?, audioSource: AudioSource? = nil, turnID: UUID? = nil, turnSequence: Int? = nil) {
        let message = InterviewMessage(
            type: type,
            content: content,
            topic: topic,
            audioSource: audioSource,
            turnID: turnID,
            turnSequence: turnSequence
        )
        voiceMessages.append(message)

        let messageView = messageViewFactory.createMessageView(for: message)
        let isNewTopic = (type == .question || type == .status || type == .codingTask || type == .screenshot)

        if isNewTopic {
            insertTimelineItemAtTop(messageView)
        } else {
            insertTimelineReplyBelowNewest(messageView)
        }

        // Update floating window Q&A if visible (real-time sync)
        if floatingSolutionController.window != nil && (type == .question || type == .answer || type == .followUp) {
            floatingSolutionController.updateQA()
        }
    }

    /// Add a user response message (collapsed by default, expandable)
    func addUserResponseMessage(content: String, topic: String?) {
        var message = InterviewMessage(type: .userResponse, content: content, topic: topic, audioSource: .microphone)
        message.isCollapsed = true
        voiceMessages.append(message)

        let messageView = createCollapsedUserResponseView(for: message)
        insertTimelineItemAtTop(messageView)
    }

    /// Create a collapsed user response view (click to expand)
    func createCollapsedUserResponseView(for message: InterviewMessage) -> NSView {
        let width = voiceTimelineContainer.frame.width - 40
        let collapsedHeight: CGFloat = 36

        let container = NSView(frame: NSRect(x: 20, y: 0, width: width, height: collapsedHeight))
        container.wantsLayer = true
        container.identifier = NSUserInterfaceItemIdentifier("userResponse_\(message.id.uuidString)")
        container.layer?.cornerRadius = 8
        container.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.024).cgColor
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.30).cgColor

        // Blue separator line on left
        let lineView = NSView(frame: NSRect(x: 0, y: 0, width: 3, height: collapsedHeight))
        lineView.wantsLayer = true
        lineView.layer?.backgroundColor = NSColor.systemBlue.cgColor
        lineView.layer?.cornerRadius = 1.5
        container.addSubview(lineView)

        // Time label
        let timeLabel = NSTextField(labelWithString: message.displayTime)
        timeLabel.frame = NSRect(x: width - 118, y: 10, width: 70, height: 16)
        timeLabel.font = .systemFont(ofSize: 11, weight: .medium)
        timeLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        timeLabel.alignment = .right
        container.addSubview(timeLabel)

        if let symbol = NSImage(systemSymbolName: "person.wave.2.fill", accessibilityDescription: nil) {
            let iconView = NSImageView(frame: NSRect(x: 14, y: 10, width: 14, height: 14))
            iconView.image = symbol
            iconView.contentTintColor = NSColor.systemBlue
            iconView.imageScaling = .scaleProportionallyUpOrDown
            container.addSubview(iconView)
        }

        let youSaidLabel = NSTextField(labelWithString: "You")
        youSaidLabel.frame = NSRect(x: 34, y: 10, width: 34, height: 16)
        youSaidLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        youSaidLabel.textColor = NSColor.systemBlue
        container.addSubview(youSaidLabel)

        // Preview of content (first ~40 chars)
        let preview = message.content.prefix(40) + (message.content.count > 40 ? "..." : "")
        let previewLabel = NSTextField(labelWithString: String(preview))
        previewLabel.frame = NSRect(x: 70, y: 10, width: width - 200, height: 16)
        previewLabel.font = .systemFont(ofSize: 12, weight: .regular)
        previewLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        previewLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(previewLabel)

        // Expand button
        let expandButton = NSButton(frame: NSRect(x: width - 50, y: 6, width: 40, height: 24))
        expandButton.title = ">"
        expandButton.bezelStyle = .inline
        expandButton.isBordered = false
        expandButton.font = .systemFont(ofSize: 10)
        expandButton.contentTintColor = NSColor.systemBlue
        expandButton.target = self
        expandButton.action = #selector(toggleUserResponseExpand(_:))
        expandButton.identifier = NSUserInterfaceItemIdentifier(message.id.uuidString)
        container.addSubview(expandButton)

        // Store full content in container for expansion
        container.toolTip = message.content

        return container
    }

    @objc func toggleUserResponseExpand(_ sender: NSButton) {
        guard let messageId = sender.identifier?.rawValue,
              UUID(uuidString: messageId) != nil else { return }

        // Find the container view
        guard let container = voiceTimelineContainer.subviews.first(where: {
            $0.identifier?.rawValue == "userResponse_\(messageId)"
        }) else { return }

        // Get stored content from tooltip
        let fullContent = container.toolTip ?? ""

        // Check if already expanded
        let isExpanded = container.frame.height > 50

        if isExpanded {
            // Collapse: animate to small height
            let collapsedHeight: CGFloat = 36
            let heightDiff = container.frame.height - collapsedHeight

            // Update button
            sender.title = ">"

            // Hide content text view if exists
            for subview in container.subviews {
                if subview is NSScrollView {
                    subview.removeFromSuperview()
                }
            }

            // Resize container
            container.frame.size.height = collapsedHeight

            // Move messages below this one down
            for subview in voiceTimelineContainer.subviews where subview.frame.origin.y > container.frame.origin.y {
                subview.frame.origin.y -= heightDiff
            }

            // Update separator line height
            if let lineView = container.subviews.first {
                lineView.frame.size.height = collapsedHeight
            }

        } else {
            // Expand: show full content
            let textHeight = messageViewFactory.estimateTextHeight(fullContent, width: container.frame.width - 30)
            let expandedHeight = max(60, textHeight + 45)
            let heightDiff = expandedHeight - container.frame.height

            // Update button
            sender.title = "v"

            // Move messages below this one up to make room
            for subview in voiceTimelineContainer.subviews where subview.frame.origin.y > container.frame.origin.y {
                subview.frame.origin.y += heightDiff
            }

            // Resize container
            container.frame.size.height = expandedHeight

            // Update separator line height
            if let lineView = container.subviews.first {
                lineView.frame.size.height = expandedHeight
            }

            // Add content text view
            let contentScrollView = NSScrollView(frame: NSRect(x: 15, y: 5, width: container.frame.width - 30, height: expandedHeight - 40))
            contentScrollView.hasVerticalScroller = false
            contentScrollView.drawsBackground = false

            let contentView = NSTextView(frame: contentScrollView.bounds)
            contentView.isEditable = false
            contentView.isSelectable = true
            contentView.drawsBackground = false
            contentView.backgroundColor = .clear
            contentView.textContainerInset = .zero
            contentView.string = fullContent
            contentView.font = .systemFont(ofSize: 12)
            contentView.textColor = NSColor.white.withAlphaComponent(0.8)

            contentScrollView.documentView = contentView
            container.addSubview(contentScrollView)
        }

        recalculateTimelineHeight()
    }

    /// Add a screenshot thumbnail to the voice timeline (gallery style - one entry, multiple thumbnails)
    func addScreenshotToTimeline(thumbnail: NSImage, screenshotId: UUID) {
        let message = InterviewMessage(type: .screenshot, content: "Screenshot", topic: nil, screenshotId: screenshotId)
        voiceMessages.append(message)

        let thumbWidth: CGFloat = 80
        let thumbHeight: CGFloat = 50
        let thumbGap: CGFloat = 8

        // Check if screenshot gallery already exists - add to it
        if let existingGallery = voiceTimelineContainer.subviews.first(where: { $0.identifier?.rawValue == "screenshotGallery" }) {
            if let card = existingGallery.subviews.first(where: { $0.identifier?.rawValue == "screenshotCard" }),
               let scrollView = card.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
               let galleryContainer = scrollView.documentView {

                // Count existing thumbnails to position new one
                let existingCount = galleryContainer.subviews.count
                let newX = CGFloat(existingCount) * (thumbWidth + thumbGap)

                // Create new thumbnail button
                let thumbnailButton = NSButton(frame: NSRect(x: newX, y: 0, width: thumbWidth, height: thumbHeight))
                thumbnailButton.image = thumbnail
                thumbnailButton.imageScaling = .scaleProportionallyUpOrDown
                thumbnailButton.isBordered = false
                thumbnailButton.bezelStyle = .rounded
                thumbnailButton.wantsLayer = true
                thumbnailButton.layer?.cornerRadius = 6
                thumbnailButton.layer?.borderWidth = 2
                thumbnailButton.layer?.borderColor = NSColor.applePurple.withAlphaComponent(0.4).cgColor
                thumbnailButton.layer?.masksToBounds = true
                thumbnailButton.target = self
                thumbnailButton.action = #selector(screenshotThumbnailClicked(_:))
                thumbnailButton.identifier = NSUserInterfaceItemIdentifier(screenshotId.uuidString)
                galleryContainer.addSubview(thumbnailButton)

                // Update gallery container width
                galleryContainer.frame.size.width = newX + thumbWidth + thumbGap

                // Update count label
                if let countLabel = card.subviews.first(where: { $0.identifier?.rawValue == "screenshotCount" }) as? NSTextField {
                    countLabel.stringValue = "\(screenshots.count) screenshots"
                }

                // Scroll to show newest thumbnail
                scrollView.contentView.scroll(to: NSPoint(x: max(0, galleryContainer.frame.width - scrollView.frame.width), y: 0))
            }
            return
        }

        // Create new screenshot gallery entry
        let badgeWidth: CGFloat = 22
        let badgeGap: CGFloat = 8
        let cardX: CGFloat = badgeWidth + badgeGap
        let cardWidth = voiceTimelineContainer.frame.width - 40 - cardX
        let containerHeight: CGFloat = 100

        // Outer container to hold badge + card
        let outerContainer = NSView(frame: NSRect(x: 20, y: 0, width: voiceTimelineContainer.frame.width - 40, height: containerHeight))
        outerContainer.identifier = NSUserInterfaceItemIdentifier("screenshotGallery")

        // S Badge - purple pill on the left
        let badge = NSView(frame: NSRect(x: 0, y: containerHeight - 26, width: badgeWidth, height: badgeWidth))
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.applePurple.withAlphaComponent(0.15).cgColor
        badge.layer?.cornerRadius = badgeWidth / 2

        let badgeLabel = NSTextField(labelWithString: "S")
        badgeLabel.frame = NSRect(x: 0, y: 3, width: badgeWidth, height: 16)
        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textColor = NSColor.applePurple
        badgeLabel.alignment = .center
        badge.addSubview(badgeLabel)
        outerContainer.addSubview(badge)

        // Card container
        let card = NSView(frame: NSRect(x: cardX, y: 0, width: cardWidth, height: containerHeight))
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.backgroundColor = NSColor.applePurple.withAlphaComponent(0.024).cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.applePurple.withAlphaComponent(0.30).cgColor
        card.identifier = NSUserInterfaceItemIdentifier("screenshotCard")
        outerContainer.addSubview(card)

        // Accent bar on left of card
        let accentBar = NSView(frame: NSRect(x: 0, y: 0, width: 3, height: containerHeight))
        accentBar.wantsLayer = true
        accentBar.layer?.backgroundColor = NSColor.applePurple.cgColor
        accentBar.layer?.cornerRadius = 1.5
        card.addSubview(accentBar)

        // Header with icon and count
        let headerIcon = NSImageView(frame: NSRect(x: 15, y: containerHeight - 26, width: 14, height: 14))
        headerIcon.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "Screenshot")
        headerIcon.contentTintColor = NSColor.applePurple
        card.addSubview(headerIcon)

        let countLabel = NSTextField(labelWithString: "1 screenshot")
        countLabel.frame = NSRect(x: 34, y: containerHeight - 25, width: 100, height: 14)
        countLabel.font = .systemFont(ofSize: 11, weight: .medium)
        countLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        countLabel.identifier = NSUserInterfaceItemIdentifier("screenshotCount")
        card.addSubview(countLabel)

        // Hint text on right
        let hintLabel = NSTextField(labelWithString: "⌘↩ analyze")
        hintLabel.frame = NSRect(x: cardWidth - 85, y: containerHeight - 25, width: 70, height: 14)
        hintLabel.font = .systemFont(ofSize: 10, weight: .medium)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.35)
        card.addSubview(hintLabel)

        // Horizontal scroll view for thumbnails
        let scrollView = NSScrollView(frame: NSRect(x: 15, y: 10, width: cardWidth - 30, height: thumbHeight + 10))
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        // Gallery container (expands horizontally)
        let galleryContainer = NSView(frame: NSRect(x: 0, y: 0, width: thumbWidth + thumbGap, height: thumbHeight))
        scrollView.documentView = galleryContainer

        // First thumbnail
        let thumbnailButton = NSButton(frame: NSRect(x: 0, y: 0, width: thumbWidth, height: thumbHeight))
        thumbnailButton.image = thumbnail
        thumbnailButton.imageScaling = .scaleProportionallyUpOrDown
        thumbnailButton.isBordered = false
        thumbnailButton.bezelStyle = .rounded
        thumbnailButton.wantsLayer = true
        thumbnailButton.layer?.cornerRadius = 6
        thumbnailButton.layer?.borderWidth = 2
        thumbnailButton.layer?.borderColor = NSColor.applePurple.withAlphaComponent(0.4).cgColor
        thumbnailButton.layer?.masksToBounds = true
        thumbnailButton.target = self
        thumbnailButton.action = #selector(screenshotThumbnailClicked(_:))
        thumbnailButton.identifier = NSUserInterfaceItemIdentifier(screenshotId.uuidString)
        galleryContainer.addSubview(thumbnailButton)

        card.addSubview(scrollView)

        insertTimelineItemAtTop(outerContainer)
    }

    @objc func screenshotThumbnailClicked(_ sender: NSButton) {
        // Trigger analysis when screenshot is clicked
        analyzeScreenshots()
    }

    /// Pin a coding task solution in the timeline (replaces previous coding task if any)
    func setPinnedSolution(_ solution: String) {
        currentPinnedSolution = solution

        // Remove any existing coding task from timeline and shift messages up
        for subview in voiceTimelineContainer.subviews {
            if subview.identifier?.rawValue == "codingTask" {
                let removedHeight = subview.frame.height + 15
                subview.removeFromSuperview()
                // Shift all messages up to fill the gap
                for other in voiceTimelineContainer.subviews {
                    if other.frame.origin.y > 10 {
                        other.frame.origin.y -= removedHeight
                    }
                }
                break
            }
        }

        // Add coding task as a timeline message at the top
        let message = InterviewMessage(type: .codingTask, content: solution, topic: "solution")
        let messageView = messageViewFactory.createMessageView(for: message)

        insertTimelineItemAtTop(messageView)

        // Hide the old overlay container (no longer needed)
        pinnedSolutionContainer.isHidden = true
    }

    /// Clear the pinned solution from timeline
    func clearPinnedSolution() {
        currentPinnedSolution = nil

        for subview in voiceTimelineContainer.subviews {
            if subview.identifier?.rawValue == "codingTask" {
                let removedHeight = subview.frame.height + LayoutConstants.Timeline.messageSpacing
                subview.removeFromSuperview()
                for otherView in voiceTimelineContainer.subviews {
                    if otherView.frame.origin.y > LayoutConstants.Timeline.messagePadding {
                        otherView.frame.origin.y -= removedHeight
                    }
                }
                break
            }
        }

        recalculateTimelineHeight()
    }
}
