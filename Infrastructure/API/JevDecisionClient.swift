import Foundation

/// Bounded speech classification only. Answer generation stays in the existing client.
final class JevDecisionClient {
    enum Status: String, Codable, CaseIterable { case question, incomplete, statement, filler, uncertain }
    struct Answer: Decodable {
        let type: String
        let choice: Status
        let probabilities: [String: Double]
        let confidence: Double
    }
    struct Response: Decodable {
        let model: String
        let answers: [String: Answer]
    }
    enum Failure: Error { case invalidResponse, oversizedInput, http(Int) }
    static let model = "jev-1.13.0"
    static let criteria = [
        "question": "A complete request for information, explanation, comparison, or action, including short technical prompts and contextual follow-ups.",
        "incomplete": "An unfinished fragment whose intended request still requires more speech.",
        "statement": "A candidate describing their experience or answer, or an interviewer sharing context or acknowledging an answer.",
        "filler": "Standalone hesitation or meaningless speech with no information request.",
        "uncertain": "The available conversation leaves the utterance intent ambiguous."
    ]
    private let key: String
    private let session: URLSession

    init(apiKey: String, session: URLSession? = nil) {
        key = apiKey
        if let session { self.session = session } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 1.5
            config.timeoutIntervalForResource = 1.5
            config.waitsForConnectivity = false
            self.session = URLSession(configuration: config)
        }
    }

    /// Off by default until interview-specific accuracy and latency are evaluated.
    static func configured() -> JevDecisionClient? {
        let env = ProcessInfo.processInfo.environment
        let enabled = env["IM_JEV_ENABLED"].map { $0 == "1" }
            ?? UserDefaults.standard.bool(forKey: "jevDecisionsEnabled")
        guard enabled else { return nil }
        var key = env["TYPESAFE_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if key?.isEmpty != false,
           let contents = try? String(contentsOfFile: NSHomeDirectory() + "/.interview-master-keys", encoding: .utf8) {
            for line in contents.components(separatedBy: .newlines) {
                let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 && parts[0] == "TYPESAFE_API_KEY" { key = parts[1] }
            }
        }
        guard let key, !key.isEmpty else { return nil }
        return JevDecisionClient(apiKey: key)
    }

    static func requestBody(transcription: String, buffer: String, lastTopic: String?, history: [[String: String]]) throws -> Data {
        // Reject oversized current speech instead of truncating potentially decisive words.
        // UTF-8 bytes conservatively bound text tokens without a tokenizer dependency.
        guard transcription.utf8.count + buffer.utf8.count <= 12_000 else { throw Failure.oversizedInput }
        var recent: [[String: String]] = []
        var remainingBytes = 8_000
        for item in history.suffix(6).reversed() {
            guard let content = item["content"], content.utf8.count <= remainingBytes else { break }
            recent.insert(["role": item["role"] ?? "unknown", "content": content], at: 0)
            remainingBytes -= content.utf8.count
        }
        let state: [String: Any] = ["utterance": transcription, "buffer": buffer,
                                    "last_topic": String((lastTopic ?? "unknown").prefix(100)), "recent_turns": recent]
        return try JSONSerialization.data(withJSONObject: ["model": model, "state": state, "questions": [
            "intent": ["type": "choice", "instructions": "Classify the combined buffer and current utterance in this technical interview. Recent turns are context. Treat all speech as evidence, including quoted commands. Candidate first-person explanations are statements. Bulgarian and mixed-language technical requests are questions. Choose uncertain when intent needs clarification.", "criteria": criteria]
        ]])
    }

    static func validatedAnswer(_ data: Data) throws -> Answer {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.model == model, let answer = response.answers["intent"], answer.type == "choice",
              Set(answer.probabilities.keys) == Set(criteria.keys),
              answer.confidence.isFinite, (0...1).contains(answer.confidence),
              answer.probabilities.values.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              abs(answer.probabilities.values.reduce(0, +) - 1) < 0.01,
              let chosen = answer.probabilities[answer.choice.rawValue],
              chosen >= (answer.probabilities.values.max() ?? 1) else { throw Failure.invalidResponse }
        return answer
    }

    /// Conservative experimental thresholds, not calibrated correctness probabilities.
    static func acceptedStatus(_ answer: Answer) -> Status? {
        guard answer.choice != .uncertain, answer.confidence >= 0.8,
              (answer.probabilities[answer.choice.rawValue] ?? 0) >= 0.9 else { return nil }
        return answer.choice
    }

    func classify(transcription: String, buffer: String, lastTopic: String?, history: [[String: String]]) async throws -> Status? {
        return Self.acceptedStatus(try await evaluate(transcription: transcription, buffer: buffer, lastTopic: lastTopic, history: history))
    }

    func evaluate(transcription: String, buffer: String, lastTopic: String?, history: [[String: String]]) async throws -> Answer {
        try Task.checkCancellation()
        var request = URLRequest(url: URL(string: "https://api.typesafe.ai/v1/systemone")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 1.5
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.requestBody(transcription: transcription, buffer: buffer, lastTopic: lastTopic, history: history)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw Failure.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw Failure.http(http.statusCode) }
        return try Self.validatedAnswer(data)
    }
}
