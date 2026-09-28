import Foundation

/// Capture-independent turn detection. All state is serialized; sinks run after state is unlocked.
final class SpeechTurnDetector {
    struct Labels {
        let idle, speaking, processing, muted: String
        static let systemAudio = Labels(idle: "🔊 Listening to system audio...", speaking: "🗣 Interviewer speaking...", processing: "⏳ Processing...", muted: "Capture muted")
        static let microphone = Labels(idle: "Listening to microphone...", speaking: "🗣 Interviewer speaking...", processing: "⏳ Processing...", muted: "Capture muted")
    }

    struct Tuning {
        let speechMargin, silenceMargin, absoluteMinSpeechDb: Float
        let minSpeechDuration, silenceTimeout, speculativeSilenceTimeout: TimeInterval
        let baselineWindowSize, baselineUpdateInterval: Int
        let levelCallbackInterval: TimeInterval

        static let systemAudio = Tuning(speechMargin: 18, silenceMargin: 10, absoluteMinSpeechDb: -35,
            minSpeechDuration: AppConstants.Thresholds.minSpeechDuration,
            silenceTimeout: AppConstants.Thresholds.silenceTimeout,
            speculativeSilenceTimeout: AppConstants.Thresholds.speculativeSilenceTimeout,
            baselineWindowSize: 40, baselineUpdateInterval: 5, levelCallbackInterval: 0.08)

        /// UNMEASURED experiment. This conservative starting point is not room-microphone calibration.
        static let microphoneExperimental = systemAudio
    }

    private enum Emission {
        case turn(SpeechTurnEmit, Data?)
        case level(Float, Bool)
        case status(String)
    }
    private let stateQueue = DispatchQueue(label: "interview.speech-turn-detector")
    private let labels: Labels
    private let tuning: Tuning
    private let logTag: String
    private let now: () -> Date
    private var turnSink: ((SpeechTurnEmit, Data?) -> Void)?
    private var levelSink: ((Float, Bool) -> Void)?
    private var statusSink: ((String) -> Void)?
    private var baselineBuffer: [Float] = []
    private var currentBaseline: Float = -60
    private var baselineUpdateCount = 0
    private var isSpeaking = false
    private var isMuted = false
    private var isShutdown = false
    private var speechStartTime: Date?
    private var lastSpeechTime: Date?
    private var peakLevel: Float = -100
    private var recordedSamples: [Float] = []
    private var sampleRate: Double = 48_000
    private var didPreviewCurrentUtterance = false
    private var lastLevelCallbackTime = Date.distantPast
    private var lastLevelCallbackSpeaking = false
    private var checkCount = 0

    init(labels: Labels, tuning: Tuning, logTag: String, now: @escaping () -> Date = Date.init,
         emitTurn: @escaping (SpeechTurnEmit, Data?) -> Void,
         emitLevel: @escaping (Float, Bool) -> Void, emitStatus: @escaping (String) -> Void) {
        self.labels = labels
        self.tuning = tuning
        self.logTag = logTag
        self.now = now
        turnSink = emitTurn
        levelSink = emitLevel
        statusSink = emitStatus
    }

    func ingest(_ samples: UnsafeBufferPointer<Float>) {
        mutate {
            guard !isShutdown, !isMuted else { return [] }
            var sum: Float = 0
            for sample in samples { sum += sample * sample }
            let rms = sqrt(sum / Float(max(samples.count, 1)))
            let db = 20 * log10(max(rms, 0.0000001))
            // Preserve the legacy policy: the triggering frame itself is not recorded.
            if isSpeaking { recordedSamples.append(contentsOf: samples) }
            return processVAD(db: db)
        }
    }

    func setSampleRate(_ rate: Double) {
        stateQueue.sync {
            if rate.isFinite && rate > 0 && rate <= Double(UInt32.max / 2) { sampleRate = rate }
        }
    }

    func setMuted(_ muted: Bool) {
        mutate {
            guard !isShutdown, isMuted != muted else { return [] }
            isMuted = muted
            var emissions: [Emission] = []
            if muted {
                if didPreviewCurrentUtterance { emissions.append(.turn(.speechResumedAfterPreview, nil)) }
                abandonCurrentUtterance()
                lastLevelCallbackSpeaking = false
                emissions.append(.level(-100, false))
            }
            emissions.append(.status(muted ? labels.muted : labels.idle))
            return emissions
        }
    }

    /// Reinitialize signal history while preserving the externally owned mute gate.
    func reset() {
        mutate {
            let cancelledPreview = didPreviewCurrentUtterance
            abandonCurrentUtterance()
            baselineBuffer.removeAll()
            currentBaseline = -60
            baselineUpdateCount = 0
            checkCount = 0
            lastLevelCallbackTime = .distantPast
            lastLevelCallbackSpeaking = false
            return cancelledPreview ? [.turn(.speechResumedAfterPreview, nil)] : []
        }
    }

