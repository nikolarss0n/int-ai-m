import Cocoa

/// Protocol for voice interview processor callbacks
protocol VoiceInterviewProcessorDelegate: AnyObject {
    // UI Callbacks
    func processorShowLoading(_ message: String, color: NSColor)
    func processorHideLoading()
    func processorDidReceiveQuestion(_ text: String, topic: String, messageType: InterviewMessage.MessageType, source: AudioSource)
    func processorDidStartStreaming(messageType: InterviewMessage.MessageType, topic: String, latencyMs: Int?)
    func processorDidReceiveAnswerChunk(_ fullContent: String)
    func processorDidFinishAnswer(_ fullAnswer: String)
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
    private let dedupeWindow: TimeInterval = 5.0
    private let similarityThreshold: Double = 0.5

    // Utterance buffering state
    private var utteranceBuffer: String = ""
    private var bufferTimestamp: Date?
    private let bufferTimeout: TimeInterval = 10.0

    // Answer cooldown
    private var lastAnswerTime: Date?
    private let answerCooldown: TimeInterval = 12.0

    // Streaming content
    private var streamingContent: String = ""

    // Streaming debounce - wait for Deepgram to settle on final transcript
    private var pendingStreamingTranscript: String?
    private var pendingStreamingSource: AudioSource?
    private var streamingDebounceTask: Task<Void, Never>?
    private let streamingDebounceDelay: UInt64 = 200_000_000  // 200ms in nanoseconds

    // Latency tracking - from question end to answer stream start
    private var questionEndTime: Date?

    init() {}

    /// Configure the processor with API clients
    func configure(groqClient: GroqInterviewClient?, anthropicClient: AnthropicClient?) {
        self.groqClient = groqClient
        self.anthropicClient = anthropicClient
        debugLog("VoiceInterviewProcessor configured - groq: \(groqClient != nil), anthropic: \(anthropicClient != nil)")
    }

