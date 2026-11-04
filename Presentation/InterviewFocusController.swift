import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    /// The CV strip is a reminder: it takes at most 40% of the space it shares with the live answer,
    /// and never so much that less than the answer's minimum stays in view.
    func focusBriefingBudget(forBodyHeight height: CGFloat) -> CGFloat {
        let leavingAnswer = height - Token.FocusLayout.briefingGap - Token.FocusLayout.minimumAnswerHeight
        return max(Token.FocusLayout.briefingMinimum, min(floor(height * 0.4), leavingAnswer))
    }

    /// Where the question strip's bottom edge sits in the voice content view.
    var focusContentBottom: CGFloat {
        let barTop = Token.CommandBar.bottomMargin + Token.CommandBar.height - voiceContentView.frame.minY
        return Token.FocusLayout.contentBottom(barTop: barTop)
    }

    func setupInterviewFocusUI() {
        guard let contentView = window.contentView else { return }
        shortcutHintBar.isHidden = true
        voiceControlBar.isHidden = true
        voiceTimelineScrollView.isHidden = true

        let contentWidth = voiceContentView.bounds.width
        let contentHeight = voiceContentView.bounds.height
        let horizontalInset = Token.Space.inset
        let usableWidth = contentWidth - horizontalInset * 2

        let headerView = FocusHeaderView(frame: NSRect(
            x: horizontalInset,
            y: contentHeight - 42,
            width: usableWidth,
            height: 34
        ))
        focusHeaderView = headerView
        focusHeaderView.autoresizingMask = [.width, .minYMargin]
        voiceContentView.addSubview(focusHeaderView)

        let appIcon = NSImageView(frame: NSRect(x: 0, y: 6, width: 22, height: 22))
        let developmentIconPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("icon_1024.png").path
        appIcon.image = NSImage(named: "AppIcon")
            ?? NSImage(contentsOfFile: developmentIconPath)
            ?? NSApp.applicationIconImage
        appIcon.imageScaling = .scaleProportionallyUpOrDown
        appIcon.wantsLayer = true
        appIcon.layer?.cornerRadius = Token.Radius.sm
        appIcon.layer?.masksToBounds = true
        focusHeaderView.addSubview(appIcon)
        headerView.iconView = appIcon

        // A widget's heading: the app name in small capitals over the interview profile, so the profile
        // does not need a row of its own in the body. It gives way to the status capsule and truncates.
        let titleWidth = usableWidth - Token.Header.titleX - Token.Space.inset - Token.Header.capsuleWidth
        focusHeaderOverlineLabel = NSTextField(labelWithString: "")
        focusHeaderOverlineLabel.frame = NSRect(x: Token.Header.titleX, y: 19, width: titleWidth, height: 14)
        focusHeaderOverlineLabel.autoresizingMask = [.width]
        focusHeaderOverlineLabel.attributedStringValue = Token.Text.overline(Self.focusAppName, color: Token.Hue.accent.text)
        // The icon already names the app; the profile is the header's only line.
        focusHeaderOverlineLabel.isHidden = true
        focusHeaderView.addSubview(focusHeaderOverlineLabel)
        headerView.overlineLabel = focusHeaderOverlineLabel

        focusHeaderTitleLabel = NSTextField(labelWithString: "Interview Master")
        focusHeaderTitleLabel.frame = NSRect(x: Token.Header.titleX, y: 8, width: titleWidth, height: 18)
        focusHeaderTitleLabel.autoresizingMask = [.width]
        focusHeaderTitleLabel.font = Token.Font.digits(.body, .semibold)
        focusHeaderTitleLabel.textColor = Token.Color.textPrimary
        focusHeaderTitleLabel.lineBreakMode = .byTruncatingTail
        focusHeaderView.addSubview(focusHeaderTitleLabel)
        headerView.titleLabel = focusHeaderTitleLabel

        // Feedback takes the title's place: same row, so nothing else moves when it comes and goes.
        focusNoticeView = FocusNoticeView(frame: NSRect(x: Token.Header.titleX, y: 0, width: titleWidth, height: 34))
        focusNoticeView.onAction = { [weak self] in self?.runFocusNoticeAction() }
        focusNoticeView.onDismiss = { [weak self] in self?.dismissFocusNotice() }
        focusHeaderView.addSubview(focusNoticeView)
        headerView.noticeView = focusNoticeView

        focusAIActivityCapsule = AIActivityCapsuleView(
            frame: NSRect(x: usableWidth - Token.Header.capsuleWidth, y: 0, width: Token.Header.capsuleWidth, height: 34)
        )
        focusAIActivityCapsule.autoresizingMask = [.minXMargin]
        focusHeaderView.addSubview(focusAIActivityCapsule)
        headerView.trailingView = focusAIActivityCapsule

        focusQuestionBurstTitleLabel = NSTextField(labelWithString: "")
        // The question strip sits at the bottom, just above the profile line and command bar.
        let burstY = focusContentBottom
        let burstHeight = Token.FocusLayout.burstHeight
        let labelIndent = Token.FocusLayout.labelIndent
        focusQuestionBurstTitleLabel.frame = NSRect(
            x: horizontalInset + labelIndent,
            y: burstY + burstHeight + Token.FocusLayout.labelToStrip,
            width: usableWidth - labelIndent * 2,
            height: Token.FocusLayout.labelHeight
        )
        focusQuestionBurstTitleLabel.autoresizingMask = [.width, .maxYMargin]
        focusQuestionBurstTitleLabel.attributedStringValue = Token.Text.overline("Questions", color: Token.Color.textBody)
        voiceContentView.addSubview(focusQuestionBurstTitleLabel)

        focusQuestionBurstView = QuestionBurstStripView(frame: NSRect(
            x: horizontalInset,
            y: burstY,
            width: usableWidth,
            height: burstHeight
        ))
        focusQuestionBurstView.autoresizingMask = [.width, .maxYMargin]
        focusQuestionBurstView.onSelect = { [weak self] id in
            self?.selectQuestionBurstEntry(id)
        }
        voiceContentView.addSubview(focusQuestionBurstView)

        let answerY = burstY + burstHeight + Token.FocusLayout.labelBlock
        let answerTop = contentHeight - Token.FocusLayout.contentTop
        let bodyHeight = max(160, answerTop - answerY)
        focusBodyScrollView = NSScrollView(frame: NSRect(
            x: horizontalInset,
            y: answerY,
            width: usableWidth,
            height: bodyHeight
        ))
        focusBodyScrollView.autoresizingMask = [.width, .height]
        focusBodyScrollView.hasVerticalScroller = true
        focusBodyScrollView.autohidesScrollers = true
        focusBodyScrollView.borderType = .noBorder
        focusBodyScrollView.drawsBackground = false
        focusBodyScrollView.backgroundColor = .clear
        voiceContentView.addSubview(focusBodyScrollView)

        focusBodyContainer = FlippedView(frame: NSRect(x: 0, y: 0, width: usableWidth, height: bodyHeight))
        focusBodyContainer.autoresizingMask = [.width]
        focusBodyScrollView.documentView = focusBodyContainer
        focusBodyCue = OverflowCueView(watching: focusBodyScrollView)
        voiceContentView.addSubview(focusBodyCue, positioned: .above, relativeTo: focusBodyScrollView)

        focusBriefingView = InterviewBriefingView(frame: NSRect(x: 0, y: 0, width: usableWidth, height: 0))
        focusBriefingView.autoresizingMask = [.width]
        focusBriefingView.isHidden = true
        focusBodyContainer.addSubview(focusBriefingView)

        focusAnswerView = FocusAnswerView(frame: NSRect(
            x: 0,
            y: 0,
            width: usableWidth,
            height: max(130, bodyHeight)
        ))
        focusAnswerView.autoresizingMask = [.width]
        focusAnswerView.onRetry = { [weak self] id in self?.retryFocusAnswer(turnID: id) }
        focusBodyContainer.addSubview(focusAnswerView)
        refreshFocusBodyLayout()

        setupFocusCodePanel()

        focusCommandBar = NSView(frame: NSRect(
            x: Token.CommandBar.sideMargin,
            y: Token.CommandBar.bottomMargin,
            width: contentView.bounds.width - Token.CommandBar.sideMargin * 2,
            height: Token.CommandBar.height
        ))
        focusCommandBar.autoresizingMask = [.width]
        focusCommandBar.applySurface(.commandBar)
        contentView.addSubview(focusCommandBar, positioned: .above, relativeTo: nil)

        setupInterviewFocusCommandBar()
        updateInterviewFocusNavigation(contextSelected: false)
        observeReduceTransparency()
        applySurfaceTransparency()
        refreshInterviewFocusUI()
    }

    // MARK: - Transparency

    /// Sets how much of the desktop shows through. The system's Reduce Transparency beats the setting:
    /// the surfaces go solid and the blur gives way to a plain window.
    func applySurfaceTransparency() {
        let reduced = updateTransparencyLevel()
        visualEffectView?.isHidden = reduced
        applyBackgroundTransparency()
        window.backgroundColor = reduced ? Token.Color.bgSolidWindow : .clear
        focusHeaderView?.applySurface(Token.Transparency.floating ? .floatingText : Token.SurfaceStyle(radius: 0))
        focusCodeTalkStrip?.applySurface(Token.Transparency.floating ? .floatingText : Token.SurfaceStyle(radius: 0))
        focusAnswerView?.applyTransparency()
        focusCodePanel?.applyTransparency()
        focusBriefingView?.applySurface(.briefing)
        focusQuestionBurstView?.applySurface(.strip)
        focusCommandBar?.applySurface(.commandBar)
        focusBodyCue?.refreshColors()
        refreshInterviewFocusUI()
    }

    /// The background slider moves only the blur and the tint behind the content. Text, code and controls
    /// are above them and keep their full strength.
    func applyBackgroundTransparency() {
        let transparency = AppSettings.shared.backgroundTransparency
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        visualEffectView?.alphaValue = Token.Transparency.blurAlpha(transparency: transparency)
        visualEffectView?.subviews.first?.layer?.backgroundColor = Token.Color
            .bgGlassFloor(alpha: Token.Transparency.tintAlpha(transparency: transparency)).cgColor
        CATransaction.commit()
    }

    /// Returns true when the system's Reduce Transparency is what decided the level.
    @discardableResult
    func updateTransparencyLevel() -> Bool {
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        Token.Transparency.level = reduced ? .solid : .balanced
        return reduced
    }

    private func observeReduceTransparency() {
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applySurfaceTransparency()
        }
        notificationObservers.append(observer)
    }

    static let focusAppName = "Interview Master"

    private func setupInterviewFocusCommandBar() {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = Token.CommandBar.itemGap
        stack.edgeInsets = Token.CommandBar.padding
        focusCommandBar.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: focusCommandBar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: focusCommandBar.trailingAnchor),
            stack.topAnchor.constraint(equalTo: focusCommandBar.topAnchor),
            stack.bottomAnchor.constraint(equalTo: focusCommandBar.bottomAnchor)
        ])

        focusContextButton = makeFocusCommandButton(
            title: "Context",
            symbol: "doc.text",
            width: Token.Sizing.control,
            compact: true,
            shortcut: "⌘1",
            action: #selector(switchToNotesTab)
        )
        stack.addArrangedSubview(focusContextButton)

        focusTimelineButton = makeFocusCommandButton(
            title: "Timeline",
            symbol: "clock",
            width: Token.Sizing.control,
            compact: true,
            style: .ghostSelected,
            shortcut: "⌘2",
            action: #selector(switchToVoiceTab)
        )
        stack.addArrangedSubview(focusTimelineButton)

        focusPracticeButton = makeFocusCommandButton(
            title: "Practice",
            symbol: "graduationcap",
            width: Token.Sizing.control,
            compact: true,
            shortcut: "⌘4",
            action: #selector(switchToPracticeTab)
        )
        stack.addArrangedSubview(focusPracticeButton)

        focusCodeButton = makeFocusCommandButton(
            title: "Code",
            symbol: "chevron.left.forwardslash.chevron.right",
            width: Token.Sizing.control,
            compact: true,
            action: #selector(toggleFocusCodePanel)
        )
        stack.addArrangedSubview(focusCodeButton)

        focusInterviewButton = makeFocusCommandButton(
            title: "Start interview",
            symbol: "play.fill",
            width: Token.Sizing.control,
            compact: true,
            style: .primary(.success),
            action: #selector(toggleInterview)
        )
        stack.addArrangedSubview(focusInterviewButton)

        let systemAudioButton = makeFocusCommandButton(
            title: "System audio — remote interviewer",
            symbol: "speaker.wave.2",
            width: Token.Sizing.control,
            compact: true,
            action: #selector(selectSystemAudioSource)
        )
        audioSystemButton = systemAudioButton
        stack.addArrangedSubview(systemAudioButton)

        let microphoneButton = makeFocusCommandButton(
            title: "Microphone — interviewer in the room (sensitivity calibration pending)",
            symbol: "mic",
            width: Token.Sizing.control,
            compact: true,
            action: #selector(selectMicrophoneSource)
        )
        audioMicrophoneButton = microphoneButton
        stack.addArrangedSubview(microphoneButton)

        let muteButton = makeFocusCommandButton(
            title: "Audio starts with the interview",
            symbol: "waveform.slash",
            width: Token.Sizing.control,
            compact: true,
            action: #selector(toggleAudioMute)
        )
        audioMuteButton = muteButton
        stack.addArrangedSubview(muteButton)

        focusCommandAIActivityCapsule = AIActivityCapsuleView(
            frame: NSRect(x: 0, y: 0, width: Token.CommandBar.capsuleWidth, height: Token.Sizing.control),
            compact: true
        )
        focusCommandAIActivityCapsule.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            focusCommandAIActivityCapsule.widthAnchor.constraint(equalToConstant: Token.CommandBar.capsuleWidth),
            focusCommandAIActivityCapsule.heightAnchor.constraint(equalToConstant: Token.Sizing.control)
        ])
        stack.addArrangedSubview(focusCommandAIActivityCapsule)
        updateFocusBarActivityVisibility()

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
        stack.addArrangedSubview(spacer)

        let exportButton = makeFocusCommandButton(
            title: "Export interview",
            symbol: "square.and.arrow.up",
            width: Token.Sizing.control,
            compact: true,
            action: #selector(exportInterview)
        )
        stack.addArrangedSubview(exportButton)

        let settingsButton = makeFocusCommandButton(
            title: "Settings",
            symbol: "gearshape",
            width: Token.Sizing.control,
            compact: true,
            shortcut: "⌘,",
            action: #selector(showSettings)
        )
        stack.addArrangedSubview(settingsButton)

        // Navigation, the interview button and the audio controls are three groups: twice the gap apart.
        stack.setCustomSpacing(Token.CommandBar.groupGap, after: focusCodeButton)
        stack.setCustomSpacing(Token.CommandBar.groupGap, after: focusInterviewButton)
    }

    private func makeFocusCommandButton(
        title: String,
        symbol: String,
        width: CGFloat,
        compact: Bool = false,
        style: Token.ControlStyle = .ghost,
        shortcut: String? = nil,
        action: Selector
    ) -> HoverButton {
        let button = HoverButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = title
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = compact ? .imageOnly : .imageLeading
        button.imageHugsTitle = true
        button.symbolConfiguration = Token.Font.symbol(.caption)
        button.font = Token.Font.text(.caption, .semibold)
        button.isBordered = false
        button.target = self
        button.action = action
        button.wantsLayer = true
        button.layer?.cornerRadius = Token.Radius.full(Token.Sizing.control)
        button.layer?.cornerCurve = .continuous
        button.apply(style)
        button.setAccessibilityLabel(title)
        button.setAccessibilityRole(.button)
        button.toolTip = shortcut.map { "\(title) (\($0))" } ?? title
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: width),
            button.heightAnchor.constraint(equalToConstant: Token.Sizing.control)
        ])
        return button
    }

    func updateInterviewFocusNavigation(contextSelected: Bool) {
        guard focusContextButton != nil, focusTimelineButton != nil else { return }
        configureFocusNavigationButton(focusContextButton, selected: contextSelected)
        configureFocusNavigationButton(focusTimelineButton, selected: !contextSelected)
        if focusPracticeButton != nil {
            configureFocusNavigationButton(focusPracticeButton, selected: false)
        }
        updateFocusNavigationVisibility()
    }

    /// Context, Timeline and Practice are for before and after the call. While an interview runs on the
    /// live view the bar keeps only what the call needs; from another tab they stay, as the way back.
    func updateFocusNavigationVisibility() {
        let inCall = isInterviewActive && currentTab == .voice
        for button in [focusContextButton, focusTimelineButton, focusPracticeButton] as [HoverButton?] {
            button?.isHidden = inCall
        }
    }

    private func configureFocusNavigationButton(_ button: HoverButton, selected: Bool) {
        button.apply(selected ? .ghostSelected : .ghost)
    }

    // MARK: - Transcribing

    /// Speech has ended and is on its way to text. The capsule says so once that has taken a moment, so a
    /// transcript that comes back at once shows nothing and a slow one is not mistaken for silence.
    func beginFocusTranscription(turnID: UUID) {
        focusTranscription.begin(turnID, at: Date())
        scheduleFocusTranscriptionRefresh()
    }

    func endFocusTranscription(turnID: UUID) {
        guard !focusTranscription.isEmpty else { return }
        focusTranscription.end(turnID)
        scheduleFocusTranscriptionRefresh()
        refreshFocusActivityCapsules()
    }

    func resetFocusTranscription() {
        focusTranscription.removeAll()
        focusTranscriptionRefresh?.cancel()
        focusTranscriptionRefresh = nil
    }

    private func scheduleFocusTranscriptionRefresh() {
        focusTranscriptionRefresh?.cancel()
        focusTranscriptionRefresh = nil
        guard let next = focusTranscription.nextChange(after: Date()) else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.refreshFocusActivityCapsules()
            self.scheduleFocusTranscriptionRefresh()
        }
        focusTranscriptionRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.01, next.timeIntervalSinceNow), execute: work)
    }

    func beginFocusAIWork(turnID: UUID) {
        // Once the words are text the AI has the turn.
        endFocusTranscription(turnID: turnID)
        questionBurstState.beginAIWork(turnID: turnID)
        focusAnswerReadyVisible = false
        focusReadyResetWorkItem?.cancel()
        refreshInterviewFocusUI()
        NSAccessibility.post(element: focusAIActivityCapsule as Any, notification: .valueChanged)
    }

    func endFocusAIWork(turnID: UUID) {
        questionBurstState.endAIWork(turnID: turnID)
        refreshInterviewFocusUI()
    }

    func endAllFocusAIWork() {
        questionBurstState.endAllAIWork()
        refreshInterviewFocusUI()
    }

    func receiveFocusQuestion(turnID: UUID, sequence: Int, text: String, topic: String) {
        questionBurstState.receiveQuestion(turnID: turnID, sequence: sequence, text: text, topic: topic)
        refreshInterviewFocusUI()
        // A question asked during a coding task opens over the code and stays until it is dismissed.
        if focusCodeOpen, topic != "coding" { showFocusAnswerOverCode(true) }
        NSAccessibility.post(element: focusQuestionBurstView as Any, notification: .valueChanged)
    }

    func startFocusAnswer(turnID: UUID) {
        questionBurstState.startStreaming(turnID: turnID)
        refreshInterviewFocusUI()
    }

    func updateFocusAnswer(turnID: UUID, content: String) {
        questionBurstState.updateAnswer(turnID: turnID, content: content)
        refreshInterviewFocusUI()
    }

    func finishFocusAnswer(turnID: UUID, content: String, latencyMs: Int?) {
        questionBurstState.finishAnswer(turnID: turnID, content: content, latencyMs: latencyMs)
        focusAnswerReadyVisible = true
        focusReadyResetWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.focusAnswerReadyVisible = false
            self.refreshInterviewFocusUI()
        }
        focusReadyResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Token.Motion.readyHold, execute: workItem)
        refreshInterviewFocusUI()
        NSAccessibility.post(element: focusAnswerView as Any, notification: .valueChanged)
    }

    func failFocusTurn(turnID: UUID, reason: String? = nil) {
        questionBurstState.fail(turnID: turnID, reason: reason)
        refreshInterviewFocusUI()
    }

    /// Asks for a failed answer again, on the same card. Only while an interview is running: a stopped one
    /// has let go of its clients.
    func retryFocusAnswer(turnID: UUID) {
        guard isInterviewActive,
              let entry = questionBurstState.entries.first(where: { $0.id == turnID }), entry.phase == .failed else { return }
        questionBurstState.restart(turnID: turnID)
        refreshInterviewFocusUI()
        voiceInterviewProcessor.retryAnswer(turnID: turnID, question: entry.question, topic: entry.topic, sequence: entry.sequence)
    }

    func selectQuestionBurstEntry(_ id: UUID) {
        questionBurstState.select(id)
        // A card that produced code brings that version of the code back.
        focusCodePanel?.selectVersion(id: id)
        refreshInterviewFocusUI()
    }

    /// Moves to the question above or below in the list, from the global shortcut.
    func moveQuestionSelection(newer: Bool) {
        guard let id = questionBurstState.neighbourOfSelection(newer: newer) else { return }
        selectQuestionBurstEntry(id)
    }

    func resetInterviewFocusUI() {
        resetFocusTranscription()
        focusReadyResetWorkItem?.cancel()
        focusReadyResetWorkItem = nil
        focusAnswerReadyVisible = false
        questionBurstState.clear()
        focusBriefingView?.update(nil)
        resetFocusCodePanel()
        refreshInterviewFocusUI()
    }

    func refreshInterviewFocusUI() {
        guard focusQuestionBurstView != nil else { return }

        let visibleEntries = questionBurstState.displayedEntries
        let selected = questionBurstState.selectedEntry
        let askedCount = questionBurstState.entries.count
        let numbers = Dictionary(uniqueKeysWithValues: visibleEntries.compactMap { entry in
            questionBurstState.questionNumber(of: entry.id).map { (entry.id, $0) }
        })
        focusQuestionBurstView.update(entries: visibleEntries, selectedID: selected?.id, numbers: numbers)
        focusQuestionBurstView.toolTip = askedCount > visibleEntries.count
            ? "\(askedCount) questions. ⌘⌥↑ and ⌘⌥↓ move between them."
            : nil

        if let selected,
           let position = questionBurstState.questionNumber(of: selected.id) {
            let attributed: NSAttributedString?
            if selected.answer.isEmpty {
                attributed = nil
            } else {
                attributed = focusAttributedAnswer(selected.answer)
            }
            focusAnswerView.update(
                entry: selected,
                position: position,
                total: askedCount,
                attributedAnswer: attributed,
                streaming: selected.phase == .answering && questionBurstState.activeAIWork.contains(selected.id),
                canRetry: isInterviewActive,
                listShowsPhase: visibleEntries.count > 1 && selected.phase.showsPill && focusQuestionBurstView.showsPhaseWords
            )
        } else {
            focusAnswerView.showWelcome()
        }
        refreshFocusCodeOrigin()
        refreshFocusTalkStrip()
        focusCodePanel?.isLive = isInterviewActive
        updateFocusNavigationVisibility()

        let profile = AppSettings.shared
        var profileParts = [profile.role.displayName, profile.programmingLanguage.displayName, profile.responseLanguage.displayName]
        if ResumeStore.shared.hasResume {
            profileParts.append("CV")
        }
        let shotStatus = liveScreenshotStatusText(count: screenshots.count)
        if !shotStatus.isEmpty {
            profileParts.append(shotStatus)
        }
        let profileLine = profileParts.joined(separator: Token.Text.separator)
        let headerTitle = NSAttributedString(
            string: profileLine,
            attributes: [.font: Token.Font.digits(.body, .semibold), .foregroundColor: Token.Color.textPrimary]
        )
        focusHeaderTitleLabel.attributedStringValue = headerTitle
        focusHeaderTitleLabel.toolTip = Self.focusAppName + Token.Text.separator + profileLine
        focusHeaderView.needsLayout = true

        refreshFocusActivityCapsules()
        updateFocusInterviewButton()
        syncAudioSourceUI()
        refreshFocusBodyLayout()
    }

    /// Lays out the CV strip and the answer under it. Content that arrives above other content moves it, so
    /// when `animated` the answer arrives at its new place from the old one instead of jumping there, and a
    /// strip that appears (`revealing`) slides in from above with a fade. The frames are final at once; only
    /// what is drawn moves. Reduce Motion gets the end state and nothing else.
    func refreshFocusBodyLayout(animated: Bool = false, revealing: NSView? = nil) {
        guard focusBodyContainer != nil, focusBriefingView != nil, focusAnswerView != nil else { return }
        layoutFocusColumnHeights()
        let width = focusBodyScrollView.bounds.width
        let briefingHeight = focusBriefingView.isHidden ? 0 : focusBriefingView.preferredHeight(forWidth: width, budget: focusBriefingBudget(forBodyHeight: focusBodyScrollView.bounds.height))
        let spacing: CGFloat = briefingHeight > 0 ? Token.FocusLayout.briefingGap : 0
        let available = max(Token.FocusLayout.minimumAnswerHeight, focusBodyScrollView.bounds.height - briefingHeight - spacing)
        let previousAnswerTop = focusAnswerView.frame.minY
        focusBriefingView.frame = NSRect(x: 0, y: 0, width: width, height: briefingHeight)
        focusAnswerView.frame = NSRect(x: 0, y: briefingHeight + spacing, width: width, height: available)
        if animated, window?.isVisible == true, !Token.Motion.reducesMotion() {
            arrive(focusAnswerView, from: previousAnswerTop)
            if let strip = revealing {
                arrive(strip, from: -(briefingHeight + spacing))
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = 0
                fade.toValue = 1
                fade.duration = Token.Motion.fadeIn
                strip.layer?.add(fade, forKey: "fadeIn")
            }
        }
        let contentHeight = focusAnswerView.frame.maxY + 8
        focusBodyContainer.frame.size = NSSize(width: width, height: max(contentHeight, focusBodyScrollView.bounds.height))
    }

    /// The view has just been moved to its final place; draw it arriving from `oldTop` over a moment.
    private func arrive(_ view: NSView, from oldTop: CGFloat) {
        guard let layer = view.layer else { return }
        let offset = oldTop - view.frame.minY
        guard abs(offset) > 0.5 else { return }
        let move = CABasicAnimation(keyPath: "transform.translation.y")
        move.fromValue = offset
        move.toValue = 0
        move.duration = Token.Motion.fadeIn
        move.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(move, forKey: "arrive")
    }

    func updateFocusSpeaking(_ speaking: Bool) {
        guard focusIsSpeaking != speaking else { return }
        focusIsSpeaking = speaking
        syncAudioSourceUI()
        guard !questionBurstState.isAIWorking else { return }
        refreshFocusActivityCapsules()
    }

    func updateFocusElapsedTime() {
        refreshFocusActivityCapsules()
    }

    private func updateFocusInterviewButton() {
        guard focusInterviewButton != nil else { return }
        let recording = isInterviewActive
        let hue: Token.Hue = recording ? .danger : .success
        let label = recording ? "End interview" : "Start interview"
        focusInterviewButton.image = NSImage(
            systemSymbolName: recording ? "stop.fill" : "play.fill",
            accessibilityDescription: label
        )
        focusInterviewButton.apply(.primary(hue))
        focusInterviewButton.toolTip = label
        focusInterviewButton.setAccessibilityLabel(label)
    }

    private func focusElapsedText() -> String {
        guard isInterviewActive, let start = recordingStartTime else { return "" }
        let elapsed = max(0, Int(Date().timeIntervalSince(start)))
        return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    /// The header shows the activity status on the live view. The bar carries the same status to the
    /// tabs whose header is out of sight, and stays out of the way where it would say it twice.
    func updateFocusBarActivityVisibility() {
        focusCommandAIActivityCapsule?.isHidden = currentTab == .voice
    }

    func refreshFocusActivityCapsules() {
        guard focusAIActivityCapsule != nil, focusCommandAIActivityCapsule != nil else { return }
        let activityMode = currentFocusActivityMode()
        focusAIActivityCapsule.update(
            mode: activityMode,
            isRecording: audioCaptureCoordinator.activeDevice != nil && !isSelfSpeechMuted,
            elapsed: focusElapsedText()
        )

        let commandMode: AIActivityCapsuleView.Mode = questionBurstState.isAIWorking
            ? .working(questionNumber: nil)
            : activityMode
        focusCommandAIActivityCapsule.update(mode: commandMode, isRecording: false, elapsed: "")
    }

    private func currentFocusActivityMode() -> AIActivityCapsuleView.Mode {
        if questionBurstState.isAIWorking {
            return .working(questionNumber: questionBurstState.questionNumber(of: questionBurstState.latestActiveWorkID))
        }
        if focusTranscription.isShowing(at: Date()) {
            return .transcribing
        }
        // Audio that is still starting is not ready to hear anyone, whatever an old answer says.
        if audioCapturePresentation == .switching {
            return .connecting
        }
        if focusAnswerReadyVisible {
            return .ready
        }
        switch audioCapturePresentation {
        case .listening:
            return .listening(speaking: false)
        case .speaking:
            return .listening(speaking: true)
        case .muted:
            return .muted
        case .unavailable:
            return .unavailable
        case .idle, .switching:
            return .idle
        }
    }

    private func focusAttributedAnswer(_ answer: String) -> NSAttributedString {
        let formatted = NSMutableAttributedString(
            attributedString: messageViewFactory.formatMessageContent(answer, isQuestion: false)
        )
        formatted.mutableString.replaceOccurrences(
            of: "▸",
            with: "•",
            options: [],
            range: NSRange(location: 0, length: formatted.length)
        )
        let rendered = formatted.string as NSString
        var searchRange = NSRange(location: 0, length: rendered.length)
        while searchRange.length > 0 {
            let bulletRange = rendered.range(of: "•", options: [], range: searchRange)
            if bulletRange.location == NSNotFound { break }
            formatted.addAttribute(
                .foregroundColor,
                value: Token.Color.textStrong,
                range: bulletRange
            )
            let nextLocation = NSMaxRange(bulletRange)
            searchRange = NSRange(location: nextLocation, length: rendered.length - nextLocation)
        }

        // Answers are read in lines: 1.5 leading, a little air between bullets, and a bullet that
        // wraps hangs so its second line starts under the words.
        let font = Token.Font.text(.lead)
        let plain = Token.Text.paragraph(for: font, leading: Token.Leading.reading, spacingAfter: Token.Space.xs)
        let hanging = Token.Text.paragraph(
            for: font, leading: Token.Leading.reading, hangingIndent: Token.Text.bulletIndent(for: font), spacingAfter: Token.Space.xs
        )
        rendered.enumerateSubstrings(in: NSRange(location: 0, length: rendered.length), options: .byParagraphs) { text, _, enclosing, _ in
            formatted.addAttribute(.paragraphStyle, value: text?.hasPrefix("•") == true ? hanging : plain, range: enclosing)
        }
        return formatted
    }
}
