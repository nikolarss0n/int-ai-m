import Foundation

/// Incremental parser for the combined classify-and-answer reply:
///
///     STATUS:question|TOPIC:oop
///     ---
///     - answer bullet
///
/// The model sometimes drops the `---` separator or the whole STATUS header. The old parser then
/// discarded every answer chunk and the card ended with "No answer text received". This parser
/// always recovers the answer text, so a format slip costs nothing.
enum ClassifierStreamParser {
    struct Parse: Equatable {
        /// First line of the reply when it is a STATUS header, e.g. "STATUS:question|TOPIC:oop".
        var statusLine: String?
        /// The reply started answering without a STATUS header.
        var formatDrift: Bool
        /// Answer text visible so far. Header and separator removed; only ever grows by appending.
        var answer: String
    }

    /// A header line is short. A first line this long with no "STATUS" in it is already answer text.
    private static let driftProbeLength = 12

    /// `headerless` is for the answer-only prompt, where the reply is the answer and nothing else.
    static func parse(_ fullText: String, headerless: Bool = false, streamEnded: Bool = false) -> Parse {
        let text = String(fullText.drop(while: { $0.isWhitespace }))
        if headerless {
            return Parse(statusLine: nil, formatDrift: false, answer: visibleAnswer(from: text, streamEnded: streamEnded))
        }
        guard !text.isEmpty else { return Parse(statusLine: nil, formatDrift: false, answer: "") }

        guard let newline = text.firstIndex(of: "\n") else {
            if isStatusLine(text) {
                // A header with no answer behind it yet (or ever, when the stream ended).
                return Parse(statusLine: streamEnded ? text : nil, formatDrift: false, answer: "")
            }
            let couldStillBeHeader = !streamEnded && text.count < driftProbeLength
                && "status:".hasPrefix(text.lowercased().prefix(7))
            if couldStillBeHeader { return Parse(statusLine: nil, formatDrift: false, answer: "") }
            return drift(text, streamEnded: streamEnded)
        }

        let firstLine = String(text[..<newline])
        if isStatusLine(firstLine) {
            let rest = String(text[text.index(after: newline)...])
            return Parse(statusLine: firstLine, formatDrift: false, answer: visibleAnswer(from: rest, streamEnded: streamEnded))
        }
        return drift(text, streamEnded: streamEnded)
    }

    private static func isStatusLine(_ line: String) -> Bool {
        line.lowercased().contains("status:")
    }

    private static func drift(_ text: String, streamEnded: Bool) -> Parse {
        // Drop any header or separator lines the model scattered into an otherwise plain answer.
        let kept = text.split(separator: "\n", omittingEmptySubsequences: false).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !isStatusLine(trimmed) && !(trimmed.count >= 3 && trimmed.allSatisfy { $0 == "-" })
        }
        let answer = visibleAnswer(from: kept.joined(separator: "\n"), streamEnded: streamEnded)
        return Parse(statusLine: nil, formatDrift: true, answer: answer)
    }

    /// Strips a leading `---` separator. A lone "-" or "--" is held back because it may still turn
    /// into "---"; "- text" is a bullet and passes straight through.
    private static func visibleAnswer(from text: String, streamEnded: Bool) -> String {
        var body = Substring(text).drop(while: { $0.isWhitespace })
        if body.hasPrefix("---") {
            body = body.drop(while: { $0 == "-" }).drop(while: { $0.isWhitespace })
            return String(body)
        }
        if !streamEnded, body == "-" || body == "--" { return "" }
        return String(body)
    }
}
