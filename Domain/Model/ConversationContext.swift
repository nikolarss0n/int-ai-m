import Foundation

/// Tracks conversation history for follow-up detection and context-aware responses
class ConversationContext {
    struct Utterance {
        let text: String
        let speaker: Speaker
        let topic: String?
        let timestamp: Date
    }

    enum Speaker: String {
        case interviewer
        case interviewee
        case unknown
    }

    /// Message format for multi-turn API calls
    struct MultiTurnMessage {
        let role: String  // "user" or "assistant"
        let content: String
    }

    private var history: [Utterance] = []
    private(set) var currentTopic: String?
    private let maxHistory = 50  // Keep more history for full context

    // Multi-turn conversation support
    private(set) var conversationSummary: String?
    private let slidingWindowSize = 8  // 4 Q&A pairs
    private let summarizationThreshold = 12  // Trigger summary after 12 messages

    /// Classify speaker based on heuristics
    func classifySpeaker(text: String, isQuestion: Bool = false) -> Speaker {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(separator: " ")
        let wordCount = words.count
        let lowercased = trimmed.lowercased()

        // If LLM already classified as question, it's the interviewer
        if isQuestion {
            return .interviewer
        }

        // Question indicators
        let hasQuestionMark = trimmed.contains("?")
        let startsWithQuestion = lowercased.hasPrefix("what") ||
                                  lowercased.hasPrefix("how") ||
                                  lowercased.hasPrefix("why") ||
                                  lowercased.hasPrefix("can you") ||
                                  lowercased.hasPrefix("could you") ||
                                  lowercased.hasPrefix("tell me") ||
                                  lowercased.hasPrefix("explain") ||
                                  lowercased.hasPrefix("describe") ||
                                  lowercased.hasPrefix("walk me") ||
                                  lowercased.hasPrefix("so ") ||
                                  lowercased.hasPrefix("let's assume")

        let isFollowUp = lowercased.contains("tell me more") ||
                         lowercased.contains("dig deeper") ||
                         lowercased.contains("elaborate") ||
                         lowercased.contains("can you expand") ||
                         lowercased.contains("more details") ||
                         lowercased.contains("give me an example")

        // Interview greetings/transitions - likely interviewer
        let isInterviewerPhrase = lowercased.contains("welcome to") ||
                                   lowercased.contains("good evening") ||
                                   lowercased.contains("good morning") ||
                                   lowercased.contains("shall proceed") ||
                                   lowercased.contains("gone through your resume") ||
                                   lowercased.contains("let me ask")

        // Short questions = interviewer
        if wordCount < 25 && (hasQuestionMark || startsWithQuestion || isFollowUp || isInterviewerPhrase) {
            return .interviewer
        }

        // Long explanations = interviewee
        if wordCount > 30 {
            return .interviewee
        }

        // Medium length with technical terms might be interviewee answering
        if wordCount > 15 {
            return .interviewee
        }

        return .unknown
    }

    /// Check if this is a follow-up request
    func isFollowUp(text: String) -> Bool {
        let lowercased = text.lowercased()
        let followUpPhrases = [
            "tell me more", "dig deeper", "elaborate", "expand on",
            "more details", "give me an example", "can you explain",
            "what else", "go deeper", "more about", "continue"
        ]
        return followUpPhrases.contains { lowercased.contains($0) }
    }

    /// Add utterance to history
    func addUtterance(text: String, topic: String?, isQuestion: Bool = false) {
        let speaker = classifySpeaker(text: text, isQuestion: isQuestion)
        let utterance = Utterance(text: text, speaker: speaker, topic: topic, timestamp: Date())
        history.append(utterance)

        // Update current topic if we detected one (case-insensitive check)
        let topicLower = topic?.lowercased()
        if let topic = topic, topicLower != "unknown", topicLower != "followup", topicLower != "answer" {
            currentTopic = topic
        }

        // Trim history
        if history.count > maxHistory {
            history.removeFirst()
        }

        print("📝 [\(speaker.rawValue)] \(text.prefix(50))... | Topic: \(topic ?? "none")")
    }

    /// Get recent context for LLM (last 5 utterances)
    func getContextForLLM() -> String {
        guard !history.isEmpty else { return "No previous conversation." }

        let recent = history.suffix(5)
        return recent.map { utterance in
            let topicStr = utterance.topic != nil ? " [topic: \(utterance.topic!)]" : ""
            return "[\(utterance.speaker.rawValue)]: \(utterance.text)\(topicStr)"
        }.joined(separator: "\n")
    }

    /// Get full conversation history for comprehensive context
    func getFullConversation() -> String {
        guard !history.isEmpty else { return "" }

        return history.map { utterance in
            let role = utterance.speaker == .interviewer ? "Q" : "A"
            return "\(role): \(utterance.text)"
        }.joined(separator: "\n")
    }

    /// Get conversation summary (topics discussed)
    func getTopicsSummary() -> String {
        let topics = history.compactMap { $0.topic }.filter {
            $0.lowercased() != "unknown" && $0.lowercased() != "followup" && $0.lowercased() != "answer"
        }
        let unique = Array(Set(topics))
        return unique.isEmpty ? "" : "Topics discussed: \(unique.joined(separator: ", "))"
    }

    /// Get the last topic discussed (for follow-ups)
    var lastTopic: String? {
        return currentTopic
    }

