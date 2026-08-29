import Cocoa

private extension PracticeRecallConfidence {
    var practiceAccessibilityHelp: String {
        switch self {
        case .very: return "I felt very confident before seeing the key ideas."
        case .mostly: return "I remembered most of the answer."
        case .unsure: return "I was unsure or could not recall the answer yet."
        }
    }
}

private final class PracticeFlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

/// Text answers should behave like form controls: Tab advances to the next
/// Practice action, while Option-Tab remains available for inserting a tab.
final class PracticeNavigableTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 48, !modifiers.contains(.option), !modifiers.contains(.command), !modifiers.contains(.control) {
            if modifiers.contains(.shift) {
                window?.selectPreviousKeyView(nil)
            } else {
                window?.selectNextKeyView(nil)
            }
            return
        }
        super.keyDown(with: event)
    }
}

private func sizePracticeTextDocument(_ textView: NSTextView, in scrollView: NSScrollView) {
    let width = max(1, scrollView.contentSize.width)
    textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false
    textView.layoutManager?.ensureLayout(for: textView.textContainer!)
    let usedHeight = textView.textContainer.flatMap { textView.layoutManager?.usedRect(for: $0).height } ?? 0
    let insetHeight = textView.textContainerInset.height * 2
    textView.frame = NSRect(
        x: 0,
        y: 0,
        width: width,
        height: max(scrollView.contentSize.height, ceil(usedHeight + insetHeight))
    )
}

private func practiceTextHeight(_ text: String, font: NSFont, width: CGFloat, minimum: CGFloat = 18) -> CGFloat {
    guard width > 1, !text.isEmpty else { return minimum }
    let rect = (text as NSString).boundingRect(
        with: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: font]
    )
    return max(minimum, ceil(rect.height))
}

/// Practice-only glass card matching Timeline's FocusAnswerView. Not used by live interview.
@available(macOS 14.0, *)
final class PracticeQuestionCard: NSVisualEffectView {
    let badge = NSView()
    let badgeLabel = NSTextField(labelWithString: "Q")
    let titleLabel = NSTextField(labelWithString: "Practice")
    let positionLabel = NSTextField(labelWithString: "Ready")
    let sourceLabel = NSTextField(labelWithString: "Questions come from the study book.")
    let questionScroll = NSScrollView()
    let questionView = NSTextView()
    let helpCard = NSView()
    let helpLabel = NSTextField(wrappingLabelWithString: "")
    let answerCaption = NSTextField(labelWithString: "YOUR ANSWER")
    let answerScroll = NSScrollView()
    let answerView = PracticeNavigableTextView()
    let reportScroll = NSScrollView()
    let reportView = NSTextView()
    let optionButtons: [NSButton] = (0..<4).map { _ in
        let button = NSButton(title: "", target: nil, action: nil)
        button.isBordered = false
        button.bezelStyle = .inline
        button.setButtonType(.momentaryChange)
        button.font = .systemFont(ofSize: 12, weight: .medium)
        button.alignment = .left
        button.lineBreakMode = .byTruncatingTail
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.cornerCurve = .continuous
        button.layer?.borderWidth = 1
        button.isHidden = true
        return button
    }

