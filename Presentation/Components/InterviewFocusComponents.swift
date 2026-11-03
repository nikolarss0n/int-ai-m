import Cocoa

enum QuestionBurstPhase: String, Equatable {
    case queued
    case generating
    case answering
    case ready
    case failed

    var title: String {
        switch self {
        case .queued: return "Queued"
        case .generating: return "Generating"
        case .answering: return "Answering"
        case .ready: return "Ready"
        case .failed: return "Failed"
        }
    }

    /// Both generating and answering are the AI at work, as the activity capsule says.
    var hue: Token.Hue {
        switch self {
        case .queued: return .neutral
        case .generating, .answering: return .warning
        case .ready: return .success
        case .failed: return .danger
        }
    }

    /// The pill's text. A queued pill has no hue of its own, so it reads as muted text.
    var color: NSColor {
        self == .queued ? Token.Color.textMuted : hue.text
    }

    /// Ready is the resting state, so a ready question carries no pill: only work and failures are marked.
    var showsPill: Bool { self != .ready }
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
    /// Why the answer failed, in a line a person can act on; nil unless `phase` is failed.
    var failure: String? = nil
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

    /// The card is open but nothing is written on it yet, so it is still generating; the first words make it answering.
    mutating func startStreaming(turnID: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == turnID }) else { return }
        updatePhase(entries[index].answer.isEmpty ? .generating : .answering, for: turnID, unlessReady: true)
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
        entries[index].failure = nil
        activeAIWork.remove(turnID)
    }

    mutating func fail(turnID: UUID, reason: String? = nil) {
        updatePhase(.failed, for: turnID, unlessReady: true)
        if let index = entries.firstIndex(where: { $0.id == turnID }), entries[index].phase == .failed {
            entries[index].failure = reason
        }
        activeAIWork.remove(turnID)
    }

    /// A failed answer is asked for again on its own card: it waits from `now` with nothing written on it.
    mutating func restart(turnID: UUID, at now: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.id == turnID }), entries[index].phase == .failed else { return }
        let failed = entries[index]
        entries[index] = QuestionBurstEntry(
            id: failed.id, sequence: failed.sequence, question: failed.question, topic: failed.topic,
            detectedAt: now, phase: .generating, answer: "", latencyMs: nil, failure: nil
        )
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

/// A soft fade along the bottom edge of a scroll view that says there is more below. It shows while
/// the content runs past the edge and goes when the reader reaches the end, whatever the system's
/// scroll bar setting is.
final class OverflowCueView: NSView {
    static let height: CGFloat = 28

    private weak var scrollView: NSScrollView?
    private weak var observedDocument: NSView?
    private let fade = CAGradientLayer()
    private var scrollObservers: [NSObjectProtocol] = []
    private var documentObserver: NSObjectProtocol?
    private var insetX: CGFloat = 0

    init(watching scrollView: NSScrollView) {
        self.scrollView = scrollView
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("overflowCue")
        wantsLayer = true
        fade.colors = [Token.Color.bgFadeClear.cgColor, Token.Color.bgFadeSolid.cgColor]
        fade.startPoint = CGPoint(x: 0.5, y: 1)
        fade.endPoint = CGPoint(x: 0.5, y: 0)
        layer?.addSublayer(fade)
        isHidden = true

        // Scrolling and resizing both change whether there is more below.
        let center = NotificationCenter.default
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.postsFrameChangedNotifications = true
        scrollObservers.append(center.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: .main) { [weak self] _ in
            self?.refresh()
        })
        scrollObservers.append(center.addObserver(forName: NSView.frameDidChangeNotification, object: scrollView, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.place(insetX: self.insetX)
        })
        observeDocument()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        scrollObservers.forEach { NotificationCenter.default.removeObserver($0) }
        if let documentObserver { NotificationCenter.default.removeObserver(documentObserver) }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        fade.frame = bounds
    }

    /// The document view can be swapped after the cue exists; follow whichever one is current.
    private func observeDocument() {
        guard let document = scrollView?.documentView, document !== observedDocument else { return }
        if let documentObserver { NotificationCenter.default.removeObserver(documentObserver) }
        document.postsFrameChangedNotifications = true
        documentObserver = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: document, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        observedDocument = document
    }

    /// Sits over the bottom edge of the scroll view. A scroll view that runs to rounded corners passes
    /// an inset so the fade stays inside them.
    func place(insetX: CGFloat = 0) {
        guard let scrollView, superview != nil else { return }
        self.insetX = insetX
        frame = NSRect(x: scrollView.frame.minX + insetX, y: scrollView.frame.minY, width: scrollView.frame.width - insetX * 2, height: Self.height)
        refresh()
    }

    func refresh() {
        observeDocument()
        guard let scrollView, let document = scrollView.documentView else { isHidden = true; return }
        let below = document.frame.height - scrollView.contentView.bounds.maxY
        isHidden = scrollView.isHidden || below <= 12
    }
}

final class QuestionBurstStripView: NSView {
    enum Orientation { case horizontal, vertical }

    var onSelect: ((UUID) -> Void)?
    /// Rows instead of columns, for a narrow column with height to spare (the code panel is open).
    var orientation: Orientation = .horizontal {
        didSet { if oldValue != orientation { needsLayout = true } }
    }

    private var entries: [QuestionBurstEntry] = []
    private var selectedID: UUID?

    /// How the questions are arranged. Side by side, each column has a pill above its question. Stacked,
    /// each question gets one line after its pill; when that line would be too short, the pill becomes a
    /// dot and its words move to the tooltip.
    private enum Mode { case columns, list, compact }

    private static let numberWidth: CGFloat = 18
    private static let minimumListQuestionWidth: CGFloat = 200

    private var mode: Mode {
        guard orientation == .vertical, !entries.isEmpty else { return .columns }
        return bounds.width - listQuestionX >= Self.minimumListQuestionWidth ? .list : .compact
    }

