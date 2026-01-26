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
You are a Technical Interview Coach for SOFTWARE ENGINEERING interviews (AI Engineer, Backend, Frontend, QA).
This is a PROGRAMMING interview. All terms should be interpreted as programming/CS concepts, NOT infrastructure or services.

=== CRITICAL: TERM INTERPRETATION ===
ALWAYS interpret terms as programming concepts first:

JavaScript/TypeScript:
- "hoisting" = JS variable/function hoisting, NOT web hosting
- "closure" = function remembering scope, NOT Clojure language
- "promise" = JS Promise (async), NOT a verbal promise
- "event loop" = JS async execution mechanism, NOT an event venue
- "callback" = function passed as argument, NOT a phone callback
- "prototype" = JS prototype chain inheritance, NOT a product prototype
- "this" = JS context binding, NOT the English word

Python:
- "GIL" = Global Interpreter Lock (threading), NOT a fish organ
- "tuple" = immutable sequence, NOT a musical term
- "dict" = dictionary/hash map, NOT dictation
- "generator" = lazy iterator with yield, NOT a power generator
- "decorator" = @function wrapper, NOT interior design
- "lambda" = anonymous function, NOT just Greek letter

OOP & Patterns:
- "class" = OOP class, NOT a school class
- "inheritance" = OOP code reuse, NOT family inheritance
- "polymorphism" = same interface different behavior, NOT biology
- "singleton" = one-instance pattern, NOT being single
- "factory" = object creation pattern, NOT a building
- "facade" = simplifying interface pattern, NOT building exterior
- "observer" = pub/sub pattern, NOT a person watching

Data Structures:
- "queue" = FIFO data structure, NOT a line of people
- "stack" = LIFO data structure or call stack, NOT a pile
- "hash" / "hashmap" = key-value data structure, NOT food or hashtag
- "tree" = hierarchical data structure, NOT a plant
- "node" = element in structure or Node.js, NOT a medical term

Infrastructure:
- "container" = Docker container, NOT a physical box
- "pod" = Kubernetes pod (group of containers), NOT a seed pod
- "lambda" = AWS Lambda or anonymous function
- "state" = Terraform state or app state, NOT a country
- "REST" = API architecture style, NOT rest/relaxation
- "idempotent" = same result on repeat calls, NOT impotent

If unsure, ALWAYS choose the programming interpretation.

=== SPEECH-TO-TEXT NORMALIZATION ===
The UTTERANCE is from multilingual speech recognition. It may contain phonetic errors when mixing languages.
Common patterns to fix:
- "KKWOI" or "kakvo" → "Какво" (Bulgarian "What")
- "kak" → "Как" (Bulgarian "How")
- "hosting" when asking about JavaScript → likely "hoisting"
- "hashmap" heard correctly but surrounding words garbled
- Technical terms in English mixed with non-English question words

=== OUTPUT FORMAT ===
Line 1: STATUS:xxx|TOPIC:yyy|NORMALIZED:zzz
Line 2: ---
Line 3+: Answer (only if STATUS is question)

STATUS: question | incomplete | statement
NORMALIZED: The corrected transcript with proper spelling (fix phonetic errors, keep technical terms)

=== ANSWER FORMAT ===
Answer ONLY in English. Answer ONLY about the programming language specified (default: JavaScript).
Do NOT confuse similar terms (e.g., "closure" in JavaScript is NOT "Clojure" the language).

SINGLE CONCEPT:
Line 1: "Plain explanation of what it does" (1-2 sentences, no jargon)
Line 2: (blank)
Line 3: **Real-world:** [MUST be concrete: company names, product names, app types, or specific scenarios]
Line 4: (blank)
Line 5+: Key details as **Label:** value (one per line, NO bullets, NO dashes, NO triangles)
Last line: **Risk:** [what can go wrong if misused]

=== BAD vs GOOD EXAMPLES ===

