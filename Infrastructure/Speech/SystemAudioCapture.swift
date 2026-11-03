import Foundation
import AVFoundation
import ScreenCaptureKit

/// A fresh adapter is created for each start; lifecycle generations reject suspended old starts.
@available(macOS 13.0, *)
final class SystemAudioCapture: AudioCaptureCallbacks, AudioSourceCapture, SCStreamOutput, SCStreamDelegate {
    let captureDevice = CaptureDevice.systemAudio
    private let lifecycleQueue = DispatchQueue(label: "interview.system-audio.lifecycle")
    private var stream: SCStream?
    private var generation: UInt64 = 0
    private var wantsCapture = false
    private var isCapturing = false
    private var isStopped = false
    private var formatLogged = false
    private var muted = false
    private lazy var detector = SpeechTurnDetector(labels: .systemAudio, tuning: .systemAudio, logTag: "SysVAD",
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
        var candidate: SCStream?
        do {
            try await AudioCaptureFactory.preflight(.systemAudio, allowPrompt: false)
            try Task.checkCancellation()
            try requireCurrent(request)
            let content = try await SCShareableContent.current
            try requireCurrent(request)
            guard let display = content.displays.first else {
                throw NSError(domain: "SystemAudioCapture", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No display found"])
            }
            let configuration = SCStreamConfiguration()
            configuration.width = 2
            configuration.height = 2
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = true
            configuration.sampleRate = 48_000
            configuration.channelCount = 1
            let next = SCStream(filter: SCContentFilter(display: display, excludingWindows: []),
                                configuration: configuration, delegate: self)
            candidate = next
            try lifecycleQueue.sync {
                guard wantsCapture, generation == request else { throw CancellationError() }
                try next.addStreamOutput(self, type: .audio, sampleHandlerQueue: lifecycleQueue)
                stream = next
            }
            try await next.startCapture()
            try lifecycleQueue.sync {
                guard wantsCapture, generation == request, stream === next else { throw CancellationError() }
                detector.reset()
                isCapturing = true
                dispatchStatus(muted ? SpeechTurnDetector.Labels.systemAudio.muted : SpeechTurnDetector.Labels.systemAudio.idle)
            }
        } catch {
            // A stop during an awaited start cannot leave a successfully started orphan stream.
            if let candidate { try? await candidate.stopCapture() }
            lifecycleQueue.sync {
                if generation == request {
                    wantsCapture = false
                    isCapturing = false
                    stream = nil
                    isStopped = true
                    detector.shutdown()
                }
            }
            throw error
        }
    }

    private func requireCurrent(_ request: UInt64) throws {
        try lifecycleQueue.sync {
            guard wantsCapture, generation == request else { throw CancellationError() }
        }
    }

    private func detach() -> SCStream? {
        lifecycleQueue.sync {
            generation &+= 1
            wantsCapture = false
            isCapturing = false
            isStopped = true
            detector.shutdown()
            let old = stream
            stream = nil
            return old
        }
    }

    func stopCapturing() async {
        if let old = detach() { try? await old.stopCapture() }
    }

    func stopCapturingSync() {
        // ScreenCaptureKit exposes asynchronous teardown only. Microphone engines stop synchronously.
        if let old = detach() { old.stopCapture(completionHandler: nil) }
    }

    func setMuted(_ muted: Bool) {
        lifecycleQueue.sync { self.muted = muted; detector.setMuted(muted) }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // ScreenCaptureKit invokes this method on lifecycleQueue, serial with stop and mute.
        guard type == .audio, isCapturing, self.stream === stream else { return }
        if !formatLogged, let format = CMSampleBufferGetFormatDescription(sampleBuffer),
           let description = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee {
            detector.setSampleRate(description.mSampleRate)
            formatLogged = true
        }
        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList()
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
            bufferListSizeNeededOut: nil, bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0,
            blockBufferOut: &blockBuffer)
        guard status == noErr, let data = audioBufferList.mBuffers.mData else { return }
        let count = Int(audioBufferList.mBuffers.mDataByteSize) / MemoryLayout<Float>.size
        detector.ingest(UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: count))
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        lifecycleQueue.async { [weak self] in
            guard let self, self.wantsCapture, self.stream === stream else { return }
            self.wantsCapture = false
            self.isCapturing = false
            self.dispatchStatus("⚠️ System audio stopped: \(error.localizedDescription)")
            self.dispatchFailure(error)
        }
    }
}
