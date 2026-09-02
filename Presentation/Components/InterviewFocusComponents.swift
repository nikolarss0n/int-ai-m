import Cocoa

enum QuestionBurstPhase: String, Equatable {
    case queued
    case generating
    case answering
    case ready
    case failed

    var title: String {
        switch self {
        case .queued: return "QUEUED"
        case .generating: return "GENERATING"
        case .answering: return "ANSWERING"
        case .ready: return "READY"
        case .failed: return "FAILED"
        }
    }

    var color: NSColor {
        switch self {
        case .queued: return NSColor.white.withAlphaComponent(0.62)
        case .generating: return .appleGold
        case .answering: return .systemBlue
        case .ready: return .appleGreen
        case .failed: return .appleRed
        }
    }
}

struct QuestionBurstEntry: Identifiable, Equatable {
    let id: UUID
    let sequence: Int
    let question: String
    let topic: String
    let detectedAt: Date
    var phase: QuestionBurstPhase
    var answer: String
    var latencyMs: Int?
}

struct QuestionBurstState {
    private(set) var entries: [QuestionBurstEntry] = []
    private(set) var selectedID: UUID?
    private(set) var activeAIWork: Set<UUID> = []

    var visibleEntries: [QuestionBurstEntry] {
        Array(entries.sorted(by: { $0.sequence > $1.sequence }).prefix(3))
    }

    var selectedEntry: QuestionBurstEntry? {
        guard let selectedID else { return visibleEntries.first }
        return entries.first(where: { $0.id == selectedID })
    }

    var isAIWorking: Bool {
        !activeAIWork.isEmpty
    }

    var latestActiveWorkID: UUID? {
        entries
            .filter { activeAIWork.contains($0.id) }
            .max(by: { $0.sequence < $1.sequence })?
            .id
    }

    mutating func beginAIWork(turnID: UUID) {
        activeAIWork.insert(turnID)
        updatePhase(.generating, for: turnID, unlessReady: true)
    }

    mutating func endAIWork(turnID: UUID) {
        activeAIWork.remove(turnID)
    }

    mutating func endAllAIWork() {
        activeAIWork.removeAll()
    }

    mutating func receiveQuestion(turnID: UUID, sequence: Int, text: String, topic: String) {
        if let index = entries.firstIndex(where: { $0.id == turnID }) {
            let existing = entries[index]
            entries[index] = QuestionBurstEntry(
                id: existing.id,
                sequence: existing.sequence,
                question: text,
                topic: topic,
                detectedAt: existing.detectedAt,
                phase: existing.phase,
                answer: existing.answer,
                latencyMs: existing.latencyMs
            )
        } else {
            entries.append(QuestionBurstEntry(
                id: turnID,
                sequence: sequence,
                question: text,
                topic: topic,
                detectedAt: Date(),
                phase: activeAIWork.contains(turnID) ? .generating : .queued,
                answer: "",
                latencyMs: nil
            ))
        }

        // Slot 1 is always the newest detected question. A slower callback from
        // an older turn must never steal focus from a later spoken question.
        selectedID = visibleEntries.first?.id
    }

    mutating func startStreaming(turnID: UUID) {
        updatePhase(.answering, for: turnID, unlessReady: true)
    }

    mutating func updateAnswer(turnID: UUID, content: String) {
        guard let index = entries.firstIndex(where: { $0.id == turnID }) else { return }
        entries[index].answer = content
        if entries[index].phase != .ready {
            entries[index].phase = .answering
        }
    }

    mutating func finishAnswer(turnID: UUID, content: String, latencyMs: Int?) {
        guard let index = entries.firstIndex(where: { $0.id == turnID }) else {
            activeAIWork.remove(turnID)
            return
        }
        entries[index].answer = content
        entries[index].latencyMs = latencyMs
        entries[index].phase = .ready
        activeAIWork.remove(turnID)
    }

    mutating func fail(turnID: UUID) {
        updatePhase(.failed, for: turnID, unlessReady: true)
        activeAIWork.remove(turnID)
    }

    mutating func select(_ id: UUID) {
        guard visibleEntries.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    mutating func clear() {
        entries.removeAll()
        selectedID = nil
        activeAIWork.removeAll()
    }

    func visiblePosition(of id: UUID?) -> Int? {
        guard let id, let index = visibleEntries.firstIndex(where: { $0.id == id }) else { return nil }
        return index + 1
    }

    private mutating func updatePhase(_ phase: QuestionBurstPhase, for id: UUID, unlessReady: Bool) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        if unlessReady && entries[index].phase == .ready { return }
        entries[index].phase = phase
    }
}

