import Foundation

enum AudioSelectionError: LocalizedError {
    case microphoneBusy
    var errorDescription: String? { "The microphone is already reserved by Practice or another recording. Stop that recording first." }
}

/// Main-thread controller with a serialized hardware queue. Permission waits do not own that queue.
final class AudioCaptureCoordinator {
    private struct Slot {
        let id: UUID
        let capture: any AudioSourceCapture
        let lease: MicrophoneReservations.Lease?
    }

    private let make: (CaptureDevice) -> any AudioSourceCapture
    private let preflight: (CaptureDevice, Bool) async throws -> Void
    let reservations: MicrophoneReservations
    private var sessionID: UUID?
    private var requestID: UUID?
    private var epoch: UInt64 = 0
    private var active: Slot?
    private var owned: [UUID: Slot] = [:]
    private var permissionLeases: [UUID: MicrophoneReservations.Lease] = [:]
    private var pendingErrors: [UUID: Error] = [:]
    private var lifecycleTail: Task<Void, Never>?
    private var terminating = false
    private(set) var selectedDevice: CaptureDevice = .systemAudio
    private(set) var isMuted = false
    var activeDevice: CaptureDevice? { active?.capture.captureDevice }
    var isSwitching: Bool { requestID != nil }
    var sessionActive: Bool { sessionID != nil }

    var onStateChange: (() -> Void)?
    var onResetBuffers: (() -> Void)?
    var onCommitted: ((CaptureDevice, Bool) -> Void)?
    var onProblem: ((CaptureDevice, Error) -> Void)?
    var onLevel: ((Float, Bool) -> Void)?
    var onPreview: ((Data, CaptureDevice) -> Void)?
    var onCancelled: (() -> Void)?
    var onSegment: ((Data, CaptureDevice) -> Void)?
    var onStatus: ((String) -> Void)?

    init(reservations: MicrophoneReservations, initialDevice: CaptureDevice = .systemAudio,
         make: @escaping (CaptureDevice) -> any AudioSourceCapture,
         preflight: @escaping (CaptureDevice, Bool) async throws -> Void) {
        self.reservations = reservations
        self.selectedDevice = initialDevice
        self.make = make
        self.preflight = preflight
    }

