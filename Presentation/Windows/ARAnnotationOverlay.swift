import Cocoa
import ApplicationServices

/// AR-style annotations that float next to actual code lines
/// Uses sharingType = .none to be invisible during screen sharing
@available(macOS 13.0, *)
class ARAnnotationOverlay {

    private var annotationWindows: [NSWindow] = []
    private let lineDetector = TesseractLineDetector()  // Tesseract 5 for better gutter detection
    private var scrollMonitor: Any?
    private var isRefreshing = false
    private var refreshDebounceTimer: Timer?

    // Code suggestions with original pattern and replacement
    struct CodeSuggestion {
        let searchPattern: String      // Keywords to search for in detected code
        let replacementCode: [String]  // Lines of replacement code
    }

    private var codeSuggestions: [CodeSuggestion] = []

    // Simple line-based annotations (fallback)
    private var annotations: [Int: String] = [:]

    // Show detection indicators (terminal-style vertical bars) for all detected lines
    private var showDetectionIndicators = true

    // Track occupied Y ranges to prevent bubble overlap
    private var occupiedYRanges: [(top: CGFloat, bottom: CGFloat)] = []

    // Usage example to show below all bubbles
    private var usageExample: [String]? = nil

    /// Whether annotations are currently visible
    var isShowing: Bool { !annotationWindows.isEmpty || scrollMonitor != nil }

    // MARK: - Public Interface

    /// Start AR overlay with empty boxes (test mode)
    func showWithAutoTest() {
        debugLog("🧪 ARAnnotationOverlay.showWithAutoTest()")
        annotations.removeAll()
        codeSuggestions.removeAll()
        startScrollMonitoring()
        refreshPositions()
    }

    /// Set code suggestions from AI analysis - matches by text content
    func setCodeSuggestions(_ suggestions: [(searchPattern: String, replacementCode: [String])], usageExample: [String]? = nil) {
        codeSuggestions.removeAll()
        for suggestion in suggestions {
            codeSuggestions.append(CodeSuggestion(
                searchPattern: suggestion.searchPattern,
                replacementCode: suggestion.replacementCode
            ))
        }
        self.usageExample = usageExample
        debugLog("📝 AR overlay received \(codeSuggestions.count) code suggestions + usage: \(usageExample != nil)")

        if scrollMonitor == nil {
            startScrollMonitoring()
        }
        refreshPositions()
    }

    /// Set annotations from AI analysis (line number -> comment) - simple mode
    func setAnnotations(_ newAnnotations: [(line: Int, comment: String)]) {
        annotations.removeAll()
        for annotation in newAnnotations {
            annotations[annotation.line] = annotation.comment
        }
        debugLog("📝 AR overlay received \(annotations.count) annotations")

        // Start monitoring if not already
        if scrollMonitor == nil {
            startScrollMonitoring()
        }

        // Refresh to show annotations
        refreshPositions()
    }