    /// The words in the pill, centred so a pill wider than its words (a list shares one width) stays balanced.
    private func pillText(_ entry: QuestionBurstEntry) -> NSAttributedString {
        let text = NSMutableAttributedString(attributedString: Token.Text.overline(
            entry.phase.title, detail: entry.latencyMs.map { InterviewMessage.formatLatency($0) } ?? "", color: entry.phase.color
        ))
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
        return text
    }

    /// The pills of a list share one width, so their questions start on one edge.
    private var listPillWidth: CGFloat {
        entries.filter { $0.phase.showsPill }.map { ceil(pillText($0).size().width) + Token.Space.inset }.max() ?? 0
    }

    private var listStatusX: CGFloat { Token.Space.inset + Self.numberWidth + Token.Space.sm }
    private var listQuestionX: CGFloat { listStatusX + (listPillWidth > 0 ? listPillWidth + Token.Space.md : 0) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        applySurface(.strip)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Questions")
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

        let segments = subviews.filter { $0.identifier?.rawValue.hasPrefix("burstSegment-") == true }
        let mode = self.mode
        switch mode {
        case .list, .compact:
            // The controller gives the list the height of its rows; a squeezed list shrinks them evenly.
            let rowHeight = min(Token.FocusLayout.stripRowHeight, floor(bounds.height / CGFloat(entries.count)))
            for (index, segment) in segments.enumerated() {
                segment.frame = NSRect(x: 0, y: bounds.height - CGFloat(index + 1) * rowHeight, width: bounds.width, height: rowHeight)
                layoutSegment(segment, size: segment.frame.size, mode: mode)
            }
        case .columns:
            let segmentWidth = bounds.width / CGFloat(entries.count)
            for (index, segment) in segments.enumerated() {
                segment.frame = NSRect(x: CGFloat(index) * segmentWidth, y: 0, width: segmentWidth, height: bounds.height)
                layoutSegment(segment, size: segment.frame.size, mode: mode)
            }
        }
    }

    private func rebuild() {
        subviews.forEach { $0.removeFromSuperview() }

        // With no questions the controller hides the strip and its label, so there is nothing to show.
        guard !entries.isEmpty else { return }

        for (index, entry) in entries.enumerated() {
            let segment = NSView(frame: .zero)
            segment.identifier = NSUserInterfaceItemIdentifier("burstSegment-\(entry.id.uuidString)")
            segment.applySurface(.segment)

            if entry.id == selectedID {
                let highlight = NSView(frame: .zero)
                highlight.identifier = NSUserInterfaceItemIdentifier("highlight")
                highlight.applySurface(.highlight)
                let bar = NSView(frame: .zero)
                bar.identifier = NSUserInterfaceItemIdentifier("highlightBar")
                bar.applySurface(.highlightBar)
                highlight.addSubview(bar)
                segment.addSubview(highlight)
            }

            let number = NSTextField(labelWithString: "\(index + 1)")
            number.identifier = NSUserInterfaceItemIdentifier("number")
            number.font = Token.Font.digits(.body, .semibold)
            number.textColor = Token.Color.textStrong
            number.alignment = .left
            number.drawsBackground = false
            number.isBezeled = false
            number.isEditable = false
            number.isSelectable = false
            segment.addSubview(number)

            let status = NSTextField(labelWithString: "")
            status.identifier = NSUserInterfaceItemIdentifier("status")
            status.attributedStringValue = pillText(entry)
            status.alignment = .center
            status.applySurface(.pill(entry.phase.hue, height: Token.Sizing.pill))
            segment.addSubview(status)

            let compactDot = NSView(frame: .zero)
            compactDot.identifier = NSUserInterfaceItemIdentifier("compactDot")
            compactDot.applySurface(.dot(entry.phase.hue))
            compactDot.isHidden = true
            segment.addSubview(compactDot)

            let question = NSTextField(wrappingLabelWithString: "")
            question.identifier = NSUserInterfaceItemIdentifier("question")
            question.attributedStringValue = Token.Text.attributed(
                entry.question,
                font: Token.Font.text(.body, entry.id == selectedID ? .medium : .regular),
                color: entry.id == selectedID ? Token.Color.textStrong : Token.Color.textBody,
                leading: Token.Leading.compact
            )
            question.maximumNumberOfLines = 2
            question.lineBreakMode = .byWordWrapping
            question.cell?.truncatesLastVisibleLine = true
            question.toolTip = "\(entry.phase.title)\(entry.latencyMs.map { " in " + InterviewMessage.formatLatency($0) } ?? ""): \(entry.question)"
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

            // A line between two questions, except against the selected one: its wash already separates it.
            if index > 0, entry.id != selectedID, entries[index - 1].id != selectedID {
                let divider = NSView(frame: .zero)
                divider.identifier = NSUserInterfaceItemIdentifier("divider")
                divider.wantsLayer = true
                divider.layer?.backgroundColor = Token.Color.separator.cgColor
                segment.addSubview(divider)
            }

            addSubview(segment)
        }

        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func layoutSegment(_ segment: NSView, size: CGSize, mode: Mode) {
        let width = size.width
        let pad = Token.Space.inset
        let vertical = mode != .columns
        func view(_ name: String) -> NSView? { segment.subviews.first(where: { $0.identifier?.rawValue == name }) }
        let status = view("status") as? NSTextField
        let compactDot = view("compactDot")
        let number = view("number")
        let question = view("question") as? NSTextField

        segment.subviews.first(where: { $0 is NSButton })?.frame = segment.bounds
        if let highlight = view("highlight") {
            // Inset inside the row, so the wash never meets the list's rounded corners or its neighbours.
            let inset = Token.Selection.inset
            let washHeight = max(0, size.height - inset)
            highlight.frame = NSRect(x: inset, y: inset / 2, width: max(0, width - inset * 2), height: washHeight)
            let barHeight = max(0, washHeight - Token.Selection.barVerticalInset * 2)
            highlight.subviews.first?.frame = NSRect(
                x: Token.Selection.barInset, y: (washHeight - barHeight) / 2, width: Token.Selection.barWidth, height: barHeight
            )
        }
        view("divider")?.frame = vertical
            ? NSRect(x: pad, y: size.height - 1, width: max(0, width - pad * 2), height: 1)
            : NSRect(x: 0, y: 10, width: 1, height: max(20, size.height - 20))

        if mode != .columns, let question {
            // One line per question, centred in its row: number, then the pill (or a dot in its hue),
            // then the question. The pill's words are on hover and in the accessibility label.
            let listing = mode == .list
            let marked = entryShowsPill(segment)
            status?.isHidden = !listing || !marked
            compactDot?.isHidden = listing || !marked
            let lineHeight = ceil(NSLayoutManager().defaultLineHeight(for: Token.Font.text(.body))) + 2
            let rowY = floor((size.height - lineHeight) / 2)
            number?.frame = NSRect(x: pad, y: rowY, width: Self.numberWidth, height: lineHeight)
            let markX = pad + Self.numberWidth + Token.Space.sm
            let textX: CGFloat
            if listing {
                status?.frame = NSRect(x: markX, y: rowY + 2, width: listPillWidth, height: Token.Sizing.pill)
                textX = listQuestionX
            } else {
                compactDot?.frame = NSRect(x: markX, y: (size.height - Token.Sizing.dot) / 2, width: Token.Sizing.dot, height: Token.Sizing.dot)
                textX = marked ? markX + Token.Sizing.dot + Token.Space.sm : markX
            }
            question.maximumNumberOfLines = 1
            question.frame = NSRect(x: textX, y: rowY, width: max(50, width - textX - pad), height: lineHeight)
            return
        }

        status?.isHidden = !entryShowsPill(segment)
        compactDot?.isHidden = true
        let topY = max(42, size.height - 27)
        let statusX = pad + Self.numberWidth + Token.Space.sm
        // The pill hugs its capitals; a narrow column never lets it clip them.
        let statusWidth = min(ceil(status?.attributedStringValue.size().width ?? 46) + 16, max(62, width - statusX - 12))
        number?.frame = NSRect(x: pad, y: topY, width: Self.numberWidth, height: 18)
        status?.frame = NSRect(x: statusX, y: topY + 2, width: statusWidth, height: Token.Sizing.pill)
        if let question {
            // The text is measured, so its frame is as tall as its lines and hangs under the pill row.
            let font = (question.attributedStringValue.length > 0 ? question.attributedStringValue.attribute(.font, at: 0, effectiveRange: nil) as? NSFont : nil) ?? Token.Font.text(.body)
            let spacing = Token.Text.lineSpacing(for: font, leading: Token.Leading.compact)
            let pitch = ceil(NSLayoutManager().defaultLineHeight(for: font)) + spacing
            let fitting = max(1, Int(floor((topY - 8 + spacing) / pitch)))
            let lines = min(2, fitting)
            let labelWidth = min(max(50, width - pad * 2), Token.Measure.caption)
            let height = font.wrappedHeight(of: question.stringValue, width: labelWidth - 4, maxLines: lines, lineSpacing: spacing) + 2
            question.maximumNumberOfLines = lines
            question.frame = NSRect(x: pad, y: max(4, topY - 4 - height), width: labelWidth, height: height)
        }
    }

    private func entryShowsPill(_ segment: NSView) -> Bool {
        let raw = segment.identifier?.rawValue.replacingOccurrences(of: "burstSegment-", with: "")
        return entries.first(where: { $0.id.uuidString == raw })?.phase.showsPill ?? true
    }

    @objc private func selectSegment(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        onSelect?(id)
    }
}

/// The window's top row: the app icon, a title that fills the room the status capsule leaves, and the
/// capsule on the right. The capsule is as wide as what it says, so the title takes the rest.
final class FocusHeaderView: NSView {
    weak var titleLabel: NSView?
    /// The app's name in small capitals above the title.
    weak var overlineLabel: NSView?
    weak var trailingView: NSView?
    /// A line of feedback that takes the title's place while there is one.
    weak var noticeView: NSView?

