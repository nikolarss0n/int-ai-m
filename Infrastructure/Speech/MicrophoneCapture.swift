import Foundation
import AVFoundation

@available(macOS 13.0, *)
final class MicrophoneCapture: AudioCaptureCallbacks, AudioSourceCapture, @unchecked Sendable {
    let captureDevice = CaptureDevice.microphone
    private let lifecycleQueue = DispatchQueue(label: "interview.microphone.lifecycle")
    private var engine: AVAudioEngine?
    private var observer: NSObjectProtocol?
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var inputFormat: AVAudioFormat?
    private var tapInstalled = false
    private var generation: UInt64 = 0
    private var formatGeneration: UInt64 = 0
    private var wantsCapture = false
    private var isCapturing = false
    private var isStopped = false
    private var muted = false
    private lazy var detector = SpeechTurnDetector(labels: .microphone, tuning: .microphoneExperimental,
        logTag: "MicVAD-UNMEASURED",
        emitTurn: { [weak self] in self?.dispatchTurn($0, audio: $1) },
        emitLevel: { [weak self] in self?.dispatchLevel($0, speaking: $1) },
        emitStatus: { [weak self] in self?.dispatchStatus($0) })

    func startCapturing() async throws {
        let request: UInt64 = try lifecycleQueue.sync {
            guard !isStopped, !wantsCapture else { throw CancellationError() }
            generation &+= 1
            wantsCapture = true
            _ = detector
            return generation
        }
        do {
            // Do not instantiate/access an input engine before TCC authorization.
            try await AudioCaptureFactory.preflight(.microphone, allowPrompt: false)
            try Task.checkCancellation()
            try lifecycleQueue.sync {
                guard wantsCapture, generation == request else { throw CancellationError() }
                let engine = AVAudioEngine()
                self.engine = engine
                observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange,
                    object: engine, queue: nil) { [weak self] _ in
                        self?.lifecycleQueue.async { [weak self] in self?.recoverConfiguration(request: request) }
                    }
                try configureAndStart(engine, request: request)
                dispatchStatus(muted ? SpeechTurnDetector.Labels.microphone.muted : SpeechTurnDetector.Labels.microphone.idle)
            }
        } catch {
            stopCapturingSync()
            throw error
        }
    }

    private func configureAndStart(_ engine: AVAudioEngine, request: UInt64) throws {
        guard wantsCapture, generation == request else { throw CancellationError() }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0,
              let mono48k = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                                         channels: 1, interleaved: false) else {
            throw captureError("The default microphone has no usable audio format.")
        }
        inputFormat = format
        outputFormat = mono48k
        let isPassthrough = format.sampleRate == mono48k.sampleRate && format.channelCount == 1 &&
            format.commonFormat == .pcmFormatFloat32 && !format.isInterleaved
        converter = isPassthrough ? nil : AVAudioConverter(from: format, to: mono48k)
        if !isPassthrough && converter == nil { throw captureError("The microphone format could not be converted.") }
        detector.reset()
        detector.setSampleRate(mono48k.sampleRate)
        detector.setMuted(muted)
        formatGeneration &+= 1
        let formatRequest = formatGeneration
        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(max(1, format.sampleRate * 0.02)),
                         format: format) { [weak self] buffer, _ in
            // AVAudioEngine owns/reuses the tap buffer. Copy before crossing onto the lifecycle queue.
            guard let copy = Self.copyBuffer(buffer) else { return }
            self?.lifecycleQueue.async { [weak self] in
                self?.consume(copy, request: request, formatRequest: formatRequest)
            }
        }
        tapInstalled = true
        engine.prepare()
        try engine.start()
        isCapturing = true
        NSLog("MIC: engine started, input %.0f Hz/%u channels; output 48000 Hz/mono; microphone tuning UNMEASURED",
              format.sampleRate, format.channelCount)
    }

    private static func copyBuffer(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameLength) else { return nil }
        copy.frameLength = source.frameLength
        let input = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: source.audioBufferList))
        let output = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        guard input.count == output.count else { return nil }
        for index in input.indices {
            guard input[index].mDataByteSize <= output[index].mDataByteSize,
                  let from = input[index].mData, let to = output[index].mData else { return nil }
            memcpy(to, from, Int(input[index].mDataByteSize))
            output[index].mDataByteSize = input[index].mDataByteSize
        }
        return copy
    }

    private func consume(_ input: AVAudioPCMBuffer, request: UInt64, formatRequest: UInt64) {
        guard wantsCapture, isCapturing, generation == request, formatGeneration == formatRequest else { return }
        let processed: AVAudioPCMBuffer
        if let converter, let outputFormat {
            do {
                processed = try Self.convert(input, using: converter, outputFormat: outputFormat)
            } catch {
                fail(error)
                return
            }
        } else {
            processed = input
        }
        guard processed.frameLength > 0, let samples = processed.floatChannelData?[0] else { return }
        detector.ingest(UnsafeBufferPointer(start: samples, count: Int(processed.frameLength)))
    }

    /// Also exercised without hardware by the synthetic microphone-format test harness.
    static func convert(_ input: AVAudioPCMBuffer, using converter: AVAudioConverter,
                        outputFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * outputFormat.sampleRate / input.format.sampleRate)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw NSError(domain: "MicrophoneCapture", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not allocate microphone conversion buffer."])
        }
        var supplied = false
        var error: NSError?
        let result = converter.convert(to: output, error: &error) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true
            status.pointee = .haveData
            return input
        }
        if result == .error || error != nil {
            throw error ?? NSError(domain: "MicrophoneCapture", code: 3,
                                   userInfo: [NSLocalizedDescriptionKey: "The microphone audio could not be converted."])
        }
        return output
    }

    private func recoverConfiguration(request: UInt64) {
        guard wantsCapture, generation == request, let engine else { return }
        let newFormat = engine.inputNode.outputFormat(forBus: 0)
        // Engine start can emit a redundant notification. Do not create a restart loop.
        if isCapturing, engine.isRunning, let inputFormat, inputFormat == newFormat { return }
        isCapturing = false
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        do {
            try configureAndStart(engine, request: request)
        } catch {
            fail(error)
        }
    }

    private func captureError(_ description: String) -> NSError {
        NSError(domain: "MicrophoneCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: description])
    }

    private func fail(_ error: Error) {
        stopLocked()
        dispatchStatus("Microphone unavailable: \(error.localizedDescription)")
        dispatchFailure(error)
    }

    private func stopLocked() {
        generation &+= 1
        wantsCapture = false
        isCapturing = false
        isStopped = true
        if let observer { NotificationCenter.default.removeObserver(observer); self.observer = nil }
        engine?.stop()
        if tapInstalled { engine?.inputNode.removeTap(onBus: 0); tapInstalled = false }
        converter = nil
        inputFormat = nil
        outputFormat = nil
        engine = nil
        detector.shutdown()
    }

    func stopCapturing() async { stopCapturingSync() }
    func stopCapturingSync() { lifecycleQueue.sync { stopLocked() } }
    func setMuted(_ muted: Bool) {
        lifecycleQueue.sync { self.muted = muted; detector.setMuted(muted) }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        engine?.stop()
        if tapInstalled { engine?.inputNode.removeTap(onBus: 0) }
    }
}