    /// Refresh box positions (call after scrolling)
    func refreshPositions() {
        guard !isRefreshing else { return }
        isRefreshing = true
        debugLog("🔄 AROverlay: refreshPositions called")

        Task {
            guard let (windowID, bounds, appName) = lineDetector.findTargetWindow() else {
                debugLog("❌ AROverlay: No target window found - looking for: Code, Chrome, Safari, Firefox, Cursor, WezTerm, iTerm, Terminal")
                await MainActor.run { isRefreshing = false }
                return
            }
            debugLog("✅ AROverlay: Found window '\(appName)' (ID: \(windowID)) at \(bounds)")

            guard let result = await lineDetector.detectCodeLines(windowID: windowID, windowBounds: bounds) else {
                debugLog("❌ AROverlay: Vision detection failed for window \(windowID)")
                await MainActor.run { isRefreshing = false }
                return
            }

            debugLog("📊 AROverlay: Vision found \(result.lines.count) lines, lineHeight=\(result.estimatedLineHeight)")
            for (i, line) in result.lines.prefix(5).enumerated() {
                debugLog("   Line \(i): L\(line.lineNumber ?? -1) y=\(Int(line.screenY)) x=\(Int(line.rightEdgeX)) '\(line.text.prefix(40))'")
            }
            if result.lines.count > 5 {
                debugLog("   ... and \(result.lines.count - 5) more lines")
            }

            await MainActor.run {
                // Remove old boxes and clear occupied ranges
                for window in annotationWindows {
                    window.orderOut(nil)
                }
                annotationWindows.removeAll()
                occupiedYRanges.removeAll()

                // Track which lines already have suggestions
                var usedLineIndices = Set<Int>()

                // First, try to match code suggestions by line number or text content
                for suggestion in codeSuggestions {
                    var matchIndex: Int? = nil
                    var parsedLineNum: Int? = nil

                    // Check if pattern starts with "L{number}:" format for direct line number matching
                    if suggestion.searchPattern.hasPrefix("L"),
                       let colonIndex = suggestion.searchPattern.firstIndex(of: ":") {
                        let numPart = String(suggestion.searchPattern[suggestion.searchPattern.index(after: suggestion.searchPattern.startIndex)..<colonIndex])
                        if let targetLineNum = Int(numPart) {
                            parsedLineNum = targetLineNum  // Save the parsed line number from Claude
                            // Direct line number match with Vision-detected gutter numbers
                            matchIndex = result.lines.firstIndex { line in
                                !usedLineIndices.contains(line.index) && line.lineNumber == targetLineNum
                            }
                            if matchIndex != nil {
                                debugLog("✅ Direct line number match: L\(targetLineNum)")
                            }
                        }
                    }

                    // Fallback to text-based matching
                    if matchIndex == nil {
                        let searchText = suggestion.searchPattern.contains(":") && suggestion.searchPattern.hasPrefix("L")
                            ? String(suggestion.searchPattern.dropFirst(suggestion.searchPattern.firstIndex(of: ":")!.utf16Offset(in: suggestion.searchPattern) + 1))
                            : suggestion.searchPattern
                        matchIndex = findMatchingLine(pattern: searchText, in: result.lines, excluding: usedLineIndices)
                    }

                    if let matchIndex = matchIndex {
                        let startLine = result.lines[matchIndex]
                        let lineCount = suggestion.replacementCode.count

                        // Mark these lines as used
                        for i in 0..<lineCount {
                            if matchIndex + i < result.lines.count {
                                usedLineIndices.insert(matchIndex + i)
                            }
                        }

                        // Use the PARSED line number from Claude's output (L4, L5, etc.)
                        // NOT the Vision-detected line number (which may be wrong or nil)
                        let displayLineNum = parsedLineNum ?? startLine.lineNumber ?? (startLine.index + 1)

                        debugLog("✨ Matched pattern to line \(matchIndex): screenY=\(Int(startLine.screenY)), displayL=\(displayLineNum)")

                        // Create compact code bubble
                        createCodeBubble(
                            startY: startLine.screenY,
                            rightX: startLine.rightEdgeX,
                            lineHeight: result.estimatedLineHeight,
                            codeLines: suggestion.replacementCode,
                            lineNumber: displayLineNum
                        )
                    }
                }

                // Only show annotation bubbles for lines with explicit annotations
                // (Don't show grey dots for every line - it's visual noise)
                for (index, line) in result.lines.enumerated() {
                    if usedLineIndices.contains(index) { continue }

                    let lineNumber = line.lineNumber ?? (line.index + 1)
                    if let comment = annotations[lineNumber] {
                        createAnnotationBubble(
                            lineNumber: lineNumber,
                            screenY: line.screenY,
                            rightX: line.rightEdgeX,
                            lineHeight: result.estimatedLineHeight,
                            comment: comment
                        )
                    }
                }

                // Show detection indicators for ALL detected lines (terminal-style vertical bars)
                // This helps user see that Vision is working and what lines it found
                if showDetectionIndicators {
                    for line in result.lines {
                        if !usedLineIndices.contains(line.index) {
                            createDetectionIndicator(
                                screenY: line.screenY,
                                rightX: line.rightEdgeX,
                                lineHeight: result.estimatedLineHeight,
                                lineNumber: line.lineNumber
                            )
                        }
                    }
                }

                // Create "How to Use" bubble below all other bubbles
                if let usage = usageExample, !usage.isEmpty {
                    // Find the lowest bubble position
                    let lowestY = occupiedYRanges.map { $0.bottom }.min() ?? 200
                    // Use the rightX from the last detected line, or a default
                    let rightX = result.lines.last?.rightEdgeX ?? 400
                    createUsageBubble(
                        usage: usage,
                        screenY: lowestY - 20,  // Place below with gap
                        rightX: rightX
                    )
                }

                isRefreshing = false
            }
        }
    }