final class QuestionBurstStripView: NSView {
    var onSelect: ((UUID) -> Void)?

    private var entries: [QuestionBurstEntry] = []
    private var selectedID: UUID?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.24).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Question burst")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(entries: [QuestionBurstEntry], selectedID: UUID?) {
        let sameContent = self.entries.count == entries.count && zip(self.entries, entries).allSatisfy { current, next in
            current.id == next.id &&
            current.sequence == next.sequence &&
            current.question == next.question &&
            current.phase == next.phase
        }
        guard !sameContent || self.selectedID != selectedID else { return }
        self.entries = entries
        self.selectedID = selectedID
        rebuild()
    }

    override func layout() {
        super.layout()
        guard !entries.isEmpty else { return }

        let segmentWidth = bounds.width / CGFloat(entries.count)
        for (index, segment) in subviews.filter({ $0.identifier?.rawValue.hasPrefix("burstSegment-") == true }).enumerated() {
            segment.frame = NSRect(
                x: CGFloat(index) * segmentWidth,
                y: 0,
                width: segmentWidth,
                height: bounds.height
            )
            layoutSegment(segment, width: segmentWidth)
        }
    }

    private func rebuild() {
        subviews.forEach { $0.removeFromSuperview() }

        guard !entries.isEmpty else {
            let placeholder = NSTextField(labelWithString: "Listening for the next interview question…")
            placeholder.frame = bounds.insetBy(dx: 18, dy: 18)
            placeholder.autoresizingMask = [.width, .height]
            placeholder.font = .systemFont(ofSize: 13, weight: .medium)
            placeholder.textColor = NSColor.white.withAlphaComponent(0.68)
            placeholder.alignment = .center
            addSubview(placeholder)
            return
        }

        for (index, entry) in entries.enumerated() {
            let segment = NSView(frame: .zero)
            segment.identifier = NSUserInterfaceItemIdentifier("burstSegment-\(entry.id.uuidString)")
            segment.wantsLayer = true
            segment.layer?.cornerRadius = 11
            segment.layer?.cornerCurve = .continuous

            if entry.id == selectedID {
                segment.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.09).cgColor
                segment.layer?.borderWidth = 1.5
                segment.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.88).cgColor
                segment.layer?.shadowColor = NSColor.systemBlue.cgColor
                segment.layer?.shadowOpacity = 0.18
                segment.layer?.shadowRadius = 8
            }

            let number = NSTextField(labelWithString: "\(index + 1)")
            number.identifier = NSUserInterfaceItemIdentifier("number")
            number.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            number.textColor = NSColor.white.withAlphaComponent(0.92)
            number.alignment = .left
            number.drawsBackground = false
            number.isBezeled = false
            number.isEditable = false
            number.isSelectable = false
            segment.addSubview(number)

            let status = NSTextField(labelWithString: entry.phase.title)
            status.identifier = NSUserInterfaceItemIdentifier("status")
            status.font = .systemFont(ofSize: 9.5, weight: .bold)
            status.textColor = entry.phase.color
            status.alignment = .center
            status.wantsLayer = true
            status.layer?.cornerRadius = 7
            status.layer?.backgroundColor = entry.phase.color.withAlphaComponent(0.12).cgColor
            segment.addSubview(status)

            if entry.phase == .ready {
                let readyDot = NSView(frame: .zero)
                readyDot.identifier = NSUserInterfaceItemIdentifier("phaseDot")
                readyDot.wantsLayer = true
                readyDot.layer?.cornerRadius = 4
                readyDot.layer?.backgroundColor = NSColor.appleGreen.cgColor
                segment.addSubview(readyDot)
            } else if entry.phase == .generating {
                let progress = NSProgressIndicator(frame: .zero)
                progress.identifier = NSUserInterfaceItemIdentifier("phaseProgress")
                progress.style = .spinning
                progress.controlSize = .small
                progress.startAnimation(nil)
                segment.addSubview(progress)
            }

            let question = NSTextField(wrappingLabelWithString: entry.question)
            question.identifier = NSUserInterfaceItemIdentifier("question")
            question.font = .systemFont(ofSize: 12.5, weight: entry.id == selectedID ? .medium : .regular)
            question.textColor = NSColor.white.withAlphaComponent(entry.id == selectedID ? 0.98 : 0.80)
            question.maximumNumberOfLines = 2
            question.lineBreakMode = .byWordWrapping
            question.cell?.truncatesLastVisibleLine = true
            segment.addSubview(question)

            let button = NSButton(frame: .zero)
            button.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)
            button.title = ""
            button.isBordered = false
            button.target = self
            button.action = #selector(selectSegment(_:))
            button.setAccessibilityLabel("Question \(index + 1) of \(entries.count), \(entry.phase.title.lowercased()): \(entry.question)")
            button.setAccessibilityRole(.button)
            segment.addSubview(button)

            if index > 0 {
                let divider = NSView(frame: .zero)
                divider.identifier = NSUserInterfaceItemIdentifier("divider")
                divider.wantsLayer = true
                divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
                segment.addSubview(divider)
            }

            addSubview(segment)
        }

        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func layoutSegment(_ segment: NSView, width: CGFloat) {
        let topY = max(42, bounds.height - 27)
        segment.subviews.first(where: { $0.identifier?.rawValue == "number" })?.frame = NSRect(x: 12, y: topY, width: 18, height: 18)
        segment.subviews.first(where: { $0.identifier?.rawValue == "status" })?.frame = NSRect(x: 39, y: topY + 2, width: min(82, max(62, width - 68)), height: 16)
        segment.subviews.first(where: { $0.identifier?.rawValue == "phaseDot" })?.frame = NSRect(x: min(width - 18, 126), y: topY + 6, width: 8, height: 8)
        segment.subviews.first(where: { $0.identifier?.rawValue == "phaseProgress" })?.frame = NSRect(x: min(width - 24, 122), y: topY + 1, width: 18, height: 18)
        segment.subviews.first(where: { $0.identifier?.rawValue == "question" })?.frame = NSRect(x: 12, y: 9, width: max(50, width - 24), height: max(28, topY - 12))
        segment.subviews.first(where: { $0 is NSButton })?.frame = segment.bounds
        segment.subviews.first(where: { $0.identifier?.rawValue == "divider" })?.frame = NSRect(x: 0, y: 10, width: 1, height: max(20, bounds.height - 20))
    }

    @objc private func selectSegment(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        onSelect?(id)
    }
}

