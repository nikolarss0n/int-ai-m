import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    func setupInterviewFocusUI() {
        guard let contentView = window.contentView else { return }
        shortcutHintBar.isHidden = true
        voiceControlBar.isHidden = true
        voiceTimelineScrollView.isHidden = true

        let contentWidth = voiceContentView.bounds.width
        let contentHeight = voiceContentView.bounds.height
        let horizontalInset: CGFloat = 16
        let usableWidth = contentWidth - horizontalInset * 2

        focusHeaderView = NSView(frame: NSRect(
            x: horizontalInset,
            y: contentHeight - 42,
            width: usableWidth,
            height: 34
        ))
        focusHeaderView.autoresizingMask = [.width, .minYMargin]
        voiceContentView.addSubview(focusHeaderView)

        let appIcon = NSImageView(frame: NSRect(x: 0, y: 3, width: 28, height: 28))
        let developmentIconPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("icon_1024.png").path
        appIcon.image = NSImage(named: "AppIcon")
            ?? NSImage(contentsOfFile: developmentIconPath)
            ?? NSApp.applicationIconImage
        appIcon.imageScaling = .scaleProportionallyUpOrDown
        appIcon.wantsLayer = true
        appIcon.layer?.cornerRadius = 7
        appIcon.layer?.masksToBounds = true
        focusHeaderView.addSubview(appIcon)

        let appTitle = NSTextField(labelWithString: "Interview Master")
        appTitle.frame = NSRect(x: 38, y: 7, width: 190, height: 22)
        appTitle.font = .systemFont(ofSize: 17, weight: .semibold)
        appTitle.textColor = .white
        focusHeaderView.addSubview(appTitle)

        focusAIActivityCapsule = AIActivityCapsuleView(
            frame: NSRect(x: usableWidth - 260, y: 0, width: 260, height: 34)
        )
        focusAIActivityCapsule.autoresizingMask = [.minXMargin]
        focusHeaderView.addSubview(focusAIActivityCapsule)

        focusQuestionBurstTitleLabel = NSTextField(labelWithString: "QUESTION BURST")
        focusQuestionBurstTitleLabel.frame = NSRect(
            x: horizontalInset,
            y: contentHeight - 66,
            width: usableWidth,
            height: 14
        )
        focusQuestionBurstTitleLabel.autoresizingMask = [.width, .minYMargin]
        focusQuestionBurstTitleLabel.font = .systemFont(ofSize: 9.5, weight: .bold)
        focusQuestionBurstTitleLabel.textColor = NSColor.white.withAlphaComponent(0.72)
        focusQuestionBurstTitleLabel.stringValue = "QUESTION BURST"
        voiceContentView.addSubview(focusQuestionBurstTitleLabel)

        focusQuestionBurstView = QuestionBurstStripView(frame: NSRect(
            x: horizontalInset,
            y: contentHeight - 146,
            width: usableWidth,
            height: 74
        ))
        focusQuestionBurstView.autoresizingMask = [.width, .minYMargin]
        focusQuestionBurstView.onSelect = { [weak self] id in
            self?.selectQuestionBurstEntry(id)
        }
        voiceContentView.addSubview(focusQuestionBurstView)

        let answerY: CGFloat = 88
        let answerTop = contentHeight - 154
        focusAnswerView = FocusAnswerView(frame: NSRect(
            x: horizontalInset,
            y: answerY,
            width: usableWidth,
            height: max(130, answerTop - answerY)
        ))
        focusAnswerView.autoresizingMask = [.width, .height]
        voiceContentView.addSubview(focusAnswerView)

        focusProfileLabel = NSTextField(labelWithString: "")
        focusProfileLabel.frame = NSRect(x: horizontalInset + 4, y: 62, width: usableWidth - 8, height: 18)
        focusProfileLabel.autoresizingMask = [.width]
        focusProfileLabel.font = .systemFont(ofSize: 11, weight: .medium)
        focusProfileLabel.textColor = NSColor.white.withAlphaComponent(0.68)
        focusProfileLabel.lineBreakMode = .byTruncatingTail
        voiceContentView.addSubview(focusProfileLabel)

        focusCommandBar = NSVisualEffectView(frame: NSRect(
            x: 28,
            y: 14,
            width: contentView.bounds.width - 56,
            height: 52
        ))
        focusCommandBar.autoresizingMask = [.width]
        focusCommandBar.material = .hudWindow
        focusCommandBar.blendingMode = .withinWindow
        focusCommandBar.state = .active
        focusCommandBar.wantsLayer = true
        focusCommandBar.layer?.cornerRadius = 26
        focusCommandBar.layer?.cornerCurve = .continuous
        focusCommandBar.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.28).cgColor
        focusCommandBar.layer?.borderWidth = 1
        focusCommandBar.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        focusCommandBar.layer?.shadowColor = NSColor.black.cgColor
        focusCommandBar.layer?.shadowOpacity = 0.20
        focusCommandBar.layer?.shadowRadius = 14
        focusCommandBar.layer?.shadowOffset = CGSize(width: 0, height: 4)
        contentView.addSubview(focusCommandBar, positioned: .above, relativeTo: nil)

        setupInterviewFocusCommandBar()
        updateInterviewFocusNavigation(contextSelected: false)
        refreshInterviewFocusUI()
    }

    private func setupInterviewFocusCommandBar() {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
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
            width: 82,
            action: #selector(switchToNotesTab)
        )
        stack.addArrangedSubview(focusContextButton)

        focusTimelineButton = makeFocusCommandButton(
            title: "Timeline",
            symbol: "clock",
            width: 86,
            selected: true,
            action: #selector(switchToVoiceTab)
        )
        stack.addArrangedSubview(focusTimelineButton)

        focusInterviewButton = makeFocusCommandButton(
            title: "Start interview",
            symbol: "play.fill",
            width: 118,
            accent: .appleGreen,
            emphasized: true,
            action: #selector(toggleInterview)
        )
        stack.addArrangedSubview(focusInterviewButton)

        focusCommandAIActivityCapsule = AIActivityCapsuleView(
            frame: NSRect(x: 0, y: 0, width: 122, height: 32),
            compact: true
        )
        focusCommandAIActivityCapsule.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            focusCommandAIActivityCapsule.widthAnchor.constraint(equalToConstant: 122),
            focusCommandAIActivityCapsule.heightAnchor.constraint(equalToConstant: 32)
        ])
        stack.addArrangedSubview(focusCommandAIActivityCapsule)

        let exportButton = makeFocusCommandButton(
            title: "Export",
            symbol: "square.and.arrow.up",
            width: 72,
            action: #selector(exportInterview)
        )
        stack.addArrangedSubview(exportButton)

        let settingsButton = makeFocusCommandButton(
            title: "Settings",
            symbol: "gearshape",
            width: 78,
            action: #selector(showSettings)
        )
        stack.addArrangedSubview(settingsButton)
    }

    private func makeFocusCommandButton(
        title: String,
        symbol: String,
        width: CGFloat,
        selected: Bool = false,
        accent: NSColor = .white,
        emphasized: Bool = false,
        action: Selector
    ) -> HoverButton {
        let button = HoverButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = title
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        button.font = .systemFont(ofSize: 11, weight: .semibold)
        button.contentTintColor = accent.withAlphaComponent(selected ? 1.0 : 0.86)
        button.isBordered = false
        button.target = self
        button.action = action
        button.wantsLayer = true
        button.layer?.cornerRadius = 15
        button.layer?.cornerCurve = .continuous
        let normalBackground = emphasized
            ? accent.withAlphaComponent(0.13)
            : (selected ? NSColor.white.withAlphaComponent(0.13) : .clear)
        let normalBorder = emphasized
            ? accent.withAlphaComponent(0.32)
            : (selected ? NSColor.white.withAlphaComponent(0.18) : .clear)
        button.layer?.borderWidth = selected || emphasized ? 1 : 0
        button.configureHoverColors(
            normalBackground: normalBackground,
            hoverBackground: accent.withAlphaComponent(emphasized ? 0.22 : 0.12),
            pressBackground: accent.withAlphaComponent(emphasized ? 0.30 : 0.18),
            normalBorder: normalBorder,
            hoverBorder: accent.withAlphaComponent(0.36)
        )
        button.setAccessibilityLabel(title)
        button.setAccessibilityRole(.button)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: width),
            button.heightAnchor.constraint(equalToConstant: 32)
        ])
        return button
    }

    func updateInterviewFocusNavigation(contextSelected: Bool) {
        guard focusContextButton != nil, focusTimelineButton != nil else { return }
        configureFocusNavigationButton(focusContextButton, selected: contextSelected)
        configureFocusNavigationButton(focusTimelineButton, selected: !contextSelected)
    }

    private func configureFocusNavigationButton(_ button: HoverButton, selected: Bool) {
        button.contentTintColor = NSColor.white.withAlphaComponent(selected ? 1.0 : 0.82)
        button.layer?.borderWidth = selected ? 1 : 0
        button.configureHoverColors(
            normalBackground: selected ? NSColor.white.withAlphaComponent(0.13) : .clear,
            hoverBackground: NSColor.white.withAlphaComponent(0.12),
            pressBackground: NSColor.white.withAlphaComponent(0.18),
            normalBorder: selected ? NSColor.white.withAlphaComponent(0.18) : .clear,
            hoverBorder: NSColor.white.withAlphaComponent(0.30)
        )
    }

    func beginFocusAIWork(turnID: UUID) {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: workItem)
        refreshInterviewFocusUI()
        NSAccessibility.post(element: focusAnswerView as Any, notification: .valueChanged)
    }

    func failFocusTurn(turnID: UUID) {
        questionBurstState.fail(turnID: turnID)
        refreshInterviewFocusUI()
    }

    func selectQuestionBurstEntry(_ id: UUID) {
        questionBurstState.select(id)
        refreshInterviewFocusUI()
    }

    func resetInterviewFocusUI() {
        focusReadyResetWorkItem?.cancel()
        focusReadyResetWorkItem = nil
        focusAnswerReadyVisible = false
        questionBurstState.clear()
        refreshInterviewFocusUI()
    }

    func refreshInterviewFocusUI() {
        guard focusQuestionBurstView != nil else { return }

        let visibleEntries = questionBurstState.visibleEntries
        let selected = questionBurstState.selectedEntry
        focusQuestionBurstTitleLabel.stringValue = visibleEntries.isEmpty
            ? "QUESTION BURST"
            : "QUESTION BURST   ·   \(visibleEntries.count)"
        focusQuestionBurstView.update(entries: visibleEntries, selectedID: selected?.id)

        if let selected,
           let position = visibleEntries.firstIndex(where: { $0.id == selected.id }).map({ $0 + 1 }) {
            let attributed: NSAttributedString?
            if selected.answer.isEmpty {
                attributed = nil
            } else {
                attributed = focusAttributedAnswer(selected.answer)
            }
            focusAnswerView.update(
                entry: selected,
                position: position,
                total: visibleEntries.count,
                attributedAnswer: attributed,
                streaming: selected.phase == .answering && questionBurstState.activeAIWork.contains(selected.id)
            )
        } else {
            focusAnswerView.showWelcome()
        }

        let profile = AppSettings.shared
        focusProfileLabel.stringValue = "\(profile.role.displayName)   ·   \(profile.programmingLanguage.displayName)   ·   \(profile.responseLanguage.displayName)"

        refreshFocusActivityCapsules()
        updateFocusInterviewButton()
    }

    func updateFocusSpeaking(_ speaking: Bool) {
        guard focusIsSpeaking != speaking else { return }
        focusIsSpeaking = speaking
        guard !questionBurstState.isAIWorking else { return }
        refreshFocusActivityCapsules()
    }

    func updateFocusElapsedTime() {
        refreshFocusActivityCapsules()
    }

    private func updateFocusInterviewButton() {
        guard focusInterviewButton != nil else { return }
        let recording = isInterviewActive
        let color = recording ? NSColor.appleRed : NSColor.appleGreen
        focusInterviewButton.title = recording ? "End interview" : "Start interview"
        focusInterviewButton.image = NSImage(
            systemSymbolName: recording ? "stop.fill" : "play.fill",
            accessibilityDescription: recording ? "End interview" : "Start interview"
        )
        focusInterviewButton.contentTintColor = color
        focusInterviewButton.layer?.borderWidth = 1
        focusInterviewButton.configureHoverColors(
            normalBackground: color.withAlphaComponent(0.13),
            hoverBackground: color.withAlphaComponent(0.22),
            pressBackground: color.withAlphaComponent(0.30),
            normalBorder: color.withAlphaComponent(0.32),
            hoverBorder: color.withAlphaComponent(0.48)
        )
        focusInterviewButton.setAccessibilityLabel(recording ? "End interview" : "Start interview")
    }

    private func focusElapsedText() -> String {
        guard isInterviewActive, let start = recordingStartTime else { return "" }
        let elapsed = max(0, Int(Date().timeIntervalSince(start)))
        return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private func refreshFocusActivityCapsules() {
        guard focusAIActivityCapsule != nil, focusCommandAIActivityCapsule != nil else { return }
        let activityMode = currentFocusActivityMode()
        focusAIActivityCapsule.update(
            mode: activityMode,
            isRecording: isInterviewActive,
            elapsed: focusElapsedText()
        )

        let commandMode: AIActivityCapsuleView.Mode = questionBurstState.isAIWorking
            ? .working(questionNumber: nil)
            : activityMode
        focusCommandAIActivityCapsule.update(mode: commandMode, isRecording: false, elapsed: "")
    }

    private func currentFocusActivityMode() -> AIActivityCapsuleView.Mode {
        if questionBurstState.isAIWorking {
            return .working(questionNumber: questionBurstState.visiblePosition(of: questionBurstState.latestActiveWorkID))
        }
        if focusAnswerReadyVisible {
            return .ready
        }
        if isInterviewActive {
            return .listening(speaking: focusIsSpeaking)
        }
        return .idle
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
                value: NSColor.white.withAlphaComponent(0.92),
                range: bulletRange
            )
            let nextLocation = NSMaxRange(bulletRange)
            searchRange = NSRange(location: nextLocation, length: rendered.length - nextLocation)
        }
        return formatted
    }
}
