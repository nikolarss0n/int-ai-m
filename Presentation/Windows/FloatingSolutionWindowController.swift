import Cocoa

/// Protocol for floating solution window data source
protocol FloatingSolutionDataSource: AnyObject {
    var currentPinnedSolution: String? { get }
    var voiceMessages: [InterviewMessage] { get }
    var messageViewFactory: MessageViewFactory! { get }
}

/// Controller for the floating solution window (stealth mode)
class FloatingSolutionWindowController {
    private weak var dataSource: FloatingSolutionDataSource?

    // Window references
    private(set) var window: NSWindow?
    private var textView: NSTextView?
    private var scrollView: NSScrollView?
    private var qaContainer: NSView?
    private var loadingView: NSView?
    private var eventMonitor: Any?

    init(dataSource: FloatingSolutionDataSource) {
        self.dataSource = dataSource
    }

    // MARK: - Public Interface

    /// Show floating solution window in top-right corner
    func show() {
        guard let dataSource = dataSource,
              let solution = dataSource.currentPinnedSolution, !solution.isEmpty else { return }

        // Dismiss existing if any
        dismiss()

        // Get screen dimensions
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // Floating window size (wider and taller for better readability)
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = min(750, screenFrame.height * 0.8)

        // Position in top-right corner with padding
        let windowX = screenFrame.maxX - windowWidth - 20
        let windowY = screenFrame.maxY - windowHeight - 20

        // Create borderless floating window (StealthWindow = clicks don't steal focus)
        let floatingWindow = StealthWindow(
            contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        floatingWindow.level = .floating
        floatingWindow.isOpaque = false
        floatingWindow.backgroundColor = .clear
        floatingWindow.hasShadow = true
        floatingWindow.isMovableByWindowBackground = true

        // Container with blur effect
        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.applePurple.withAlphaComponent(0.5).cgColor

        // Header with shortcuts
        let headerLabel = NSTextField(labelWithString: "⌘B Show  •  ⌘\\ Hide  •  ⌘J/K Scroll  •  ⌘Arrows Move")
        headerLabel.frame = NSRect(x: 12, y: windowHeight - 24, width: windowWidth - 24, height: 16)
        headerLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        headerLabel.textColor = .tertiaryLabelColor
        headerLabel.alignment = .center
        container.addSubview(headerLabel)

        // Calculate space for last Q&A (timeline style - taller to avoid overlap)
        let lastQA = getLastQuestionAnswer()
        let qaHeight: CGFloat = lastQA != nil ? 270 : 0
        let loadingHeight: CGFloat = 40

        // Solution scroll view (hidden scrollers, show on hover)
        let solutionScrollView = NSScrollView(frame: NSRect(x: 8, y: qaHeight + loadingHeight + 8, width: windowWidth - 16, height: windowHeight - 36 - qaHeight - loadingHeight))
        solutionScrollView.hasVerticalScroller = true
        solutionScrollView.hasHorizontalScroller = false
        solutionScrollView.autohidesScrollers = true
        solutionScrollView.scrollerStyle = .overlay
        solutionScrollView.borderType = .noBorder
        solutionScrollView.drawsBackground = false
        solutionScrollView.backgroundColor = .clear

        // Solution text view
        let solutionTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: solutionScrollView.contentSize.width, height: 0))
        solutionTextView.isEditable = false
        solutionTextView.isSelectable = true
        solutionTextView.drawsBackground = false
        solutionTextView.backgroundColor = .clear
        solutionTextView.textContainerInset = NSSize(width: 4, height: 4)
        solutionTextView.isVerticallyResizable = true
        solutionTextView.autoresizingMask = [.width]
        solutionTextView.textContainer?.widthTracksTextView = true

        // Format and set solution content
        let attributedSolution = dataSource.messageViewFactory.formatMessageContent(solution, isQuestion: false)
        solutionTextView.textStorage?.setAttributedString(attributedSolution)

        solutionScrollView.documentView = solutionTextView
        container.addSubview(solutionScrollView)
        self.textView = solutionTextView
        self.scrollView = solutionScrollView

        // Loading indicator - ambient glow
        let floatingGlowSize: CGFloat = 40
        let loadingViewInstance = NSView(frame: NSRect(
            x: (windowWidth - floatingGlowSize) / 2,
            y: qaHeight + (loadingHeight - floatingGlowSize) / 2,
            width: floatingGlowSize,
            height: floatingGlowSize
        ))
        loadingViewInstance.wantsLayer = true
        loadingViewInstance.isHidden = true