    func shutdown() {
        stateQueue.sync {
            isShutdown = true
            abandonCurrentUtterance()
            turnSink = nil
            levelSink = nil
            statusSink = nil
        }
    }

    private func mutate(_ body: () -> [Emission]) {
        let (emissions, turn, level, status) = stateQueue.sync {
            (body(), turnSink, levelSink, statusSink)
        }
        for emission in emissions {
            switch emission {
            case let .turn(kind, data): turn?(kind, data)
            case let .level(db, speaking): level?(db, speaking)
            case let .status(text): status?(text)
            }
        }
    }

    private func updateBaseline(_ db: Float) {
        guard !isSpeaking, db > -90, db < -20 else { return }
        baselineUpdateCount += 1
        guard baselineUpdateCount >= tuning.baselineUpdateInterval else { return }
        baselineUpdateCount = 0
        baselineBuffer.append(db)
        if baselineBuffer.count > tuning.baselineWindowSize { baselineBuffer.removeFirst() }
        if baselineBuffer.count >= 10 {
            let quietHalf = baselineBuffer.sorted().prefix(baselineBuffer.count / 2)
            let newBaseline = quietHalf.reduce(0, +) / Float(quietHalf.count)
            currentBaseline = currentBaseline * 0.7 + newBaseline * 0.3
        }
    }

    private func processVAD(db: Float) -> [Emission] {
        let time = now()
        var emissions: [Emission] = []
        checkCount += 1
        updateBaseline(db)
        if checkCount % 100 == 0 {
            NSLog("%@: db=%.1f, baseline=%.1f, speaking=%@", logTag, db, currentBaseline, isSpeaking ? "YES" : "NO")
        }
        if db > currentBaseline + tuning.speechMargin && db > tuning.absoluteMinSpeechDb {
            lastSpeechTime = time
            peakLevel = max(peakLevel, db)
            if !isSpeaking {
                isSpeaking = true
                speechStartTime = time
                peakLevel = db
                recordedSamples = []
                didPreviewCurrentUtterance = false
                emissions.append(.status(labels.speaking))
            } else if didPreviewCurrentUtterance {
                didPreviewCurrentUtterance = false
                emissions.append(.turn(.speechResumedAfterPreview, nil))
            }
        } else if isSpeaking {
            let nearBaseline = db < currentBaseline + tuning.silenceMargin
            let silence = lastSpeechTime.map { time.timeIntervalSince($0) } ?? 0
            if nearBaseline && silence > tuning.speculativeSilenceTimeout && !didPreviewCurrentUtterance,
               let audio = eligibleUtteranceWAV() {
                didPreviewCurrentUtterance = true
                NSLog("%@: STT preview %.2fs (%d bytes wav)", logTag, speechStartTime.map { now().timeIntervalSince($0) } ?? 0, audio.count)
                emissions.append(.turn(.speculativePreview, audio))
            }
            if nearBaseline && silence > tuning.silenceTimeout {
                if let audio = eligibleUtteranceWAV() {
                    NSLog("%@: final commit %.2fs (%d bytes wav)", logTag, speechStartTime.map { now().timeIntervalSince($0) } ?? 0, audio.count)
                    emissions.append(.status(labels.processing))
                    emissions.append(.turn(.finalSilence, audio))
                } else if didPreviewCurrentUtterance {
                    emissions.append(.turn(.speechResumedAfterPreview, nil))
                }
                abandonCurrentUtterance()
                emissions.append(.status(labels.idle))
            }
        }
        let stateChanged = isSpeaking != lastLevelCallbackSpeaking
        if stateChanged || time.timeIntervalSince(lastLevelCallbackTime) >= tuning.levelCallbackInterval {
            lastLevelCallbackTime = time
            lastLevelCallbackSpeaking = isSpeaking
            emissions.append(.level(db, isSpeaking))
        }
        return emissions
    }

    private func abandonCurrentUtterance() {
        isSpeaking = false
        speechStartTime = nil
        lastSpeechTime = nil
        peakLevel = -100
        recordedSamples.removeAll()
        didPreviewCurrentUtterance = false
    }

    private func eligibleUtteranceWAV() -> Data? {
        let duration = speechStartTime.map { now().timeIntervalSince($0) } ?? 0
        guard duration > tuning.minSpeechDuration,
              peakLevel - currentBaseline >= tuning.speechMargin * 0.5,
              !recordedSamples.isEmpty else { return nil }
        let dataSize = UInt32(recordedSamples.count * 2)
        var wav = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) }
        }
        append(dataSize + 36)
        wav.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate) * 2)
        append(UInt16(2))
        append(UInt16(16))
        wav.append(contentsOf: "data".utf8)
        append(dataSize)
        for sample in recordedSamples {
            append(Int16(max(-1, min(1, sample)) * Float(Int16.max)))
        }
        return wav
    }
}
