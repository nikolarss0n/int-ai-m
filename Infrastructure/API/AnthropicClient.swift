import Foundation

/// Infrastructure: Anthropic API Client
/// Handles communication with Anthropic's Claude API
class AnthropicClient {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-haiku-4-5-20251001"
    private let maxTokens = 4096

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

    /// Classification result for an utterance
    struct UtteranceClassification {
        let status: String   // "question", "incomplete", "statement" (or "answer" for backwards compat), "filler"
        let topic: String?   // topic name or nil
        let normalizedText: String?  // Corrected transcript (fixes phonetic STT errors like "KKWOI" → "Какво")
    }

    /// Static system prompt for classification (cached) - OPTIMIZED: topics come from settings
    private static let classificationSystemPrompt = """
You are a Technical Interview Coach. Convert topics into speakable flashcards.

=== SPEECH-TO-TEXT NORMALIZATION ===
The UTTERANCE is from multilingual speech recognition. It may contain phonetic errors when mixing languages.
Common patterns to fix:
- "KKWOI" or "kakvo" → "Какво" (Bulgarian "What")
- "kak" → "Как" (Bulgarian "How")
- "hashmap" heard correctly but surrounding words garbled
- Technical terms in English mixed with non-English question words

=== OUTPUT FORMAT ===
Line 1: STATUS:xxx|TOPIC:yyy|NORMALIZED:zzz
Line 2: ---
Line 3+: Answer (only if STATUS is question)

STATUS: question | incomplete | statement
NORMALIZED: The corrected transcript with proper spelling (fix phonetic errors, keep technical terms)

=== ANSWER FORMAT ===
ALWAYS start with a plain English summary that answers "when/why use this?" in simple terms.
Then add technical bullets. Keep it minimal.

SINGLE CONCEPT:
Line 1: Plain English summary - NO jargon (what it does, when to use it)
Line 2+: Technical details with complexity

COMPARISON (X vs Y):
Line 1: Plain English - NO jargon, explain like talking to someone ("X = fast to do this. Y = fast to do that.")
Then: Bullets with technical differences

ENUMERATION: Just the list
- **Name**: What it does (5-8 words max)

=== STYLE ===
- Phrases, not full sentences
- NO extras: no "Watch out", "Pro tip", "Common use", "Key features"
- Just answer the question, nothing more

=== LANGUAGE RULE ===
When answering in non-English languages (Bulgarian, German, Spanish, etc.):
1. Keep ALL programming/CS terms in English: key-value, hash code, bucket, collision, load factor, thread-safe, mapping, lookup, insert, delete, chaining, etc.
2. NEVER translate technical terms to the target language (no "колизии" → use "collisions", no "ключ-стойност" → use "key-value")
3. NEVER use Chinese, Japanese, or Korean characters - only Latin/Cyrillic as appropriate

Example for Bulgarian:
- YES: "HashMap е key-value структура с O(1) lookup. При collisions използва chaining."
- NO: "HashMap е ключ-стойност структура" (don't translate)
- NO: "При колизии използва..." (use "collisions" not "колизии")

=== EXAMPLES ===

Q: "What is a HashMap?"
A:
Use when you need fast lookups by key.
• O(1) average for get/put/remove
• Uses hash function to map keys to buckets

Q: "What is a closure?"
A:
Use when you need a function to remember variables from where it was created.
• Function that captures variables from enclosing scope

Q: "ArrayList vs LinkedList?"
A:
ArrayList = fast to read any item. LinkedList = fast to add/remove at the beginning or end.
• ArrayList: O(1) access, O(n) insert middle
• LinkedList: O(n) access, O(1) insert at ends

Q: "What are OOP principles?"
A:
- **Encapsulation**: Hide internals, expose interface
- **Inheritance**: Reuse parent behavior
- **Polymorphism**: Same interface, different implementations
- **Abstraction**: Hide complexity

Q: "What HTTP methods exist?"
A:
- **GET**: Read
- **POST**: Create
- **PUT**: Replace
- **PATCH**: Update
- **DELETE**: Remove

CODE only if explicitly asked.
"""

