import Cocoa

@available(macOS 14.0, *)
extension InterviewMasterDelegate {
    @objc func toggleSearch() {
        isSearchVisible.toggle()

        if isSearchVisible {
            searchContainer.isHidden = false
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                searchContainer.animator().alphaValue = 1
            }, completionHandler: {
                self.searchField.becomeFirstResponder()
            })
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                searchContainer.animator().alphaValue = 0
            }, completionHandler: {
                self.searchContainer.isHidden = true
                self.searchField.stringValue = ""
                self.searchResultsLabel.stringValue = ""
                self.clearSearchHighlights()
            })
        }
    }

    @objc func performSearch() {
        let searchTerm = searchField.stringValue.lowercased()
        guard !searchTerm.isEmpty else {
            clearSearchHighlights()
            searchResultsLabel.stringValue = ""
            return
        }

        let text = textView.string.lowercased()
        var matchCount = 0
        var searchStartIndex = text.startIndex

        while let range = text.range(of: searchTerm, range: searchStartIndex..<text.endIndex) {
            matchCount += 1
            searchStartIndex = range.upperBound
        }

        if matchCount > 0 {
            searchResultsLabel.stringValue = "✓ \(matchCount)"
            searchResultsLabel.textColor = .appleGreen
            highlightSearchResults(searchTerm: searchTerm)
        } else {
            searchResultsLabel.stringValue = "✗ 0"
            searchResultsLabel.textColor = .appleRed
            clearSearchHighlights()
        }
    }

    func highlightSearchResults(searchTerm: String) {
        guard let storage = textView.textStorage else { return }
        let text = storage.string
        let lowercasedText = text.lowercased()

        clearSearchHighlights()

        var searchStartIndex = lowercasedText.startIndex
        var firstMatchRange: NSRange?

        while let range = lowercasedText.range(of: searchTerm, range: searchStartIndex..<lowercasedText.endIndex) {
            let nsRange = NSRange(range, in: text)

            if firstMatchRange == nil {
                firstMatchRange = nsRange
            }

            storage.addAttributes([
                .backgroundColor: NSColor.appleGold.withAlphaComponent(0.5),
                .foregroundColor: NSColor.black
            ], range: nsRange)
            searchStartIndex = range.upperBound
        }

        if let firstMatch = firstMatchRange {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.textView.scrollRangeToVisible(firstMatch)
                self.textView.setSelectedRange(firstMatch)
                self.textView.showFindIndicator(for: firstMatch)
            }
        }
    }

    func clearSearchHighlights() {
        renderMarkdown()
    }
}