    private var showingHelp = false
    private var showingReport = false
    private var showingOptions = false
    private var showingIdle = true

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor(white: 0.035, alpha: 0.78).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.16
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: 0, height: 4)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Practice question card")

        badge.wantsLayer = true
        badge.layer?.cornerRadius = 11
        badge.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.16).cgColor
        badge.layer?.borderWidth = 1
        badge.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.55).cgColor
        addSubview(badge)

        badgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        badgeLabel.textColor = .systemBlue
        badgeLabel.alignment = .center
        badge.addSubview(badgeLabel)

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)

        positionLabel.font = .systemFont(ofSize: 11, weight: .medium)
        positionLabel.textColor = NSColor.white.withAlphaComponent(0.68)
        positionLabel.alignment = .right
        addSubview(positionLabel)

        sourceLabel.font = .systemFont(ofSize: 11, weight: .medium)
        sourceLabel.textColor = NSColor.white.withAlphaComponent(0.55)
        sourceLabel.lineBreakMode = .byTruncatingTail
        addSubview(sourceLabel)

        configureScroll(questionScroll, textView: questionView, editable: false)
        questionView.font = .systemFont(ofSize: 15, weight: .regular)
        questionView.setAccessibilityLabel("Question")

        helpCard.wantsLayer = true
        helpCard.layer?.cornerRadius = 10
        helpCard.layer?.cornerCurve = .continuous
        helpCard.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.14).cgColor
        helpCard.layer?.borderWidth = 1
        helpCard.layer?.borderColor = NSColor.systemYellow.withAlphaComponent(0.55).cgColor
        helpCard.isHidden = true
        addSubview(helpCard)

        helpLabel.font = .systemFont(ofSize: 13, weight: .medium)
        helpLabel.textColor = NSColor.systemYellow
        helpLabel.maximumNumberOfLines = 10
        helpCard.addSubview(helpLabel)

        answerCaption.font = .systemFont(ofSize: 9.5, weight: .bold)
        answerCaption.textColor = NSColor.white.withAlphaComponent(0.72)
        addSubview(answerCaption)

        configureScroll(answerScroll, textView: answerView, editable: true)
        answerView.font = .systemFont(ofSize: 15, weight: .regular)
        answerView.insertionPointColor = .white
        answerView.setAccessibilityLabel("Your answer")
        answerView.setAccessibilityHelp("Type or dictate your answer before submitting.")
        for button in optionButtons {
            addSubview(button)
        }

        configureScroll(reportScroll, textView: reportView, editable: false)
        reportView.font = .systemFont(ofSize: 13, weight: .regular)
        reportView.setAccessibilityLabel("Practice report")
        reportScroll.isHidden = true

        showIdle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureScroll(_ scroll: NSScrollView, textView: NSTextView, editable: Bool) {
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear
        addSubview(scroll)

        textView.isEditable = editable
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.isRichText = false
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        scroll.documentView = textView
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height
        badge.frame = NSRect(x: 18, y: h - 42, width: 24, height: 24)
        badgeLabel.frame = NSRect(x: 0, y: 4, width: 24, height: 16)
        titleLabel.frame = NSRect(x: 54, y: h - 42, width: max(120, w - 230), height: 24)
        positionLabel.frame = NSRect(x: w - 164, y: h - 39, width: 146, height: 18)
        sourceLabel.frame = NSRect(x: 54, y: h - 58, width: max(80, w - 74), height: 16)

        if showingReport {
            reportScroll.frame = NSRect(x: 20, y: 16, width: w - 40, height: max(40, h - 78))
            sizePracticeTextDocument(reportView, in: reportScroll)
            return
        }

        if showingIdle {
            questionScroll.frame = NSRect(x: 20, y: 18, width: w - 40, height: max(48, h - 88))
            sizePracticeTextDocument(questionView, in: questionScroll)
            return
        }

        let helpHeight: CGFloat = showingHelp ? min(130, max(72, h * 0.22)) : 0
        let buttonsReserve: CGFloat = 44
        let optionHeight: CGFloat = 28
        let optionGap: CGFloat = 6
        let optionsBlock: CGFloat = showingOptions ? (4 * optionHeight + 3 * optionGap) : 0
        let answerHeight: CGFloat = showingOptions ? 0 : min(110, max(72, h * 0.22))
        let answerY = buttonsReserve + 8
        answerScroll.frame = NSRect(x: 20, y: answerY, width: w - 40, height: answerHeight)
        sizePracticeTextDocument(answerView, in: answerScroll)
        answerCaption.frame = NSRect(x: 20, y: answerScroll.frame.maxY + (showingOptions ? 0 : 4), width: 160, height: showingOptions ? 0 : 14)
        answerScroll.isHidden = showingOptions
        answerCaption.isHidden = showingOptions

        var stackY = showingOptions ? answerY : answerCaption.frame.maxY + 8
        if showingOptions {
            for (index, button) in optionButtons.enumerated() {
                button.frame = NSRect(x: 20, y: stackY + CGFloat(3 - index) * (optionHeight + optionGap), width: w - 40, height: optionHeight)
            }
            stackY += optionsBlock + 8
        } else {
            optionButtons.forEach { $0.frame = .zero }
        }

        helpCard.frame = NSRect(x: 18, y: stackY, width: w - 36, height: helpHeight)
        helpLabel.frame = helpCard.bounds.insetBy(dx: 10, dy: 8)

        let questionTop = helpCard.frame.maxY + 8
        let questionH = max(48, (h - 64) - questionTop)
        questionScroll.frame = NSRect(x: 20, y: questionTop, width: w - 40, height: questionH)
        sizePracticeTextDocument(questionView, in: questionScroll)
    }

    func showIdle() {
        showingReport = false
        showingHelp = false
        showingIdle = true
        badgeLabel.stringValue = "Q"
        titleLabel.stringValue = "Practice"
        positionLabel.stringValue = "Ready"
        sourceLabel.stringValue = "Questions come from the study book."
        setQuestionText("Choose a role, topics, and session length. Active Recall lets you answer in your own words, compare key ideas, and control when each concept returns.")
        answerView.string = ""
        answerView.isEditable = true
        helpCard.isHidden = true
        reportScroll.isHidden = true
        questionScroll.isHidden = false
        answerScroll.isHidden = true
        answerCaption.isHidden = true
        showingOptions = false
        optionButtons.forEach { $0.isHidden = true }
        needsLayout = true
    }

    /// Renders a compact, glanceable daily-plan surface in the existing idle card.
    /// The controller keeps ownership of the Start/Resume actions.
    func showTodayPlan(_ plan: PracticeTodayPlan, resumeSummary: String? = nil) {
        showIdle()
        badgeLabel.stringValue = "T"
        titleLabel.stringValue = "Today’s plan"
        positionLabel.stringValue = "~\(max(1, plan.estimatedMinutes)) min"
        sourceLabel.stringValue = "Due work first, then new material"

        var lines = [
            "\(max(0, plan.dueCount)) due for review",
            "\(max(0, plan.newCount)) new questions",
            "\(max(0, plan.weakCount)) weak concepts to repair"
        ]
        if let resume = resumeSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !resume.isEmpty {
            lines.append("")
            lines.append("Continue: \(resume)")
        }
        setQuestionText(lines.joined(separator: "\n"))
        questionView.setAccessibilityLabel("Today’s practice plan")
        questionView.setAccessibilityHelp("Review the plan, then use the Start practice control.")
        needsLayout = true
    }

    /// Reuses the report surface for a topic-first mastery summary.
    func showMasterySummary(_ items: [PracticeTopicMasterySummary], headline: String = "Topic mastery") {
        let rows = items.map { item -> String in
            let percent = Int((min(1, max(0, item.masteredFraction)) * 100).rounded())
            let due = item.dueCount > 0 ? " · \(item.dueCount) due" : ""
            let learning = item.learningCount > 0 ? " · \(item.learningCount) learning" : ""
            let new = item.newCount > 0 ? " · \(item.newCount) new" : ""
            return "\(item.topic.title)  \(percent)% solid\(due)\(learning)\(new)"
        }
        showReport(([headline] + (rows.isEmpty ? ["No mastery data yet."] : rows)).joined(separator: "\n\n"))
        titleLabel.stringValue = headline
        sourceLabel.stringValue = "Practice the weakest or due topics next"
        reportView.setAccessibilityLabel(headline)
    }

    func showQuestion(
        topic: String,
        index: Int,
        total: Int,
        question: String,
        source: String,
        help: String?,
        answer: String,
        editable: Bool,
        options: [String] = [],
        selectedOption: Int? = nil,
        correctOption: Int? = nil,
        helpCaption: String = "ANSWER · 0.4×"
    ) {
        showingReport = false
        showingHelp = help != nil
        showingOptions = !options.isEmpty
        showingIdle = false
        badgeLabel.stringValue = "Q"
        titleLabel.stringValue = topic
        positionLabel.stringValue = "Question \(index) of \(total)"
        sourceLabel.stringValue = source
        setAccessibilityLabel("Practice question \(index) of \(total)")
        setQuestionText(question)
        if let help {
            helpLabel.stringValue = "\(helpCaption)\n\(help)"
            helpCard.isHidden = false
        } else {
            helpCard.isHidden = true
        }
        answerView.string = answer
        answerView.isEditable = editable && !showingOptions
        answerView.setAccessibilityHelp(editable ? "Type or dictate your answer before submitting." : "Previously submitted answer.")
        for (i, button) in optionButtons.enumerated() {
            if i < options.count {
                let label = "\(Character(UnicodeScalar(65 + i)!)).  \(options[i])"
                button.isHidden = false
                button.isEnabled = true
                styleLearnOption(
                    button,
                    title: label,
                    mark: practiceLearnOptionMark(index: i, selected: selectedOption, correct: correctOption)
                )
            } else {
                button.isHidden = true
            }
        }
        reportScroll.isHidden = true
        questionScroll.isHidden = false
        answerScroll.isHidden = showingOptions
        answerCaption.isHidden = showingOptions
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    func showReport(_ text: String) {
        showingReport = true
        showingHelp = false
        showingIdle = false
        badgeLabel.stringValue = "R"
        titleLabel.stringValue = "Run report"
        positionLabel.stringValue = "Done"
        sourceLabel.stringValue = "Saved to practice history"
        reportView.string = text
        reportView.setAccessibilityValue(text)
        reportView.textColor = NSColor.white.withAlphaComponent(0.9)
        helpCard.isHidden = true
        questionScroll.isHidden = true
        answerScroll.isHidden = true
        answerCaption.isHidden = true
        showingOptions = false
        optionButtons.forEach { $0.isHidden = true }
        reportScroll.isHidden = false
        needsLayout = true
    }

    func setHelp(_ text: String, caption: String = "ANSWER · 0.4×") {
        showingHelp = true
        helpLabel.stringValue = "\(caption)\n\(text)"
        helpCard.isHidden = false
        needsLayout = true
    }

    private func styleLearnOption(_ button: NSButton, title: String, mark: PracticeLearnOptionMark) {
        let fill: NSColor
        let border: NSColor
        let text: NSColor
        switch mark {
        case .unmarked:
            fill = NSColor.white.withAlphaComponent(0.06)
            border = NSColor.white.withAlphaComponent(0.2)
            text = NSColor.white.withAlphaComponent(0.92)
        case .selectedCorrect, .revealedCorrect:
            fill = NSColor.systemGreen.withAlphaComponent(0.22)
            border = NSColor.systemGreen.withAlphaComponent(0.9)
            text = NSColor.systemGreen
        case .selectedWrong:
            fill = NSColor.systemRed.withAlphaComponent(0.22)
            border = NSColor.systemRed.withAlphaComponent(0.9)
            text = NSColor.systemRed
        }
        button.layer?.backgroundColor = fill.cgColor
        button.layer?.borderColor = border.cgColor
        let para = NSMutableParagraphStyle()
        para.alignment = .left
        para.lineBreakMode = .byTruncatingTail
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: text,
            .paragraphStyle: para
        ])
    }

    private func setQuestionText(_ text: String) {
        questionView.textStorage?.setAttributedString(NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: NSColor.white.withAlphaComponent(0.92)
            ]
        ))
    }
}