    /// Clear all state (call when stopping interview)
    func reset() {
        recentTranscriptions.removeAll()
        utteranceBuffer = ""
        bufferTimestamp = nil
        lastAnswerTime = nil
        streamingContent = ""
        streamingDebounceTask?.cancel()
        streamingDebounceTask = nil
        pendingStreamingTranscript = nil
        pendingStreamingSource = nil
        questionEndTime = nil
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
    private func isDuplicateTranscription(_ text: String, source: AudioSource) -> Bool {
        let now = Date()
        // Clean old entries
        recentTranscriptions.removeAll { now.timeIntervalSince($0.timestamp) > dedupeWindow }

        // Check similarity with recent transcriptions
        for recent in recentTranscriptions {
            let similarity = stringSimilarity(text, recent.text)
            if similarity > similarityThreshold {
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
        let lowerText = text.lowercased()
        let markers = [
            // Universal
            "?",
            // English
            "what is", "what are", "what's", "whats", "what did", "what do",
            "how do", "how does", "how is", "how would", "how can", "how to",
            "why do", "why does", "why is", "why would",
            "can you explain", "could you explain", "can you tell", "could you tell",
            "tell me about", "tell me more",
            "explain ", "describe ",
            "what about", "how about",
            "difference between", "differences between",
            "when do", "when does", "when would", "when should",
            "where do", "where does", "where is",
            "which ", "who ", "whose ",
            // Bulgarian
            "какво", "как", "защо", "кога", "къде", "кой", "коя", "кое", "кои",
            "разкажи", "обясни", "опиши",
            // German
            "was ", "wie ", "warum", "wann", "wo ", "wer ", "welche",
            // French
            "qu'est", "comment", "pourquoi", "quand", "où ", "qui ",
            // Spanish
            "qué ", "cómo", "por qué", "cuándo", "dónde", "quién"
        ]
        return markers.contains { lowerText.contains($0) }
    }

    // MARK: - Main Processing Pipeline

    /// Process a pre-transcribed text (from streaming STT like Deepgram)
    /// Skips the STT step and goes directly to classification/answer
    func processStreamingTranscript(_ transcription: String, isFinal: Bool, source: AudioSource) {
        let sourceLabel = source == .microphone ? "🎤 MIC" : "🔊 SYS"
        debugLog(.transcription, "\(sourceLabel) processStreamingTranscript: '\(String(transcription.prefix(50)))...' final=\(isFinal)")

        let transcript = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }

        // For partial transcripts, just update status (show live transcription)
        if !isFinal {
            DispatchQueue.main.async {
                self.delegate?.processorDidUpdateStatus("🎙️ \(String(transcript.prefix(60)))...")
            }
            return
        }

        // DEBOUNCE: Deepgram can send multiple "final" transcripts in quick succession
        // Wait 200ms for a potentially better/longer transcript before processing
        streamingDebounceTask?.cancel()
        pendingStreamingTranscript = transcript
        pendingStreamingSource = source

        streamingDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: streamingDebounceDelay)
            } catch {
                // Task was cancelled - a new transcript came in
                return
            }

            // After debounce, process the pending transcript
            guard let transcript = pendingStreamingTranscript,
                  let src = pendingStreamingSource else { return }

            pendingStreamingTranscript = nil
            pendingStreamingSource = nil

            // Run in detached task so cancellation doesn't propagate to API calls
            Task.detached { [weak self] in
                await self?.processDebounced(transcript: transcript, source: src)
            }
        }
    }

    /// Process transcript after debounce delay
    private func processDebounced(transcript: String, source: AudioSource) async {
        // Track when question processing starts (for latency calculation)
        questionEndTime = Date()

        // Deduplication check
        if isDuplicateTranscription(transcript, source: source) {
            NSLog("🔄 STREAMING: SKIPPED - Duplicate transcription")
            return
        }

        NSLog("📝 STREAMING: Final transcript (%d chars): '%@'", transcript.count, transcript)

        // Filter very short transcriptions
        if transcript.count < 5 && !transcript.contains("?") {
            NSLog("👻 STREAMING: SKIPPED - Too short (%d chars): '%@'", transcript.count, transcript)
            return
        }

        // MICROPHONE = YOUR VOICE → Show directly as user response
        if source == .microphone {
            NSLog("🎤 STREAMING: Mic audio - showing as user response directly")
            print("🎤 [you] \(transcript)")
            delegate?.conversationContext.addUtterance(text: transcript, topic: delegate?.conversationContext.lastTopic ?? "unknown")
            return
        }

        // SYSTEM AUDIO = INTERVIEWER → Classify and potentially generate answer
        // Local pre-filter for greetings/fillers
        if shouldSkipAsFillerOrGreeting(transcript) {
            debugLog(.classification, "STREAMING: SKIPPED - Greeting/filler")
            return
        }

        // Skip very short utterances
        let normalizedText = transcript.lowercased().trimmingCharacters(in: .whitespaces)
        if normalizedText.count < 4 {
            NSLog("⚡ STREAMING: LOCAL SKIP - Too short: '%@'", transcript)
            return
        }

        debugLog(.classification, "STREAMING: Proceeding to classification...")

        // Combined classify + answer in ONE Haiku call
        guard let haiku = anthropicClient else {
            debugLog(.error, "STREAMING: anthropicClient is nil!")
            return
        }

        // Local incomplete filter
        if isLocallyIncomplete(transcript) {
            await MainActor.run {
                utteranceBuffer = utteranceBuffer.isEmpty ? transcript : "\(utteranceBuffer) \(transcript)"
                bufferTimestamp = Date()
            }
            NSLog("⚡ STREAMING: LOCAL INCOMPLETE - Buffered: '%@'", transcript)
            return
        }

        await MainActor.run { delegate?.processorShowLoading("🔍 Analyzing...", color: .applePurple) }

        // Get context for the combined call
        let userBackground = await MainActor.run { delegate?.userBackground ?? "" }
        let pinnedSolution = delegate?.pinnedSolution
        guard let context = delegate?.conversationContext else {
            await MainActor.run { delegate?.processorHideLoading() }
            return
        }

        // Build multi-turn messages for context
        let multiTurnMessages = context.buildMultiTurnMessages(
            currentUtterance: transcript,
            pinnedSolution: pinnedSolution
        )
        let messagesForAPI = context.messagesToAPIFormat(multiTurnMessages)

        // State for handling classification result
        var shouldStreamAnswer = false
        var detectedTopic: String = "unknown"
        var messageType: InterviewMessage.MessageType = .answer
        var fullText = ""

        let startTime = Date()

        let result = await haiku.classifyAndStreamAnswer(
            transcription: transcript,
                buffer: utteranceBuffer,
                lastTopic: context.lastTopic,
                userBackground: userBackground.isEmpty ? nil : userBackground,
                multiTurnMessages: messagesForAPI,
                onClassification: { [self] classification in
                    let latency = Date().timeIntervalSince(startTime) * 1000
                    debugLog(.classification, "STREAMING Result (\(Int(latency))ms): status='\(classification.status)', topic='\(classification.topic ?? "nil")'")

                    // Handle filler words
                    if classification.status == "filler" {
                        NSLog("🗣️ STREAMING: SKIPPED - Filler word: '%@'", transcript)
                        return
                    }

                    // Handle incomplete utterances
                    if classification.status == "incomplete" {
                        utteranceBuffer = utteranceBuffer.isEmpty ? transcript : "\(utteranceBuffer) \(transcript)"
                        bufferTimestamp = Date()
                        NSLog("📦 STREAMING: BUFFERED - Incomplete utterance")
                        return
                    }

                    // Complete utterance - prefer normalized text if available (fixes phonetic STT errors)
                    let rawText = utteranceBuffer.isEmpty ? transcript : "\(utteranceBuffer) \(transcript)"
                    fullText = classification.normalizedText ?? rawText
                    if classification.normalizedText != nil {
                        debugLog(.classification, "Using normalized text: '\(fullText)'")
                    }
                    utteranceBuffer = ""
                    detectedTopic = classification.topic ?? "unknown"

                    // System audio classified as "answer" or "statement" = interviewer talking (not asking)
                    if classification.status == "answer" || classification.status == "statement" {
                        NSLog("🔊 STREAMING: Interviewer statement (not a question)")
                        context.addUtterance(text: fullText, topic: detectedTopic)
                        return
                    }

                    // Check cooldown
                    if let lastAnswer = lastAnswerTime {
                        let elapsed = Date().timeIntervalSince(lastAnswer)
                        if elapsed < answerCooldown {
                            let isClearQuestion = checkForQuestionMarkers(fullText)
                            if !isClearQuestion {
                                NSLog("⏸️ STREAMING: SKIPPED - Cooldown active")
                                context.addUtterance(text: fullText, topic: detectedTopic)
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
                        let backgroundKeywords = ["experience", "background", "yourself", "projects", "position", "role", "job", "work", "company", "team", "career"]
                        let isLikelyBackground = backgroundKeywords.contains { fullText.lowercased().contains($0) }
                        if !isLikelyBackground {
                            NSLog("⚠️ STREAMING: SKIPPED - Orphan followup")
                            return
                        }
                        detectedTopic = "experience"
                    } else if topicLower == "unknown", let lastTopic = context.lastTopic {
                        if checkForQuestionMarkers(fullText) {
                            messageType = .followUp
                            detectedTopic = lastTopic
                        } else {
                            NSLog("⚠️ STREAMING: SKIPPED - Unknown topic, no question markers")
                            return
                        }
                    }

                    // All checks passed - enable answer streaming
                    debugLog(.answer, "✅ STREAMING: Passed all filters! Will stream answer for topic='\(detectedTopic)'")
                    shouldStreamAnswer = true

                    // Calculate latency from question end to now
                    let latencyMs: Int? = questionEndTime.map { Int(Date().timeIntervalSince($0) * 1000) }

                    // Update context and UI on main thread
                    DispatchQueue.main.async { [self] in
                        delegate?.processorShowLoading("💭 Generating answer...", color: .appleGreen)
                        delegate?.processorDidReceiveQuestion(fullText, topic: detectedTopic, messageType: messageType, source: .systemAudio)
                        streamingContent = ""
                        delegate?.processorDidStartStreaming(messageType: messageType, topic: detectedTopic, latencyMs: latencyMs)
                    }

                    context.addUtterance(text: fullText, topic: detectedTopic, isQuestion: true)
                    lastAnswerTime = Date()
                },
                onAnswerChunk: { [self] chunk in
                    guard shouldStreamAnswer else { return }
                    DispatchQueue.main.async { [self] in
                        streamingContent += chunk
                        delegate?.processorDidReceiveAnswerChunk(streamingContent)
                    }
            }
        )

        let totalLatency = Date().timeIntervalSince(startTime) * 1000

        switch result {
        case .success:
            if shouldStreamAnswer {
                debugLog(.answer, "STREAMING: Answer complete (\(Int(totalLatency))ms), \(streamingContent.count) chars")
                await MainActor.run { delegate?.processorDidFinishAnswer(streamingContent) }

                // Add answer to conversation history for multi-turn context
                context.addUtterance(text: streamingContent, topic: detectedTopic, isQuestion: false)

                // Auto-summarization
                if context.needsSummarization, let haiku = anthropicClient {
                    Task {
                        let textToSummarize = context.getTextForSummarization()
                        if !textToSummarize.isEmpty {
                            do {
                                let summary = try await haiku.summarizeConversation(conversationText: textToSummarize)
                                context.setSummary(summary)
                            } catch {
                                print("⚠️ Summarization failed: \(error)")
                            }
                        }
                    }
                }
            }
        case .failure(let error):
            debugLog(.error, "STREAMING: Combined call FAILED: \(error)")
            if shouldStreamAnswer {
                await MainActor.run { delegate?.processorDidReceiveAnswerChunk("Error: \(error.localizedDescription)") }
            }
        }

        await MainActor.run { delegate?.processorHideLoading() }
    }

    /// Process an audio segment through the full pipeline
    func processAudioSegment(_ audioData: Data, source: AudioSource) {
        let sourceLabel = source == .microphone ? "🎤 MIC" : "🔊 SYS"
        let segmentStartTime = Date()  // Track latency from audio received to answer start
        debugLog(.audio, "\(sourceLabel) processAudioSegment called with \(audioData.count) bytes")
        guard let client = groqClient else {
            debugLog(.error, "groqClient is nil!")
            return
        }
        debugLog(.audio, "groqClient configured: \(client)")

        Task {
            do {
                // 1. Transcribe audio + warmup Anthropic connection in parallel
                await MainActor.run { delegate?.processorShowLoading("🎙️ Transcribing...", color: .systemBlue) }
                debugLog(.transcription, "Sending \(audioData.count) bytes to Groq...")

                // Start connection warmup in background (fire-and-forget, saves ~50-100ms)
                Task { await anthropicClient?.warmupConnection() }

                // STT is the critical path - don't block on warmup
                let (transcription, sttLatency) = try await client.transcribe(audioData: audioData)
                debugLog(.transcription, "Result (\(Int(sttLatency))ms): '\(transcription)'")

                let transcript = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !transcript.isEmpty else {
                    NSLog("⚠️ PROCESS: SKIPPED - Empty transcription after trimming")
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                // Deduplication check - skip if similar text was just processed
                if isDuplicateTranscription(transcript, source: source) {
                    NSLog("🔄 PROCESS: SKIPPED - Duplicate transcription")
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                NSLog("📝 PROCESS: Trimmed text (%d chars): '%@'", transcript.count, transcript)

                // Filter Whisper hallucinations (common artifacts from silence/noise)
                if isWhisperHallucination(transcript) {
                    NSLog("👻 PROCESS: SKIPPED - Whisper hallucination: '%@'", transcript)
                    print("👻 Whisper hallucination filtered: \(transcript)")
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                // Filter non-ASCII garbage when language is English
                if AppSettings.shared.language == .english {
                    let nonAsciiCount = transcript.unicodeScalars.filter { !$0.isASCII }.count
                    let nonAsciiRatio = Float(nonAsciiCount) / Float(max(transcript.count, 1))
                    if nonAsciiRatio > 0.15 && nonAsciiCount > 3 {
                        NSLog("👻 PROCESS: SKIPPED - Non-ASCII garbage (%.0f%% non-ASCII): '%@'", nonAsciiRatio * 100, transcript)
                        print("👻 Non-ASCII hallucination filtered (\(Int(nonAsciiRatio * 100))% non-ASCII): \(transcript)")
                        await MainActor.run { delegate?.processorHideLoading() }
                        return
                    }
                }

                // Filter very short transcriptions (likely noise)
                if transcript.count < 5 && !transcript.contains("?") {
                    NSLog("👻 PROCESS: SKIPPED - Too short (%d chars), no '?': '%@'", transcript.count, transcript)
                    print("👻 Too short, likely noise: \(transcript)")
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                NSLog("✅ PROCESS: Passed hallucination/length filters, proceeding...")

                // MICROPHONE = YOUR VOICE → Show directly as user response
                if source == .microphone {
                    NSLog("🎤 PROCESS: Mic audio - showing as user response directly")
                    print("🎤 [you] \(transcript)")
                    await MainActor.run { delegate?.processorHideLoading() }
                    delegate?.conversationContext.addUtterance(text: transcript, topic: delegate?.conversationContext.lastTopic ?? "unknown")
                    return
                }

                // SYSTEM AUDIO = INTERVIEWER → Classify and potentially generate answer
                debugLog(.classification, "System audio - checking filters...")

                // Local pre-filter for greetings/fillers
                if shouldSkipAsFillerOrGreeting(transcript) {
                    debugLog(.classification, "SKIPPED - Greeting/filler")
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                // Skip very short utterances
                let normalizedText = transcript.lowercased().trimmingCharacters(in: .whitespaces)
                if normalizedText.count < 4 {
                    NSLog("⚡ PROCESS: LOCAL SKIP - Too short: '%@'", transcript)
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                debugLog(.classification, "Proceeding to classification...")

                // Combined classify + answer in ONE Haiku call
                guard let haiku = anthropicClient else {
                    debugLog(.error, "anthropicClient is nil!")
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }
                debugLog(.classification, "anthropicClient configured: \(haiku)")

                // Local incomplete filter
                if isLocallyIncomplete(transcript) {
                    await MainActor.run {
                        utteranceBuffer = utteranceBuffer.isEmpty ? transcript : "\(utteranceBuffer) \(transcript)"
                        bufferTimestamp = Date()
                    }
                    NSLog("⚡ PROCESS: LOCAL INCOMPLETE - Buffered without LLM: '%@'", transcript)
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                await MainActor.run { delegate?.processorShowLoading("🔍 Analyzing...", color: .applePurple) }

                // Get context for the combined call
                let userBackground = await MainActor.run { delegate?.userBackground ?? "" }
                let pinnedSolution = delegate?.pinnedSolution
                guard let context = delegate?.conversationContext else {
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                // Build multi-turn messages for context
                let multiTurnMessages = context.buildMultiTurnMessages(
                    currentUtterance: transcript,
                    pinnedSolution: pinnedSolution
                )
                let messagesForAPI = context.messagesToAPIFormat(multiTurnMessages)

                // State for handling classification result
                var shouldStreamAnswer = false
                var detectedTopic: String = "unknown"
                var messageType: InterviewMessage.MessageType = .answer
                var fullText = ""

                let startTime = Date()

                let result = await haiku.classifyAndStreamAnswer(
                    transcription: transcript,
                    buffer: utteranceBuffer,
                    lastTopic: context.lastTopic,
                    userBackground: userBackground.isEmpty ? nil : userBackground,
                    multiTurnMessages: messagesForAPI,
                    onClassification: { [self] classification in
                        let latency = Date().timeIntervalSince(startTime) * 1000
                        debugLog(.classification, "Result (\(Int(latency))ms): status='\(classification.status)', topic='\(classification.topic ?? "nil")'")

                        // Handle filler words
                        if classification.status == "filler" {
                            NSLog("🗣️ PROCESS: SKIPPED - Filler word detected: '%@'", transcript)
                            return
                        }

                        // Comma-ending override
                        let combinedForCheck = utteranceBuffer.isEmpty ? transcript : "\(utteranceBuffer) \(transcript)"
                        let endsWithComma = combinedForCheck.trimmingCharacters(in: .whitespaces).hasSuffix(",")
                        if classification.status == "question" && endsWithComma {
                            NSLog("⚠️ PROCESS: OVERRIDE - Ends with comma, treating as incomplete")
                            utteranceBuffer = combinedForCheck
                            bufferTimestamp = Date()
                            return
                        }

                        // Handle incomplete utterances
                        if classification.status == "incomplete" {
                            utteranceBuffer = utteranceBuffer.isEmpty ? transcript : "\(utteranceBuffer) \(transcript)"
                            bufferTimestamp = Date()
                            NSLog("📦 PROCESS: BUFFERED - Incomplete utterance")
                            return
                        }

                        // Complete utterance - prefer normalized text if available (fixes phonetic STT errors)
                        let rawText = utteranceBuffer.isEmpty ? transcript : "\(utteranceBuffer) \(transcript)"
                        fullText = classification.normalizedText ?? rawText
                        if classification.normalizedText != nil {
                            debugLog(.classification, "Using normalized text: '\(fullText)'")
                        }
                        utteranceBuffer = ""
                        detectedTopic = classification.topic ?? "unknown"

                        // System audio classified as "answer" or "statement" = interviewer talking (not asking)
                        if classification.status == "answer" || classification.status == "statement" {
                            NSLog("🔊 PROCESS: Interviewer statement (not a question)")
                            context.addUtterance(text: fullText, topic: detectedTopic)
                            return
                        }

                        // Check cooldown
                        if let lastAnswer = lastAnswerTime {
                            let elapsed = Date().timeIntervalSince(lastAnswer)
                            if elapsed < answerCooldown {
                                let isClearQuestion = checkForQuestionMarkers(fullText)
                                if !isClearQuestion {
                                    NSLog("⏸️ PROCESS: SKIPPED - Cooldown active")
                                    context.addUtterance(text: fullText, topic: detectedTopic)
                                    return
                                }

                                // Extra check for short continuations
                                let wordCount = fullText.split(separator: " ").count
                                let startsWithContinuation = ["so ", "and ", "then ", "but ", "or "].contains {
                                    fullText.lowercased().hasPrefix($0)
                                }
                                if elapsed < 3.0 && wordCount <= 6 && startsWithContinuation {
                                    NSLog("🔗 PROCESS: SKIPPED - Short continuation fragment")
                                    context.addUtterance(text: fullText, topic: detectedTopic)
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
                            let backgroundKeywords = ["experience", "background", "yourself", "projects", "position", "role", "job", "work", "company", "team", "career"]
                            let isLikelyBackground = backgroundKeywords.contains { fullText.lowercased().contains($0) }
                            if !isLikelyBackground {
                                NSLog("⚠️ PROCESS: SKIPPED - Orphan followup")
                                return
                            }
                            detectedTopic = "experience"
                        } else if topicLower == "unknown", let lastTopic = context.lastTopic {
                            if checkForQuestionMarkers(fullText) {
                                messageType = .followUp
                                detectedTopic = lastTopic
                            } else {
                                NSLog("⚠️ PROCESS: SKIPPED - Unknown topic, no question markers")
                                return
                            }
                        }

                        // All checks passed - enable answer streaming
                        debugLog(.answer, "✅ Passed all filters! Will stream answer for topic='\(detectedTopic)'")
                        shouldStreamAnswer = true

                        // Update context and UI on main thread
                        let batchLatencyMs = Int(Date().timeIntervalSince(segmentStartTime) * 1000)
                        DispatchQueue.main.async { [self] in
                            debugLog(.delegate, "Calling processorDidReceiveQuestion for '\(fullText.prefix(50))...'")
                            delegate?.processorShowLoading("💭 Generating answer...", color: .appleGreen)
                            delegate?.processorDidReceiveQuestion(fullText, topic: detectedTopic, messageType: messageType, source: .systemAudio)
                            streamingContent = ""
                            debugLog(.delegate, "Calling processorDidStartStreaming (latency=\(batchLatencyMs)ms)")
                            delegate?.processorDidStartStreaming(messageType: messageType, topic: detectedTopic, latencyMs: batchLatencyMs)
                        }

                        context.addUtterance(text: fullText, topic: detectedTopic, isQuestion: true)
                        lastAnswerTime = Date()
                    },
                    onAnswerChunk: { [self] chunk in
                        guard shouldStreamAnswer else { return }
                        DispatchQueue.main.async { [self] in
                            streamingContent += chunk
                            if streamingContent.count < 100 || streamingContent.count % 200 == 0 {
                                debugLog(.stream, "Chunk received, total: \(streamingContent.count) chars")
                            }
                            delegate?.processorDidReceiveAnswerChunk(streamingContent)
                        }
                    }
                )

                debugLog(.answer, "classifyAndStreamAnswer returned, shouldStreamAnswer=\(shouldStreamAnswer)")

                let totalLatency = Date().timeIntervalSince(startTime) * 1000

                switch result {
                case .success:
                    debugLog(.answer, "Result: SUCCESS")
                    if shouldStreamAnswer {
                        debugLog(.answer, "Answer complete (\(Int(totalLatency))ms), \(streamingContent.count) chars")
                        debugLog(.delegate, "Calling processorDidFinishAnswer")
                        await MainActor.run { delegate?.processorDidFinishAnswer(streamingContent) }

                        // Add answer to conversation history for multi-turn context
                        context.addUtterance(text: streamingContent, topic: detectedTopic, isQuestion: false)

                        // Auto-summarization
                        if context.needsSummarization, let haiku = anthropicClient {
                            Task {
                                let textToSummarize = context.getTextForSummarization()
                                if !textToSummarize.isEmpty {
                                    do {
                                        let summary = try await haiku.summarizeConversation(conversationText: textToSummarize)
                                        context.setSummary(summary)
                                    } catch {
                                        print("⚠️ Summarization failed: \(error)")
                                    }
                                }
                            }
                        }
                    }
                case .failure(let error):
                    debugLog(.error, "Combined call FAILED: \(error)")
                    if shouldStreamAnswer {
                        await MainActor.run { delegate?.processorDidReceiveAnswerChunk("Error: \(error.localizedDescription)") }
                    }
                }

                await MainActor.run { delegate?.processorHideLoading() }

            } catch {
                print("❌ Error processing audio: \(error)")
                await MainActor.run {
                    delegate?.processorHideLoading()
                    delegate?.processorDidUpdateStatus("Error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Check if text is a Whisper hallucination
    private func isWhisperHallucination(_ transcript: String) -> Bool {
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

        let lowerTrimmed = transcript.lowercased()
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        return transcript.count < 30 && whisperHallucinations.contains(where: { lowerTrimmed == $0 })
    }

    /// Check if text should be skipped as filler or greeting
    private func shouldSkipAsFillerOrGreeting(_ transcript: String) -> Bool {
        let normalizedText = transcript.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[.!?,']", with: "", options: .regularExpression)

        let greetingStarts = ["hello", "hi ", "hey ", "good morning", "good afternoon", "good evening", "welcome to"]
        let isGreeting = greetingStarts.contains { normalizedText.hasPrefix($0) }

        let fillerPatterns = ["thank you", "thanks", "yes sure", "yeah sure", "okay", "sure", "sounds good", "got it", "i see", "i understand", "alright"]
        let isFiller = fillerPatterns.contains { normalizedText.hasPrefix($0) || normalizedText == $0 }

        // Multilingual question detection
        let questionWords = [
            // English
            "what", "how", "why", "when", "where", "which", "who",
            "can you", "could you", "would you", "tell me", "explain", "describe", "give me", "show me", "walk me",
            // Bulgarian
            "какво", "как", "защо", "кога", "къде", "кой", "коя", "кое",
            "може ли", "обясни", "кажи", "опиши",
            // German
            "was ", "wie ", "warum", "wann", "wo ", "wer ",
            // Spanish
            "qué", "cómo", "por qué", "cuándo", "dónde", "quién"
        ]
        let hasQuestionWord = questionWords.contains { normalizedText.contains($0) }

        // Also check for question mark
        let hasQuestionMark = transcript.contains("?")

        if (isGreeting || isFiller) && normalizedText.count < 50 && !hasQuestionWord && !hasQuestionMark {
            NSLog("⚡ PROCESS: LOCAL SKIP - Greeting/filler: '%@'", transcript)
            return true
        }

        return false
    }

    /// Check if text is locally incomplete (ends with common incomplete patterns)
    private func isLocallyIncomplete(_ transcript: String) -> Bool {
        let textForCheck = transcript.lowercased().trimmingCharacters(in: .whitespaces)
        let incompleteEndings = [" so", " and", " but", " the", " a", " an", " to", " of", " that", " if", " when", " is", " are", " have", " can", " will", " for", " with", " on", " in", ","]
        let endsIncomplete = incompleteEndings.contains { textForCheck.hasSuffix($0) }
        let hasQuestionMark = textForCheck.contains("?")

        return endsIncomplete && !hasQuestionMark
    }

    // MARK: - Standalone Answer Generation

    /// Generate answer using Haiku with streaming (for manual invocation)
    func streamAnswerWithHaiku(question: String, topic: String, messageType: InterviewMessage.MessageType) async {
        guard let haiku = anthropicClient else {
            NSLog("❌ Anthropic client not configured!")
            return
        }

        let userBackground = delegate?.userBackground ?? ""
        guard let context = delegate?.conversationContext else { return }

        let backgroundContext = !userBackground.isEmpty ? """
        YOUR BACKGROUND (use for personal questions like "tell me about yourself"):
        \(userBackground)

        """ : ""

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

        \(backgroundContext)\(historyContext)\(pinnedContext)CURRENT QUESTION: "\(question)"
        Topic: \(topic)

        SPEECH-TO-TEXT: The question text is from voice transcription and may contain errors.
        ALWAYS answer about the Topic shown above. Ignore garbled words.
        Example: "What is key developer?" with Topic: hashmap → Answer about HashMap keys.

        Just answer the topic directly and confidently.

        FORMAT: Definition + complexity only. 1-2 lines max.
        NO extras: no "Watch out", "Pro tip", "Common use", "Key features".
        LANGUAGE: Keep ALL programming terms in English (key-value, hash code, bucket, collision, thread-safe, etc.) even when responding in other languages.
        If they want more details, they'll ask follow-up questions.\(languageInstruction)
        """

        // Create empty streaming message on main thread
        await MainActor.run {
            streamingContent = ""
            delegate?.processorDidStartStreaming(messageType: messageType, topic: topic, latencyMs: nil)
        }

        let startTime = Date()

        let result = await haiku.streamTextMessage(prompt: prompt, maxTokens: 250) { [weak self] chunk in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.streamingContent += chunk
                self.delegate?.processorDidReceiveAnswerChunk(self.streamingContent)
            }
        }

        let latency = Date().timeIntervalSince(startTime) * 1000

        switch result {
        case .success:
            print("💡 Answer (Haiku \(Int(latency))ms): \(streamingContent.prefix(100))...")
            await MainActor.run {
                delegate?.processorDidFinishAnswer(streamingContent)
            }
            // Add answer to conversation history for multi-turn context
            delegate?.conversationContext.addUtterance(text: streamingContent, topic: topic, isQuestion: false)
        case .failure(let error):
            print("❌ Streaming error: \(error)")
            await MainActor.run {
                delegate?.processorDidReceiveAnswerChunk("Error: \(error.localizedDescription)")
            }
        }
    }
}