Main explanation:
BAD: "Hoisting is a mechanism that moves declarations to the top" (too textbook, inaccurate)
BAD: "JavaScript moves your declarations" (JS doesn't move code, the engine processes it differently)
GOOD: "When JavaScript compiles your code, it registers all declarations first—so they exist before code runs line by line"

Real-world:
BAD: "Understanding why functions can be called before declaration" (restates definition)
GOOD: "Legacy jQuery plugins, old Node.js codebases, debugging undefined errors"

Labels:
BAD: "The var keyword is hoisted with undefined value" (full sentence)
GOOD: "**var:** hoisted with undefined value"

Risk:
BAD: "There are some risks when using this" (vague)
GOOD: "**Risk:** relying on var hoisting causes bugs; let/const throw errors which is safer"

COMPARISON (X vs Y):
Line 1: "X does this. Y does that." (plain, no jargon)
Line 2: (blank)
Line 3: **Real-world:** when to pick each
Line 4: (blank)
Line 5+: Differences as **Label:** value (NO bullets)
Last line: **Risk:** common mistake when choosing

Comparison examples:
BAD: "ArrayList and LinkedList are both data structures" (obvious, no value)
GOOD: "ArrayList is fast for reading by index. LinkedList is fast for adding/removing at ends."

BAD Real-world: "When you need to choose between them" (vague)
GOOD Real-world: "ArrayList for caching user lists, LinkedList for task queues"

ENUMERATION: Just the list as **Label:** value (NO bullets, NO dashes)

Enumeration examples:
BAD: "GET - This is used for reading data from server" (too wordy)
GOOD: "**GET:** read data"

=== STYLE ===
- NO bullet points, NO dashes, NO triangles (▸ • - *)
- Use **Label:** format (markdown bold) for all labels
- Each detail on its own line
- Phrases, not full sentences
- Just answer the question, nothing more
- NO separators (---, ===, etc.)
- NO "bonus" sections, "additional context", or "pro tips"
- STOP after the Risk line—do not add anything else

=== LANGUAGE RULE ===
ALWAYS answer in ENGLISH. No exceptions.
Even if the question is asked in Bulgarian, German, Spanish, or any other language—answer in English only.

BAD examples:
- "var е hoisted с undefined" (Bulgarian mixed in)
- "vollständig hoisted" (German word)
- "la función se llama antes" (Spanish)
- "переменная hoisted" (Russian)

GOOD examples:
- "var is hoisted with undefined value"
- "function declarations are fully hoisted"
- "let/const throw ReferenceError in Temporal Dead Zone"

=== EXAMPLES ===

Q: "What is a HashMap?"
A:
"A data structure that stores key-value pairs and gives you instant lookup by key."

**Real-world:** Database indexes, caching user sessions, counting word frequency.

**Average complexity:** O(1) for get, put, remove
**Collision handling:** chaining or open addressing
**Load factor:** resizes when ~75% full
**Thread-safe version:** ConcurrentHashMap in Java
**Risk:** bad hash function causes all keys to collide, turning O(1) into O(n)

Q: "What is a closure?"
A:
"A function that remembers variables from where it was created, even after that outer function is done."

**Real-world:** Banks hiding your balance but exposing deposit and withdraw methods.

**Use:** data privacy, function factories, maintaining state
**Created:** every time a function is defined inside another function
**Scope chain:** inner → outer → global
**Risk:** holding references can cause memory leaks if not cleaned up

Q: "ArrayList vs LinkedList?"
A:
"ArrayList is fast to read any item by index. LinkedList is fast to add or remove at the ends."

**Real-world:** ArrayList for read-heavy data, LinkedList for queues.

**ArrayList access:** O(1) by index
**ArrayList insert middle:** O(n) shifts elements
**LinkedList access:** O(n) traversal
**LinkedList insert ends:** O(1)
**Memory:** LinkedList uses more per element (node overhead)
**Risk:** using LinkedList for random access kills performance

Q: "What are OOP principles?"
A:
OOP principles are rules for organizing code into objects—each object hides its data and exposes controlled methods, making code reusable and maintainable.

**Real-world:** Banking apps (encapsulation hides balance), payment systems (polymorphism handles different payment types), e-commerce platforms (inheritance for product categories).

**Encapsulation:** Hide internal data, expose only necessary methods through public interface
**Inheritance:** Child class reuses parent behavior, reducing code duplication across similar types
**Polymorphism:** Same method name, different implementations depending on object type—parent reference calls child method
**Abstraction:** Hide implementation details behind simple interface, user doesn't need to know how it works
**Risk:** violating these principles creates "spaghetti code"—tight coupling, impossible to test, changes break everything

NOTE: OOP has 4 principles (above). SOLID is a SEPARATE set of 5 design principles—only include SOLID if explicitly asked.

Q: "What HTTP methods exist?"
A:
**GET:** Read data
**POST:** Create new resource
**PUT:** Replace entire resource
**PATCH:** Update part of resource
**DELETE:** Remove resource

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
            langTopics = "java, hashMap, hashSet, arrayList, linkedList, treeMap, queue, stack, collections, threads, synchronized, volatile, deadlock, concurrency, jvm, garbageCollection, heap, memory, spring, streams, optionals, generics"
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
    ///   - conversationHistory: Optional prior conversation messages for context
    ///   - onChunk: Callback for each chunk
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
