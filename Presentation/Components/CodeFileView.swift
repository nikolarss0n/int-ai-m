import Cocoa

/// Sideways scrolling for a code line that runs past the panel. Vertical scrolling passes through to
/// the panel, so the wheel still moves the page when the pointer is over code.
private final class CodeLineScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            super.scrollWheel(with: event)
        } else {
            nextResponder?.scrollWheel(with: event)
        }
    }
}

/// The well behind a file's code. It draws what is not part of the text: line numbers, the hairlines
/// between steps, and the marks for lines that changed since the previous version.
private final class CodeWellView: NSView {
    enum RowKind: Equatable {
        case note(isFirst: Bool, number: Int?)
        case code(line: Int)
    }
    struct Row {
        let rect: NSRect
        let kind: RowKind
        /// The baseline of the row's text, for what the gutter draws beside it.
        let baseline: CGFloat
        /// The step the row belongs to, and whether it is set back because another step is being typed.
        let step: Int
        let dimmed: Bool
    }

    var rows: [Row] = [] { didSet { needsDisplay = true } }
    var changes = CodeLineChanges() { didSet { needsDisplay = true } }
    var gutterWidth: CGFloat = 0 { didSet { needsDisplay = true } }
    /// One step is being typed: its number is lit and the others are set back.
    var focusesStep = false { didSet { needsDisplay = true } }
    /// Where a mark for removed lines goes when they were at the very end of the file.
    var endY: CGFloat = 0

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        for row in rows {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: CodeFileView.lineNumberFont,
                .foregroundColor: row.dimmed ? CodeFileView.dimmed(Token.Color.textMuted) : Token.Color.textMuted
            ]
            switch row.kind {
            case .note(let isFirst, let step):
                // The step's number shares the line numbers' column, so its note starts where the code does.
                if let step {
                    let number = NSAttributedString(string: "\(step)", attributes: [
                        .font: CodeFileView.stepNumberFont,
                        .foregroundColor: row.dimmed ? CodeFileView.dimmed(Token.Color.textBody)
                            : (focusesStep ? Token.Hue.accent.text : Token.Color.textBody)
                    ])
                    number.draw(at: NSPoint(
                        x: gutterWidth - Token.Space.md - number.size().width,
                        y: row.baseline - CodeFileView.stepNumberFont.ascender
                    ))
                }
                guard !isFirst else { continue }
                Token.Color.separator.setFill()
                NSRect(x: 0, y: row.rect.minY - Token.Space.xs, width: bounds.width, height: 1).fill()
            case .code(let line):
                let number = NSAttributedString(string: "\(line + 1)", attributes: attributes)
                let size = number.size()
                number.draw(at: NSPoint(
                    x: gutterWidth - Token.Space.md - size.width,
                    y: row.rect.minY + Token.Font.mono(.code).ascender - CodeFileView.lineNumberFont.ascender
                ))
                if changes.changed.contains(line) {
                    Token.Hue.success.solid.setFill()
                    NSRect(x: CodeFileView.markX, y: row.rect.minY, width: CodeFileView.markWidth, height: row.rect.height).fill()
                }
                if changes.removedBefore.contains(line) { drawRemovedMark(y: row.rect.minY) }
            }
        }
        if let last = rows.last, case .code(let line) = last.kind, changes.removedBefore.contains(line + 1) {
            drawRemovedMark(y: endY)
        }
    }

    private func drawRemovedMark(y: CGFloat) {
        Token.Hue.danger.solid.setFill()
        NSRect(x: CodeFileView.markX, y: y - 1, width: Token.Space.sm, height: CodeFileView.markWidth).fill()
    }
}

