import Foundation
import AVFoundation

/// Deepgram Nova-3 Streaming STT Client
/// Uses WebSocket for real-time transcription with ~100-150ms latency
class DeepgramStreamingClient: NSObject {
    private let apiKey: String
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    // Audio streaming state
    private var isConnected = false
    private var isConnecting = false
    private var isStreaming = false

    // Configuration
    private let model = "nova-3"
    private let sampleRate = 16000
    private let encoding = "linear16"

    // Reconnection settings
    private let maxReconnectAttempts = 3
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private var currentLanguage = "en"
    private var currentKeyterms: [String] = []

    // Connection timeout
    private let connectionTimeout: TimeInterval = 10.0
    private var connectionTimeoutTask: Task<Void, Never>?

    // KeepAlive timer
    private let keepAliveInterval: TimeInterval = 10.0
    private var keepAliveTask: Task<Void, Never>?

    // Callbacks
    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onSpeechEnded: (() -> Void)?  // Fires when speech_final: true (utterance complete)
    var onError: ((Error) -> Void)?
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?

    // Transcript accumulation
    private var currentUtterance = ""
    private var finalizedText = ""

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }

    deinit {
        cleanup()
    }

    private func cleanup() {
        keepAliveTask?.cancel()
        keepAliveTask = nil
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        webSocket = nil
    }

    /// Connect to Deepgram WebSocket
    /// - Parameters:
    ///   - language: Language code ("en", "bg", "multi" for multilingual)
    ///   - keyterms: Technical terms to boost recognition (e.g., ["hashmap", "LinkedList", "async"])
    func connect(language: String = "en", keyterms: [String] = []) {
        guard !isConnected && !isConnecting else {
            NSLog("⚠️ Deepgram: Already connected or connecting")
            return
        }

        isConnecting = true
        currentLanguage = language
        currentKeyterms = keyterms

        // Build WebSocket URL with query parameters
        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        var queryItems = [
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "encoding", value: encoding),
            URLQueryItem(name: "sample_rate", value: String(sampleRate)),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "endpointing", value: "300"),  // 300ms silence = end of utterance
            URLQueryItem(name: "vad_events", value: "true"),
            URLQueryItem(name: "smart_format", value: "true")
        ]

        // Add keyterms for boosted vocabulary recognition (Nova-3 feature)
        // Each keyterm is added as a separate query parameter
        for term in keyterms {
            queryItems.append(URLQueryItem(name: "keyterm", value: term))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            NSLog("❌ Deepgram: Invalid URL")
            isConnecting = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        webSocket = urlSession?.webSocketTask(with: request)

        webSocket?.resume()

        NSLog("🔌 Deepgram: Connecting to %@", url.absoluteString)

        // Start connection timeout
        startConnectionTimeout()

        // Start receiving messages
        receiveMessage()
    }

    /// Start connection timeout timer
    private func startConnectionTimeout() {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.connectionTimeout ?? 10.0) * 1_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self, self.isConnecting && !self.isConnected else { return }
                NSLog("❌ Deepgram: Connection timeout after \(self.connectionTimeout)s")
                self.isConnecting = false
                self.handleConnectionFailure()
            }
        }
    }

    /// Start keepAlive timer
    private func startKeepAliveTimer() {
        keepAliveTask?.cancel()
        keepAliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.keepAliveInterval ?? 10.0) * 1_000_000_000)
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    guard let self = self, self.isConnected && !self.isStreaming else { return }
                    self.keepAlive()
                }
            }
        }
    }

    /// Handle connection failure with auto-reconnect
    private func handleConnectionFailure() {
        guard reconnectAttempt < maxReconnectAttempts else {
            NSLog("❌ Deepgram: Max reconnect attempts (\(maxReconnectAttempts)) reached")
            reconnectAttempt = 0
            DispatchQueue.main.async {
                self.onError?(DeepgramError.maxReconnectAttemptsReached)
            }
            return
        }

        reconnectAttempt += 1
        let delay = pow(2.0, Double(reconnectAttempt)) // Exponential backoff: 2, 4, 8 seconds
        NSLog("🔄 Deepgram: Reconnecting in \(delay)s (attempt \(reconnectAttempt)/\(maxReconnectAttempts))")

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self else { return }
                self.cleanup()
                self.connect(language: self.currentLanguage, keyterms: self.currentKeyterms)
            }
        }
    }

    /// Disconnect from WebSocket
    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0

        guard isConnected || isConnecting else { return }

        // Send close stream message
        let closeMessage = "{\"type\": \"CloseStream\"}"
        webSocket?.send(.string(closeMessage)) { [weak self] error in
            if let error = error {
                NSLog("⚠️ Deepgram: Error sending close: %@", error.localizedDescription)
            }
            self?.webSocket?.cancel(with: .normalClosure, reason: nil)
            self?.isConnected = false
            self?.isConnecting = false
            self?.isStreaming = false
            self?.cleanup()
            NSLog("🔌 Deepgram: Disconnected")

            DispatchQueue.main.async {
                self?.onDisconnected?()
            }
        }
    }

    /// Send audio data to Deepgram
    /// - Parameter audioData: Raw PCM Int16 audio data at 16kHz mono
    func sendAudio(_ audioData: Data) {
        guard isConnected, let webSocket = webSocket else {
            NSLog("⚠️ Deepgram: Not connected, can't send audio")
            return
        }

        isStreaming = true

        webSocket.send(.data(audioData)) { error in
            if let error = error {
                NSLog("❌ Deepgram: Error sending audio: %@", error.localizedDescription)
            }
        }
    }

    /// Signal end of audio stream (finalize current utterance)
    func finalizeUtterance() {
        guard isConnected else { return }

        let finalizeMessage = "{\"type\": \"Finalize\"}"
        webSocket?.send(.string(finalizeMessage)) { error in
            if let error = error {
                NSLog("⚠️ Deepgram: Error sending finalize: %@", error.localizedDescription)
            }
        }
    }

    /// Send keep-alive to maintain connection
    func keepAlive() {
        guard isConnected else { return }

        let keepAliveMessage = "{\"type\": \"KeepAlive\"}"
        webSocket?.send(.string(keepAliveMessage)) { _ in }
    }

    // MARK: - Private Methods

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleTextMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleTextMessage(text)
                    }
                @unknown default:
                    break
                }

                // Continue receiving
                if self.isConnected {
                    self.receiveMessage()
                }

            case .failure(let error):
                debugLog(.error, "❌ Deepgram: Receive error: \(error.localizedDescription)")
                self.isConnected = false
                self.isConnecting = false
                self.isStreaming = false
                self.keepAliveTask?.cancel()

                // Try to reconnect
                self.handleConnectionFailure()
            }
        }
    }

    private func handleTextMessage(_ text: String) {
        // Log ALL messages for debugging
        debugLog(.transcription, "📨 Deepgram RAW: \(String(text.prefix(300)))")

        guard let data = text.data(using: .utf8) else { return }

        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)

            // Handle different message types
            switch response.type {
            case "Results":
                handleTranscriptResults(response)
            case "Metadata":
                debugLog(.audio, "📋 Deepgram: Metadata received - connected!")
                DispatchQueue.main.async {
                    self.onConnected?()
                }
            case "SpeechStarted":
                debugLog(.audio, "🎤 Deepgram: Speech started")
            case "UtteranceEnd":
                debugLog(.audio, "🔚 Deepgram: Utterance end")
                // Finalize current utterance
                if !currentUtterance.isEmpty {
                    let final = currentUtterance.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !final.isEmpty {
                        DispatchQueue.main.async {
                            self.onFinalTranscript?(final)
                        }
                    }
                    currentUtterance = ""
                }
            default:
                debugLog(.audio, "📨 Deepgram: Unknown message type: \(response.type ?? "nil")")
            }

        } catch {
            // Try to parse as a simple error message - might be an error from Deepgram
            debugLog(.error, "⚠️ Deepgram: Parse error: \(error.localizedDescription) - Raw: \(String(text.prefix(300)))")
        }
    }

    private func handleTranscriptResults(_ response: DeepgramResponse) {
        guard let channel = response.channel,
              let alternatives = channel.alternatives,
              let firstAlt = alternatives.first else {
            return
        }

        let transcript = firstAlt.transcript ?? ""
        let isFinal = response.isFinal ?? false
        let speechFinal = response.speechFinal ?? false

        // Fire speech ended callback when Deepgram signals end of utterance
        // IMPORTANT: When speech_final=true and final transcript is empty,
        // use the last stored partial (currentUtterance) instead
        if speechFinal {
            debugLog(.transcription, "🔚 Deepgram: speech_final=true (utterance complete)")

            // If final is empty but we have a stored partial, send that instead
            if transcript.isEmpty && !currentUtterance.isEmpty {
                let partialToSend = currentUtterance.trimmingCharacters(in: .whitespacesAndNewlines)
                NSLog("🔄 Deepgram: Empty final, sending last partial: '%@'", partialToSend)
                DispatchQueue.main.async {
                    self.onFinalTranscript?(partialToSend)
                }
                currentUtterance = ""
            }

            DispatchQueue.main.async {
                self.onSpeechEnded?()
            }
        }

        if transcript.isEmpty { return }

        if isFinal {
            // Final result for this segment
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            NSLog("✅ Deepgram [FINAL]: '%@' (len=%d)", trimmed, trimmed.count)
            print("✅ Deepgram [FINAL]: '\(trimmed)' (len=\(trimmed.count))")

            // Only early-finalize on questions (?) - let UtteranceEnd handle statements
            // This prevents "ok." from cutting off "ok. tell me about OOP"
            let hasQuestionMark = trimmed.hasSuffix("?")

            // Also detect questions by question words (multilingual support)
            let lowerText = trimmed.lowercased()
            let questionStarts = [
                // English
                "what ", "how ", "why ", "when ", "where ", "which ", "who ",
                "can you", "could you", "would you", "do you", "does ", "is ", "are ",
                // Bulgarian
                "какво ", "как ", "защо ", "кога ", "къде ", "кой ", "коя ", "кое ",
                "може ли", "можеш ли", "знаеш ли",
                // German
                "was ", "wie ", "warum ", "wann ", "wo ", "wer ",
                // Spanish
                "qué ", "cómo ", "por qué", "cuándo ", "dónde ", "quién "
            ]
            let looksLikeQuestion = hasQuestionMark ||
                questionStarts.contains { lowerText.hasPrefix($0) }

            // Send any transcript with 4+ characters - let classifier handle relevance
            // This ensures tech terms like "HashMap" aren't filtered out
            if looksLikeQuestion || trimmed.count >= 4 {
                debugLog(.transcription, "🚀 Deepgram: Sending final: '\(trimmed)' (question=\(looksLikeQuestion), len=\(trimmed.count))")
                DispatchQueue.main.async {
                    self.onFinalTranscript?(trimmed)
                }
                currentUtterance = ""
            } else {
                // Very short (1-3 chars) - store for UtteranceEnd
                debugLog(.transcription, "⏳ Deepgram: Storing for UtteranceEnd: '\(trimmed)' (very short)")
                currentUtterance = trimmed
            }
        } else {
            // Interim result
            currentUtterance = transcript
            NSLog("📝 Deepgram [interim]: %@", transcript)

            DispatchQueue.main.async {
                self.onPartialTranscript?(transcript)
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension DeepgramStreamingClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        debugLog(.audio, "✅ Deepgram: WebSocket TCP connected!")
        isConnected = true
        isConnecting = false
        reconnectAttempt = 0

        // Cancel connection timeout
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil

        // Start keepAlive timer
        startKeepAliveTimer()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        debugLog(.audio, "🔌 Deepgram: WebSocket closed - code: \(closeCode.rawValue), reason: \(reasonStr)")
        let wasConnected = isConnected
        isConnected = false
        isConnecting = false
        isStreaming = false
        keepAliveTask?.cancel()

        // If unexpected close, try to reconnect
        if wasConnected && closeCode != .normalClosure {
            debugLog(.audio, "⚠️ Deepgram: Unexpected disconnect, attempting reconnect...")
            handleConnectionFailure()
        } else {
            DispatchQueue.main.async {
                self.onDisconnected?()
            }
        }
    }
}

// MARK: - Errors

enum DeepgramError: Error, LocalizedError {
    case maxReconnectAttemptsReached
    case connectionTimeout

    var errorDescription: String? {
        switch self {
        case .maxReconnectAttemptsReached:
            return "Failed to connect to Deepgram after maximum retry attempts"
        case .connectionTimeout:
            return "Connection to Deepgram timed out"
        }
    }
}

// MARK: - Response Models

private struct DeepgramResponse: Codable {
    let type: String?
    let requestId: String?
    let channel: DeepgramChannel?
    let isFinal: Bool?
    let speechFinal: Bool?
    let start: Double?
    let duration: Double?

    enum CodingKeys: String, CodingKey {
        case type
        case requestId = "request_id"
        case channel
        case isFinal = "is_final"
        case speechFinal = "speech_final"
        case start
        case duration
    }
}

private struct DeepgramChannel: Codable {
    let alternatives: [DeepgramAlternative]?
}

private struct DeepgramAlternative: Codable {
    let transcript: String?
    let confidence: Double?
    let words: [DeepgramWord]?
}

private struct DeepgramWord: Codable {
    let word: String?
    let start: Double?
    let end: Double?
    let confidence: Double?
}
