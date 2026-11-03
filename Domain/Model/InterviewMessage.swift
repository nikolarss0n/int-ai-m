import Foundation

/// Device that captured an interviewer utterance, independent of speaker identity.
enum CaptureDevice: String, CaseIterable {
    case microphone = "microphone"
    case systemAudio = "system"

    var displayName: String {
        switch self {
        case .microphone: return "Microphone"
        case .systemAudio: return "System audio"
        }
    }
}

/// Represents a message in the interview timeline
struct InterviewMessage: Identifiable {
    let id: UUID
    let timestamp: Date
    let type: MessageType
    let content: String
    let topic: String?
    let turnID: UUID?
    let turnSequence: Int?
    var screenshotId: UUID?  // For screenshot type messages
    var audioSource: CaptureDevice?  // Device that captured the audio
    var isCollapsed: Bool = true   // For userResponse - collapsed by default
    var responseLatencyMs: Int?    // Time from question end to completed answer

    enum MessageType {
        case question      // Interviewer question
        case answer        // Generated AI answer
        case userResponse  // User's spoken response (detected as "answer")
        case followUp      // Follow-up answer
        case status        // System status message
        case screenshot    // Screenshot thumbnail in timeline
        case codingTask    // Pinned coding task solution (full width, larger)
        case briefing      // In-place conversation digest + resume talking points
    }

    init(type: MessageType, content: String, topic: String? = nil, screenshotId: UUID? = nil, audioSource: CaptureDevice? = nil, responseLatencyMs: Int? = nil, turnID: UUID? = nil, turnSequence: Int? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.content = content
        self.topic = topic
        self.turnID = turnID
        self.turnSequence = turnSequence
        self.screenshotId = screenshotId
        self.audioSource = audioSource
        self.isCollapsed = (type == .userResponse)  // Collapsed by default for user responses
        self.responseLatencyMs = responseLatencyMs
    }

    var isQuestion: Bool {
        type == .question
    }

    var isAnswer: Bool {
        type == .answer || type == .followUp
    }

    var displayTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    var displayLatency: String? {
        responseLatencyMs.map(InterviewMessage.formatLatency)
    }

    /// "850ms" under a second, "2.4s" above.
    static func formatLatency(_ ms: Int) -> String {
        if ms >= 1000 {
            let seconds = Double(ms) / 1000.0
            return String(format: "%.1fs", seconds)
        } else {
            return "\(ms)ms"
        }
    }
}
