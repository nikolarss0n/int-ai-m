import Foundation

/// Coordinates two Deepgram streams (primary + English) for multilingual transcription
/// Primary stream: Bulgarian/native language for sentence structure
/// English stream: For technical term recognition (hashmap, LinkedList, etc.)
/// Merges finals with Claude Haiku for best-of-both-worlds output
///
/// Event-driven approach:
/// - Store finals as they arrive from each stream
/// - Flush immediately when BOTH finals arrive
/// - OR flush on finalizeUtterance() call (VAD silence detection)
/// - No hardcoded timeouts
class DualStreamTranscriber {
    private let primaryClient: DeepgramStreamingClient
    private let englishClient: DeepgramStreamingClient
    private let anthropicClient: AnthropicClient

    private let primaryLanguage: String
    private var keyterms: [String] = []

    // Synchronization state - transcripts
    private var primaryFinal: String?
    private var englishFinal: String?
    private var isFlushing = false

    // Callbacks
    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?  // Merged or primary-only
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onError: ((Error) -> Void)?

    // Track connection state
    private var primaryConnected = false
    private var englishConnected = false

    init(deepgramApiKey: String, anthropicApiKey: String, primaryLanguage: String) {
        self.primaryLanguage = primaryLanguage
        self.primaryClient = DeepgramStreamingClient(apiKey: deepgramApiKey)
        self.englishClient = DeepgramStreamingClient(apiKey: deepgramApiKey)
        self.anthropicClient = AnthropicClient(apiKey: anthropicApiKey)

        setupCallbacks()
    }

    private func setupCallbacks() {
        // PRIMARY STREAM callbacks
        primaryClient.onConnected = { [weak self] in
            guard let self = self else { return }
            self.primaryConnected = true
            NSLog("✅ DualStream: Primary (\(self.primaryLanguage)) connected")
            self.checkBothConnected()
        }

        primaryClient.onPartialTranscript = { [weak self] text in
            // Show primary partials immediately for responsive UI
            self?.onPartialTranscript?(text)
        }

        primaryClient.onFinalTranscript = { [weak self] text in
            NSLog("🔵 DualStream: Primary FINAL: '\(text)'")
            self?.handlePrimaryFinal(text)
        }

        primaryClient.onDisconnected = { [weak self] in
            self?.primaryConnected = false
            NSLog("🔌 DualStream: Primary disconnected")
            // Flush on disconnect
            self?.flushIfNeeded()
            self?.onDisconnected?()
        }

        primaryClient.onError = { [weak self] error in
            NSLog("❌ DualStream: Primary error: \(error.localizedDescription)")
            self?.onError?(error)
        }

        // ENGLISH STREAM callbacks
        englishClient.onConnected = { [weak self] in
            self?.englishConnected = true
            NSLog("✅ DualStream: English connected")
            self?.checkBothConnected()
        }

        englishClient.onPartialTranscript = { _ in
            // Ignore English partials - we only care about finals
        }

        englishClient.onFinalTranscript = { [weak self] text in
            NSLog("🟢 DualStream: English FINAL: '\(text)'")
            self?.handleEnglishFinal(text)
        }

        englishClient.onDisconnected = { [weak self] in
            self?.englishConnected = false
            NSLog("🔌 DualStream: English disconnected")
        }

        englishClient.onError = { error in
            // English stream errors are non-critical - we can fall back to primary only
            NSLog("⚠️ DualStream: English error (non-critical): \(error.localizedDescription)")
        }
    }

    private func checkBothConnected() {
        if primaryConnected && englishConnected {
            onConnected?()
        }
    }

    // MARK: - Public API

    func connect(keyterms: [String] = []) {
        self.keyterms = keyterms

        // Connect both streams
        primaryClient.connect(language: primaryLanguage)
        englishClient.connect(language: "en")
    }

    func disconnect() {
        primaryClient.disconnect()
        englishClient.disconnect()
        resetState()
    }

    func sendAudio(_ audioData: Data) {
        // Send same audio to BOTH streams
        primaryClient.sendAudio(audioData)
        englishClient.sendAudio(audioData)
    }

    /// Called when VAD detects silence - flush whatever we have
    func finalizeUtterance() {
        NSLog("🔚 DualStream: finalizeUtterance called - flushing")
        primaryClient.finalizeUtterance()
        englishClient.finalizeUtterance()

        // Give streams a moment to process, then flush
        // This is triggered by VAD silence detection, so we should send now
        DispatchQueue.main.async { [weak self] in
            self?.flushIfNeeded()
        }
    }

