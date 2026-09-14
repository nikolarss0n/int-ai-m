import Foundation
import PDFKit

extension Notification.Name {
    static let resumeDidChange = Notification.Name("resumeDidChange")
}

/// Persists extracted resume text locally. This is the live interview CV,
/// not Context notes.
final class ResumeStore {
    static let shared = ResumeStore()

    private let textKey = "InterviewMaster.ResumeText"
    private let pathKey = "InterviewMaster.ResumeSourcePath"
    private let nameKey = "InterviewMaster.ResumeFileName"

    private init() {}

    var extractedText: String {
        UserDefaults.standard.string(forKey: textKey) ?? ""
    }

    var fileName: String {
        UserDefaults.standard.string(forKey: nameKey) ?? ""
    }

    var sourcePath: String {
        UserDefaults.standard.string(forKey: pathKey) ?? ""
    }

    var hasResume: Bool {
        !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func attach(fileURL: URL) throws {
        let text = try extractResumeText(fromFileURL: fileURL)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(
                domain: "ResumeStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not read any text from that file."]
            )
        }
        UserDefaults.standard.set(text, forKey: textKey)
        UserDefaults.standard.set(fileURL.path, forKey: pathKey)
        UserDefaults.standard.set(fileURL.lastPathComponent, forKey: nameKey)
        NotificationCenter.default.post(name: .resumeDidChange, object: nil)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: textKey)
        UserDefaults.standard.removeObject(forKey: pathKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
        NotificationCenter.default.post(name: .resumeDidChange, object: nil)
    }
}

func extractResumeText(fromFileURL url: URL) throws -> String {
    let ext = url.pathExtension.lowercased()
    if ext == "pdf" {
        guard let document = PDFDocument(url: url) else {
            throw NSError(
                domain: "ResumeStore",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not open the PDF."]
            )
        }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            if let page = document.page(at: index), let string = page.string, !string.isEmpty {
                pages.append(string)
            }
        }
        return extractResumeText(fromMarkdown: pages.joined(separator: "\n"))
    }

    let raw = try String(contentsOf: url, encoding: .utf8)
    return extractResumeText(fromMarkdown: raw)
}
