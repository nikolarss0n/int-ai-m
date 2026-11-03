import Foundation

/// How much a message matters, which decides what it may push aside and how long it stays.
enum FeedbackKind: Equatable {
    case info, success, warning, error

    fileprivate var rank: Int {
        switch self {
        case .info, .success: return 0
        case .warning: return 1
        case .error: return 2
        }
    }
}

/// One line of feedback about something that just happened. A confirmation says so and goes; an error
/// stays until it is dismissed or the thing it is about has gone right again.
struct FeedbackNotice: Equatable {
    /// What it is about. A second notice with the same key replaces the first, and resolving the key removes it.
    var key: String
    var kind: FeedbackKind
    var message: String
    /// The longer explanation, for hover and for VoiceOver.
    var detail: String? = nil
    /// A way out or a way back: "Undo", "Show", "Try again". The controller knows what it does.
    var actionTitle: String? = nil
    /// Seconds it stays; `nil` means until it is dismissed or resolved.
    var lasts: TimeInterval? = nil

    static let confirmationHold: TimeInterval = 3.5
    /// A notice with an action needs longer: the person has to read it and reach for the button.
    static let undoHold: TimeInterval = 8

    /// Something worked. It says so and goes; with an action ("Show", "Undo") it stays a little longer.
    static func confirmation(_ key: String, _ message: String, detail: String? = nil, actionTitle: String? = nil) -> FeedbackNotice {
        FeedbackNotice(key: key, kind: .success, message: message, detail: detail, actionTitle: actionTitle,
                       lasts: actionTitle == nil ? confirmationHold : undoHold)
    }

    /// Something to know that needs nothing done, or something done that can be taken back.
    static func info(_ key: String, _ message: String, detail: String? = nil, actionTitle: String? = nil) -> FeedbackNotice {
        FeedbackNotice(key: key, kind: .info, message: message, detail: detail, actionTitle: actionTitle,
                       lasts: actionTitle == nil ? confirmationHold : undoHold)
    }

    /// Something failed. It stays until it is dismissed or the thing it is about goes right.
    static func error(_ key: String, _ message: String, detail: String? = nil, actionTitle: String? = nil) -> FeedbackNotice {
        FeedbackNotice(key: key, kind: .error, message: message, detail: detail, actionTitle: actionTitle, lasts: nil)
    }
}

/// The one notice on screen. Time is passed in, so the rules can be tested without waiting.
struct NoticeBoard {
    private(set) var current: FeedbackNotice?
    private var shownAt: Date?

    /// Shows `notice` unless something more important is already showing (an error is not covered by a
    /// confirmation). Returns whether it was shown.
    @discardableResult
    mutating func show(_ notice: FeedbackNotice, at now: Date) -> Bool {
        expire(at: now)
        if let current, current.key != notice.key, current.kind.rank > notice.kind.rank { return false }
        current = notice
        shownAt = now
        return true
    }

    mutating func dismiss() {
        current = nil
        shownAt = nil
    }

    /// The thing the notice was about has gone right again.
    mutating func resolve(_ key: String) {
        if current?.key == key { dismiss() }
    }

    /// Removes a notice that has lasted as long as it was meant to.
    mutating func expire(at now: Date) {
        guard let lasts = current?.lasts, let shownAt, now.timeIntervalSince(shownAt) >= lasts else { return }
        dismiss()
    }

    /// When the notice on screen goes by itself, for scheduling a refresh.
    var expiry: Date? {
        guard let lasts = current?.lasts, let shownAt else { return nil }
        return shownAt.addingTimeInterval(lasts)
    }
}

/// The words for what went wrong, in the terms of what the person can do about it: what failed, then
/// the fix. A line the person cannot act on says what may have been lost instead.
enum FeedbackCopy {
    /// What a failure was, read from the words of its error. The header notice and the failed card both
    /// take their wording from this, so they never name two causes for one failure.
    enum Cause: Equatable {
        case network, timeout, keyRejected, busy, noText, other
    }

    /// The labels of a notice's button when the fix is somewhere else, or is to do it again.
    static let openSettings = "Open Settings"
    static let tryAgain = "Try again"
    static let showInFinder = "Show in Finder"
    static let export = "Export"
    static let lastQuestionMissed = "The last question may not have been captured."

    static func cause(of message: String) -> Cause {
        let lowered = reason(in: message).lowercased()
        if lowered.contains("no answer text") { return .noText }
        if lowered.contains("timed out") || lowered.contains("timeout") { return .timeout }
        if lowered.contains("network") || lowered.contains("offline") || lowered.contains("connection") || lowered.contains("internet") { return .network }
        if lowered.contains("401") || lowered.contains("unauthorized") || lowered.contains("api key") || lowered.contains("x-api-key") { return .keyRejected }
        if lowered.contains("429") || lowered.contains("rate limit") || lowered.contains("overloaded") { return .busy }
        return .other
    }

