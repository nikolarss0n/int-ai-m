import Foundation

/// Groq API client for interview assistance (Whisper STT + LLM)
class GroqInterviewClient {
    private let apiKey: String
    private let whisperURL = AppConstants.APIURLs.groqTranscriptions
    private let chatURL = AppConstants.APIURLs.groqChat

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.httpMaximumConnectionsPerHost = 2
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

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

    func transcribe(audioData: Data, filename: String = "audio.m4a") async throws -> (text: String, latencyMs: Double) {
        let startTime = Date()
        let maxAttempts = 3
        let backoffIntervals: [Double] = [0.5, 1.0, 1.5]

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: whisperURL)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(AppConstants.Models.groqWhisper)\r\n".data(using: .utf8)!)

        let languageCode = AppSettings.shared.languageCode
        debugLog(.transcription, "Groq STT language=\(languageCode), responseLanguage=\(AppSettings.shared.responseLanguage.displayName)")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(languageCode)\r\n".data(using: .utf8)!)

        let vocabulary = cappedWhisperPrompt(AppSettings.shared.whisperVocabulary)
        debugLog(.transcription, "Groq STT prompt length=\(vocabulary.count) chars, \(vocabulary.utf8.count) bytes")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(vocabulary)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                debugLog(.transcription, "Groq STT attempt \(attempt + 1)/\(maxAttempts), model=\(AppConstants.Models.groqWhisper), audio=\(audioData.count) bytes")
                let (data, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    debugLog(.transcription, "Groq STT HTTP \(httpResponse.statusCode), response=\(data.count) bytes")
                    if !(200..<300).contains(httpResponse.statusCode) {
                        let body = String(data: data, encoding: .utf8) ?? ""
                        let message = body.isEmpty ? "HTTP \(httpResponse.statusCode)" : "HTTP \(httpResponse.statusCode): \(body.prefix(300))"
                        throw NSError(domain: "GroqClient", code: httpResponse.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: message])
                    }
                }

                let latency = Date().timeIntervalSince(startTime) * 1000

                struct Response: Codable { let text: String }
                do {
                    let result = try JSONDecoder().decode(Response.self, from: data)
                    debugLog(.transcription, "Groq STT decoded \(result.text.count) chars")
                    return (result.text, latency)
                } catch {
                    let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                    debugLog(.error, "Groq STT decode failed: \(error). Body prefix: \(body.prefix(300))")
                    throw error
                }
            } catch {
                let nsError = error as NSError
                if (400..<500).contains(nsError.code) && nsError.domain == "GroqClient" {
                    debugLog(.error, "Groq STT non-retryable failure: \(error.localizedDescription)")
                    throw error
                }

                lastError = error
                if attempt < maxAttempts - 1 {
                    debugLog(.error, "Groq STT attempt \(attempt + 1) failed: \(error.localizedDescription). Retrying...")
                    try await Task.sleep(nanoseconds: UInt64(backoffIntervals[attempt] * 1_000_000_000))
                }
            }
        }

        if let lastError = lastError {
            debugLog(.error, "Groq STT failed after \(maxAttempts) attempts: \(lastError.localizedDescription)")
        }
        throw lastError ?? NSError(
            domain: "GroqClient",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Transcription failed after retries"]
        )
    }

    private func cappedWhisperPrompt(_ prompt: String) -> String {
        let limit = AppConstants.Limits.groqWhisperPromptBytes
        guard prompt.utf8.count > limit else { return prompt }

        var capped = ""
        var byteCount = 0

        for character in prompt {
            let byteLength = String(character).utf8.count
            guard byteCount + byteLength <= limit else { break }
            capped.append(character)
            byteCount += byteLength
        }

        if let lastComma = capped.lastIndex(of: ",") {
            let trimmed = String(capped[..<lastComma]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return capped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generate a concise interview answer for a topic
    func generateAnswer(for topic: String, transcription: String, userBackground: String? = nil) async throws -> (answer: String, latencyMs: Double) {
        let startTime = Date()
        let maxAttempts = 3
        let backoffIntervals: [Double] = [0.5, 1.0, 1.5]

        let prompt = answerPrompt(topic: topic, transcription: transcription, userBackground: userBackground)

        var request = URLRequest(url: URL(string: chatURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = groqChatRequestBody(
            messages: [["role": "user", "content": prompt]],
            maxTokens: AppConstants.MaxTokens.groqAnswer,
            temperature: 0.3,
            model: AppConstants.Models.groqFastAnswer
        )

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   (400..<500).contains(httpResponse.statusCode) {
                    throw NSError(domain: "GroqClient", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                }

                let latency = Date().timeIntervalSince(startTime) * 1000

                struct ChatResponse: Codable {
                    struct Choice: Codable {
                        struct Message: Codable { let content: String }
                        let message: Message
                    }
                    struct ErrorDetail: Codable { let message: String }
                    let choices: [Choice]?
                    let error: ErrorDetail?
                }

                let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)

                if let error = decoded.error {
                    print("⚠️ Groq API error: \(error.message)")
                    return ("API error: \(error.message)", latency)
                }

                let answer = decoded.choices?.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No answer generated"
                return (answer, latency)
            } catch {
                let nsError = error as NSError
                if (400..<500).contains(nsError.code) && nsError.domain == "GroqClient" {
                    throw error
                }

                lastError = error
                if attempt < maxAttempts - 1 {
                    try await Task.sleep(nanoseconds: UInt64(backoffIntervals[attempt] * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NSError(
            domain: "GroqClient",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Answer generation failed after retries"]
        )
    }

    /// Shared cue-card answer prompt used by both buffered and streaming answers.
    /// When `context` is provided (vague follow-ups), the recent conversation is added
    /// so the answer extends the topic with new angles instead of repeating it.
    private func answerPrompt(topic: String, transcription: String, userBackground: String?, context: String? = nil) -> String {
        let backgroundContext = userBackground != nil && !userBackground!.isEmpty ? """

        === USER'S BACKGROUND ===
        \(userBackground!)
        === END BACKGROUND ===

        For personal questions (Tell me about yourself, experience, projects), use ONLY the background above.

        """ : ""

        let followUpContext: String
        if let context = context,
           !context.isEmpty,
           context != "No previous conversation." {
            followUpContext = """

            === CONVERSATION SO FAR ===
            \(context)
            === END CONVERSATION ===

            This is a follow-up on the same topic. Add new, deeper points or a concrete example; do NOT repeat what was already covered.

            """
        } else {
            followUpContext = ""
        }

        let languageInstruction = AppSettings.shared.llmLanguageInstruction
        return """
        Technical Interview Coach. Give a concise answer the candidate can say naturally.
        \(backgroundContext)\(followUpContext)
        \(AppSettings.shared.interviewContext)

        \(AppSettings.shared.answerStyleInstruction)

        Q: "\(transcription)"
        Topic: \(topic)

        FORMAT:
        3-5 cue-card bullets only. Every line starts with "- ".
        No paragraphs. Keep each bullet short enough to read while speaking.

        \(languageInstruction)
        """
    }

    /// Stream a concise interview answer for a topic (fast quality path).
    /// Uses Groq's OpenAI-compatible SSE so the first useful text reaches the
    /// card without waiting on the slower authoritative classification.
    /// Returns failure (and may have emitted nothing) so the caller can fall back.
    func streamAnswer(
        topic: String,
        transcription: String,
        userBackground: String? = nil,
        context: String? = nil,
        onChunk: @escaping (String) -> Void
    ) async -> Result<Void, Error> {
        let prompt = answerPrompt(topic: topic, transcription: transcription, userBackground: userBackground, context: context)

        var request = URLRequest(url: URL(string: chatURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body = groqChatRequestBody(
            messages: [["role": "user", "content": prompt]],
            maxTokens: AppConstants.MaxTokens.groqAnswer,
            temperature: 0.3,
            model: AppConstants.Models.groqFastAnswer
        )
        body["stream"] = true

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return .failure(error)
        }

        for attempt in 0..<2 {
            do {
                let (bytes, response) = try await session.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    return .failure(NSError(domain: "GroqClient", code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    if (400..<500).contains(httpResponse.statusCode) {
                        return .failure(NSError(domain: "GroqClient", code: httpResponse.statusCode,
                                                userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
                    }
                    if attempt == 0 {
                        try await Task.sleep(nanoseconds: 500_000_000)
                        continue
                    }
                    return .failure(NSError(domain: "GroqClient", code: httpResponse.statusCode,
                                            userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
                }

                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let jsonString = String(line.dropFirst(6))
                    if jsonString == "[DONE]" { break }

                    if let data = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any],
                       let content = delta["content"] as? String,
                       !content.isEmpty {
                        onChunk(content)
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

        return .failure(NSError(domain: "GroqClient", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Answer stream failed after retry"]))
    }

    /// Classification result for an utterance
    struct UtteranceClassification {
        let status: String   // "question", "incomplete", "answer", "filler"
        let topic: String?   // topic name or nil
    }

    /// Combined classification: status + topic in ONE call
    /// Replaces both checkCompleteness() and detectTopic()
    func classifyUtterance(_ text: String, buffer: String, lastTopic: String?) async throws -> (classification: UtteranceClassification, latencyMs: Double) {
        let startTime = Date()
        let maxAttempts = 3
        let backoffIntervals: [Double] = [0.5, 1.0, 1.5]

        let combinedText = buffer.isEmpty ? text : "\(buffer) \(text)"
        let lastTopicNote = lastTopic != nil ? "Last topic: \(lastTopic!)" : ""

        let prompt = """
        Classify this utterance. Return: STATUS,TOPIC

        Text: "\(combinedText)"
        \(lastTopicNote)

        IMPORTANT: This is speech-to-text from a technical interview. Words may be misheard.
        Use context to interpret what makes sense technically (e.g., "Ray vs ArrayList" → Array vs ArrayList).

        STATUS (pick one):
        - question = asking about something OR mentioning a topic (wants info)
        - incomplete = cut off mid-sentence ("What is the", "Can you")
        - answer = user responding/explaining (any length). Includes: "Yes, sure", "Thank you", "Okay, I understand", any explanation
        - filler = ONLY single meaningless sounds: "um", "uh", "hmm", "ah". NOT "okay", "yes", "thank you"

        Short topic mentions like "polymorphism", "singleton pattern" = question

        TOPICS:
        array, arrayList, linkedList, hashMap, hashSet, treeMap, queue, collections
        threads, process, synchronized, volatile, deadlock, locks
        jvm, jdk, jre, garbageCollection, heap, stack
        oop, inheritance, polymorphism, encapsulation, abstraction, abstractClass, interface
        lambda, streamApi, optional, functionalInterface
        exceptions, checkedExceptions, uncheckedExceptions
        closure, hoisting, eventLoop, promises, asyncAwait, this, scope
        reactHooks, useState, useEffect, useContext, virtualDOM, redux
        typescript, generics, interfaces, types
        bigO, sorting, binarySearch, recursion, dynamicProgramming, bfs, dfs
        systemDesign, caching, redis, loadBalancing, database, sql, nosql, microservices, rest
        singleton, factory, builder, observer, strategy, dependencyInjection, solid
        testing, unitTest, tdd, mocking, testAutomation, selenium, playwright, playwrightTest, playwrightLocators, webFirstAssertions, autoWaiting, storageState, browserContext, playwrightFixtures, pageRoute, networkMocking, traceViewer, playwrightProjects, workers, sharding, retries, cypress, apiTesting, contractTesting, e2eTesting, fixtures, testData, pageObjects, locators, visualRegression, accessibilityTesting, testStrategy, flakyTests
        docker, kubernetes, ci, cd, git, aws
        linux, bash, ssh, networking
        background, experience, tellMeAboutYourself, projects
        followUp (for "tell me more" with no new topic)
        unknown (if no match)

        EXAMPLES:
        "What is ray list?" → question,arrayList (ray list = ArrayList)
        "difference between a ray and ray list" → question,array (comparing Array vs ArrayList)
        "What is key developer?" → question,hashMap (nonsense phrase + last topic = asking about hashMap key)
        "What is the" → incomplete,none
        "Tell me more" → question,followUp

        NOTE: If phrase makes no sense (like "key developer"), use lastTopic - it's likely a misheard word.

        Return ONLY: STATUS,TOPIC (e.g., "question,array")
        """

        var request = URLRequest(url: URL(string: chatURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = groqChatRequestBody(
            messages: [["role": "user", "content": prompt]],
            maxTokens: AppConstants.MaxTokens.groqClassification,
            temperature: 0,
            model: AppConstants.Models.groqFastClassification
        )

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   (400..<500).contains(httpResponse.statusCode) {
                    throw NSError(domain: "GroqClient", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                }

                let latency = Date().timeIntervalSince(startTime) * 1000

                struct ChatResponse: Codable {
                    struct Choice: Codable {
                        struct Message: Codable { let content: String }
                        let message: Message
                    }
                    let choices: [Choice]
                }

                let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
                let raw = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "question,unknown"

                let cleaned = raw.replacingOccurrences(of: ":", with: ",").replacingOccurrences(of: " ", with: "")
                let parts = cleaned.split(separator: ",").map { String($0) }
                let status = parts.first ?? "question"
                let topicRaw = parts.count > 1 ? parts[1] : "unknown"
                var topic: String? = (topicRaw == "none" || topicRaw.isEmpty) ? nil : topicRaw
                if status == "question",
                   (topic == nil || topic?.lowercased() == "unknown"),
                   isVagueFollowUpPrompt(combinedText) {
                    topic = "followUp"
                }

                return (UtteranceClassification(status: status, topic: topic), latency)
            } catch {
                let nsError = error as NSError
                if (400..<500).contains(nsError.code) && nsError.domain == "GroqClient" {
                    throw error
                }

                lastError = error
                if attempt < maxAttempts - 1 {
                    try await Task.sleep(nanoseconds: UInt64(backoffIntervals[attempt] * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NSError(
            domain: "GroqClient",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Classification failed after retries"]
        )
    }

    /// Generate follow-up answer for current topic
    func generateFollowUpAnswer(for topic: String, transcription: String, context: String, userBackground: String? = nil) async throws -> (answer: String, latencyMs: Double) {
        let startTime = Date()
        let maxAttempts = 3
        let backoffIntervals: [Double] = [0.5, 1.0, 1.5]

        let backgroundContext = userBackground != nil && !userBackground!.isEmpty ? """

        === USER'S BACKGROUND ===
        \(userBackground!)
        === END BACKGROUND ===

        """ : ""

        let languageInstruction = AppSettings.shared.llmLanguageInstruction
        let prompt = """
        Follow-up on: \(topic)
        Request: "\(transcription)"
        \(backgroundContext)
        \(AppSettings.shared.interviewContext)

        \(AppSettings.shared.answerStyleInstruction)

        Context: \(context)

        Add 1-2 short bullets not covered. No intro. Every line starts with "- ".
        \(languageInstruction)
        """

        var request = URLRequest(url: URL(string: chatURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = groqChatRequestBody(
            messages: [["role": "user", "content": prompt]],
            maxTokens: AppConstants.MaxTokens.followUp,
            temperature: 0.3,
            model: AppConstants.Models.groqFastAnswer
        )

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   (400..<500).contains(httpResponse.statusCode) {
                    throw NSError(domain: "GroqClient", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                }

                let latency = Date().timeIntervalSince(startTime) * 1000

                struct ChatResponse: Codable {
                    struct Choice: Codable {
                        struct Message: Codable { let content: String }
                        let message: Message
                    }
                    struct APIError: Codable { let message: String }
                    let choices: [Choice]?
                    let error: APIError?
                }

                let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)

                if let error = decoded.error {
                    print("⚠️ Groq API error: \(error.message)")
                    return ("API error: \(error.message)", latency)
                }

                let answer = decoded.choices?.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No answer generated"
                return (answer, latency)
            } catch {
                let nsError = error as NSError
                if (400..<500).contains(nsError.code) && nsError.domain == "GroqClient" {
                    throw error
                }

                lastError = error
                if attempt < maxAttempts - 1 {
                    try await Task.sleep(nanoseconds: UInt64(backoffIntervals[attempt] * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NSError(
            domain: "GroqClient",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Follow-up answer failed after retries"]
        )
    }

    private func isVagueFollowUpPrompt(_ text: String) -> Bool {
        let cleaned = text.lowercased()
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

    private func groqChatRequestBody(
        messages: [[String: String]],
        maxTokens: Int,
        temperature: Double,
        model: String
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": temperature
        ]

        if model.hasPrefix("openai/gpt-oss") {
            body["reasoning_effort"] = "low"
            body["reasoning_format"] = "hidden"
        }

        return body
    }
}
