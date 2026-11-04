import Cocoa

/// The right-hand pane of the interview window. It shows the code the interviewer asked for, step
/// by step, and keeps it in place while new questions are answered on the left. Every request that
/// produces code is kept as a version, so an earlier answer is one click away instead of gone.
final class CodePanelView: NSView {
    /// One request's code. The id is the answer card it belongs to.
    struct Version: Equatable {
        let id: UUID
        var title: String
        var markdown: String
        var outcome: CodingTaskOutcome
        var isStreaming: Bool
        let allowsChanges: Bool
        /// When the code was asked for (or asked for again), for counting a long wait.
        var startedAt: Date = CodePanelView.now()
    }

    static let maxVersions = 10
    /// The clock a waiting panel reads, so the QA driver can look at a long wait without making it.
    static var now: () -> Date = Date.init

    var onClose: (() -> Void)?
    /// A one-click change; the string is worded like a spoken request.
    var onQuickAction: ((String) -> Void)?
    var onRetry: (() -> Void)?
    /// The question this code answers was asked for, from the "from Q4" link in the title.
    var onOriginClick: (() -> Void)?
    /// What is on screen changed, so anything that describes it can catch up.
    var onRendered: (() -> Void)?

    // Header
    /// "Code" in small capitals in the code hue, above what the code is.
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let previousButton = HoverButton(frame: .zero)
    private let nextButton = HoverButton(frame: .zero)
    private let positionLabel = NSTextField(labelWithString: "")
    private let originButton = HoverButton(frame: .zero)
    private let copiedLabel = NSTextField(labelWithString: "Copied")
    private let copyAllButton = HoverButton(frame: .zero)
    private let closeButton = HoverButton(frame: .zero)
    // Body
    private let scrollView = NSScrollView()
    private let documentView = FlippedView()
    private let fallbackView = NSTextView()
    /// The card the first step will fill, while nothing has been written yet.
    private let stepSkeleton = CodeStepSkeletonView()
    private var waitTimer: Timer?
    private let emptyTitle = NSTextField(labelWithString: "Code appears here")
    private let emptyBody = NSTextField(wrappingLabelWithString: "")
    // Incomplete banner
    private let banner = NSView()
    private let bannerLabel = NSTextField(wrappingLabelWithString: "")
    private let retryButton = HoverButton(frame: .zero)
    // Footer
    private let footer = NSView()
    private var chips: [HoverButton] = []
    private var chipInstructions: [String] = []
    private let viewingLabel = NSTextField(labelWithString: "")
    private let latestButton = HoverButton(frame: .zero)

    private var fileViews: [CodeFileView] = []
    /// The steps on screen, read as files.
    private(set) var sections: [CodeFileSection] = []
    /// Quick actions wait below the code until the pointer comes near them.
    private var quickActionsRevealed = false
    private var quickActionsArea: NSTrackingArea?
    private(set) var versions: [Version] = []
    private(set) var displayedIndex: Int?
    /// Steps of the version on screen.
    private(set) var steps: [CodingInterviewStep] = []
    private var usesFallback = false
    /// True once the interview has stopped: there is nobody left to ask for a change or a retry.
    private(set) var changesLocked = false
    private var copyAllResetWorkItem: DispatchWorkItem?

    private let headerHeight: CGFloat = 66
    private let cardSpacing = Token.Space.md
    private let contentInset = Token.Space.inset
    private lazy var overflowCue = OverflowCueView(watching: scrollView)

    var displayed: Version? { displayedIndex.flatMap { versions.indices.contains($0) ? versions[$0] : nil } }
    private var isShowingLatest: Bool { displayedIndex == versions.count - 1 }
    /// The newest version is still being written.
    var isStreaming: Bool { versions.last?.isStreaming ?? false }

