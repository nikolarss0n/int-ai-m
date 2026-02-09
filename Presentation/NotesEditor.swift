import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    // MARK: - Markdown Rendering (Basic)
    func renderMarkdown() {
        guard let storage = textView.textStorage else { return }
        notesMarkdownRenderer.render(in: storage)
    }

    // MARK: - Markdown Rendering for Analysis View
    func renderAnalysisMarkdown() {
        guard let storage = analysisTextView.textStorage else { return }
        analysisMarkdownRenderer.render(in: storage)
    }

    // MARK: - NSTextViewDelegate
    func textDidChange(_ notification: Notification) {
        // Re-render markdown with debounce to prevent conflicts
        guard let currentTextView = notification.object as? NSTextView else { return }
        if currentTextView == textView {
            let currentLength = textView.string.count
            let textGrew = currentLength > lastTextLength

            // Only auto-continue lists when text grew (not when deleting)
            if textGrew {
                handleListAutoContinuation()
            }

            lastTextLength = currentLength

            // Auto-save notes to UserDefaults
            saveNotes()

            renderTimer?.invalidate()
            renderTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                let renderer = self.notesMarkdownRenderer
                DispatchQueue.global(qos: .userInitiated).async {
                    DispatchQueue.main.async {
                        guard let storage = self.textView.textStorage else { return }
                        renderer.render(in: storage)
                    }
                }
            }
        }
    }

    // MARK: - Persistence
    func saveNotes() {
        UserDefaults.standard.set(textView.string, forKey: notesStorageKey)
    }

    func handleListAutoContinuation() {
        let text = textView.string as NSString
        let cursorLocation = textView.selectedRange().location

        // Check if user just pressed Enter (newline at cursor-1)
        guard cursorLocation > 0,
              cursorLocation <= text.length,
              text.character(at: cursorLocation - 1) == 10 else { return } // 10 = newline

        // Find the start of the previous line
        var lineStart = cursorLocation - 2
        while lineStart > 0 && text.character(at: lineStart) != 10 {
            lineStart -= 1
        }
        if lineStart > 0 { lineStart += 1 }

        // Get the previous line
        let lineLength = cursorLocation - lineStart - 1
        guard lineLength > 0 else { return }
        let previousLine = text.substring(with: NSRange(location: lineStart, length: lineLength))

        // Check if previous line starts with "- " or is just "- "
        if previousLine.hasPrefix("- ") {
            let content = String(previousLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)

            // If previous line was just "- " (empty bullet), remove it and stop list
            if content.isEmpty {
                // Remove the bullet line and the newline we just added
                textView.undoManager?.beginUndoGrouping()
                let removeRange = NSRange(location: lineStart, length: lineLength + 1)
                textView.shouldChangeText(in: removeRange, replacementString: "")
                textView.replaceCharacters(in: removeRange, with: "")
                textView.didChangeText()
                textView.undoManager?.endUndoGrouping()
            } else {
                // Add new bullet for next item
                textView.insertText("- ", replacementRange: NSRange(location: cursorLocation, length: 0))
            }
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        // Show toolbar when editing notes
        guard let currentTextView = notification.object as? NSTextView else { return }
        if currentTextView == textView && currentTab == .notes {
            showFormattingToolbar()
        }
    }
}