    /// Find line that matches the search pattern - tries multiple strategies
    private func findMatchingLine(pattern: String, in lines: [TesseractLineDetector.DetectedCodeLine], excluding: Set<Int>) -> Int? {
        let patternLower = pattern.lowercased()
        let patternNorm = normalizeForMatching(pattern)
        debugLog("🔍 Searching for: '\(pattern.prefix(80))...' in \(lines.count) lines")

        var bestMatch: (index: Int, score: Int)? = nil

        for (index, line) in lines.enumerated() {
            guard !excluding.contains(index) else { continue }

            let lineText = line.text
            let lineTextLower = lineText.lowercased()
            let lineNorm = normalizeForMatching(lineText)

            var score = 0

            // Strategy 1: Normalized substring match (handles OCR variations)
            if lineNorm.contains(patternNorm) || patternNorm.contains(lineNorm) {
                score += 10
            }

            // Strategy 2: Key token overlap (words/identifiers)
            let patternTokens = extractTokens(from: patternLower)
            let lineTokens = extractTokens(from: lineTextLower)
            let commonTokens = patternTokens.intersection(lineTokens)
            score += commonTokens.count * 2

            // Strategy 3: Check for method/function name match
            let identifiers = extractIdentifiers(from: pattern)
            let lineIdentifiers = extractIdentifiers(from: lineText)
            for id in identifiers {
                if lineIdentifiers.contains(id) {
                    score += 5
                } else if lineTextLower.contains(id) {
                    score += 3
                }
            }

            // Strategy 4: Keyword matching
            let keywords = ["func ", "class ", "struct ", "let ", "var ", "if ", "for ", "while ", "guard ", "return ", "def ", "function ", "const ", "private ", "public ", "static "]
            for kw in keywords {
                if patternLower.contains(kw) && lineTextLower.contains(kw.trimmingCharacters(in: .whitespaces)) {
                    score += 1
                }
            }

            // Strategy 5: Character-level similarity for short patterns
            if patternNorm.count > 5 && lineNorm.count > 5 {
                let shorter = patternNorm.count < lineNorm.count ? patternNorm : lineNorm
                let longer = patternNorm.count < lineNorm.count ? lineNorm : patternNorm
                if let range = longer.range(of: shorter.prefix(min(10, shorter.count))) {
                    score += 2
                }
            }

            if score > 0 {
                debugLog("    Line \(index): '\(lineText.prefix(40))...' score=\(score)")
                if bestMatch == nil || score > bestMatch!.score {
                    bestMatch = (index, score)
                }
            }
        }

        // Lower threshold to 2 to catch more matches
        if let match = bestMatch, match.score >= 2 {
            debugLog("✅ Found match at line \(match.index) with score \(match.score)")
            return match.index
        }

        debugLog("❌ No confident match found for pattern (best score: \(bestMatch?.score ?? 0))")
        return nil
    }

    /// Normalize text for fuzzy matching (handles OCR errors)
    private func normalizeForMatching(_ text: String) -> String {
        return text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .filter { $0.isLetter || $0.isNumber }
    }

    /// Extract significant tokens (words > 2 chars)
    private func extractTokens(from text: String) -> Set<String> {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return Set(words.filter { $0.count > 2 })
    }

