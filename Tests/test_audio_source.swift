import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError("FAIL: \(message)") }
}

private final class Gate {
    private let lock = NSLock()
    private var didEnter = false
    var entered: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didEnter
    }
    private var open = false
    private var waiter: CheckedContinuation<Void, Never>?
    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            didEnter = true
            let alreadyOpen = open
            if !alreadyOpen { waiter = continuation }
            lock.unlock()
            if alreadyOpen { continuation.resume() }
        }
    }
    func release() {
        lock.lock()
        open = true
        let continuation = waiter
        waiter = nil
        lock.unlock()
        continuation?.resume()
    }
}

private struct TestError: Error {}

private final class FakeCapture: AudioSourceCapture {
    let captureDevice: CaptureDevice
    var onLevelUpdate: ((Float, Bool) -> Void)?
    var onSpeechPreview: ((Data) -> Void)?
    var onSpeechCancelled: (() -> Void)?
    var onSpeechSegment: ((Data) -> Void)?
    var onStatusChange: ((String) -> Void)?
    var onCaptureFailed: ((Error) -> Void)?
    var startGate: Gate?
    var stopGate: Gate?
    var fails = false
    var starts = 0
    var stops = 0
    var syncStops = 0
    var muted = false
    var running = false
    init(_ device: CaptureDevice) { captureDevice = device }
    func startCapturing() async throws {
        let gate = await MainActor.run { self.starts += 1; return self.startGate }
        await gate?.wait()
        try await MainActor.run {
            if self.fails { throw TestError() }
            self.running = true
        }
    }
    func stopCapturing() async {
        let gate = await MainActor.run { self.stops += 1; return self.stopGate }
        await gate?.wait()
        await MainActor.run { self.running = false }
    }
    func stopCapturingSync() { syncStops += 1; running = false }
    func setMuted(_ value: Bool) { muted = value }
}

private final class Rig {
    let reservations = MicrophoneReservations()
    var captures: [FakeCapture] = []
    var permission: ((CaptureDevice, Bool) async throws -> Void)?
    var configure: ((FakeCapture, Int) -> Void)?
    var commits: [(CaptureDevice, Bool)] = []
    var errors = 0
    var resets = 0
    var segments: [CaptureDevice] = []
    lazy var coordinator: AudioCaptureCoordinator = {
        let result = AudioCaptureCoordinator(reservations: reservations, make: { [unowned self] device in
            let capture = FakeCapture(device)
            configure?(capture, captures.count)
            captures.append(capture)
            return capture
        }, preflight: { [unowned self] device, prompt in
            try await permission?(device, prompt)
        })
        result.onCommitted = { [unowned self] device, explicit in commits.append((device, explicit)) }
        result.onProblem = { [unowned self] _, _ in errors += 1 }
        result.onResetBuffers = { [unowned self] in resets += 1 }
        result.onSegment = { [unowned self] _, source in segments.append(source) }
        return result
    }()
}

