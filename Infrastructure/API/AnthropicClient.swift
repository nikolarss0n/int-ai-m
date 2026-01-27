import Foundation

// MARK: - Chat Message Types for Multi-Turn Conversations

/// Represents a message in a multi-turn conversation
struct ChatMessage {
    enum Role: String {
        case user
        case assistant
    }

    let role: Role
    let content: String

    func toDictionary() -> [String: Any] {
        return ["role": role.rawValue, "content": content]
    }
}

/// Manages conversation history for multi-turn chats
class ChatHistory {
    private var messages: [ChatMessage] = []
    private let maxMessages: Int

    init(maxMessages: Int = 20) {
        self.maxMessages = maxMessages
    }

    /// Add a user message
    func addUser(_ content: String) {
        messages.append(ChatMessage(role: .user, content: content))
        trimIfNeeded()
    }

    /// Add an assistant message
    func addAssistant(_ content: String) {
        messages.append(ChatMessage(role: .assistant, content: content))
        trimIfNeeded()
    }

    /// Get messages as array for API
    func toAPIMessages() -> [[String: Any]] {
        return messages.map { $0.toDictionary() }
    }

    /// Get messages with a new user query appended (doesn't modify history)
    func toAPIMessagesWithQuery(_ query: String) -> [[String: Any]] {
        var result = messages.map { $0.toDictionary() }
        result.append(["role": "user", "content": query])
        return result
    }

    /// Clear conversation
    func clear() {
        messages.removeAll()
    }

    /// Check if empty
    var isEmpty: Bool {
        return messages.isEmpty
    }

    /// Get message count
    var count: Int {
        return messages.count
    }

    private func trimIfNeeded() {
        // Keep pairs (user + assistant) to maintain coherent context
        while messages.count > maxMessages {
            // Remove oldest pair
            if messages.count >= 2 {
                messages.removeFirst(2)
            } else {
                messages.removeFirst()
            }
        }
    }
}

/// Infrastructure: Anthropic API Client
/// Handles communication with Anthropic's Claude API
class AnthropicClient {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-haiku-4-5-20251001"
    private let maxTokens = 4096

    /// Retry configuration (matches Anthropic SDK defaults)
    private let maxRetries = 2
    private let retryableStatusCodes: Set<Int> = [408, 409, 429, 500, 502, 503, 529]