/// One file of a coding answer: its name and one block of code. Steps stay visible as a numbered line
/// where each one starts, so the candidate can pace the typing without stitching fragments together.
final class CodeFileView: NSView {
    fileprivate static let lineNumberFont = Token.Font.digits(.caption, .regular)
    fileprivate static let stepNumberFont = Token.Font.digits(.caption, .semibold)
    /// Code that is not the step being typed: still readable, but out of the way.
    fileprivate static func dimmed(_ color: NSColor) -> NSColor {
        color.withAlphaComponent(color.alphaComponent * Token.State.setBackAlpha)
    }
    /// Marks the text of a step that is set back, so the contrast audit holds it to the dimmed
    /// threshold instead of the one for code that is being read.
    static let setBackKey = NSAttributedString.Key("InterviewMaster.setBack")
    fileprivate static let markX: CGFloat = 2
    fileprivate static let markWidth: CGFloat = 2

    private let fileLabel = NSTextField(labelWithString: "")
    private let well = CodeWellView()
    private let lineScroll = CodeLineScrollView()
    private let codeView = NSTextView()
    private let copyButton = HoverButton(frame: .zero)
    private let highlighter = SyntaxHighlighter(fontSize: Token.Font.Size.code.points)
    private var copyResetWorkItem: DispatchWorkItem?

    private(set) var section: CodeFileSection
    private var numbersSteps: Bool
    private var showsCopy: Bool
    private var changes: CodeLineChanges?
    /// The step being typed; nil shows every step alike.
    private var currentStep: Int?
    /// Each row's text range, in the order it is drawn.
    private var rowRanges: [(range: NSRange, kind: CodeWellView.RowKind, step: Int)] = []
    private var textSize = NSSize.zero

    private let headerHeight: CGFloat = 26
    private let codePadding: CGFloat = 10

    override var isFlipped: Bool { true }