@available(macOS 14.0, *)
final class PracticeRecallCard: NSVisualEffectView {
    let responseView = PracticeNavigableTextView()

    var onConfidenceSelection: ((PracticeRecallConfidence) -> Void)?
    var onCoverageChange: ((Int, Bool) -> Void)?
    var onGapRepairSubmit: ((String) -> Void)?
    var onGapRepairDraftChange: ((String) -> Void)?

    private let badge = NSView()
    private let badgeLabel = NSTextField(labelWithString: "Q")
    private let questionScroll = NSScrollView()
    private let questionView = NSTextView()
    private let topDivider = NSView()
    private let responseIcon = NSImageView()
    private let responseCaption = NSTextField(labelWithString: "YOUR RESPONSE")
    private let responseSurface = NSView()
    private let responseScroll = NSScrollView()
    private let repairView = PracticeGapRepairView(frame: .zero)
    private let columnDivider = NSView()
    private let keyIdeasIcon = NSImageView()
    private let keyIdeasCaption = NSTextField(labelWithString: "KEY IDEAS")
    private let keyIdeasScroll = NSScrollView()
    private let keyIdeasDocument = PracticeFlippedDocumentView(frame: .zero)
    private var ideaRows: [PracticeKeyIdeaRow] = []
    private let coverageIcon = NSImageView()
    private let coverageLabel = NSTextField(labelWithString: "")
    private let actionDivider = NSView()
    private let actionPromptLabel = NSTextField(wrappingLabelWithString: "")
    private let confidencePicker = PracticeConfidencePickerView(frame: .zero)
    private var showingReview = false
    private var showingRepair = false
    private var currentIdeas: [String] = []
    private var currentCoverage: [Bool] = []
    private var coverageIsEstimated = true
    private var allowsManualCoverage = false

    var selectedConfidence: PracticeRecallConfidence? {
        confidencePicker.selection
    }

    var repairDraft: String {
        repairView.text
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor(white: 0.035, alpha: 0.8).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.16
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: 0, height: 4)

