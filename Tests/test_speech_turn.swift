import Foundation

private var checks = 0
private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    guard condition() else { fatalError("SpeechTurnDetector: \(message)") }
}

struct Turn: Equatable {
    let kind: SpeechTurnEmit
    let time: Double
    let wav: Data?
}

final class Harness {
    var time: Double = 0
    var turns: [Turn] = []
    var levels: [(Float, Bool)] = []
    var statuses: [String] = []
    var detector: SpeechTurnDetector!
    init(tuning: SpeechTurnDetector.Tuning = .systemAudio, epoch: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        detector = SpeechTurnDetector(labels: .systemAudio, tuning: tuning, logTag: "TestVAD",
            now: { [unowned self] in epoch.addingTimeInterval(self.time) },
            emitTurn: { [unowned self] in self.turns.append(Turn(kind: $0, time: self.time, wav: $1)) },
            emitLevel: { [unowned self] in self.levels.append(($0, $1)) },
            emitStatus: { [unowned self] in self.statuses.append($0) })
    }
    func feed(_ at: Double, _ samples: [Float]) {
        time = at
        samples.withUnsafeBufferPointer { detector.ingest($0) }
    }
    func voice(_ at: Double) { feed(at, [0.1, -0.1, 0.1, -0.1]) }
    func silence(_ at: Double) { feed(at, [0, 0, 0, 0]) }
}

private func tuning(minDuration: Double = 0.5, floor: Float = -35) -> SpeechTurnDetector.Tuning {
    .init(speechMargin: 18, silenceMargin: 10, absoluteMinSpeechDb: floor,
          minSpeechDuration: minDuration, silenceTimeout: 0.65,
          speculativeSilenceTimeout: 0.25, baselineWindowSize: 40,
          baselineUpdateInterval: 5, levelCallbackInterval: 0.08)
}

// Frozen from the original SystemAudioCapture detector, before extraction, using only an injected
// clock and synchronous callback observation. These WAVs include clipping and silence frame bytes.
let golden = Harness()
let signals: [(Double, [Float])] = [
    (0, [0.1, -0.1, 0.25, -0.25]), (0.25, [0.2, -0.2, 0.4, -0.4]),
    (0.5, [1.1, -1.1, 0.5, -0.5]), (0.749, [0, 0, 0, 0]),
    (0.75, [0, 0, 0, 0]), (0.751, [0, 0, 0, 0]),
    (0.8, [0.3, -0.3, 0.15, -0.15]), (1.049, [0, 0, 0, 0]),
    (1.05, [0, 0, 0, 0]), (1.051, [0, 0, 0, 0]),
    (1.449, [0, 0, 0, 0]), (1.45, [0, 0, 0, 0]), (1.451, [0, 0, 0, 0])
]
for (at, samples) in signals { golden.feed(at, samples) }
let expected = [
    Turn(kind: .speculativePreview, time: 0.751, wav: Data(base64Encoded: "UklGRkwAAABXQVZFZm10IBAAAAABAAEAgLsAAAB3AQACABAAZGF0YSgAAACZGWfmMjPOzP9/AYD/PwHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")),
    Turn(kind: .speechResumedAfterPreview, time: 0.8, wav: nil),
    Turn(kind: .speculativePreview, time: 1.051, wav: Data(base64Encoded: "UklGRmwAAABXQVZFZm10IBAAAAABAAEAgLsAAAB3AQACABAAZGF0YUgAAACZGWfmMjPOzP9/AYD/PwHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZiaa2TMTzewAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")),
    Turn(kind: .finalSilence, time: 1.451, wav: Data(base64Encoded: "UklGRoQAAABXQVZFZm10IBAAAAABAAEAgLsAAAB3AQACABAAZGF0YWAAAACZGWfmMjPOzP9/AYD/PwHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZiaa2TMTzewAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="))
]
check(expected.filter { $0.kind != .speechResumedAfterPreview }.allSatisfy { $0.wav != nil }, "valid legacy golden fixtures")
check(golden.turns == expected, "legacy event times and all WAV bytes are unchanged")

