import Cocoa

/// One typed step of a coding answer: a numbered header with the file name, the one-line reason,
/// and the highlighted code with a copy button.
final class CodeStepCardView: NSView {
    private let badge = NSView()
    private let numberLabel = NSTextField(labelWithString: "1")
    private let fileLabel = NSTextField(labelWithString: "")
    private let whyLabel = NSTextField(wrappingLabelWithString: "")
    private let codeBackground = NSView()
    private let codeView = NSTextView()
    private let copyButton = HoverButton(frame: .zero)
    private let highlighter = SyntaxHighlighter(fontSize: Token.Font.Size.code.points)
    private(set) var step: CodingInterviewStep
    private var continuesFile: Bool
    private var copyResetWorkItem: DispatchWorkItem?

    /// Steps are flat: they line up with the panel's title and spacing separates them.
    private let sidePadding: CGFloat = 0
    private let bottomPadding = Token.Space.sm
    private var hoverArea: NSTrackingArea?
    private let headerHeight: CGFloat = 30
    private let codePadding: CGFloat = 10

    init(step: CodingInterviewStep, continuesFile: Bool) {
        self.step = step
        self.continuesFile = continuesFile
        super.init(frame: .zero)

        // A plain muted number: the steps are already in order, the digit only names them.
        addSubview(badge)

        // Light text: the saturated purple on its own wash measured about 3.2:1, under the 4.5:1 target.
        numberLabel.font = Token.Font.digits(.micro, .semibold)
        numberLabel.textColor = Token.Color.textMuted
        numberLabel.alignment = .left
        badge.addSubview(numberLabel)

        fileLabel.font = Token.Font.mono(.caption, .semibold)
        fileLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(fileLabel)

        whyLabel.maximumNumberOfLines = 3
        addSubview(whyLabel)

        codeBackground.applySurface(.codeWell)
        addSubview(codeBackground)

        codeView.isEditable = false
        codeView.isSelectable = true
        codeView.drawsBackground = false
        codeView.textContainerInset = .zero
        codeView.textContainer?.lineFragmentPadding = 0
        codeView.isVerticallyResizable = false
        codeView.isHorizontallyResizable = false
        codeView.textContainer?.widthTracksTextView = false
        codeBackground.addSubview(codeView)

        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy code")
        copyButton.imagePosition = .imageOnly
        copyButton.symbolConfiguration = Token.Font.symbol(.caption)
        copyButton.isBordered = false
        copyButton.target = self
        copyButton.action = #selector(copyCode)
        copyButton.wantsLayer = true
        copyButton.layer?.cornerRadius = Token.Radius.sm
        copyButton.apply(.ghost)
        copyButton.toolTip = "Copy step code"
        copyButton.setAccessibilityLabel("Copy step code")
        // Shown on hover; the panel's copy-all stays visible, and the button stays in the accessibility tree.
        copyButton.alphaValue = 0
        addSubview(copyButton)

        apply(step: step)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(step newStep: CodingInterviewStep, continuesFile newContinues: Bool) {
        guard newStep != step || newContinues != continuesFile else { return }
        step = newStep
        continuesFile = newContinues
        apply(step: newStep)
    }

    private func apply(step: CodingInterviewStep) {
        numberLabel.stringValue = "\(step.number)"
        // Steps that add to the file above say so instead of repeating its name as if it were new.
        fileLabel.stringValue = continuesFile ? "↳ \(step.fileName)" : step.fileName
        fileLabel.textColor = continuesFile ? Token.Color.textMuted : Token.Color.textStrong
        fileLabel.toolTip = step.fileName
        whyLabel.attributedStringValue = Token.Text.attributed(
            step.why, font: Token.Font.text(.caption), color: Token.Color.textMuted, leading: Token.Leading.compact
        )
        whyLabel.isHidden = step.why.isEmpty
        let language = Self.highlighterLanguage(for: step.language)
        let code = NSMutableAttributedString(attributedString: highlighter.highlight(step.code, language: language))
        code.addAttribute(
            .paragraphStyle,
            value: Token.Text.paragraph(for: Token.Font.mono(.code), leading: Token.Leading.compact),
            range: NSRange(location: 0, length: code.length)
        )
        codeView.textStorage?.setAttributedString(code)
        setAccessibilityLabel("Step \(step.number), \(continuesFile ? "continues " : "")\(step.fileName). \(step.why)")
        needsLayout = true
    }

    /// The highlighter knows a handful of languages; the rest use its generic rules.
    static func highlighterLanguage(for fence: String) -> String? {
        switch fence.lowercased() {
        case "python", "py": return "python"
        case "javascript", "js", "typescript", "ts", "tsx", "jsx": return "javascript"
        case "java": return "java"
        case "sql": return "sql"
        case "swift": return "swift"
        case "go", "golang": return "go"
        default: return nil
        }
    }

    func preferredHeight(forWidth width: CGFloat) -> CGFloat {
        let innerWidth = max(80, width - sidePadding * 2)
        let whyHeight = whyTextHeight(forWidth: innerWidth) + (step.why.isEmpty ? 0 : 4)
        let codeHeight = codeTextHeight(forWidth: innerWidth - codePadding * 2)
        return headerHeight + whyHeight + Token.Space.sm + codeHeight + codePadding * 2 + bottomPadding
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) { copyButton.animator().alphaValue = 1 }
    override func mouseExited(with event: NSEvent) { copyButton.animator().alphaValue = 0 }

    private func whyTextHeight(forWidth width: CGFloat) -> CGFloat {
        let font = Token.Font.text(.caption)
        let spacing = Token.Text.lineSpacing(for: font, leading: Token.Leading.compact)
        return font.wrappedHeight(of: step.why, width: min(width, Token.Measure.note) - 4, maxLines: 3, lineSpacing: spacing) + 2
    }

    private func codeTextHeight(forWidth width: CGFloat) -> CGFloat {
        guard let storage = codeView.textStorage, storage.length > 0 else { return 16 }
        let bounds = storage.boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(bounds.height) + 2
    }

    override func layout() {
        super.layout()
        let innerWidth = bounds.width - sidePadding * 2
        var y = bounds.height - headerHeight
        badge.frame = NSRect(x: sidePadding, y: y + 5, width: Token.Sizing.badgeSmall, height: Token.Sizing.badgeSmall)
        numberLabel.frame = NSRect(x: 0, y: 2, width: 20, height: 16)
        copyButton.frame = NSRect(x: bounds.width - sidePadding - Token.Sizing.controlSmall, y: y + 2, width: Token.Sizing.controlSmall, height: Token.Sizing.controlSmall)
        fileLabel.frame = NSRect(x: sidePadding + Token.Sizing.badgeSmall + Token.Space.sm, y: y + 6, width: max(40, innerWidth - Token.Sizing.badgeSmall - Token.Space.sm - Token.Sizing.controlSmall - Token.Space.xs), height: 18)

        if !whyLabel.isHidden {
            let whyHeight = whyTextHeight(forWidth: innerWidth)
            y -= whyHeight + 4
            whyLabel.frame = NSRect(x: sidePadding, y: y + 2, width: min(innerWidth, Token.Measure.note), height: whyHeight)
        }

        let codeHeight = codeTextHeight(forWidth: innerWidth - codePadding * 2)
        let backgroundHeight = codeHeight + codePadding * 2
        codeBackground.frame = NSRect(x: sidePadding, y: bottomPadding, width: innerWidth, height: backgroundHeight)
        codeView.frame = NSRect(x: codePadding, y: codePadding, width: innerWidth - codePadding * 2, height: codeHeight)
        codeView.textContainer?.containerSize = NSSize(width: innerWidth - codePadding * 2, height: .greatestFiniteMagnitude)
    }

    @objc private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(step.code, forType: .string)
        flashCopied()
    }