        badge.wantsLayer = true
        badge.layer?.cornerRadius = 11
        badge.layer?.cornerCurve = .continuous
        badge.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
        badge.layer?.borderWidth = 1
        badge.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.55).cgColor
        addSubview(badge)

        badgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        badgeLabel.textColor = .systemBlue
        badgeLabel.alignment = .center
        badge.addSubview(badgeLabel)

        questionScroll.hasVerticalScroller = true
        questionScroll.autohidesScrollers = true
        questionScroll.borderType = .noBorder
        questionScroll.drawsBackground = false
        questionScroll.backgroundColor = .clear
        questionScroll.setAccessibilityLabel("Question")
        addSubview(questionScroll)

        questionView.isEditable = false
        questionView.isSelectable = true
        questionView.isRichText = false
        questionView.drawsBackground = false
        questionView.backgroundColor = .clear
        questionView.textColor = NSColor.white.withAlphaComponent(0.96)
        questionView.font = .systemFont(ofSize: 17, weight: .medium)
        questionView.textContainerInset = .zero
        questionView.textContainer?.lineFragmentPadding = 0
        questionView.isVerticallyResizable = true
        questionView.isHorizontallyResizable = false
        questionView.minSize = .zero
        questionView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        questionView.autoresizingMask = [.width]
        questionView.textContainer?.widthTracksTextView = true
        questionView.textContainer?.heightTracksTextView = false
        questionView.setAccessibilityLabel("Practice question")
        questionScroll.documentView = questionView

        for divider in [topDivider, columnDivider, actionDivider] {
            divider.wantsLayer = true
            divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
            addSubview(divider)
        }

        configureSymbol(responseIcon, name: "person.fill", color: .systemBlue, description: "Your response")
        configureCaption(responseCaption, color: .systemBlue)
        addSubview(responseIcon)
        addSubview(responseCaption)

        responseSurface.wantsLayer = true
        responseSurface.layer?.cornerRadius = 10
        responseSurface.layer?.cornerCurve = .continuous
        responseSurface.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.035).cgColor
        responseSurface.layer?.borderWidth = 1
        responseSurface.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
        responseSurface.setAccessibilityElement(true)
        responseSurface.setAccessibilityRole(.group)
        responseSurface.setAccessibilityLabel("Your response")
        addSubview(responseSurface)

        responseScroll.hasVerticalScroller = true
        responseScroll.autohidesScrollers = true
        responseScroll.borderType = .noBorder
        responseScroll.drawsBackground = false
        responseScroll.backgroundColor = .clear
        responseSurface.addSubview(responseScroll)

        responseView.isEditable = true
        responseView.isSelectable = true
        responseView.isRichText = false
        responseView.drawsBackground = false
        responseView.backgroundColor = .clear
        responseView.textColor = NSColor.white.withAlphaComponent(0.94)
        responseView.font = .systemFont(ofSize: 15, weight: .regular)
        responseView.insertionPointColor = .white
        responseView.textContainerInset = NSSize(width: 10, height: 8)
        responseView.textContainer?.lineFragmentPadding = 0
        responseView.isVerticallyResizable = true
        responseView.isHorizontallyResizable = false
        responseView.autoresizingMask = [.width]
        responseView.textContainer?.widthTracksTextView = true
        responseView.textContainer?.heightTracksTextView = false
        responseView.minSize = .zero
        responseView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        responseView.setAccessibilityLabel("Your response")
        responseView.setAccessibilityHelp("Write what you remember before revealing the key ideas.")
        responseScroll.documentView = responseView

        repairView.isHidden = true
        repairView.onSubmit = { [weak self] text in
            self?.onGapRepairSubmit?(text)
        }
        repairView.onDraftChange = { [weak self] text in
            self?.onGapRepairDraftChange?(text)
        }
        addSubview(repairView)

        configureSymbol(keyIdeasIcon, name: "lightbulb.fill", color: .appleGold, description: "Key ideas")
        configureCaption(keyIdeasCaption, color: .appleGold)
        addSubview(keyIdeasIcon)
        addSubview(keyIdeasCaption)

        keyIdeasScroll.hasVerticalScroller = true
        keyIdeasScroll.autohidesScrollers = true
        keyIdeasScroll.borderType = .noBorder
        keyIdeasScroll.drawsBackground = false
        keyIdeasScroll.backgroundColor = .clear
        keyIdeasDocument.setAccessibilityElement(true)
        keyIdeasDocument.setAccessibilityRole(.group)
        keyIdeasDocument.setAccessibilityLabel("Key idea list")
        keyIdeasScroll.documentView = keyIdeasDocument
        keyIdeasScroll.setAccessibilityElement(true)
        keyIdeasScroll.setAccessibilityRole(.group)
        keyIdeasScroll.setAccessibilityLabel("Key ideas")
        keyIdeasScroll.setAccessibilityHelp("Review the prepared ideas. Each idea announces whether it was covered.")
        addSubview(keyIdeasScroll)

        configureSymbol(coverageIcon, name: "checkmark.circle", color: .appleGreen, description: "Coverage")
        addSubview(coverageIcon)
        coverageLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        coverageLabel.textColor = .appleGreen
        coverageLabel.lineBreakMode = .byWordWrapping
        coverageLabel.maximumNumberOfLines = 2
        coverageLabel.setAccessibilityLabel("Coverage summary")
        addSubview(coverageLabel)

        actionPromptLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        actionPromptLabel.textColor = NSColor.white.withAlphaComponent(0.72)
        actionPromptLabel.maximumNumberOfLines = 2
        actionPromptLabel.lineBreakMode = .byWordWrapping
        addSubview(actionPromptLabel)

        confidencePicker.isHidden = true
        confidencePicker.onSelection = { [weak self] selection in
            self?.onConfidenceSelection?(selection)
        }
        addSubview(confidencePicker)

        showPrompt(question: "", response: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureSymbol(_ view: NSImageView, name: String, color: NSColor, description: String) {
        view.image = NSImage(systemSymbolName: name, accessibilityDescription: description)
        view.contentTintColor = color
        view.imageScaling = .scaleProportionallyDown
    }

    private func configureCaption(_ label: NSTextField, color: NSColor) {
        label.font = .systemFont(ofSize: 10.5, weight: .bold)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
    }

    func showPrompt(
        question: String,
        response: String,
        confidence: PracticeRecallConfidence? = nil,
        showsConfidencePicker: Bool = false
    ) {
        showingReview = false
        showingRepair = false
        setQuestionText(question)
        responseView.string = response
        responseView.isEditable = true
        responseView.setAccessibilityHelp("Write what you remember before revealing the key ideas.")
        responseSurface.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.035).cgColor
        responseSurface.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
        actionPromptLabel.stringValue = "Write what you remember, then reveal the key ideas."
        confidencePicker.selection = confidence
        confidencePicker.isHidden = !showsConfidencePicker
        repairView.isHidden = true
        setReviewElementsHidden(true)
        setAccessibilityLabel("Active Recall question")
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    func showReview(
        question: String,
        response: String,
        review: PracticeRecallReview,
        coverageIsEstimated: Bool = true,
        allowsManualCoverage: Bool = false
    ) {
        showingReview = true
        showingRepair = false
        self.coverageIsEstimated = coverageIsEstimated
        self.allowsManualCoverage = allowsManualCoverage
        setQuestionText(question)
        responseView.string = response
        responseView.isEditable = false
        responseView.setAccessibilityHelp("Your original response. Compare it with the key ideas.")
        responseSurface.layer?.backgroundColor = NSColor.clear.cgColor
        responseSurface.layer?.borderColor = NSColor.clear.cgColor
        repairView.isHidden = true
        confidencePicker.isHidden = true
        configureKeyIdeas(ideas: review.keyIdeas, covered: review.covered)
        actionPromptLabel.stringValue = "When should we ask you this again?"
        setReviewElementsHidden(false)
        setAccessibilityLabel("Active Recall review")
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    func setConfidencePickerVisible(
        _ visible: Bool,
        selected: PracticeRecallConfidence? = nil
    ) {
        confidencePicker.selection = selected
        confidencePicker.isHidden = !visible || showingReview
        needsLayout = true
    }

    func setManualCoverageEnabled(_ enabled: Bool) {
        allowsManualCoverage = enabled
        for (index, row) in ideaRows.enumerated() where currentIdeas.indices.contains(index) {
            row.configure(
                text: currentIdeas[index],
                covered: currentCoverage.indices.contains(index) && currentCoverage[index],
                allowsToggle: enabled
            )
        }
        updateCoverageSummary()
    }

    func setCoverage(_ covered: Bool, forIdeaAt index: Int, notify: Bool = false) {
        guard currentCoverage.indices.contains(index), ideaRows.indices.contains(index) else { return }
        currentCoverage[index] = covered
        ideaRows[index].configure(
            text: currentIdeas[index],
            covered: covered,
            allowsToggle: allowsManualCoverage
        )
        updateCoverageSummary()
        if notify { onCoverageChange?(index, covered) }
    }

    /// Shows a separate repair editor while retaining the original response above it.
    func beginGapRepair(missedIdea: String, draft: String = "") {
        guard showingReview else { return }
        showingRepair = true
        repairView.configure(missedIdea: missedIdea, draft: draft)
        repairView.isHidden = false
        actionPromptLabel.stringValue = "Repair one missed idea, then choose when to review again."
        needsLayout = true
        layoutSubtreeIfNeeded()
        window?.makeFirstResponder(repairView.textView)
    }

    var gapRepairResponder: NSResponder {
        repairView.textView
    }

    func endGapRepair() {
        showingRepair = false
        repairView.isHidden = true
        actionPromptLabel.stringValue = showingReview
            ? "When should we ask you this again?"
            : "Write what you remember, then reveal the key ideas."
        needsLayout = true
    }

    func setGapRepairValidationMessage(_ message: String?) {
        repairView.setValidationMessage(message)
    }

    private func setQuestionText(_ text: String) {
        questionView.string = text
        questionView.setAccessibilityValue(text)
    }

    private func configureKeyIdeas(ideas: [String], covered: [Bool]) {
        currentIdeas = ideas
        currentCoverage = ideas.indices.map { covered.indices.contains($0) && covered[$0] }
        ensureIdeaRows(count: ideas.count)
        for (index, row) in ideaRows.enumerated() {
            guard ideas.indices.contains(index) else {
                row.isHidden = true
                continue
            }
            row.configure(
                text: ideas[index],
                covered: currentCoverage[index],
                allowsToggle: allowsManualCoverage
            )
            row.onToggle = { [weak self] value in
                self?.setCoverage(value, forIdeaAt: index, notify: true)
            }
            row.isHidden = false
        }
        updateCoverageSummary()
    }

    private func ensureIdeaRows(count: Int) {
        while ideaRows.count < count {
            let row = PracticeKeyIdeaRow(frame: .zero)
            ideaRows.append(row)
            keyIdeasDocument.addSubview(row)
        }
    }

    private func updateCoverageSummary() {
        guard !currentIdeas.isEmpty else {
            coverageLabel.stringValue = "No prepared key ideas are available for this question."
            coverageIcon.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Information")
            coverageIcon.contentTintColor = .appleGold
            coverageLabel.textColor = .appleGold
            coverageLabel.setAccessibilityValue(coverageLabel.stringValue)
            return
        }
        let coveredCount = currentCoverage.filter { $0 }.count
        let prefix = coverageIsEstimated ? "Estimated: " : ""
        let correction = allowsManualCoverage ? " Select an idea to correct it." : ""
        coverageLabel.stringValue = "\(prefix)\(coveredCount) of \(currentIdeas.count) key ideas covered.\(correction)"
        coverageIcon.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Coverage")
        coverageIcon.contentTintColor = .appleGreen
        coverageLabel.textColor = .appleGreen
        coverageLabel.setAccessibilityValue(coverageLabel.stringValue)
        keyIdeasScroll.setAccessibilityValue("\(coveredCount) of \(currentIdeas.count) covered")
    }

    private func setReviewElementsHidden(_ hidden: Bool) {
        columnDivider.isHidden = hidden
        keyIdeasIcon.isHidden = hidden
        keyIdeasCaption.isHidden = hidden
        keyIdeasScroll.isHidden = hidden
        for (index, row) in ideaRows.enumerated() {
            row.isHidden = hidden || !currentIdeas.indices.contains(index)
        }
        coverageIcon.isHidden = hidden
        coverageLabel.isHidden = hidden
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height
        let pad: CGFloat = 20
        guard w > pad * 2, h > 160 else { return }

        let questionWidth = max(120, w - pad * 2 - 40)
        let naturalQuestionHeight = practiceTextHeight(
            questionView.string,
            font: questionView.font ?? .systemFont(ofSize: 17, weight: .medium),
            width: questionWidth
        )
        let maximumQuestionHeight = min(120, max(54, h * 0.3))
        let questionHeight = min(maximumQuestionHeight, max(42, naturalQuestionHeight + 4))
        let questionY = h - pad - questionHeight

        badge.frame = NSRect(x: pad, y: h - pad - 24, width: 24, height: 24)
        badgeLabel.frame = NSRect(x: 0, y: 4, width: 24, height: 16)
        questionScroll.frame = NSRect(x: pad + 40, y: questionY, width: questionWidth, height: questionHeight)
        sizePracticeTextDocument(questionView, in: questionScroll)
        topDivider.frame = NSRect(x: pad, y: questionY - 10, width: max(0, w - pad * 2), height: 1)

        let actionButtonReserve: CGFloat = 46
        let contentBottom: CGFloat
        if showingReview {
            actionPromptLabel.frame = NSRect(x: pad, y: actionButtonReserve + 5, width: max(80, w - pad * 2), height: 28)
            coverageIcon.frame = NSRect(x: pad, y: actionButtonReserve + 39, width: 16, height: 16)
            coverageLabel.frame = NSRect(x: pad + 24, y: actionButtonReserve + 35, width: max(80, w - pad * 2 - 24), height: 30)
            actionDivider.frame = NSRect(x: pad, y: actionButtonReserve + 70, width: max(0, w - pad * 2), height: 1)
            contentBottom = actionButtonReserve + 80
        } else if !confidencePicker.isHidden {
            confidencePicker.frame = NSRect(x: pad, y: actionButtonReserve + 4, width: min(300, max(180, w - pad * 2)), height: 30)
            actionPromptLabel.frame = NSRect(x: pad, y: confidencePicker.frame.maxY + 5, width: max(80, w - pad * 2), height: 28)
            actionDivider.frame = NSRect(x: pad, y: actionPromptLabel.frame.maxY + 5, width: max(0, w - pad * 2), height: 1)
            contentBottom = actionDivider.frame.maxY + 8
        } else {
            confidencePicker.frame = .zero
            actionPromptLabel.frame = NSRect(x: pad, y: actionButtonReserve + 8, width: max(80, w - pad * 2), height: 28)
            actionDivider.frame = NSRect(x: pad, y: actionButtonReserve + 40, width: max(0, w - pad * 2), height: 1)
            contentBottom = actionButtonReserve + 50
        }

        let contentTop = topDivider.frame.minY - 12
        let contentHeight = max(54, contentTop - contentBottom)

        if showingReview {
            // The shipped 700-point window yields a 644-point card; preserve the
            // selected Key-Ideas-on-the-right design there and stack only below it.
            let usesStackedLayout = w < 620
            if usesStackedLayout {
                layoutStackedReview(
                    x: pad,
                    y: contentBottom,
                    width: w - pad * 2,
                    height: contentHeight
                )
            } else {
                layoutColumnReview(
                    x: pad,
                    y: contentBottom,
                    width: w - pad * 2,
                    height: contentHeight
                )
            }
        } else {
            responseIcon.frame = NSRect(x: pad, y: contentTop - 20, width: 16, height: 16)
            responseCaption.frame = NSRect(x: pad + 24, y: contentTop - 20, width: max(80, w - pad * 2 - 24), height: 16)
            responseSurface.isHidden = false
            responseSurface.frame = NSRect(x: pad, y: contentBottom, width: max(120, w - pad * 2), height: max(42, contentHeight - 30))
            repairView.isHidden = true
            columnDivider.frame = .zero
            keyIdeasScroll.frame = .zero
        }

        responseScroll.frame = responseSurface.bounds
        if !responseSurface.isHidden {
            sizePracticeTextDocument(responseView, in: responseScroll)
        }
        layoutIdeaRows()
    }

    private func layoutColumnReview(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let columnGap: CGFloat = 25
        let columnWidth = max(120, floor((width - columnGap) / 2))
        let rightX = x + columnWidth + columnGap
        let headerY = y + height - 20
        let bodyHeight = max(32, height - 30)

        responseIcon.frame = NSRect(x: x, y: headerY, width: 16, height: 16)
        responseCaption.frame = NSRect(x: x + 24, y: headerY, width: max(60, columnWidth - 24), height: 16)
        layoutResponseArea(NSRect(x: x, y: y, width: columnWidth, height: bodyHeight))

        columnDivider.frame = NSRect(x: x + columnWidth + floor(columnGap / 2), y: y, width: 1, height: height)
        keyIdeasIcon.frame = NSRect(x: rightX, y: headerY, width: 16, height: 16)
        keyIdeasCaption.frame = NSRect(x: rightX + 24, y: headerY, width: max(60, columnWidth - 24), height: 16)
        keyIdeasScroll.frame = NSRect(x: rightX, y: y, width: columnWidth, height: bodyHeight)
    }

    private func layoutStackedReview(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let fixedHeight: CGFloat = 65
        let bodySpace = max(48, height - fixedHeight)
        let responseBodyHeight = max(24, floor(bodySpace * (showingRepair ? 0.58 : 0.48)))
        let keyBodyHeight = max(24, bodySpace - responseBodyHeight)

        keyIdeasScroll.frame = NSRect(x: x, y: y, width: width, height: keyBodyHeight)
        keyIdeasIcon.frame = NSRect(x: x, y: keyIdeasScroll.frame.maxY + 5, width: 16, height: 16)
        keyIdeasCaption.frame = NSRect(x: x + 24, y: keyIdeasScroll.frame.maxY + 5, width: max(60, width - 24), height: 16)

        let dividerY = keyIdeasCaption.frame.maxY + 7
        columnDivider.frame = NSRect(x: x, y: dividerY, width: width, height: 1)
        let responseY = dividerY + 8
        layoutResponseArea(NSRect(x: x, y: responseY, width: width, height: responseBodyHeight))
        responseIcon.frame = NSRect(x: x, y: responseY + responseBodyHeight + 5, width: 16, height: 16)
        responseCaption.frame = NSRect(x: x + 24, y: responseY + responseBodyHeight + 5, width: max(60, width - 24), height: 16)
    }

    private func layoutResponseArea(_ frame: NSRect) {
        if showingRepair {
            if frame.height < 92 {
                responseSurface.isHidden = true
                repairView.frame = frame
            } else {
                responseSurface.isHidden = false
                let repairHeight = max(50, min(108, floor(frame.height * 0.56)))
                repairView.frame = NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: repairHeight)
                responseSurface.frame = NSRect(
                    x: frame.minX,
                    y: repairView.frame.maxY + 7,
                    width: frame.width,
                    height: max(28, frame.height - repairHeight - 7)
                )
            }
            repairView.isHidden = false
        } else {
            responseSurface.isHidden = false
            responseSurface.frame = frame
            repairView.isHidden = true
        }
        responseScroll.frame = responseSurface.bounds
        if !responseSurface.isHidden {
            sizePracticeTextDocument(responseView, in: responseScroll)
        }
        repairView.needsLayout = true
    }

    private func layoutIdeaRows() {
        guard !keyIdeasScroll.isHidden, keyIdeasScroll.bounds.width > 1 else { return }
        let width = max(1, keyIdeasScroll.contentSize.width)
        var y: CGFloat = 0
        for (index, row) in ideaRows.enumerated() where currentIdeas.indices.contains(index) {
            let rowHeight = row.preferredHeight(forWidth: width)
            row.frame = NSRect(x: 0, y: y, width: width, height: rowHeight)
            y += rowHeight + 6
        }
        keyIdeasDocument.frame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: max(keyIdeasScroll.contentSize.height, max(0, y - 6))
        )
    }
}