    /// Get topics based on current role and programming language settings
    private static func getTopicsForSettings() -> String {
        let settings = AppSettings.shared
        let role = settings.role
        let lang = settings.programmingLanguage
        let common = "oop, algorithms, systemDesign, api, aws, patterns, devops, personal, followUp, unknown"

        // QA-specific topics
        let qaTopics = "testAutomation, selenium, playwright, cypress, apiTesting, e2eTesting, unitTesting, integrationTesting, mocking, fixtures, pageObjects, testStrategy, cicd, llmEvaluation, promptTesting, genAI, chatbotTesting"

        // Language-specific topics
        var langTopics: String
        switch lang {
        case .java:
            langTopics = "java, collections, threads, jvm, spring"
        case .python:
            langTopics = "python, django, fastapi, asyncio, pytest"
        case .javascript:
            langTopics = "javascript, node, react, eventLoop, promises"
        case .typescript:
            langTopics = "typescript, react, types, generics, jest"
        case .go:
            langTopics = "go, goroutines, channels"
        case .csharp:
            langTopics = "csharp, dotnet, linq, async"
        case .cpp:
            langTopics = "cpp, stl, pointers, memory"
        case .rust:
            langTopics = "rust, ownership, traits, async"
        case .kotlin:
            langTopics = "kotlin, coroutines, spring, android"
        case .swift:
            langTopics = "swift, swiftui, uikit, combine"
        }

        // Add QA topics if role is QA-related
        if role.rawValue.contains("qa") || role == .sdet {
            return "\(qaTopics), \(langTopics), \(common)"
        }

        return "\(langTopics), \(common)"
    }

    /// Combined classify + answer in ONE streaming call with PROMPT CACHING
    /// Uses multi-turn message format for better context handling
    /// Returns classification immediately, then streams answer if status is "question"
    func classifyAndStreamAnswer(
        transcription: String,
        buffer: String,
        lastTopic: String?,
        userBackground: String?,
        multiTurnMessages: [[String: String]],  // Pre-built multi-turn history
        onClassification: @escaping (UtteranceClassification) -> Void,
        onAnswerChunk: @escaping (String) -> Void
    ) async -> Result<Void, Error> {
        let combinedText = buffer.isEmpty ? transcription : "\(buffer) \(transcription)"

        // Build the final user message with classification context
        var userParts: [String] = []
        userParts.append("UTTERANCE: \"\(combinedText)\"")
        userParts.append("TOPICS: \(Self.getTopicsForSettings())")
        if let topic = lastTopic { userParts.append("Last topic: \(topic)") }

        if let bg = userBackground, !bg.isEmpty {
            userParts.append("YOUR BACKGROUND: \(bg)")
        }

        let languageInstruction = AppSettings.shared.llmLanguageInstruction
        if !languageInstruction.isEmpty {
            userParts.append(languageInstruction)
        }

        let currentUserMessage = userParts.joined(separator: "\n\n")

        // Build request with PROMPT CACHING - system message is cached
        let systemContent: [[String: Any]] = [
            [
                "type": "text",
                "text": Self.classificationSystemPrompt,
                "cache_control": ["type": "ephemeral"]
            ]
        ]

        // Build messages array: multi-turn history + current utterance
        var messages: [[String: Any]] = multiTurnMessages.map { $0 as [String: Any] }

        // Replace or append the final user message with classification context
        if messages.isEmpty || messages.last?["role"] as? String != "user" {
            messages.append(["role": "user", "content": currentUserMessage])
        } else {
            // Merge with existing last user message if it's contextual
            messages[messages.count - 1] = ["role": "user", "content": currentUserMessage]
        }

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 600,  // Increased for enumeration questions
            "stream": true,
            "system": systemContent,
            "messages": messages
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
            var answerContentStarted = false  // Track if we've sent any actual content

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
                                let classification = parseClassification(firstLine, originalText: combinedText)
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
                                    answerContentStarted = true
                                    onAnswerChunk(afterSeparator)
                                }
                            }
                        } else if answerStarted {
                            // Trim leading whitespace until we have actual content
                            if !answerContentStarted {
                                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    answerContentStarted = true
                                    onAnswerChunk(trimmed)
                                }
                            } else {
                                onAnswerChunk(text)
                            }
                        }
                    }
                }
            }

            // Handle case where classification wasn't parsed (fallback)
            if !classificationSent {
                let classification = parseClassification(fullText, originalText: combinedText)
                onClassification(classification)
            }

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Parse STATUS:xxx|TOPIC:yyy|NORMALIZED:zzz format
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

    /// Send a message with images and stream the response
    /// - Parameters:
    ///   - images: Base64-encoded images
    ///   - prompt: User prompt
    ///   - prefill: Optional assistant prefill to start the response (forces format)
    ///   - onChunk: Callback for each chunk
    func sendMessageStream(
        images: [String],
        prompt: String,
        prefill: String? = nil,
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

        // Build messages array
        var messages: [[String: Any]] = [
            [
                "role": "user",
                "content": contentBlocks
            ]
        ]

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

    // MARK: - Conversation Summarization

    /// Summarize older conversation history to compress context
    /// - Parameter conversationText: Pre-formatted conversation (e.g., "Q: ...\nA: ...")
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
