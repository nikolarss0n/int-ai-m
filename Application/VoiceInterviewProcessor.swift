import Cocoa

/// Protocol for voice interview processor callbacks
protocol VoiceInterviewProcessorDelegate: AnyObject {
    // UI Callbacks
    func processorShowLoading(_ message: String, color: NSColor, turnID: UUID)
    func processorHideLoading(turnID: UUID)
    func processorDidReceiveQuestion(_ text: String, topic: String, messageType: InterviewMessage.MessageType, source: AudioSource, turnID: UUID, sequence: Int)
    func processorDidStartStreaming(messageType: InterviewMessage.MessageType, topic: String, latencyMs: Int?, turnID: UUID, sequence: Int)
    func processorDidReceiveAnswerChunk(_ fullContent: String, turnID: UUID)
    func processorDidFinishAnswer(_ fullAnswer: String, totalLatencyMs: Int?, turnID: UUID)
    func processorDidUpdateStatus(_ message: String)

    // Data Access
    var userBackground: String { get }
    var pinnedSolution: String? { get }
    var conversationContext: ConversationContext { get }
}

/// Handles voice interview audio processing: transcription, classification, and answer generation
class VoiceInterviewProcessor {
    weak var delegate: VoiceInterviewProcessorDelegate?

    // Clients (injected)
    private var groqClient: GroqInterviewClient?
    private var anthropicClient: AnthropicClient?

    // Deduplication state
    private var recentTranscriptions: [(text: String, timestamp: Date, source: AudioSource)] = []
    private let dedupeWindow: TimeInterval = AppConstants.Thresholds.dedupeWindow
    private let similarityThreshold: Double = AppConstants.Thresholds.similarityThreshold

    // Utterance buffering state
    private var utteranceBuffer: String = ""
    private var bufferTimestamp: Date?
    private var utteranceBufferSequence: Int?
    private let bufferTimeout: TimeInterval = AppConstants.Thresholds.bufferTimeout

    // Answer cooldown
    private var lastAnswerTime: Date?
    private let answerCooldown: TimeInterval = AppConstants.Thresholds.answerCooldown

    // Memory retrieval
    private let memoryRetrieval = MemoryRetrievalUseCase()
    private let transcriptionTimeout: TimeInterval = 12.0
    private let turnLock = NSLock()
    private let processingStateLock = NSRecursiveLock()
    private var turnGeneration = 0
    private var previewGeneration = 0
    private var nextTurnSequence = 1
    private var summaryRevision = 0
    private var summaryInFlight = false
    private var previewTask: Task<Void, Never>?
    private var processTasks: [UUID: Task<Void, Never>] = [:]
    private var previewTranscript: (text: String, byteCount: Int, generation: Int)?

    private enum ProcessingError: LocalizedError {
        case transcriptionTimeout(TimeInterval)

        var errorDescription: String? {
            switch self {
            case .transcriptionTimeout(let seconds):
                return "Groq transcription timed out after \(Int(seconds))s"
            }
        }
    }

    private struct QuestionSignal {
        let score: Int
        let reasons: [String]
        let topicHint: String?
        let isFollowUp: Bool
        let isBareIncomplete: Bool

        var protectsFromSkip: Bool {
            score >= 3 && !isBareIncomplete
        }
    }

    private final class AnswerStreamState: @unchecked Sendable {
        private let lock = NSLock()
        private var accumulatedText = ""
        private var started = false
        private var cancelled = false

        func appendVisibleChunk(_ chunk: String) -> (snapshot: String, isFirst: Bool)? {
            lock.lock()
            defer { lock.unlock() }

            guard !cancelled else { return nil }
            if !started && chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return nil
            }