    /// Shared URLSession for connection reuse (HTTP/2 multiplexing)
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: config)
    }()

    /// Track if connection has been warmed up
    private var isConnectionWarm = false

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Check if an HTTP status code is retryable
    private func isRetryable(statusCode: Int) -> Bool {
        retryableStatusCodes.contains(statusCode)
    }

    /// Calculate exponential backoff delay for retry attempt
    private func backoffDelay(attempt: Int) -> UInt64 {
        // Exponential backoff: 1s, 2s, 4s with jitter
        let baseDelay = pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.5)
        return UInt64((baseDelay + jitter) * 1_000_000_000)
    }

    /// Pre-warm the connection to Anthropic API (DNS + TCP + TLS handshake)
    /// Call this while STT is running to save ~50-100ms on first request
    func warmupConnection() async {
        guard !isConnectionWarm else { return }

        let startTime = Date()

        // HEAD request to establish connection without sending data
        guard let url = URL(string: "https://api.anthropic.com") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let _ = try await session.data(for: request)
            isConnectionWarm = true
            let latency = Date().timeIntervalSince(startTime) * 1000
            NSLog("🔥 Anthropic connection warmed up in %.0fms", latency)
        } catch {
            // Connection warmup failed, but that's okay - we'll connect on first real request
            NSLog("⚠️ Connection warmup failed (non-critical): %@", error.localizedDescription)
        }
    }

    /// Quick non-streaming message for interview answers
    func sendMessage(prompt: String, maxTokens: Int = 300) async throws -> (text: String, latencyMs: Double) {
        let startTime = Date()

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await session.data(for: request)
        let latency = Date().timeIntervalSince(startTime) * 1000

        struct Response: Codable {
            struct Content: Codable { let text: String }
            let content: [Content]
        }

        let response = try JSONDecoder().decode(Response.self, from: data)
        let text = response.content.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return (text, latency)
    }

    /// Stream text-only message (no images) - for interview answers
    func streamTextMessage(
        prompt: String,
        maxTokens: Int = 300,
        onChunk: @escaping (String) -> Void
    ) async -> Result<Void, Error> {
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        guard let url = URL(string: baseURL) else {
            return .failure(NSError(domain: "Invalid URL", code: -1))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return .failure(error)
        }

        do {
            let (bytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NSError(domain: "Invalid response", code: -1))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                var errorMessage = "HTTP \(httpResponse.statusCode)"
                var errorBody = ""
                for try await line in bytes.lines {
                    errorBody += line + "\n"
                    if errorBody.count > 500 { break }
                }

                if let data = errorBody.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = message
                }

                return .failure(NSError(domain: errorMessage, code: httpResponse.statusCode))
            }

            // Parse SSE stream
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    if jsonString == "[DONE]" { break }

                    if let data = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let type = json["type"] as? String,
                       type == "content_block_delta",
                       let delta = json["delta"] as? [String: Any],
                       let text = delta["text"] as? String {
                        onChunk(text)
                    }
                }
            }

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Stream message with images and optional conversation history (for pinned solution)
    func sendMessageStream(
        images: [String],
        prompt: String,
        prefill: String? = nil,
        conversationHistory: [[String: Any]]? = nil,
        onChunk: @escaping (String) -> Void
    ) async -> Result<Void, Error> {

        // Build request body
        var contentBlocks: [[String: Any]] = []

        // Add images
        for imageBase64 in images {
            contentBlocks.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/png",
                    "data": imageBase64
                ]
            ])
        }

        // Add text
        contentBlocks.append([
            "type": "text",
            "text": prompt
        ])

        // Build messages array: prepend conversation history if provided
        var messages: [[String: Any]] = conversationHistory ?? []

        // Add current user message with images
        messages.append([
            "role": "user",
            "content": contentBlocks
        ])

        // Add prefill if provided (forces model to continue from this point)
        if let prefill = prefill, !prefill.isEmpty {
            messages.append([
                "role": "assistant",
                "content": prefill
            ])
            // Send prefill as first chunk so UI shows it
            onChunk(prefill)
        }

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "messages": messages
        ]

        guard let url = URL(string: baseURL) else {
            return .failure(NSError(domain: "Invalid URL", code: -1))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return .failure(error)
        }

        do {
            let (bytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NSError(domain: "Invalid response", code: -1))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to read error message
                var errorMessage = "HTTP \(httpResponse.statusCode)"
                var errorBody = ""
                for try await line in bytes.lines {
                    errorBody += line + "\n"
                    if errorBody.count > 500 { break } // Limit error message size
                }

                if let data = errorBody.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = message
                }

                return .failure(NSError(domain: errorMessage, code: httpResponse.statusCode))
            }

            // Parse SSE stream
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    if jsonString == "[DONE]" { break }

                    if let data = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let type = json["type"] as? String,
                       type == "content_block_delta",
                       let delta = json["delta"] as? [String: Any],
                       let text = delta["text"] as? String {
                        onChunk(text)
                    }
                }
            }

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Classification result for an utterance
    struct UtteranceClassification {
        let status: String   // "question", "incomplete", "answer", "filler"
        let topic: String?   // topic name or nil
        let normalizedText: String?  // For correcting phonetic STT errors
    }

    /// Static system prompt for classification (cached) - simple and fast
    private static let classificationSystemPrompt = """
You are a helpful assistant that answers questions.
Classify the user's utterance, then answer if it's a question.

=== CLASSIFY ===
Output ONE line: STATUS:xxx|TOPIC:yyy

STATUS:
- question = wants info OR requests action
- incomplete = genuinely cut off mid-word/mid-phrase
- answer = responding/explaining, confirmations, thanks

=== IF question, ADD ANSWER ===
After STATUS line, output "---" then answer in 3-4 bullet points. Be direct, no fluff.
"""

    /// Get topics based on current tech stack setting
    private static func getTopicsForStack() -> String {
        let settings = AppSettings.shared
        let lang = settings.programmingLanguage
        let common = "oop, algorithms, systemDesign, api, aws, patterns, devops, personal, followUp, unknown"

        switch lang {
        case .java:
            return "java, collections, threads, jvm, spring, \(common)"
        case .python:
            return "python, django, fastapi, asyncio, \(common)"
        case .javascript:
            return "javascript, node, react, eventLoop, promises, \(common)"
        case .typescript:
            return "typescript, react, types, generics, \(common)"
        case .go:
            return "go, goroutines, channels, \(common)"
        case .csharp:
            return "csharp, dotnet, linq, async, \(common)"
        case .cpp:
            return "cpp, stl, pointers, memory, \(common)"
        case .rust:
            return "rust, ownership, traits, async, \(common)"
        case .kotlin:
            return "kotlin, coroutines, spring, android, \(common)"
        case .swift:
            return "swift, swiftui, uikit, combine, \(common)"
        }
    }

    /// Combined classify + answer in ONE streaming call with PROMPT CACHING
    /// Returns classification immediately, then streams answer if status is "question"
    func classifyAndStreamAnswer(
        transcription: String,
        buffer: String,
        lastTopic: String?,
        userBackground: String?,
        multiTurnMessages: [[String: String]],
        onClassification: @escaping (UtteranceClassification) -> Void,
        onAnswerChunk: @escaping (String) -> Void
    ) async -> Result<Void, Error> {
        let combinedText = buffer.isEmpty ? transcription : "\(buffer) \(transcription)"

        // Build dynamic user message (compact)
        var userParts: [String] = []
        userParts.append("UTTERANCE: \"\(combinedText)\"")
        userParts.append("TOPICS: \(Self.getTopicsForStack())")
        if let topic = lastTopic { userParts.append("Last topic: \(topic)") }

        if let bg = userBackground, !bg.isEmpty {
            userParts.append("YOUR BACKGROUND: \(bg)")
        }

        let languageInstruction = AppSettings.shared.llmLanguageInstruction
        if !languageInstruction.isEmpty {
            userParts.append(languageInstruction)
        }

        let userMessage = userParts.joined(separator: "\n\n")

        // Build request with PROMPT CACHING - system message is cached
        let systemContent: [[String: Any]] = [
            [
                "type": "text",
                "text": Self.classificationSystemPrompt,
                "cache_control": ["type": "ephemeral"]
            ]
        ]

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 600,
            "stream": true,
            "system": systemContent,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        guard let url = URL(string: baseURL) else {
            return .failure(NSError(domain: "Invalid URL", code: -1))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
        request.addValue("application/json", forHTTPHeaderField: "content-type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return .failure(error)
        }

        do {
            let (bytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NSError(domain: "Invalid response", code: -1))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                var errorMessage = "HTTP \(httpResponse.statusCode)"
                var errorBody = ""
                for try await line in bytes.lines {
                    errorBody += line + "\n"
                    if errorBody.count > 500 { break }
                }
                if let data = errorBody.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = message
                }
                return .failure(NSError(domain: errorMessage, code: httpResponse.statusCode))
            }

            var fullText = ""
            var classificationSent = false
            var answerStarted = false

            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    if jsonString == "[DONE]" { break }

                    if let data = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let type = json["type"] as? String,
                       type == "content_block_delta",
                       let delta = json["delta"] as? [String: Any],
                       let text = delta["text"] as? String {
                        fullText += text

                        // Parse classification from first line
                        if !classificationSent && fullText.contains("\n") {
                            let lines = fullText.components(separatedBy: "\n")
                            if let firstLine = lines.first, firstLine.contains("STATUS:") {
                                let classification = parseClassification(firstLine)
                                classificationSent = true
                                onClassification(classification)

                                // If not a question, we're done after classification
                                if classification.status != "question" {
                                    return .success(())
                                }
                            }
                        }

                        // Stream answer after "---"
                        if classificationSent && !answerStarted && fullText.contains("---") {
                            answerStarted = true
                            // Send any content after ---
                            if let range = fullText.range(of: "---") {
                                let afterSeparator = String(fullText[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                                if !afterSeparator.isEmpty {
                                    onAnswerChunk(afterSeparator)
                                }
                            }
                        } else if answerStarted {
                            onAnswerChunk(text)
                        }
                    }
                }
            }

            // Handle case where classification wasn't parsed (fallback)
            if !classificationSent {
                let classification = parseClassification(fullText)
                onClassification(classification)
            }

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Parse STATUS:xxx|TOPIC:yyy format
    private func parseClassification(_ text: String, originalText: String? = nil) -> UtteranceClassification {
        // For status/topic parsing, use lowercase version
        let cleaned = text.lowercased()
            .replacingOccurrences(of: "\n", with: "")

        var status = "question"
        var topic: String? = "unknown"
        var normalizedText: String? = nil

        // Parse STATUS:xxx
        if let statusRange = cleaned.range(of: "status:") {
            let afterStatus = String(cleaned[statusRange.upperBound...])
            let statusEnd = afterStatus.firstIndex(of: "|") ?? afterStatus.endIndex
            status = String(afterStatus[..<statusEnd]).trimmingCharacters(in: .whitespaces)
        }

        // Parse TOPIC:yyy
        if let topicRange = cleaned.range(of: "topic:") {
            let afterTopic = String(cleaned[topicRange.upperBound...])
            let topicEnd = afterTopic.firstIndex(of: "|") ?? afterTopic.firstIndex(of: "-") ?? afterTopic.endIndex
            let topicValue = String(afterTopic[..<topicEnd]).trimmingCharacters(in: .whitespaces)
            topic = (topicValue == "none" || topicValue.isEmpty) ? nil : topicValue
        }

        // Parse NORMALIZED:zzz (preserve original case for this one)
        let originalCleaned = text.replacingOccurrences(of: "\n", with: "")
        if let normalizedRange = originalCleaned.range(of: "NORMALIZED:", options: .caseInsensitive) {
            let afterNormalized = String(originalCleaned[normalizedRange.upperBound...])
            // NORMALIZED is last field, so take everything until end or "---"
            let normalizedEnd = afterNormalized.range(of: "---")?.lowerBound ?? afterNormalized.endIndex
            let normalizedValue = String(afterNormalized[..<normalizedEnd]).trimmingCharacters(in: .whitespaces)
            if !normalizedValue.isEmpty && normalizedValue != originalText {
                normalizedText = normalizedValue
                NSLog("🔧 Transcript normalized: '%@' → '%@'", originalText ?? "", normalizedValue)
            }
        }

        return UtteranceClassification(status: status, topic: topic, normalizedText: normalizedText)
    }

    /// Summarize a conversation for context compression
    func summarizeConversation(conversationText: String) async throws -> String {
        guard !conversationText.isEmpty else { return "" }

        let prompt = """
        Summarize this interview conversation in 2-3 concise sentences.
        Focus on: main topics discussed, key technical concepts, and any important context for follow-up questions.

        Conversation:
        \(conversationText)

        Summary:
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 150,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await session.data(for: request)

        struct Response: Codable {
            struct Content: Codable { let text: String }
            let content: [Content]
        }

        let response = try JSONDecoder().decode(Response.self, from: data)
        let summary = response.content.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        print("📋 Generated summary: \(summary.prefix(100))...")
        return summary
    }
}
