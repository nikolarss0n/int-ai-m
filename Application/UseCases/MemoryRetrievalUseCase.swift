import Foundation

struct MemoryRetrievalUseCase {

    private let maxTokenBudget = AppConstants.MaxTokens.memoryContext

    func retrieve(forTopics topics: [String]) -> String? {
        guard !topics.isEmpty else { return nil }

        let (sessions, knowledge, profile) = MemoryStore.shared.searchByTopics(topics)
        var parts: [String] = []

        // Past session insights
        if !sessions.isEmpty {
            let topicName = topics.first ?? "this topic"
            let count = sessions.count
            parts.append("You've been asked about \(topicName) \(count) time\(count == 1 ? "" : "s") before")

            if let latest = sessions.last {
                let insights = latest.keyInsights.prefix(2)
                for insight in insights {
                    parts.append(insight)
                }
            }
        }

        // Relevant strengths/weaknesses
        let topicsLower = Set(topics.map { $0.lowercased() })
        let relevantStrengths = profile.strengths.filter { s in
            topicsLower.contains(where: { s.lowercased().contains($0) })
        }
        let relevantWeaknesses = profile.weaknesses.filter { w in
            topicsLower.contains(where: { w.lowercased().contains($0) })
        }
        if !relevantStrengths.isEmpty {
            parts.append("Strength: \(relevantStrengths.joined(separator: ", "))")
        }
        if !relevantWeaknesses.isEmpty {
            parts.append("Area to improve: \(relevantWeaknesses.joined(separator: ", "))")
        }

        // Knowledge notes
        for entry in knowledge.prefix(2) {
            parts.append("Your note: \"\(entry.content)\"")
        }

        guard !parts.isEmpty else { return nil }

        // Enforce token budget (~4 chars per token approximation)
        var result = "MEMORY (from past sessions):\n"
        var charCount = result.count
        for part in parts {
            let line = "• \(part)\n"
            if charCount + line.count > maxTokenBudget * 4 { break }
            result += line
            charCount += line.count
        }

        return result
    }
}