final class AIActivityCapsuleView: NSVisualEffectView {
    enum Mode: Equatable {
        case idle
        case listening(speaking: Bool)
        case working(questionNumber: Int?)
        case ready
    }

    private let compact: Bool
    private let recordingDot = NSView()
    private let sparkleView = NSImageView()
    private let stateLabel = NSTextField(labelWithString: "Ready")
    private let elapsedLabel = NSTextField(labelWithString: "")
    private let waveformView = NSView()
    private var waveformBars: [NSView] = []
    private var mode: Mode = .idle
    private var isRecording = false
    private var waveformIsAnimated = false
    private var waveformColor: NSColor?

    init(frame frameRect: NSRect, compact: Bool = false) {
        self.compact = compact
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = frameRect.height / 2
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.black.withAlphaComponent(compact ? 0.18 : 0.30).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

        recordingDot.wantsLayer = true
        recordingDot.layer?.cornerRadius = 4
        addSubview(recordingDot)

        sparkleView.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "AI")
        sparkleView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        sparkleView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(sparkleView)

        stateLabel.font = .systemFont(ofSize: compact ? 10.5 : 12, weight: .semibold)
        stateLabel.lineBreakMode = .byTruncatingTail
        addSubview(stateLabel)

        elapsedLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        elapsedLabel.alignment = .right
        addSubview(elapsedLabel)