    func clear() {
        history.removeAll()
        currentTopic = nil
        conversationSummary = nil
    }

    // MARK: - Multi-Turn Conversation Support

    /// Check if summarization is needed (history exceeds threshold)
    var needsSummarization: Bool {
        return conversationSummary == nil && history.count > summarizationThreshold
    }

    /// Get messages older than sliding window (for summarization)
    func getMessagesForSummarization() -> [Utterance] {
        guard history.count > slidingWindowSize else { return [] }
        return Array(history.prefix(history.count - slidingWindowSize))
    }

    /// Get formatted text of old messages for summarization API call
    func getTextForSummarization() -> String {
        let oldMessages = getMessagesForSummarization()
        return oldMessages.map { utterance in
            let role = utterance.speaker == .interviewer ? "Interviewer" : "Candidate"
            return "\(role): \(utterance.text)"
        }.joined(separator: "\n")
    }

    /// Set the conversation summary (called after LLM summarizes)
    func setSummary(_ summary: String) {
        conversationSummary = summary
        // Trim history to sliding window size
        if history.count > slidingWindowSize {
            history = Array(history.suffix(slidingWindowSize))
        }
        print("📋 Conversation summarized. Keeping last \(history.count) messages.")
    }

    /// Build multi-turn messages array for API call
    /// Structure: [Summary context] + [Recent sliding window] + [Current utterance]
    func buildMultiTurnMessages(currentUtterance: String, pinnedSolution: String? = nil) -> [MultiTurnMessage] {
        var messages: [MultiTurnMessage] = []

        // 1. Add summary context if exists
        if let summary = conversationSummary {
            var contextContent = "Previous interview context: \(summary)"
            if let pinned = pinnedSolution {
                contextContent += "\n\nCurrent code solution being discussed:\n\(pinned)"
            }
            messages.append(MultiTurnMessage(role: "user", content: contextContent))
            messages.append(MultiTurnMessage(role: "assistant", content: "I understand the context. I'll help with the interview questions."))
        } else if let pinned = pinnedSolution {
            // No summary yet, but have pinned solution
            messages.append(MultiTurnMessage(role: "user", content: "Current code solution being discussed:\n\(pinned)"))
            messages.append(MultiTurnMessage(role: "assistant", content: "I see the code. I'll help with questions about it."))
        }

        // 2. Add recent history as alternating user/assistant messages
        let recentHistory = conversationSummary != nil ? history : Array(history.suffix(slidingWindowSize))

        for utterance in recentHistory {
            let role = utterance.speaker == .interviewer ? "user" : "assistant"
            messages.append(MultiTurnMessage(role: role, content: utterance.text))
        }

        // 3. Add current utterance
        messages.append(MultiTurnMessage(role: "user", content: currentUtterance))

        return messages
    }

    /// Convert multi-turn messages to API format
    func messagesToAPIFormat(_ messages: [MultiTurnMessage]) -> [[String: String]] {
        // Ensure alternating roles (API requirement)
        var result: [[String: String]] = []
        var lastRole: String?

        for msg in messages {
            // If same role as last, merge content
            if msg.role == lastRole, var lastMsg = result.last {
                lastMsg["content"] = (lastMsg["content"] ?? "") + "\n\n" + msg.content
                result[result.count - 1] = lastMsg
            } else {
                result.append(["role": msg.role, "content": msg.content])
                lastRole = msg.role
            }
        }

        // Ensure starts with "user" role
        if result.first?["role"] != "user" {
            result.insert(["role": "user", "content": "(Interview in progress)"], at: 0)
        }

        return result
    }

    // MARK: - Screenshot Analysis Context

    /// Build context for screenshot analysis (returns nil if no history)
    /// Uses sliding window + summary for efficient context
    func buildContextForScreenshotAnalysis() -> [[String: Any]]? {
        guard !history.isEmpty else { return nil }

        var messages: [[String: Any]] = []

        // 1. Add summary context if exists
        if let summary = conversationSummary {
            messages.append(["role": "user", "content": "Previous conversation context: \(summary)"])
            messages.append(["role": "assistant", "content": "I understand the context from our prior discussion."])
        }

        // 2. Add recent history (sliding window)
        let recentHistory = conversationSummary != nil ? history : Array(history.suffix(slidingWindowSize))

        // Build messages with role alternation
        var lastRole: String?
        for utterance in recentHistory {
            let role = utterance.speaker == .interviewer ? "user" : "assistant"

            // If same role as last, merge content
            if role == lastRole, !messages.isEmpty {
                if var lastContent = messages[messages.count - 1]["content"] as? String {
                    lastContent += "\n\n" + utterance.text
                    messages[messages.count - 1]["content"] = lastContent
                }
            } else {
                messages.append(["role": role, "content": utterance.text])
                lastRole = role
            }
        }

        // Ensure starts with "user" role (API requirement)
        if let firstRole = messages.first?["role"] as? String, firstRole != "user" {
            messages.insert(["role": "user", "content": "(Continuing interview discussion)"], at: 0)
        }

        // Ensure ends with "assistant" role so next user message (with images) is valid
        if let lastRole = messages.last?["role"] as? String, lastRole == "user" {
            messages.append(["role": "assistant", "content": "I'm ready to help with the next question."])
        }

        return messages.isEmpty ? nil : messages
    }
}