    /// The notice for a status line from the pipeline. Only errors get one; progress is not news. Every
    /// status error comes from the audio turn, so each says what happened to the question.
    static func notice(forStatus message: String) -> FeedbackNotice? {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.lowercased().hasPrefix("error:") else { return nil }
        let detail = reason(in: text)
        func error(_ line: String, _ hint: String?, action: String? = nil) -> FeedbackNotice {
            FeedbackNotice(key: "pipeline", kind: .error, message: line, detail: hint, actionTitle: action)
        }
        switch cause(of: detail) {
        case .network:
            return error("Couldn't transcribe. Check your connection.", "Transcription needs a connection to Groq. \(lastQuestionMissed)")
        case .timeout:
            return error("Transcription timed out. Ask again.", "\(lastQuestionMissed) If it keeps happening, check your connection.")
        case .keyRejected:
            return error("Groq API key rejected", "\(lastQuestionMissed) Check the key in Settings.", action: openSettings)
        case .busy:
            return error("Transcription is busy. Ask again in a moment.", "\(lastQuestionMissed) The service is handling too many requests.")
        case .noText, .other:
            return error("Couldn't transcribe. Ask again.", ([detail.isEmpty ? nil : sentence(detail), lastQuestionMissed] as [String?]).compactMap { $0 }.joined(separator: " "))
        }
    }

    /// Why an answer failed, in a line a person can act on. `message` is the pipeline's "Error: ..." text.
    static func failureReason(from message: String) -> String {
        let text = reason(in: message)
        switch cause(of: text) {
        case .noText: return "The model sent back no text."
        case .timeout: return "The model took too long to answer."
        case .network: return "The network connection failed. Check it, then try again."
        case .keyRejected: return "The API key was rejected. Check it in Settings or ~/.interview-master-keys."
        case .busy: return "The service is busy. Wait a moment and try again."
        case .other: break
        }
        guard !text.isEmpty else { return "The model did not answer." }
        let firstSentence = text.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? text
        let clipped = firstSentence.count > 90 ? String(firstSentence.prefix(89)) + "…" : firstSentence
        return sentence(clipped)
    }

    /// ⌘↩ with nothing captured: what to do first is on the line, what comes after is on hover.
    static let nothingToAnalyze = FeedbackNotice.info(
        "analyze", "No screenshots yet. Press ⌘S to capture one.", detail: "Then press ⌘↩ to analyze."
    )

    /// Clicks go to the app behind, so the way back has to be on screen.
    static let clickThroughOn = FeedbackNotice.info(
        "clickThrough", "Click-through is on. Press ⌘I to use this window."
    )

    static let nothingToExport = FeedbackNotice.info(
        "export", "Nothing to export yet", detail: "Export saves the questions and answers from an interview. Start one first."
    )

    static func exported(fileName: String, path: String) -> FeedbackNotice {
        .confirmation("export", "Exported \(fileName)", detail: path)
    }

    static func sessionSaved(path: String) -> FeedbackNotice {
        .confirmation("session", "Session saved", detail: path, actionTitle: showInFinder)
    }

    /// The automatic save failed. Export writes the same interview somewhere else, so the button is there.
    static func sessionNotSaved(reason: String) -> FeedbackNotice {
        .error("session", "Couldn't save the session", detail: sentence(reason) + " Export keeps a copy somewhere else.", actionTitle: export)
    }

    /// The screenshot could not be taken. Doing it again is the fix, so the button is next to the error.
    static func screenshotFailed(detail: String) -> FeedbackNotice {
        FeedbackNotice(key: "screenshot", kind: .error, message: "Couldn't capture the screenshot", detail: detail, actionTitle: tryAgain)
    }

    /// What a clear took away, or `nil` when there was nothing to take.
    static func cleared(screenshots: Int, pinnedCode: Bool) -> String? {
        summary("Cleared", screenshots: screenshots, pinnedCode: pinnedCode)
    }

    /// What Undo put back, in the same words the clear used.
    static func restored(screenshots: Int, pinnedCode: Bool) -> String? {
        summary("Restored", screenshots: screenshots, pinnedCode: pinnedCode)
    }

    /// A reason as one sentence: it ends in a full stop unless it already ends in punctuation.
    static func sentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return "" }
        return ".!?…".contains(last) ? trimmed : trimmed + "."
    }

    /// The message without its "Error:" prefix.
    private static func reason(in message: String) -> String {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.lowercased().hasPrefix("error:") else { return text }
        return String(text.dropFirst("error:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func summary(_ verb: String, screenshots: Int, pinnedCode: Bool) -> String? {
        var parts: [String] = []
        if screenshots > 0 { parts.append(screenshots == 1 ? "1 screenshot" : "\(screenshots) screenshots") }
        if pinnedCode { parts.append("the pinned code") }
        guard !parts.isEmpty else { return nil }
        return verb + " " + parts.joined(separator: " and ")
    }
}
