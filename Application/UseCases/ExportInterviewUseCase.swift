import Foundation

enum ExportFormat: String {
    case markdown
    case json
}

struct ExportData: Codable {
    let version: String
    let exportDate: String
    let settings: ExportSettings
    let messages: [ExportMessage]

    struct ExportSettings: Codable {
        let role: String
        let programmingLanguage: String
        let listeningLanguage: String
        let responseLanguage: String
        let speakingLanguage: String
        let frameworks: String
    }

    struct ExportMessage: Codable {
        let type: String
        let content: String
        let topic: String?
        let timestamp: String
        let audioSource: String?
        let latencyMs: Int?
    }
}

struct ExportInterviewUseCase {

    func execute(messages: [InterviewMessage], format: ExportFormat) -> String {
        let exportable = messages.filter { msg in
            switch msg.type {
            case .question, .answer, .followUp, .codingTask:
                return true
            default:
                return false
            }
        }

        switch format {
        case .markdown:
            return formatMarkdown(exportable)
        case .json:
            return formatJSON(exportable)
        }
    }

    private func formatMarkdown(_ messages: [InterviewMessage]) -> String {
        let settings = AppSettings.shared

        var md = "# Interview Transcript\n\n"
        md += "**Date:** \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))\n"
        md += "**Role:** \(settings.role.displayName)\n"
        md += "**Programming Language:** \(settings.programmingLanguage.displayName)\n"
        md += "**Listening Language:** \(settings.listeningLanguage.displayName)\n"
        md += "**Response Language:** \(settings.responseLanguage.displayName)\n"
        if !settings.frameworks.isEmpty {
            md += "**Frameworks:** \(settings.frameworks)\n"
        }
        md += "\n"
        md += "**Legend:**\n"
        md += "- 🎙️ **Interviewer** - Questions from the interviewer\n"
        md += "- 💡 **Suggested Answer** - AI-generated answer hints\n\n"
        md += "---\n\n"

        var currentTopic: String? = nil

        for msg in messages {
            if let topic = msg.topic, topic != currentTopic, topic != "unknown" {
                md += "## \(topic.capitalized)\n\n"
                currentTopic = topic
            }

            let time = msg.displayTime
            switch msg.type {
            case .question:
                md += "### 🎙️ Interviewer <small>(\(time))</small>\n\n"
                md += "> \(msg.content)\n\n"
            case .answer, .followUp:
                var header = "### 💡 Suggested Answer"
                if let latency = msg.displayLatency {
                    header += " <small>(\(latency))</small>"
                }
                md += "\(header)\n\n"
                md += "\(msg.content)\n\n"
            case .codingTask:
                md += "### 💻 Coding Solution\n\n"
                md += "\(msg.content)\n\n"
            default:
                break
            }
        }

        md += "---\n\n*Exported from Interview Master*\n"
        return md
    }

    private func formatJSON(_ messages: [InterviewMessage]) -> String {
        let settings = AppSettings.shared
        let dateFormatter = ISO8601DateFormatter()

        let exportMessages = messages.map { msg in
            ExportData.ExportMessage(
                type: typeString(msg.type),
                content: msg.content,
                topic: msg.topic,
                timestamp: dateFormatter.string(from: msg.timestamp),
                audioSource: msg.audioSource.map { $0 == .microphone ? "microphone" : "system" },
                latencyMs: msg.responseLatencyMs
            )
        }

        let data = ExportData(
            version: "1.0",
            exportDate: dateFormatter.string(from: Date()),
            settings: ExportData.ExportSettings(
                role: settings.role.displayName,
                programmingLanguage: settings.programmingLanguage.displayName,
                listeningLanguage: settings.listeningLanguage.displayName,
                responseLanguage: settings.responseLanguage.displayName,
                speakingLanguage: settings.responseLanguage.displayName,
                frameworks: settings.frameworks
            ),
            messages: exportMessages
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }

        return jsonString
    }

    private func typeString(_ type: InterviewMessage.MessageType) -> String {
        switch type {
        case .question: return "question"
        case .answer: return "answer"
        case .followUp: return "followUp"
        case .codingTask: return "codingTask"
        case .userResponse: return "userResponse"
        case .status: return "status"
        case .screenshot: return "screenshot"
        }
    }
}