    init(section: CodeFileSection, numbersSteps: Bool, showsCopy: Bool, changes: CodeLineChanges?, currentStep: Int? = nil) {
        self.section = section
        self.numbersSteps = numbersSteps
        self.showsCopy = showsCopy
        self.changes = changes
        self.currentStep = currentStep
        super.init(frame: .zero)

        fileLabel.font = Token.Font.mono(.caption, .semibold)
        fileLabel.textColor = Token.Color.textStrong
        fileLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(fileLabel)

        well.applySurface(.codeWell)
        addSubview(well)

        codeView.isEditable = false
        codeView.isSelectable = true
        codeView.drawsBackground = false
        codeView.textContainerInset = .zero
        codeView.textContainer?.lineFragmentPadding = 0
        codeView.isVerticallyResizable = false
        codeView.isHorizontallyResizable = false
        codeView.textContainer?.widthTracksTextView = false
        codeView.textContainer?.heightTracksTextView = false
        codeView.textContainer?.containerSize = NSSize(width: 100_000, height: 10_000_000)

        lineScroll.drawsBackground = false
        lineScroll.borderType = .noBorder
        lineScroll.hasVerticalScroller = false
        lineScroll.hasHorizontalScroller = true
        lineScroll.autohidesScrollers = true
        lineScroll.scrollerStyle = .overlay
        lineScroll.verticalScrollElasticity = .none
        lineScroll.documentView = codeView
        well.addSubview(lineScroll)

        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy file")
        copyButton.imagePosition = .imageOnly
        copyButton.symbolConfiguration = Token.Font.symbol(.caption)
        copyButton.isBordered = false
        copyButton.target = self
        copyButton.action = #selector(copyFile)
        copyButton.wantsLayer = true
        copyButton.layer?.cornerRadius = Token.Radius.sm
        copyButton.apply(.ghost)
        addSubview(copyButton)

        apply()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(section newSection: CodeFileSection, numbersSteps newNumbers: Bool, showsCopy newCopy: Bool, changes newChanges: CodeLineChanges?, currentStep newStep: Int? = nil) {
        guard newSection != section || newNumbers != numbersSteps || newCopy != showsCopy || newChanges != changes
                || newStep != currentStep else { return }
        currentStep = newStep
        section = newSection
        numbersSteps = newNumbers
        showsCopy = newCopy
        changes = newChanges
        apply()
    }

    private func apply() {
        fileLabel.stringValue = section.fileName
        fileLabel.toolTip = section.fileName
        copyButton.isHidden = !showsCopy
        copyButton.toolTip = "Copy \(section.fileName)"
        copyButton.setAccessibilityLabel("Copy \(section.fileName)")

        let text = NSMutableAttributedString()
        rowRanges = []
        var isFirstRow = true

        func addRow(_ source: NSAttributedString, kind: CodeWellView.RowKind, step: Int) {
            var row = source
            if let currentStep, step != currentStep {
                let faded = NSMutableAttributedString(attributedString: source)
                let whole = NSRange(location: 0, length: faded.length)
                faded.enumerateAttribute(.foregroundColor, in: whole) { value, range, _ in
                    faded.addAttribute(.foregroundColor, value: Self.dimmed(value as? NSColor ?? Token.Color.textBody), range: range)
                }
                faded.addAttribute(Self.setBackKey, value: true, range: whole)
                row = faded
            }
            // A blank code line is only this character, so it needs the code's font to keep the line height.
            if !isFirstRow {
                text.append(NSAttributedString(string: "\n", attributes: [.font: Token.Font.mono(.code), .paragraphStyle: codeParagraph]))
            }
            isFirstRow = false
            rowRanges.append((NSRange(location: text.length, length: row.length), kind, step))
            text.append(row)
        }

        for (index, chunk) in section.chunks.enumerated() {
            for (lineIndex, line) in noteLines(for: chunk, isFirst: index == 0).enumerated() {
                // Only a note's first line carries the step's number and the hairline above it.
                let kind: CodeWellView.RowKind = lineIndex == 0
                    ? .note(isFirst: index == 0, number: numbersSteps ? chunk.number : nil)
                    : .note(isFirst: true, number: nil)
                addRow(line, kind: kind, step: chunk.number)
            }
            guard !chunk.code.isEmpty else { continue }
            let highlighted = highlighter.highlight(chunk.code, language: Self.highlighterLanguage(for: section.language))
            let code = NSMutableAttributedString(attributedString: highlighted)
            code.addAttribute(.paragraphStyle, value: codeParagraph, range: NSRange(location: 0, length: code.length))
            var line = chunk.firstLine
            let source = code.string as NSString
            source.enumerateSubstrings(in: NSRange(location: 0, length: source.length), options: [.byLines, .substringNotRequired]) { _, range, _, _ in
                addRow(code.attributedSubstring(from: range), kind: .code(line: line), step: chunk.number)
                line += 1
            }
        }

        codeView.textStorage?.setAttributedString(text)
        measureRows()
        well.changes = changes ?? CodeLineChanges()
        setAccessibilityLabel(accessibilityDescription)
        needsLayout = true
    }

    func applyTransparency() {
        well.applySurface(.codeWell)
    }

    private var codeParagraph: NSParagraphStyle {
        let style = Token.Text.paragraph(for: Token.Font.mono(.code), leading: Token.Leading.compact)
        style.lineBreakMode = .byClipping
        return style
    }

    /// The step's note: its number, when there are several, and what the chunk does. The space above it
    /// holds the hairline that marks where a new step starts. The code never wraps, so a note longer
    /// than its measure is split into lines here instead of running off the edge.
    private func noteLines(for chunk: CodeChunk, isFirst: Bool) -> [NSAttributedString] {
        let font = Token.Font.text(.caption)
        func style(first: Bool, last: Bool) -> NSParagraphStyle {
            let style = Token.Text.paragraph(for: font, leading: Token.Leading.compact)
            style.lineBreakMode = .byClipping
            style.paragraphSpacingBefore = first && !isFirst ? Token.Space.md : 0
            style.paragraphSpacing = last ? Token.Space.xs : 0
            return style
        }
        guard !chunk.why.isEmpty || chunk.repeatsEarlierCode else {
            // A numbered step with nothing to say still keeps its line, for the number in the gutter.
            guard numbersSteps else { return [] }
            return [NSAttributedString(string: "\u{200B}", attributes: [.font: font, .paragraphStyle: style(first: true, last: true)])]
        }
        let lines = chunk.why.isEmpty ? [""] : Self.wrapped(chunk.why, font: font, width: Token.Measure.note)
        return lines.enumerated().map { index, text in
            let isLast = index == lines.count - 1
            // A sentence to read, so it takes the body step: the muted one measured Lc 64 on the glass.
            let line = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: Token.Color.textBody])
            if isLast, chunk.repeatsEarlierCode {
                let separator = chunk.why.isEmpty ? "" : Token.Text.separator
                line.append(NSAttributedString(string: separator + "Repeats earlier code", attributes: [.font: font, .foregroundColor: Token.Hue.warning.text]))
            }
            line.addAttribute(.paragraphStyle, value: style(first: index == 0, last: isLast), range: NSRange(location: 0, length: line.length))
            return line
        }
    }

    /// Breaks text between words so that no line is wider than `width`, then evens the lines out, so
    /// a note that needs two lines does not leave one word alone on the second.
    private static func wrapped(_ text: String, font: NSFont, width: CGFloat) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [""] }
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let widths = words.map { ($0 as NSString).size(withAttributes: attributes).width }
        let space = (" " as NSString).size(withAttributes: attributes).width

        /// The index of the first word of each line when no line may be wider than `limit`.
        func starts(within limit: CGFloat) -> [Int] {
            var starts = [0]
            var used = widths[0]
            for index in 1..<words.count {
                if used + space + widths[index] > limit {
                    starts.append(index)
                    used = widths[index]
                } else {
                    used += space + widths[index]
                }
            }
            return starts
        }

        var best = starts(within: width)
        if best.count > 1 {
            // The narrowest limit that still takes the same number of lines.
            var low = width / CGFloat(best.count), high = width
            for _ in 0..<8 {
                let middle = (low + high) / 2
                let candidate = starts(within: middle)
                if candidate.count == best.count {
                    best = candidate
                    high = middle
                } else {
                    low = middle
                }
            }
        }
        return best.enumerated().map { line, start in
            let end = line + 1 < best.count ? best[line + 1] : words.count
            return words[start..<end].joined(separator: " ")
        }
    }

    private func measureRows() {
        guard let layoutManager = codeView.layoutManager, let container = codeView.textContainer,
              let storage = codeView.textStorage, storage.length > 0 else {
            textSize = NSSize(width: 0, height: 16)
            well.rows = []
            return
        }
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container)
        textSize = NSSize(width: ceil(used.width), height: ceil(used.height))
        well.rows = rowRanges.map { row in
            let character = min(row.range.location, storage.length - 1)
            let glyph = layoutManager.glyphIndexForCharacter(at: character)
            let rect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
            let baseline = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
                + layoutManager.location(forGlyphAt: glyph).y + codePadding
            return CodeWellView.Row(
                rect: rect.offsetBy(dx: 0, dy: codePadding), kind: row.kind, baseline: baseline,
                step: row.step, dimmed: currentStep != nil && row.step != currentStep
            )
        }
        well.focusesStep = currentStep != nil
        well.endY = codePadding + textSize.height + 2
    }

    /// Where a step's lines are, in this view's coordinates; nil when the step is in another file.
    func rect(forStep step: Int) -> NSRect? {
        let rows = well.rows.filter { $0.step == step }
        guard let top = rows.map(\.rect.minY).min(), let bottom = rows.map(\.rect.maxY).max() else { return nil }
        return NSRect(x: 0, y: headerHeight + top, width: bounds.width, height: bottom - top)
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

    /// Code does not wrap, so the height depends only on how many lines there are.
    var preferredHeight: CGFloat {
        headerHeight + textSize.height + codePadding * 2
    }

    private var gutterWidth: CGFloat {
        let lastLine = section.chunks.last.map { $0.firstLine + max(1, $0.code.components(separatedBy: "\n").count) } ?? 1
        let digits = max(2, String(lastLine).count)
        let sample = NSAttributedString(string: String(repeating: "0", count: digits), attributes: [.font: Self.lineNumberFont])
        return ceil(sample.size().width) + Token.Space.md * 2
    }

    override func layout() {
        super.layout()
        let control = Token.Sizing.controlSmall
        copyButton.frame = NSRect(x: bounds.width - control, y: (headerHeight - control) / 2 - 2, width: control, height: control)
        fileLabel.frame = NSRect(x: 0, y: 2, width: max(40, bounds.width - (showsCopy ? control + Token.Space.xs : 0)), height: 18)

        well.frame = NSRect(x: 0, y: headerHeight, width: bounds.width, height: textSize.height + codePadding * 2)
        let gutter = gutterWidth
        well.gutterWidth = gutter
        lineScroll.frame = NSRect(x: gutter, y: codePadding, width: max(40, bounds.width - gutter - codePadding), height: textSize.height)
        codeView.frame = NSRect(x: 0, y: 0, width: max(lineScroll.frame.width, textSize.width + Token.Space.sm), height: textSize.height)
    }

    @objc private func copyFile() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(section.code, forType: .string)
        announceForAccessibility("Copied \(section.fileName)")
        copyButton.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Copied")
        copyButton.contentTintColor = Token.Hue.success.text
        copyResetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy file")
            self?.copyButton.contentTintColor = Token.Color.iconDefault
        }
        copyResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Token.Motion.feedbackHold, execute: work)
    }

    private var accessibilityDescription: String {
        var parts = [section.fileName, "\(section.chunks.count) step\(section.chunks.count == 1 ? "" : "s")"]
        if let changes, !changes.changed.isEmpty { parts.append("\(changes.changed.count) changed lines") }
        if let changes, !changes.removedBefore.isEmpty { parts.append("lines removed") }
        return parts.joined(separator: ", ")
    }
}

