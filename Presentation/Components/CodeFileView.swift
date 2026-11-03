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
        case note(isFirst: Bool)
        case code(line: Int)
    }
    struct Row {
        let rect: NSRect
        let kind: RowKind
    }

    var rows: [Row] = [] { didSet { needsDisplay = true } }
    var changes = CodeLineChanges() { didSet { needsDisplay = true } }
    var gutterWidth: CGFloat = 0 { didSet { needsDisplay = true } }
    /// Where a mark for removed lines goes when they were at the very end of the file.
    var endY: CGFloat = 0

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: CodeFileView.lineNumberFont,
            .foregroundColor: Token.Color.textMuted
        ]
        for row in rows {
            switch row.kind {
            case .note(let isFirst):
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
    /// Each row's text range, in the order it is drawn.
    private var rowRanges: [(range: NSRange, kind: CodeWellView.RowKind)] = []
    private var textSize = NSSize.zero

    private let headerHeight: CGFloat = 26
    private let codePadding: CGFloat = 10

    override var isFlipped: Bool { true }

    init(section: CodeFileSection, numbersSteps: Bool, showsCopy: Bool, changes: CodeLineChanges?) {
        self.section = section
        self.numbersSteps = numbersSteps
        self.showsCopy = showsCopy
        self.changes = changes
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

    func update(section newSection: CodeFileSection, numbersSteps newNumbers: Bool, showsCopy newCopy: Bool, changes newChanges: CodeLineChanges?) {
        guard newSection != section || newNumbers != numbersSteps || newCopy != showsCopy || newChanges != changes else { return }
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

        func addRow(_ row: NSAttributedString, kind: CodeWellView.RowKind) {
            // A blank code line is only this character, so it needs the code's font to keep the line height.
            if !isFirstRow {
                text.append(NSAttributedString(string: "\n", attributes: [.font: Token.Font.mono(.code), .paragraphStyle: codeParagraph]))
            }
            isFirstRow = false
            rowRanges.append((NSRange(location: text.length, length: row.length), kind))
            text.append(row)
        }

        for (index, chunk) in section.chunks.enumerated() {
            if let note = note(for: chunk, isFirst: index == 0) {
                addRow(note, kind: .note(isFirst: index == 0))
            }
            guard !chunk.code.isEmpty else { continue }
            let highlighted = highlighter.highlight(chunk.code, language: Self.highlighterLanguage(for: section.language))
            let code = NSMutableAttributedString(attributedString: highlighted)
            code.addAttribute(.paragraphStyle, value: codeParagraph, range: NSRange(location: 0, length: code.length))
            var line = chunk.firstLine
            let source = code.string as NSString
            source.enumerateSubstrings(in: NSRange(location: 0, length: source.length), options: [.byLines, .substringNotRequired]) { _, range, _, _ in
                addRow(code.attributedSubstring(from: range), kind: .code(line: line))
                line += 1
            }
        }

        codeView.textStorage?.setAttributedString(text)
        measureRows()
        well.changes = changes ?? CodeLineChanges()
        setAccessibilityLabel(accessibilityDescription)
        needsLayout = true
    }

    private var codeParagraph: NSParagraphStyle {
        let style = Token.Text.paragraph(for: Token.Font.mono(.code), leading: Token.Leading.compact)
        style.lineBreakMode = .byClipping
        return style
    }

    /// The step's line: its number, when there are several, and what the chunk does. The space above it
    /// holds the hairline that marks where a new step starts.
    private func note(for chunk: CodeChunk, isFirst: Bool) -> NSAttributedString? {
        guard numbersSteps || !chunk.why.isEmpty || chunk.repeatsEarlierCode else { return nil }
        let font = Token.Font.text(.caption)
        let style = Token.Text.paragraph(for: font, leading: Token.Leading.compact)
        style.lineBreakMode = .byClipping
        style.paragraphSpacingBefore = isFirst ? 0 : Token.Space.md
        style.paragraphSpacing = Token.Space.xs
        let note = NSMutableAttributedString()
        if numbersSteps {
            note.append(NSAttributedString(string: "\(chunk.number)  ", attributes: [
                .font: Token.Font.digits(.caption, .semibold), .foregroundColor: Token.Color.textBody
            ]))
        }
        note.append(NSAttributedString(string: chunk.why, attributes: [.font: font, .foregroundColor: Token.Color.textMuted]))
        if chunk.repeatsEarlierCode {
            let separator = chunk.why.isEmpty ? "" : Token.Text.separator
            note.append(NSAttributedString(string: separator + "Repeats earlier code", attributes: [.font: font, .foregroundColor: Token.Hue.warning.text]))
        }
        note.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: note.length))
        return note
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
            return CodeWellView.Row(rect: rect.offsetBy(dx: 0, dy: codePadding), kind: row.kind)
        }
        well.endY = codePadding + textSize.height + 2
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