    override func layout() {
        super.layout()
        guard let titleLabel, let trailingView else { return }
        let right = trailingView.frame.minX - Token.Space.inset
        titleLabel.frame.size.width = max(0, right - titleLabel.frame.minX)
        overlineLabel?.frame.size.width = titleLabel.frame.width
        noticeView?.frame = NSRect(x: titleLabel.frame.minX, y: 0, width: max(0, right - titleLabel.frame.minX), height: bounds.height)
    }
}

final class AIActivityCapsuleView: NSVisualEffectView {
    enum Mode: Equatable {
        case idle
        case listening(speaking: Bool)
        /// The interviewer's words are being turned into text.
        case transcribing
        /// The audio source is starting or being switched.
        case connecting
        /// The person muted capture, so nothing the interviewer says is heard.
        case muted
        /// The interview is running with no audio source to hear.
        case unavailable
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
    private var waveformHue: Token.Hue?

    init(frame frameRect: NSRect, compact: Bool = false) {
        self.compact = compact
        super.init(frame: frameRect)
        applyGlass(.capsule(height: frameRect.height))

        recordingDot.applySurface(.dot(.danger))
        addSubview(recordingDot)

        sparkleView.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "AI")
        sparkleView.symbolConfiguration = Token.Font.symbol(.micro)
        sparkleView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(sparkleView)

        stateLabel.font = Token.Font.digits(.caption, .semibold)
        stateLabel.lineBreakMode = .byTruncatingTail
        addSubview(stateLabel)

        elapsedLabel.font = Token.Font.digits(.caption, .medium)
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

        let hue: Token.Hue
        let labelColor: NSColor
        let label: String
        let animate: Bool

        switch mode {
        case .idle:
            hue = .neutral
            labelColor = Token.Color.textMuted
            label = "Ready"
            animate = false
        case .listening(let speaking):
            hue = .success
            labelColor = hue.text
            label = speaking ? "Hearing speech" : "Listening"
            animate = speaking
        case .transcribing:
            hue = .warning
            labelColor = hue.text
            label = "Transcribing…"
            animate = true
        case .connecting:
            hue = .neutral
            labelColor = Token.Color.textBody
            label = "Connecting audio…"
            animate = true
        case .muted:
            hue = .warning
            labelColor = hue.text
            label = "Muted"
            animate = false
        case .unavailable:
            hue = .danger
            labelColor = hue.text
            label = "No audio"
            animate = false
        case .working(let questionNumber):
            hue = .warning
            labelColor = hue.text
            label = questionNumber.map { "AI working\(Token.Text.separator)Q\($0)" } ?? "AI working"
            animate = true
        case .ready:
            hue = .success
            labelColor = hue.text
            label = "Answer ready"
            animate = false
        }

