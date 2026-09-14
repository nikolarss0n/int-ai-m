import Foundation

/// Live conversation briefing shown on the Timeline (digest + resume talking points).
/// Cue cards are a separate path; this type never opens one.
struct InterviewBriefing: Equatable {
    var thread: String
    var digest: String
    var talkingPoints: [String]
}

enum BriefingDecision: Equatable {
    case noChange
    case update(InterviewBriefing)

    var briefing: InterviewBriefing? {
        switch self {
        case .noChange: return nil
        case .update(let briefing): return briefing
        }
    }
}

/// Briefing never opens a cue card. Questions still use the existing card gate.
func briefingOpensCueCard(_ decision: BriefingDecision) -> Bool {
    _ = decision
    return false
}

func nextInterviewBriefing(
    utterance: String,
    isQuestion: Bool,
    resumeText: String,
    prior: InterviewBriefing?
) -> BriefingDecision {
    _ = isQuestion
    let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 8 else { return .noChange }

    var thread = detectBriefingThread(in: trimmed)
    if thread == "unknown" {
        thread = prior?.thread ?? "unknown"
    }
    guard thread != "unknown" else { return .noChange }

    let next = InterviewBriefing(
        thread: thread,
        digest: briefingDigest(utterance: trimmed, thread: thread),
        talkingPoints: talkingPointsFromResume(resumeText, thread: thread)
    )
    if next == prior { return .noChange }
    return .update(next)
}

func formatBriefingContent(_ briefing: InterviewBriefing) -> String {
    var lines = [briefing.digest]
    if briefing.talkingPoints.isEmpty {
        lines.append("No matching resume points for this thread.")
    } else {
        lines.append(contentsOf: briefing.talkingPoints.map { "- [CV] \($0)" })
    }
    return lines.joined(separator: "\n")
}