        waveformView.wantsLayer = true
        addSubview(waveformView)
        buildWaveformBars()

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        update(mode: .idle, isRecording: false, elapsed: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(mode: Mode, isRecording: Bool, elapsed: String) {
        self.mode = mode
        self.isRecording = isRecording
        elapsedLabel.stringValue = elapsed
        recordingDot.isHidden = compact || !isRecording

        let accent: NSColor
        let label: String
        let animate: Bool

        switch mode {
        case .idle:
            accent = NSColor.white.withAlphaComponent(0.50)
            label = "Ready"
            animate = false
        case .listening(let speaking):
            accent = .appleGreen
            label = speaking ? "Hearing speech" : "Listening"
            animate = speaking
        case .working(let questionNumber):
            accent = .appleGold
            label = questionNumber.map { "AI working · Q\($0)" } ?? "AI working"
            animate = true
        case .ready:
            accent = .appleGreen
            label = "Answer ready"
            animate = false
        }

        stateLabel.stringValue = label
        stateLabel.textColor = accent
        sparkleView.contentTintColor = accent
        sparkleView.isHidden = compact || {
            if case .working = mode { return false }
            return true
        }()
        elapsedLabel.textColor = NSColor.white.withAlphaComponent(0.72)
        recordingDot.layer?.backgroundColor = NSColor.appleRed.cgColor

        layer?.borderColor = accent.withAlphaComponent(mode.isWorking ? 0.70 : 0.18).cgColor
        layer?.backgroundColor = accent.withAlphaComponent(mode.isWorking ? 0.10 : (compact ? 0.035 : 0.055)).cgColor
        setWaveform(color: accent, animated: animate)

        let recordingDescription = isRecording ? ", recording" : ""
        let elapsedDescription = elapsed.isEmpty ? "" : ", \(elapsed)"
        setAccessibilityLabel("\(label)\(recordingDescription)\(elapsedDescription)")
        needsLayout = true
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2

        if compact {
            waveformView.frame = NSRect(x: 10, y: (bounds.height - 16) / 2, width: 38, height: 16)
            stateLabel.frame = NSRect(x: 53, y: (bounds.height - 16) / 2, width: max(30, bounds.width - 61), height: 16)
            recordingDot.frame = .zero
            sparkleView.frame = .zero
            elapsedLabel.frame = .zero
        } else {
            recordingDot.frame = NSRect(x: 12, y: (bounds.height - 8) / 2, width: 8, height: 8)
            sparkleView.frame = NSRect(x: 27, y: (bounds.height - 14) / 2, width: 14, height: 14)
            stateLabel.frame = NSRect(x: sparkleView.isHidden ? 29 : 46, y: (bounds.height - 18) / 2, width: max(80, bounds.width - 166), height: 18)
            waveformView.frame = NSRect(x: bounds.width - 110, y: (bounds.height - 18) / 2, width: 62, height: 18)
            elapsedLabel.frame = NSRect(x: bounds.width - 45, y: (bounds.height - 16) / 2, width: 36, height: 16)
        }

        layoutWaveformBars()
    }

    private func buildWaveformBars() {
        waveformBars.forEach { $0.removeFromSuperview() }
        waveformBars = (0..<9).map { _ in
            let bar = NSView(frame: .zero)
            bar.wantsLayer = true
            bar.layer?.cornerRadius = 1
            waveformView.addSubview(bar)
            return bar
        }
    }

    private func layoutWaveformBars() {
        guard !waveformBars.isEmpty, waveformView.bounds.width > 0 else { return }
        let barWidth: CGFloat = 2
        let spacing = max(1.5, (waveformView.bounds.width - CGFloat(waveformBars.count) * barWidth) / CGFloat(waveformBars.count - 1))
        let heights: [CGFloat] = [5, 9, 13, 8, 15, 10, 13, 8, 5]
        for (index, bar) in waveformBars.enumerated() {
            let height = min(waveformView.bounds.height, heights[index])
            bar.frame = NSRect(
                x: CGFloat(index) * (barWidth + spacing),
                y: (waveformView.bounds.height - height) / 2,
                width: barWidth,
                height: height
            )
            bar.layer?.cornerRadius = barWidth / 2
        }
    }

    private func setWaveform(color: NSColor, animated: Bool) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let shouldAnimate = animated && !reduceMotion
        let unchanged = waveformIsAnimated == shouldAnimate && (waveformColor?.isEqual(color) ?? false)
        waveformIsAnimated = shouldAnimate
        waveformColor = color

        for (index, bar) in waveformBars.enumerated() {
            bar.layer?.backgroundColor = color.withAlphaComponent(animated ? 0.95 : 0.64).cgColor
            if unchanged { continue }
            bar.layer?.removeAnimation(forKey: "activity")
            guard shouldAnimate else { continue }

            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = 0.42
            animation.toValue = index.isMultiple(of: 2) ? 1.0 : 0.78
            animation.duration = 0.28 + Double(index % 4) * 0.055
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.035
            bar.layer?.add(animation, forKey: "activity")
        }
    }
}

private extension AIActivityCapsuleView.Mode {
    var isWorking: Bool {
        if case .working = self { return true }
        return false
    }
}

final class FocusAnswerView: NSVisualEffectView {
    private let badge = NSView()
    private let badgeLabel = NSTextField(labelWithString: "A")
    private let titleLabel = NSTextField(labelWithString: "Live answer")
    private let positionLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let loadingIndicator = NSProgressIndicator()
    private let loadingLabel = NSTextField(labelWithString: "Generating answer…")
    private var currentEntryID: UUID?

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