@available(macOS 14.0, *)
private final class PracticeKeyIdeaRow: NSButton {
    private let icon = NSImageView()
    private let label = NSTextField(wrappingLabelWithString: "")
    private var isCovered = false
    private var allowsToggle = false
    var onToggle: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = ""
        isBordered = false
        bezelStyle = .inline
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleCoverage)
        focusRingType = .exterior
        wantsLayer = true
        layer?.cornerRadius = 7
        setAccessibilityRole(.checkBox)

        icon.imageScaling = .scaleProportionallyDown
        icon.setAccessibilityElement(false)
        addSubview(icon)
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = NSColor.white.withAlphaComponent(0.88)
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setAccessibilityElement(false)
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { allowsToggle && isEnabled }

    func configure(text: String, covered: Bool, allowsToggle: Bool) {
        isCovered = covered
        self.allowsToggle = allowsToggle
        isEnabled = allowsToggle
        let color = covered ? NSColor.appleGreen : NSColor.appleGold.withAlphaComponent(0.78)
        let symbol = covered ? "checkmark.circle" : "circle"
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: covered ? "Covered" : "Review")
        icon.contentTintColor = color
        label.stringValue = text
        label.textColor = covered ? NSColor.white.withAlphaComponent(0.92) : NSColor.white.withAlphaComponent(0.72)
        layer?.backgroundColor = allowsToggle ? NSColor.white.withAlphaComponent(0.025).cgColor : NSColor.clear.cgColor
        setAccessibilityLabel(text)
        setAccessibilityValue(covered ? 1 : 0)
        setAccessibilityHelp(allowsToggle
            ? "Toggle whether your response covered this idea."
            : (covered ? "Covered by your response." : "Review this missed idea."))
        toolTip = allowsToggle ? "Click to correct estimated coverage" : nil
    }

    func preferredHeight(forWidth width: CGFloat) -> CGFloat {
        let textHeight = practiceTextHeight(
            label.stringValue,
            font: label.font ?? .systemFont(ofSize: 13),
            width: max(40, width - 34)
        )
        return max(38, min(132, textHeight + 12))
    }

    @objc private func toggleCoverage() {
        guard allowsToggle else { return }
        isCovered.toggle()
        configure(text: label.stringValue, covered: isCovered, allowsToggle: true)
        onToggle?(isCovered)
    }

    override func layout() {
        super.layout()
        icon.frame = NSRect(x: 4, y: max(2, bounds.height - 24), width: 18, height: 18)
        label.frame = NSRect(x: 32, y: 4, width: max(40, bounds.width - 36), height: max(18, bounds.height - 8))
    }
}