        // At rest the header says nothing: an answer shows itself and an idle app needs no badge.
        if !compact { isHidden = mode == .idle || mode == .ready }
        stateLabel.stringValue = label
        stateLabel.toolTip = mode.explanation ?? label
        toolTip = mode.explanation
        stateLabel.textColor = labelColor
        sparkleView.contentTintColor = labelColor
        sparkleView.isHidden = compact || {
            if case .working = mode { return false }
            return true
        }()
        elapsedLabel.textColor = Token.Color.textBody

        let emphasised = mode.isWorking || mode.needsAttention
        layer?.backgroundColor = hue.tint(emphasised ? .medium : .soft).cgColor
        setWaveform(hue: hue, animated: animate)
        // Bars that do not move say nothing, so they show only while someone is speaking or the AI works.
        waveformView.isHidden = !animate

        let recordingDescription = isRecording ? ", recording" : ""
        let elapsedDescription = elapsed.isEmpty ? "" : ", \(elapsed)"
        setAccessibilityLabel("\(label)\(recordingDescription)\(elapsedDescription)")
        fitToContent()
        needsLayout = true
    }

    /// Where each piece of the header capsule sits, left to right. A piece that is not showing takes no
    /// room, so the capsule is as wide as what it says: "Answer ready" alone is not a 300 point pill.
    private struct HeaderLayout {
        var dot = NSRect.zero, sparkle = NSRect.zero, label = NSRect.zero, waveform = NSRect.zero, elapsed = NSRect.zero
        var width: CGFloat = 0
    }

    /// The longest thing the capsule says is "Connecting audio…" (118 with its padding).
    private static let maximumLabelWidth: CGFloat = 128

    private func headerLayout() -> HeaderLayout {
        let height = frame.height
        let edge = Token.Space.inset - 2
        var result = HeaderLayout()
        var x = edge
        if !recordingDot.isHidden {
            result.dot = NSRect(x: x, y: (height - Token.Sizing.dot) / 2, width: Token.Sizing.dot, height: Token.Sizing.dot)
            x += Token.Sizing.dot + Token.Space.sm
        }
        if !sparkleView.isHidden {
            result.sparkle = NSRect(x: x, y: (height - 14) / 2, width: 14, height: 14)
            x += 14 + 6
        }
        let labelWidth = min(ceil(stateLabel.attributedStringValue.size().width) + 4, Self.maximumLabelWidth)
        result.label = NSRect(x: x, y: (height - 18) / 2, width: labelWidth, height: 18)
        x += labelWidth
        if !waveformView.isHidden {
            x += Token.Space.md
            result.waveform = NSRect(x: x, y: (height - 18) / 2, width: 62, height: 18)
            x += 62
        }
        if !elapsedLabel.stringValue.isEmpty {
            x += Token.Space.md
            let elapsedWidth = ceil(elapsedLabel.attributedStringValue.size().width) + 4
            result.elapsed = NSRect(x: x, y: (height - 16) / 2, width: elapsedWidth, height: 16)
            x += elapsedWidth
        }
        result.width = x + edge
        return result
    }

    /// Keeps the right edge where it is and moves the left one.
    private func fitToContent() {
        guard !compact else { return }
        let width = headerLayout().width
        guard abs(width - frame.width) > 0.5 else { return }
        frame = NSRect(x: frame.maxX - width, y: frame.minY, width: width, height: frame.height)
        superview?.needsLayout = true
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = Token.Radius.full(bounds.height)

        if compact {
            waveformView.frame = NSRect(x: 10, y: (bounds.height - 16) / 2, width: 38, height: 16)
            let labelX: CGFloat = waveformView.isHidden ? 14 : 53
            stateLabel.frame = NSRect(x: labelX, y: (bounds.height - 16) / 2, width: max(30, bounds.width - labelX - 8), height: 16)
            recordingDot.frame = .zero
            sparkleView.frame = .zero
            elapsedLabel.frame = .zero
        } else {
            let pieces = headerLayout()
            recordingDot.frame = pieces.dot
            sparkleView.frame = pieces.sparkle
            stateLabel.frame = pieces.label
            waveformView.frame = pieces.waveform
            elapsedLabel.frame = pieces.elapsed
        }

        layoutWaveformBars()
    }

    private func buildWaveformBars() {
        waveformBars.forEach { $0.removeFromSuperview() }
        waveformBars = Token.Waveform.barHeights.map { _ in
            let bar = NSView(frame: .zero)
            bar.wantsLayer = true
            waveformView.addSubview(bar)
            return bar
        }
    }

    private func layoutWaveformBars() {
        guard !waveformBars.isEmpty, waveformView.bounds.width > 0 else { return }
        let barWidth = Token.Waveform.barWidth
        let spacing = max(1.5, (waveformView.bounds.width - CGFloat(waveformBars.count) * barWidth) / CGFloat(waveformBars.count - 1))
        let heights = Token.Waveform.barHeights
        for (index, bar) in waveformBars.enumerated() {
            let height = min(waveformView.bounds.height, heights[index])
            bar.frame = NSRect(
                x: CGFloat(index) * (barWidth + spacing),
                y: (waveformView.bounds.height - height) / 2,
                width: barWidth,
                height: height
            )
            bar.layer?.cornerRadius = Token.Radius.full(barWidth)
        }
    }

