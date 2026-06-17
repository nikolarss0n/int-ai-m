import Foundation

/// Infrastructure: Anthropic API Client
/// Handles communication with Anthropic's Claude API
class AnthropicClient {
    private let apiKey: String
    private let baseURL = AppConstants.APIURLs.anthropicMessages
    private let model = AppConstants.Models.anthropicHaiku
    private let maxTokens = AppConstants.MaxTokens.imageAnalysis

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: config)
    }()

    private var isConnectionWarm = false
    private var currentTask: Task<Void, Error>?

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    deinit {
        currentTask?.cancel()
        session.invalidateAndCancel()
    }

    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }

    private func isClientError(data: Data) -> Bool {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let _ = json["error"] {
            return true
        }
        return false
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

    func sendMessage(prompt: String, maxTokens: Int = 300) async throws -> (text: String, latencyMs: Double) {
        let startTime = Date()
        let maxAttempts = 3
        let backoffIntervals: [Double] = [0.5, 1.0, 1.5]

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

        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   (400..<500).contains(httpResponse.statusCode) {
                    throw NSError(domain: "AnthropicClient", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                }

                let latency = Date().timeIntervalSince(startTime) * 1000

                struct Response: Codable {
                    struct Content: Codable { let text: String }
                    let content: [Content]
                }

                let decoded = try JSONDecoder().decode(Response.self, from: data)
                let text = decoded.content.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return (text, latency)
            } catch {
                let nsError = error as NSError
                if (400..<500).contains(nsError.code) && nsError.domain == "AnthropicClient" {
                    throw error
                }

                lastError = error
                if attempt < maxAttempts - 1 {
                    try await Task.sleep(nanoseconds: UInt64(backoffIntervals[attempt] * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NSError(
            domain: "AnthropicClient",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Request failed after retries"]
        )
    }

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

        for attempt in 0..<2 {
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

                    if (400..<500).contains(httpResponse.statusCode) {
                        return .failure(NSError(domain: errorMessage, code: httpResponse.statusCode))
                    }

                    if attempt == 0 {
                        try await Task.sleep(nanoseconds: 500_000_000)
                        continue
                    }
                    return .failure(NSError(domain: errorMessage, code: httpResponse.statusCode))
                }

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
                if !isNetworkError(error) || attempt == 1 {
                    return .failure(error)
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        return .failure(NSError(domain: "AnthropicClient", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Stream request failed after retry"]))
    }

    /// Classification result for an utterance
    struct UtteranceClassification {
        let status: String   // "question", "incomplete", "statement" (or "answer" for backwards compat), "filler"
        let topic: String?   // topic name or nil
    }

    /// Static system prompt for classification (cached) - OPTIMIZED: topics come from settings
    private static let classificationSystemPrompt = """
You are a live technical interview co-pilot. Classify the interviewer utterance, then give a concise answer the candidate can say naturally.

=== OUTPUT FORMAT ===
Line 1: STATUS:xxx|TOPIC:yyy
Line 2: ---
Line 3+: Answer (only if STATUS is question)

STATUS options:
- question = Interviewer asking a technical question OR requesting action OR expressing curiosity. Includes:
  • Direct questions ("What is hoisting?", "Explain closures", "How does X work?")
  • Implicit requests ("let's talk about", "tell me about", "walk me through")
  • Statements with uncertainty ("I wonder", "I'm not sure about", "right?", "correct?")
  • Requests starting with fillers ("okay so what about", "sure but how does", "thanks, now tell me")
- incomplete = genuinely cut off mid-word/mid-phrase (e.g. "So when you ha-", "The thing about mem")
  Do NOT mark as incomplete just because it ends with a preposition or conjunction - natural speech often does.
- statement = ONLY use for pure confirmations/acknowledgments with NO information request ("Great answer", "I see", "Got it", "Let's move on")
- filler = ONLY for standalone noise words with zero meaning ("um", "hmm", "uh")

CRITICAL: When in doubt, ALWAYS classify as "question". It is far better to answer a non-question than to skip a real question.
"okay, what about the deployment" → question (starts with filler but asks about deployment)
"so tell me about the architecture" → question (starts with conjunction but is a request)
"thank you, now what's next" → question (gratitude + question)

Bulgarian and mixed-language interview speech:
- Treat "какво е", "как работи", "разкажи", "раскажи", "обясни", "а какво е", "в принцип", "в принципе" plus a technical term as question.
- Map "хешмап", "хеш мап", "хеш таблица", "hash map" to TOPIC:hashMap.
- Map "хеш код", "hash code", "hashCode" to TOPIC:hashCode.
- Map "ОП", "ООП", "обектно-ориентирано", "object oriented" to TOPIC:oop.
- Bulgarian/Russian-looking filler around a technical term is still a question unless it is only an acknowledgment.

=== STYLE ===
- Return cue-card bullets only: 3-5 lines, every line starts with "- ".
- Each bullet must be short enough to read while speaking, ideally under 90 characters.
- No paragraphs, headings, markdown labels, preambles, or filler words.
- For experience/profile questions, first bullet must be the headline: "8+ years..." or similar.
- Prefer concrete trade-offs and examples over textbook lists.
- Sound like a real candidate speaking: plain, practical, slightly conversational.
- Use first person when it fits: "I usually...", "I would...", "For me...".
- Do not over-polish, over-explain, or list every possible angle.
- For QA/SDET/test-automation topics, default to Playwright unless the question names another framework. Use locators, web-first assertions, fixtures, storageState, page.route, browser contexts, traces, projects, workers, retries, sharding, API setup, and flaky-test triage where relevant.

=== EXAMPLE ===
Q: "What is polymorphism?"
STATUS:question|TOPIC:oop
---
- Polymorphism means the same interface can behave differently by implementation.
- In tests, I see it when mocks or page objects share contracts but vary behavior.
- I use it when it keeps code flexible, not just to add abstraction.

CODE only if explicitly asked.
"""

    /// Get topics based on current role and programming language settings
    private static func getTopicsForSettings() -> String {
        let settings = AppSettings.shared
        let lang = settings.programmingLanguage
        let common = "oop, hashMap, hashCode, dataStructures, algorithms, collections, arrays, trees, systemDesign, api, aws, patterns, devops, personal, followUp, unknown"

        // QA-specific topics
        let qaTopics = "playwright, playwrightTest, playwrightLocators, webFirstAssertions, autoWaiting, storageState, browserContext, playwrightFixtures, pageRoute, networkMocking, traceViewer, playwrightProjects, workers, sharding, retries, testAutomation, selenium, cypress, apiTesting, contractTesting, e2eTesting, unitTesting, integrationTesting, mocking, fixtures, testData, pageObjects, locators, visualRegression, accessibilityTesting, testStrategy, flakyTests, cicd, llmEvaluation, promptTesting, genAI, chatbotTesting"

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
        if settings.isTestAutomationRole {
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

        // Build simple user message - just the utterance and topic hints
        var userParts: [String] = []
        userParts.append("Q: \"\(combinedText)\"")
        userParts.append("TOPICS: \(Self.getTopicsForSettings())")
        userParts.append(AppSettings.shared.interviewContext)
        userParts.append(AppSettings.shared.answerStyleInstruction)
        if let topic = lastTopic { userParts.append("Last topic: \(topic)") }
        if let userBackground = userBackground, !userBackground.isEmpty {
            userParts.append("""
            CANDIDATE BACKGROUND:
            \(userBackground)
            Use this only when the interviewer asks about experience, projects, strengths, or personal examples.
            """)
        }

        let languageInstruction = AppSettings.shared.llmLanguageInstruction
        if !languageInstruction.isEmpty {
            userParts.append(languageInstruction)
        }

        let currentUserMessage = userParts.joined(separator: "\n")

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
            "max_tokens": AppConstants.MaxTokens.classification,
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

        for attempt in 0..<2 {
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

                    if (400..<500).contains(httpResponse.statusCode) {
                        return .failure(NSError(domain: errorMessage, code: httpResponse.statusCode))
                    }

                    if attempt == 0 {
                        try await Task.sleep(nanoseconds: 500_000_000)
                        continue
                    }
                    return .failure(NSError(domain: errorMessage, code: httpResponse.statusCode))
                }

                var fullText = ""
                var classificationSent = false
                var answerStarted = false
                var answerContentStarted = false

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

                            if !classificationSent && fullText.contains("\n") {
                                let lines = fullText.components(separatedBy: "\n")
                                if let firstLine = lines.first, firstLine.contains("STATUS:") {
                                    let classification = adjustedClassification(parseClassification(firstLine), for: combinedText)
                                    classificationSent = true
                                    onClassification(classification)

                                    if classification.status != "question" {
                                        return .success(())
                                    }
                                }
                            }

                            if classificationSent && !answerStarted && fullText.contains("---") {
                                answerStarted = true
                                if let range = fullText.range(of: "---") {
                                    let afterSeparator = String(fullText[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !afterSeparator.isEmpty {
                                        answerContentStarted = true
                                        onAnswerChunk(afterSeparator)
                                    }
                                }
                            } else if answerStarted {
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

                if !classificationSent {
                    let classification = adjustedClassification(parseClassification(fullText), for: combinedText)
                    onClassification(classification)
                }

                return .success(())
            } catch {
                if !isNetworkError(error) || attempt == 1 {
                    return .failure(error)
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        return .failure(NSError(domain: "AnthropicClient", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Classify stream failed after retry"]))
    }

    /// Parse STATUS:xxx|TOPIC:yyy format
    private func parseClassification(_ text: String) -> UtteranceClassification {
        let cleaned = text.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")

        var status = "question"
        var topic: String? = "unknown"

        // Parse STATUS:xxx
        if let statusRange = cleaned.range(of: "status:") {
            let afterStatus = String(cleaned[statusRange.upperBound...])
            let statusEnd = afterStatus.firstIndex(of: "|") ?? afterStatus.endIndex
            status = String(afterStatus[..<statusEnd])
        }

        // Parse TOPIC:yyy
        if let topicRange = cleaned.range(of: "topic:") {
            let afterTopic = String(cleaned[topicRange.upperBound...])
            let topicEnd = afterTopic.firstIndex(of: "|") ?? afterTopic.firstIndex(of: "-") ?? afterTopic.endIndex
            let topicValue = String(afterTopic[..<topicEnd])
            topic = (topicValue == "none" || topicValue.isEmpty) ? nil : topicValue
        }

        return UtteranceClassification(status: status, topic: topic)
    }

    private func adjustedClassification(_ classification: UtteranceClassification, for text: String) -> UtteranceClassification {
        let topic = correctedTopic(for: text, classifiedTopic: classification.topic)
        if classification.status != "question" && hasTechnicalQuestionMarker(text) {
            return UtteranceClassification(status: "question", topic: topic)
        }

        return UtteranceClassification(status: classification.status, topic: topic)
    }

    private func correctedTopic(for text: String, classifiedTopic: String?) -> String? {
        let normalized = text.lowercased()

        if normalized.contains("хешмап") ||
            normalized.contains("хеш мап") ||
            normalized.contains("хеш таблиц") ||
            normalized.contains("hash map") ||
            normalized.contains("hashmap") ||
            normalized.contains("hash table") {
            return "hashMap"
        }

        if normalized.contains("хеш код") ||
            normalized.contains("hash code") ||
            normalized.contains("hashcode") {
            return "hashCode"
        }

        if normalized.contains("ооп") ||
            normalized.contains("обектно") ||
            normalized.contains("object oriented") ||
            normalized.contains("object-oriented") ||
            normalized.contains(" полиморф") ||
            normalized.contains(" наследяване") ||
            normalized.contains(" капсулация") ||
            normalized.hasPrefix("оп,") ||
            normalized.hasPrefix("оп ") ||
            normalized.contains(" оп,") ||
            normalized.contains(" оп ") {
            return "oop"
        }

        if isVagueFollowUpPrompt(normalized),
           classifiedTopic == nil || classifiedTopic?.lowercased() == "unknown" {
            return "followUp"
        }

        return classifiedTopic
    }

    private func isVagueFollowUpPrompt(_ normalized: String) -> Bool {
        let cleaned = normalized
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,!?:;"))

        let topicMarkers = [
            "hash", "array", "list", "oop", "solid", "playwright", "selenium",
            "cypress", "test", "api", "contract", "fixture", "locator", "mock",
            "flaky", "trace", "worker", "sharding", "retry", "retries",
            "thread", "deadlock", "jvm", "jdk", "garbage", "closure",
            "event loop", "docker", "kubernetes", "linux", "sql", "database",
            "хеш", "ооп", "полиморф", "наследяване", "капсулация"
        ]
        guard !topicMarkers.contains(where: { cleaned.contains($0) }) else { return false }

        let exactFollowUps: Set<String> = [
            "tell me more", "can you elaborate", "could you elaborate", "elaborate",
            "what else", "anything else", "go deeper", "more details",
            "can you expand", "expand on that", "continue"
        ]
        if exactFollowUps.contains(cleaned) {
            return true
        }

        return cleaned.contains("give me an example") ||
            cleaned.contains("more about that") ||
            cleaned.contains("expand on this")
    }

    private func hasTechnicalQuestionMarker(_ text: String) -> Bool {
        let normalized = text.lowercased()
        let markers = [
            "?", "what is", "what are", "what's", "how do", "how does", "why is",
            "tell me", "explain", "describe", "walk me through", "what about", "how about",
            "difference between", " vs ", " versus ", "compare", "edge cases", "corner cases",
            "complexity", "time complexity", "space complexity", "tradeoff", "trade-off",
            "what else", "elaborate", "go deeper", "give me an example",
            "какво", "как ", "защо", "разкажи", "раскажи", "обясни", "опиши",
            "хеш", "хешмап", "хеш мап", "хеш таблица", "хеш код",
            "hash map", "hashmap", "hash table", "hash code", "hashcode",
            "ооп", "оп,", "оп ", "обектно", "object oriented", "object-oriented",
            "полиморф", "наследяване", "капсулация",
            "playwright", "locator", "fixture", "mocking", "flaky", "trace",
            "storage state", "browser context", "page route", "workers", "sharding",
            "retry", "retries", "api testing", "contract testing", "ci pipeline"
        ]

        return markers.contains { normalized.contains($0) }
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

        for attempt in 0..<2 {
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

                    if (400..<500).contains(httpResponse.statusCode) {
                        return .failure(NSError(domain: errorMessage, code: httpResponse.statusCode))
                    }

                    if attempt == 0 {
                        try await Task.sleep(nanoseconds: 500_000_000)
                        continue
                    }
                    return .failure(NSError(domain: errorMessage, code: httpResponse.statusCode))
                }

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
                if !isNetworkError(error) || attempt == 1 {
                    return .failure(error)
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        return .failure(NSError(domain: "AnthropicClient", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Image stream failed after retry"]))
    }

    // MARK: - Session Analysis

    struct SessionAnalysisResult {
        let topics: [String]
        let strengths: [String]
        let weaknesses: [String]
        let insights: [String]
    }

    func analyzeSession(transcript: String) async throws -> SessionAnalysisResult {
        let prompt = """
        Analyze this interview session transcript. Return EXACTLY this format (one item per line within each section):

        TOPICS:
        <topic1>
        <topic2>

        STRENGTHS:
        <strength1>

        WEAKNESSES:
        <weakness1>

        INSIGHTS:
        <insight1>
        <insight2>

        Use short topic slugs (e.g., oop, systemDesign, algorithms). Strengths/weaknesses should be brief phrases. Insights should be 1 sentence each (max 3).

        Transcript:
        \(transcript)
        """

        let (text, _) = try await sendMessage(prompt: prompt, maxTokens: AppConstants.MaxTokens.sessionAnalysis)
        return parseAnalysisResponse(text)
    }

    private func parseAnalysisResponse(_ text: String) -> SessionAnalysisResult {
        var topics: [String] = []
        var strengths: [String] = []
        var weaknesses: [String] = []
        var insights: [String] = []

        var currentSection: String?

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let upper = trimmed.uppercased()
            if upper.hasPrefix("TOPICS") { currentSection = "topics"; continue }
            if upper.hasPrefix("STRENGTHS") { currentSection = "strengths"; continue }
            if upper.hasPrefix("WEAKNESSES") { currentSection = "weaknesses"; continue }
            if upper.hasPrefix("INSIGHTS") { currentSection = "insights"; continue }

            let clean = trimmed.hasPrefix("- ") ? String(trimmed.dropFirst(2)) : trimmed

            switch currentSection {
            case "topics": topics.append(clean)
            case "strengths": strengths.append(clean)
            case "weaknesses": weaknesses.append(clean)
            case "insights": insights.append(clean)
            default: break
            }
        }

        return SessionAnalysisResult(
            topics: topics,
            strengths: strengths,
            weaknesses: weaknesses,
            insights: insights
        )
    }

    // MARK: - Conversation Summarization

    /// Summarize older conversation history to compress context
    /// - Parameter conversationText: Pre-formatted conversation (e.g., "Q: ...\nA: ...")
    func summarizeConversation(conversationText: String) async throws -> String {
        guard !conversationText.isEmpty else { return "" }

        let maxAttempts = 3
        let backoffIntervals: [Double] = [0.5, 1.0, 1.5]

        let prompt = """
        Summarize this interview conversation in 2-3 concise sentences.
        Focus on: main topics discussed, key technical concepts, and any important context for follow-up questions.

        Conversation:
        \(conversationText)

        Summary:
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": AppConstants.MaxTokens.summarization,
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

        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   (400..<500).contains(httpResponse.statusCode) {
                    throw NSError(domain: "AnthropicClient", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                }

                struct Response: Codable {
                    struct Content: Codable { let text: String }
                    let content: [Content]
                }

                let decoded = try JSONDecoder().decode(Response.self, from: data)
                let summary = decoded.content.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                print("📋 Generated summary: \(summary.prefix(100))...")
                return summary
            } catch {
                let nsError = error as NSError
                if (400..<500).contains(nsError.code) && nsError.domain == "AnthropicClient" {
                    throw error
                }

                lastError = error
                if attempt < maxAttempts - 1 {
                    try await Task.sleep(nanoseconds: UInt64(backoffIntervals[attempt] * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NSError(
            domain: "AnthropicClient",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Summarization failed after retries"]
        )
    }
}