    func keepAlive() {
        primaryClient.keepAlive()
        englishClient.keepAlive()
    }

    // MARK: - Final Transcript Handling

    private func handlePrimaryFinal(_ text: String) {
        NSLog("🔵 DualStream: Storing primary: '\(text)'")
        primaryFinal = text
        tryFlush()
    }

    private func handleEnglishFinal(_ text: String) {
        NSLog("🟢 DualStream: Storing English: '\(text)'")
        englishFinal = text
        tryFlush()
    }

    /// Try to flush if both finals are ready
    private func tryFlush() {
        guard primaryFinal != nil && englishFinal != nil else {
            NSLog("⏳ DualStream: Waiting (primary=\(primaryFinal != nil), english=\(englishFinal != nil))")
            return
        }

        NSLog("🚀 DualStream: Both finals ready, flushing")
        flushTranscripts()
    }

    /// Flush whatever we have (called on silence/disconnect)
    private func flushIfNeeded() {
        guard primaryFinal != nil || englishFinal != nil else {
            return  // Nothing to flush
        }
        flushTranscripts()
    }

    private func flushTranscripts() {
        guard !isFlushing else {
            NSLog("⚠️ DualStream: Already flushing, skipping")
            return
        }

        isFlushing = true
        NSLog("📤 DualStream: Flushing (primary='\(primaryFinal ?? "nil")', english='\(englishFinal ?? "nil")')")

        // Send whatever we have
        if let primary = primaryFinal, let english = englishFinal {
            mergeAndSend(primary: primary, english: english)
        } else if let primary = primaryFinal {
            NSLog("📤 DualStream: Sending primary only")
            onFinalTranscript?(primary)
            resetState()
        } else if let english = englishFinal {
            NSLog("📤 DualStream: Sending English only")
            onFinalTranscript?(english)
            resetState()
        } else {
            resetState()
        }
    }

    private func mergeAndSend(primary: String, english: String) {
        // Skip merge if transcripts are essentially identical
        let normalizedPrimary = primary.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEnglish = english.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedPrimary == normalizedEnglish {
            NSLog("✅ DualStream: Transcripts identical, sending primary")
            onFinalTranscript?(primary)
            resetState()
            return
        }

        // Check if English has technical terms that primary might have mangled
        let techTerms = ["hashmap", "linkedlist", "array", "string", "class", "function",
                        "async", "await", "api", "json", "rest", "http", "sql", "css", "html",
                        "react", "node", "python", "java", "swift", "kotlin", "typescript",
                        "git", "docker", "kubernetes", "aws", "azure", "redis", "mongodb",
                        "oauth", "jwt", "crud", "orm", "mvc", "solid", "dry", "kiss"]

        let englishLower = english.lowercased()
        let hasTechTerms = techTerms.contains { englishLower.contains($0) }

        if !hasTechTerms {
            NSLog("✅ DualStream: No tech terms detected, sending primary")
            onFinalTranscript?(primary)
            resetState()
            return
        }

        // Merge with Claude
        NSLog("🔄 DualStream: Merging (primary='%@', english='%@')...", primary, english)
        Task {
            let merged = await mergeWithClaude(primary: primary, english: english)

            await MainActor.run {
                NSLog("🔀 DualStream: Merged result: '\(merged)'")
                self.onFinalTranscript?(merged)
                self.resetState()
            }
        }
    }

    private func mergeWithClaude(primary: String, english: String) async -> String {
        let prompt = """
        You merge two speech-to-text transcripts of the SAME audio.
        Primary transcript (\(primaryLanguage)): "\(primary)"
        Secondary transcript (English): "\(english)"

        Rules:
        - Output should be in \(primaryLanguage)
        - Replace any phonetic/transliterated programming terms with correct English spelling from secondary
        - Common terms: hashmap, LinkedList, array, string, class, function, API, JSON, async, await, etc.
        - Keep the sentence structure from primary, only fix technical term spelling
        - Return ONLY the merged text, nothing else.
        """

        do {
            let (result, latency) = try await anthropicClient.sendMessage(prompt: prompt, maxTokens: 150)
            NSLog("⚡ DualStream: Merge completed in %.0fms", latency)
            return result.isEmpty ? primary : result
        } catch {
            NSLog("❌ DualStream: Merge failed: \(error.localizedDescription)")
            return primary
        }
    }

    private func resetState() {
        primaryFinal = nil
        englishFinal = nil
        isFlushing = false
    }
}
