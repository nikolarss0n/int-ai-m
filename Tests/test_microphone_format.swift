import Foundation
import AVFoundation

// Synthetic PCM only: this harness never creates an engine, requests permission, or records sound.
private var checks = 0
private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    guard condition() else { fatalError("Microphone format: \(message)") }
}

let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)!
for rate in [44_100.0, 48_000.0] {
    for channels: AVAudioChannelCount in [1, 2] {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: channels, interleaved: false)!
        let converter = AVAudioConverter(from: format, to: outputFormat)!
        let frameCount = AVAudioFrameCount(rate / 50)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        for channel in 0..<Int(channels) {
            for sample in 0..<Int(frameCount) {
                buffer.floatChannelData![channel][sample] = 0.2 * sin(Float(sample) * 2 * .pi * 440 / Float(rate))
            }
        }
        var samples: [Float] = []
        for _ in 0..<50 {
            let converted = try MicrophoneCapture.convert(buffer, using: converter, outputFormat: outputFormat)
            check(converted.format.sampleRate == 48_000 && converted.format.channelCount == 1,
                  "\(rate) Hz / \(channels)ch produces mono 48k")
            if let data = converted.floatChannelData?[0] {
                samples.append(contentsOf: UnsafeBufferPointer(start: data, count: Int(converted.frameLength)))
            }
        }
        check(abs(samples.count - 48_000) < 200, "resampler preserves one-second duration")
        check(samples.contains { abs($0) > 0.1 }, "conversion preserves audible signal")
        check(samples.allSatisfy(\.isFinite), "converted PCM samples remain finite")

        var time = 0.0
        var committed: Data?
        let detector = SpeechTurnDetector(labels: .microphone, tuning: .microphoneExperimental, logTag: "FormatTest",
            now: { Date(timeIntervalSinceReferenceDate: time) },
            emitTurn: { kind, wav in if kind == .finalSilence { committed = wav } },
            emitLevel: { _, _ in }, emitStatus: { _ in })
        detector.setSampleRate(outputFormat.sampleRate)
        [Float(0.2)].withUnsafeBufferPointer { detector.ingest($0) }
        time = 1
        samples.withUnsafeBufferPointer { detector.ingest($0) }
        time = 1.7
        [Float(0)].withUnsafeBufferPointer { detector.ingest($0) }
        check(committed != nil, "converted speech reaches detector")
        if let committed {
            let headerRate = committed[24..<28].enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset * 8) }
            check(headerRate == 48_000, "converted samples and WAV header agree on output rate")
            check(committed.count == 44 + (samples.count + 1) * 2, "WAV contains converted frame count")
        }
    }
}
print("Microphone format: \(checks) checks passed (synthetic PCM; no recording)")
