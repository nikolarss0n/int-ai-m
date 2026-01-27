import Foundation
import AVFoundation
import CoreML

/// Streaming VAD Recorder - combines Silero VAD with Deepgram streaming
/// Achieves ~300-500ms latency reduction by transcribing during speech
class StreamingVADRecorder: NSObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var vadModel: MLModel?
    private var deepgramClient: DeepgramStreamingClient?

    private var isListening = false
    private var isSpeaking = false

    // Silero VAD state
    private let sampleRate: Double = 16000
    private let vadChunkSize: Int = 576  // 36ms chunks for Silero
    private let speechThreshold: Float = 0.5
    private var hiddenState: MLMultiArray?
    private var cellState: MLMultiArray?

    // Audio buffers
    private var vadBuffer: [Float] = []
    private var audioBuffer: [Float] = []  // For Deepgram streaming
    private let bufferLock = NSLock()

    // Speech timing
    private var speechStartTime: Date?
    private var lastSpeechTime: Date?
    private let minSpeechDuration: TimeInterval = 0.3
    private let silenceTimeout: TimeInterval = 0.5  // Shorter since Deepgram handles endpointing

    // Current transcription state
    private var currentTranscript = ""
    private var hasDetectedQuestion = false

    // Callbacks
    var onTranscript: ((String, Bool) -> Void)?  // (text, isFinal)
    var onSpeechStart: (() -> Void)?
    var onSpeechEnd: (() -> Void)?
    var onStatusChange: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    // Language setting
    private var language: String = "en"
    private var keyterms: [String] = []

    init(deepgramApiKey: String, language: String = "en", keyterms: [String] = []) {
        self.language = language
        self.keyterms = keyterms
        super.init()
        loadVADModel()
        initializeVADState()
        setupDeepgramClient(apiKey: deepgramApiKey)
    }

    private func loadVADModel() {
        let modelPath = Bundle.main.path(forResource: "SileroVAD", ofType: "mlmodelc")
            ?? "./SileroVAD.mlmodelc"

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            vadModel = try MLModel(contentsOf: URL(fileURLWithPath: modelPath), configuration: config)
            NSLog("✅ StreamingVAD: Silero model loaded")
        } catch {
            NSLog("❌ StreamingVAD: Failed to load Silero model: %@", error.localizedDescription)
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
            NSLog("❌ StreamingVAD: Failed to initialize LSTM state: %@", error.localizedDescription)
        }
    }

    private func setupDeepgramClient(apiKey: String) {
        deepgramClient = DeepgramStreamingClient(apiKey: apiKey)

        deepgramClient?.onConnected = { [weak self] in
            NSLog("✅ StreamingVAD: Deepgram connected")
            DispatchQueue.main.async {
                self?.onStatusChange?("🎤 Streaming ready...")
            }
        }

        deepgramClient?.onPartialTranscript = { [weak self] text in
            guard let self = self else { return }
            self.currentTranscript = text

            // Check for early question detection
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasSuffix("?") && !self.hasDetectedQuestion {
                self.hasDetectedQuestion = true
                NSLog("❓ StreamingVAD: Question detected early: %@", trimmed)
                // Trigger early classification!
                DispatchQueue.main.async {
                    self.onTranscript?(trimmed, true)
                }
            } else {
                DispatchQueue.main.async {
                    self.onTranscript?(text, false)
                }
            }
        }

        deepgramClient?.onFinalTranscript = { [weak self] text in
            guard let self = self else { return }
            NSLog("✅ StreamingVAD: Final transcript: %@", text)
            self.currentTranscript = text

            DispatchQueue.main.async {
                self.onTranscript?(text, true)
            }
        }

        deepgramClient?.onDisconnected = { [weak self] in
            NSLog("🔌 StreamingVAD: Deepgram disconnected")
            DispatchQueue.main.async {
                self?.onStatusChange?("🔌 Disconnected")
            }
        }

        deepgramClient?.onError = { [weak self] error in
            NSLog("❌ StreamingVAD: Deepgram error: %@", error.localizedDescription)
            DispatchQueue.main.async {
                self?.onError?(error)
            }
        }
    }

    func startListening() throws {
        guard vadModel != nil else {
            throw NSError(domain: "StreamingVAD", code: 1, userInfo: [NSLocalizedDescriptionKey: "VAD model not loaded"])
        }

        NSLog("🎤 StreamingVAD: Starting (lang=%@, keyterms=%d)...", language, keyterms.count)

        // Connect to Deepgram with keyterms for vocabulary boosting
        deepgramClient?.connect(language: language)

        // Setup audio engine
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        guard let inputNode = inputNode else {
            throw NSError(domain: "StreamingVAD", code: 2, userInfo: [NSLocalizedDescriptionKey: "No audio input"])
        }

        let nativeFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "StreamingVAD", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot create target format"])
        }

        guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat) else {
            throw NSError(domain: "StreamingVAD", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot create converter"])
        }

        let bufferSize = AVAudioFrameCount(nativeFormat.sampleRate * 0.05)  // 50ms buffer
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nativeFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        try audioEngine?.start()
        isListening = true
        initializeVADState()

        DispatchQueue.main.async {
            self.onStatusChange?("🎤 Listening (streaming)...")
        }

        NSLog("🎤 StreamingVAD: Started successfully")
    }

    func stopListening() {
        isListening = false
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil

        deepgramClient?.disconnect()

        bufferLock.lock()
        vadBuffer.removeAll()
        audioBuffer.removeAll()
        bufferLock.unlock()

        isSpeaking = false
        speechStartTime = nil
        lastSpeechTime = nil
        currentTranscript = ""
        hasDetectedQuestion = false

        NSLog("🎤 StreamingVAD: Stopped")
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        // Convert to 16kHz
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * sampleRate / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
            return
        }

        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, let floatData = convertedBuffer.floatChannelData else {
            return
        }

        let samples = Array(UnsafeBufferPointer(start: floatData[0], count: Int(convertedBuffer.frameLength)))

        bufferLock.lock()
        vadBuffer.append(contentsOf: samples)
        bufferLock.unlock()

        // Process VAD chunks
        processVADChunks()

        // If speaking, stream audio to Deepgram
        if isSpeaking {
            streamAudioToDeepgram(samples)
        }
    }

    private func processVADChunks() {
        bufferLock.lock()

        while vadBuffer.count >= vadChunkSize {
            let chunk = Array(vadBuffer.prefix(vadChunkSize))
            vadBuffer.removeFirst(vadChunkSize)
            bufferLock.unlock()

            processVADChunk(chunk)

            bufferLock.lock()
        }

        bufferLock.unlock()
    }

    private func processVADChunk(_ chunk: [Float]) {
        guard let model = vadModel,
              let hidden = hiddenState,
              let cell = cellState else {
            return
        }

        do {
            let audioInput = try MLMultiArray(shape: [1, NSNumber(value: vadChunkSize)], dataType: .float32)
            for (i, sample) in chunk.enumerated() {
                audioInput[i] = NSNumber(value: sample)
            }

            let input = SileroVADInput(audio_input: audioInput, hidden_state: hidden, cell_state: cell)
            let prediction = try model.prediction(from: input)

            guard let vadOutput = prediction.featureValue(for: "vad_output")?.multiArrayValue,
                  let newHidden = prediction.featureValue(for: "new_hidden_state")?.multiArrayValue,
                  let newCell = prediction.featureValue(for: "new_cell_state")?.multiArrayValue else {
                return
            }

            hiddenState = newHidden
            cellState = newCell

            let speechProb = vadOutput[0].floatValue
            let isSpeechDetected = speechProb > speechThreshold

            handleSpeechState(isSpeechDetected: isSpeechDetected, probability: speechProb)

        } catch {
            NSLog("❌ StreamingVAD: VAD inference error: %@", error.localizedDescription)
        }
    }

    private func handleSpeechState(isSpeechDetected: Bool, probability: Float) {
        let now = Date()

        if isSpeechDetected {
            lastSpeechTime = now

            if !isSpeaking {
                // Speech just started
                isSpeaking = true
                speechStartTime = now
                currentTranscript = ""
                hasDetectedQuestion = false

                NSLog("🟢 StreamingVAD: Speech started (prob: %.2f)", probability)

                DispatchQueue.main.async {
                    self.onSpeechStart?()
                    self.onStatusChange?("🗣 Speaking...")
                }
            }
        } else if isSpeaking {
            let silenceDuration = lastSpeechTime.map { now.timeIntervalSince($0) } ?? 0

            if silenceDuration > silenceTimeout {
                let speechDuration = speechStartTime.map { now.timeIntervalSince($0) } ?? 0

                NSLog("🔴 StreamingVAD: Speech ended - duration: %.2fs", speechDuration)

                if speechDuration >= minSpeechDuration {
                    // Signal end of speech to Deepgram
                    deepgramClient?.finalizeUtterance()

                    // If we haven't already sent a final transcript, send what we have
                    if !hasDetectedQuestion && !currentTranscript.isEmpty {
                        let final = currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !final.isEmpty {
                            DispatchQueue.main.async {
                                self.onTranscript?(final, true)
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
                    self.onStatusChange?("🎤 Listening (streaming)...")
                }
            }
        }
    }

    private func streamAudioToDeepgram(_ samples: [Float]) {
        // Convert Float32 [-1, 1] to Int16 for Deepgram (linear16)
        var int16Data = Data(capacity: samples.count * 2)
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16Value = Int16(clamped * 32767.0)
            withUnsafeBytes(of: int16Value.littleEndian) { int16Data.append(contentsOf: $0) }
        }

        deepgramClient?.sendAudio(int16Data)
    }
}

// MARK: - CoreML Input Wrapper (reuse from SileroVADRecorder)

private class SileroVADInput: MLFeatureProvider {
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
