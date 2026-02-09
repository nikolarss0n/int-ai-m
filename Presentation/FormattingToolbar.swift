import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    // MARK: - Formatting Toolbar
    func setupFormattingToolbar(in parentView: NSView) {
        // Floating toolbar container - visionOS style
        formattingToolbar = NSVisualEffectView(frame: NSRect(
            x: (parentView.frame.width - 360) / 2,
            y: parentView.frame.height - 60,
            width: 360,
            height: 44
        ))
        formattingToolbar.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        formattingToolbar.blendingMode = .withinWindow
        formattingToolbar.material = .hudWindow
        formattingToolbar.state = .active
        formattingToolbar.alphaValue = 0
        formattingToolbar.isHidden = true
        formattingToolbar.wantsLayer = true
        formattingToolbar.layer?.cornerRadius = 12
        formattingToolbar.layer?.borderWidth = 1.5
        formattingToolbar.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        parentView.addSubview(formattingToolbar)

        let buttonWidth: CGFloat = 40
        let spacing: CGFloat = 4
        var xOffset: CGFloat = 8

        // Heading button
        let headingBtn = createFormattingButton(
            icon: "textformat.size",
            tooltip: "Heading",
            action: #selector(insertHeading)
        )
        headingBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(headingBtn)
        xOffset += buttonWidth + spacing

        // Bold button
        let boldBtn = createFormattingButton(
            icon: "bold",
            tooltip: "Bold",
            action: #selector(insertBold)
        )
        boldBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(boldBtn)
        xOffset += buttonWidth + spacing

        // Italic button
        let italicBtn = createFormattingButton(
            icon: "italic",
            tooltip: "Italic",
            action: #selector(insertItalic)
        )
        italicBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(italicBtn)
        xOffset += buttonWidth + spacing

        // Code button
        let codeBtn = createFormattingButton(
            icon: "chevron.left.forwardslash.chevron.right",
            tooltip: "Code",
            action: #selector(insertCode)
        )
        codeBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(codeBtn)
        xOffset += buttonWidth + spacing

        // Code block button
        let codeBlockBtn = createFormattingButton(
            icon: "curlybraces",
            tooltip: "Code Block",
            action: #selector(insertCodeBlock)
        )
        codeBlockBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(codeBlockBtn)
        xOffset += buttonWidth + spacing

        // List button
        let listBtn = createFormattingButton(
            icon: "list.bullet",
            tooltip: "Bullet List",
            action: #selector(insertList)
        )
        listBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(listBtn)
        xOffset += buttonWidth + spacing

        // Link button
        let linkBtn = createFormattingButton(
            icon: "link",
            tooltip: "Link",
            action: #selector(insertLink)
        )
        linkBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(linkBtn)
        xOffset += buttonWidth + spacing

        // Divider button
        let dividerBtn = createFormattingButton(
            icon: "minus",
            tooltip: "Divider",
            action: #selector(insertDivider)
        )
        dividerBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(dividerBtn)
    }

    func createFormattingButton(icon: String, tooltip: String, action: Selector) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 40, height: 30))
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: tooltip)
        button.bezelStyle = .rounded
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.target = self
        button.action = action
        button.toolTip = tooltip
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.contentTintColor = .white
        return button
    }

    func showFormattingToolbar() {
        guard let toolbar = formattingToolbar, !isFormattingToolbarVisible else { return }
        isFormattingToolbarVisible = true

        toolbar.isHidden = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            toolbar.animator().alphaValue = 0.95
        })
    }

    func hideFormattingToolbar() {
        guard let toolbar = formattingToolbar, isFormattingToolbarVisible else { return }
        isFormattingToolbarVisible = false

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            toolbar.animator().alphaValue = 0
        }, completionHandler: {
            toolbar.isHidden = true
        })
    }

    // MARK: - Formatting Actions
    @objc func insertHeading() {
        insertMarkdownWrapper(prefix: "## ", suffix: "", placeholder: "Heading")
    }

    @objc func insertBold() {
        insertMarkdownWrapper(prefix: "**", suffix: "**", placeholder: "bold text")
    }

    @objc func insertItalic() {
        insertMarkdownWrapper(prefix: "*", suffix: "*", placeholder: "italic text")
    }

    @objc func insertCode() {
        insertMarkdownWrapper(prefix: "`", suffix: "`", placeholder: "code")
    }

    @objc func insertCodeBlock() {
        insertMarkdownWrapper(prefix: "```\n", suffix: "\n```", placeholder: "code block")
    }

    @objc func insertList() {
        let range = textView.selectedRange()
        let selectedText = (textView.string as NSString).substring(with: range)

        guard !selectedText.isEmpty else { return }

        // Split by lines and add bullet to each line
        let lines = selectedText.components(separatedBy: .newlines)
        let bulletedText = lines.map { line in
            line.isEmpty ? "" : "- \(line)"
        }.joined(separator: "\n")

        textView.insertText(bulletedText, replacementRange: range)

        DispatchQueue.main.async {
            self.renderMarkdown()
        }
    }

    @objc func insertLink() {
        insertMarkdownWrapper(prefix: "[", suffix: "](url)", placeholder: "link text")
    }

    @objc func insertDivider() {
        let range = textView.selectedRange()
        textView.insertText("\n\n---\n\n", replacementRange: range)
        renderMarkdown()
    }

    func insertMarkdownWrapper(prefix: String, suffix: String, placeholder: String) {
        let range = textView.selectedRange()
        let selectedText = (textView.string as NSString).substring(with: range)

        // Only format if there's selected text
        guard !selectedText.isEmpty else { return }

        let textToInsert = prefix + selectedText + suffix
        textView.insertText(textToInsert, replacementRange: range)

        // Force re-render markdown
        DispatchQueue.main.async { [weak self] in
            self?.renderMarkdown()
        }
    }
}
