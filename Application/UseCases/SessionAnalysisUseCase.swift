import Foundation

struct SessionAnalysisUseCase {

    func analyze(messages: [InterviewMessage], sourceFile: String, anthropicClient: AnthropicClient) {
        let exportable = messages.filter { msg in
            switch msg.type {
            case .question, .answer, .followUp, .codingTask:
                return true
            default:
                return false
            }
        }
        guard exportable.count >= 2 else { return }

        let transcript = exportable.map { msg -> String in
            let role: String
            switch msg.type {
            case .question: role = "Interviewer"
            case .answer, .followUp: role = "Answer"
            case .codingTask: role = "Code Solution"
            default: role = "Other"
            }
            let topicStr = msg.topic.map { " [\($0)]" } ?? ""
            return "\(role)\(topicStr): \(msg.content)"
        }.joined(separator: "\n")

        Task {
            do {
                let result = try await anthropicClient.analyzeSession(transcript: transcript)
                let summary = SessionSummary(
                    id: UUID().uuidString,
                    date: Date(),
                    topics: result.topics,
                    questionsAsked: exportable.filter { $0.type == .question }.count,
                    keyInsights: result.insights,
                    sourceFile: sourceFile
                )
                MemoryStore.shared.addSessionSummary(summary)
                MemoryStore.shared.updateUserProfile(
                    strengths: result.strengths,
                    weaknesses: result.weaknesses
                )
                NSLog("🧠 Session analysis complete: %d topics, %d insights", result.topics.count, result.insights.count)
            } catch {
                NSLog("⚠️ Session analysis failed: %@", error.localizedDescription)
            }
        }
    }
}