    private func setWaveform(hue: Token.Hue, animated: Bool) {
        let reduceMotion = Token.Motion.reducesMotion()
        let shouldAnimate = animated && !reduceMotion
        let unchanged = waveformIsAnimated == shouldAnimate && (waveformHue?.solid.isEqual(hue.solid) ?? false)
        waveformIsAnimated = shouldAnimate
        waveformHue = hue

        for (index, bar) in waveformBars.enumerated() {
            bar.layer?.backgroundColor = Token.Waveform.barColor(hue, animated: animated).cgColor
            if unchanged { continue }
            bar.layer?.removeAnimation(forKey: "activity")
            guard shouldAnimate else { continue }

            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = Token.Waveform.restScale
            animation.toValue = index.isMultiple(of: 2) ? Token.Waveform.peakScaleEven : Token.Waveform.peakScaleOdd
            animation.duration = Token.Waveform.period + Double(index % 4) * Token.Waveform.periodStep
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.beginTime = CACurrentMediaTime() + Double(index) * Token.Waveform.stagger
            bar.layer?.add(animation, forKey: "activity")
        }
    }
}

private extension AIActivityCapsuleView.Mode {
    /// The AI has the turn (or is about to), which the capsule shows with a stronger outline.
    var isWorking: Bool {
        switch self {
        case .working, .transcribing: return true
        default: return false
        }
    }

    /// Something the person can fix is stopping the app from hearing, so the capsule is as loud as when it works.
    var needsAttention: Bool {
        switch self {
        case .muted, .unavailable: return true
        default: return false
        }
    }

    /// What to do about it, for hover.
    var explanation: String? {
        switch self {
        case .muted: return "Muted. Click the mute button or press ⌘⇧M to unmute."
        case .unavailable: return "No audio source is working. Select one in the bar to try again."
        case .connecting: return "Starting the audio source."
        default: return nil
        }
    }
}

final class FocusAnswerView: NSVisualEffectView {
    /// The topic, in small capitals in the accent, above the question: the day above the date in the
    /// Calendar widget.
    private let titleLabel = NSTextField(labelWithString: "")
    private var topic = TopicTitle.unknown
    private let positionLabel = NSTextField(labelWithString: "")
    private let questionLabel = NSTextField(wrappingLabelWithString: "")
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    /// Bars where the first lines of the answer will be, while nothing has been written yet.
    private let loadingSkeleton = SkeletonView()
    /// The message of a failed answer.
    private let failureLabel = NSTextField(labelWithString: "Couldn't generate the answer")
    /// Why, in a line, and a way to ask again.
    private let failureDetail = NSTextField(wrappingLabelWithString: "")
    private let retryButton = HoverButton(frame: .zero)
    /// Asks for the answer to the question on this card again.
    var onRetry: ((UUID) -> Void)?
    private var currentEntryID: UUID?
    /// The clock a waiting card reads, so the QA driver can look at a long wait without making it.
    static var now: () -> Date = Date.init
    private struct Waiting {
        let since: Date
        let queued: Bool
    }
    private var waiting: Waiting?
    private var shownPhase: QuestionBurstPhase = .ready
    private var shownLatency: String?
    private var waitTimer: Timer?
    /// "Ready · 1.5s", and its short form for a card too narrow to show both: the state, or for a
    /// finished answer just the latency. The strip says which of the questions this is, so the card says
    /// only how its answer is doing.
    private var positionFull = ""
    private var positionShort = ""
    /// The topic is the card's heading: the state's latency gives up its room before the title drops under this.
    private static let minimumTitleWidth: CGFloat = 150
    private lazy var overflowCue = OverflowCueView(watching: scrollView)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        applyGlass(.card)

        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)

        positionLabel.font = Token.Font.digits(.caption, .medium)
        positionLabel.textColor = Token.Color.textMuted
        positionLabel.alignment = .right
        addSubview(positionLabel)

        // The question is the card's heading. The list clips it to a line; the card shows what was asked.
        questionLabel.maximumNumberOfLines = 3
        questionLabel.lineBreakMode = .byWordWrapping
        questionLabel.cell?.truncatesLastVisibleLine = true
        questionLabel.isHidden = true
        addSubview(questionLabel)

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        addSubview(overflowCue, positioned: .above, relativeTo: scrollView)

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

        loadingSkeleton.isHidden = true
        addSubview(loadingSkeleton)

        failureLabel.font = Token.Font.text(.body, .medium)
        failureLabel.textColor = Token.Hue.danger.text
        failureLabel.isHidden = true
        addSubview(failureLabel)

        failureDetail.font = Token.Font.text(.caption)
        failureDetail.textColor = Token.Color.textMuted
        failureDetail.maximumNumberOfLines = 2
        failureDetail.cell?.truncatesLastVisibleLine = true
        failureDetail.isHidden = true
        addSubview(failureDetail)

        retryButton.title = "Try again"
        retryButton.attributedTitle = NSAttributedString(string: "Try again", attributes: [
            .font: Token.Font.text(.caption, .semibold),
            .foregroundColor: Token.Hue.warning.text
        ])
        retryButton.imagePosition = .noImage
        retryButton.isBordered = false
        retryButton.wantsLayer = true
        retryButton.layer?.cornerRadius = Token.Radius.full(Token.Sizing.controlSmall)
        retryButton.layer?.cornerCurve = .continuous
        retryButton.apply(.chip(.warning))
        retryButton.target = self
        retryButton.action = #selector(retryClicked)
        retryButton.toolTip = "Ask for this answer again"
        retryButton.setAccessibilityLabel("Try again")
        retryButton.isHidden = true
        addSubview(retryButton)

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        showWelcome()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let inset = Token.Space.inset
        let top = bounds.height - inset