    /// All code on screen, ready for the clipboard.
    var allCode: String {
        sections.map(\.code).joined(separator: "\n\n")
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        applySurface(.codePanel)

        titleLabel.attributedStringValue = Token.Text.overline("Code", color: Token.Hue.code.text)
        titleLabel.setAccessibilityLabel("Code")
        addSubview(titleLabel)

        subtitleLabel.font = Token.Font.text(.title, .semibold)
        subtitleLabel.textColor = Token.Color.textPrimary
        subtitleLabel.lineBreakMode = .byTruncatingTail
        addSubview(subtitleLabel)

        configure(previousButton, symbol: "chevron.left", label: "Previous version", action: #selector(showPreviousVersion))
        configure(nextButton, symbol: "chevron.right", label: "Next version", action: #selector(showNextVersion))
        positionLabel.font = Token.Font.digits(.caption, .medium)
        positionLabel.textColor = Token.Color.textMuted
        positionLabel.alignment = .center
        addSubview(positionLabel)
        addSubview(previousButton)
        addSubview(nextButton)

        configure(copyAllButton, symbol: "doc.on.doc", label: "Copy all code", action: #selector(copyAll))
        configure(closeButton, symbol: "xmark", label: "Hide code panel", action: #selector(closePanel))
        addSubview(copyAllButton)
        addSubview(closeButton)

        copiedLabel.font = Token.Font.text(.caption, .medium)
        copiedLabel.textColor = Token.Hue.success.text
        copiedLabel.alignment = .right
        copiedLabel.isHidden = true
        addSubview(copiedLabel)

        originButton.target = self
        originButton.action = #selector(originClicked)
        originButton.toolTip = "Go to the question this code answers"
        originButton.isHidden = true
        addSubview(originButton)

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.documentView = documentView
        addSubview(scrollView)
        addSubview(overflowCue, positioned: .above, relativeTo: scrollView)

        fallbackView.isEditable = false
        fallbackView.isSelectable = true
        fallbackView.drawsBackground = false
        fallbackView.textContainerInset = .zero
        fallbackView.textContainer?.lineFragmentPadding = 0
        fallbackView.isVerticallyResizable = false
        fallbackView.isHorizontallyResizable = false
        fallbackView.isHidden = true
        documentView.addSubview(fallbackView)

        stepSkeleton.isHidden = true
        addSubview(stepSkeleton)

        emptyTitle.font = Token.Font.text(.lead, .semibold)
        emptyTitle.textColor = Token.Color.textBody
        emptyTitle.alignment = .center
        emptyBody.attributedStringValue = Token.Text.attributed(
            "When the interviewer asks for code, you get it here one step at a time.",
            font: Token.Font.text(.body), color: Token.Color.textBody, leading: Token.Leading.compact, alignment: .center
        )
        addSubview(emptyTitle)
        addSubview(emptyBody)

        banner.applySurface(.banner)
        banner.isHidden = true
        addSubview(banner)
        bannerLabel.maximumNumberOfLines = 2
        banner.addSubview(bannerLabel)
        styleChip(retryButton, title: "Try again", hue: .warning)
        retryButton.toolTip = "Ask for this code again"
        retryButton.target = self
        retryButton.action = #selector(retry)
        banner.addSubview(retryButton)

        footer.isHidden = true
        addSubview(footer)
        viewingLabel.font = Token.Font.digits(.caption, .medium)
        viewingLabel.textColor = Token.Color.textMuted
        footer.addSubview(viewingLabel)
        styleChip(latestButton, title: "Show latest")
        latestButton.toolTip = "Go to the newest version"
        latestButton.target = self
        latestButton.action = #selector(showLatestVersion)
        footer.addSubview(latestButton)

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Code panel")
        render()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure(_ button: HoverButton, symbol: String, label: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.imagePosition = .imageOnly
        button.symbolConfiguration = Token.Font.symbol(.caption)
        button.isBordered = false
        button.target = self
        button.action = action
        button.wantsLayer = true
        button.layer?.cornerRadius = Token.Radius.full(Token.Sizing.controlSmall)
        button.apply(.ghost)
        button.toolTip = label
        button.setAccessibilityLabel(label)
    }

    private func styleChip(_ button: HoverButton, title: String, hue: Token.Hue = .neutral, quiet: Bool = false) {
        button.title = title
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: Token.Font.text(.caption, .semibold),
            .foregroundColor: hue.text
        ])
        button.imagePosition = .noImage
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = Token.Radius.full(Token.Sizing.controlSmall)
        button.layer?.cornerCurve = .continuous
        // Follow-up actions are quiet text that lights on hover; retry and "Show latest" keep their fill.
        button.apply(quiet ? .ghost : .chip(hue))
        button.setAccessibilityLabel(title)
    }

    // MARK: - Versions

    /// Starts a version for a request. The same id again means a retry (fresh code) or a dictated
    /// refinement (the code so far stays and is updated).
    func beginVersion(_ info: CodingTaskInfo) {
        changesLocked = false
        if let index = versions.firstIndex(where: { $0.id == info.turnID }) {
            if !info.isRefinement {
                versions[index].markdown = ""
                versions[index].outcome = .complete
            }
            versions[index].isStreaming = true
            versions[index].startedAt = Self.now()
            displayedIndex = index
        } else {
            versions.append(Version(
                id: info.turnID, title: info.request, markdown: "", outcome: .complete,
                isStreaming: true, allowsChanges: info.allowsChanges
            ))
            if versions.count > Self.maxVersions { versions.removeFirst() }
            displayedIndex = versions.count - 1
        }
        render()
    }

    /// New text for the newest version, which is what streams. It is shown unless an older version is open.
    func updateLatest(markdown: String) {
        if versions.isEmpty {
            versions.append(Version(id: UUID(), title: "", markdown: "", outcome: .complete, isStreaming: false, allowsChanges: false))
            displayedIndex = 0
        }
        versions[versions.count - 1].markdown = markdown
        if isShowingLatest { render() } else { renderHeaderAndFooter() }
    }

    func finishLatest(_ outcome: CodingTaskOutcome) {
        guard !versions.isEmpty else { return }
        versions[versions.count - 1].isStreaming = false
        versions[versions.count - 1].outcome = outcome
        render()
    }

    /// Shows the version that answered a given card. Returns false when that card made no code.
    @discardableResult
    func selectVersion(id: UUID) -> Bool {
        guard let index = versions.firstIndex(where: { $0.id == id }) else { return false }
        guard displayedIndex != index else { return true }
        displayedIndex = index
        render()
        return true
    }

    func clear() {
        versions = []
        displayedIndex = nil
        changesLocked = false
        render()
    }

    /// Keeps the code readable and copyable but stops offering changes and retries.
    func lockChanges() {
        guard !changesLocked else { return }
        changesLocked = true
        render()
    }

    @objc private func showPreviousVersion() { stepVersion(by: -1) }
    @objc private func showNextVersion() { stepVersion(by: 1) }
    @objc private func showLatestVersion() {
        guard !versions.isEmpty else { return }
        displayedIndex = versions.count - 1
        render()
    }

    private func stepVersion(by delta: Int) {
        guard let current = displayedIndex else { return }
        let target = current + delta
        guard versions.indices.contains(target) else { return }
        displayedIndex = target
        render()
    }

    // MARK: - Rendering

    private func render() {
        let version = displayed
        let markdown = version?.markdown ?? ""
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        let progress = parseCodingInterviewStepsStreaming(markdown)

        if progress.steps.isEmpty && !trimmed.isEmpty && !looksLikeStepHeader(trimmed) {
            showFallback(text: trimmed)
        } else {
            showSteps(progress.steps)
        }
        renderHeaderAndFooter()
        needsLayout = true
        onRendered?()
    }

    /// During an interview the copy buttons step aside for the code; ⌘⌥C still copies.
    var isLive = false {
        didSet {
            guard isLive != oldValue else { return }
            if !steps.isEmpty, !usesFallback { showSteps(steps) }
            renderHeaderAndFooter()
        }
    }

    private func renderHeaderAndFooter() {
        refreshSubtitle()
        refreshStatus()
        refreshBannerAndFooter()
        copyAllButton.isEnabled = !steps.isEmpty
        copyAllButton.isHidden = steps.isEmpty || isLive
        let copyLabel = sections.count > 1 ? "Copy all files" : "Copy code"
        copyAllButton.toolTip = "\(copyLabel) (⌘⌥C)"
        copyAllButton.setAccessibilityLabel(copyLabel)
        needsLayout = true
    }

    private func looksLikeStepHeader(_ text: String) -> Bool {
        text.range(of: #"^\s*STEP\b"#, options: [.regularExpression, .caseInsensitive]) != nil
            || "step".hasPrefix(text.lowercased())
    }

    private func showSteps(_ newSteps: [CodingInterviewStep]) {
        usesFallback = false
        fallbackView.isHidden = true
        steps = newSteps
        sections = groupCodeSteps(newSteps)
        let numbersSteps = newSteps.count > 1
        let showsCopy = sections.count > 1 && !isLive
        let previous = previousVersionSections()
        for (index, section) in sections.enumerated() {
            let changes = lineChanges(for: section, among: previous)
            if index < fileViews.count {
                fileViews[index].update(section: section, numbersSteps: numbersSteps, showsCopy: showsCopy, changes: changes)
            } else {
                let view = CodeFileView(section: section, numbersSteps: numbersSteps, showsCopy: showsCopy, changes: changes)
                documentView.addSubview(view)
                fileViews.append(view)
            }
        }
        while fileViews.count > sections.count {
            fileViews.removeLast().removeFromSuperview()
        }
    }

    /// The files of the version before the one on screen, once both have finished writing.
    private func previousVersionSections() -> [CodeFileSection] {
        guard let index = displayedIndex, index > 0, versions.indices.contains(index),
              !versions[index].isStreaming, !versions[index - 1].isStreaming else { return [] }
        return groupCodeSteps(parseCodingInterviewStepsStreaming(versions[index - 1].markdown).steps)
    }

    /// A file is compared with its namesake, or with the only file of the version before.
    private func lineChanges(for section: CodeFileSection, among previous: [CodeFileSection]) -> CodeLineChanges? {
        let earlier = previous.first { $0.fileName == section.fileName } ?? (previous.count == 1 && sections.count == 1 ? previous.first : nil)
        return earlier.flatMap { codeLineChanges(from: $0.code, to: section.code) }
    }

    private func showFallback(text: String) {
        usesFallback = true
        steps = []
        sections = []
        fileViews.forEach { $0.removeFromSuperview() }
        fileViews = []
        fallbackView.isHidden = false
        // Headings, lists and code blocks render as the notes view renders them.
        let storage = NSTextStorage(string: text)
        MarkdownRenderer(style: .panel).render(in: storage)
        fallbackView.textStorage?.setAttributedString(storage)
    }

    private func refreshSubtitle() {
        guard let version = displayed else {
            subtitleLabel.stringValue = ""
            return
        }
        var summary: String
        if usesFallback {
            summary = version.isStreaming ? "Working…" : "Analysis"
        } else if steps.isEmpty {
            // The language is not known until code arrives: "write it in TypeScript" changes it.
            summary = version.isStreaming
                ? WaitProgress.codeStatus(elapsed: Self.now().timeIntervalSince(version.startedAt), separator: Token.Text.separator)
                : ""
        } else {
            // Name the language of the code that is shown, not the app setting it may have replaced.
            let language = steps.compactMap { codingLanguageDisplayName(forFence: $0.language) }.first
                ?? AppSettings.shared.programmingLanguage.displayName
            summary = steps.count > 1 ? "\(language)\(Token.Text.separator)\(steps.count) steps" : language
            if version.isStreaming { summary += "\(Token.Text.separator)writing" }
        }
        subtitleLabel.attributedStringValue = NSAttributedString(string: summary, attributes: [
            .font: Token.Font.digits(.title, .semibold),
            .foregroundColor: Token.Color.textPrimary
        ])
        // The title stays short; hover says which request this version answered.
        let request = version.title.trimmingCharacters(in: .whitespacesAndNewlines)
        subtitleLabel.toolTip = request.isEmpty ? summary : request
    }

    /// Names the question this code came from while another question is selected. Nil hides it.
    func setOrigin(_ text: String?) {
        guard originButton.title != (text ?? "") || originButton.isHidden != (text == nil) else { return }
        originButton.isHidden = text == nil
        if let text {
            styleChip(originButton, title: text, quiet: true)
            originButton.attributedTitle = NSAttributedString(string: text, attributes: [
                .font: Token.Font.text(.caption, .medium),
                .foregroundColor: Token.Color.textMuted
            ])
        }
        needsLayout = true
    }

    private func refreshStatus() {
        let showsStatus = steps.isEmpty && !usesFallback && (displayed?.isStreaming ?? false)
        let showsEmpty = displayed == nil
        let wasShowingStatus = !stepSkeleton.isHidden
        let wasHidden = scrollView.isHidden
        emptyTitle.isHidden = !showsEmpty
        emptyBody.isHidden = !showsEmpty
        scrollView.isHidden = showsStatus || showsEmpty
        if showsStatus {
            stepSkeleton.layer?.removeAnimation(forKey: "fadeOut")
            stepSkeleton.isHidden = false
        } else if wasShowingStatus && wasHidden && !scrollView.isHidden {
            replaceSkeleton()
        } else {
            stepSkeleton.layer?.removeAnimation(forKey: "fadeOut")
            stepSkeleton.isHidden = true
        }
        updateWaitTimer(running: showsStatus)
    }

    /// The first step fades in where the placeholder card was while the placeholder fades out.
    private func replaceSkeleton() {
        guard !Token.Motion.reducesMotion(), window != nil, let contentLayer = scrollView.layer, let skeletonLayer = stepSkeleton.layer else {
            stepSkeleton.isHidden = true
            return
        }
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = Token.Motion.fadeIn
        contentLayer.add(fadeIn, forKey: "fadeIn")
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1
        fadeOut.toValue = 0
        fadeOut.duration = Token.Motion.fadeIn
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false
        skeletonLayer.add(fadeOut, forKey: "fadeOut")
        DispatchQueue.main.asyncAfter(deadline: .now() + Token.Motion.fadeIn) { [weak self] in
            guard let self, self.scrollView.isHidden == false else { return }
            self.stepSkeleton.layer?.removeAnimation(forKey: "fadeOut")
            self.stepSkeleton.isHidden = true
        }
    }

    /// While code has not started to appear the subtitle counts the wait.
    private func updateWaitTimer(running: Bool) {
        guard running, window != nil else {
            waitTimer?.invalidate()
            waitTimer = nil
            return
        }
        guard waitTimer == nil else { return }
        let timer = Timer(timeInterval: Token.Motion.clockTick, repeats: true) { [weak self] _ in
            self?.refreshSubtitle()
        }
        RunLoop.main.add(timer, forMode: .common)
        waitTimer = timer
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateWaitTimer(running: !stepSkeleton.isHidden)
    }

    deinit {
        waitTimer?.invalidate()
    }

    private func refreshBannerAndFooter() {
        // Incomplete code says so, next to the way out.
        if let version = displayed, isShowingLatest, case .incomplete(let reason) = version.outcome, !version.isStreaming {
            bannerLabel.attributedStringValue = Token.Text.attributed(
                "Incomplete. \(reason)", font: Token.Font.text(.caption, .medium), color: Token.Color.textStrong, leading: Token.Leading.compact
            )
            retryButton.isHidden = changesLocked
            banner.isHidden = false
        } else {
            banner.isHidden = true
        }

        // The footer either offers quick changes (newest code) or a way back to it (an older version).
        chips.forEach { $0.removeFromSuperview() }
        chips = []
        footer.alphaValue = 1
        chipInstructions = []
        guard let version = displayed else {
            footer.isHidden = true
            return
        }
        if !isShowingLatest {
            viewingLabel.stringValue = "Version \((displayedIndex ?? 0) + 1) of \(versions.count)"
            viewingLabel.isHidden = false
            latestButton.isHidden = false
            footer.isHidden = false
        } else if version.allowsChanges, !changesLocked, !version.isStreaming, !steps.isEmpty, version.outcome == .complete {
            viewingLabel.isHidden = true
            latestButton.isHidden = true
            let language = steps.compactMap { codingLanguageDisplayName(forFence: $0.language) }.first
            for action in CodeQuickAction.allCases {
                let chip = HoverButton(frame: .zero)
                chip.identifier = NSUserInterfaceItemIdentifier("quickAction")
                styleChip(chip, title: action.title(currentLanguage: language), quiet: true)
                chip.target = self
                chip.action = #selector(quickActionClicked(_:))
                chip.tag = chips.count
                chip.toolTip = "Ask for: \(action.instruction(currentLanguage: language))"
                footer.addSubview(chip)
                chips.append(chip)
                chipInstructions.append(action.instruction(currentLanguage: language))
            }
            footer.isHidden = false
            footer.alphaValue = quickActionsRevealed ? 1 : 0
        } else {
            footer.isHidden = true
        }
    }

    func applyTransparency() {
        applySurface(.codePanel)
        overflowCue.refreshColors()
        banner.applySurface(.banner)
        fileViews.forEach { $0.applyTransparency() }
    }

    // MARK: - Quick actions on hover

    /// The strip of the panel that wakes the quick actions. It works while the window is not key, because
    /// during a call the video app has the focus.
    private static let quickActionsZone: CGFloat = 88

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let quickActionsArea { removeTrackingArea(quickActionsArea) }
        let zone = NSRect(x: 0, y: 0, width: bounds.width, height: min(bounds.height, Self.quickActionsZone))
        let area = NSTrackingArea(rect: zone, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        quickActionsArea = area
    }

    override func mouseEntered(with event: NSEvent) { setQuickActionsRevealed(true) }
    override func mouseExited(with event: NSEvent) { setQuickActionsRevealed(false) }

    /// The actions stay in the accessibility tree while they are faded out.
    func setQuickActionsRevealed(_ revealed: Bool) {
        quickActionsRevealed = revealed
        guard !chips.isEmpty else { return }
        let alpha: CGFloat = revealed ? 1 : 0
        if Token.Motion.reducesMotion() {
            footer.alphaValue = alpha
        } else {
            footer.animator().alphaValue = alpha
        }
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        let bannerShown = !banner.isHidden
        let footerShown = !footer.isHidden

        let inset = contentInset
        let titleX = inset
        let headerTop = bounds.height - inset
        closeButton.frame = NSRect(x: bounds.width - inset - Token.Sizing.controlSmall, y: bounds.height - 41, width: Token.Sizing.controlSmall, height: Token.Sizing.controlSmall)
        copyAllButton.frame = NSRect(x: closeButton.frame.minX - Token.Sizing.controlSmall - Token.Space.sm, y: bounds.height - 41, width: Token.Sizing.controlSmall, height: Token.Sizing.controlSmall)
        titleLabel.frame = NSRect(x: titleX, y: headerTop - 17, width: ceil(titleLabel.attributedStringValue.size().width) + 6, height: 16)

        let showsStepper = versions.count > 1
        // Once code is in, "Python · 3 steps" is the heading; the overline stays for the empty and
        // waiting states, and to anchor the version stepper.
        let headingOnly = !steps.isEmpty && !showsStepper
        titleLabel.isHidden = headingOnly
        previousButton.isHidden = !showsStepper
        nextButton.isHidden = !showsStepper
        positionLabel.isHidden = !showsStepper
        if showsStepper {
            let index = displayedIndex ?? 0
            positionLabel.stringValue = "\(index + 1)/\(versions.count)"
            let stepperX = titleLabel.frame.maxX + Token.Space.xs
            previousButton.frame = NSRect(x: stepperX, y: headerTop - 20, width: 24, height: 24)
            positionLabel.frame = NSRect(x: previousButton.frame.maxX, y: headerTop - 17, width: 44, height: 16)
            nextButton.frame = NSRect(x: positionLabel.frame.maxX, y: headerTop - 20, width: 24, height: 24)
            previousButton.isEnabled = index > 0
            previousButton.alphaValue = index > 0 ? 1 : Token.State.disabledAlpha
            nextButton.isEnabled = index < versions.count - 1
            nextButton.alphaValue = index < versions.count - 1 ? 1 : Token.State.disabledAlpha
        }
        let copiedWidth: CGFloat = copiedLabel.isHidden ? 0 : 52
        copiedLabel.frame = NSRect(x: copyAllButton.frame.minX - Token.Space.xs - copiedWidth, y: copyAllButton.frame.midY - 8, width: copiedWidth, height: 16)
        let buttonsX = copyAllButton.frame.minX - Token.Space.sm - copiedWidth
        let subtitleY = headingOnly ? copyAllButton.frame.midY - 23 / 2 : headerTop - 17 - Token.Space.xs - 23
        let originWidth = originButton.isHidden ? 0 : ceil(originButton.attributedTitle.size().width) + 16
        let subtitleSpace = max(40, buttonsX - titleX - (originWidth > 0 ? originWidth + Token.Space.xs : 0))
        let subtitleWidth = originWidth > 0 ? min(subtitleSpace, ceil(subtitleLabel.attributedStringValue.size().width) + 6) : subtitleSpace
        subtitleLabel.frame = NSRect(x: titleX, y: subtitleY, width: subtitleWidth, height: 23)
        originButton.frame = NSRect(x: subtitleLabel.frame.maxX + Token.Space.xs, y: subtitleY, width: originWidth, height: Token.Sizing.controlSmall)

        var top = bounds.height - (headingOnly ? headerHeight - 17 - Token.Space.xs : headerHeight)
        if bannerShown {
            // The banner is as tall as its message needs at this width: narrow panels wrap it.
            let labelWidth = bounds.width - contentInset * 2 - contentInset - 58 - Token.Space.md * 2
            let font = Token.Font.text(.caption, .medium)
            let spacing = Token.Text.lineSpacing(for: font, leading: Token.Leading.compact)
            let labelHeight = font.wrappedHeight(of: bannerLabel.stringValue, width: labelWidth - 4, maxLines: 2, lineSpacing: spacing) + 2
            let bannerHeight = max(36, labelHeight + Token.Space.md * 2)
            banner.frame = NSRect(x: contentInset, y: top - Token.Space.xs - bannerHeight, width: bounds.width - contentInset * 2, height: bannerHeight)
            retryButton.frame = NSRect(x: banner.bounds.width - 58 - Token.Space.md, y: (banner.bounds.height - 24) / 2, width: 58, height: 24)
            bannerLabel.frame = NSRect(x: contentInset, y: (bannerHeight - labelHeight) / 2, width: labelWidth, height: labelHeight)
            top -= Token.Space.xs + bannerHeight + Token.Space.xs
        }
        let footerHeight = footerShown ? currentFooterHeight() : 0
        // The row is kept clear even while the actions are faded out: with nothing behind them they
        // would land on the code.
        let bottom: CGFloat = footerShown ? footerHeight : 6
        let bodyFrame = NSRect(x: 0, y: bottom, width: bounds.width, height: max(40, top - bottom))
        scrollView.frame = bodyFrame
        overflowCue.place(insetX: Token.Radius.lg / 2)
        // Where the first step card will be: the document starts half an inset down.
        let skeletonHeight = min(CodeStepSkeletonView.height, max(0, bodyFrame.height - contentInset * 0.5))
        stepSkeleton.frame = NSRect(x: contentInset, y: bodyFrame.maxY - contentInset * 0.5 - skeletonHeight, width: bounds.width - contentInset * 2, height: skeletonHeight)
        let emptyWidth = min(bodyFrame.width - 48, 300)
        // A title and one sentence, centred as a block: the follow-up actions appear as chips once there is code.
        let bodyFont = Token.Font.text(.body)
        let bodyHeight = bodyFont.wrappedHeight(
            of: emptyBody.stringValue, width: emptyWidth - 4, lineSpacing: Token.Text.lineSpacing(for: bodyFont, leading: Token.Leading.compact)
        ) + 2
        let blockHeight = 20 + Token.Space.sm + bodyHeight
        let blockTop = bodyFrame.midY + blockHeight / 2
        emptyTitle.frame = NSRect(x: (bounds.width - emptyWidth) / 2, y: blockTop - 20, width: emptyWidth, height: 20)
        emptyBody.frame = NSRect(x: (bounds.width - emptyWidth) / 2, y: blockTop - blockHeight, width: emptyWidth, height: bodyHeight)

        if footerShown {
            footer.frame = NSRect(x: 0, y: 0, width: bounds.width, height: footerHeight)
            layoutFooter()
        }
        layoutDocument()
    }

    private static let chipRowGap = Token.Space.sm
    private static let footerPadding: CGFloat = 11

    /// Quick actions flow onto as many rows as they need. An action that does not fit is not hidden.
    private func chipRows(width: CGFloat) -> [[HoverButton]] {
        var rows: [[HoverButton]] = [[]]
        var x: CGFloat = 0
        for chip in chips {
            let chipWidth = ceil(chip.attributedTitle.size().width) + 24
            if x > 0 && x + chipWidth > width {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(chip)
            x += chipWidth + Token.Space.md
        }
        return rows
    }

    private func currentFooterHeight() -> CGFloat {
        let rows = latestButton.isHidden ? chipRows(width: bounds.width - contentInset * 2).count : 1
        let height = Token.Sizing.controlSmall
        return Self.footerPadding * 2 + CGFloat(rows) * height + CGFloat(max(0, rows - 1)) * Self.chipRowGap
    }

    private func layoutFooter() {
        let rowHeight = Token.Sizing.controlSmall
        let top = footer.bounds.height - Self.footerPadding - rowHeight
        if !latestButton.isHidden {
            viewingLabel.sizeToFit()
            viewingLabel.frame.origin = NSPoint(x: contentInset, y: top + (rowHeight - viewingLabel.frame.height) / 2)
            let width = ceil(latestButton.attributedTitle.size().width) + 24
            latestButton.frame = NSRect(x: footer.bounds.width - contentInset - width, y: top, width: width, height: rowHeight)
            return
        }
        for (row, rowChips) in chipRows(width: footer.bounds.width - contentInset * 2).enumerated() {
            var x = contentInset
            let y = top - CGFloat(row) * (rowHeight + Self.chipRowGap)
            for chip in rowChips {
                let width = ceil(chip.attributedTitle.size().width) + 24
                chip.isHidden = false
                chip.frame = NSRect(x: x, y: y, width: width, height: rowHeight)
                x += width + Token.Space.md
            }
        }
    }

    private func layoutDocument() {
        let width = scrollView.contentSize.width
        let innerWidth = max(120, width - contentInset * 2)
        var y = contentInset * 0.5
        if usesFallback {
            fallbackView.textContainer?.containerSize = NSSize(width: innerWidth, height: .greatestFiniteMagnitude)
            var height: CGFloat = 20
            if let storage = fallbackView.textStorage, storage.length > 0 {
                height = ceil(storage.boundingRect(
                    with: NSSize(width: innerWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
                ).height) + 4
            }
            fallbackView.frame = NSRect(x: contentInset, y: y, width: innerWidth, height: height)
            y += height + contentInset
        } else {
            for view in fileViews {
                let height = view.preferredHeight
                view.frame = NSRect(x: contentInset, y: y, width: innerWidth, height: height)
                y += height + cardSpacing
            }
            y += contentInset - cardSpacing
        }
        documentView.frame = NSRect(x: 0, y: 0, width: width, height: max(y, scrollView.contentSize.height))
    }

    // MARK: - Actions

    @objc private func quickActionClicked(_ sender: NSButton) {
        guard chipInstructions.indices.contains(sender.tag) else { return }
        onQuickAction?(chipInstructions[sender.tag])
    }

    @objc private func retry() {
        onRetry?()
    }

    @objc private func originClicked() {
        onOriginClick?()
    }

    @objc private func copyAll() {
        copyDisplayedCode()
    }

    /// Copies the code on screen and says so next to the button. Returns false when there is none.
    @discardableResult
    func copyDisplayedCode() -> Bool {
        guard !allCode.isEmpty else { return false }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(allCode, forType: .string)
        announceForAccessibility("Copied all code")
        copyAllButton.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Copied")
        copyAllButton.contentTintColor = Token.Hue.success.text
        copiedLabel.isHidden = false
        needsLayout = true
        copyAllResetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.copyAllButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy all code")
            self?.copyAllButton.contentTintColor = Token.Color.iconDefault
            self?.copiedLabel.isHidden = true
            self?.needsLayout = true
        }
        copyAllResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Token.Motion.feedbackHold, execute: work)
        return true
    }

    @objc private func closePanel() {
        onClose?()
    }
}
