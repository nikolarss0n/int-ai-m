import Cocoa
import UniformTypeIdentifiers

@available(macOS 14.0, *)
extension InterviewMasterDelegate {

    // MARK: - Export Interview

    @objc func exportInterview() {
        let exportableMessages = voiceMessages.filter { msg in
            switch msg.type {
            case .question, .answer, .followUp, .codingTask:
                return true
            case .userResponse, .status, .screenshot:
                return false
            }
        }

        guard !exportableMessages.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Nothing to Export"
            alert.informativeText = "Start an interview and have some Q&A before exporting."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Export Interview"
        savePanel.canCreateDirectories = true

        // Format selector accessory view
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 32))
        let label = NSTextField(labelWithString: "Format:")
        label.frame = NSRect(x: 0, y: 6, width: 55, height: 20)
        accessoryView.addSubview(label)

        let formatPopup = NSPopUpButton(frame: NSRect(x: 60, y: 2, width: 180, height: 28))
        formatPopup.addItems(withTitles: ["Markdown (.md)", "JSON (.json)"])
        formatPopup.target = nil
        formatPopup.tag = 100
        accessoryView.addSubview(formatPopup)

        savePanel.accessoryView = accessoryView

        // Set default filename
        let dateSuffix = formattedDateForFilename()
        savePanel.nameFieldStringValue = "interview_\(dateSuffix).md"
        savePanel.allowedContentTypes = [.plainText]

        // Update filename when format changes
        formatPopup.target = self
        formatPopup.action = #selector(exportFormatChanged(_:))
        // Store save panel reference in popup's identifier for the callback
        formatPopup.identifier = NSUserInterfaceItemIdentifier("exportFormatPopup")

        if savePanel.runModal() == .OK, let url = savePanel.url {
            let format: ExportFormat = formatPopup.indexOfSelectedItem == 1 ? .json : .markdown
            let useCase = ExportInterviewUseCase()
            let content = useCase.execute(messages: exportableMessages, format: format)

            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }

    @objc func exportFormatChanged(_ sender: NSPopUpButton) {
        // Update save panel filename extension based on format selection
        if let savePanel = sender.window?.sheetParent?.sheets.first as? NSSavePanel
            ?? NSApp.windows.compactMap({ $0 as? NSSavePanel }).first {
            let baseName = savePanel.nameFieldStringValue
                .replacingOccurrences(of: ".md", with: "")
                .replacingOccurrences(of: ".json", with: "")
            let ext = sender.indexOfSelectedItem == 1 ? ".json" : ".md"
            savePanel.nameFieldStringValue = baseName + ext
        }
    }

    func autoSaveSession() {
        let exportableMessages = voiceMessages.filter { msg in
            switch msg.type {
            case .question, .answer, .followUp, .codingTask:
                return true
            default:
                return false
            }
        }
        guard !exportableMessages.isEmpty else { return }

        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/InterviewMaster/sessions")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let useCase = ExportInterviewUseCase()
        let json = useCase.execute(messages: exportableMessages, format: .json)
        let filename = "session_\(formattedDateForFilename()).json"
        let url = dir.appendingPathComponent(filename)

        try? json.write(to: url, atomically: true, encoding: .utf8)
        NSLog("📁 Auto-saved session to \(url.path)")

        // Analyze session and store in memory (async, non-blocking)
        if let client = anthropicClient {
            let analysis = SessionAnalysisUseCase()
            analysis.analyze(messages: exportableMessages, sourceFile: filename, anthropicClient: client)
        }
    }

    private func formattedDateForFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: Date())
    }

    private func cleanUserResponse(_ text: String) -> String {
        var cleaned = text

        while let first = cleaned.unicodeScalars.first, !first.isASCII || first.value < 32 {
            cleaned = String(cleaned.dropFirst())
        }

        let hallucationPrefixes = [
            "tabii,", "tabii", "tabibi", "merci beaucoup", "merci", "gracias",
            "thank you for watching", "thanks for watching", "subscribe",
            "reunited with", "accidental", "nexus,", "nexus"
        ]

        let lowerCleaned = cleaned.lowercased()
        for prefix in hallucationPrefixes {
            if lowerCleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        if let firstChar = cleaned.first, firstChar.isLowercase {
            let words = cleaned.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
            for (index, word) in words.enumerated() {
                if let first = word.first, first.isUppercase && index > 0 {
                    let restOfSentence = words[index...].joined(separator: " ")
                    if restOfSentence.count > 10 {
                        cleaned = restOfSentence
                        break
                    }
                }
            }
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}