        badge.wantsLayer = true
        badge.layer?.cornerRadius = 11
        badge.layer?.backgroundColor = NSColor.appleGreen.withAlphaComponent(0.16).cgColor
        badge.layer?.borderWidth = 1
        badge.layer?.borderColor = NSColor.appleGreen.withAlphaComponent(0.55).cgColor
        addSubview(badge)

        badgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        badgeLabel.textColor = .appleGreen
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

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        addSubview(scrollView)

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        scrollView.documentView = textView

        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .small
        addSubview(loadingIndicator)

        loadingLabel.font = .systemFont(ofSize: 13, weight: .medium)
        loadingLabel.textColor = NSColor.white.withAlphaComponent(0.72)
        addSubview(loadingLabel)

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        showWelcome()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        badge.frame = NSRect(x: 18, y: bounds.height - 42, width: 24, height: 24)
        badgeLabel.frame = NSRect(x: 0, y: 4, width: 24, height: 16)
        titleLabel.frame = NSRect(x: 54, y: bounds.height - 42, width: max(120, bounds.width - 230), height: 24)
        positionLabel.frame = NSRect(x: bounds.width - 164, y: bounds.height - 39, width: 146, height: 18)
        scrollView.frame = NSRect(x: 20, y: 16, width: bounds.width - 40, height: max(40, bounds.height - 68))
        textView.frame.size.width = scrollView.contentSize.width
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        loadingIndicator.frame = NSRect(x: 22, y: bounds.midY - 10, width: 20, height: 20)
        loadingLabel.frame = NSRect(x: 50, y: bounds.midY - 8, width: 220, height: 18)
    }

    func update(
        entry: QuestionBurstEntry?,
        position: Int,
        total: Int,
        attributedAnswer: NSAttributedString?,
        streaming: Bool
    ) {
        guard let entry else {
            showWelcome()
            return
        }

        let selectionChanged = currentEntryID != entry.id
        currentEntryID = entry.id

        titleLabel.stringValue = displayTitle(for: entry.topic)
        let phaseTitle: String
        switch entry.phase {
        case .queued: phaseTitle = "Queued"
        case .generating: phaseTitle = "Generating"
        case .answering: phaseTitle = "Answering"
        case .ready: phaseTitle = "Ready"
        case .failed: phaseTitle = "Failed"
        }
        positionLabel.stringValue = "\(phaseTitle) \(position) of \(max(total, 1))"
        loadingLabel.stringValue = entry.phase == .failed ? "Answer generation failed" : "Generating answer…"
        loadingLabel.textColor = entry.phase == .failed ? .appleRed : NSColor.white.withAlphaComponent(0.72)

        if let attributedAnswer, attributedAnswer.length > 0 {
            let mutable = NSMutableAttributedString(attributedString: attributedAnswer)
            if streaming {
                mutable.append(NSAttributedString(
                    string: "  ▌",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 15, weight: .medium),
                        .foregroundColor: NSColor.appleGreen
                    ]
                ))
            }
            textView.textStorage?.setAttributedString(mutable)
            textView.isHidden = false
            scrollView.isHidden = false
            loadingIndicator.stopAnimation(nil)
            loadingIndicator.isHidden = true
            loadingLabel.isHidden = true
            if selectionChanged {
                scrollView.contentView.scroll(to: .zero)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        } else {
            textView.string = ""
            scrollView.isHidden = true
            loadingIndicator.isHidden = entry.phase == .failed
            if entry.phase != .failed {
                loadingIndicator.startAnimation(nil)
            } else {
                loadingIndicator.stopAnimation(nil)
            }
            loadingLabel.isHidden = false
        }

        setAccessibilityLabel("\(positionLabel.stringValue), \(titleLabel.stringValue)")
    }

    func showWelcome() {
        currentEntryID = nil
        titleLabel.stringValue = "Interview Assistant"
        positionLabel.stringValue = "Ready"
        let welcome = NSAttributedString(
            string: "Start the interview. Detected questions and concise answer cues will appear here.",
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: NSColor.white.withAlphaComponent(0.82)
            ]
        )
        textView.textStorage?.setAttributedString(welcome)
        scrollView.isHidden = false
        scrollView.contentView.scroll(to: .zero)
        loadingIndicator.stopAnimation(nil)
        loadingIndicator.isHidden = true
        loadingLabel.isHidden = true
    }

    private func displayTitle(for topic: String) -> String {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "unknown" else { return "Live answer" }

        var result = ""
        for character in trimmed {
            if character.isUppercase, !result.isEmpty {
                result.append(" ")
            }
            result.append(character)
        }
        return result.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