        // Pure glow layer
        let floatingGlow = CALayer()
        floatingGlow.frame = CGRect(x: 0, y: 0, width: floatingGlowSize, height: floatingGlowSize)
        floatingGlow.cornerRadius = floatingGlowSize / 2
        floatingGlow.backgroundColor = NSColor.appleGreen.withAlphaComponent(0.2).cgColor
        floatingGlow.shadowColor = NSColor.appleGreen.cgColor
        floatingGlow.shadowOffset = .zero
        floatingGlow.shadowRadius = 15
        floatingGlow.shadowOpacity = 0.5
        loadingViewInstance.layer?.addSublayer(floatingGlow)

        container.addSubview(loadingViewInstance)
        self.loadingView = loadingViewInstance

        // Q&A section (timeline style)
        if let (question, answer) = lastQA {
            // Divider
            let divider = NSView(frame: NSRect(x: 12, y: qaHeight + 4, width: windowWidth - 24, height: 1))
            divider.wantsLayer = true
            divider.layer?.backgroundColor = NSColor.separatorColor.cgColor
            container.addSubview(divider)

            // Q&A container
            let qaContainerView = NSView(frame: NSRect(x: 8, y: 8, width: windowWidth - 16, height: qaHeight - 12))
            qaContainerView.wantsLayer = true
            container.addSubview(qaContainerView)
            self.qaContainer = qaContainerView

            // Question bubble (timeline style - left aligned, darker)
            let qBubble = NSView(frame: NSRect(x: 0, y: qaHeight - 50, width: windowWidth - 40, height: 38))
            qBubble.wantsLayer = true
            qBubble.layer?.cornerRadius = 8
            qBubble.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
            qaContainerView.addSubview(qBubble)

            let qLabel = NSTextField(wrappingLabelWithString: question)
            qLabel.frame = NSRect(x: 8, y: 4, width: qBubble.frame.width - 16, height: 30)
            qLabel.font = .systemFont(ofSize: 11)
            qLabel.textColor = .secondaryLabelColor
            qLabel.lineBreakMode = .byTruncatingTail
            qLabel.maximumNumberOfLines = 2
            qBubble.addSubview(qLabel)

            // Answer bubble (timeline style - full width, lighter)
            let aBubble = NSView(frame: NSRect(x: 0, y: 4, width: windowWidth - 40, height: qaHeight - 58))
            aBubble.wantsLayer = true
            aBubble.layer?.cornerRadius = 8
            aBubble.layer?.backgroundColor = NSColor.applePurple.withAlphaComponent(0.15).cgColor
            qaContainerView.addSubview(aBubble)

            let aScrollView = NSScrollView(frame: NSRect(x: 4, y: 4, width: aBubble.frame.width - 8, height: aBubble.frame.height - 8))
            aScrollView.hasVerticalScroller = true
            aScrollView.hasHorizontalScroller = false
            aScrollView.autohidesScrollers = true
            aScrollView.scrollerStyle = .overlay
            aScrollView.borderType = .noBorder
            aScrollView.drawsBackground = false

            let aTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: aScrollView.contentSize.width, height: 0))
            aTextView.isEditable = false
            aTextView.isSelectable = true
            aTextView.drawsBackground = false
            aTextView.textContainerInset = NSSize(width: 2, height: 2)
            aTextView.isVerticallyResizable = true
            aTextView.textContainer?.widthTracksTextView = true
            aTextView.font = .systemFont(ofSize: 11)
            aTextView.textColor = .labelColor

            let attributedAnswer = dataSource.messageViewFactory.formatMessageContent(answer, isQuestion: false)
            aTextView.textStorage?.setAttributedString(attributedAnswer)

            aScrollView.documentView = aTextView
            aBubble.addSubview(aScrollView)
        }

        floatingWindow.contentView = container
        floatingWindow.alphaValue = 0
        floatingWindow.orderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            floatingWindow.animator().alphaValue = 1
        }

        self.window = floatingWindow

        // Add global keyboard monitor for scrolling and moving - works when app is hidden
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let floatingWindow = self.window else { return }

            // Only respond to Cmd+key combinations
            guard event.modifierFlags.contains(.command) else { return }

            let scrollAmount: CGFloat = 50
            let moveAmount: CGFloat = 30

            // ⌘+J = scroll down
            if event.keyCode == 38 {
                self.scroll(by: -scrollAmount)
            }
            // ⌘+K = scroll up
            if event.keyCode == 40 {
                self.scroll(by: scrollAmount)
            }
            // ⌘+↑ = move window up
            if event.keyCode == 126 {
                var frame = floatingWindow.frame
                frame.origin.y += moveAmount
                floatingWindow.setFrame(frame, display: true)
            }
            // ⌘+↓ = move window down
            if event.keyCode == 125 {
                var frame = floatingWindow.frame
                frame.origin.y -= moveAmount
                floatingWindow.setFrame(frame, display: true)
            }
            // ⌘+← = move window left
            if event.keyCode == 123 {
                var frame = floatingWindow.frame
                frame.origin.x -= moveAmount
                floatingWindow.setFrame(frame, display: true)
            }
            // ⌘+→ = move window right
            if event.keyCode == 124 {
                var frame = floatingWindow.frame
                frame.origin.x += moveAmount
                floatingWindow.setFrame(frame, display: true)
            }
        }
    }

    /// Dismiss the floating solution window
    func dismiss() {
        // Remove keyboard monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        guard let floatingWindow = window else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            floatingWindow.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            floatingWindow.orderOut(nil)
            self?.window = nil
            self?.textView = nil
            self?.scrollView = nil
            self?.qaContainer = nil
            self?.loadingView = nil
        })
    }

    /// Scroll the floating solution by delta
    func scroll(by delta: CGFloat) {
        guard let scrollView = scrollView,
              let clipView = scrollView.contentView as? NSClipView else { return }

        var newOrigin = clipView.bounds.origin
        newOrigin.y -= delta

        // Clamp to bounds
        let maxY = max(0, (scrollView.documentView?.frame.height ?? 0) - clipView.bounds.height)
        newOrigin.y = max(0, min(newOrigin.y, maxY))

        clipView.setBoundsOrigin(newOrigin)
    }

    /// Show loading animation
    func showLoading() {
        guard let loadingView = loadingView else { return }
        loadingView.isHidden = false
        startSpinnerAnimation()
    }

    /// Hide loading animation
    func hideLoading() {
        loadingView?.isHidden = true
        stopSpinnerAnimation()
    }

    /// Update the solution content in real-time
    func updateContent(_ content: String) {
        guard let textView = textView, let dataSource = dataSource else { return }

        DispatchQueue.main.async {
            let attributedContent = dataSource.messageViewFactory.formatMessageContent(content, isQuestion: false)
            textView.textStorage?.setAttributedString(attributedContent)
        }
    }

    /// Update the Q&A section in real-time
    func updateQA() {
        guard let floatingWindow = window,
              let container = floatingWindow.contentView as? NSVisualEffectView,
              let dataSource = dataSource else { return }

        let windowWidth = floatingWindow.frame.width
        let windowHeight = floatingWindow.frame.height
        let qaHeight: CGFloat = 270
        let loadingHeight: CGFloat = 40

        // Remove existing Q&A container if any
        qaContainer?.removeFromSuperview()
        qaContainer = nil

        // Get latest Q&A
        guard let (question, answer) = getLastQuestionAnswer() else { return }

        // Resize solution scroll view to make room for Q&A
        if let solutionScrollView = scrollView {
            let newSolutionHeight = windowHeight - 36 - qaHeight - loadingHeight
            solutionScrollView.frame = NSRect(x: 8, y: qaHeight + loadingHeight + 8, width: windowWidth - 16, height: newSolutionHeight)
        }

        // Find or create divider
        let dividerId = NSUserInterfaceItemIdentifier("floatingQADivider")
        if container.subviews.first(where: { $0.identifier == dividerId }) == nil {
            let divider = NSView(frame: NSRect(x: 12, y: qaHeight + 4, width: windowWidth - 24, height: 1))
            divider.identifier = dividerId
            divider.wantsLayer = true
            divider.layer?.backgroundColor = NSColor.separatorColor.cgColor
            container.addSubview(divider)
        }

        // Create new Q&A container
        let qaContainerView = NSView(frame: NSRect(x: 8, y: 8, width: windowWidth - 16, height: qaHeight - 12))
        qaContainerView.wantsLayer = true
        container.addSubview(qaContainerView)
        self.qaContainer = qaContainerView

        // Question bubble
        let qBubble = NSView(frame: NSRect(x: 0, y: qaHeight - 50, width: windowWidth - 40, height: 38))
        qBubble.wantsLayer = true
        qBubble.layer?.cornerRadius = 8
        qBubble.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        qaContainerView.addSubview(qBubble)

        let qLabel = NSTextField(wrappingLabelWithString: question)
        qLabel.frame = NSRect(x: 8, y: 4, width: qBubble.frame.width - 16, height: 30)
        qLabel.font = .systemFont(ofSize: 11)
        qLabel.textColor = .secondaryLabelColor
        qLabel.lineBreakMode = .byTruncatingTail
        qLabel.maximumNumberOfLines = 2
        qBubble.addSubview(qLabel)

        // Answer bubble
        let aBubble = NSView(frame: NSRect(x: 0, y: 4, width: windowWidth - 40, height: qaHeight - 58))
        aBubble.wantsLayer = true
        aBubble.layer?.cornerRadius = 8
        aBubble.layer?.backgroundColor = NSColor.applePurple.withAlphaComponent(0.15).cgColor
        qaContainerView.addSubview(aBubble)

        let aScrollView = NSScrollView(frame: NSRect(x: 4, y: 4, width: aBubble.frame.width - 8, height: aBubble.frame.height - 8))
        aScrollView.hasVerticalScroller = true
        aScrollView.hasHorizontalScroller = false
        aScrollView.autohidesScrollers = true
        aScrollView.scrollerStyle = .overlay
        aScrollView.borderType = .noBorder
        aScrollView.drawsBackground = false

        let aTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: aScrollView.contentSize.width, height: 0))
        aTextView.isEditable = false
        aTextView.isSelectable = true
        aTextView.drawsBackground = false
        aTextView.textContainerInset = NSSize(width: 2, height: 2)
        aTextView.isVerticallyResizable = true
        aTextView.textContainer?.widthTracksTextView = true
        aTextView.font = .systemFont(ofSize: 11)
        aTextView.textColor = .labelColor

        let attributedAnswer = dataSource.messageViewFactory.formatMessageContent(answer, isQuestion: false)
        aTextView.textStorage?.setAttributedString(attributedAnswer)

        aScrollView.documentView = aTextView
        aBubble.addSubview(aScrollView)
    }

    // MARK: - Private Helpers

    /// Get the last question and answer from voice messages
    private func getLastQuestionAnswer() -> (question: String, answer: String)? {
        guard let messages = dataSource?.voiceMessages else { return nil }

        // Find the last answer that's not a status message
        var lastAnswer: InterviewMessage?
        var lastQuestion: InterviewMessage?

        for message in messages.reversed() {
            if lastAnswer == nil && (message.type == .answer || message.type == .followUp) {
                lastAnswer = message
            }
            if lastAnswer != nil && message.type == .question {
                lastQuestion = message
                break
            }
        }

        guard let question = lastQuestion, let answer = lastAnswer else { return nil }

        return (question.content, answer.content)
    }

    /// Start glow pulse animation
    private func startSpinnerAnimation() {
        guard let loadingView = loadingView,
              let glowLayer = loadingView.layer?.sublayers?.first else { return }

        glowLayer.removeAllAnimations()

        let radiusPulse = CABasicAnimation(keyPath: "shadowRadius")
        radiusPulse.fromValue = 6
        radiusPulse.toValue = 15
        radiusPulse.duration = 1.2
        radiusPulse.autoreverses = true
        radiusPulse.repeatCount = .infinity
        radiusPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let opacityPulse = CABasicAnimation(keyPath: "shadowOpacity")
        opacityPulse.fromValue = 0.3
        opacityPulse.toValue = 0.7
        opacityPulse.duration = 1.2
        opacityPulse.autoreverses = true
        opacityPulse.repeatCount = .infinity
        opacityPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        glowLayer.add(radiusPulse, forKey: "radiusPulse")
        glowLayer.add(opacityPulse, forKey: "opacityPulse")
    }

    /// Stop glow pulse animation
    private func stopSpinnerAnimation() {
        guard let loadingView = loadingView,
              let glowLayer = loadingView.layer?.sublayers?.first else { return }
        glowLayer.removeAllAnimations()
    }
}
