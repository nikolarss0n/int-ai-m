import Cocoa

/// Protocol for streaming message handler callbacks
protocol StreamingMessageHandlerDelegate: AnyObject {
    var voiceMessages: [InterviewMessage] { get set }
    func updateFloatingQA()
}

/// Handles creation and updates of streaming answer messages in the timeline
class StreamingMessageHandler {
    private weak var timelineContainer: NSView?
    private weak var scrollView: NSScrollView?
    private let messageViewFactory: MessageViewFactory
    private weak var delegate: StreamingMessageHandlerDelegate?

    // Current streaming state
    private(set) var currentTextView: NSTextView?
    private(set) var currentContainer: NSView?
    private var currentAccentColor: NSColor = .appleGreen

    init(timelineContainer: NSView, scrollView: NSScrollView, messageViewFactory: MessageViewFactory, delegate: StreamingMessageHandlerDelegate) {
        self.timelineContainer = timelineContainer
        self.scrollView = scrollView
        self.messageViewFactory = messageViewFactory
        self.delegate = delegate
    }

    /// Add an empty streaming message that will be updated
    func addStreamingMessage(type: InterviewMessage.MessageType, topic: String?, latencyMs: Int? = nil) {
        guard let timelineContainer = timelineContainer else { return }
        _ = latencyMs

        // Completion timing is shown only after the answer is fully generated.
        let message = InterviewMessage(type: type, content: "▌", topic: topic)
        delegate?.voiceMessages.append(message)

        // Layout: A badge indented from the question rail, card after badge.
        let horizontalInset = LayoutConstants.Timeline.horizontalInset
        let badgeWidth = LayoutConstants.Timeline.badgeSize
        let badgeGap = LayoutConstants.Timeline.badgeGap
        let answerIndent = LayoutConstants.Timeline.answerIndent
        let badgeX: CGFloat = answerIndent
        let cardX: CGFloat = badgeX + badgeWidth + badgeGap
        let outerWidth = timelineContainer.frame.width - horizontalInset * 2
        let cardWidth = outerWidth - cardX
        let initialHeight: CGFloat = 80
        let accentColor = streamingAccentColor(for: topic)
        currentAccentColor = accentColor

        // Outer container for badge + card
        let outerContainer = NSView(frame: NSRect(x: horizontalInset, y: 0, width: outerWidth, height: initialHeight))
        outerContainer.identifier = NSUserInterfaceItemIdentifier("streamingOuter")

        // A Badge
        let badge = NSView(frame: NSRect(x: badgeX, y: badgeY(for: initialHeight), width: badgeWidth, height: badgeWidth))
        badge.wantsLayer = true
        badge.layer?.backgroundColor = accentColor.withAlphaComponent(0.12).cgColor
        badge.layer?.cornerRadius = badgeWidth / 2
        badge.identifier = NSUserInterfaceItemIdentifier("streamingBadge")

        let badgeLabel = NSTextField(labelWithString: "A")
        badgeLabel.frame = NSRect(x: 0, y: 3, width: badgeWidth, height: 16)
        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textColor = accentColor
        badgeLabel.alignment = .center
        badge.addSubview(badgeLabel)
        outerContainer.addSubview(badge)

        // Card container
        let container = NSView(frame: NSRect(x: cardX, y: 0, width: cardWidth, height: initialHeight))
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.backgroundColor = accentColor.withAlphaComponent(0.024).cgColor
        container.layer?.borderWidth = 1
        container.layer?.borderColor = accentColor.withAlphaComponent(0.30).cgColor
        container.layer?.shadowColor = NSColor.black.withAlphaComponent(0.45).cgColor
        container.layer?.shadowOpacity = 0.06
        container.layer?.shadowRadius = 5
        container.layer?.shadowOffset = CGSize(width: 0, height: 1)
        container.identifier = NSUserInterfaceItemIdentifier("streamingContainer")

        // Green accent bar on left
        let lineView = NSView(frame: NSRect(x: 0, y: 0, width: LayoutConstants.Timeline.accentBarWidth, height: initialHeight))
        lineView.wantsLayer = true
        lineView.layer?.backgroundColor = accentColor.cgColor
        lineView.layer?.cornerRadius = 1.5
        lineView.identifier = NSUserInterfaceItemIdentifier("streamingLine")
        container.addSubview(lineView)

        // SF Symbol icon
        let symbolName = isPlaywrightTopic(topic) ? "checkmark.seal.fill" : "sparkles"
        if let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let iconBackplate = NSView(frame: NSRect(x: 10, y: initialHeight - 25, width: 22, height: 22))
            iconBackplate.wantsLayer = true
            iconBackplate.layer?.cornerRadius = 6
            iconBackplate.layer?.backgroundColor = accentColor.withAlphaComponent(0.10).cgColor
            iconBackplate.identifier = NSUserInterfaceItemIdentifier("streamingIconBackplate")
            container.addSubview(iconBackplate)

            let iconView = NSImageView(frame: NSRect(x: 13, y: initialHeight - 22, width: 16, height: 16))
            iconView.image = symbolImage
            iconView.contentTintColor = accentColor
            iconView.imageScaling = .scaleProportionallyUpOrDown
            container.addSubview(iconView)
        }