@available(macOS 14.0, *)
private final class PracticeConfidencePickerView: NSView {
    var onSelection: ((PracticeRecallConfidence) -> Void)?
    var selection: PracticeRecallConfidence? {
        didSet { refreshButtons() }
    }

    private var buttons: [HoverButton] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Confidence before reveal")
        for (index, confidence) in PracticeRecallConfidence.allCases.enumerated() {
            let button = HoverButton(frame: .zero)
            button.title = confidence.title
            button.tag = index
            button.isBordered = false
            button.font = .systemFont(ofSize: 11.5, weight: .semibold)
            button.wantsLayer = true
            button.layer?.cornerRadius = 7
            button.layer?.borderWidth = 1
            button.target = self
            button.action = #selector(selectConfidence(_:))
            button.setAccessibilityLabel("Confidence: \(confidence.title)")
            button.setAccessibilityHelp(confidence.practiceAccessibilityHelp)
            addSubview(button)
            buttons.append(button)
        }
        refreshButtons()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func selectConfidence(_ sender: NSButton) {
        guard PracticeRecallConfidence.allCases.indices.contains(sender.tag) else { return }
        let confidence = PracticeRecallConfidence.allCases[sender.tag]
        selection = confidence
        setAccessibilityValue(confidence.title)
        onSelection?(confidence)
    }

