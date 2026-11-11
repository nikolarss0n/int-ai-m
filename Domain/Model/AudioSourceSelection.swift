import Foundation

/// Application-level ownership covers permission requests as well as running recorders.
final class MicrophoneReservations {
    enum Owner { case interview, practice }
    struct Lease: Equatable {
        let id = UUID()
        let owner: Owner
    }
    private(set) var current: Lease?

    func acquire(_ owner: Owner) -> Lease? {
        dispatchPrecondition(condition: .onQueue(.main))
        guard current == nil else { return nil }
        let lease = Lease(owner: owner)
        current = lease
        return lease
    }

    func owns(_ lease: Lease) -> Bool { current == lease }

    func release(_ lease: Lease) {
        dispatchPrecondition(condition: .onQueue(.main))
        if current == lease { current = nil }
    }
}

struct PushToTalkState {
    private(set) var latched = false
    private(set) var pressedAt: TimeInterval?
    private var clearsLatch = false
    private(set) var pressID: UUID?
    var isMuted: Bool { latched || (pressedAt != nil && !clearsLatch) }

    mutating func keyDown(at time: TimeInterval, isRepeat: Bool) -> UUID? {
        guard !isRepeat, pressedAt == nil else { return nil }
        clearsLatch = latched
        if clearsLatch { latched = false }
        pressedAt = time
        let id = UUID()
        pressID = id
        return id
    }

    @discardableResult mutating func keyUp(at time: TimeInterval) -> Bool {
        guard let start = pressedAt else { return false }
        if !clearsLatch { latched = time - start < 0.4 }
        pressedAt = nil
        pressID = nil
        clearsLatch = false
        return true
    }

    mutating func toggleLatch() {
        // A click explicitly replaces the current gesture; its later release is ignored.
        let next = !isMuted
        self = PushToTalkState()
        latched = next
    }

    @discardableResult mutating func expire(_ id: UUID) -> Bool {
        guard pressID == id else { return false }
        self = PushToTalkState()
        return true
    }
}

enum CapturePresentation: Equatable {
    case idle, switching, unavailable, listening(CaptureDevice), speaking(CaptureDevice), muted

    var symbol: String {
        switch self {
        case .idle, .unavailable: return "waveform.slash"
        case .switching: return "arrow.triangle.2.circlepath"
        // Not the source's own glyph: the source buttons sit right beside this one.
        case .listening: return "ear"
        case .speaking: return "waveform"
        case .muted: return "mic.slash.fill"
        }
    }

    var label: String {
        switch self {
        case .idle: return "Audio starts with the interview"
        case .switching: return "Switching audio source"
        case .unavailable: return "Audio unavailable. Select a source to try again."
        case .listening(let device): return "Listening to \(device.displayName). Click or press ⌘⇧M to mute."
        case .speaking(let device): return "Speech detected on \(device.displayName). Click or press ⌘⇧M to mute."
        case .muted: return "Muted. Click or press ⌘⇧M to unmute."
        }
    }
}

func capturePresentation(active: CaptureDevice?, sessionActive: Bool, switching: Bool, muted: Bool, speaking: Bool) -> CapturePresentation {
    guard sessionActive else { return .idle }
    if muted { return .muted }
    if let active { return speaking ? .speaking(active) : .listening(active) }
    return switching ? .switching : .unavailable
}

func resolveStartupCaptureDevice(preferred: CaptureDevice, microphoneAllowed: Bool) -> CaptureDevice {
    preferred == .microphone && !microphoneAllowed ? .systemAudio : preferred
}
