import Foundation

@available(macOS 13.0, *)
protocol AudioSourceCapture: AnyObject {
    var captureDevice: CaptureDevice { get }
    var onLevelUpdate: ((Float, Bool) -> Void)? { get set }
    var onSpeechPreview: ((Data) -> Void)? { get set }
    var onSpeechCancelled: (() -> Void)? { get set }
    var onSpeechSegment: ((Data) -> Void)? { get set }
    var onStatusChange: ((String) -> Void)? { get set }
    var onCaptureFailed: ((Error) -> Void)? { get set }
    func startCapturing() async throws
    func stopCapturing() async
    func stopCapturingSync()
    func setMuted(_ muted: Bool)
}

/// Property access and callback snapshots may occur on different audio/main queues.
class AudioCaptureCallbacks: NSObject {
    private struct Sinks {
        var level: ((Float, Bool) -> Void)?
        var preview: ((Data) -> Void)?
        var cancelled: (() -> Void)?
        var segment: ((Data) -> Void)?
        var status: ((String) -> Void)?
        var failed: ((Error) -> Void)?
    }
    private let callbackLock = NSLock()
    private var sinks = Sinks()
    private func read<T>(_ keyPath: KeyPath<Sinks, T>) -> T {
        callbackLock.lock()
        defer { callbackLock.unlock() }
        return sinks[keyPath: keyPath]
    }
    private func write<T>(_ keyPath: WritableKeyPath<Sinks, T>, _ value: T) {
        callbackLock.lock()
        defer { callbackLock.unlock() }
        sinks[keyPath: keyPath] = value
    }
    var onLevelUpdate: ((Float, Bool) -> Void)? {
        get { read(\.level) }
        set { write(\.level, newValue) }
    }
    var onSpeechPreview: ((Data) -> Void)? {
        get { read(\.preview) }
        set { write(\.preview, newValue) }
    }
    var onSpeechCancelled: (() -> Void)? {
        get { read(\.cancelled) }
        set { write(\.cancelled, newValue) }
    }
    var onSpeechSegment: ((Data) -> Void)? {
        get { read(\.segment) }
        set { write(\.segment, newValue) }
    }
    var onStatusChange: ((String) -> Void)? {
        get { read(\.status) }
        set { write(\.status, newValue) }
    }
    var onCaptureFailed: ((Error) -> Void)? {
        get { read(\.failed) }
        set { write(\.failed, newValue) }
    }

    func dispatchTurn(_ emit: SpeechTurnEmit, audio: Data?) {
        let preview = onSpeechPreview
        let cancelled = onSpeechCancelled
        let segment = onSpeechSegment
        DispatchQueue.main.async {
            switch SpeechTurnPolicy.action(for: emit) {
            case .prefetchTranscriptionOnly: if let audio { preview?(audio) }
            case .cancelInFlightWork: cancelled?()
            case .commitAnswer: if let audio { segment?(audio) }
            }
        }
    }
    func dispatchLevel(_ db: Float, speaking: Bool) {
        let callback = onLevelUpdate
        DispatchQueue.main.async { callback?(db, speaking) }
    }
    func dispatchStatus(_ text: String) {
        let callback = onStatusChange
        DispatchQueue.main.async { callback?(text) }
    }
    func dispatchFailure(_ error: Error) {
        let callback = onCaptureFailed
        DispatchQueue.main.async { callback?(error) }
    }
}
