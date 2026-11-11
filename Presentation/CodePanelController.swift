import Cocoa

/// Gives the code the interviewer asked for the full width of the window, under one line of what to
/// say. The full answer, and any question asked meanwhile, open over the code until dismissed. When the
/// main window is hidden (stealth), code falls back to the floating overlay as before.
@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    private var focusCodeInset: CGFloat { Token.Space.inset }

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
            self.showFocusAnswerOverCode(true)
        }
        panel.onRendered = { [weak self] in self?.refreshFocusCodeOrigin() }
        voiceContentView.addSubview(panel)
        focusCodePanel = panel

        let strip = CodeTalkStripView(frame: .zero)
        strip.autoresizingMask = []
        strip.isHidden = true
        strip.onToggle = { [weak self] in self?.toggleFocusAnswerOverCode() }
        voiceContentView.addSubview(strip)
        focusCodeTalkStrip = strip

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

    /// Everything takes the full width: the code when it is up, the answer and questions otherwise.
    func applyFocusColumnLayout() {
        guard focusCodePanel != nil, focusBodyScrollView != nil, focusQuestionBurstView != nil else { return }
        let fullWidth = voiceContentView.bounds.width - focusCodeInset * 2
        guard fullWidth > 0 else { return }
        for view in [focusQuestionBurstView, focusBodyScrollView] as [NSView?] {
            view?.frame.size.width = fullWidth
        }
        focusQuestionBurstTitleLabel.frame.size.width = max(0, fullWidth - Token.FocusLayout.labelIndent * 2)
        refreshFocusBodyLayout()
    }

    /// The vertical split. Code runs from under its one line down to the bar. Otherwise the question list
    /// takes the height its rows need and the answer card takes the rest, because the card is what is
    /// read. Before the first question there is no list and no label: the card runs down to the bar.
    func layoutFocusColumnHeights() {
        guard focusCodePanel != nil, focusCodeTalkStrip != nil, focusQuestionBurstView != nil, focusBodyScrollView != nil,
              focusQuestionBurstTitleLabel != nil, focusAnswerView != nil, focusBriefingView != nil else { return }
        let bottom = focusContentBottom
        let top = voiceContentView.bounds.height - Token.FocusLayout.contentTop
        let x = focusBodyScrollView.frame.minX
        let width = focusBodyScrollView.frame.width
        let layout = Token.FocusLayout.self
        let readingAnswer = !focusCodeOpen || focusAnswerOverCode
        let bodyTop = focusCodeOpen ? top - layout.talkStripHeight - layout.talkStripGap : top
        // One question is already the card's heading; the list appears once there is a choice.
        let hasStrip = readingAnswer && questionBurstState.displayedEntries.count > 1
        focusQuestionBurstView.isHidden = !hasStrip
        // The rows carry their interview-wide numbers, so they need no heading.
        focusQuestionBurstTitleLabel.isHidden = true
        focusBodyScrollView.isHidden = !readingAnswer
        focusCodeTalkStrip.isHidden = !focusCodeOpen
        focusCodeTalkStrip.frame = NSRect(x: x, y: top - layout.talkStripHeight, width: width, height: layout.talkStripHeight)

        let stripHeight: CGFloat = hasStrip ? layout.burstHeight : 0
        let bodyY = bottom + (hasStrip ? stripHeight + layout.cardToLabel : 0)
        focusQuestionBurstView.frame = NSRect(x: x, y: bottom, width: width, height: stripHeight)
        focusQuestionBurstTitleLabel.frame = NSRect(
            x: x + layout.labelIndent, y: bottom + stripHeight + layout.labelToStrip,
            width: max(0, width - layout.labelIndent * 2), height: layout.labelHeight
        )
        focusBodyScrollView.frame = NSRect(x: x, y: bodyY, width: width, height: max(layout.minimumCardHeight, bodyTop - bodyY))
        focusBodyCue?.place(insetX: Token.Radius.lg / 2)
        if focusCodeOpen {
            focusCodePanel.frame = NSRect(x: x, y: bottom, width: width, height: max(160, bodyTop - bottom))
            focusCodePanel.needsLayout = true
        }
    }

    // MARK: - Where the code came from

    /// The code names the question that asked for it, by number and words, so each version reads as
    /// the answer to something. A click goes to that question.
    func refreshFocusCodeOrigin() {
        guard focusCodePanel != nil else { return }
        guard let version = focusCodePanel.displayed, let number = questionBurstState.questionNumber(of: version.id) else {
            focusCodePanel.setOrigin(nil)
            return
        }
        let request = version.title.trimmingCharacters(in: .whitespacesAndNewlines)
        focusCodePanel.setOrigin(request.isEmpty ? "Q\(number)" : "Q\(number)\(Token.Text.separator)\(request)")
        refreshSystemHotkeys()
    }

    /// Copies the code on screen, from the global shortcut.
    func copyFocusCode() {
        guard focusCodePanel != nil, focusCodeOpen else { return }
        focusCodePanel.copyDisplayedCode()
    }

    // MARK: - Showing and hiding

    /// Feeds code into the panel. The panel opens by itself for new code unless the user closed it.
    func showCodeSolutionInPanel(_ content: String) {
        guard focusCodePanel != nil, window.isVisible else { return }
        focusCodePanel.updateLatest(markdown: content)
        if !focusCodeOpen && !focusCodePanelDismissed {
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
        // The question's row now says it has code.
        refreshInterviewFocusUI()
        if !focusCodeOpen && !focusCodePanelDismissed {
            openFocusCodePanel()
        }
        // A new task is what the candidate has to look at; a dictated refinement leaves their reading alone.
        if !info.isRefinement { showFocusAnswerOverCode(false) }
        updateFocusCodeButton()
    }

    func endFocusCodeStream(_ outcome: CodingTaskOutcome = .complete) {
        guard focusCodePanel != nil else { return }
        focusCodePanel.finishLatest(outcome)
        updateFocusCodeButton()
    }

    private func openFocusCodePanel() {
        debugLog(.delegate, "code panel opened")
        focusCodeOpen = true
        showFocusAnswerOverCode(false)
    }

    func hideFocusCodePanel(byUser: Bool) {
        guard focusCodePanel != nil else { return }
        if byUser { focusCodePanelDismissed = true }
        guard focusCodeOpen else { return }
        debugLog(.delegate, "code panel hidden (byUser=\(byUser))")
        focusCodeOpen = false
        showFocusAnswerOverCode(false)
    }

    @objc func toggleFocusCodePanel() {
        guard focusCodePanel != nil else { return }
        if !focusCodeOpen {
            focusCodePanelDismissed = false
            openFocusCodePanel()
        } else if focusAnswerOverCode {
            showFocusAnswerOverCode(false)
        } else {
            hideFocusCodePanel(byUser: true)
        }
        updateFocusCodeButton()
    }

    /// Opens the answer and question list over the code, or goes back to the code, which keeps its place.
    func showFocusAnswerOverCode(_ open: Bool) {
        guard focusCodePanel != nil else { return }
        focusAnswerOverCode = open && focusCodeOpen
        focusCodePanel.isHidden = !focusCodeOpen || focusAnswerOverCode
        refreshFocusTalkStrip()
        applyFocusColumnLayout()
        updateFocusCodeButton()
    }

    func toggleFocusAnswerOverCode() {
        showFocusAnswerOverCode(!focusAnswerOverCode)
    }

    func refreshFocusTalkStrip() {
        guard focusCodeTalkStrip != nil else { return }
        let selected = questionBurstState.selectedEntry
        let line = selected.map { firstTalkingPoint($0.answer) ?? $0.question } ?? ""
        focusCodeTalkStrip.update(line: line, answerOpen: focusAnswerOverCode)
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
        if focusCodeOpen {
            focusCodeOpen = false
            showFocusAnswerOverCode(false)
        }
        currentPinnedSolution = nil
        updateFocusCodeButton()
    }

    /// The toolbar button is always there, so the panel can be found before the first request. It is
    /// dimmed while it has nothing to show and lit while the panel is open.
    func updateFocusCodeButton() {
        refreshSystemHotkeys()
        guard let button = focusCodeButton else { return }
        let hasCode = focusCodePanel != nil && !focusCodePanel.versions.isEmpty
        let visible = focusCodeOpen && !focusAnswerOverCode
        button.alphaValue = hasCode || visible ? 1 : Token.State.idleAlpha
        button.apply(visible ? .selected(.accent) : .ghost)
        let action = visible ? "Hide code panel" : "Show code panel"
        button.toolTip = hasCode ? "\(action) (⌘3)" : "\(action) (⌘3). Code appears here when the interviewer asks for it."
        button.setAccessibilityValue(visible ? "Shown" : "Hidden")
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