let boundaries = Harness()
boundaries.voice(-1)
boundaries.voice(0)
boundaries.silence(0.249)
check(boundaries.turns.isEmpty, "no preview before 0.25s")
boundaries.silence(0.25)
check(boundaries.turns.isEmpty, "no preview exactly at 0.25s")
boundaries.silence(0.251)
check(boundaries.turns.map(\.kind) == [.speculativePreview], "preview strictly after 0.25s")
boundaries.silence(0.649)
boundaries.silence(0.65)
check(boundaries.turns.count == 1, "no final before or exactly at 0.65s")
boundaries.silence(0.651)
check(boundaries.turns.map(\.kind) == [.speculativePreview, .finalSilence], "final strictly after 0.65s")

let trailing = Harness()
trailing.voice(0)
trailing.voice(0.3)
trailing.silence(0.56)
check(trailing.turns.map(\.kind) == [.speculativePreview], "trailing silence counts toward elapsed minimum duration")
trailing.silence(0.96)
check(trailing.turns.last?.kind == .finalSilence, "0.3s spoken clip commits after eligible trailing silence")

let minimum = Harness()
minimum.voice(0)
minimum.silence(0.499)
minimum.silence(0.5)
check(minimum.turns.isEmpty, "duration minimum is strict, including exactly 0.5s")
minimum.silence(0.501)
check(minimum.turns.map(\.kind) == [.speculativePreview], "elapsed duration over minimum previews")
let oldEpoch = Harness(tuning: tuning(minDuration: 2), epoch: Date(timeIntervalSince1970: 0))
oldEpoch.voice(0)
oldEpoch.voice(0.1)
oldEpoch.silence(0.8)
check(oldEpoch.turns.isEmpty, "eligibility uses injected 1970 clock, never wall time")

let muted = Harness()
muted.voice(0)
muted.voice(0.3)
muted.silence(0.56)
muted.detector.setMuted(true)
check(muted.turns.map(\.kind) == [.speculativePreview, .speechResumedAfterPreview], "mute cancels speculative preview")
muted.silence(2)
check(!muted.turns.contains { $0.kind == .finalSilence }, "mute abandons current utterance without committing")
muted.detector.reset()
let levelCount = muted.levels.count
muted.voice(3)
check(muted.levels.count == levelCount, "configuration reset preserves mute before level/RMS work")
muted.detector.setMuted(false)
muted.voice(4)
muted.silence(4.7)
check(muted.turns.last?.kind == .finalSilence, "unmute starts a fresh utterance")

let recovery = Harness()
recovery.voice(0)
recovery.voice(0.3)
recovery.silence(0.56)
recovery.detector.reset()
check(recovery.turns.map(\.kind) == [.speculativePreview, .speechResumedAfterPreview], "configuration reset cancels an abandoned preview")
recovery.silence(2)
check(!recovery.turns.contains { $0.kind == .finalSilence }, "configuration reset cannot commit the old utterance")

let baseline = Harness(tuning: tuning(floor: -90))
baseline.detector.setMuted(true)
for tick in 0..<200 { baseline.feed(Double(tick) / 100, [0.03162278, -0.03162278]) }
baseline.detector.setMuted(false)
let quietVoice: [Float] = [0.01258925, -0.01258925] // -38 dB; above preserved -60 dB baseline + 18.
baseline.feed(3, quietVoice)
baseline.feed(3.3, quietVoice)
baseline.silence(4)
check(baseline.turns.last?.kind == .finalSilence, "muted sound cannot raise the baseline and deafen subsequent speech")

let header = Harness()
header.detector.setSampleRate(44_100)
header.voice(0)
header.silence(0.7)
let wav = header.turns.last!.wav!
let sampleRate = wav[24..<28].enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset * 8) }
check(sampleRate == 44_100, "WAV header carries detector sample rate")
check(String(data: wav[0..<4], encoding: .utf8) == "RIFF", "WAV RIFF header")
let priorTurns = header.turns.count
header.detector.shutdown()
header.voice(2)
header.silence(3)
check(header.turns.count == priorTurns, "shutdown suppresses every future signal")

var reentrant: SpeechTurnDetector!
var callbackRan = false
reentrant = SpeechTurnDetector(labels: .systemAudio, tuning: .systemAudio, logTag: "Reentrant",
    emitTurn: { _, _ in }, emitLevel: { _, _ in
        reentrant.setSampleRate(48_000)
        callbackRan = true
    }, emitStatus: { _ in })
[Float(0.1)].withUnsafeBufferPointer { reentrant.ingest($0) }
check(callbackRan, "sinks execute outside detector state lock")
print("SpeechTurnDetector: \(checks) checks passed")
