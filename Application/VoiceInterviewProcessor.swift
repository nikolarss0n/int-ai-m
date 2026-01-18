import Cocoa

/// Protocol for voice interview processor callbacks
protocol VoiceInterviewProcessorDelegate: AnyObject {
    // UI Callbacks
    func processorShowLoading(_ message: String, color: NSColor)
    func processorHideLoading()
    func processorDidReceiveQuestion(_ text: String, topic: String, messageType: InterviewMessage.MessageType, source: AudioSource)
    func processorDidStartStreaming(messageType: InterviewMessage.MessageType, topic: String)
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

    /// Process an audio segment through the full pipeline
    func processAudioSegment(_ audioData: Data, source: AudioSource) {
        let sourceLabel = source == .microphone ? "🎤 MIC" : "🔊 SYS"
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

                let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    NSLog("⚠️ PROCESS: SKIPPED - Empty transcription after trimming")
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                // Deduplication check - skip if similar text was just processed
                if isDuplicateTranscription(trimmed, source: source) {
                    NSLog("🔄 PROCESS: SKIPPED - Duplicate transcription")
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                NSLog("📝 PROCESS: Trimmed text (%d chars): '%@'", trimmed.count, trimmed)

                // Filter Whisper hallucinations (common artifacts from silence/noise)
                if isWhisperHallucination(trimmed) {
                    NSLog("👻 PROCESS: SKIPPED - Whisper hallucination: '%@'", trimmed)
                    print("👻 Whisper hallucination filtered: \(trimmed)")
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                // Filter non-ASCII garbage when language is English
                if AppSettings.shared.language == .english {
                    let nonAsciiCount = trimmed.unicodeScalars.filter { !$0.isASCII }.count
                    let nonAsciiRatio = Float(nonAsciiCount) / Float(max(trimmed.count, 1))
                    if nonAsciiRatio > 0.15 && nonAsciiCount > 3 {
                        NSLog("👻 PROCESS: SKIPPED - Non-ASCII garbage (%.0f%% non-ASCII): '%@'", nonAsciiRatio * 100, trimmed)
                        print("👻 Non-ASCII hallucination filtered (\(Int(nonAsciiRatio * 100))% non-ASCII): \(trimmed)")
                        await MainActor.run { delegate?.processorHideLoading() }
                        return
                    }
                }

                // Filter very short transcriptions (likely noise)
                if trimmed.count < 5 && !trimmed.contains("?") {
                    NSLog("👻 PROCESS: SKIPPED - Too short (%d chars), no '?': '%@'", trimmed.count, trimmed)
                    print("👻 Too short, likely noise: \(trimmed)")
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                NSLog("✅ PROCESS: Passed hallucination/length filters, proceeding...")

                // MICROPHONE = YOUR VOICE → Show directly as user response
                if source == .microphone {
                    NSLog("🎤 PROCESS: Mic audio - showing as user response directly")
                    print("🎤 [you] \(trimmed)")
                    await MainActor.run { delegate?.processorHideLoading() }
                    delegate?.conversationContext.addUtterance(text: trimmed, topic: delegate?.conversationContext.lastTopic ?? "unknown")
                    return
                }

                // SYSTEM AUDIO = INTERVIEWER → Classify and potentially generate answer
                debugLog(.classification, "System audio - checking filters...")

                // Local pre-filter for greetings/fillers
                if shouldSkipAsFillerOrGreeting(trimmed) {
                    debugLog(.classification, "SKIPPED - Greeting/filler")
                    await MainActor.run { delegate?.processorHideLoading() }
                    return
                }

                // Skip very short utterances
                let normalizedText = trimmed.lowercased().trimmingCharacters(in: .whitespaces)
                if normalizedText.count < 4 {
                    NSLog("⚡ PROCESS: LOCAL SKIP - Too short: '%@'", trimmed)
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
                if isLocallyIncomplete(trimmed) {
                    await MainActor.run {
                        utteranceBuffer = utteranceBuffer.isEmpty ? trimmed : "\(utteranceBuffer) \(trimmed)"
                        bufferTimestamp = Date()
                    }
                    NSLog("⚡ PROCESS: LOCAL INCOMPLETE - Buffered without LLM: '%@'", trimmed)
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
                    currentUtterance: trimmed,
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
                    transcription: trimmed,
                    buffer: utteranceBuffer,
                    lastTopic: context.lastTopic,
                    userBackground: userBackground.isEmpty ? nil : userBackground,
                    multiTurnMessages: messagesForAPI,
                    onClassification: { [self] classification in
                        let latency = Date().timeIntervalSince(startTime) * 1000
                        debugLog(.classification, "Result (\(Int(latency))ms): status='\(classification.status)', topic='\(classification.topic ?? "nil")'")

                        // Handle filler words
                        if classification.status == "filler" {
                            NSLog("🗣️ PROCESS: SKIPPED - Filler word detected: '%@'", trimmed)
                            return
                        }

                        // Comma-ending override
                        let combinedForCheck = utteranceBuffer.isEmpty ? trimmed : "\(utteranceBuffer) \(trimmed)"
                        let endsWithComma = combinedForCheck.trimmingCharacters(in: .whitespaces).hasSuffix(",")
                        if classification.status == "question" && endsWithComma {
                            NSLog("⚠️ PROCESS: OVERRIDE - Ends with comma, treating as incomplete")
                            utteranceBuffer = combinedForCheck
                            bufferTimestamp = Date()
                            return
                        }

                        // Handle incomplete utterances
                        if classification.status == "incomplete" {
                            utteranceBuffer = utteranceBuffer.isEmpty ? trimmed : "\(utteranceBuffer) \(trimmed)"
                            bufferTimestamp = Date()
                            NSLog("📦 PROCESS: BUFFERED - Incomplete utterance")
                            return
                        }

                        // Complete utterance
                        fullText = utteranceBuffer.isEmpty ? trimmed : "\(utteranceBuffer) \(trimmed)"
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
                        DispatchQueue.main.async { [self] in
                            debugLog(.delegate, "Calling processorDidReceiveQuestion for '\(fullText.prefix(50))...'")
                            delegate?.processorShowLoading("💭 Generating answer...", color: .appleGreen)
                            delegate?.processorDidReceiveQuestion(fullText, topic: detectedTopic, messageType: messageType, source: .systemAudio)
                            streamingContent = ""
                            debugLog(.delegate, "Calling processorDidStartStreaming")
                            delegate?.processorDidStartStreaming(messageType: messageType, topic: detectedTopic)
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

        FORBIDDEN PHRASES (never use these):
        - "doesn't exist", "you might mean", "you might be thinking of"
        - "ask them to clarify", "could you clarify", "did you mean"
        - "I think you're asking about", "possible intended question"

        Just answer the topic directly and confidently.

        FORMAT (pick best for quick scanning):
        • Comparisons: X: [brief] | Y: [brief]
        • Definitions: One sentence + 2-3 bullets
        • Code: `command` + one line why

        RULES: MAX 4-5 lines. Bullets only. No fluff. Be direct.\(languageInstruction)
        """

        // Create empty streaming message on main thread
        await MainActor.run {
            streamingContent = ""
            delegate?.processorDidStartStreaming(messageType: messageType, topic: topic)
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
        case .failure(let error):
            print("❌ Streaming error: \(error)")
            await MainActor.run {
                delegate?.processorDidReceiveAnswerChunk("Error: \(error.localizedDescription)")
            }
        }
    }
}
