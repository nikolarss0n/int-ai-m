import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreML

/// Captures system audio (Zoom, Teams, etc.) using ScreenCaptureKit
/// Supports two modes:
/// - Batch mode: Records speech, converts to M4A, sends to Whisper (default)
/// - Streaming mode: Silero VAD + Deepgram Nova-3 for ~300-500ms faster results
@available(macOS 13.0, *)
class SystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var isCapturing = false
    private var retryCount = 0
    private let maxRetries = 3
    private var retryTask: Task<Void, Never>?

    // VAD parameters (matching VADAudioRecorder) - used in batch mode
    private let speechMargin: Float = 18.0
    private let silenceMargin: Float = 10.0
    private let minSpeechDuration: TimeInterval = 0.6
    private let absoluteMinSpeechDb: Float = -35.0
    private let silenceTimeout: TimeInterval = 0.8
    private let baselineWindowSize: Int = 40
    private let baselineUpdateInterval: Int = 5

    // Baseline tracking
    private var baselineBuffer: [Float] = []
    private var currentBaseline: Float = -60.0
    private var baselineUpdateCount: Int = 0

    // State tracking
    private var isSpeaking = false
    private var speechStartTime: Date?
    private var lastSpeechTime: Date?
    private var peakLevel: Float = -100.0

    // Audio recording (batch mode)
    private var recordedSamples: [Float] = []
    private var sampleRate: Double = 48000.0

    // Callbacks
    var onLevelUpdate: ((Float, Bool) -> Void)?
    var onSpeechSegment: ((Data) -> Void)?
    var onStatusChange: ((String) -> Void)?

    // STREAMING MODE: Deepgram Nova-3 + Silero VAD
    private var streamingMode = false
    private var deepgramClient: DeepgramStreamingClient?
    private var streamingLanguage: String = "en"
    private var streamingKeyterms: [String] = []

    // DUAL-STREAM MODE: Two Deepgram streams (primary + English) for multilingual transcription
    private var dualStreamMode = false
    private var dualStreamTranscriber: DualStreamTranscriber?
    private var anthropicApiKey: String?
    private var vadModel: MLModel?
    private var hiddenState: MLMultiArray?
    private var cellState: MLMultiArray?
    private let vadChunkSize: Int = 576  // 36ms chunks at 16kHz
    private let sileroSpeechThreshold: Float = 0.5
    private var vadBuffer: [Float] = []
    private var streamingSilenceTimeout: TimeInterval = 0.4

    // Streaming callbacks
    var onTranscript: ((String, Bool) -> Void)?  // (text, isFinal)
    var onSpeechStart: (() -> Void)?
    var onSpeechEnd: (() -> Void)?
    var onError: ((Error) -> Void)?

    // Transcript accumulation for streaming
    private var currentTranscript = ""
    private var hasDetectedQuestion = false

    // Keep-alive timer for Deepgram connection
    private var keepAliveTimer: Timer?
    private let keepAliveInterval: TimeInterval = 5.0

    private var speechThreshold: Float { currentBaseline + speechMargin }
    private var silenceThreshold: Float { currentBaseline + silenceMargin }

    // MARK: - Streaming Mode Setup

    /// Enable streaming mode with Deepgram Nova-3 + Silero VAD
    /// - Parameters:
    ///   - deepgramApiKey: Deepgram API key
    ///   - language: Language code ("en", "bg", "multi" for multilingual code-switching)
    ///   - keyterms: Technical terms to boost recognition (e.g., ["hashmap", "LinkedList"])
    func enableStreamingMode(deepgramApiKey: String, language: String = "en", keyterms: [String] = []) {
        streamingMode = true
        streamingKeyterms = keyterms
        loadVADModel()
        initializeVADState()
        setupDeepgramClient(apiKey: deepgramApiKey, language: language)
        NSLog("🎤 SystemAudio: Streaming mode enabled (lang=%@, keyterms=%d)", language, keyterms.count)
    }

    /// Enable dual-stream mode for multilingual transcription with technical term fixing
    /// - Parameters:
    ///   - deepgramApiKey: Deepgram API key
    ///   - anthropicApiKey: Anthropic API key (for Claude Haiku merge)
    ///   - primaryLanguage: Primary language code ("bg", "de", etc.) - English stream runs automatically
    ///   - keyterms: Technical terms to boost recognition
    func enableDualStreamMode(deepgramApiKey: String, anthropicApiKey: String, primaryLanguage: String, keyterms: [String] = []) {
        dualStreamMode = true
        streamingMode = true  // Dual mode is a variant of streaming mode
        self.anthropicApiKey = anthropicApiKey
        streamingLanguage = primaryLanguage
        streamingKeyterms = keyterms

        loadVADModel()
        initializeVADState()
        setupDualStreamTranscriber(deepgramApiKey: deepgramApiKey, anthropicApiKey: anthropicApiKey, primaryLanguage: primaryLanguage)
        NSLog("🎤 SystemAudio: DUAL-STREAM mode enabled (primary=%@, secondary=en, keyterms=%d)", primaryLanguage, keyterms.count)
    }

    private func setupDualStreamTranscriber(deepgramApiKey: String, anthropicApiKey: String, primaryLanguage: String) {
        dualStreamTranscriber = DualStreamTranscriber(
            deepgramApiKey: deepgramApiKey,
            anthropicApiKey: anthropicApiKey,
            primaryLanguage: primaryLanguage
        )

        dualStreamTranscriber?.onConnected = { [weak self] in
            debugLog(.audio, "✅ DualStream CONNECTED (both streams)")
            DispatchQueue.main.async {
                self?.onStatusChange?("🔊 Dual-stream ready...")
            }
        }

        dualStreamTranscriber?.onPartialTranscript = { [weak self] text in
            guard let self = self else { return }
            self.currentTranscript = text

            // In dual-stream mode, DON'T send early finals - let DualStreamTranscriber handle all finals
            // Just show partials for UI feedback
            DispatchQueue.main.async {
                self.onTranscript?(text, false)
            }
        }

        dualStreamTranscriber?.onFinalTranscript = { [weak self] text in
            guard let self = self else { return }
            debugLog(.transcription, "✅ FINAL transcript (dual): '\(text)'")
            self.currentTranscript = text
            self.hasDetectedQuestion = true

            DispatchQueue.main.async {
                self.onTranscript?(text, true)
            }
        }

        dualStreamTranscriber?.onDisconnected = { [weak self] in
            debugLog(.audio, "🔌 DualStream DISCONNECTED")
            DispatchQueue.main.async {
                self?.onStatusChange?("🔌 Disconnected")
            }
        }

        dualStreamTranscriber?.onError = { [weak self] error in
            debugLog(.error, "❌ DualStream ERROR: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self?.onError?(error)
            }
        }
    }

    private func loadVADModel() {
        let modelPath = Bundle.main.path(forResource: "SileroVAD", ofType: "mlmodelc")
            ?? "./SileroVAD.mlmodelc"

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            vadModel = try MLModel(contentsOf: URL(fileURLWithPath: modelPath), configuration: config)
            NSLog("✅ SystemAudio: Silero VAD model loaded")
        } catch {
            NSLog("❌ SystemAudio: Failed to load Silero model: %@", error.localizedDescription)
        }
    }

    private func initializeVADState() {
        do {
            hiddenState = try MLMultiArray(shape: [1, 128], dataType: .float32)
            cellState = try MLMultiArray(shape: [1, 128], dataType: .float32)
            for i in 0..<128 {
                hiddenState?[i] = 0.0
                cellState?[i] = 0.0
            }
        } catch {
            NSLog("❌ SystemAudio: Failed to initialize LSTM state: %@", error.localizedDescription)
        }
    }

    private func setupDeepgramClient(apiKey: String, language: String) {
        deepgramClient = DeepgramStreamingClient(apiKey: apiKey)

        deepgramClient?.onConnected = { [weak self] in
            debugLog(.audio, "✅ Deepgram CONNECTED successfully!")
            NSLog("✅ SystemAudio: Deepgram connected")
            DispatchQueue.main.async {
                self?.onStatusChange?("🔊 Streaming ready...")
            }
        }

        deepgramClient?.onPartialTranscript = { [weak self] text in
            guard let self = self else { return }
            self.currentTranscript = text

            // Send partials for UI feedback only (never final=true)
            DispatchQueue.main.async {
                self.onTranscript?(text, false)
            }
        }

        deepgramClient?.onFinalTranscript = { [weak self] text in
            guard let self = self else { return }
            debugLog(.transcription, "✅ FINAL transcript from Deepgram: '\(text)'")
            self.currentTranscript = text

            DispatchQueue.main.async {
                debugLog(.transcription, "📤 Sending FINAL to processor: '\(text)'")
                self.onTranscript?(text, true)
            }
        }

        deepgramClient?.onDisconnected = { [weak self] in
            debugLog(.audio, "🔌 Deepgram DISCONNECTED")
            NSLog("🔌 SystemAudio: Deepgram disconnected")
            DispatchQueue.main.async {
                self?.onStatusChange?("🔌 Disconnected")
            }
        }

        deepgramClient?.onError = { [weak self] error in
            debugLog(.error, "❌ Deepgram ERROR: \(error.localizedDescription)")
            NSLog("❌ SystemAudio: Deepgram error: %@", error.localizedDescription)
            DispatchQueue.main.async {
                self?.onError?(error)
            }
        }

        // Save language - will connect after capture starts
        streamingLanguage = language
    }

    // MARK: - Capture Control

    func startCapturing() async throws {
        debugLog(.audio, "SystemAudio: Starting capture...")

        // Check and request screen recording permission
        let hasPermission = CGPreflightScreenCaptureAccess()
        debugLog(.audio, "SystemAudio: Screen recording permission = \(hasPermission)")

        if !hasPermission {
            debugLog(.audio, "SystemAudio: Requesting screen recording permission...")
            CGRequestScreenCaptureAccess()
            // Wait a moment for permission dialog
            try await Task.sleep(nanoseconds: 1_000_000_000)

            let nowHasPermission = CGPreflightScreenCaptureAccess()
            debugLog(.audio, "SystemAudio: After request, permission = \(nowHasPermission)")
            if !nowHasPermission {
                throw NSError(domain: "SystemAudioCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Screen recording permission denied"])
            }
        }

        let content = try await SCShareableContent.current
        debugLog(.audio, "SystemAudio: Found \(content.displays.count) displays, \(content.applications.count) apps")

        guard let display = content.displays.first else {
            debugLog(.error, "SystemAudio: No display found!")
            throw NSError(domain: "SystemAudioCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }
        debugLog(.audio, "SystemAudio: Using display \(display.displayID)")

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()

        // Minimal video (required but unused)
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        // Audio settings
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 1

        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "system.audio.capture"))
        debugLog(.audio, "SystemAudio: Starting stream capture...")
        try await stream?.startCapture()

        isCapturing = true
        baselineBuffer = []
        currentBaseline = -60.0

        // Connect to Deepgram AFTER capture is working (streaming mode only)
        if streamingMode {
            if dualStreamMode {
                // DUAL-STREAM: Connect both primary + English streams
                debugLog(.audio, "🔌 Connecting DUAL streams (primary=\(streamingLanguage), secondary=en)...")
                NSLog("🔊 SystemAudio: Connecting dual streams...")
                dualStreamTranscriber?.connect(keyterms: streamingKeyterms)

                // Keep-alive for dual stream
                DispatchQueue.main.async {
                    self.keepAliveTimer = Timer.scheduledTimer(withTimeInterval: self.keepAliveInterval, repeats: true) { [weak self] _ in
                        self?.dualStreamTranscriber?.keepAlive()
                    }
                }
            } else {
                // SINGLE-STREAM: Original behavior
                debugLog(.audio, "🔌 Connecting to Deepgram (lang=\(streamingLanguage), keyterms=\(streamingKeyterms.count))...")
                NSLog("🔊 SystemAudio: Connecting to Deepgram...")
                deepgramClient?.connect(language: streamingLanguage, keyterms: streamingKeyterms)

                // Start keep-alive timer to prevent Deepgram timeout during answer generation
                DispatchQueue.main.async {
                    self.keepAliveTimer = Timer.scheduledTimer(withTimeInterval: self.keepAliveInterval, repeats: true) { [weak self] _ in
                        self?.deepgramClient?.keepAlive()
                    }
                }
            }
        }

        debugLog(.audio, "SystemAudio: Capture started successfully!")
        DispatchQueue.main.async {
            self.onStatusChange?(self.streamingMode ? "🔊 Listening (streaming)..." : "🔊 Listening to system audio...")
        }
    }

    func stopCapturing() async {
        NSLog("🔊 SystemAudio: Stopping capture")
        isCapturing = false
        retryTask?.cancel()
        retryTask = nil
        retryCount = 0
        try? await stream?.stopCapture()
        stream = nil

        // Cleanup streaming mode
        if streamingMode {
            keepAliveTimer?.invalidate()
            keepAliveTimer = nil

            if dualStreamMode {
                dualStreamTranscriber?.disconnect()
            } else {
                deepgramClient?.disconnect()
            }

            vadBuffer.removeAll()
            currentTranscript = ""
            hasDetectedQuestion = false
            initializeVADState()
        }
    }

    // MARK: - SCStreamOutput

    private var formatLogged = false

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, isCapturing else { return }

        // Log format once
        if !formatLogged, let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
            if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee {
                debugLog(.audio, "🔊 SysAudio FORMAT: sampleRate=\(asbd.mSampleRate), channels=\(asbd.mChannelsPerFrame), bitsPerChannel=\(asbd.mBitsPerChannel), bytesPerFrame=\(asbd.mBytesPerFrame)")
                sampleRate = asbd.mSampleRate
            }
            formatLogged = true
        }

        // Get audio buffer list
        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList()
        var size = MemoryLayout<AudioBufferList>.size

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else {
            NSLog("🔊 SysAudio: Failed to get audio buffer: %d", status)
            return
        }

        // Extract samples from buffer
        let buffer = audioBufferList.mBuffers
        guard let data = buffer.mData else { return }

        // ScreenCaptureKit provides 32-bit float samples at 48kHz
        let floatCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        let floatPointer = data.bindMemory(to: Float.self, capacity: floatCount)
        let samples48k = Array(UnsafeBufferPointer(start: floatPointer, count: floatCount))

        if streamingMode {
            // STREAMING MODE: Silero VAD + Deepgram
            processStreamingAudio(samples48k)
        } else {
            // BATCH MODE: dB-threshold VAD + batch Whisper
            processBatchAudio(samples48k)
        }
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        debugLog(.error, "SystemAudio stream error: \(error.localizedDescription)")
        debugLog(.error, "Full error: \(error)")

        let nsError = error as NSError
        let isRecoverableError = nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && nsError.code == -3805

        if isRecoverableError && retryCount < maxRetries {
            retryCount += 1
            let delay = pow(2.0, Double(retryCount)) // Exponential backoff: 2, 4, 8 seconds
            debugLog(.audio, "SystemAudio: Retrying capture in \(delay)s (attempt \(retryCount)/\(maxRetries))")

            DispatchQueue.main.async {
                self.onStatusChange?("⚠️ Reconnecting... (attempt \(self.retryCount)/\(self.maxRetries))")
            }

            retryTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }

                do {
                    try await self.startCapturing()
                    self.retryCount = 0 // Reset on success
                } catch {
                    debugLog(.error, "SystemAudio: Retry failed: \(error.localizedDescription)")
                }
            }
        } else {
            isCapturing = false
            retryCount = 0
            DispatchQueue.main.async {
                self.onStatusChange?("⚠️ System audio stopped: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Batch Mode Audio Processing

    private func processBatchAudio(_ samples: [Float]) {
        // Calculate RMS level
        var rmsSum: Float = 0
        for sample in samples { rmsSum += sample * sample }
        let rms = sqrt(rmsSum / Float(max(samples.count, 1)))
        let db = 20 * log10(max(rms, 0.0000001))

        if isSpeaking {
            recordedSamples.append(contentsOf: samples)
        }

        processVAD(db: db)
    }

    // MARK: - Streaming Mode Audio Processing

    private func processStreamingAudio(_ samples48k: [Float]) {
        // Resample 48kHz → 16kHz (factor of 3)
        let samples16k = resampleTo16k(samples48k)

        // Calculate level for UI
        var rmsSum: Float = 0
        for sample in samples16k { rmsSum += sample * sample }
        let rms = sqrt(rmsSum / Float(max(samples16k.count, 1)))
        let db = 20 * log10(max(rms, 0.0000001))

        DispatchQueue.main.async {
            self.onLevelUpdate?(db, self.isSpeaking)
        }

        // Accumulate for Silero VAD processing
        vadBuffer.append(contentsOf: samples16k)

        // Process VAD chunks (576 samples = 36ms at 16kHz)
        while vadBuffer.count >= vadChunkSize {
            let chunk = Array(vadBuffer.prefix(vadChunkSize))
            vadBuffer.removeFirst(vadChunkSize)
            processSileroVADChunk(chunk)
        }

        // If speaking, stream to Deepgram
        if isSpeaking {
            streamToDeepgram(samples16k)
        }
    }

    private func resampleTo16k(_ input: [Float]) -> [Float] {
        // Simple decimation with averaging (48kHz → 16kHz, factor of 3)
        let ratio = 3
        let outputLength = input.count / ratio
        guard outputLength > 0 else { return [] }

        var output = [Float](repeating: 0, count: outputLength)
        for i in 0..<outputLength {
            let start = i * ratio
            let end = min(start + ratio, input.count)
            var sum: Float = 0
            for j in start..<end { sum += input[j] }
            output[i] = sum / Float(end - start)
        }
        return output
    }

    private func processSileroVADChunk(_ chunk: [Float]) {
        guard let model = vadModel,
              let hidden = hiddenState,
              let cell = cellState else { return }

        do {
            let audioInput = try MLMultiArray(shape: [1, NSNumber(value: vadChunkSize)], dataType: .float32)
            for (i, sample) in chunk.enumerated() {
                audioInput[i] = NSNumber(value: sample)
            }

            let input = SystemAudioSileroVADInput(audio_input: audioInput, hidden_state: hidden, cell_state: cell)
            let prediction = try model.prediction(from: input)

            guard let vadOutput = prediction.featureValue(for: "vad_output")?.multiArrayValue,
                  let newHidden = prediction.featureValue(for: "new_hidden_state")?.multiArrayValue,
                  let newCell = prediction.featureValue(for: "new_cell_state")?.multiArrayValue else { return }

            hiddenState = newHidden
            cellState = newCell

            let speechProb = vadOutput[0].floatValue
            handleStreamingSpeechState(isSpeechDetected: speechProb > sileroSpeechThreshold, probability: speechProb)

        } catch {
            NSLog("❌ SystemAudio: Silero VAD error: %@", error.localizedDescription)
        }
    }

    private func handleStreamingSpeechState(isSpeechDetected: Bool, probability: Float) {
        let now = Date()

        if isSpeechDetected {
            lastSpeechTime = now

            if !isSpeaking {
                isSpeaking = true
                speechStartTime = now
                currentTranscript = ""
                hasDetectedQuestion = false

                NSLog("🟢 SystemAudio: Speech started (Silero prob: %.2f)", probability)

                DispatchQueue.main.async {
                    self.onSpeechStart?()
                    self.onStatusChange?("🗣 Interviewer speaking...")
                }
            }
        } else if isSpeaking {
            let silenceDuration = lastSpeechTime.map { now.timeIntervalSince($0) } ?? 0

            if silenceDuration > streamingSilenceTimeout {
                let speechDuration = speechStartTime.map { now.timeIntervalSince($0) } ?? 0
                NSLog("🔴 SystemAudio: Speech ended - duration: %.2fs", speechDuration)

                if speechDuration >= minSpeechDuration {
                    // Signal end of speech to Deepgram
                    if dualStreamMode {
                        dualStreamTranscriber?.finalizeUtterance()
                        // In dual-stream mode, DualStreamTranscriber handles all finals
                    } else {
                        deepgramClient?.finalizeUtterance()

                        // Send current transcript as final if not already sent (single-stream only)
                        if !hasDetectedQuestion && !currentTranscript.isEmpty {
                            let final = currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !final.isEmpty {
                                DispatchQueue.main.async {
                                    self.onTranscript?(final, true)
                                }
                            }
                        }
                    }
                }

                // Reset state
                isSpeaking = false
                speechStartTime = nil
                initializeVADState()

                DispatchQueue.main.async {
                    self.onSpeechEnd?()
                    self.onStatusChange?("🔊 Listening (streaming)...")
                }
            }
        }
    }

    private var audioSentCount = 0
    private var totalAudioBytes = 0

    private func streamToDeepgram(_ samples: [Float]) {
        // Convert Float32 [-1, 1] to Int16 for Deepgram (linear16)
        var int16Data = Data(capacity: samples.count * 2)
        var maxSample: Float = 0
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            maxSample = max(maxSample, abs(clamped))
            let int16Value = Int16(clamped * 32767.0)
            withUnsafeBytes(of: int16Value.littleEndian) { int16Data.append(contentsOf: $0) }
        }

        audioSentCount += 1
        totalAudioBytes += int16Data.count

        // Log every 10th chunk to avoid spam
        if audioSentCount % 10 == 1 {
            debugLog(.audio, "📤 Deepgram: Sending audio chunk #\(audioSentCount), \(int16Data.count) bytes, peak=\(String(format: "%.3f", maxSample)), total=\(totalAudioBytes) bytes")
        }

        // Route to dual stream or single stream
        if dualStreamMode {
            dualStreamTranscriber?.sendAudio(int16Data)
        } else {
            deepgramClient?.sendAudio(int16Data)
        }
    }

    // MARK: - Batch Mode VAD

    private var checkCount = 0

    private func updateBaseline(_ db: Float) {
        guard !isSpeaking && db > -90.0 && db < -20.0 else { return }

        baselineUpdateCount += 1
        guard baselineUpdateCount >= baselineUpdateInterval else { return }
        baselineUpdateCount = 0

        baselineBuffer.append(db)
        if baselineBuffer.count > baselineWindowSize {
            baselineBuffer.removeFirst()
        }

        if baselineBuffer.count >= 10 {
            let sorted = baselineBuffer.sorted()
            let quietHalf = Array(sorted.prefix(sorted.count / 2))
            let newBaseline = quietHalf.reduce(0, +) / Float(quietHalf.count)
            currentBaseline = currentBaseline * 0.7 + newBaseline * 0.3
        }
    }

    private func processVAD(db: Float) {
        let now = Date()
        checkCount += 1

        updateBaseline(db)

        if checkCount % 100 == 0 {
            NSLog("🔊 SysVAD[%d]: db=%.1f, baseline=%.1f, speaking=%@",
                  checkCount, db, currentBaseline, isSpeaking ? "YES" : "NO")
        }

        DispatchQueue.main.async {
            self.onLevelUpdate?(db, self.isSpeaking)
        }

        let isAboveSpeech = db > speechThreshold && db > absoluteMinSpeechDb

        if isAboveSpeech {
            lastSpeechTime = now
            peakLevel = max(peakLevel, db)

            if !isSpeaking {
                isSpeaking = true
                speechStartTime = now
                peakLevel = db
                recordedSamples = []

                NSLog("🟢 SysAudio: Speech STARTED - db=%.1f", db)
                DispatchQueue.main.async {
                    self.onStatusChange?("🗣 Interviewer speaking...")
                }
            }
        } else if isSpeaking {
            let nearBaseline = db < silenceThreshold
            let silenceDuration = lastSpeechTime.map { now.timeIntervalSince($0) } ?? 0

            if nearBaseline && silenceDuration > silenceTimeout {
                let speechDuration = speechStartTime.map { now.timeIntervalSince($0) } ?? 0
                let peakAboveBaseline = peakLevel - currentBaseline

                NSLog("🔴 SysAudio: Speech ENDED - duration=%.2fs", speechDuration)

                if speechDuration > minSpeechDuration && peakAboveBaseline >= speechMargin * 0.5 {
                    if let audioData = convertSamplesToM4A() {
                        NSLog("✅ SysAudio: Processing %.2fs (%d bytes)", speechDuration, audioData.count)
                        DispatchQueue.main.async {
                            self.onStatusChange?("⏳ Processing...")
                            self.onSpeechSegment?(audioData)
                        }
                    }
                }

                isSpeaking = false
                speechStartTime = nil
                peakLevel = -100.0
                recordedSamples = []

                DispatchQueue.main.async {
                    self.onStatusChange?("🔊 Listening to system audio...")
                }
            }
        }
    }

    private func convertSamplesToM4A() -> Data? {
        guard !recordedSamples.isEmpty else { return nil }

        // Write to temp WAV file, then convert to M4A for Whisper compatibility
        let tempDir = FileManager.default.temporaryDirectory
        let wavURL = tempDir.appendingPathComponent("sysaudio_\(UUID().uuidString).wav")
        let m4aURL = tempDir.appendingPathComponent("sysaudio_\(UUID().uuidString).m4a")

        defer {
            try? FileManager.default.removeItem(at: wavURL)
            try? FileManager.default.removeItem(at: m4aURL)
        }

        // Create WAV data
        var wavData = Data(createWAVHeader(sampleCount: recordedSamples.count))
        for sample in recordedSamples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16 = Int16(clamped * Float(Int16.max))
            withUnsafeBytes(of: int16.littleEndian) { wavData.append(contentsOf: $0) }
        }

        do {
            try wavData.write(to: wavURL)

            // Convert to M4A using AVAssetWriter
            let asset = AVAsset(url: wavURL)
            let reader = try AVAssetReader(asset: asset)

            guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
                NSLog("❌ SysAudio: No audio track in WAV")
                return wavData // Fall back to WAV
            }

            let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ])
            reader.add(readerOutput)

            let writer = try AVAssetWriter(outputURL: m4aURL, fileType: .m4a)
            let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000
            ])
            writer.add(writerInput)

            reader.startReading()
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            let queue = DispatchQueue(label: "audio.convert")
            let semaphore = DispatchSemaphore(value: 0)

            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let buffer = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(buffer)
                    } else {
                        writerInput.markAsFinished()
                        semaphore.signal()
                        break
                    }
                }
            }

            semaphore.wait()
            writer.finishWriting {}

            // Wait for writer to finish
            while writer.status == .writing {
                Thread.sleep(forTimeInterval: 0.01)
            }

            if writer.status == .completed {
                return try Data(contentsOf: m4aURL)
            } else {
                NSLog("❌ SysAudio: Writer failed: %@", writer.error?.localizedDescription ?? "unknown")
                return wavData
            }
        } catch {
            NSLog("❌ SysAudio: Conversion error: %@", error.localizedDescription)
            return wavData
        }
    }

    private func createWAVHeader(sampleCount: Int) -> [UInt8] {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(Int(sampleRate) * Int(channels) * Int(bitsPerSample) / 8)
        let blockAlign = UInt16(channels * bitsPerSample / 8)
        let dataSize = UInt32(sampleCount * Int(blockAlign))
        let fileSize = dataSize + 36

        var header = [UInt8]()
        header.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // RIFF
        header.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        header.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // WAVE
        header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // fmt
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        header.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // data
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        return header
    }
}

// MARK: - CoreML Input Wrapper for Silero VAD

private class SystemAudioSileroVADInput: MLFeatureProvider {
    let audio_input: MLMultiArray
    let hidden_state: MLMultiArray
    let cell_state: MLMultiArray

    var featureNames: Set<String> {
        return ["audio_input", "hidden_state", "cell_state"]
    }

    init(audio_input: MLMultiArray, hidden_state: MLMultiArray, cell_state: MLMultiArray) {
        self.audio_input = audio_input
        self.hidden_state = hidden_state
        self.cell_state = cell_state
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "audio_input": return MLFeatureValue(multiArray: audio_input)
        case "hidden_state": return MLFeatureValue(multiArray: hidden_state)
        case "cell_state": return MLFeatureValue(multiArray: cell_state)
        default: return nil
        }
    }
}