    private func flashCopied() {
        announceForAccessibility("Copied")
        copyButton.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Copied")
        copyButton.contentTintColor = Token.Hue.success.text
        copyResetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy code")
            self?.copyButton.contentTintColor = Token.Color.iconDefault
        }
        copyResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Token.Motion.feedbackHold, execute: work)
    }
}

/// The right-hand pane of the interview window. It shows the code the interviewer asked for, step
/// by step, and keeps it in place while new questions are answered on the left. Every request that
/// produces code is kept as a version, so an earlier answer is one click away instead of gone.
final class CodePanelView: NSVisualEffectView {
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

    // Header
    /// "Code" in small capitals in the code hue, above what the code is.
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let previousButton = HoverButton(frame: .zero)
    private let nextButton = HoverButton(frame: .zero)
    private let positionLabel = NSTextField(labelWithString: "")
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

    private var cards: [CodeStepCardView] = []
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
        steps.map(\.code).joined(separator: "\n\n")
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        applyGlass(.codePanel)

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
    }

    private func renderHeaderAndFooter() {
        refreshSubtitle()
        refreshStatus()
        refreshBannerAndFooter()
        copyAllButton.isEnabled = !steps.isEmpty
        copyAllButton.isHidden = steps.isEmpty
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
        for (index, step) in newSteps.enumerated() {
            let continues = index > 0 && newSteps[index - 1].fileName == step.fileName
            if index < cards.count {
                cards[index].update(step: step, continuesFile: continues)
            } else {
                let card = CodeStepCardView(step: step, continuesFile: continues)
                documentView.addSubview(card)
                cards.append(card)
            }
        }
        while cards.count > newSteps.count {
            cards.removeLast().removeFromSuperview()
        }
    }

    private func showFallback(text: String) {
        usesFallback = true
        steps = []
        cards.forEach { $0.removeFromSuperview() }
        cards = []
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
            summary = "\(language)\(Token.Text.separator)\(steps.count) step\(steps.count == 1 ? "" : "s")"
            if version.isStreaming { summary += "\(Token.Text.separator)writing" }
        }
        // A lone version answers the question the card above quotes; several need telling apart.
        let request = versions.count > 1 ? version.title.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let text = NSMutableAttributedString(string: summary, attributes: [
            .font: Token.Font.digits(.title, .semibold),
            .foregroundColor: Token.Color.textPrimary
        ])
        if !request.isEmpty {
            text.append(NSAttributedString(string: (summary.isEmpty ? "" : Token.Text.separator) + "“\(request)”", attributes: [
                .font: Token.Font.text(.title),
                .foregroundColor: Token.Color.textBody
            ]))
        }
        subtitleLabel.attributedStringValue = text
        subtitleLabel.toolTip = text.string
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
        } else {
            footer.isHidden = true
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
        let buttonsX = copyAllButton.frame.minX - Token.Space.sm
        let subtitleY = headingOnly ? copyAllButton.frame.midY - 23 / 2 : headerTop - 17 - Token.Space.xs - 23
        subtitleLabel.frame = NSRect(x: titleX, y: subtitleY, width: max(40, buttonsX - titleX), height: 23)

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
            for card in cards {
                let height = card.preferredHeight(forWidth: innerWidth)
                card.frame = NSRect(x: contentInset, y: y, width: innerWidth, height: height)
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

    @objc private func copyAll() {
        guard !allCode.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(allCode, forType: .string)
        announceForAccessibility("Copied all code")
        copyAllButton.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Copied")
        copyAllButton.contentTintColor = Token.Hue.success.text
        copyAllResetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.copyAllButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy all code")
            self?.copyAllButton.contentTintColor = Token.Color.iconDefault
        }
        copyAllResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Token.Motion.feedbackHold, execute: work)
    }

    @objc private func closePanel() {
        onClose?()
    }
}