    private func refreshButtons() {
        for button in buttons {
            let selectedIndex = selection.flatMap { PracticeRecallConfidence.allCases.firstIndex(of: $0) }
            let selected = selectedIndex == button.tag
            let accent = selected ? NSColor.systemBlue : NSColor.white.withAlphaComponent(0.72)
            button.contentTintColor = accent
            button.configureHoverColors(
                normalBackground: accent.withAlphaComponent(selected ? 0.18 : 0.06),
                hoverBackground: accent.withAlphaComponent(selected ? 0.26 : 0.12),
                pressBackground: accent.withAlphaComponent(0.3),
                normalBorder: accent.withAlphaComponent(selected ? 0.7 : 0.22),
                hoverBorder: accent.withAlphaComponent(0.7)
            )
            button.setAccessibilityValue(selected ? 1 : 0)
        }
    }

    override func layout() {
        super.layout()
        guard !buttons.isEmpty else { return }
        let gap: CGFloat = 6
        let width = max(40, (bounds.width - gap * CGFloat(buttons.count - 1)) / CGFloat(buttons.count))
        for (index, button) in buttons.enumerated() {
            button.frame = NSRect(x: CGFloat(index) * (width + gap), y: 0, width: width, height: bounds.height)
        }
    }
}

@available(macOS 14.0, *)
private final class PracticeGapRepairView: NSView, NSTextViewDelegate {
    let textView = PracticeNavigableTextView()
    var onSubmit: ((String) -> Void)?
    var onDraftChange: ((String) -> Void)?
    var text: String { textView.string.trimmingCharacters(in: .whitespacesAndNewlines) }