            accumulatedText += chunk
            let first = !started
            started = true
            return (accumulatedText, first)
        }

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }

        var hasStarted: Bool {
            lock.lock()
            defer { lock.unlock() }
            return started
        }

        var text: String {
            lock.lock()
            defer { lock.unlock() }
            return accumulatedText
        }
    }

    init() {}

    /// Configure the processor with API clients
    func configure(groqClient: GroqInterviewClient?, anthropicClient: AnthropicClient?) {
        self.groqClient = groqClient
        self.anthropicClient = anthropicClient
        debugLog("VoiceInterviewProcessor configured - groq: \(groqClient != nil), anthropic: \(anthropicClient != nil)")
        Task {
            await groqClient?.warmupConnection()
            await anthropicClient?.warmupConnection()
        }
    }

    /// Clear all state (call when stopping interview)
    func reset() {
        cancelInFlightTurn()
        withProcessingStateLock {
            recentTranscriptions.removeAll()
            utteranceBuffer = ""
            bufferTimestamp = nil
            utteranceBufferSequence = nil
            lastAnswerTime = nil
            summaryRevision += 1
            summaryInFlight = false
        }
        withTurnLock { nextTurnSequence = 1 }
    }

    func cancelInFlightTurn() {
        let cancellation = withTurnLock { () -> (Task<Void, Never>?, [Task<Void, Never>]) in
            turnGeneration += 1
            previewGeneration += 1
            previewTranscript = nil
            let currentPreview = previewTask
            previewTask = nil
            let currentTasks = Array(processTasks.values)
            processTasks.removeAll()
            return (currentPreview, currentTasks)
        }
        cancellation.0?.cancel()
        cancellation.1.forEach { $0.cancel() }
        groqClient?.cancelCurrentRequest()
        anthropicClient?.cancelCurrentRequest()
        debugLog(.audio, "Cancelled in-flight turn")
    }

    /// Cancel speculative STT only. A resumed utterance must not cancel an already
    /// committed answer for the previous question in a rapid question burst.
    func cancelPrefetchTranscription() {
        let task = withTurnLock { () -> Task<Void, Never>? in
            previewGeneration += 1
            previewTranscript = nil
            let current = previewTask
            previewTask = nil
            return current
        }
        task?.cancel()
        debugLog(.audio, "Cancelled speculative transcription preview")
    }

    /// Overlap Whisper with the remaining end-of-speech wait. Must not start an answer card.
    func prefetchTranscription(_ audioData: Data, source: AudioSource) {
        let action = SpeechTurnPolicy.action(for: .speculativePreview)
        guard action == .prefetchTranscriptionOnly,
              !SpeechTurnPolicy.startsAnswerCard(action) else { return }
        guard let client = groqClient else { return }

        let previewSetup = withTurnLock { () -> (Int, Task<Void, Never>?) in
            previewGeneration += 1
            previewTranscript = nil
            let previous = previewTask
            previewTask = nil
            return (previewGeneration, previous)
        }
        let generation = previewSetup.0
        previewSetup.1?.cancel()

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let (text, _) = try await self.transcribeWithTimeout(client: client, audioData: audioData)
                try Task.checkCancellation()
                let stillCurrent = self.withTurnLock {
                    let current = generation == self.previewGeneration
                    if current {
                        self.previewTranscript = (text, audioData.count, generation)
                    }
                    return current
                }
                if stillCurrent {
                    debugLog(.transcription, "Preview STT cached \(text.count) chars from \(source == .microphone ? "mic" : "system")")
                }
            } catch {
                debugLog(.transcription, "Preview STT skipped: \(error.localizedDescription)")
            }
        }
        let accepted = withTurnLock {
            guard generation == previewGeneration else { return false }
            previewTask = task
            return true
        }
        if !accepted { task.cancel() }
    }

    private func isCurrentTurn(_ generation: Int) -> Bool {
        withTurnLock { generation == turnGeneration }
    }

    private func withTurnLock<T>(_ body: () -> T) -> T {
        turnLock.lock()
        defer { turnLock.unlock() }
        return body()
    }

    private func reserveTurnSequence() -> Int {
        withTurnLock {
            let sequence = nextTurnSequence
            nextTurnSequence += 1
            return sequence
        }
    }

    private func withProcessingStateLock<T>(_ body: () -> T) -> T {
        processingStateLock.lock()
        defer { processingStateLock.unlock() }
        return body()
    }

    private func scheduleSummarizationIfNeeded(context: ConversationContext, generation: Int) {
        guard let client = anthropicClient else { return }

        let work = withProcessingStateLock { () -> (revision: Int, text: String)? in
            guard context.needsSummarization, !summaryInFlight else { return nil }
            summaryRevision += 1
            summaryInFlight = true
            return (summaryRevision, context.getTextForSummarization())
        }
        guard let work else { return }
        guard !work.text.isEmpty else {
            finishSummarization(revision: work.revision)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            guard self.isCurrentTurn(generation) else {
                self.finishSummarization(revision: work.revision)
                return
            }

            do {
                let summary = try await client.summarizeConversation(conversationText: work.text)
                guard self.isCurrentTurn(generation) else {
                    self.finishSummarization(revision: work.revision)
                    return
                }
                self.withProcessingStateLock {
                    guard work.revision == self.summaryRevision else { return }
                    context.setSummary(summary)
                    self.summaryInFlight = false
                }
            } catch {
                self.finishSummarization(revision: work.revision)
                print("⚠️ Summarization failed: \(error)")
            }
        }
    }

    private func finishSummarization(revision: Int) {
        withProcessingStateLock {
            if revision == summaryRevision {
                summaryInFlight = false
            }
        }
    }

    private func cachedPreviewTranscript(matching audioData: Data, generation: Int) -> String? {
        turnLock.lock()
        defer { turnLock.unlock() }
        guard let preview = previewTranscript,
              preview.generation == generation,
              !preview.text.isEmpty else { return nil }
        let larger = max(preview.byteCount, audioData.count)
        guard larger > 0 else { return nil }
        let delta = abs(preview.byteCount - audioData.count)
        guard (delta * 100) / larger < 25 else { return nil }
        return preview.text
    }

    // MARK: - Deduplication Helpers

    /// Jaccard similarity between two strings (word-level)
    private func stringSimilarity(_ a: String, _ b: String) -> Double {
        let wordsA = Set(a.lowercased().split(separator: " ").map { String($0) })
        let wordsB = Set(b.lowercased().split(separator: " ").map { String($0) })
        guard !wordsA.isEmpty || !wordsB.isEmpty else { return 0 }
        let intersection = wordsA.intersection(wordsB).count
        let union = wordsA.union(wordsB).count
        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    /// Check if transcription is duplicate (similar text within time window)
    private func isDuplicateTranscription(_ text: String, source: AudioSource, signal: QuestionSignal) -> Bool {
        processingStateLock.lock()
        defer { processingStateLock.unlock() }
        let now = Date()
        // Clean old entries
        recentTranscriptions.removeAll { now.timeIntervalSince($0.timestamp) > dedupeWindow }
        let currentTechnicalTokens = technicalQuestionTokens(in: normalizedQuestionText(text))

        // Check similarity with recent transcriptions
        for recent in recentTranscriptions {
            let similarity = stringSimilarity(text, recent.text)
            if similarity > similarityThreshold {
                let recentTechnicalTokens = technicalQuestionTokens(in: normalizedQuestionText(recent.text))
                if signal.protectsFromSkip,
                   !currentTechnicalTokens.isEmpty,
                   !recentTechnicalTokens.isEmpty,
                   currentTechnicalTokens != recentTechnicalTokens {
                    NSLog("🔄 DEDUPE: Keeping similar question because topic changed (%@ → %@)",
                          recentTechnicalTokens.sorted().joined(separator: ","),
                          currentTechnicalTokens.sorted().joined(separator: ","))
                    continue
                }

                // Don't dedupe if new text is significantly longer (it's more complete, not a duplicate)
                let lengthRatio = Double(text.count) / Double(max(recent.text.count, 1))
                if lengthRatio > 1.3 {
                    NSLog("🔄 DEDUPE: Keeping longer transcription (%.0f%% similar but %.0f%% longer)", similarity * 100, (lengthRatio - 1) * 100)
                    continue
                }
                let previewText = String(recent.text.prefix(30))
                NSLog("🔄 DEDUPE: Skipping similar transcription (%.0f%% match with '%@')", similarity * 100, previewText)
                return true
            }
        }

        recentTranscriptions.append((text, now, source))
        return false
    }

    /// Check for question markers in text
    func checkForQuestionMarkers(_ text: String) -> Bool {
        questionSignal(for: text, lastTopic: delegate?.conversationContext.lastTopic).protectsFromSkip
    }

    private func questionSignal(for text: String, lastTopic: String?) -> QuestionSignal {
        let normalized = normalizedQuestionText(text)
        let words = normalized.split(separator: " ").map(String.init)
        let wordCount = words.count
        var score = 0
        var reasons: [String] = []

        func add(_ points: Int, _ reason: String) {
            score += points
            reasons.append(reason)
        }

        let isCandidateStatement =
            normalized.hasPrefix("i ") ||
            normalized.hasPrefix("i'm ") ||
            normalized.hasPrefix("ive ") ||
            normalized.hasPrefix("i've ") ||
            normalized.hasPrefix("we ") ||
            normalized.hasPrefix("my ") ||
            normalized.contains("i have ") ||
            normalized.contains("i worked ") ||
            normalized.contains("we used ") ||
            normalized.contains("we implemented ")

        let bareIncomplete = isBareIncompletePrompt(normalized)

        if normalized.contains("?") {
            add(3, "question_mark")
        }

        let directQuestionPatterns = [
            "what is", "what are", "what's", "whats", "what did", "what do", "what does",
            "what exactly",
            "how do", "how does", "how is", "how would", "how can", "how to",
            "why do", "why does", "why is", "why would",
            "when do", "when does", "when would", "when should",
            "where do", "where does", "where is", "where exactly",
            "which ", "who ", "whose "
        ]
        if directQuestionPatterns.contains(where: { normalized.contains($0) }) {
            add(3, "direct_question")
        }

        let requestPatterns = [
            "can you explain", "could you explain", "can you tell", "could you tell",
            "tell me about", "tell me more", "walk me through", "walk us through",
            "could you walk through", "talk me through ", "talk us through ",
            "show me", "give me", "give us ",
            "help me understand", "help us understand",
            "explain ", "describe ", "let's talk about", "lets talk about",
            "let's discuss ", "lets discuss ", "let's go over ", "lets go over ",
            "introduce yourself", "please introduce", "can we start with your", "can we begin with your",
            "would like to know", "i want to know", "i'd like to know", "id like to know"
        ]
        if requestPatterns.contains(where: { normalized.contains($0) }) {
            add(3, "request")
        }

        let mixedLanguagePatterns = [
            "какво", "как ", "защо", "кога", "къде", "кой", "коя", "кое", "кои",
            "разкажи", "раскажи", "обясни", "опиши",
            "was ", "wie ", "warum", "wann", "wo ", "wer ", "welche",
            "qu'est", "comment", "pourquoi", "quand", "où ", "qui ",
            "qué ", "cómo", "por qué", "cuándo", "dónde", "quién"
        ]
        if mixedLanguagePatterns.contains(where: { normalized.contains($0) }) {
            add(3, "question_language_marker")
        }

        let comparisonPatterns = [
            " vs ", " versus ", "difference between", "differences between",
            "compare ", "pros and cons", "tradeoff", "trade-off", "trade off"
        ]
        if comparisonPatterns.contains(where: { normalized.contains($0) }) {
            add(2, "comparison")
        }

        let followUpPatterns = [
            "what about", "how about", "what else", "anything else", "tell me more",
            "can you elaborate", "could you elaborate", "elaborate",
            "can you expand", "expand on that", "go deeper", "more details",
            "give me an example", "example", "edge cases", "corner cases",
            "complexity", "time complexity", "space complexity", "drawbacks",
            "risks", "retry", "retries", "mocking"
        ]
        let hasFollowUpPhrase = !isCandidateStatement && followUpPatterns.contains { normalized.contains($0) }
        let technicalTokens = technicalQuestionTokens(in: normalized)
        let isShortTechnicalPrompt = wordCount <= 7 && !technicalTokens.isEmpty && !isCandidateStatement
        let isContextualShortFollowUp = lastTopic != nil && wordCount <= 6 && (hasFollowUpPhrase || isShortTechnicalPrompt)
        let isFollowUp = hasFollowUpPhrase || isContextualShortFollowUp

        if isFollowUp {
            add(lastTopic == nil ? 2 : 3, "follow_up")
        }

        if !technicalTokens.isEmpty {
            add(1, "technical_term")
            if isShortTechnicalPrompt {
                add(2, "short_technical_prompt")
            }
        }

        let topicHint = isVagueFollowUpPrompt(normalized, technicalTokens: technicalTokens)
            ? "followUp"
            : bestTopicHint(from: normalized, technicalTokens: technicalTokens)
        return QuestionSignal(
            score: score,
            reasons: reasons,
            topicHint: topicHint,
            isFollowUp: isFollowUp,
            isBareIncomplete: bareIncomplete
        )
    }

    private func normalizedQuestionText(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func repairNoisyTechnicalTranscript(
        _ text: String,
        favorsAIAcronyms: Bool = AppSettings.shared.role.isAIOrData
    ) -> String {
        guard favorsAIAcronyms else { return text }

        let normalized = normalizedQuestionText(text)
        func hasWord(_ word: String) -> Bool {
            let pattern = "(^|[^a-z0-9])\(word)($|[^a-z0-9])"
            return normalized.range(of: pattern, options: .regularExpression) != nil
        }

        let hasRack = hasWord("rack")
        let hasRag = hasWord("rag")
        let hasCAC = hasWord("cac")
        let hasCAG = hasWord("cag")
        let rackLooksLikeRAG = hasRack && (
            hasCAC ||
            hasCAG ||
            normalized.range(of: #"\brack\s+(system|pipeline|architecture)\b"#, options: .regularExpression) != nil
        )
        let cacLooksLikeCAG = hasCAC && (
            hasRack ||
            hasRag ||
            normalized.contains("cache augmented") ||
            normalized.contains("context augmented")
        )

        guard rackLooksLikeRAG || cacLooksLikeCAG else { return text }

        var repaired = text
        if rackLooksLikeRAG {
            repaired = repaired.replacingOccurrences(
                of: #"\brack\b"#,
                with: "RAG",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        if cacLooksLikeCAG {
            repaired = repaired.replacingOccurrences(
                of: #"\bcac\b"#,
                with: "CAG",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return repaired
    }

    private func isBareIncompletePrompt(_ normalized: String) -> Bool {
        let cleaned = normalized.trimmingCharacters(in: CharacterSet(charactersIn: " .,!?:;"))
        let incompleteStems: Set<String> = [
            "what is the", "what is a", "what are the", "how do you", "how does the",
            "can you", "can you explain", "could you", "could you explain",
            "tell me about", "explain", "describe", "walk me through"
        ]
        if incompleteStems.contains(cleaned) {
            return true
        }

        let incompleteComparisonSuffixes = [
            "difference between", "differences between",
            "compare", "compare between", "versus", "vs"
        ]
        return incompleteComparisonSuffixes.contains { cleaned.hasSuffix($0) }
    }

    private func technicalQuestionTokens(in normalized: String) -> Set<String> {
        let tokenMap: [(String, String)] = [
            ("hash map", "hashMap"), ("hashmap", "hashMap"), ("hash table", "hashMap"),
            ("hash set", "hashSet"), ("hashset", "hashSet"),
            ("hash code", "hashCode"), ("hashcode", "hashCode"),
            ("arraylist", "arrayList"), ("array list", "arrayList"),
            ("linkedlist", "linkedList"), ("linked list", "linkedList"),
            ("oop", "oop"), ("o o p", "oop"), ("object oriented", "oop"),
            ("solid", "solid"), ("polymorphism", "polymorphism"), ("inheritance", "inheritance"),
            ("encapsulation", "encapsulation"), ("abstraction", "abstraction"),
            ("singleton", "singleton"), ("factory", "factory"), ("dependency injection", "dependencyInjection"),
            ("playwright", "playwright"), ("selenium", "selenium"), ("cypress", "cypress"),
            ("pytest", "pytest"), ("test automation", "testAutomation"), ("e2e", "e2eTesting"),
            ("end to end", "e2eTesting"), ("api testing", "apiTesting"), ("contract testing", "contractTesting"),
            ("accessibility testing", "accessibilityTesting"), ("a11y", "accessibilityTesting"),
            ("wcag", "accessibilityTesting"), ("screen reader", "accessibilityTesting"),
            ("keyboard navigation", "accessibilityTesting"),
            ("cross browser", "crossBrowserTesting"), ("browser compatibility", "crossBrowserTesting"),
            ("page object", "pageObjects"), ("locator", "playwrightLocators"), ("locators", "playwrightLocators"),
            ("fixture", "playwrightFixtures"), ("fixtures", "playwrightFixtures"),
            ("test data", "testData"), ("mocking", "mocking"), ("mock", "mocking"),
            ("flaky", "flakyTests"), ("flake", "flakyTests"), ("trace viewer", "traceViewer"),
            ("trace", "traceViewer"), ("ci pipeline", "cicd"), ("pipeline", "cicd"),
            ("ci/cd", "cicd"), ("ci cd", "cicd"), ("cicd", "cicd"),
            ("continuous integration", "cicd"), ("continuous delivery", "cicd"),
            ("continuous deployment", "cicd"),
            ("regression", "regression"), ("getbyrole", "playwrightLocators"),
            ("get by role", "playwrightLocators"), ("web first", "webFirstAssertions"),
            ("auto wait", "autoWaiting"), ("storage state", "storageState"),
            ("browser context", "browserContext"), ("page route", "pageRoute"),
            ("network intercept", "networkMocking"), ("har", "networkMocking"),
            ("workers", "workers"), ("worker", "workers"), ("sharding", "sharding"),
            ("retry", "retries"), ("retries", "retries"), ("codegen", "codegen"),
            ("thread", "threads"), ("threads", "threads"), ("deadlock", "deadlock"),
            ("lock", "locks"), ("locks", "locks"), ("jvm", "jvm"), ("jdk", "jdk"),
            ("garbage collection", "garbageCollection"), ("heap", "heap"), ("stack", "stack"),
            ("closure", "closure"), ("event loop", "eventLoop"), ("promise", "promises"),
            ("promises", "promises"), ("async await", "asyncAwait"),
            ("big o", "bigO"), ("complexity", "bigO"), ("binary search", "binarySearch"),
            ("recursion", "recursion"), ("dynamic programming", "dynamicProgramming"),
            ("docker", "docker"), ("kubernetes", "kubernetes"), ("linux", "linux"),
            ("bash", "bash"), ("rest", "rest"), ("microservices", "microservices"),
            ("database", "database"), ("sql", "sql"), ("nosql", "nosql"),
            ("llm", "llm"), ("large language model", "llm"),
            ("rag", "rag"), ("retrieval augmented generation", "rag"),
            ("cag", "cag"), ("cache augmented generation", "cag"),
            ("context augmented generation", "cag"),
            ("vector database", "vectorDatabase"),
            ("embedding", "embeddings"), ("embeddings", "embeddings"),
            ("prompt engineering", "promptEngineering"),
            ("fine tune", "fineTuning"), ("fine tuning", "fineTuning"),
            ("transformer", "transformers"), ("attention", "attention"),
            // Common interview topics that were missing from local detection. Adding them
            // lets clear questions on these topics resolve a concrete topic locally and take
            // the direct Haiku answer path instead of waiting on the slower classifier path.
            ("interface", "interface"),
            ("abstract class", "abstractClass"), ("abstractclass", "abstractClass"),
            ("lambda", "lambda"), ("stream api", "streamApi"), ("streams", "streamApi"),
            ("generics", "generics"), ("typescript", "typescript"),
            ("exception", "exceptions"), ("exceptions", "exceptions"),
            ("volatile", "volatile"), ("synchronized", "synchronized"), ("synchronization", "synchronized"),
            ("caching", "caching"), ("cache", "caching"), ("redis", "redis"),
            ("load balancing", "loadBalancing"), ("load balancer", "loadBalancing"),
            ("redux", "redux"), ("react hooks", "reactHooks"),
            ("usestate", "useState"), ("useeffect", "useEffect"),
            // More high-frequency interview topics. The short/ambiguous tokens below
            // (aws, git, css, dom, orm, jwt, tcp, udp) are matched on word boundaries
            // via `wordBoundaryNeedles` so they never fire inside unrelated words
            // (e.g. "performance" must not match "orm", "random" must not match "dom").
            ("graphql", "graphql"), ("oauth", "oauth"), ("kafka", "kafka"),
            ("websocket", "websockets"), ("web socket", "websockets"),
            ("middleware", "middleware"),
            ("aws", "aws"), ("git", "git"), ("css", "css"), ("dom", "dom"),
            ("orm", "orm"), ("jwt", "jwt"), ("tcp", "tcp"), ("udp", "udp"),
            // High-frequency QA/SDET and backend interview topics that were missing from
            // local detection. Resolving them locally lets clear questions take the fast
            // direct answer path instead of the slower model classification path that adds
            // visible answer latency. All are
            // multi-word or distinctive tokens, so they are word-boundary-safe; only "acid"
            // is guarded via `wordBoundaryNeedles` (it is a substring of "placid").
            ("test pyramid", "testPyramid"), ("test strategy", "testStrategy"),
            ("test plan", "testStrategy"), ("test case", "testDesign"), ("test design", "testDesign"),
            ("boundary value", "boundaryValue"), ("equivalence partition", "equivalencePartitioning"),
            ("smoke test", "smokeTesting"), ("sanity test", "sanityTesting"), ("sanity check", "sanityTesting"),
            ("cucumber", "bdd"), ("gherkin", "bdd"), ("behavior driven", "bdd"), ("behaviour driven", "bdd"),
            // Test-methodology fundamentals — among the most common interview openers and
            // previously absent from local detection, so clear questions ("What is unit
            // testing?", "What is TDD?") fell through to the slow Haiku classify+answer path.
            // Multi-word phrases are substring-safe; the bare abbreviations "tdd"/"bdd" are
            // guarded via `wordBoundaryNeedles` so they never fire inside another word.
            ("unit test", "unitTesting"), ("integration test", "integrationTesting"),
            ("test driven", "tdd"), ("tdd", "tdd"), ("bdd", "bdd"),
            ("design pattern", "designPatterns"),
            ("rest assured", "apiTesting"), ("restassured", "apiTesting"),
            ("soft assert", "assertions"), ("headless", "headless"), ("xpath", "playwrightLocators"),
            ("performance testing", "performanceTesting"), ("load testing", "performanceTesting"),
            ("stress testing", "performanceTesting"),
            ("database index", "indexing"), ("db index", "indexing"), ("indexing", "indexing"),
            ("acid", "transactions"), ("transaction", "transactions"),
            ("message queue", "messageQueue"), ("rate limit", "rateLimiting"),
            ("memory leak", "memoryLeak"), ("cap theorem", "capTheorem"),
            ("idempoten", "idempotency"), ("normalization", "normalization"), ("normalisation", "normalization"),
            // Core data-structure and system-design openers that were missing from local
            // detection, so clear questions ("What is a queue?", "How does sorting work?",
            // "Walk me through a system design problem") fell through to the slow Haiku
            // classify+answer path. All three are distinct, substring-safe tokens already in
            // the model's TOPICS list, so resolving them locally lets clear questions take the
            // direct answer path without changing classification behavior.
            // "message queue" stays the more specific messageQueue topic (it sorts before
            // bare "queue").
            ("queue", "queue"), ("sorting", "sorting"), ("system design", "systemDesign"),
            // High-frequency DSA patterns and concurrency openers that were missing from
            // local detection, so clear questions ("What is an array?", "What is
            // backtracking?", "What is a race condition?") fell through to the slow
            // Haiku classify+answer path instead of the direct answer path. "array" is guarded in `wordBoundaryNeedles`
            // so it never fires inside "disarray"/"arrayed" and never shadows arrayList
            // (disambiguated in `bestTopicHint`); the rest are multi-word or distinctive
            // tokens that are inherently substring-safe. ("two pointer" is intentionally
            // omitted: "two" contains the German "wo " question marker, which would let a
            // candidate statement mentioning it score as a question and get fast-pathed.)
            ("array", "array"),
            ("sliding window", "slidingWindow"),
            ("backtracking", "backtracking"), ("memoization", "memoization"),
            ("concurrency", "concurrency"), ("race condition", "raceCondition"),
            ("хешмап", "hashMap"), ("хеш мап", "hashMap"), ("хеш таблиц", "hashMap"),
            ("хеш код", "hashCode"), ("ооп", "oop"), ("оп,", "oop"), ("оп ", "oop"),
            ("обектно", "oop"), ("полиморф", "polymorphism"),
            ("наследяване", "inheritance"), ("капсулация", "encapsulation")
        ]

        // Short or ambiguous tokens that must match on a word boundary so they do not
        // fire as substrings of unrelated words (e.g. "har" in "share", "orm" in
        // "performance", "dom" in "random", "aws" in "flaws", "git" in "legitimate").
        let wordBoundaryNeedles: Set<String> = ["har", "aws", "git", "css", "dom", "orm", "jwt", "tcp", "udp", "acid", "tdd", "bdd", "array", "llm", "rag", "cag"]
        var result = Set<String>()
        func containsNeedle(_ needle: String) -> Bool {
            if wordBoundaryNeedles.contains(needle) {
                let pattern = "(^|[^a-z0-9])" + needle + "($|[^a-z0-9])"
                return normalized.range(of: pattern, options: .regularExpression) != nil
            }
            return normalized.contains(needle)
        }

        for (needle, token) in tokenMap where containsNeedle(needle) {
            result.insert(token)
        }
        return result
    }

    private func bestTopicHint(from normalized: String, technicalTokens: Set<String>) -> String? {
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
            normalized.contains("полиморф") ||
            normalized.contains("наследяване") ||
            normalized.contains("капсулация") {
            return "oop"
        }
        if technicalTokens.contains("rag") && technicalTokens.contains("cag") {
            return "ragCag"
        }
        if normalized.contains("introduce yourself") ||
            normalized.contains("please introduce") ||
            normalized.contains("your introduction") ||
            normalized.contains("quick intro") ||
            normalized.contains("brief intro") ||
            normalized.contains("about yourself") ||
            normalized.contains("your background") ||
            normalized.contains("your experience") ||
            normalized.contains("your project") ||
            normalized.contains("your projects") ||
            normalized.contains("recent project") ||
            normalized.contains("last project") ||
            normalized.contains("project you worked on") ||
            normalized.contains("current role") ||
            normalized.contains("last role") {
            return "personal"
        }
        // "array list"/"arraylist" matches both the bare "array" token and the more
        // specific arrayList needle; prefer arrayList so it is never shadowed by the
        // alphabetically-earlier "array" in the fallback below.
        if normalized.contains("array list") || normalized.contains("arraylist") {
            return "arrayList"
        }
        return technicalTokens.sorted().first
    }

    private func isVagueFollowUpPrompt(_ normalized: String, technicalTokens: Set<String>) -> Bool {
        guard technicalTokens.isEmpty else { return false }

        let cleaned = normalized.trimmingCharacters(in: CharacterSet(charactersIn: " .,!?:;"))
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

    private func shouldSkipAsSocialPleasantry(_ trimmed: String) -> Bool {
        let normalized = normalizedQuestionText(trimmed)
        let cleaned = normalized
            .replacingOccurrences(of: #"[^a-z0-9\s']+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }

        let contentMarkers = [
            "experience", "background", "project", "role", "testing", "automation",
            "framework", "code", "implement", "design", "architecture", "system",
            "api", "test", "strength", "weakness", "company", "last role",
            "introduction", "introduce"
        ]
        if !technicalQuestionTokens(in: normalized).isEmpty ||
            contentMarkers.contains(where: { cleaned.contains($0) }) {
            return false
        }

        let interviewRequestPhrases = [
            "tell me about", "tell us about",
            "walk me through", "walk us through",
            "talk me through", "talk us through",
            "let's talk about", "lets talk about",
            "let's discuss", "lets discuss",
            "let's go over", "lets go over",
            "explain your", "describe your",
            "introduce yourself", "please introduce"
        ]
        if interviewRequestPhrases.contains(where: { cleaned.contains($0) }) {
            return false
        }

        let exactSocialPrompts: Set<String> = [
            "how are you", "how are you doing", "how's it going", "how is it going",
            "how have you been", "how have you been doing",
            "can you hear me", "are you there", "are you able to hear me",
            "can you see my screen", "shall we start", "are you ready", "what's up"
        ]
        if exactSocialPrompts.contains(cleaned) {
            return true
        }

        let setupCheckPhrases = [
            "can you hear me", "can you hear us", "can you hear okay", "can you hear clearly",
            "do you hear me", "do you hear us", "hear us okay", "hear us clearly",
            "is the audio okay", "audio okay", "audio working", "audio is working",
            "can you confirm your audio", "can you confirm audio",
            "is the sound okay", "sound okay", "sound working", "sound is working",
            "can you see my screen",
            "are you able to see my screen", "see my screen",
            "can you see the screen", "are you able to see the screen",
            "see the screen", "see this screen", "see shared screen",
            "see the shared screen", "see the screen share",
            "is my screen visible", "is the screen visible",
            "is the shared screen visible", "screen visible",
            "shared screen visible", "screen share visible"
        ]
        let wordCount = cleaned.split(separator: " ").count
        if wordCount <= 12 && setupCheckPhrases.contains(where: { cleaned.contains($0) }) {
            return true
        }

        let readySetupPhrases = [
            "are you ready to start", "are you ready to begin", "are you ready to proceed",
            "ready to start", "ready to begin", "ready to proceed", "shall we begin",
            "shall we proceed", "can we start", "can we begin", "can we proceed",
            "are you comfortable to start", "are you comfortable to begin",
            "are you comfortable to proceed", "comfortable to start",
            "comfortable to begin", "comfortable to proceed"
        ]
        if wordCount <= 8 && readySetupPhrases.contains(where: { cleaned.contains($0) }) {
            return true
        }

        let reciprocalSocialPrompts = ["how about you", "what about you", "and you"]
        if wordCount <= 10,
           reciprocalSocialPrompts.contains(where: { cleaned == $0 || cleaned.hasSuffix(" \($0)") }) {
            let socialReplyMarkers = [
                "i'm good", "im good", "i am good", "doing good", "doing well",
                "all good", "i'm fine", "im fine", "thanks", "thank you", "on my side"
            ]
            return wordCount <= 4 || socialReplyMarkers.contains(where: { cleaned.contains($0) })
        }

        let hasSocialHowQuestion = cleaned.contains("how are you") || cleaned.contains("how have you been")
        if hasSocialHowQuestion {
            let contentfulHowAreYouPhrases = [
                "how are you handling", "how are you using", "how are you testing",
                "how are you implementing", "how are you designing", "how are you managing",
                "how are you debugging", "how are you solving", "how are you approaching",
                "how are you dealing", "how are you working", "how are you doing with",
                "how are you doing in", "how are you doing on", "how are you doing for",
                "how have you been handling", "how have you been using", "how have you used",
                "how have you been testing", "how have you been implementing",
                "how have you been designing", "how have you been managing",
                "how have you been debugging", "how have you been solving",
                "how have you been approaching", "how have you been dealing",
                "how have you been working"
            ]
            if contentfulHowAreYouPhrases.contains(where: { cleaned.contains($0) }) {
                return false
            }

            let socialLeadIns = [
                "hi ", "hello ", "hey ", "so hi", "so hello",
                "nice to meet you", "good to meet you", "great to meet you",
                "pleasure to meet you",
                "before we start", "before we begin", "before we get started",
                "before getting started", "before we jump in"
            ]
            let socialWellnessPhrases = [
                "how are you today", "how are you doing", "how are you doing today",
                "how are you feeling", "how are you feeling today",
                "how have you been", "how have you been doing",
                "how have you been today", "how have you been feeling"
            ]
            let socialReplyMarkers = [
                "doing good", "doing well", "i'm good", "im good", "i am good",
                "i'm fine", "im fine", "all good"
            ]

            return socialReplyMarkers.contains(where: { cleaned.contains($0) }) ||
                socialLeadIns.contains(where: { cleaned.hasPrefix($0) || cleaned.contains(" \($0)") }) ||
                (wordCount <= 12 && socialWellnessPhrases.contains(where: { cleaned.contains($0) }))
        }

        return false
    }

    private func shouldVetoQuestionAsCandidateStatement(_ text: String, signal: QuestionSignal) -> Bool {
        let normalized = normalizedQuestionText(text)
        let wordCount = normalized.split(separator: " ").count
        guard wordCount >= 5 else { return false }

        let firstPersonStarts = [
            "i ", "i'm ", "im ", "ive ", "i've ", "we ", "my ",
            "in my last role", "in my current role"
        ]
        let answerPhrases = [
            "i have ", "i worked ", "i use ", "i used ", "i usually ",
            "i was ", "we used ", "we implemented ", "we have ",
            "my experience", "my main strength", "the system uses ",
            "let me explain", "let me describe", "let me walk through"
        ]

        let looksLikeCandidateStatement = firstPersonStarts.contains(where: { normalized.hasPrefix($0) }) ||
            answerPhrases.contains(where: { normalized.contains($0) })
        guard looksLikeCandidateStatement else { return false }

        let interviewerRequestPhrases = [
            "i would like to know", "i'd like to know", "id like to know",
            "i want to know", "i wanted to ask",
            "i would like you to", "i'd like you to", "id like you to"
        ]
        if interviewerRequestPhrases.contains(where: { normalized.contains($0) }) {
            return false
        }

        let candidateAbilityLeadIns = [
            "i can explain", "i could explain", "i can tell", "i could tell",
            "i can describe", "i could describe", "i can walk through", "i could walk through",
            "i can show", "i could show", "i would explain", "i'd explain", "id explain",
            "i will explain", "i'll explain", "ill explain",
            "i would describe", "i'd describe", "id describe",
            "i will describe", "i'll describe", "ill describe",
            "i will walk through", "i'll walk through", "ill walk through",
            "let me explain", "let me describe", "let me walk through",
            "we can explain", "we could explain", "we can walk through", "we could walk through"
        ]
        if let leadIn = candidateAbilityLeadIns.first(where: { normalized.hasPrefix($0) }) {
            if leadIn.hasPrefix("let me ") {
                let candidateNarrationMarkers = [
                    " i ", " i'm ", " im ", " i've ", " ive ",
                    " my ", " we ", " our ", " in my ", " in our "
                ]
                if candidateNarrationMarkers.contains(where: { normalized.contains($0) }) {
                    return true
                }
            } else {
                return true
            }
        }

        if signal.protectsFromSkip {
            let interviewerReasonMarkers = [
                "direct_question", "request", "question_language_marker",
                "comparison", "follow_up", "short_technical_prompt"
            ]
            if signal.reasons.contains(where: { interviewerReasonMarkers.contains($0) }) {
                return false
            }
        }

        return true
    }

    private func shouldTreatLocalSignalAsClearQuestion(_ text: String, signal: QuestionSignal) -> Bool {
        signal.protectsFromSkip && !shouldVetoQuestionAsCandidateStatement(text, signal: signal)
    }

    /// Topics that must always defer to the authoritative model path because the
    /// status is ambiguous or a good answer needs multi-turn conversation context.
    private static let provisionalDeferredTopics: Set<String> = ["followup", "unknown", "none"]

    /// Concrete-enough topics that still need the candidate's background to answer
    /// well (personal / experience / project openers). These are eligible for the
    /// fast path only when a background is available; otherwise they defer so the
    /// model path runs and we never invent experience the candidate does not have.
    private static let backgroundDependentTopics: Set<String> = ["personal"]

    /// When the local signal alone is an unambiguous, complete, concrete-topic
    /// interviewer question, return the topic to answer immediately with the fast
    /// direct answer stream — putting useful text on the card without waiting for the
    /// slower authoritative classification. Returns nil to defer to the model path
    /// (ambiguous status, incomplete utterance, candidate statement, a topic that
    /// needs conversation context, or a personal question with no background).
    func provisionalAnswerTopic(for text: String, lastTopic: String?, hasBackground: Bool = false) -> String? {
        let signal = questionSignal(for: text, lastTopic: lastTopic)
        guard shouldTreatLocalSignalAsClearQuestion(text, signal: signal) else { return nil }
        guard !signal.isBareIncomplete, !isLocallyIncomplete(text) else { return nil }

        var topic = correctedTopic(for: text, classifiedTopic: signal.topicHint)
        if topic.lowercased() == "unknown", let hint = signal.topicHint {
            topic = hint
        }
        let topicLower = topic.lowercased()

        // Topics with no concrete subject of their own — vague follow-ups ("tell me more",
        // "can you elaborate", "go deeper") AND clear questions that local detection cannot
        // map to a named topic ("where do we start with?", "what should we expect?") — carry
        // no new topic. When a concrete prior topic exists, answer them immediately on that
        // topic via the fast path instead of waiting on the slow model path. This mirrors the
        // slow path, which already routes an unknown-topic question with prior context onto
        // the prior topic as a follow-up (see processAudioSegment); doing it here saves the
        // visible classify-then-answer round-trip (~580ms+) on the single most common kind of
        // real interview turn. The fast model still receives the verbatim question text, so a
        // contextual prior-topic hint does not blur what is actually being asked. Orphans
        // (no usable prior topic) still defer to the model path so we never answer a fresh
        // topicless question from stale context.
        if Self.provisionalDeferredTopics.contains(topicLower) {
            guard let priorTopic = lastTopic,
                  !Self.provisionalDeferredTopics.contains(priorTopic.lowercased()),
                  !Self.backgroundDependentTopics.contains(priorTopic.lowercased()) else { return nil }
            return priorTopic
        }

        if Self.backgroundDependentTopics.contains(topicLower) {
            return hasBackground ? topic : nil
        }
        return topic
    }

    // MARK: - Main Processing Pipeline

    /// Process an audio segment through the full pipeline
    func processAudioSegment(_ audioData: Data, source: AudioSource) {
        let turnID = UUID()
        let turnSequence = reserveTurnSequence()
        let sourceLabel = source == .microphone ? "🎤 MIC" : "🔊 SYS"
        debugLog(.audio, "\(sourceLabel) processAudioSegment called with \(audioData.count) bytes")
        guard SpeechTurnPolicy.startsAnswerCard(SpeechTurnPolicy.action(for: .finalSilence)) else {
            debugLog(.error, "SpeechTurnPolicy blocked answer commit")
            return
        }
        guard let client = groqClient else {
            debugLog(.error, "groqClient is nil!")
            return
        }
        debugLog(.audio, "groqClient configured: \(client)")

        let turnSnapshot = withTurnLock { (turnGeneration, previewTask, previewGeneration) }
        let generation = turnSnapshot.0
        let previewForTurn = turnSnapshot.1
        let previewGenerationForTurn = turnSnapshot.2

        let task = Task { [self] in
            defer { finishProcessTask(turnID) }
            do {
                // 1. Transcribe audio + warmup Anthropic connection in parallel
                await MainActor.run { delegate?.processorShowLoading("🎙️ Transcribing...", color: .systemBlue, turnID: turnID) }
                debugLog(.transcription, "Sending \(audioData.count) bytes to Groq...")

                Task {
                    await client.warmupConnection()
                    await anthropicClient?.warmupConnection()
                }

                await previewForTurn?.value

                let transcription: String
                let sttLatency: Double
                if let cached = cachedPreviewTranscript(matching: audioData, generation: previewGenerationForTurn) {
                    transcription = cached
                    sttLatency = 0
                    debugLog(.transcription, "Reusing preview STT (0ms): '\(transcription)'")
                } else {
                    let result = try await transcribeWithTimeout(client: client, audioData: audioData)
                    transcription = result.text
                    sttLatency = result.latencyMs
                    debugLog(.transcription, "Result (\(Int(sttLatency))ms): '\(transcription)'")
                }
                guard isCurrentTurn(generation) else {
                    debugLog(.audio, "PROCESS: dropped stale turn after STT")
                    return
                }

                // Per-turn latency anchor; rapid turns must not overwrite each other.
                let questionEndTime = Date()

                let rawTrimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmed = repairNoisyTechnicalTranscript(rawTrimmed)
                if trimmed != rawTrimmed {
                    debugLog(.transcription, "Repaired noisy AI transcript: '\(rawTrimmed)' -> '\(trimmed)'")
                }
                guard !trimmed.isEmpty else {
                    NSLog("⚠️ PROCESS: SKIPPED - Empty transcription after trimming")
                    await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                    return
                }

                // Deduplication check - skip if similar text was just processed
                let initialSignal = questionSignal(for: trimmed, lastTopic: delegate?.conversationContext.lastTopic)
                if initialSignal.protectsFromSkip {
                    NSLog("🧭 SIGNAL: score=%d reasons=%@ topic=%@", initialSignal.score, initialSignal.reasons.joined(separator: ","), initialSignal.topicHint ?? "nil")
                }

                if isDuplicateTranscription(trimmed, source: source, signal: initialSignal) {
                    NSLog("🔄 PROCESS: SKIPPED - Duplicate transcription")
                    await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                    return
                }

                NSLog("📝 PROCESS: Trimmed text (%d chars): '%@'", trimmed.count, trimmed)

                // Filter Whisper hallucinations (common artifacts from silence/noise)
                if isWhisperHallucination(trimmed) {
                    NSLog("👻 PROCESS: SKIPPED - Whisper hallucination: '%@'", trimmed)
                    print("👻 Whisper hallucination filtered: \(trimmed)")
                    await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                    return
                }

                // Filter non-ASCII garbage when language is English
                if AppSettings.shared.listeningLanguage == .english {
                    let nonAsciiCount = trimmed.unicodeScalars.filter { !$0.isASCII }.count
                    let nonAsciiRatio = Float(nonAsciiCount) / Float(max(trimmed.count, 1))
                    if nonAsciiRatio > 0.15 && nonAsciiCount > 3 && !initialSignal.protectsFromSkip {
                        NSLog("👻 PROCESS: SKIPPED - Non-ASCII garbage (%.0f%% non-ASCII): '%@'", nonAsciiRatio * 100, trimmed)
                        print("👻 Non-ASCII hallucination filtered (\(Int(nonAsciiRatio * 100))% non-ASCII): \(trimmed)")
                        await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                        return
                    }
                }

                // Filter very short transcriptions (likely noise)
                if trimmed.count < 5 && !trimmed.contains("?") && !initialSignal.protectsFromSkip {
                    NSLog("👻 PROCESS: SKIPPED - Too short (%d chars), no '?': '%@'", trimmed.count, trimmed)
                    print("👻 Too short, likely noise: \(trimmed)")
                    await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                    return
                }

                NSLog("✅ PROCESS: Passed hallucination/length filters, proceeding...")

                // MICROPHONE = YOUR VOICE → Show directly as user response
                if source == .microphone {
                    NSLog("🎤 PROCESS: Mic audio - showing as user response directly")
                    print("🎤 [you] \(trimmed)")
                    await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                    withProcessingStateLock {
                        delegate?.conversationContext.addUtterance(
                            text: trimmed,
                            topic: delegate?.conversationContext.lastTopic ?? "unknown"
                        )
                    }
                    return
                }

                // SYSTEM AUDIO = INTERVIEWER → Classify and potentially generate answer
                debugLog(.classification, "System audio - checking filters...")

                if shouldSkipAsFillerOrGreeting(trimmed) || shouldSkipAsSocialPleasantry(trimmed) {
                    await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                    return
                }

                // Skip very short utterances (< 4 chars and no question mark)
                let normalizedText = trimmed.lowercased().trimmingCharacters(in: .whitespaces)
                if normalizedText.count < 4 && !normalizedText.contains("?") && !initialSignal.protectsFromSkip {
                    NSLog("⚡ PROCESS: LOCAL SKIP - Too short: '%@'", trimmed)
                    await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                    return
                }

                let bufferStateSnapshot = withProcessingStateLock { () -> (text: String, sequence: Int?) in
                    if let timestamp = bufferTimestamp,
                       !utteranceBuffer.isEmpty,
                       Date().timeIntervalSince(timestamp) > bufferTimeout {
                        NSLog("📦 PROCESS: Clearing stale buffer before classification: '%@'", utteranceBuffer)
                        utteranceBuffer = ""
                        bufferTimestamp = nil
                        utteranceBufferSequence = nil
                    }
                    guard utteranceBufferSequence == turnSequence - 1 else { return ("", nil) }
                    return (utteranceBuffer, utteranceBufferSequence)
                }
                let bufferSnapshot = bufferStateSnapshot.text
                let bufferSnapshotSequence = bufferStateSnapshot.sequence

                debugLog(.classification, "Proceeding to classification...")

                // Haiku 4.5 is the authoritative fallback path for ambiguous turns.
                // Do not add a separate model preclassification call here: clear questions
                // are routed locally into the direct answer stream, and ambiguous turns
                // are cheaper and faster as one combined classify+answer stream.
                guard let haiku = anthropicClient else {
                    debugLog(.error, "anthropicClient is nil!")
                    await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                    return
                }
                debugLog(.classification, "anthropicClient configured: \(haiku)")

                // Local buffering removed - LLM classification handles incomplete detection

                await MainActor.run { delegate?.processorShowLoading("🔍 Analyzing...", color: .applePurple, turnID: turnID) }

                // Get context for the combined call
                var userBackground = await MainActor.run { delegate?.userBackground ?? "" }
                let pinnedSolution = delegate?.pinnedSolution
                guard let context = delegate?.conversationContext else {
                    await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                    return
                }

                // Inject memory context from past sessions
                let lastTopic = withProcessingStateLock { context.lastTopic }
                let memoryTopics = [lastTopic].compactMap { $0 }
                if let memoryContext = memoryRetrieval.retrieve(forTopics: memoryTopics) {
                    userBackground = userBackground.isEmpty ? memoryContext : "\(userBackground)\n\n\(memoryContext)"
                }

                // FAST ANSWER PATH: a strong, complete, concrete-topic local
                // question streams an answer immediately, so useful text reaches
                // the card without waiting for the STATUS/--- classifier parser.
                // Groq is tried first for lower first-token latency; Haiku remains
                // the quality fallback if Groq emits nothing.
                guard isCurrentTurn(generation) else {
                    debugLog(.audio, "PROCESS: dropped stale turn before answer")
                    return
                }

                if bufferSnapshot.isEmpty,
                   let provisionalTopic = provisionalAnswerTopic(for: trimmed, lastTopic: lastTopic, hasBackground: !userBackground.isEmpty) {
                    debugLog(.answer, "⚡ FAST GROQ PATH: answer-only stream for topic='\(provisionalTopic)'")
                    let groqHandled = await streamProvisionalAnswer(
                        text: trimmed,
                        topic: provisionalTopic,
                        groqClient: client,
                        userBackground: userBackground,
                        context: context,
                        turnID: turnID,
                        turnSequence: turnSequence,
                        turnGeneration: generation,
                        questionEndTime: questionEndTime
                    )
                    if groqHandled {
                        await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                        return
                    }

                    debugLog(.answer, "⚡ FAST GROQ PATH: no visible text, trying direct Haiku fallback")
                    let haikuHandled = await streamDirectHaikuAnswer(
                        text: trimmed,
                        topic: provisionalTopic,
                        haiku: haiku,
                        userBackground: userBackground,
                        context: context,
                        pinnedSolution: pinnedSolution,
                        turnID: turnID,
                        turnSequence: turnSequence,
                        turnGeneration: generation,
                        questionEndTime: questionEndTime
                    )
                    if haikuHandled {
                        await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                        return
                    }

                    debugLog(.answer, "⚡ FAST PATH: yielded nothing, falling back to Haiku classifier")
                }

                // Build multi-turn messages (limited to recent context)
                let messagesForAPI = withProcessingStateLock {
                    let multiTurnMessages = context.buildMultiTurnMessages(
                        currentUtterance: trimmed,
                        pinnedSolution: pinnedSolution
                    )
                    return context.messagesToAPIFormat(multiTurnMessages)
                }

                // State for handling classification result
                var shouldStreamAnswer = false
                var detectedTopic: String = "unknown"
                var messageType: InterviewMessage.MessageType = .answer
                var fullText = ""
                let turnStreamState = AnswerStreamState()

                let startTime = Date()

                let result = await haiku.classifyAndStreamAnswer(
                    transcription: trimmed,
                    buffer: bufferSnapshot,
                    lastTopic: lastTopic,
                    userBackground: userBackground.isEmpty ? nil : userBackground,
                    multiTurnMessages: messagesForAPI,
                    onClassification: { [weak self] classification in
                        guard let self = self else { return }
                        guard isCurrentTurn(generation) else { return }
                        processingStateLock.lock()
                        defer { processingStateLock.unlock() }
                        guard isCurrentTurn(generation) else { return }
                        let latency = Date().timeIntervalSince(startTime) * 1000
                        debugLog(.classification, "Result (\(Int(latency))ms): status='\(classification.status)', topic='\(classification.topic ?? "nil")'")

                        // Handle filler words
                        if classification.status == "filler" {
                            if initialSignal.protectsFromSkip {
                                NSLog("⚠️ PROCESS: OVERRIDE - Strong local signal despite filler status (%@)", initialSignal.reasons.joined(separator: ","))
                            } else {
                                NSLog("🗣️ PROCESS: SKIPPED - Filler word detected: '%@'", trimmed)
                                return
                            }
                        }

                        // Comma-ending override
                        let combinedForCheck = bufferSnapshot.isEmpty ? trimmed : "\(bufferSnapshot) \(trimmed)"
                        let endsWithComma = combinedForCheck.trimmingCharacters(in: .whitespaces).hasSuffix(",")
                        let combinedSignal = questionSignal(for: combinedForCheck, lastTopic: context.lastTopic)
                        if classification.status == "question" && endsWithComma && !combinedSignal.protectsFromSkip {
                            NSLog("⚠️ PROCESS: OVERRIDE - Ends with comma, treating as incomplete")
                            if utteranceBufferSequence == nil || turnSequence >= utteranceBufferSequence! {
                                utteranceBuffer = combinedForCheck
                                bufferTimestamp = Date()
                                utteranceBufferSequence = turnSequence
                            }
                            return
                        }

                        // Complete utterance
                        fullText = bufferSnapshot.isEmpty ? trimmed : "\(bufferSnapshot) \(trimmed)"
                        if let bufferSnapshotSequence,
                           utteranceBufferSequence == bufferSnapshotSequence {
                            utteranceBuffer = ""
                            bufferTimestamp = nil
                            utteranceBufferSequence = nil
                        }
                        let localSignal = questionSignal(for: fullText, lastTopic: context.lastTopic)
                        let hasClearQuestionMarker = shouldTreatLocalSignalAsClearQuestion(fullText, signal: localSignal)
                        let shouldBufferLocalIncomplete = localSignal.isBareIncomplete || isLocallyIncomplete(fullText)
                        detectedTopic = correctedTopic(for: fullText, classifiedTopic: classification.topic)
                        if detectedTopic.lowercased() == "unknown", let topicHint = localSignal.topicHint {
                            detectedTopic = topicHint
                        }

                        if classification.status == "question" && shouldBufferLocalIncomplete {
                            if utteranceBufferSequence == nil || turnSequence >= utteranceBufferSequence! {
                                utteranceBuffer = fullText
                                bufferTimestamp = Date()
                                utteranceBufferSequence = turnSequence
                            }
                            NSLog("📦 PROCESS: BUFFERED - Locally incomplete question")
                            return
                        }

                        if classification.status == "question" && shouldVetoQuestionAsCandidateStatement(fullText, signal: localSignal) {
                            NSLog("🔊 PROCESS: SKIPPED - Candidate-style explanation, not interviewer question: '%@'", fullText)
                            context.addUtterance(text: fullText, topic: detectedTopic, sequence: turnSequence)
                            return
                        }

                        if classification.status == "incomplete" && hasClearQuestionMarker {
                            NSLog("⚠️ PROCESS: OVERRIDE - Clear question signal despite incomplete status (%@)", localSignal.reasons.joined(separator: ","))
                        } else if classification.status == "incomplete" {
                            if utteranceBufferSequence == nil || turnSequence >= utteranceBufferSequence! {
                                utteranceBuffer = fullText
                                bufferTimestamp = Date()
                                utteranceBufferSequence = turnSequence
                            }
                            NSLog("📦 PROCESS: BUFFERED - Incomplete utterance")
                            return
                        }

                        // Promote short Bulgarian/mixed technical prompts that Whisper transcribes without a question mark.
                        if classification.status == "answer" || classification.status == "statement" {
                            if hasClearQuestionMarker {
                                NSLog("⚠️ PROCESS: OVERRIDE - Clear question signal despite status '%@' (%@)", classification.status, localSignal.reasons.joined(separator: ","))
                            } else {
                                NSLog("🔊 PROCESS: Interviewer statement (not a question)")
                                context.addUtterance(text: fullText, topic: detectedTopic, sequence: turnSequence)
                                return
                            }
                        }

                        // Check cooldown - only skip if within cooldown AND no clear question markers
                        if let lastAnswer = lastAnswerTime {
                            let elapsed = Date().timeIntervalSince(lastAnswer)
                            if elapsed < answerCooldown {
                                let isClearQuestion = hasClearQuestionMarker
                                if !isClearQuestion {
                                    NSLog("⏸️ PROCESS: SKIPPED - Cooldown active, no question markers")
                                    context.addUtterance(text: fullText, topic: detectedTopic, sequence: turnSequence)
                                    return
                                }
                            }
                        }

                        // Determine message type based on topic
                        let topicLower = detectedTopic.lowercased()
                        if topicLower == "followup" && context.lastTopic != nil {
                            messageType = .followUp
                            detectedTopic = context.lastTopic!
                        } else if topicLower == "followup" && context.lastTopic == nil {
                            // Orphan follow-up with no prior context - treat as new question
                            detectedTopic = "unknown"
                        } else if topicLower == "unknown", let lastTopic = context.lastTopic {
                            // Unknown topic but we have prior context - treat as follow-up
                            messageType = .followUp
                            detectedTopic = lastTopic
                        }

                        // All checks passed - enable answer streaming
                        debugLog(.answer, "✅ Passed all filters! Will stream answer for topic='\(detectedTopic)'")
                        shouldStreamAnswer = true

                        // Card-start timing is diagnostic only; the UI shows completed-answer time.
                        let cardStartLatencyMs = Int(Date().timeIntervalSince(questionEndTime) * 1000)

                        // Update context and UI on main thread
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            guard isCurrentTurn(generation) else { return }
                            debugLog(.delegate, "Calling processorDidReceiveQuestion for '\(fullText.prefix(50))...'")
                            delegate?.processorShowLoading("💭 Generating answer...", color: .appleGreen, turnID: turnID)
                            delegate?.processorDidReceiveQuestion(fullText, topic: detectedTopic, messageType: messageType, source: .systemAudio, turnID: turnID, sequence: turnSequence)
                            debugLog(.delegate, "Calling processorDidStartStreaming with cardStart=\(cardStartLatencyMs)ms")
                            delegate?.processorDidStartStreaming(messageType: messageType, topic: detectedTopic, latencyMs: cardStartLatencyMs, turnID: turnID, sequence: turnSequence)
                        }

                        context.addUtterance(text: fullText, topic: detectedTopic, isQuestion: true, sequence: turnSequence)
                        lastAnswerTime = Date()
                    },
                    onAnswerChunk: { [weak self] chunk in
                        guard let self = self else { return }
                        guard isCurrentTurn(generation) else { return }
                        guard shouldStreamAnswer else { return }
                        guard let update = turnStreamState.appendVisibleChunk(chunk) else { return }
                        let snapshot = update.snapshot
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            guard isCurrentTurn(generation) else { return }
                            if snapshot.count < 100 || snapshot.count % 200 == 0 {
                                debugLog(.stream, "Chunk received, total: \(snapshot.count) chars")
                            }
                            delegate?.processorDidReceiveAnswerChunk(self.stripInlineMarkdownForCueCard(snapshot), turnID: turnID)
                        }
                    }
                )

                debugLog(.answer, "classifyAndStreamAnswer returned, shouldStreamAnswer=\(shouldStreamAnswer)")

                guard isCurrentTurn(generation), !Task.isCancelled else {
                    turnStreamState.cancel()
                    await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
                    return
                }

                let totalLatency = Date().timeIntervalSince(startTime) * 1000

                switch result {
                case .success:
                    debugLog(.answer, "Result: SUCCESS")
                    if shouldStreamAnswer {
                        let rawAnswer = turnStreamState.text
                        guard !rawAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            await MainActor.run {
                                delegate?.processorDidReceiveAnswerChunk("Error: No answer text received", turnID: turnID)
                                delegate?.processorHideLoading(turnID: turnID)
                            }
                            return
                        }
                        debugLog(.answer, "Answer complete (\(Int(totalLatency))ms), \(rawAnswer.count) chars")
                        debugLog(.delegate, "Calling processorDidFinishAnswer")
                        // Total time from question end to fully-streamed answer (not just time-to-card)
                        let answerLatencyMs = Int(Date().timeIntervalSince(questionEndTime) * 1000)
                        let cleanedAnswer = conversationalDisplayAnswer(rawAnswer)
                        await MainActor.run {
                            if cleanedAnswer != rawAnswer {
                                delegate?.processorDidReceiveAnswerChunk(cleanedAnswer, turnID: turnID)
                            }
                            delegate?.processorDidFinishAnswer(cleanedAnswer, totalLatencyMs: answerLatencyMs, turnID: turnID)
                        }

                        scheduleSummarizationIfNeeded(context: context, generation: generation)
                    }
                case .failure(let error):
                    debugLog(.error, "Combined call FAILED: \(error)")
                    if shouldStreamAnswer {
                        await MainActor.run { delegate?.processorDidReceiveAnswerChunk("Error: \(error.localizedDescription)", turnID: turnID) }
                    }
                }

                await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }

            } catch {
                let message = userFacingProcessingError(error)
                debugLog(.error, "Error processing audio: \(error.localizedDescription)")
                await MainActor.run {
                    delegate?.processorHideLoading(turnID: turnID)
                    delegate?.processorDidUpdateStatus(message)
                }
            }
        }

        turnLock.lock()
        processTasks[turnID] = task
        turnLock.unlock()
    }

    private func finishProcessTask(_ turnID: UUID) {
        turnLock.lock()
        processTasks.removeValue(forKey: turnID)
        turnLock.unlock()
    }

    // MARK: - Private Helpers

    private func transcribeWithTimeout(client: GroqInterviewClient, audioData: Data) async throws -> (text: String, latencyMs: Double) {
        try Task.checkCancellation()
        return try await withThrowingTaskGroup(of: (String, Double).self) { group in
            group.addTask {
                try Task.checkCancellation()
                return try await client.transcribe(audioData: audioData)
            }

            group.addTask { [transcriptionTimeout] in
                try await Task.sleep(nanoseconds: UInt64(transcriptionTimeout * 1_000_000_000))
                throw ProcessingError.transcriptionTimeout(transcriptionTimeout)
            }

            guard let result = try await group.next() else {
                throw ProcessingError.transcriptionTimeout(transcriptionTimeout)
            }

            group.cancelAll()
            return (text: result.0, latencyMs: result.1)
        }
    }

    private func userFacingProcessingError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "Error: Groq transcription network issue. Check connection and try again."
        }
        if nsError.domain == "GroqClient" {
            return "Error: Groq transcription failed: \(error.localizedDescription)"
        }
        return "Error: \(error.localizedDescription)"
    }

    private func correctedTopic(for text: String, classifiedTopic: String?) -> String {
        let normalized = text.lowercased()
        let topic = classifiedTopic?.isEmpty == false ? classifiedTopic! : "unknown"
        let topicLower = topic.lowercased()

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

        if topicLower == "unknown" || topicLower == "none" {
            let normalizedForSignal = normalizedQuestionText(text)
            let localTokens = technicalQuestionTokens(in: normalizedForSignal)
            if isVagueFollowUpPrompt(normalizedForSignal, technicalTokens: localTokens) {
                return "followUp"
            }
            if let topicHint = bestTopicHint(from: normalizedForSignal, technicalTokens: localTokens) {
                return topicHint
            }
        }

        return topic
    }

    /// Remove common model section labels so the final answer reads like something the candidate can say.
    private func conversationalDisplayAnswer(_ answer: String) -> String {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        guard !trimmed.contains("```") else { return trimmed }

        var cueItems: [String] = []
        for rawLine in trimmed.components(separatedBy: .newlines) {
            let cleaned = cleanConversationalLine(rawLine)
            guard !cleaned.isEmpty else { continue }
            let unbulleted = stripCueMarker(from: cleaned)
            cueItems.append(contentsOf: cueFragments(from: unbulleted))
        }

        var uniqueItems: [String] = []
        var seen = Set<String>()
        for item in cueItems {
            let compact = compactCueLine(item)
            guard !compact.isEmpty else { continue }
            let key = compact.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            uniqueItems.append(compact)
            if uniqueItems.count == 5 { break }
        }

        guard !uniqueItems.isEmpty else { return trimmed }
        return uniqueItems.map { "- \($0)" }.joined(separator: "\n")
    }

    private func cleanConversationalLine(_ line: String) -> String {
        var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        var marker = ""
        if cleaned.hasPrefix("- ") || cleaned.hasPrefix("* ") {
            marker = String(cleaned.prefix(2))
            cleaned = String(cleaned.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        } else if cleaned.count > 3,
                  let first = cleaned.first,
                  first.isNumber,
                  cleaned.dropFirst().hasPrefix(". ") {
            marker = "- "
            cleaned = String(cleaned.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }

        cleaned = stripInlineMarkdownForCueCard(cleaned)
        let withoutBold = cleaned
        let lowerWithoutBold = withoutBold.lowercased()
        let discardableIntroPrefixes = [
            "sure, here's", "sure here's", "here's a concise", "here is a concise",
            "here are", "of course", "absolutely"
        ]
        if discardableIntroPrefixes.contains(where: { lowerWithoutBold.hasPrefix($0) }) &&
            (lowerWithoutBold.contains("answer") ||
             lowerWithoutBold.contains("bullet") ||
             lowerWithoutBold.contains("cue")) {
            if let inlineCueTail = inlineCueTail(in: withoutBold) {
                return inlineCueTail
            }
            return ""
        }

        let answerLeadInPrefixes = [
            "i would answer it as:", "i'd answer it as:", "id answer it as:",
            "i would say:", "i'd say:", "id say:",
            "my answer would be:",
            "for this one, i would say:", "for this one, i'd say:", "for this one, id say:"
        ]
        for prefix in answerLeadInPrefixes where lowerWithoutBold.hasPrefix(prefix) {
            cleaned = String(withoutBold.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            break
        }

        let softLeadInPatterns = [
            #"^(for this one,\s*)?i would say\s+(?=[a-z0-9])"#,
            #"^(for this one,\s*)?i'd say\s+(?=[a-z0-9])"#,
            #"^(for this one,\s*)?id say\s+(?=[a-z0-9])"#,
            #"^i would answer it as\s+(?=[a-z0-9])"#,
            #"^my answer would be\s+(?=[a-z0-9])"#
        ]
        for pattern in softLeadInPatterns
            where cleaned.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
            cleaned = cleaned
                .replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespaces)
            break
        }

        let headingPrefixes = [
            "definition:", "key point:", "key points:", "gotcha:", "senior tip:",
            "answer:", "short answer:", "direct answer:", "summary:",
            "approach:", "trade-off:", "tradeoff:", "example:", "for example:"
        ]

        for prefix in headingPrefixes {
            if withoutBold.lowercased().hasPrefix(prefix) {
                cleaned = String(withoutBold.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        guard !cleaned.isEmpty else { return "" }
        return marker + cleaned
    }

    private func inlineCueTail(in text: String) -> String? {
        let markerPatterns = [
            #"\s+[-*]\s+"#,
            #"\s+\d+\.\s+"#
        ]

        for pattern in markerPatterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                var start = range.lowerBound
                while start < text.endIndex && text[start].isWhitespace {
                    start = text.index(after: start)
                }
                let tail = String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return tail.isEmpty ? nil : tail
            }
        }

        return nil
    }

    private func stripInlineMarkdownForCueCard(_ text: String) -> String {
        var cleaned = text
        cleaned = cleaned.replacingOccurrences(
            of: #"\*\*([A-Za-z])\*\*([A-Za-z]+)"#,
            with: "$1 - $1$2",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\b([A-Za-z])\*\*\s*"#,
            with: "$1 - ",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\*\*([^*]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "__", with: "")
        cleaned = cleaned.replacingOccurrences(
            of: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#,
            with: "$1",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripCueMarker(from line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("- ") || text.hasPrefix("* ") {
            text = String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        } else if text.count > 3,
                  let first = text.first,
                  first.isNumber,
                  text.dropFirst().hasPrefix(". ") {
            text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }
        return text
    }

    private func cueFragments(from text: String) -> [String] {
        let marker = "\u{1E}"
        let acronymLock = "\u{1F}"
        let lockedAcronyms = text.replacingOccurrences(
            of: #"\b([A-Za-z]) - "#,
            with: "$1\(acronymLock)",
            options: .regularExpression
        )
        let prepared = lockedAcronyms
            .replacingOccurrences(of: #"\s+[-*]\s+"#, with: marker, options: .regularExpression)
            .replacingOccurrences(of: #"\s+\d+\.\s+"#, with: marker, options: .regularExpression)
            .replacingOccurrences(of: #"\s+/\s+"#, with: marker, options: .regularExpression)
            .replacingOccurrences(of: "—", with: ". ")
            .replacingOccurrences(of: " - ", with: ". ")
            .replacingOccurrences(of: acronymLock, with: " - ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prepared.isEmpty else { return [] }

        return prepared
            .replacingOccurrences(of: #";\s+"#, with: marker, options: .regularExpression)
            .replacingOccurrences(of: #"(?<=[.!?])\s+"#, with: marker, options: .regularExpression)
            .components(separatedBy: marker)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap(splitLongCommaCueFragment)
            .filter { !$0.isEmpty }
    }

    private func splitLongCommaCueFragment(_ text: String) -> [String] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 140 else { return [cleaned] }

        let marker = "\u{1E}"
        let splitPattern = #",\s+(?=(?:and\s+)?(?:i|we|then|also|use|set|keep|review|report|focus|make|start|build|write|run|debug|validate|separate)\b)"#
        let splitText = cleaned.replacingOccurrences(
            of: splitPattern,
            with: marker,
            options: [.regularExpression, .caseInsensitive]
        )
        let parts = splitText
            .components(separatedBy: marker)
            .map { part -> String in
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.lowercased().hasPrefix("and ")
                    ? String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                    : trimmed
            }
            .filter { !$0.isEmpty }

        return parts.count >= 2 ? parts : [cleaned]
    }

    private func compactCueLine(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-*")))
        guard !cleaned.isEmpty else { return "" }

        let maxCharacters = 120
        guard cleaned.count > maxCharacters else { return cleaned }

        let limitIndex = cleaned.index(cleaned.startIndex, offsetBy: maxCharacters)
        let head = String(cleaned[..<limitIndex])
        let separators = [",", ";", " because ", " so ", " and ", " with "]
        for separator in separators {
            if let range = head.range(of: separator, options: .backwards),
               head.distance(from: head.startIndex, to: range.lowerBound) >= 55 {
                let shortened = String(head[..<range.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return shortened.hasSuffix(".") ? shortened : "\(shortened)."
            }
        }

        let shortened = head.trimmingCharacters(in: .whitespacesAndNewlines)
        return shortened.hasSuffix(".") ? shortened : "\(shortened)..."
    }

    /// Check if text is a Whisper hallucination
    private func isWhisperHallucination(_ trimmed: String) -> Bool {
        let whisperHallucinations = [
            // YouTube-style outros
            "thank you", "thank you for watching", "thank you for listening",
            "thanks", "thanks for watching", "thanks for listening",
            "please subscribe", "like and subscribe", "see you next time",
            "bye", "goodbye", "bye bye", "bye-bye", "take care",
            "see you", "see you later", "see you soon",
            // Filler/noise
            "you", "the end", "so", "okay", "ok", "right",
            "hmm", "hm", "um", "uh", "ah", "oh", "mhm", "uh-huh",
            // Media artifacts
            "music", "applause", "laughter", "silence", "crickets",
            "[music]", "[applause]", "[laughter]", "[silence]",
            "(music)", "(applause)", "(laughter)", "(silence)",
            // Attribution
            "subtitles by", "captions by", "translated by",
            // German
            "danke", "danke fürs zuschauen", "abonnieren", "abonniert", "tschüss", "auf wiedersehen", "bis bald",
            // Spanish
            "gracias", "gracias por ver", "suscríbete", "suscribirse", "adiós", "hasta luego", "hasta pronto",
            // French
            "merci", "merci d'avoir regardé", "abonnez-vous", "s'abonner", "au revoir", "à bientôt", "salut",
            // Italian
            "grazie", "grazie per la visione", "iscriviti", "iscrivetevi", "ciao", "arrivederci", "a presto",
            // Portuguese
            "obrigado", "obrigada", "inscreva-se", "se inscreva", "tchau", "adeus", "até logo", "até mais",
            // Bulgarian
            "благодаря", "благодаря ви", "абонирайте се", "абонирай се", "харесайте", "довиждане", "чао",
            // Russian
            "спасибо", "спасибо за просмотр", "подписывайтесь", "подпишитесь", "пока", "до свидания", "до скорого",
            // Chinese
            "谢谢", "谢谢观看", "订阅", "请订阅", "再见", "拜拜",
            "xièxiè", "dìngyuè", "zàijiàn",
            // Japanese
            "ありがとう", "ありがとうございます", "チャンネル登録", "登録", "さようなら", "バイバイ", "じゃね",
            // Korean
            "감사합니다", "구독", "구독해주세요", "좋아요", "안녕", "안녕하세요", "다음에 봐요"
        ]

        let lowerTrimmed = trimmed.lowercased()
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        return trimmed.count < 30 && whisperHallucinations.contains(where: { lowerTrimmed == $0 })
    }

    /// Check if text should be skipped as filler or greeting
    private func shouldSkipAsFillerOrGreeting(_ trimmed: String) -> Bool {
        let normalizedText = trimmed.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[.!?,']", with: "", options: .regularExpression)

        let greetingStarts = ["hello", "hi ", "hey ", "good morning", "good afternoon", "good evening", "welcome to"]
        let isGreeting = greetingStarts.contains { normalizedText.hasPrefix($0) }

        let fillerPatterns = ["thank you", "thanks", "yes sure", "yeah sure", "okay", "sure", "sounds good", "got it", "i see", "i understand", "alright"]
        let isFiller = fillerPatterns.contains { normalizedText.hasPrefix($0) || normalizedText == $0 }

        let questionWords = ["what", "how", "why", "when", "where", "which", "who", "can you", "could you", "would you", "tell me", "explain", "describe", "give me", "show me", "walk me"]
        let hasQuestionWord = questionWords.contains { normalizedText.contains($0) }

        if (isGreeting || isFiller) && normalizedText.count < 50 && !hasQuestionWord {
            NSLog("⚡ PROCESS: LOCAL SKIP - Greeting/filler: '%@'", trimmed)
            return true
        }

        return false
    }

    /// Check if text is locally incomplete (ends with common incomplete patterns)
    private func isLocallyIncomplete(_ trimmed: String) -> Bool {
        let textForCheck = trimmed.lowercased().trimmingCharacters(in: .whitespaces)
        let incompleteEndings = [" so", " and", " but", " the", " a", " an", " to", " of", " that", " if", " when", " is", " are", " have", " can", " will", " for", " with", " on", " in", " between", ","]
        let endsIncomplete = incompleteEndings.contains { textForCheck.hasSuffix($0) }
        let hasQuestionMark = textForCheck.contains("?")

        return endsIncomplete && !hasQuestionMark
    }

    // MARK: - Fast Quality Answer

    private func directHaikuAnswerPrompt(
        text: String,
        topic: String,
        userBackground: String,
        context: ConversationContext,
        pinnedSolution: String?
    ) -> String {
        let normalized = normalizedQuestionText(text)
        let isVagueFollowUp = isVagueFollowUpPrompt(normalized, technicalTokens: technicalQuestionTokens(in: normalized))

        let backgroundContext = !userBackground.isEmpty ? """

        CANDIDATE BACKGROUND:
        \(userBackground)
        Use this only for experience, project, strengths, or personal-example questions.

        """ : ""

        let followUpContext: String
        if isVagueFollowUp {
            let recentContext = context.getContextForLLM()
            followUpContext = recentContext == "No previous conversation." ? "" : """

            RECENT INTERVIEW CONTEXT:
            \(recentContext)
            Add a new angle or concrete example. Do not repeat the previous answer.

            """
        } else {
            followUpContext = ""
        }

        let pinnedContext = pinnedSolution.map { solution in
            """

            CURRENT PINNED CODING SOLUTION:
            \(solution)
            If the question relates to this solution, answer in that context.

            """
        } ?? ""

        let languageInstruction = AppSettings.shared.llmLanguageInstruction
        let topicGuidance = topicSpecificAnswerGuidance(for: topic)
        return """
        You are helping a candidate answer a live technical interview question.
        Start immediately with useful answer text. No intro, no labels, no clarification request.

        \(AppSettings.shared.interviewContext)
        \(AppSettings.shared.answerStyleInstruction)
        \(backgroundContext)\(followUpContext)\(pinnedContext)
        QUESTION: "\(text)"
        TOPIC: \(topic)
        \(topicGuidance)

        The transcript may contain speech-to-text errors. Trust TOPIC when words are garbled.
        Output 3-5 cue-card bullets only. Every line starts with "- ".
        Keep each bullet short enough to read while speaking.
        Plain text only. No markdown, no **bold**, no headings.
        For acronyms like SOLID, one bullet per letter as "S - Single Responsibility: ...".

        \(languageInstruction)
        """
    }

    private func topicSpecificAnswerGuidance(for topic: String) -> String {
        let topicLower = topic.lowercased()
        if topicLower == "solid" {
            return """

            SOLID ANSWER SHAPE:
            One bullet per letter. Plain text. Never write **S**ingle or S**.
            - S - Single Responsibility: one class, one reason to change
            - O - Open/Closed: extend without modifying existing code
            - L - Liskov Substitution: subtypes must replace their base type
            - I - Interface Segregation: many small interfaces, not one fat one
            - D - Dependency Inversion: depend on abstractions, not concretions
            """
        }
        guard topicLower == "rag" || topicLower == "cag" || topicLower == "ragcag" else {
            return ""
        }

        return """

        RAG/CAG ANSWER SHAPE:
        - First bullet: "RAG (Retrieval-Augmented Generation) means..."
        - Explain that docs, pages, PDFs, images, or video/audio transcripts are chunked and embedded.
        - Mention those embeddings are stored in a vector DB and searched semantically.
        - End with the LLM using retrieved chunks as context, plus one practical trade-off.
        - Avoid abstract-only wording like "combines a vector store with generation".
        """
    }

    /// Stream a direct answer-only Haiku response for a clear local question.
    /// The card is created only after the first visible answer chunk. If Haiku
    /// does not emit visible text quickly, cancel the visible path so the caller
    /// can use a backup stream without duplicate cards.
    private func streamDirectHaikuAnswer(
        text: String,
        topic: String,
        haiku: AnthropicClient,
        userBackground: String,
        context: ConversationContext,
        pinnedSolution: String?,
        turnID: UUID,
        turnSequence: Int,
        turnGeneration: Int,
        questionEndTime: Date
    ) async -> Bool {
        let startTime = Date()
        let normalized = normalizedQuestionText(text)
        let isVagueFollowUp = isVagueFollowUpPrompt(normalized, technicalTokens: technicalQuestionTokens(in: normalized))
        let messageType: InterviewMessage.MessageType = isVagueFollowUp ? .followUp : .answer
        let prompt = withProcessingStateLock {
            directHaikuAnswerPrompt(
                text: text,
                topic: topic,
                userBackground: userBackground,
                context: context,
                pinnedSolution: pinnedSolution
            )
        }
        let state = AnswerStreamState()

        let streamTask = Task { [weak self, state] in
            await haiku.streamTextMessage(prompt: prompt, maxTokens: AppConstants.MaxTokens.answerStream) { [weak self, state] chunk in
                guard let self = self,
                      self.isCurrentTurn(turnGeneration),
                      let update = state.appendVisibleChunk(chunk) else { return }

                if update.isFirst {
                    let committed = self.withProcessingStateLock { () -> Bool in
                        guard self.isCurrentTurn(turnGeneration) else { return false }
                        context.addUtterance(
                            text: text,
                            topic: topic,
                            isQuestion: true,
                            sequence: turnSequence
                        )
                        self.lastAnswerTime = Date()
                        return true
                    }
                    guard committed else { state.cancel(); return }
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    guard self.isCurrentTurn(turnGeneration) else { return }
                    if update.isFirst {
                        debugLog(.delegate, "Calling processorDidReceiveQuestion for '\(text.prefix(50))...'")
                        self.delegate?.processorDidReceiveQuestion(text, topic: topic, messageType: messageType, source: .systemAudio, turnID: turnID, sequence: turnSequence)
                        let cardStartLatencyMs = Int(Date().timeIntervalSince(questionEndTime) * 1000)
                        debugLog(.delegate, "Calling processorDidStartStreaming with cardStart=\(cardStartLatencyMs)ms")
                        self.delegate?.processorDidStartStreaming(messageType: messageType, topic: topic, latencyMs: cardStartLatencyMs, turnID: turnID, sequence: turnSequence)
                    }

                    if update.snapshot.count < 100 || update.snapshot.count % 200 == 0 {
                        debugLog(.stream, "Direct Haiku chunk received, total: \(update.snapshot.count) chars")
                    }
                    self.delegate?.processorDidReceiveAnswerChunk(self.stripInlineMarkdownForCueCard(update.snapshot), turnID: turnID)
                }
            }
        }

        let firstChunkTimeout = AppConstants.Thresholds.directHaikuFirstChunkTimeout
        while !state.hasStarted {
            guard isCurrentTurn(turnGeneration), !Task.isCancelled else {
                state.cancel()
                streamTask.cancel()
                return false
            }
            if Date().timeIntervalSince(startTime) >= firstChunkTimeout {
                state.cancel()
                streamTask.cancel()
                debugLog(.answer, "Direct Haiku first chunk timeout after \(Int(firstChunkTimeout * 1000))ms")
                return false
            }
            do {
                try await Task.sleep(nanoseconds: 50_000_000)
            } catch {
                state.cancel()
                streamTask.cancel()
                return false
            }
        }

        let result = await streamTask.value
        guard isCurrentTurn(turnGeneration), !Task.isCancelled else {
            state.cancel()
            return false
        }
        let accumulated = state.text
        let trimmedAnswer = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty else {
            if case .failure(let error) = result {
                debugLog(.error, "Direct Haiku answer produced no text: \(error.localizedDescription)")
            }
            return false
        }

        if case .failure(let error) = result {
            debugLog(.error, "Direct Haiku stream ended after visible text with error: \(error.localizedDescription)")
        }

        let answerLatencyMs = Int(Date().timeIntervalSince(questionEndTime) * 1000)
        let totalLatency = Date().timeIntervalSince(startTime) * 1000
        debugLog(.answer, "Direct Haiku answer complete (\(Int(totalLatency))ms), \(accumulated.count) chars")

        let cleaned = conversationalDisplayAnswer(accumulated)
        await MainActor.run {
            if cleaned != accumulated {
                self.delegate?.processorDidReceiveAnswerChunk(cleaned, turnID: turnID)
            }
            self.delegate?.processorDidFinishAnswer(cleaned, totalLatencyMs: answerLatencyMs, turnID: turnID)
        }

        scheduleSummarizationIfNeeded(context: context, generation: turnGeneration)

        return true
    }

    /// Stream a concise answer from the Groq backup model for a clear,
    /// concrete-topic local question. The question bubble and answer card are
    /// committed on the first chunk so the card appears already populated.
    /// Returns true if answer text was shown (turn handled); false if nothing was
    /// emitted, so the caller can fall back to the model path without a duplicate card.
    private func streamProvisionalAnswer(
        text: String,
        topic: String,
        groqClient: GroqInterviewClient,
        userBackground: String,
        context: ConversationContext,
        turnID: UUID,
        turnSequence: Int,
        turnGeneration: Int,
        questionEndTime: Date
    ) async -> Bool {
        let startTime = Date()
        let state = AnswerStreamState()

        // Vague follow-ups ("tell me more", "go deeper") resolve their topic from the
        // prior turn (see provisionalAnswerTopic). Tag them as follow-ups and pass the
        // recent conversation so the fast model adds new angles instead of repeating the
        // earlier answer. Concrete questions stay fresh answers with no extra context.
        let normalized = normalizedQuestionText(text)
        let isVagueFollowUp = isVagueFollowUpPrompt(normalized, technicalTokens: technicalQuestionTokens(in: normalized))
        let messageType: InterviewMessage.MessageType = isVagueFollowUp ? .followUp : .answer
        let followUpContext = withProcessingStateLock {
            isVagueFollowUp ? context.getContextForLLM() : nil
        }

        let result = await groqClient.streamAnswer(
            topic: topic,
            transcription: text,
            userBackground: userBackground.isEmpty ? nil : userBackground,
            context: followUpContext
        ) { chunk in
            guard self.isCurrentTurn(turnGeneration) else { return }
            guard let update = state.appendVisibleChunk(chunk) else { return }
            if update.isFirst {
                let committed = self.withProcessingStateLock { () -> Bool in
                    guard self.isCurrentTurn(turnGeneration) else { return false }
                    context.addUtterance(
                        text: text,
                        topic: topic,
                        isQuestion: true,
                        sequence: turnSequence
                    )
                    self.lastAnswerTime = Date()
                    return true
                }
                guard committed else { state.cancel(); return }
            }
            let snapshot = update.snapshot
            let isFirst = update.isFirst
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard self.isCurrentTurn(turnGeneration) else { return }
                if isFirst {
                    debugLog(.delegate, "Calling processorDidReceiveQuestion for '\(text.prefix(50))...'")
                    self.delegate?.processorDidReceiveQuestion(text, topic: topic, messageType: messageType, source: .systemAudio, turnID: turnID, sequence: turnSequence)
                    let cardStartLatencyMs = Int(Date().timeIntervalSince(questionEndTime) * 1000)
                    debugLog(.delegate, "Calling processorDidStartStreaming with cardStart=\(cardStartLatencyMs)ms")
                    self.delegate?.processorDidStartStreaming(messageType: messageType, topic: topic, latencyMs: cardStartLatencyMs, turnID: turnID, sequence: turnSequence)
                }
                if snapshot.count < 100 || snapshot.count % 200 == 0 {
                    debugLog(.stream, "Chunk received, total: \(snapshot.count) chars")
                }
                self.delegate?.processorDidReceiveAnswerChunk(self.stripInlineMarkdownForCueCard(snapshot), turnID: turnID)
            }
        }

        guard isCurrentTurn(turnGeneration), !Task.isCancelled else {
            state.cancel()
            return false
        }
        let accumulated = state.text
        let trimmedAnswer = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state.hasStarted, !trimmedAnswer.isEmpty else {
            if case .failure(let error) = result {
                debugLog(.error, "Provisional answer produced nothing, falling back: \(error.localizedDescription)")
            }
            return false
        }

        let answerLatencyMs = Int(Date().timeIntervalSince(questionEndTime) * 1000)
        let totalLatency = Date().timeIntervalSince(startTime) * 1000
        debugLog(.answer, "Answer complete (\(Int(totalLatency))ms), \(accumulated.count) chars")

        let cleaned = conversationalDisplayAnswer(accumulated)
        await MainActor.run {
            if cleaned != accumulated {
                self.delegate?.processorDidReceiveAnswerChunk(cleaned, turnID: turnID)
            }
            self.delegate?.processorDidFinishAnswer(cleaned, totalLatencyMs: answerLatencyMs, turnID: turnID)
        }

        scheduleSummarizationIfNeeded(context: context, generation: turnGeneration)

        return true
    }

    // MARK: - Standalone Answer Generation

    /// Generate answer using Haiku with streaming (for manual invocation)
    func streamAnswerWithHaiku(question: String, topic: String, messageType: InterviewMessage.MessageType) async {
        let turnID = UUID()
        let turnSequence = reserveTurnSequence()
        let generation = withTurnLock { turnGeneration }
        guard let haiku = anthropicClient else {
            NSLog("❌ Anthropic client not configured!")
            return
        }

        let userBackground = delegate?.userBackground ?? ""
        guard let context = delegate?.conversationContext else { return }

        var backgroundContext = !userBackground.isEmpty ? """
        YOUR BACKGROUND (use for personal questions like "tell me about yourself"):
        \(userBackground)

        """ : ""

        // Inject memory from past sessions
        if let memoryContext = memoryRetrieval.retrieve(forTopics: [topic]) {
            backgroundContext += "\(memoryContext)\n\n"
        }

        let conversationHistory = context.getFullConversation()
        let topicsSummary = context.getTopicsSummary()
        let historyContext = conversationHistory.isEmpty ? "" : """

        INTERVIEW SO FAR:
        \(conversationHistory)
        \(topicsSummary)

        """

        let pinnedContext = delegate?.pinnedSolution != nil ? """

        CURRENT CODING TASK SOLUTION (pinned above):
        \(delegate!.pinnedSolution!)

        If the question relates to this solution, answer in context of it.

        """ : ""

        let languageInstruction = AppSettings.shared.llmLanguageInstruction
        let prompt = """
        You are helping someone who is BEING INTERVIEWED for a software engineering position.
        They need quick, glanceable answers to help them respond to the interviewer.

        \(AppSettings.shared.interviewContext)

        \(AppSettings.shared.answerStyleInstruction)

        \(backgroundContext)\(historyContext)\(pinnedContext)CURRENT QUESTION: "\(question)"
        Topic: \(topic)

        SPEECH-TO-TEXT: The question text is from voice transcription and may contain errors.
        ALWAYS answer about the Topic shown above. Ignore garbled words.
        Example: "What is key developer?" with Topic: hashmap → Answer about HashMap keys.

        FORBIDDEN PHRASES (never use these):
        - "doesn't exist", "you might mean", "you might be thinking of"
        - "ask them to clarify", "could you clarify", "did you mean"
        - "I think you're asking about", "possible intended question"

        Just answer the topic directly and confidently.

        FORMAT (pick best for quick scanning):
        - Comparisons: X: [brief] | Y: [brief]
        - Definitions: one sentence + 1-3 bullets
        - Code: `command` + one line why

        \(languageInstruction)
        """

        // Create empty streaming message on main thread
        await MainActor.run {
            delegate?.processorShowLoading("💭 Generating answer...", color: .appleGreen, turnID: turnID)
            delegate?.processorDidReceiveQuestion(question, topic: topic, messageType: messageType, source: .systemAudio, turnID: turnID, sequence: turnSequence)
            delegate?.processorDidStartStreaming(messageType: messageType, topic: topic, latencyMs: nil, turnID: turnID, sequence: turnSequence)
        }

        let startTime = Date()
        let manualState = AnswerStreamState()

        let result = await haiku.streamTextMessage(prompt: prompt, maxTokens: AppConstants.MaxTokens.answerStream) { [weak self] chunk in
            guard let self = self,
                  self.isCurrentTurn(generation),
                  let update = manualState.appendVisibleChunk(chunk) else { return }
            let snapshot = update.snapshot
            DispatchQueue.main.async {
                guard self.isCurrentTurn(generation) else { return }
                self.delegate?.processorDidReceiveAnswerChunk(self.stripInlineMarkdownForCueCard(snapshot), turnID: turnID)
            }
        }

        let latency = Date().timeIntervalSince(startTime) * 1000
        guard isCurrentTurn(generation), !Task.isCancelled else {
            manualState.cancel()
            await MainActor.run { delegate?.processorHideLoading(turnID: turnID) }
            return
        }
        let manualStreamingContent = manualState.text

        switch result {
        case .success:
            print("💡 Answer (Haiku \(Int(latency))ms): \(manualStreamingContent.prefix(100))...")
            let cleanedAnswer = conversationalDisplayAnswer(manualStreamingContent)
            await MainActor.run {
                if cleanedAnswer != manualStreamingContent {
                    delegate?.processorDidReceiveAnswerChunk(cleanedAnswer, turnID: turnID)
                }
                delegate?.processorDidFinishAnswer(cleanedAnswer, totalLatencyMs: Int(latency), turnID: turnID)
                delegate?.processorHideLoading(turnID: turnID)
            }
        case .failure(let error):
            print("❌ Streaming error: \(error)")
            await MainActor.run {
                delegate?.processorDidReceiveAnswerChunk("Error: \(error.localizedDescription)", turnID: turnID)
                delegate?.processorHideLoading(turnID: turnID)
            }
        }
    }
}