    /// Extract meaningful identifiers from code (function names, variables, etc.)
    private func extractIdentifiers(from code: String) -> Set<String> {
        var identifiers = Set<String>()

        // Match common patterns: funcName, ClassName, variable_name, CONSTANT
        let patterns = [
            "func\\s+(\\w+)",           // function names
            "class\\s+(\\w+)",          // class names
            "struct\\s+(\\w+)",         // struct names
            "let\\s+(\\w+)",            // let bindings
            "var\\s+(\\w+)",            // var bindings
            "(\\w+)\\s*\\(",            // function calls
            "\\.(\\w+)",                // property/method access
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: code, range: NSRange(code.startIndex..., in: code))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: code) {
                        let id = String(code[range]).lowercased()
                        if id.count > 2 && !["the", "and", "for", "let", "var", "new", "nil", "true", "false"].contains(id) {
                            identifiers.insert(id)
                        }
                    }
                }
            }
        }

        return identifiers
    }

    /// Dismiss all annotation windows and stop monitoring
    func dismiss() {
        stopScrollMonitoring()
        refreshDebounceTimer?.invalidate()
        refreshDebounceTimer = nil
        annotations.removeAll()

        for window in annotationWindows {
            window.orderOut(nil)
        }
        annotationWindows.removeAll()
    }

    // MARK: - Scroll Monitoring

    private func startScrollMonitoring() {
        guard scrollMonitor == nil else { return }

        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
        }
        debugLog("👀 Started scroll monitoring")
    }

    private func stopScrollMonitoring() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
            debugLog("🛑 Stopped scroll monitoring")
        }
    }

    private func handleScrollEvent(_ event: NSEvent) {
        refreshDebounceTimer?.invalidate()
        refreshDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.refreshPositions()
        }
    }

    // MARK: - Box Creation

    /// Create a single combined bubble with comment on top, code below
    private func createCodeBubble(startY: CGFloat, rightX: CGFloat, lineHeight: CGFloat, codeLines: [String], lineNumber: Int) {
        guard let screen = NSScreen.main else { return }
        guard startY > 50 && startY < screen.frame.height - 50 else {
            debugLog("⚠️ Skipping bubble L\(lineNumber): screenY=\(Int(startY)) out of range")
            return
        }

        debugLog("📦 Creating bubble L\(lineNumber) at y=\(Int(startY)) x=\(Int(rightX)) with \(codeLines.count) lines")

        // First line is the comment/fix, rest is code
        let comment = codeLines.first ?? ""
        let codeOnly = Array(codeLines.dropFirst().prefix(3))  // Max 3 code lines

        createCombinedBubble(
            comment: comment,
            codeLines: codeOnly,
            screenY: startY,
            rightX: rightX,
            lineNumber: lineNumber
        )
    }

    /// Single bubble: orange comment header + green code body
    private func createCombinedBubble(comment: String, codeLines: [String], screenY: CGFloat, rightX: CGFloat, lineNumber: Int) {
        guard let screen = NSScreen.main else { return }
        guard screenY > 50 && screenY < screen.frame.height - 50 else { return }

        let commentFont = NSFont.systemFont(ofSize: 10, weight: .medium)
        let codeFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        let padding: CGFloat = 6
        let codeLineHeight: CGFloat = 13
        let maxBubbleWidth: CGFloat = 550  // Allow wider bubbles for full text

        // Calculate width based on content (allow more width)
        let commentWidth = (comment as NSString).size(withAttributes: [.font: commentFont]).width
        let maxCodeWidth = codeLines.map { ($0 as NSString).size(withAttributes: [.font: codeFont]).width }.max() ?? 0
        let bubbleWidth = min(max(commentWidth, maxCodeWidth) + padding * 2 + 40, maxBubbleWidth)

        // Calculate wrapped comment height
        let commentLabelWidth = bubbleWidth - 40
        let commentSize = (comment as NSString).boundingRect(
            with: NSSize(width: commentLabelWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: commentFont]
        )
        let commentHeight = max(ceil(commentSize.height) + 4, 16)

        // Calculate height: comment + code lines
        let hasCode = !codeLines.isEmpty
        let bubbleHeight = commentHeight + (hasCode ? CGFloat(codeLines.count) * codeLineHeight + 4 : 0) + padding * 2

        // Calculate initial Y position (centered on line)
        var bubbleY = screenY - bubbleHeight / 2
        let bubbleTop = bubbleY + bubbleHeight
        let bubbleBottom = bubbleY

        // Check for overlap with existing bubbles and offset if needed
        let minGap: CGFloat = 5  // Minimum gap between bubbles
        for occupied in occupiedYRanges {
            // Check if this bubble overlaps with an occupied range
            if bubbleBottom < occupied.top + minGap && bubbleTop > occupied.bottom - minGap {
                // Overlap detected - push this bubble below the occupied one
                bubbleY = occupied.bottom - bubbleHeight - minGap
                debugLog("📦 Offsetting bubble L\(lineNumber) to avoid overlap: y=\(Int(bubbleY))")
            }
        }

        // Track this bubble's Y range
        occupiedYRanges.append((top: bubbleY + bubbleHeight, bottom: bubbleY))

        let bubble = NSWindow(
            contentRect: NSRect(
                x: rightX + 10,
                y: bubbleY,
                width: bubbleWidth,
                height: bubbleHeight
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        bubble.sharingType = .none
        bubble.level = .floating
        bubble.isOpaque = false
        bubble.backgroundColor = .clear
        bubble.hasShadow = true
        bubble.ignoresMouseEvents = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: bubbleWidth, height: bubbleHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        container.layer?.cornerRadius = 5
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.5).cgColor

        // Line number badge
        let lineLabel = NSTextField(labelWithString: "L\(lineNumber)")
        lineLabel.frame = NSRect(x: padding, y: bubbleHeight - commentHeight - padding + 2, width: 28, height: 14)
        lineLabel.font = .monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        lineLabel.textColor = .systemOrange
        container.addSubview(lineLabel)

        // Comment text (orange) - wrapping enabled
        let commentLabel = NSTextField(wrappingLabelWithString: comment)
        commentLabel.frame = NSRect(x: 32, y: bubbleHeight - commentHeight - padding + 2, width: commentLabelWidth, height: commentHeight)
        commentLabel.font = commentFont
        commentLabel.textColor = NSColor.systemOrange.withAlphaComponent(0.95)
        commentLabel.lineBreakMode = .byWordWrapping
        commentLabel.maximumNumberOfLines = 0  // Unlimited lines
        container.addSubview(commentLabel)

        // Code lines (green) - below the comment
        if hasCode {
            for (i, codeLine) in codeLines.enumerated() {
                let y = bubbleHeight - commentHeight - padding - CGFloat(i + 1) * codeLineHeight - 2
                let label = NSTextField(labelWithString: codeLine)
                label.frame = NSRect(x: padding + 4, y: y, width: bubbleWidth - padding * 2 - 8, height: 12)
                label.font = codeFont
                label.textColor = NSColor.systemGreen.withAlphaComponent(0.9)
                label.lineBreakMode = .byTruncatingTail
                container.addSubview(label)
            }
        }

        // Arrow
        addArrow(to: container, bubbleHeight: bubbleHeight, color: NSColor.black.withAlphaComponent(0.9))

        bubble.contentView = container
        bubble.orderFront(nil)
        annotationWindows.append(bubble)
    }

    /// Blue "How to Use" bubble - shows usage example
    private func createUsageBubble(usage: [String], screenY: CGFloat, rightX: CGFloat) {
        guard let screen = NSScreen.main else { return }
        guard screenY > 50 && screenY < screen.frame.height - 50 else { return }

        let headerFont = NSFont.systemFont(ofSize: 10, weight: .bold)
        let codeFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        let padding: CGFloat = 8
        let codeLineHeight: CGFloat = 14

        // Calculate width based on content
        let maxCodeWidth = usage.map { ($0 as NSString).size(withAttributes: [.font: codeFont]).width }.max() ?? 100
        let bubbleWidth = min(max(maxCodeWidth + padding * 2 + 20, 200), 500)

        // Header + code lines
        let headerHeight: CGFloat = 18
        let bubbleHeight = headerHeight + CGFloat(usage.count) * codeLineHeight + padding * 2

        let bubble = NSWindow(
            contentRect: NSRect(
                x: rightX + 10,
                y: screenY - bubbleHeight,
                width: bubbleWidth,
                height: bubbleHeight
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        bubble.sharingType = .none
        bubble.level = .floating
        bubble.isOpaque = false
        bubble.backgroundColor = .clear
        bubble.hasShadow = true
        bubble.ignoresMouseEvents = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: bubbleWidth, height: bubbleHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        container.layer?.cornerRadius = 5
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.6).cgColor

        // Header "📋 HOW TO USE"
        let headerLabel = NSTextField(labelWithString: "📋 HOW TO USE")
        headerLabel.frame = NSRect(x: padding, y: bubbleHeight - headerHeight - padding + 2, width: bubbleWidth - padding * 2, height: 14)
        headerLabel.font = headerFont
        headerLabel.textColor = NSColor.systemBlue
        container.addSubview(headerLabel)

        // Code lines (cyan)
        for (i, codeLine) in usage.enumerated() {
            let y = bubbleHeight - headerHeight - padding - CGFloat(i + 1) * codeLineHeight
            let label = NSTextField(labelWithString: codeLine)
            label.frame = NSRect(x: padding + 4, y: y, width: bubbleWidth - padding * 2 - 8, height: 12)
            label.font = codeFont
            label.textColor = NSColor.systemCyan.withAlphaComponent(0.95)
            label.lineBreakMode = .byTruncatingTail
            container.addSubview(label)
        }

        // Arrow pointing left
        addArrow(to: container, bubbleHeight: bubbleHeight, color: NSColor.black.withAlphaComponent(0.9))

        bubble.contentView = container
        bubble.orderFront(nil)
        annotationWindows.append(bubble)

        debugLog("📋 Created usage bubble at y=\(Int(screenY)) with \(usage.count) lines")
    }

    /// Orange comment bubble - fits text width dynamically
    private func createCommentBubble(text: String, screenY: CGFloat, rightX: CGFloat, lineNumber: Int) {
        guard let screen = NSScreen.main else { return }
        guard screenY > 50 && screenY < screen.frame.height - 50 else { return }

        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let padding: CGFloat = 8
        let lineNumWidth: CGFloat = 32

        // Dynamic width based on text
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let bubbleWidth = min(max(textWidth + padding * 2 + lineNumWidth + 10, 120), 500)
        let bubbleHeight: CGFloat = 22

        let bubble = NSWindow(
            contentRect: NSRect(
                x: rightX + 12,
                y: screenY - bubbleHeight / 2,
                width: bubbleWidth,
                height: bubbleHeight
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        bubble.sharingType = .none
        bubble.level = .floating
        bubble.isOpaque = false
        bubble.backgroundColor = .clear
        bubble.hasShadow = true
        bubble.ignoresMouseEvents = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: bubbleWidth, height: bubbleHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(red: 0.15, green: 0.1, blue: 0.0, alpha: 0.92).cgColor
        container.layer?.cornerRadius = 4
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.6).cgColor

        // Line number
        let lineLabel = NSTextField(labelWithString: "L\(lineNumber)")
        lineLabel.frame = NSRect(x: 6, y: 3, width: lineNumWidth, height: 16)
        lineLabel.font = .monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        lineLabel.textColor = .systemOrange
        container.addSubview(lineLabel)

        // Comment text
        let commentLabel = NSTextField(labelWithString: text)
        commentLabel.frame = NSRect(x: lineNumWidth + 8, y: 3, width: bubbleWidth - lineNumWidth - 16, height: 16)
        commentLabel.font = font
        commentLabel.textColor = .white
        commentLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(commentLabel)

        // Arrow pointing down-left
        addArrow(to: container, bubbleHeight: bubbleHeight, color: NSColor(red: 0.15, green: 0.1, blue: 0.0, alpha: 0.92))

        bubble.contentView = container
        bubble.orderFront(nil)
        annotationWindows.append(bubble)
    }

    /// Green code bubble - below the comment, dynamic width
    private func createInlineCodeBubble(codeLines: [String], screenY: CGFloat, rightX: CGFloat, lineHeight: CGFloat) {
        guard let screen = NSScreen.main else { return }
        guard screenY > 50 && screenY < screen.frame.height - 50 else { return }

        let codeFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        let lineSpacing: CGFloat = 14
        let padding: CGFloat = 6
        let lineCount = min(codeLines.count, 3)  // Max 3 lines to avoid overlap

        // Dynamic width based on longest code line
        let maxLineWidth = codeLines.prefix(lineCount).map {
            ($0 as NSString).size(withAttributes: [.font: codeFont]).width
        }.max() ?? 100
        let bubbleWidth = min(max(maxLineWidth + padding * 2 + 12, 100), 400)
        let bubbleHeight = CGFloat(lineCount) * lineSpacing + padding * 2

        let bubble = NSWindow(
            contentRect: NSRect(
                x: rightX + 12,
                y: screenY - lineHeight / 2 - 2,  // Align with line, slight offset down
                width: bubbleWidth,
                height: bubbleHeight
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        bubble.sharingType = .none
        bubble.level = .floating
        bubble.isOpaque = false
        bubble.backgroundColor = .clear
        bubble.hasShadow = true
        bubble.ignoresMouseEvents = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: bubbleWidth, height: bubbleHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(red: 0.0, green: 0.12, blue: 0.08, alpha: 0.92).cgColor
        container.layer?.cornerRadius = 4
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.6).cgColor

        // Code lines
        for (i, codeLine) in codeLines.prefix(lineCount).enumerated() {
            let y = bubbleHeight - CGFloat(i + 1) * lineSpacing - padding + 2
            let label = NSTextField(labelWithString: codeLine)
            label.frame = NSRect(x: padding, y: y, width: bubbleWidth - padding * 2, height: 13)
            label.font = codeFont
            label.textColor = NSColor.systemGreen
            label.lineBreakMode = .byClipping
            container.addSubview(label)
        }

        // Arrow
        addArrow(to: container, bubbleHeight: bubbleHeight, color: NSColor(red: 0.0, green: 0.12, blue: 0.08, alpha: 0.92))

        bubble.contentView = container
        bubble.orderFront(nil)
        annotationWindows.append(bubble)
    }

    /// Add arrow pointing left to a bubble container
    private func addArrow(to container: NSView, bubbleHeight: CGFloat, color: NSColor) {
        let arrow = NSView(frame: NSRect(x: -6, y: bubbleHeight/2 - 5, width: 10, height: 10))
        arrow.wantsLayer = true
        let arrowPath = NSBezierPath()
        arrowPath.move(to: NSPoint(x: 10, y: 0))
        arrowPath.line(to: NSPoint(x: 0, y: 5))
        arrowPath.line(to: NSPoint(x: 10, y: 10))
        arrowPath.close()
        let arrowLayer = CAShapeLayer()
        arrowLayer.path = arrowPath.cgPath
        arrowLayer.fillColor = color.cgColor
        arrow.layer?.addSublayer(arrowLayer)
        container.addSubview(arrow)
    }

    private func createLineBox(index: Int, screenY: CGFloat, rightX: CGFloat, lineHeight: CGFloat, comment: String?, lineNumber: Int) {
        // Only used for simple annotations without code
        guard let comment = comment else { return }
        createCommentBubble(text: comment, screenY: screenY, rightX: rightX, lineNumber: lineNumber)
    }

    /// Create a full annotation bubble with comment text (legacy support)
    private func createAnnotationBubble(lineNumber: Int, screenY: CGFloat, rightX: CGFloat, lineHeight: CGFloat, comment: String) {
        createCommentBubble(text: comment, screenY: screenY, rightX: rightX, lineNumber: lineNumber)
    }

    /// Create a small indicator dot (unused)
    private func createIndicatorDot(screenY: CGFloat, rightX: CGFloat) {
        // Disabled - no visual noise
    }

    /// Create a terminal-style vertical bar indicator showing Vision detected this line
    private func createDetectionIndicator(screenY: CGFloat, rightX: CGFloat, lineHeight: CGFloat, lineNumber: Int?) {
        guard let screen = NSScreen.main else { return }
        guard screenY > 50 && screenY < screen.frame.height - 50 else { return }

        let barWidth: CGFloat = 3
        let barHeight: CGFloat = max(lineHeight - 4, 12)

        let indicator = NSWindow(
            contentRect: NSRect(
                x: rightX + 8,
                y: screenY - barHeight / 2,
                width: barWidth,
                height: barHeight
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        indicator.sharingType = .none
        indicator.level = .floating
        indicator.isOpaque = false
        indicator.backgroundColor = .clear
        indicator.hasShadow = false
        indicator.ignoresMouseEvents = true

        let bar = NSView(frame: NSRect(x: 0, y: 0, width: barWidth, height: barHeight))
        bar.wantsLayer = true

        // Cyan/teal color for detection indicators (like terminal cursor)
        let indicatorColor = NSColor(red: 0.0, green: 0.8, blue: 0.8, alpha: 0.7)
        bar.layer?.backgroundColor = indicatorColor.cgColor
        bar.layer?.cornerRadius = 1

        indicator.contentView = bar
        indicator.orderFront(nil)
        annotationWindows.append(indicator)
    }
}