func extractResumeText(fromMarkdown markdown: String) -> String {
    var text = markdown.replacingOccurrences(of: "\r\n", with: "\n")
    text = text.replacingOccurrences(of: "```[\\s\\S]*?```", with: " ", options: .regularExpression)
    text = text.replacingOccurrences(
        of: #"\[([^\]]+)\]\([^)]+\)"#,
        with: "$1",
        options: .regularExpression
    )
    text = text.replacingOccurrences(of: #"!\[[^\]]*\]\([^)]+\)"#, with: " ", options: .regularExpression)
    text = text.replacingOccurrences(of: #"[*_`#>]+"#, with: " ", options: .regularExpression)
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        while trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            trimmed = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }
    return lines
        .joined(separator: "\n")
        .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func isExperienceCueCardQuestion(_ text: String, topic: String) -> Bool {
    if topic.lowercased() == "personal" { return true }
    let normalized = normalizedBriefingText(text)
    let markers = [
        "did you", "have you", "have you used", "how have you",
        "your experience", "your background", "your last",
        "you use", "you used", "you do with", "you did",
        "walk me through your", "tell me about yourself",
        "in your last", "in your role", "you've", "you have"
    ]
    return markers.contains { normalized.contains($0) }
}

func resumeGroundingInstruction(resumeText: String, questionText: String, topic: String) -> String {
    guard isExperienceCueCardQuestion(questionText, topic: topic) else { return "" }
    let trimmed = resumeText.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return """
        Do not invent personal experience, jobs, or tools the candidate has not listed.
        Do not tell a first-person story about shipping this work.
        """
    }
    return """
    CANDIDATE RESUME (only source of personal experience):
    \(trimmed)
    Use ONLY this resume for personal/experience answers.
    Do not invent jobs, tools, or projects that are not listed.
    If the asked tool or project is not in the resume, do not tell a first-person story about using it.
    """
}

// MARK: - Internals

private let briefingThreadKeywords: [(thread: String, keywords: [String])] = [
    ("rag", [
        "graph rag", "hybrid search", "multi hop", "multi-hop",
        "chunking", "chunk", "embedding", "embeddings", "rerank", "reranking",
        "citation", "citations", "retrieval", "vector db", "vector database",
        "rag"
    ]),
    ("agents", [
        "langgraph", "langchain", "multi agent", "multi-agent",
        "tool calling", "hitl", "human in the loop",
        "react", "agents", "agent"
    ]),
    ("evals", [
        "faithfulness", "grounding", "mrr", "precision", "recall",
        "evals", "eval"
    ]),
    ("production", [
        "fastapi", "pydantic", "langsmith", "mlflow", "serverless",
        "kubernetes", "aks", "k8s", "timeouts", "retries", "production"
    ]),
    ("personal", [
        "tell me about yourself", "your background", "your experience",
        "last project", "introduce yourself"
    ])
]

private func normalizedBriefingText(_ text: String) -> String {
    text.lowercased()
        .replacingOccurrences(of: "’", with: "'")
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func briefingTextContainsKeyword(_ haystack: String, _ keyword: String) -> Bool {
    let needle = keyword.lowercased()
    if needle.contains(" ") {
        return haystack.contains(needle)
    }
    let pattern = "(^|[^a-z0-9])\(NSRegularExpression.escapedPattern(for: needle))($|[^a-z0-9])"
    return haystack.range(of: pattern, options: .regularExpression) != nil
}

func detectBriefingThread(in utterance: String) -> String {
    let normalized = normalizedBriefingText(utterance)
    var bestThread = "unknown"
    var bestScore = 0
    for entry in briefingThreadKeywords {
        let score = entry.keywords.reduce(0) { partial, keyword in
            partial + (briefingTextContainsKeyword(normalized, keyword) ? 1 : 0)
        }
        if score > bestScore {
            bestScore = score
            bestThread = entry.thread
        }
    }
    return bestScore > 0 ? bestThread : "unknown"
}

func briefingDigest(utterance: String, thread: String) -> String {
    let labels = [
        "rag": "RAG / retrieval",
        "agents": "Agents / orchestration",
        "evals": "Evals / grounding",
        "production": "Production / serving",
        "personal": "Background / experience"
    ]
    let label = labels[thread] ?? thread
    let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
    let snippet = trimmed.count > 140 ? String(trimmed.prefix(137)) + "..." : trimmed
    return "\(label): \(snippet)"
}

func talkingPointsFromResume(_ resumeText: String, thread: String) -> [String] {
    let extracted = extractResumeText(fromMarkdown: resumeText)
    guard !extracted.isEmpty else { return [] }
    let keywords = briefingThreadKeywords.first(where: { $0.thread == thread })?.keywords ?? []
    guard !keywords.isEmpty else { return [] }

    var points: [String] = []
    for chunk in resumeChunks(extracted) {
        let normalized = normalizedBriefingText(chunk)
        guard keywords.contains(where: { briefingTextContainsKeyword(normalized, $0) }) else { continue }
        if isNegatedResumeChunk(normalized) { continue }
        let point = compactResumePoint(chunk)
        guard !point.isEmpty, !points.contains(point) else { continue }
        points.append(point)
        if points.count == 4 { break }
    }
    return points
}

private func resumeChunks(_ text: String) -> [String] {
    var chunks: [String] = []
    for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard line.count >= 12 else { continue }
        if line.count > 180 {
            let sentences = line.split(separator: ".", omittingEmptySubsequences: true)
            for sentence in sentences {
                let piece = sentence.trimmingCharacters(in: .whitespaces)
                if piece.count >= 12 { chunks.append(piece) }
            }
        } else {
            chunks.append(line)
        }
    }
    return chunks
}

private func isNegatedResumeChunk(_ normalized: String) -> Bool {
    normalized.hasPrefix("no ") ||
        normalized.hasPrefix("not ") ||
        normalized.hasPrefix("none ") ||
        normalized.contains("no experience") ||
        normalized.contains("not used") ||
        normalized.contains("haven't used") ||
        normalized.contains("have not used")
}

private func compactResumePoint(_ chunk: String) -> String {
    var point = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
    if point.hasSuffix(".") { point = String(point.dropLast()) }
    if point.count > 110 {
        point = String(point.prefix(107)).trimmingCharacters(in: .whitespaces) + "..."
    }
    return point
}
