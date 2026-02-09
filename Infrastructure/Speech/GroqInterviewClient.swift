import Foundation

/// Groq API client for interview assistance (Whisper STT + LLM)
class GroqInterviewClient {
    private let apiKey: String
    private let whisperURL = AppConstants.APIURLs.groqTranscriptions
    private let chatURL = AppConstants.APIURLs.groqChat

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpMaximumConnectionsPerHost = 2
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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(AppConstants.Models.groqWhisper)\r\n".data(using: .utf8)!)

        let languageCode = AppSettings.shared.languageCode
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(languageCode)\r\n".data(using: .utf8)!)

        let vocabulary = AppSettings.shared.whisperVocabulary
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
                let (data, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   (400..<500).contains(httpResponse.statusCode) {
                    throw NSError(domain: "GroqClient", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                }

                let latency = Date().timeIntervalSince(startTime) * 1000

                struct Response: Codable { let text: String }
                let result = try JSONDecoder().decode(Response.self, from: data)

                return (result.text, latency)
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

        throw lastError!
    }

    /// Generate a concise interview answer for a topic
    func generateAnswer(for topic: String, transcription: String, userBackground: String? = nil) async throws -> (answer: String, latencyMs: Double) {
        let startTime = Date()
        let maxAttempts = 3
        let backoffIntervals: [Double] = [0.5, 1.0, 1.5]

        let backgroundContext = userBackground != nil && !userBackground!.isEmpty ? """

        === USER'S BACKGROUND ===
        \(userBackground!)
        === END BACKGROUND ===

        For personal questions (Tell me about yourself, experience, projects), use ONLY the background above.

        """ : ""

        let languageInstruction = AppSettings.shared.llmLanguageInstruction
        let prompt = """
        Technical Interview Coach. Speakable flashcard format.
        \(backgroundContext)
        Q: "\(transcription)"
        Topic: \(topic)

        FORMAT:
        **Definition**: one line
        **Key points**: 2-3 bullets
        **Gotcha**: one pitfall (separate bullet)
        **Senior tip**: one insight (separate bullet)

        One idea per bullet. Phrases, not sentences.
        \(languageInstruction)
        """

        var request = URLRequest(url: URL(string: chatURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": AppConstants.Models.groqLlama,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": AppConstants.MaxTokens.groqAnswer,
            "temperature": 0.3
        ]

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

        throw lastError!
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
        testing, unitTest, tdd, mocking
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

        let body: [String: Any] = [
            "model": AppConstants.Models.groqLlama,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": AppConstants.MaxTokens.groqClassification,
            "temperature": 0
        ]

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
                let topic: String? = (topicRaw == "none" || topicRaw.isEmpty) ? nil : topicRaw

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

        throw lastError!
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
        Context: \(context)

        Add 1-2 NEW points not covered:
        **Gotcha**: one pitfall
        **Senior tip**: one optimization or trade-off

        One idea per bullet. No intro.\(languageInstruction)
        """

        var request = URLRequest(url: URL(string: chatURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": AppConstants.Models.groqLlama,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": AppConstants.MaxTokens.followUp,
            "temperature": 0.3
        ]

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

        throw lastError!
    }
}