        // Completion timestamp. Hidden while the answer is still loading.
        let timeLabel = NSTextField(labelWithString: "")
        timeLabel.frame = NSRect(x: cardWidth - 80, y: initialHeight - 22, width: 70, height: 16)
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        timeLabel.textColor = NSColor.white.withAlphaComponent(0.35)
        timeLabel.alignment = .right
        timeLabel.isHidden = true
        timeLabel.identifier = NSUserInterfaceItemIdentifier("streamingTimeLabel")
        container.addSubview(timeLabel)

        // Topic badge
        if let topic = topic, topic != "followUp" && topic != "answer" && topic != "unknown" {
            let topicPill = NSView(frame: NSRect(x: 38, y: initialHeight - 22, width: 0, height: 18))
            topicPill.wantsLayer = true
            topicPill.layer?.backgroundColor = accentColor.withAlphaComponent(0.12).cgColor
            topicPill.layer?.cornerRadius = 9
            topicPill.identifier = NSUserInterfaceItemIdentifier("streamingTopicPill")

            let topicLabel = NSTextField(labelWithString: topic.lowercased())
            topicLabel.font = .systemFont(ofSize: 10, weight: .medium)
            topicLabel.textColor = accentColor
            topicLabel.sizeToFit()

            topicPill.frame.size.width = topicLabel.frame.width + 16
            topicLabel.frame.origin = NSPoint(x: 8, y: 2)
            topicPill.addSubview(topicLabel)
            container.addSubview(topicPill)
        }