    func startSession(device: CaptureDevice) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !terminating else { return }
        stopSession()
        sessionID = UUID()
        selectedDevice = device
        beginRequest(device, explicit: false)
    }

    func select(_ device: CaptureDevice) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !terminating, requestID == nil else { return }
        guard activeDevice != device else { return }
        beginRequest(device, explicit: true)
    }

    private func beginRequest(_ device: CaptureDevice, explicit: Bool) {
        let id = UUID()
        let session = sessionID
        requestID = id
        onStateChange?()
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.isCurrent(id, session) else { return }
            do {
                // A previous session can still own a mic while its hardware drains.
                if device == .microphone, self.reservations.current?.owner == .interview {
                    await self.lifecycleTail?.value
                    guard self.isCurrent(id, session) else { return }
                }
                if device == .microphone {
                    guard let lease = self.reservations.acquire(.interview) else { throw AudioSelectionError.microphoneBusy }
                    self.permissionLeases[id] = lease
                }
                try await self.preflight(device, true)
                guard self.isCurrent(id, session) else { self.releasePermission(id); return }
                if session == nil {
                    self.selectedDevice = device
                    self.releasePermission(id)
                    self.requestID = nil
                    self.onCommitted?(device, explicit)
                    self.onStateChange?()
                    return
                }
                let predecessor = self.lifecycleTail
                self.lifecycleTail = Task { @MainActor [weak self] in
                    await predecessor?.value
                    guard let self else { return }
                    guard self.isCurrent(id, session) else { self.releasePermission(id); return }
                    await self.performSwitch(device, id: id, session: session, explicit: explicit)
                }
            } catch {
                self.releasePermission(id)
                guard self.isCurrent(id, session) else { return }
                self.requestID = nil
                self.onStateChange?()
                self.onProblem?(device, error)
            }
        }
    }

    @MainActor private func performSwitch(_ device: CaptureDevice, id: UUID, session: UUID?, explicit: Bool) async {
        let previous = active
        active = nil
        epoch &+= 1
        if let previous { detach(previous.capture) }
        onResetBuffers?()
        onStateChange?()
        if let previous { await drain(previous) }
        guard isCurrent(id, session) else { releasePermission(id); return }
        do {
            try await activate(device, id: id, session: session)
            guard isCurrent(id, session) else { return }
            finishSelection(device, id: id, explicit: explicit)
        } catch {
            releasePermission(id)
            guard isCurrent(id, session) else { return }
            let originalError = error
            if let previous {
                let fallback = previous.capture.captureDevice
                do {
                    try await preflight(fallback, false)
                    guard isCurrent(id, session) else { return }
                    if fallback == .microphone {
                        guard let lease = reservations.acquire(.interview) else { throw AudioSelectionError.microphoneBusy }
                        permissionLeases[id] = lease
                    }
                    try await activate(fallback, id: id, session: session)
                    guard isCurrent(id, session) else { return }
                    finishSelection(fallback, id: id, explicit: false)
                    onProblem?(device, originalError)
                    return
                } catch {
                    releasePermission(id)
                    guard isCurrent(id, session) else { return }
                }
            }
            requestID = nil
            onStateChange?()
            onProblem?(device, originalError)
        }
    }

    @MainActor private func activate(_ device: CaptureDevice, id: UUID, session: UUID?) async throws {
        guard isCurrent(id, session) else { throw CancellationError() }
        epoch &+= 1
        let slot = Slot(id: UUID(), capture: make(device), lease: permissionLeases.removeValue(forKey: id))
        owned[slot.id] = slot
        installCallbacks(slot, session: session, epoch: epoch)
        slot.capture.setMuted(isMuted)
        do {
            try await slot.capture.startCapturing()
            if let failure = pendingErrors.removeValue(forKey: slot.id) { throw failure }
            guard isCurrent(id, session) else { throw CancellationError() }
            slot.capture.setMuted(isMuted)
            active = slot
        } catch {
            await drain(slot)
            throw error
        }
    }

    private func finishSelection(_ device: CaptureDevice, id: UUID, explicit: Bool) {
        guard requestID == id else { return }
        selectedDevice = device
        requestID = nil
        onCommitted?(device, explicit)
        onStateChange?()
    }

    private func isCurrent(_ id: UUID, _ session: UUID?) -> Bool {
        !terminating && requestID == id && sessionID == session
    }

    private func accepts(_ slot: UUID, _ session: UUID?, _ generation: UInt64) -> Bool {
        session != nil && sessionID == session && active?.id == slot && epoch == generation
    }

    private func installCallbacks(_ slot: Slot, session: UUID?, epoch generation: UInt64) {
        let device = slot.capture.captureDevice
        let slotID = slot.id
        slot.capture.onLevelUpdate = { [weak self] db, speaking in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.accepts(slotID, session, generation) else { return }
                self.onLevel?(db, speaking)
            }
        }
        slot.capture.onSpeechPreview = { [weak self] data in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.accepts(slotID, session, generation) else { return }
                self.onPreview?(data, device)
            }
        }
        slot.capture.onSpeechCancelled = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.accepts(slotID, session, generation) else { return }
                self.onCancelled?()
            }
        }
        slot.capture.onSpeechSegment = { [weak self] data in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.accepts(slotID, session, generation) else { return }
                self.onSegment?(data, device)
            }
        }
        slot.capture.onStatusChange = { [weak self] status in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.accepts(slotID, session, generation) else { return }
                self.onStatus?(status)
            }
        }
        slot.capture.onCaptureFailed = { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.sessionID == session, self.epoch == generation,
                      let failedSlot = self.owned[slotID] else { return }
                if self.active?.id != slotID {
                    self.pendingErrors[slotID] = error
                    return
                }
                self.active = nil
                self.epoch &+= 1
                self.detach(failedSlot.capture)
                let predecessor = self.lifecycleTail
                self.lifecycleTail = Task { @MainActor [weak self] in
                    await predecessor?.value
                    await self?.drain(failedSlot)
                }
                self.onStateChange?()
                self.onProblem?(device, error)
            }
        }
    }

    func setMuted(_ muted: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        isMuted = muted
        for slot in owned.values { slot.capture.setMuted(muted) }
        onStateChange?()
    }

    func stopSession() {
        dispatchPrecondition(condition: .onQueue(.main))
        sessionID = nil
        requestID = nil
        epoch &+= 1
        active = nil
        isMuted = false
        for id in Array(permissionLeases.keys) { releasePermission(id) }
        let slots = Array(owned.values)
        for slot in slots { detach(slot.capture) }
        let predecessor = lifecycleTail
        lifecycleTail = Task { @MainActor [weak self] in
            await predecessor?.value
            guard let self else { return }
            for slot in slots where self.owned[slot.id] != nil { await self.drain(slot) }
        }
        onStateChange?()
    }

    func terminate() {
        dispatchPrecondition(condition: .onQueue(.main))
        terminating = true
        stopSession()
        for slot in owned.values { slot.capture.stopCapturingSync() }
    }

    @MainActor func waitForHardwareIdle() async { await lifecycleTail?.value }

    @MainActor private func drain(_ slot: Slot) async {
        detach(slot.capture)
        await slot.capture.stopCapturing()
        owned[slot.id] = nil
        pendingErrors[slot.id] = nil
        if let lease = slot.lease { reservations.release(lease) }
    }

    private func releasePermission(_ id: UUID) {
        if let lease = permissionLeases.removeValue(forKey: id) { reservations.release(lease) }
    }

    private func detach(_ capture: any AudioSourceCapture) {
        capture.onLevelUpdate = nil
        capture.onSpeechPreview = nil
        capture.onSpeechCancelled = nil
        capture.onSpeechSegment = nil
        capture.onStatusChange = nil
        capture.onCaptureFailed = nil
    }
}