        // The topic takes what the position leaves. When the whole position would squeeze the topic,
        // the position gives up its latency first.
        let rowWidth = bounds.width - inset * 2
        // The question is the heading, so the topic shows only on the welcome card. A finished answer
        // has no state to show, so with neither the row takes no room and the question starts at the top.
        titleLabel.isHidden = !questionLabel.isHidden
        let rowHeight = titleLabel.isHidden && positionFull.isEmpty ? 0 : Self.rowHeight
        func width(of text: String) -> CGFloat {
            ceil(NSAttributedString(string: text, attributes: [.font: positionLabel.font ?? Token.Font.digits(.caption, .medium)]).size().width) + 6
        }
        let fitsWhole = rowWidth - width(of: positionFull) - Token.Space.md >= Self.minimumTitleWidth
        let position = fitsWhole || positionShort.isEmpty ? positionFull : positionShort
        if positionLabel.stringValue != position { positionLabel.stringValue = position }
        let positionWidth = position.isEmpty ? 0 : min(width(of: position), rowWidth * 0.6)
        let positionGap = position.isEmpty ? 0 : Token.Space.md
        // The capitals sit a point lower than the state beside them, so the two share a baseline.
        titleLabel.frame = NSRect(x: inset, y: top - rowHeight, width: max(40, rowWidth - positionWidth - positionGap), height: rowHeight - 1)
        positionLabel.frame = NSRect(x: bounds.width - inset - positionWidth, y: top - rowHeight, width: positionWidth, height: rowHeight)