        // Loading spinner
        let spinner = NSProgressIndicator(frame: NSRect(x: 15, y: initialHeight / 2 - 20, width: 20, height: 20))
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)
        spinner.identifier = NSUserInterfaceItemIdentifier("streamingSpinner")
        container.addSubview(spinner)

        // Loading label next to spinner
        let loadingLabel = NSTextField(labelWithString: "Generating answer...")
        loadingLabel.frame = NSRect(x: 42, y: initialHeight / 2 - 18, width: 150, height: 16)
        loadingLabel.font = .systemFont(ofSize: 12, weight: .medium)
        loadingLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        loadingLabel.identifier = NSUserInterfaceItemIdentifier("streamingLoadingLabel")
        container.addSubview(loadingLabel)

        // Streaming text view (hidden initially)
        let textView = NSTextView(frame: NSRect(x: 14, y: 12, width: cardWidth - 28, height: initialHeight - 42))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .white
        textView.string = ""
        textView.isHidden = true
        textView.alphaValue = 0
        textView.identifier = NSUserInterfaceItemIdentifier("streamingText")
        container.addSubview(textView)

        outerContainer.addSubview(container)

        currentTextView = textView
        currentContainer = container

        // Streaming answers appear directly below the newest timeline item.
        let topMessageMaxY = replyInsertionYBelowNewestItem(in: timelineContainer)

        // Push messages below the answer position
        let newMessageHeight = outerContainer.frame.height + LayoutConstants.Timeline.messageSpacing
        for subview in timelineContainer.subviews {
            if subview.frame.origin.y >= topMessageMaxY {
                subview.frame.origin.y += newMessageHeight
            }
        }

        outerContainer.frame.origin.y = topMessageMaxY
        timelineContainer.addSubview(outerContainer)

        // Update container height
        updateTimelineHeight()

        // Scroll to top to show newest
        scrollView?.contentView.scroll(to: NSPoint(x: 0, y: 0))
    }

    /// Update the streaming message with new content (with live formatting)
    func updateStreamingMessage(_ content: String) {
        guard let textView = currentTextView,
              let container = currentContainer,
              let timelineContainer = timelineContainer else { return }

        // Hide spinner and loading label, show text view when content starts
        if !content.isEmpty && textView.isHidden {
            if let spinner = container.subviews.first(where: { $0.identifier?.rawValue == "streamingSpinner" }) as? NSProgressIndicator {
                spinner.stopAnimation(nil)
                spinner.isHidden = true
            }
            if let loadingLabel = container.subviews.first(where: { $0.identifier?.rawValue == "streamingLoadingLabel" }) {
                loadingLabel.isHidden = true
            }
            textView.isHidden = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = LayoutConstants.Animation.normal
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                textView.animator().alphaValue = 1
            }
        }

        // Apply formatting in real-time
        let formattedContent = messageViewFactory.formatMessageContent(content, isQuestion: false)
        let mutableContent = NSMutableAttributedString(attributedString: formattedContent)

        // Add blinking cursor
        let cursorAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: currentAccentColor
        ]
        mutableContent.append(NSAttributedString(string: " ▌", attributes: cursorAttrs))

        textView.textStorage?.setAttributedString(mutableContent)

        // Dynamically resize container as content grows
        let width = container.frame.width - 30
        let newTextHeight = max(40, messageViewFactory.estimateTextHeight(content, width: width))
        let newContainerHeight = newTextHeight + 40

        if newContainerHeight > container.frame.height {
            let heightDiff = newContainerHeight - container.frame.height

            // Update container and text view
            container.frame.size.height = newContainerHeight
            textView.frame.size.height = newTextHeight

            let outerContainer = container.superview ?? container
            resizeStreamingOuterContainer(for: container, to: newContainerHeight)
            updateStreamingCardChrome(in: container, height: newContainerHeight)
            shiftTimelineItemsBelow(outerContainer, by: heightDiff, in: timelineContainer)

            // Update total container height
            updateTimelineHeight()
        }
    }

    /// Finalize streaming message with proper formatting
    func finalizeStreamingMessage(_ content: String, totalLatencyMs: Int? = nil) {
        guard let textView = currentTextView,
              let container = currentContainer,
              let timelineContainer = timelineContainer else { return }

        // Apply formatted text
        let attributedContent = messageViewFactory.formatMessageContent(content, isQuestion: false)
        textView.textStorage?.setAttributedString(attributedContent)

        // Recalculate height
        let width = container.frame.width - 30
        let newTextHeight = max(40, messageViewFactory.estimateTextHeight(content, width: width))
        let newContainerHeight = newTextHeight + 40

        // Calculate height difference
        let heightDiff = newContainerHeight - container.frame.height

        // Update container and children
        container.frame.size.height = newContainerHeight
        textView.frame.size.height = newTextHeight

        let outerContainer = container.superview ?? container
        resizeStreamingOuterContainer(for: container, to: newContainerHeight)
        updateStreamingCardChrome(in: container, height: newContainerHeight)
        showCompletionMetadata(in: container, content: content, totalLatencyMs: totalLatencyMs, height: newContainerHeight)
        shiftTimelineItemsBelow(outerContainer, by: heightDiff, in: timelineContainer)

        // Update container height
        updateTimelineHeight()

        // Update the last message in voiceMessages with final content
        if var messages = delegate?.voiceMessages, !messages.isEmpty {
            let lastIndex = messages.count - 1
            let lastMessage = messages[lastIndex]
            messages[lastIndex] = InterviewMessage(type: lastMessage.type, content: content, topic: lastMessage.topic, responseLatencyMs: totalLatencyMs ?? lastMessage.responseLatencyMs)
            delegate?.voiceMessages = messages

            // Update floating window Q&A
            delegate?.updateFloatingQA()
        }

        // Clear streaming state
        currentTextView = nil
        currentContainer = nil
    }

    /// Clear the current streaming state without finalizing
    func clearStreamingState() {
        currentTextView = nil
        currentContainer = nil
    }

    // MARK: - Private Helpers

    private func replyInsertionYBelowNewestItem(in timelineContainer: NSView) -> CGFloat {
        guard let newestItem = timelineContainer.subviews.min(by: { $0.frame.origin.y < $1.frame.origin.y }) else {
            return LayoutConstants.Timeline.messagePadding
        }
        return newestItem.frame.maxY + LayoutConstants.Timeline.messageSpacing
    }

    private func badgeY(for containerHeight: CGFloat) -> CGFloat {
        containerHeight - LayoutConstants.Timeline.badgeSize - LayoutConstants.Spacing.xs
    }

    private func resizeStreamingOuterContainer(for container: NSView, to height: CGFloat) {
        guard let outerContainer = container.superview,
              outerContainer.identifier?.rawValue == "streamingOuter" else { return }

        outerContainer.frame.size.height = height
        if let badge = outerContainer.subviews.first(where: { $0.identifier?.rawValue == "streamingBadge" }) {
            badge.frame.origin.y = badgeY(for: height)
        }
    }

    private func updateStreamingCardChrome(in container: NSView, height: CGFloat) {
        if let lineView = container.subviews.first(where: { $0.identifier?.rawValue == "streamingLine" }) {
            lineView.frame.size.height = height
        }

        for subview in container.subviews {
            let identifier = subview.identifier?.rawValue
            if identifier == "streamingIconBackplate" {
                subview.frame.origin.y = height - 25
            } else if subview is NSTextField || subview is NSImageView || identifier == "streamingTopicPill" {
                if identifier != "streamingText" &&
                   identifier != "streamingSpinner" &&
                   identifier != "streamingLoadingLabel" {
                    subview.frame.origin.y = height - 22
                }
            }
        }
    }

    private func showCompletionMetadata(in container: NSView, content: String, totalLatencyMs: Int?, height: CGFloat) {
        let completionMessage = InterviewMessage(type: .answer, content: content, responseLatencyMs: totalLatencyMs)
        let cardWidth = container.frame.width

        if let display = completionMessage.displayLatency {
            let latencyLabel = metadataLabel(
                in: container,
                identifier: "streamingLatencyLabel",
                frame: NSRect(x: cardWidth - 145, y: height - 22, width: 55, height: 16),
                color: NSColor.systemCyan.withAlphaComponent(0.8),
                weight: .medium
            )
            latencyLabel.stringValue = "⚡\(display)"
            latencyLabel.isHidden = false
        }

        let timeLabel = metadataLabel(
            in: container,
            identifier: "streamingTimeLabel",
            frame: NSRect(x: cardWidth - 80, y: height - 22, width: 70, height: 16),
            color: NSColor.white.withAlphaComponent(0.35),
            weight: .regular
        )
        timeLabel.stringValue = completionMessage.displayTime
        timeLabel.isHidden = false
    }

    private func metadataLabel(
        in container: NSView,
        identifier: String,
        frame: NSRect,
        color: NSColor,
        weight: NSFont.Weight
    ) -> NSTextField {
        if let label = container.subviews.first(where: { $0.identifier?.rawValue == identifier }) as? NSTextField {
            label.frame = frame
            label.textColor = color
            label.alignment = .right
            return label
        }

        let label = NSTextField(labelWithString: "")
        label.frame = frame
        label.font = .monospacedDigitSystemFont(ofSize: 10, weight: weight)
        label.textColor = color
        label.alignment = .right
        label.identifier = NSUserInterfaceItemIdentifier(identifier)
        container.addSubview(label)
        return label
    }

    private func shiftTimelineItemsBelow(_ referenceView: NSView, by delta: CGFloat, in timelineContainer: NSView) {
        guard delta != 0 else { return }

        for subview in timelineContainer.subviews where subview !== referenceView {
            if subview.frame.origin.y > referenceView.frame.origin.y {
                subview.frame.origin.y += delta
            }
        }
    }

    private func updateTimelineHeight() {
        guard let timelineContainer = timelineContainer else { return }

        var maxY: CGFloat = 0
        for subview in timelineContainer.subviews {
            maxY = max(maxY, subview.frame.maxY)
        }
        timelineContainer.frame.size.height = max(scrollView?.frame.height ?? 0, maxY + 20)
    }

    private func isPlaywrightTopic(_ topic: String?) -> Bool {
        guard let topic = topic?.lowercased() else { return false }
        let handles = [
            "playwright", "locator", "autowait", "auto-wait", "webfirst", "web-first",
            "storagestate", "browsercontext", "pageroute", "trac", "fixture",
            "shard", "worker", "retry", "flaky", "e2e", "api"
        ]
        return handles.contains { topic.contains($0) }
    }

    private func streamingAccentColor(for topic: String?) -> NSColor {
        if isPlaywrightTopic(topic) {
            return .systemCyan
        }
        return .appleGreen
    }
}