extension CodeFileView {
    /// Where a file's first rows sit, for the placeholder that stands in for the first file. It is
    /// measured from a real file, so the placeholder cannot drift from what replaces it.
    struct Placeholder {
        /// The file's name: where its text starts, the middle of its line and how wide a short name is.
        let nameX: CGFloat
        let nameMidY: CGFloat
        let nameWidth: CGFloat
        let wellTop: CGFloat
        let wellHeight: CGFloat
        /// Where the line numbers end and where the text beside them starts.
        let numberMaxX: CGFloat
        let textX: CGFloat
        /// The middle of each row's capitals: a step's note, then three lines of code.
        let rowMidYs: [CGFloat]
        /// How far the lines inside a function start further in.
        let indent: CGFloat
        let height: CGFloat
    }

    static let placeholder: Placeholder = {
        let section = CodeFileSection(fileName: "main.py", language: "python", chunks: [
            CodeChunk(number: 1, why: "Note", code: "def f():\n    a\n    b", firstLine: 0, repeatsEarlierCode: false)
        ])
        let file = CodeFileView(section: section, numbersSteps: false, showsCopy: false, changes: nil)
        file.frame = NSRect(x: 0, y: 0, width: 600, height: file.preferredHeight)
        file.layoutSubtreeIfNeeded()
        let nameFont = file.fileLabel.font ?? Token.Font.mono(.caption, .semibold)
        let noteFont = Token.Font.text(.caption)
        let codeFont = Token.Font.mono(.code)
        return Placeholder(
            // A label draws its text two points inside its frame.
            nameX: file.fileLabel.frame.minX + 2,
            nameMidY: file.fileLabel.frame.minY + NSLayoutManager().defaultLineHeight(for: nameFont) / 2,
            nameWidth: ceil((section.fileName as NSString).size(withAttributes: [.font: nameFont]).width),
            wellTop: file.well.frame.minY,
            wellHeight: file.well.frame.height,
            numberMaxX: file.gutterWidth - Token.Space.md,
            textX: file.gutterWidth,
            rowMidYs: file.well.rows.map { row in
                let font = row.kind == .note(isFirst: true, number: nil) ? noteFont : codeFont
                return file.well.frame.minY + row.baseline - font.capHeight / 2
            },
            indent: ceil(("    " as NSString).size(withAttributes: [.font: codeFont]).width),
            height: file.preferredHeight
        )
    }()
}
