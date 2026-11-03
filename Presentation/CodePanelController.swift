import Cocoa

/// Docks the code the interviewer asked for on the right of the live answer, so answers to new
/// questions keep appearing on the left while the code stays in view. When the main window is
/// hidden (stealth), code falls back to the floating overlay as before.
@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    private var focusCodeInset: CGFloat { Token.Space.inset }
    private var focusCodeGap: CGFloat { Token.Space.md }
    /// Wide enough for an 80-column line beside a readable answer.
    private var focusCodeTargetWindowSize: NSSize { NSSize(width: 1040, height: 680) }

    func setupFocusCodePanel() {
        let panel = CodePanelView(frame: NSRect(x: 0, y: 0, width: 360, height: 300))
        panel.autoresizingMask = []
        panel.isHidden = true
        panel.onClose = { [weak self] in self?.hideFocusCodePanel(byUser: true) }
        panel.onQuickAction = { [weak self] instruction in
            self?.voiceInterviewProcessor.requestCodeChange(instruction)
        }
        panel.onRetry = { [weak self] in
            self?.voiceInterviewProcessor.retryLastCodingRequest()
        }
        panel.onOriginClick = { [weak self] in
            guard let self, let id = self.focusCodePanel.displayed?.id else { return }
            self.selectQuestionBurstEntry(id)
        }
        panel.onRendered = { [weak self] in self?.refreshFocusCodeOrigin() }
        voiceContentView.addSubview(panel)
        focusCodePanel = panel

        voiceContentView.postsFrameChangedNotifications = true
        let observer = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: voiceContentView,
            queue: .main
        ) { [weak self] _ in
            self?.applyFocusColumnLayout()
        }
        notificationObservers.append(observer)
    }

    // MARK: - Layout

    /// Two columns while code is shown: questions and answers on the left, code on the right.
    func applyFocusColumnLayout() {
        guard focusCodePanel != nil, focusBodyScrollView != nil, focusQuestionBurstView != nil else { return }
        let fullWidth = voiceContentView.bounds.width - focusCodeInset * 2
        guard fullWidth > 0 else { return }
        let codeVisible = !focusCodePanel.isHidden
        let minimumCodeWidth: CGFloat = 320
        let leftWidth: CGFloat = codeVisible
            ? max(300, min(fullWidth - focusCodeGap - minimumCodeWidth, floor((fullWidth - focusCodeGap) * 0.36)))
            : fullWidth

        for view in [focusQuestionBurstView, focusBodyScrollView] as [NSView?] {
            view?.frame.size.width = leftWidth
        }
        focusQuestionBurstTitleLabel.frame.size.width = max(0, leftWidth - Token.FocusLayout.labelIndent * 2)

        if codeVisible {
            let bottom = focusQuestionBurstView.frame.minY
            let top = focusBodyScrollView.frame.maxY
            focusCodePanel.frame = NSRect(
                x: focusCodeInset + leftWidth + focusCodeGap,
                y: bottom,
                width: fullWidth - leftWidth - focusCodeGap,
                height: max(160, top - bottom)
            )
            focusCodePanel.needsLayout = true
        }
        refreshFocusBodyLayout()
    }

    /// The vertical split of the left column. The question list takes the height its rows need (side
    /// by side while the code panel is closed, stacked one line each while it is open) and the answer
    /// card takes the rest, because the card is what is read. Before the first question there is no
    /// list and no label: the card runs down to the bar.
    func layoutFocusColumnHeights() {
        guard focusCodePanel != nil, focusQuestionBurstView != nil, focusBodyScrollView != nil,
              focusQuestionBurstTitleLabel != nil, focusAnswerView != nil, focusBriefingView != nil else { return }
        let bottom = focusContentBottom
        let top = voiceContentView.bounds.height - Token.FocusLayout.contentTop
        let x = focusBodyScrollView.frame.minX
        let width = focusBodyScrollView.frame.width
        let splitting = !focusCodePanel.isHidden
        let layout = Token.FocusLayout.self
        let entryCount = questionBurstState.displayedEntries.count
        // One question is already the card's heading; the list appears once there is a choice.
        let hasStrip = entryCount > 1
        focusQuestionBurstView.orientation = splitting ? .vertical : .horizontal
        focusQuestionBurstView.isHidden = !hasStrip
        // The rows carry their interview-wide numbers, so they need no heading.
        focusQuestionBurstTitleLabel.isHidden = true

        let stripHeight: CGFloat = !hasStrip ? 0 : (splitting ? CGFloat(entryCount) * layout.stripRowHeight : layout.burstHeight)
        let bodyY = bottom + (hasStrip ? stripHeight + layout.cardToLabel : 0)
        focusQuestionBurstView.frame = NSRect(x: x, y: bottom, width: width, height: stripHeight)
        focusQuestionBurstTitleLabel.frame = NSRect(
            x: x + layout.labelIndent, y: bottom + stripHeight + layout.labelToStrip,
            width: max(0, width - layout.labelIndent * 2), height: layout.labelHeight
        )
        focusBodyScrollView.frame = NSRect(x: x, y: bodyY, width: width, height: max(layout.minimumCardHeight, top - bodyY))
        focusBodyCue?.place(insetX: Token.Radius.lg / 2)
    }

    // MARK: - Where the code came from

    /// Code stays up while other questions are answered, so the title says which question it belongs to
    /// whenever that is not the selected one.
    func refreshFocusCodeOrigin() {
        guard focusCodePanel != nil else { return }
        let codeID = focusCodePanel.displayed?.id
        let number = codeID.flatMap { id in
            id == questionBurstState.selectedEntry?.id ? nil : questionBurstState.questionNumber(of: id)
        }
        focusCodePanel.setOrigin(number.map { "from Q\($0)" })
    }

    /// Copies the code on screen, from the global shortcut.
    func copyFocusCode() {
        guard focusCodePanel != nil, !focusCodePanel.isHidden else { return }
        focusCodePanel.copyDisplayedCode()
    }

    // MARK: - Showing and hiding

    /// Feeds code into the panel. The panel opens by itself for new code unless the user closed it.
    func showCodeSolutionInPanel(_ content: String) {
        guard focusCodePanel != nil, window.isVisible else { return }
        focusCodePanel.updateLatest(markdown: content)
        if focusCodePanel.isHidden && !focusCodePanelDismissed {
            openFocusCodePanel()
        }
        updateFocusCodeButton()
    }

    /// Code is about to stream in. A new request reopens a panel the user closed and adds a version;
    /// a dictated refinement updates the version it belongs to without reopening.
    func beginFocusCodeStream(info: CodingTaskInfo) {
        guard focusCodePanel != nil, window.isVisible else { return }
        if !info.isRefinement { focusCodePanelDismissed = false }
        focusCodePanel.beginVersion(info)
        if focusCodePanel.isHidden && !focusCodePanelDismissed {
            openFocusCodePanel()
        }
        updateFocusCodeButton()
    }

    func endFocusCodeStream(_ outcome: CodingTaskOutcome = .complete) {
        guard focusCodePanel != nil else { return }
        focusCodePanel.finishLatest(outcome)
        updateFocusCodeButton()
    }

    private func openFocusCodePanel() {
        debugLog(.delegate, "code panel opened")
        focusCodePanel.isHidden = false
        expandWindowForFocusCodePanel()
        applyFocusColumnLayout()
    }

    func hideFocusCodePanel(byUser: Bool) {
        guard focusCodePanel != nil else { return }
        if byUser { focusCodePanelDismissed = true }
        guard !focusCodePanel.isHidden else { return }
        debugLog(.delegate, "code panel hidden (byUser=\(byUser))")
        focusCodePanel.isHidden = true
        restoreWindowAfterFocusCodePanel()
        applyFocusColumnLayout()
        updateFocusCodeButton()
    }

    @objc func toggleFocusCodePanel() {
        guard focusCodePanel != nil else { return }
        if focusCodePanel.isHidden {
            focusCodePanelDismissed = false
            openFocusCodePanel()
        } else {
            hideFocusCodePanel(byUser: true)
        }
        updateFocusCodeButton()
    }

    /// Code that arrived while the window was hidden went to the floating overlay; catch the panel up.
    func syncFocusCodePanelWithPinnedSolution() {
        guard focusCodePanel != nil, focusCodePanel.versions.isEmpty, let solution = currentPinnedSolution else { return }
        showCodeSolutionInPanel(solution)
    }

    /// Forgets the previous exercise when a new interview starts or the timeline is cleared.
    func resetFocusCodePanel() {
        guard focusCodePanel != nil else { return }
        focusCodePanelDismissed = false
        focusCodePanel.clear()
        if !focusCodePanel.isHidden {
            focusCodePanel.isHidden = true
            restoreWindowAfterFocusCodePanel()
            applyFocusColumnLayout()
        }
        currentPinnedSolution = nil
        updateFocusCodeButton()
    }

    /// The toolbar button is always there, so the panel can be found before the first request. It is
    /// dimmed while it has nothing to show and lit while the panel is open.
    func updateFocusCodeButton() {
        guard let button = focusCodeButton else { return }
        let hasCode = focusCodePanel != nil && !focusCodePanel.versions.isEmpty
        let visible = focusCodePanel?.isHidden == false
        button.alphaValue = hasCode || visible ? 1 : Token.State.idleAlpha
        button.apply(visible ? .selected(.code) : .ghost)
        let action = visible ? "Hide code panel" : "Show code panel"
        button.toolTip = hasCode ? "\(action) (⌘3)" : "\(action) (⌘3). Code appears here when the interviewer asks for it."
        button.setAccessibilityValue(visible ? "Shown" : "Hidden")
    }

    // MARK: - Window size

    /// Opens up room for the second column, keeping the window's top-left corner in place. The menu
    /// item "Widen Window for Code" turns this off for people who want the window left where it is.
    private func expandWindowForFocusCodePanel() {
        guard AppSettings.shared.codePanelWidensWindow,
              focusCodeFrameBeforeExpand == nil, let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let current = window.frame
        let width = min(max(current.width, focusCodeTargetWindowSize.width), visible.width - 24)
        let height = min(max(current.height, focusCodeTargetWindowSize.height), visible.height - 24)
        guard width > current.width + 1 || height > current.height + 1 else { return }

        var frame = NSRect(x: current.minX, y: current.maxY - height, width: width, height: height)
        if frame.maxX > visible.maxX { frame.origin.x = visible.maxX - frame.width }
        if frame.minX < visible.minX { frame.origin.x = visible.minX }
        if frame.minY < visible.minY { frame.origin.y = visible.minY }
        focusCodeFrameBeforeExpand = current
        focusCodeExpandedFrame = frame
        window.setFrame(frame, display: true, animate: !Token.Motion.reducesMotion())
    }

    /// Undoes only our own resize; a window the user has resized since stays as they left it.
    func restoreWindowAfterFocusCodePanel() {
        defer {
            focusCodeFrameBeforeExpand = nil
            focusCodeExpandedFrame = nil
        }
        guard let original = focusCodeFrameBeforeExpand, let expanded = focusCodeExpandedFrame else { return }
        guard abs(window.frame.width - expanded.width) < 2, abs(window.frame.height - expanded.height) < 2 else { return }
        let restored = NSRect(x: window.frame.minX, y: window.frame.maxY - original.height, width: original.width, height: original.height)
        window.setFrame(restored, display: true, animate: !Token.Motion.reducesMotion())
    }

    // MARK: - Floating fallback

    /// Code lives in the docked panel while the main window is up. With the window hidden (stealth),
    /// it appears in the floating overlay instead.
    func presentFloatingSolutionIfNeeded(_ content: String) {
        let dockedPanelAvailable = focusCodePanel != nil && window.isVisible
        guard !dockedPanelAvailable,
              shouldPresentScreenshotAnalysisOverlay(mainWindowVisible: window.isVisible) else { return }
        if floatingSolutionController.window == nil {
            floatingSolutionController.show()
        }
        floatingSolutionController.updateContent(content)
    }
}