@main
private enum AudioSourceTests {
    @MainActor static func ticks(_ count: Int = 8) async {
        for _ in 0..<count {
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    @MainActor static func until(_ message: String, _ predicate: () -> Bool) async {
        for _ in 0..<200 {
            if predicate() { return }
            await ticks(1)
        }
        fatalError("Unresolved async test event: \(message)")
    }

    @MainActor static func main() async {
        testPureState()

        // Stop can invalidate a request before its Task gets its first turn on the main actor.
        do {
            let rig = Rig()
            var micPermissionRequests = 0
            rig.permission = { device, _ in if device == .microphone { micPermissionRequests += 1 } }
            rig.coordinator.startSession(device: .microphone)
            rig.coordinator.stopSession()
            rig.coordinator.startSession(device: .systemAudio)
            await until("synchronous stop/restart") { rig.coordinator.activeDevice == .systemAudio }
            expect(micPermissionRequests == 0 && rig.reservations.current == nil, "invalidated task must not request permission or reserve mic")
            expect(rig.captures.count == 1 && rig.errors == 0, "only the current task can start hardware")
            rig.coordinator.stopSession()
            await rig.coordinator.waitForHardwareIdle()
        }

        // A stale permission result cannot switch, alert, persist, or clear a newer request.
        for denied in [false, true] {
            let rig = Rig()
            let gate = Gate()
            rig.permission = { device, _ in
                if device == .microphone {
                    await gate.wait()
                    if denied { throw TestError() }
                }
            }
            rig.coordinator.startSession(device: .systemAudio)
            await until("initial source") { rig.coordinator.activeDevice == .systemAudio }
            rig.coordinator.select(.microphone)
            await until("pending permission") { gate.entered }
            expect(rig.captures[0].running, "preflight keeps old source live")
            rig.coordinator.stopSession()
            rig.coordinator.startSession(device: .systemAudio)
            await until("new session source") { rig.commits.count == 2 }
            let resets = rig.resets
            gate.release()
            await ticks()
            expect(rig.coordinator.activeDevice == .systemAudio && rig.resets == resets, "stale preflight cannot reset new session")
            expect(rig.errors == 0 && rig.commits.count == 2 && !rig.coordinator.isSwitching, "stale result has no UI/persistence side effects")
            expect(rig.reservations.current == nil, "stale permission lease released")
            rig.coordinator.stopSession()
            await rig.coordinator.waitForHardwareIdle()
        }

        // Late successful AND failed starts must drain before the next hardware start.
        for fails in [false, true] {
            let rig = Rig()
            let start = Gate(), stop = Gate()
            rig.configure = { capture, index in
                if index == 0 { capture.startGate = start; capture.stopGate = stop; capture.fails = fails }
            }
            rig.coordinator.startSession(device: .microphone)
            await until("old start suspended") { start.entered }
            rig.coordinator.stopSession()
            rig.coordinator.startSession(device: .systemAudio)
            await ticks()
            expect(rig.captures.count == 1, "new hardware cannot overlap pending startup")
            start.release()
            await until("old stop suspended") { stop.entered }
            expect(rig.captures.count == 1, "new hardware waits for confirmed stop")
            expect(rig.reservations.current?.owner == .interview, "mic lease held throughout teardown")
            stop.release()
            await until("new source starts after drain") { rig.coordinator.activeDevice == .systemAudio }
            expect(rig.errors == 0 && rig.captures.count == 2, "stale failure never recovers or alerts")
            expect(!rig.captures[0].running && rig.reservations.current == nil, "old engine drained and lease released")
            rig.coordinator.stopSession()
            await rig.coordinator.waitForHardwareIdle()
        }

        // Already queued callback from the SAME device in an older session is rejected.
        do {
            let rig = Rig()
            rig.coordinator.startSession(device: .systemAudio)
            await until("callback source") { rig.coordinator.activeDevice != nil }
            let old = rig.captures[0].onSpeechSegment
            let oldError = rig.captures[0].onCaptureFailed
            rig.coordinator.stopSession()
            rig.coordinator.startSession(device: .systemAudio)
            await until("replacement source") { rig.captures.count == 2 && rig.coordinator.activeDevice != nil }
            old?(Data([1])); oldError?(TestError())
            rig.captures[1].onSpeechSegment?(Data([2]))
            await ticks()
            expect(rig.segments == [.systemAudio] && rig.errors == 0, "old callbacks dropped even for same device")
            rig.coordinator.stopSession()
            await rig.coordinator.waitForHardwareIdle()
        }

        // Muting a pending start survives its promotion. A current pending failure cannot go live.
        do {
            let rig = Rig(), gate = Gate()
            rig.configure = { capture, _ in capture.startGate = gate }
            rig.coordinator.startSession(device: .microphone)
            await until("mic start pending") { gate.entered }
            rig.coordinator.setMuted(true)
            expect(rig.captures[0].muted, "pending capture receives mute immediately")
            gate.release()
            await until("muted capture active") { rig.coordinator.activeDevice == .microphone }
            expect(rig.captures[0].muted, "latest mute applied at activation")
            rig.coordinator.terminate()
            expect(rig.captures[0].syncStops == 1, "quit stops owned mic synchronously")
            await rig.coordinator.waitForHardwareIdle()
        }
        do {
            let rig = Rig(), gate = Gate()
            rig.configure = { capture, _ in capture.startGate = gate }
            rig.coordinator.startSession(device: .microphone)
            await until("pending failure") { gate.entered }
            rig.captures[0].onCaptureFailed?(TestError())
            await ticks()
            gate.release()
            await until("failed pending start drained") { !rig.coordinator.isSwitching }
            expect(rig.coordinator.activeDevice == nil && rig.errors == 1, "failed pending source never promoted")
            expect(rig.captures.count == 1, "initial failure has no invented fallback")
        }

        // Recovery is bounded, restores the previous source, and never persists automatically.
        for recoveryFails in [false, true] {
            let rig = Rig()
            rig.configure = { capture, index in capture.fails = index == 1 || (index == 2 && recoveryFails) }
            rig.coordinator.startSession(device: .microphone)
            await until("original mic") { rig.coordinator.activeDevice == .microphone }
            rig.coordinator.select(.systemAudio)
            await until("bounded fallback completes") { !rig.coordinator.isSwitching }
            expect(rig.captures.map(\.captureDevice) == [.microphone, .systemAudio, .microphone], "one fallback to previously working mic")
            expect(rig.coordinator.activeDevice == (recoveryFails ? nil : .microphone), "recovery state matches actual capture")
            expect(rig.commits.allSatisfy { !$0.1 }, "automatic recovery never overwrites preference")
            expect(rig.errors == 1, "one failure surfaced")
            rig.coordinator.stopSession()
            await rig.coordinator.waitForHardwareIdle()
        }

        // Practice pending/running/stopping ownership all use the same lease.
        do {
            let rig = Rig()
            let practice = rig.reservations.acquire(.practice)!
            rig.coordinator.startSession(device: .systemAudio)
            await until("remote plus Practice") { rig.coordinator.activeDevice == .systemAudio }
            rig.coordinator.select(.microphone)
            await until("mic denied by Practice") { !rig.coordinator.isSwitching }
            expect(rig.errors == 1 && rig.coordinator.activeDevice == .systemAudio, "Practice busy leaves remote source intact")
            expect(rig.reservations.owns(practice), "failed switch cannot release Practice lease")
            rig.reservations.release(practice)
            rig.coordinator.select(.microphone)
            await until("interview now owns mic") { rig.coordinator.activeDevice == .microphone }
            expect(rig.reservations.acquire(.practice) == nil, "reverse contention blocks Practice")
            expect(rig.commits.last?.1 == true, "successful explicit selection persists")
            rig.coordinator.stopSession()
            await rig.coordinator.waitForHardwareIdle()
            expect(rig.reservations.current == nil, "stop releases microphone")
        }
        print("PASS: audio source lifecycle, ownership, callbacks, mute, and preference tests")
    }

    @MainActor static func testPureState() {
        var mute = PushToTalkState()
        let first = mute.keyDown(at: 0, isRepeat: false)!
        expect(mute.isMuted, "press mutes immediately")
        expect(mute.keyDown(at: 0.1, isRepeat: true) == nil, "autorepeat ignored")
        mute.keyUp(at: 0.2)
        expect(mute.latched && !mute.expire(first), "short tap latches and watchdog cannot expire a released press")
        _ = mute.keyDown(at: 1, isRepeat: false)
        expect(!mute.isMuted, "next press clears latch")
        mute.keyUp(at: 1.1)
        expect(!mute.isMuted, "unlatch release cannot relatch")
        _ = mute.keyDown(at: 2, isRepeat: false)
        mute.keyUp(at: 2.5)
        expect(!mute.isMuted, "hold release unmutes")
        let held = mute.keyDown(at: 4, isRepeat: false)!
        expect(mute.expire(held) && !mute.isMuted, "missed release watchdog clears held state")
        mute.toggleLatch()
        expect(mute.isMuted, "button latches")
        mute = PushToTalkState()
        expect(!mute.keyUp(at: 5) && !mute.expire(held), "old release/watchdog cannot affect new session")
        expect(capturePresentation(active: .microphone, sessionActive: true, switching: false, muted: true, speaking: true) == .muted, "mute outranks speaking")
        expect(capturePresentation(active: nil, sessionActive: true, switching: false, muted: false, speaking: false) == .unavailable, "session alone does not imply listening")
        expect(CapturePresentation.muted.label.contains("⌘⇧M") && !CapturePresentation.muted.label.contains("Command-"), "the mute label names its shortcut as a glyph, as every other hint does")
        expect(CapturePresentation.unavailable.label.contains("try again") && !CapturePresentation.unavailable.label.lowercased().contains("retry"), "one phrase for doing it again")
        expect(CapturePresentation.listening(.systemAudio).label == "Listening to System audio. Click or press ⌘⇧M to mute.", "the source has one name, in sentence case, and the button says what a click does")
        expect(["Listening", "Speech", "Muted"].allSatisfy { prefix in [CapturePresentation.listening(.microphone), .speaking(.microphone), .muted].contains { $0.label.hasPrefix(prefix) && $0.label.lowercased().contains("mute") } }, "every state of the mute button names the mute")
        expect(resolveStartupCaptureDevice(preferred: .microphone, microphoneAllowed: false) == .systemAudio, "revoked permission resolves actual startup")
        let leases = MicrophoneReservations()
        let old = leases.acquire(.practice)!
        leases.release(old)
        let new = leases.acquire(.interview)!
        leases.release(old)
        expect(leases.owns(new), "stale release cannot free a new owner's lease")
    }
}