        let questionWidth = min(bounds.width - inset * 2, Token.Measure.reading)
        let questionLines = quotedLines(forCardHeight: bounds.height)
        questionLabel.maximumNumberOfLines = questionLines
        let questionHeight = askedQuestionHeight(forWidth: questionWidth, lines: questionLines)
        let headingTop = top - rowHeight - (rowHeight > 0 ? Token.Space.xs : 0)
        questionLabel.frame = NSRect(x: inset, y: headingTop - questionHeight, width: questionWidth, height: questionHeight)
        let textTop = headingTop - (questionHeight > 0 ? questionHeight + Token.Space.md : Token.Space.sm)
        scrollView.frame = NSRect(x: inset, y: inset, width: min(bounds.width - inset * 2, Token.Measure.reading), height: max(40, textTop - inset))
        textView.frame.size.width = scrollView.contentSize.width
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        overflowCue.place()
        // The wait sits where the answer will start: bars in place of its first lines, so the words arrive
        // where the bars were. A failure is a line on the card's edge.
        let font = Token.Font.text(.lead)
        let lineHeight = ceil(NSLayoutManager().defaultLineHeight(for: font))
        let pitch = lineHeight + Token.Text.lineSpacing(for: font, leading: Token.Leading.reading) + Token.Space.xs
        let rows = max(1, min(3, Int(floor((max(0, textTop - inset) + Token.Space.xs) / pitch))))
        loadingSkeleton.pieces = SkeletonView.answerLines(count: rows, indent: Token.Text.bulletIndent(for: font), pitch: pitch, lineHeight: lineHeight)
        let skeletonHeight = CGFloat(rows) * pitch
        loadingSkeleton.frame = NSRect(x: inset, y: textTop - skeletonHeight, width: min(bounds.width - inset * 2, Token.Measure.reading), height: skeletonHeight)
        failureLabel.frame = NSRect(x: inset, y: textTop - 20, width: max(60, min(240, bounds.width - inset * 2)), height: 18)
        // The reason is one or two lines under it, and the way forward under that.
        let detailFont = Token.Font.text(.caption)
        let detailWidth = min(bounds.width - inset * 2, Token.Measure.note)
        let detailSpacing = Token.Text.lineSpacing(for: detailFont, leading: Token.Leading.compact)
        let detailHeight = failureDetail.isHidden ? 0 : detailFont.wrappedHeight(of: failureDetail.stringValue, width: detailWidth - 4, maxLines: 2, lineSpacing: detailSpacing) + 2
        failureDetail.frame = NSRect(x: inset, y: failureLabel.frame.minY - Token.Space.xs - detailHeight, width: detailWidth, height: detailHeight)
        let buttonWidth = ceil(retryButton.attributedTitle.size().width) + 24
        let above = detailHeight > 0 ? failureDetail.frame.minY : failureLabel.frame.minY
        retryButton.frame = NSRect(x: inset, y: above - Token.Space.sm - Token.Sizing.controlSmall, width: buttonWidth, height: Token.Sizing.controlSmall)
    }

    @objc private func retryClicked() {
        if let currentEntryID { onRetry?(currentEntryID) }
    }

    /// The row that holds the topic and the state.
    private static let rowHeight: CGFloat = 17

    /// The question heading is context; in a short card it gives lines back to the answer.
    private func quotedLines(forCardHeight height: CGFloat) -> Int {
        height >= 220 ? 2 : 1
    }

    private func askedQuestionHeight(forWidth width: CGFloat, lines: Int = 3) -> CGFloat {
        guard !questionLabel.isHidden else { return 0 }
        let font = Self.headingFont
        let spacing = Token.Text.lineSpacing(for: font, leading: Token.Leading.heading)
        return font.wrappedHeight(of: questionLabel.stringValue, width: width, maxLines: lines, lineSpacing: spacing) + 2
    }

    func update(
        entry: QuestionBurstEntry?,
        position: Int,
        total: Int,
        attributedAnswer: NSAttributedString?,
        streaming: Bool,
        canRetry: Bool = false
    ) {
        guard let entry else {
            showWelcome()
            return
        }

        let selectionChanged = currentEntryID != entry.id
        currentEntryID = entry.id

        setTopic(TopicTitle.display(entry.topic))
        let asked = entry.question.trimmingCharacters(in: .whitespacesAndNewlines)
        questionLabel.attributedStringValue = Token.Text.attributed(
            asked, font: Self.headingFont, color: Token.Color.textPrimary, leading: Token.Leading.heading
        )
        questionLabel.toolTip = asked
        questionLabel.isHidden = entry.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasText = (attributedAnswer?.length ?? 0) > 0
        let wasWaiting = waiting != nil
        let onItsWay = entry.phase != .failed && entry.phase != .ready
        waiting = !hasText && onItsWay ? Waiting(since: entry.detectedAt, queued: entry.phase == .queued) : nil
        shownPhase = entry.phase
        shownLatency = entry.latencyMs.map { InterviewMessage.formatLatency($0) }
        refreshStatus()
        updateWaitTimer()

        if let attributedAnswer, hasText {
            let mutable = NSMutableAttributedString(attributedString: attributedAnswer)
            if streaming {
                mutable.append(NSAttributedString(
                    string: "  ▌",
                    attributes: [
                        .font: Token.Font.text(.lead, .medium),
                        .foregroundColor: Token.Color.textStrong
                    ]
                ))
            }
            textView.textStorage?.setAttributedString(mutable)
            textView.isHidden = false
            let revealing = scrollView.isHidden
            scrollView.isHidden = false
            failureLabel.isHidden = true
            failureDetail.isHidden = true
            retryButton.isHidden = true
            if wasWaiting && !selectionChanged && revealing {
                replaceSkeleton(with: scrollView)
            } else {
                hideSkeleton()
            }
            if selectionChanged {
                scrollView.contentView.scroll(to: .zero)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        } else {
            textView.string = ""
            scrollView.isHidden = true
            let failed = entry.phase == .failed
            failureLabel.isHidden = !failed
            failureDetail.stringValue = entry.failure ?? ""
            failureDetail.isHidden = !failed || (entry.failure ?? "").isEmpty
            retryButton.isHidden = !failed || !canRetry
            if waiting != nil { showSkeleton() } else { hideSkeleton() }
        }

        setAccessibilityLabel("\(entry.phase.title), question \(position) of \(max(total, 1)), \(topic)")
        // The question line changes height with the question, so the frames depend on the content.
        needsLayout = true
    }

    func showWelcome() {
        currentEntryID = nil
        setTopic(TopicTitle.unknown)
        // The activity capsule already says the app is ready.
        positionFull = ""
        positionShort = ""
        positionLabel.stringValue = positionFull
        questionLabel.isHidden = true
        let welcome = Token.Text.attributed(
            "Start the interview and each question the interviewer asks gets a short answer here. Code opens in a panel on the right.",
            font: Token.Font.text(.lead), color: Token.Color.textBody, leading: Token.Leading.reading
        )
        textView.textStorage?.setAttributedString(welcome)
        scrollView.isHidden = false
        scrollView.contentView.scroll(to: .zero)
        waiting = nil
        updateWaitTimer()
        hideSkeleton()
        failureLabel.isHidden = true
        failureDetail.isHidden = true
        retryButton.isHidden = true
        needsLayout = true
    }

    private static let headingFont = Token.Font.text(.title, .semibold)

    private func setTopic(_ text: String) {
        topic = text
        titleLabel.attributedStringValue = Token.Text.overline(text, color: Token.Hue.accent.text)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.toolTip = text
    }

    // MARK: - Waiting

    /// What the card says about how its answer is doing. While nothing is written yet that is the wait,
    /// and after a few seconds the seconds.
    private func refreshStatus() {
        if let waiting {
            let elapsed = Self.now().timeIntervalSince(waiting.since)
            positionFull = WaitProgress.answerStatus(queued: waiting.queued, elapsed: elapsed, separator: Token.Text.separator)
            positionShort = WaitProgress.answerStatusShort(queued: waiting.queued, elapsed: elapsed)
            positionLabel.toolTip = positionFull
        } else {
            // A finished answer shows itself: its latency moves to the question's tooltip.
            let ready = shownPhase == .ready
            positionFull = ready ? "" : shownPhase.title + (shownLatency.map { Token.Text.separator + $0 } ?? "")
            positionShort = ready ? "" : shownPhase.title
            positionLabel.toolTip = shownLatency.map { "\(shownPhase.title) in \($0)" } ?? shownPhase.title
            if ready, let shownLatency, !questionLabel.isHidden {
                questionLabel.toolTip = "\(questionLabel.stringValue)\n\(shownPhase.title) in \(shownLatency)"
            }
        }
        positionLabel.stringValue = positionFull
        needsLayout = true
    }

    private func updateWaitTimer() {
        guard waiting != nil, window != nil else {
            waitTimer?.invalidate()
            waitTimer = nil
            return
        }
        guard waitTimer == nil else { return }
        let timer = Timer(timeInterval: Token.Motion.clockTick, repeats: true) { [weak self] _ in
            guard let self, self.waiting != nil else { return }
            self.refreshStatus()
        }
        RunLoop.main.add(timer, forMode: .common)
        waitTimer = timer
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateWaitTimer()
    }

    deinit {
        waitTimer?.invalidate()
    }

    private func showSkeleton() {
        loadingSkeleton.layer?.removeAnimation(forKey: "fadeOut")
        loadingSkeleton.isHidden = false
    }

    private func hideSkeleton() {
        loadingSkeleton.layer?.removeAnimation(forKey: "fadeOut")
        loadingSkeleton.isHidden = true
    }

    /// The words fade in where the bars were while the bars fade out.
    private func replaceSkeleton(with content: NSView) {
        guard !Token.Motion.reducesMotion(), window != nil, let contentLayer = content.layer, let barsLayer = loadingSkeleton.layer else {
            hideSkeleton()
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
        barsLayer.add(fadeOut, forKey: "fadeOut")
        DispatchQueue.main.asyncAfter(deadline: .now() + Token.Motion.fadeIn) { [weak self] in
            guard let self, self.waiting == nil else { return }
            self.hideSkeleton()
        }
    }
}

final class InterviewBriefingView: NSVisualEffectView {
    private static let digestLines = 2
    private static let pointLines = 6
    private let badge = NSView()
    private let badgeLabel = NSTextField(labelWithString: "CV")
    private let digestLabel = NSTextField(wrappingLabelWithString: "")
    private let pointsLabel = NSTextField(wrappingLabelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        applyGlass(.briefing)
        isHidden = true

        // A label column, like the days down the Weather widget: small capitals, no chip.
        addSubview(badge)

        badgeLabel.attributedStringValue = Token.Text.overline("CV", color: Token.Color.textMuted)
        badgeLabel.alignment = .left
        badge.addSubview(badgeLabel)

        digestLabel.maximumNumberOfLines = Self.digestLines
        digestLabel.cell?.truncatesLastVisibleLine = true
        addSubview(digestLabel)

        pointsLabel.maximumNumberOfLines = Self.pointLines
        pointsLabel.cell?.truncatesLastVisibleLine = true
        addSubview(pointsLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ briefing: InterviewBriefing?) {
        guard let briefing, !briefing.talkingPoints.isEmpty else {
            isHidden = true
            digestLabel.stringValue = ""
            pointsLabel.stringValue = ""
            return
        }
        isHidden = false
        let digestFont = Token.Font.text(.body, .medium)
        digestLabel.attributedStringValue = Token.Text.attributed(briefing.digest, font: digestFont, color: Token.Color.textStrong, leading: Token.Leading.compact)
        digestLabel.toolTip = briefing.digest
        let pointFont = Token.Font.text(.body)
        let points = NSMutableAttributedString(attributedString: Token.Text.attributed(
            briefing.talkingPoints.map { "•\u{00A0}\($0)" }.joined(separator: "\n"),
            font: pointFont, color: Token.Color.textBody, leading: Token.Leading.compact
        ))
        points.addAttribute(.paragraphStyle, value: Token.Text.paragraph(
            for: pointFont, leading: Token.Leading.compact, hangingIndent: Token.Text.bulletIndent(for: pointFont)
        ), range: NSRange(location: 0, length: points.length))
        pointsLabel.attributedStringValue = points
        pointsLabel.toolTip = briefing.talkingPoints.map { "• \($0)" }.joined(separator: "\n")
        // A strip squeezed to its digest still gives the whole reminder on hover.
        toolTip = ([briefing.digest] + briefing.talkingPoints.map { "• \($0)" }).joined(separator: "\n")
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private let topPadding = Token.Space.md
    private let bottomPadding = Token.Space.md
    private let rowGap: CGFloat = 8
    private var digestX: CGFloat { Token.Space.inset + 28 + Token.Space.sm }
    private var digestFont: NSFont { Token.Font.text(.body, .medium) }
    private var pointFont: NSFont { Token.Font.text(.body) }

    private func digestWidth(forWidth width: CGFloat) -> CGFloat {
        min(max(40, width - digestX - Token.Space.inset), Token.Measure.caption)
    }

    private func digestHeight(forWidth width: CGFloat, lines: Int) -> CGFloat {
        let spacing = Token.Text.lineSpacing(for: digestFont, leading: Token.Leading.compact)
        return max(18, digestFont.wrappedHeight(of: digestLabel.stringValue, width: digestWidth(forWidth: width) - 4, maxLines: lines, lineSpacing: spacing)) + 2
    }

    /// Height of the talking points, or of `lines` of them when the strip is short.
    private func pointsHeight(forWidth width: CGFloat, lines: Int = pointLines) -> CGFloat {
        let text = pointsLabel.attributedStringValue
        guard text.length > 0 else { return 0 }
        let bounds = text.boundingRect(with: NSSize(width: min(width - Token.Space.inset * 2, Token.Measure.caption) - 4, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading])
        let spacing = Token.Text.lineSpacing(for: pointFont, leading: Token.Leading.compact)
        let cap = ceil(NSLayoutManager().defaultLineHeight(for: pointFont)) * CGFloat(lines) + spacing * CGFloat(max(0, lines - 1))
        return min(ceil(bounds.height), cap) + 2
    }

    private var pointPitch: CGFloat {
        ceil(NSLayoutManager().defaultLineHeight(for: pointFont)) + Token.Text.lineSpacing(for: pointFont, leading: Token.Leading.compact)
    }

    /// The height that shows the digest and every talking point at this width, so nothing is clipped.
    /// When `budget` is less, the tallest form that fits it and has no empty space: the digest on two
    /// lines with as many points as remain, then one line, then the digest alone. The strip is a
    /// reminder and never crowds out the answer.
    func preferredHeight(forWidth width: CGFloat, budget: CGFloat = .greatestFiniteMagnitude) -> CGFloat {
        guard !isHidden else { return 0 }
        let natural = topPadding + digestHeight(forWidth: width, lines: Self.digestLines) + rowGap + pointsHeight(forWidth: width) + bottomPadding
        guard natural > budget else { return natural }
        let spacing = Token.Text.lineSpacing(for: pointFont, leading: Token.Leading.compact)
        for digestLines in [Self.digestLines, 1] {
            let digest = digestHeight(forWidth: width, lines: digestLines)
            let room = budget - topPadding - digest - rowGap - bottomPadding
            if room >= pointPitch {
                let lines = min(Self.pointLines, Int(floor((room + spacing) / pointPitch)))
                return topPadding + digest + rowGap + pointsHeight(forWidth: width, lines: lines) + bottomPadding
            }
        }
        return topPadding + digestHeight(forWidth: width, lines: 1) + bottomPadding
    }

    override func layout() {
        super.layout()
        let inset = Token.Space.inset
        // In a short strip the digest gives up its second line first, then the points give up lines.
        var digestLines = Self.digestLines
        var digest = digestHeight(forWidth: bounds.width, lines: digestLines)
        var room = bounds.height - topPadding - digest - rowGap - bottomPadding
        if room < pointPitch {
            digestLines = 1
            digest = digestHeight(forWidth: bounds.width, lines: 1)
            room = bounds.height - topPadding - digest - rowGap - bottomPadding
        }
        let spacing = Token.Text.lineSpacing(for: pointFont, leading: Token.Leading.compact)
        let pointLines = room >= pointPitch ? max(1, min(Self.pointLines, Int(floor((room + spacing) / pointPitch)))) : 0
        digestLabel.maximumNumberOfLines = digestLines
        pointsLabel.isHidden = pointLines == 0
        pointsLabel.maximumNumberOfLines = max(1, pointLines)

        badge.frame = NSRect(x: inset, y: bounds.height - topPadding - 18, width: 28, height: 18)
        badgeLabel.frame = badge.bounds
        digestLabel.frame = NSRect(x: digestX, y: bounds.height - topPadding - digest, width: digestWidth(forWidth: bounds.width), height: digest)
        pointsLabel.frame = NSRect(x: inset, y: bottomPadding, width: min(bounds.width - inset * 2, Token.Measure.caption), height: pointLines == 0 ? 0 : pointsHeight(forWidth: bounds.width, lines: pointLines))
    }
}
