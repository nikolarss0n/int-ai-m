import Foundation

/// Practice-only Groq client. Talks to the same Groq HTTP APIs as live assist
/// without adding Help, TTS, or scoring onto GroqInterviewClient.
final class PracticeGroqClient {
    private let apiKey: String
    private let chatURL = "https://api.groq.com/openai/v1/chat/completions"
    private let whisperURL = "https://api.groq.com/openai/v1/audio/transcriptions"
    private let speechURL = "https://api.groq.com/openai/v1/audio/speech"
    private let ttsModel = "canopylabs/orpheus-v1-english"
    private let ttsVoice = "austin"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func transcribe(audioData: Data) async throws -> String {
        let upload = GroqRequestTuning.transcriptionUpload(for: audioData)
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: whisperURL)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        field("model", AppConstants.Models.groqWhisper)
        field("language", "en")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(upload.filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(upload.mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try throwIfHTTPError(response, data: data, domain: "PracticeGroqSTT")
        struct Response: Codable { let text: String }
        return try JSONDecoder().decode(Response.self, from: data).text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func helpCueCard(question: String) async throws -> String {
        let prompt = """
        Cue-card hints for a candidate who asked for help. 3-5 short bullets.
        Every line starts with "- ". Under 90 characters. Plain text, no markdown.
        Cover definition, one example, one trade-off. Do not write a full speech.

        Question: \(question)
        """
        return try await chat(prompt: prompt, maxTokens: 280, temperature: 0.3)
    }

    func judgeAnswer(question: String, answer: String, rubric: String = "") async throws -> (score: Double, feedback: String, strengths: [String], gaps: [String]) {
        let rubricBlock = rubric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : "\nRubric (from the question bank):\n\(rubric)\n"
        let prompt = """
        Score this interview answer from 0 to 1. JSON only, no markdown:
        {"score":0.0,"feedback":"one short paragraph","strengths":["..."],"gaps":["..."]}
        Score raw quality only. Ignore whether the candidate used notes.
        \(rubricBlock)
        Question: \(question)
        Answer: \(answer)
        """
        let raw = try await chat(prompt: prompt, maxTokens: 320, temperature: 0.2)
        if let parsed = parseJudgeJSON(raw) {
            return parsed
        }
        let fallback = heuristicPracticeRawScore(question: question, answer: answer)
        return (fallback, raw.trimmingCharacters(in: .whitespacesAndNewlines), [], [])
    }

    func synthesizeSpeech(text: String) async throws -> Data {
        let clipped = clipForOrpheus(text)
        var request = URLRequest(url: URL(string: speechURL)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": ttsModel,
            "input": clipped,
            "voice": ttsVoice,
            "response_format": "wav"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await session.data(for: request)
        try throwIfHTTPError(response, data: data, domain: "PracticeGroqTTS")
        return data
    }

    private func chat(prompt: String, maxTokens: Int, temperature: Double) async throws -> String {
        let model = AppConstants.Models.groqFastAnswer
        var request = URLRequest(url: URL(string: chatURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": maxTokens,
            "temperature": temperature
        ]
        for (key, value) in GroqRequestTuning.chatReasoningFields(for: model) {
            body[key] = value
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try throwIfHTTPError(response, data: data, domain: "PracticeGroqChat")

        struct ChatResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable { let content: String? }
                let message: Message
            }
            let choices: [Choice]?
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return decoded.choices?.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func throwIfHTTPError(_ response: URLResponse, data: Data, domain: String) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: domain,
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body.prefix(240))"]
            )
        }
    }

    private func clipForOrpheus(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 200 { return trimmed }
        let limit = trimmed.index(trimmed.startIndex, offsetBy: 197)
        return String(trimmed[..<limit]) + "..."
    }

    private func parseJudgeJSON(_ text: String) -> (score: Double, feedback: String, strengths: [String], gaps: [String])? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
        let slice = String(text[start...end]).data(using: .utf8) ?? Data()
        struct Payload: Codable {
            let score: Double
            let feedback: String
            let strengths: [String]?
            let gaps: [String]?
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: slice) else { return nil }
        return (
            min(1, max(0, payload.score)),
            payload.feedback,
            payload.strengths ?? [],
            payload.gaps ?? []
        )
    }
}
