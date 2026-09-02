import Foundation
import AVFoundation
import ScreenCaptureKit

/// Captures system audio (Zoom, Teams, etc.) using ScreenCaptureKit
@available(macOS 13.0, *)
class SystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var isCapturing = false

    // VAD parameters (matching VADAudioRecorder)
    private let speechMargin: Float = 18.0
    private let silenceMargin: Float = 10.0
    private let minSpeechDuration: TimeInterval = AppConstants.Thresholds.minSpeechDuration
    private let absoluteMinSpeechDb: Float = -35.0
    private let silenceTimeout: TimeInterval = AppConstants.Thresholds.silenceTimeout
    private let speculativeSilenceTimeout: TimeInterval = AppConstants.Thresholds.speculativeSilenceTimeout
    private var didPreviewCurrentUtterance = false
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

    // Audio recording
    private var recordedSamples: [Float] = []
    private var sampleRate: Double = 48000.0
    private var lastLevelCallbackTime = Date.distantPast
    private var lastLevelCallbackSpeaking = false
    private let levelCallbackInterval: TimeInterval = 0.08

    // Callbacks
    var onLevelUpdate: ((Float, Bool) -> Void)?
    var onSpeechPreview: ((Data) -> Void)?
    var onSpeechCancelled: (() -> Void)?
    var onSpeechSegment: ((Data) -> Void)?
    var onStatusChange: ((String) -> Void)?

    private var speechThreshold: Float { currentBaseline + speechMargin }
    private var silenceThreshold: Float { currentBaseline + silenceMargin }

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
        lastLevelCallbackTime = .distantPast
        lastLevelCallbackSpeaking = false

        debugLog(.audio, "SystemAudio: Capture started successfully!")
        let statusChange = onStatusChange
        DispatchQueue.main.async {
            statusChange?("🔊 Listening to system audio...")
        }
    }

    func stopCapturing() async {
        NSLog("🔊 SystemAudio: Stopping capture")
        isCapturing = false
        try? await stream?.stopCapture()
        stream = nil
    }

    // MARK: - SCStreamOutput

    private var formatLogged = false

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, isCapturing else { return }

        // Log format once
        if !formatLogged, let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
            if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee {
                NSLog("🔊 SysAudio FORMAT: sampleRate=%.0f, channels=%d, bitsPerChannel=%d, bytesPerFrame=%d, formatID=%d",
                      asbd.mSampleRate, asbd.mChannelsPerFrame, asbd.mBitsPerChannel, asbd.mBytesPerFrame, asbd.mFormatID)
                sampleRate = asbd.mSampleRate
            }
            formatLogged = true
        }

        // Get audio buffer list
        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList()
        let size = MemoryLayout<AudioBufferList>.size

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

        // ScreenCaptureKit provides 32-bit float samples
        let floatCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        let floatPointer = data.bindMemory(to: Float.self, capacity: floatCount)
        let samples = Array(UnsafeBufferPointer(start: floatPointer, count: floatCount))

        // Calculate RMS level
        var rmsSum: Float = 0
        for sample in samples {
            rmsSum += sample * sample
        }
        let rms = sqrt(rmsSum / Float(max(samples.count, 1)))
        let db = 20 * log10(max(rms, 0.0000001))

        if isSpeaking {
            recordedSamples.append(contentsOf: samples)
        }

        processVAD(db: db)
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        debugLog(.error, "SystemAudio stream error: \(error.localizedDescription)")
        debugLog(.error, "Full error: \(error)")
        isCapturing = false
        let statusChange = onStatusChange
        DispatchQueue.main.async {
            statusChange?("⚠️ System audio stopped: \(error.localizedDescription)")
        }
    }

    // MARK: - VAD

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

        let isAboveSpeech = db > speechThreshold && db > absoluteMinSpeechDb

        if isAboveSpeech {
            lastSpeechTime = now
            peakLevel = max(peakLevel, db)

            if !isSpeaking {
                isSpeaking = true
                speechStartTime = now
                peakLevel = db
                recordedSamples = []
                didPreviewCurrentUtterance = false

                NSLog("🟢 SysAudio: Speech STARTED - db=%.1f", db)
                let statusChange = onStatusChange
                DispatchQueue.main.async {
                    statusChange?("🗣 Interviewer speaking...")
                }
            } else if didPreviewCurrentUtterance {
                didPreviewCurrentUtterance = false
                NSLog("🟡 SysAudio: Speech resumed after STT preview")
                dispatchSpeechTurn(.speechResumedAfterPreview, audio: nil)
            }
        } else if isSpeaking {
            let nearBaseline = db < silenceThreshold
            let silenceDuration = lastSpeechTime.map { now.timeIntervalSince($0) } ?? 0

            if nearBaseline && silenceDuration > speculativeSilenceTimeout {
                emitPreviewIfNeeded()
            }

            if nearBaseline && silenceDuration > silenceTimeout {
                let speechDuration = speechStartTime.map { now.timeIntervalSince($0) } ?? 0
                NSLog("🔴 SysAudio: Speech ENDED - duration: %.2fs", speechDuration)
                emitFinalCommit()

                isSpeaking = false
                speechStartTime = nil
                peakLevel = -100.0
                recordedSamples = []
                didPreviewCurrentUtterance = false

                let statusChange = onStatusChange
                DispatchQueue.main.async {
                    statusChange?("🔊 Listening to system audio...")
                }
            }
        }

        emitLevelUpdate(db: db, now: now)
    }

    private func emitLevelUpdate(db: Float, now: Date) {
        let speaking = isSpeaking
        let stateChanged = speaking != lastLevelCallbackSpeaking
        guard stateChanged || now.timeIntervalSince(lastLevelCallbackTime) >= levelCallbackInterval else { return }

        lastLevelCallbackTime = now
        lastLevelCallbackSpeaking = speaking
        let levelUpdate = onLevelUpdate
        DispatchQueue.main.async {
            levelUpdate?(db, speaking)
        }
    }

    private func emitPreviewIfNeeded() {
        guard !didPreviewCurrentUtterance else { return }
        guard let audioData = eligibleUtteranceWAV() else { return }
        didPreviewCurrentUtterance = true
        NSLog("✅ SysAudio: STT preview %.2fs (%d bytes wav)", speechStartTime.map { Date().timeIntervalSince($0) } ?? 0, audioData.count)
        dispatchSpeechTurn(.speculativePreview, audio: audioData)
    }

    private func emitFinalCommit() {
        guard let audioData = eligibleUtteranceWAV() else {
            if didPreviewCurrentUtterance {
                dispatchSpeechTurn(.speechResumedAfterPreview, audio: nil)
            }
            return
        }
        NSLog("✅ SysAudio: final commit %.2fs (%d bytes wav)", speechStartTime.map { Date().timeIntervalSince($0) } ?? 0, audioData.count)
        let statusChange = onStatusChange
        DispatchQueue.main.async {
            statusChange?("⏳ Processing...")
        }
        dispatchSpeechTurn(.finalSilence, audio: audioData)
    }

    private func eligibleUtteranceWAV() -> Data? {
        let speechDuration = speechStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let peakAboveBaseline = peakLevel - currentBaseline
        guard speechDuration > minSpeechDuration, peakAboveBaseline >= speechMargin * 0.5 else { return nil }
        return convertSamplesToWAV()
    }

    private func dispatchSpeechTurn(_ emit: SpeechTurnEmit, audio: Data?) {
        let action = SpeechTurnPolicy.action(for: emit)
        let preview = onSpeechPreview
        let cancelled = onSpeechCancelled
        let segment = onSpeechSegment
        DispatchQueue.main.async {
            switch action {
            case .prefetchTranscriptionOnly:
                if let audio {
                    preview?(audio)
                }
            case .cancelInFlightWork:
                cancelled?()
            case .commitAnswer:
                if let audio {
                    segment?(audio)
                }
            }
        }
    }

    private func convertSamplesToWAV() -> Data? {
        guard !recordedSamples.isEmpty else { return nil }

        var wavData = Data(createWAVHeader(sampleCount: recordedSamples.count))
        for sample in recordedSamples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16 = Int16(clamped * Float(Int16.max))
            withUnsafeBytes(of: int16.littleEndian) { wavData.append(contentsOf: $0) }
        }
        return wavData
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
