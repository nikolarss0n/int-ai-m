import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {

    @objc func showTemplateSelector() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Interview Templates"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.center()

        let contentView = NSView(frame: panel.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        panel.contentView = contentView

        // Background
        let bg = NSVisualEffectView(frame: contentView.bounds)
        bg.autoresizingMask = [.width, .height]
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        contentView.addSubview(bg)

        // Category tabs
        let tabBar = NSSegmentedControl(frame: NSRect(x: 20, y: contentView.bounds.height - 50, width: contentView.bounds.width - 40, height: 30))
        tabBar.segmentCount = InterviewTemplate.Category.allCases.count
        for (i, cat) in InterviewTemplate.Category.allCases.enumerated() {
            tabBar.setLabel(cat.displayName, forSegment: i)
            tabBar.setWidth(0, forSegment: i) // Auto-size
        }
        tabBar.selectedSegment = 0
        tabBar.segmentStyle = .roundRect
        tabBar.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(tabBar)

        // Scroll view for template list
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: contentView.bounds.width, height: contentView.bounds.height - 60))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        contentView.addSubview(scrollView)

        let listContainer = NSView(frame: NSRect(x: 0, y: 0, width: scrollView.bounds.width, height: 1000))
        scrollView.documentView = listContainer

        // Populate with initial category
        populateTemplateList(in: listContainer, scrollView: scrollView, category: .behavioral, panel: panel)

        // Handle tab changes via timer-based polling (simple approach without NSSegmentedControl target)
        tabBar.target = self
        tabBar.action = #selector(templateCategoryChanged(_:))
        tabBar.identifier = NSUserInterfaceItemIdentifier("templateTabBar")

        // Store references for the callback
        objc_setAssociatedObject(panel, "listContainer", listContainer, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(panel, "scrollView", scrollView, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(tabBar, "panel", panel, .OBJC_ASSOCIATION_RETAIN)

        panel.makeKeyAndOrderFront(nil)
    }

    @objc func templateCategoryChanged(_ sender: NSSegmentedControl) {
        let categories = InterviewTemplate.Category.allCases
        guard sender.selectedSegment >= 0, sender.selectedSegment < categories.count else { return }
        let category = categories[sender.selectedSegment]

        guard let panel = objc_getAssociatedObject(sender, "panel") as? NSPanel,
              let listContainer = objc_getAssociatedObject(panel, "listContainer") as? NSView,
              let scrollView = objc_getAssociatedObject(panel, "scrollView") as? NSScrollView else { return }

        populateTemplateList(in: listContainer, scrollView: scrollView, category: category, panel: panel)
    }

    private func populateTemplateList(in container: NSView, scrollView: NSScrollView, category: InterviewTemplate.Category, panel: NSPanel) {
        container.subviews.forEach { $0.removeFromSuperview() }

        let templates = BuiltInTemplates.templatesForCategory(category)
        let width = scrollView.bounds.width
        var y: CGFloat = 10

        for template in templates {
            // Template card
            let cardHeight: CGFloat = CGFloat(60 + template.questions.count * 28)
            let card = NSView(frame: NSRect(x: 15, y: y, width: width - 30, height: cardHeight))
            card.wantsLayer = true
            card.layer?.cornerRadius = 8
            card.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.055).cgColor
            card.layer?.borderWidth = 1
            card.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor

            // Title
            let title = NSTextField(labelWithString: template.name)
            title.frame = NSRect(x: 15, y: cardHeight - 28, width: card.frame.width - 120, height: 20)
            title.font = .systemFont(ofSize: 14, weight: .semibold)
            title.textColor = .white
            card.addSubview(title)

            // Description
            let desc = NSTextField(labelWithString: template.description)
            desc.frame = NSRect(x: 15, y: cardHeight - 48, width: card.frame.width - 120, height: 16)
            desc.font = .systemFont(ofSize: 11)
            desc.textColor = NSColor.white.withAlphaComponent(0.5)
            card.addSubview(desc)

            // Load button
            let loadButton = NSButton(frame: NSRect(x: card.frame.width - 95, y: cardHeight - 35, width: 80, height: 28))
            loadButton.title = "Load"
            loadButton.bezelStyle = .rounded
            loadButton.font = .systemFont(ofSize: 12, weight: .medium)
            loadButton.contentTintColor = template.category == .testAutomation ? .systemCyan : .white
            loadButton.target = self
            loadButton.action = #selector(loadTemplate(_:))
            loadButton.identifier = NSUserInterfaceItemIdentifier(template.id)
            objc_setAssociatedObject(loadButton, "panel", panel, .OBJC_ASSOCIATION_RETAIN)
            card.addSubview(loadButton)

            // Questions list
            var qy = cardHeight - 60
            for q in template.questions {
                let difficultyColor: NSColor = {
                    switch q.difficulty {
                    case .easy: return NSColor.systemGreen
                    case .medium: return NSColor.systemOrange
                    case .hard: return NSColor.systemRed
                    }
                }()

                let dot = NSView(frame: NSRect(x: 20, y: qy + 4, width: 6, height: 6))
                dot.wantsLayer = true
                dot.layer?.cornerRadius = 3
                dot.layer?.backgroundColor = difficultyColor.cgColor
                card.addSubview(dot)

                let qLabel = NSTextField(labelWithString: q.text)
                qLabel.frame = NSRect(x: 32, y: qy, width: card.frame.width - 50, height: 16)
                qLabel.font = .systemFont(ofSize: 11)
                qLabel.textColor = NSColor.white.withAlphaComponent(0.7)
                qLabel.lineBreakMode = .byTruncatingTail
                card.addSubview(qLabel)

                qy -= 28
            }

            container.addSubview(card)
            y += cardHeight + 10
        }

        container.frame.size.height = max(scrollView.bounds.height, y + 10)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
    }

    @objc func loadTemplate(_ sender: NSButton) {
        guard let templateId = sender.identifier?.rawValue else { return }
        guard let template = BuiltInTemplates.all.first(where: { $0.id == templateId }) else { return }

        // Build markdown outline
        var markdown = "# \(template.name)\n\n"
        markdown += "*\(template.description)*\n\n"

        for (i, q) in template.questions.enumerated() {
            markdown += "## \(i + 1). \(q.text)\n\n"
            markdown += "**Topic:** \(q.topic) | **Difficulty:** \(q.difficulty.rawValue.capitalized)\n\n"
            if !q.hints.isEmpty {
                markdown += "**Hints:**\n"
                for hint in q.hints {
                    markdown += "- \(hint)\n"
                }
                markdown += "\n"
            }
            markdown += "**Your notes:**\n\n\n"
        }

        // Load into notes tab
        textView.string = markdown
        switchToNotesTab()
        renderMarkdown()

        // Close the panel
        if let panel = objc_getAssociatedObject(sender, "panel") as? NSPanel {
            panel.close()
        }
    }
}