    private let promptLabel = NSTextField(wrappingLabelWithString: "")
    private let scrollView = NSScrollView()
    private let submitButton = HoverButton(frame: .zero)
    private let validationLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.055).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.38).cgColor
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("One-gap repair")

        promptLabel.font = .systemFont(ofSize: 10.5, weight: .medium)
        promptLabel.textColor = NSColor.white.withAlphaComponent(0.78)
        promptLabel.maximumNumberOfLines = 2
        addSubview(promptLabel)

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        addSubview(scrollView)

        textView.isEditable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.font = .systemFont(ofSize: 12.5)
        textView.textContainerInset = NSSize(width: 5, height: 4)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.setAccessibilityLabel("Repair sentence")
        textView.setAccessibilityHelp("Add one sentence that covers the missed idea.")
        textView.delegate = self
        scrollView.documentView = textView

        submitButton.title = "Save"
        submitButton.isBordered = false
        submitButton.font = .systemFont(ofSize: 11, weight: .semibold)
        submitButton.wantsLayer = true
        submitButton.layer?.cornerRadius = 7
        submitButton.layer?.borderWidth = 1
        submitButton.configureHoverColors(accent: .systemBlue)
        submitButton.target = self
        submitButton.action = #selector(submit)
        submitButton.setAccessibilityLabel("Save repair")
        addSubview(submitButton)

        validationLabel.font = .systemFont(ofSize: 9.5, weight: .medium)
        validationLabel.textColor = .systemRed
        validationLabel.alignment = .right
        validationLabel.lineBreakMode = .byTruncatingTail
        validationLabel.isHidden = true
        addSubview(validationLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func textDidChange(_ notification: Notification) {
        onDraftChange?(textView.string)
    }

    func configure(missedIdea: String, draft: String) {
        promptLabel.stringValue = "Add one sentence for: \(missedIdea)"
        promptLabel.setAccessibilityValue(promptLabel.stringValue)
        textView.string = draft
        setValidationMessage(nil)
        needsLayout = true
    }

    func setValidationMessage(_ message: String?) {
        let value = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        validationLabel.stringValue = value
        validationLabel.isHidden = value.isEmpty
        if !value.isEmpty {
            NSAccessibility.post(element: textView, notification: .announcementRequested, userInfo: [
                NSAccessibility.NotificationUserInfoKey.announcement: value,
                NSAccessibility.NotificationUserInfoKey.priority: NSAccessibilityPriorityLevel.high.rawValue
            ])
        }
    }

    @objc private func submit() {
        let value = text
        guard !value.isEmpty else {
            setValidationMessage("Write one repair sentence first.")
            return
        }
        setValidationMessage(nil)
        onSubmit?(value)
    }

    override func layout() {
        super.layout()
        let pad: CGFloat = 8
        let buttonWidth: CGFloat = min(64, max(50, bounds.width * 0.2))
        let promptHeight = min(34, practiceTextHeight(
            promptLabel.stringValue,
            font: promptLabel.font ?? .systemFont(ofSize: 10.5),
            width: max(60, bounds.width - pad * 2)
        ))
        promptLabel.frame = NSRect(x: pad, y: bounds.height - pad - promptHeight, width: max(60, bounds.width - pad * 2), height: promptHeight)
        submitButton.frame = NSRect(x: bounds.width - pad - buttonWidth, y: pad, width: buttonWidth, height: min(26, max(20, bounds.height - promptHeight - pad * 3)))
        validationLabel.frame = NSRect(x: pad, y: submitButton.frame.maxY + 1, width: bounds.width - pad * 2, height: 12)
        scrollView.frame = NSRect(
            x: pad,
            y: pad,
            width: max(30, submitButton.frame.minX - pad * 2),
            height: max(20, promptLabel.frame.minY - pad * 2)
        )
        sizePracticeTextDocument(textView, in: scrollView)
    }
}

@available(macOS 14.0, *)
final class PracticeProgressSegmentsView: NSView {
    var completed = 0 {
        didSet {
            needsDisplay = true
            updateAccessibilityProgress()
        }
    }
    var total = 0 {
        didSet {
            needsDisplay = true
            updateAccessibilityProgress()
        }
    }
    var queuedReviews = 0 {
        didSet {
            needsDisplay = true
            updateAccessibilityProgress()
        }
    }
    var currentIndex = 0 {
        didSet {
            needsDisplay = true
            updateAccessibilityProgress()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.progressIndicator)
        setAccessibilityLabel("Practice progress")
        setAccessibilityMinValue(0)
        setAccessibilityMaxValue(1)
        updateAccessibilityProgress()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setAccessibilityElement(true)
        setAccessibilityRole(.progressIndicator)
        setAccessibilityLabel("Practice progress")
        setAccessibilityMinValue(0)
        setAccessibilityMaxValue(1)
        updateAccessibilityProgress()
    }

    private func updateAccessibilityProgress() {
        let safeTotal = max(0, total)
        let safeCompleted = min(safeTotal, max(0, completed))
        let value = safeTotal == 0 ? 0 : Double(safeCompleted) / Double(safeTotal)
        let currentText = safeTotal > 0 ? ", current question \(min(safeTotal, max(0, currentIndex) + 1))" : ""
        let reviewText = queuedReviews > 0 ? ", with \(queuedReviews) review questions queued" : ""
        setAccessibilityValue(value)
        setAccessibilityHelp("\(safeCompleted) of \(safeTotal) questions completed\(currentText)\(reviewText).")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard total > 0 else { return }
        let segmentCount = min(total, 10)
        let completedSegments = min(
            segmentCount,
            Int(ceil(Double(max(0, completed)) / Double(total) * Double(segmentCount)))
        )
        let currentSegment = min(
            segmentCount - 1,
            max(0, Int(floor(Double(max(0, currentIndex)) / Double(total) * Double(segmentCount))))
        )
        let gap: CGFloat = 5
        let segmentWidth = max(4, (bounds.width - CGFloat(segmentCount - 1) * gap) / CGFloat(segmentCount))
        let segmentHeight = min(6, bounds.height)
        let y = floor((bounds.height - segmentHeight) / 2)
        for index in 0..<segmentCount {
            let rect = NSRect(
                x: CGFloat(index) * (segmentWidth + gap),
                y: y,
                width: segmentWidth,
                height: segmentHeight
            )
            let color: NSColor
            if index < completedSegments {
                color = .systemBlue
            } else if index == currentSegment {
                color = NSColor.systemBlue.withAlphaComponent(0.48)
            } else {
                color = NSColor.white.withAlphaComponent(0.24)
            }
            color.setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: segmentHeight / 2, yRadius: segmentHeight / 2)
            path.fill()
            if index == currentSegment, index >= completedSegments {
                NSColor.systemBlue.setStroke()
                path.lineWidth = 1
                path.stroke()
            }
        }
    }
}
