import Cocoa

// This harness links the real processor, clients, domain models, and exporter.
// Only transport responses and clocks are faked; no production logic is copied.
private final class Channel<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Value] = []
    private var waiters: [CheckedContinuation<Value, Never>] = []

    func send(_ value: Value) {
        lock.lock()
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            lock.unlock()
            waiter.resume(returning: value)
        } else {
            values.append(value)
            lock.unlock()
        }
    }

    func next() async -> Value {
        await withCheckedContinuation { continuation in
            lock.lock()
            if !values.isEmpty {
                let value = values.removeFirst()
                lock.unlock()
                continuation.resume(returning: value)
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }
}

private final class CompletionEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var completed: Set<UUID> = []
    private var waiters: [UUID: [CheckedContinuation<Void, Never>]] = [:]

    func complete(_ id: UUID) {
        lock.lock()
        completed.insert(id)
        let pending = waiters.removeValue(forKey: id) ?? []
        lock.unlock()
        pending.forEach { $0.resume() }
    }

    func wait(for id: UUID) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if completed.contains(id) {
                lock.unlock()
                continuation.resume()
            } else {
                waiters[id, default: []].append(continuation)
                lock.unlock()
            }
        }
    }
}

private final class BufferClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 100)
    private var reads = 0

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        reads += 1
        return value
    }

    func advance(by seconds: TimeInterval) {
        lock.lock()
        value = value.addingTimeInterval(seconds)
        lock.unlock()
    }

    var readCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return reads
    }
}

private struct TranscriptionCall {
    let input: String
    let response = Channel<String>()
}

private struct AnswerCall {
    let onChunk: (String) -> Void
    let completion = Channel<Result<Void, Error>>()
}

private final class FakeGroqClient: GroqInterviewClient {
    enum AnswerMode { case success, empty, held }
    let answerMode: AnswerMode
    let heldTranscription: String?
    let transcriptionCalls = Channel<TranscriptionCall>()
    let answerCalls = Channel<AnswerCall>()
    private(set) var cancellationCount = 0

    init(answerMode: AnswerMode = .success, heldTranscription: String? = nil) {
        self.answerMode = answerMode
        self.heldTranscription = heldTranscription
        super.init(apiKey: "test-no-network")
    }

    override func warmupConnection() async {}
    override func cancelCurrentRequest() { cancellationCount += 1 }

    override func transcribe(audioData: Data, filename: String? = nil) async throws -> (text: String, latencyMs: Double) {
        let input = String(decoding: audioData, as: UTF8.self)
        guard input == heldTranscription else { return (input, 0) }
        let call = TranscriptionCall(input: input)
        transcriptionCalls.send(call)
        return (await call.response.next(), 0)
    }

    override func streamAnswer(topic: String, transcription: String, userBackground: String? = nil,
                               context: String? = nil, onChunk: @escaping (String) -> Void) async -> Result<Void, Error> {
        switch answerMode {
        case .success:
            onChunk("- The answer comes from the deterministic Groq transport.")
            return .success(())
        case .empty:
            return .success(())
        case .held:
            let call = AnswerCall(onChunk: onChunk)
            answerCalls.send(call)
            return await call.completion.next()
        }
    }
}

private struct ClassificationResponse {
    let status: String
    let topic: String
    let answer: String
}

private struct ClassificationCall {
    let transcription: String
    let buffer: String
    let response = Channel<ClassificationResponse>()

    func finish(status: String, topic: String = "architecture", answer: String = "") {
        response.send(ClassificationResponse(status: status, topic: topic, answer: answer))
    }
}

private final class FakeAnthropicClient: AnthropicClient {
    let classificationCalls = Channel<ClassificationCall>()
    private(set) var cancellationCount = 0

    init() { super.init(apiKey: "test-no-network") }
    override func warmupConnection() async {}
    override func cancelCurrentRequest() { cancellationCount += 1 }
    override func summarizeConversation(conversationText: String) async throws -> String { "Test conversation summary" }

    override func streamTextMessage(prompt: String, maxTokens: Int = 300,
                                    onChunk: @escaping (String) -> Void) async -> Result<Void, Error> {
        onChunk("- The answer comes from the deterministic direct transport.")
        return .success(())
    }

    override func classifyAndStreamAnswer(transcription: String, buffer: String, lastTopic: String?,
                                         userBackground: String?, multiTurnMessages: [[String: String]],
                                         jevMaySuppressAnswer: Bool = false,
                                         onClassification: @escaping (UtteranceClassification) -> Void,
                                         onAnswerChunk: @escaping (String) -> Void) async -> Result<Void, Error> {
        let call = ClassificationCall(transcription: transcription, buffer: buffer)
        classificationCalls.send(call)
        let response = await call.response.next()
        onClassification(UtteranceClassification(status: response.status, topic: response.topic))
        if !response.answer.isEmpty { onAnswerChunk(response.answer) }
        return .success(())
    }
}

private final class RecordingDelegate: VoiceInterviewProcessorDelegate {
    let userBackground = ""
    let pinnedSolution: String? = nil
    let conversationContext = ConversationContext()
    let started = Channel<UUID>()
    let chunks = Channel<UUID>()
    let hidden = CompletionEvents()
    let finished = CompletionEvents()
    private var observedTurns: Set<UUID> = []
    private(set) var messages: [InterviewMessage] = []
    private(set) var answers: [UUID: String] = [:]

    func processorShowLoading(_ message: String, color: NSColor, turnID: UUID) {
        if observedTurns.insert(turnID).inserted { started.send(turnID) }
    }
    func processorHideLoading(turnID: UUID) { hidden.complete(turnID) }
    func processorDidReceiveQuestion(_ text: String, topic: String, messageType: InterviewMessage.MessageType,
                                     source: CaptureDevice, turnID: UUID, sequence: Int) {
        messages.append(InterviewMessage(type: .question, content: text, topic: topic,
                                        audioSource: source, turnID: turnID, turnSequence: sequence))
    }
    func processorDidStartStreaming(messageType: InterviewMessage.MessageType, topic: String,
                                    latencyMs: Int?, turnID: UUID, sequence: Int) {}
    func processorDidReceiveAnswerChunk(_ fullContent: String, turnID: UUID) {
        answers[turnID] = fullContent
        chunks.send(turnID)
    }
    func processorDidFinishAnswer(_ fullAnswer: String, totalLatencyMs: Int?, turnID: UUID) {
        answers[turnID] = fullAnswer
        finished.complete(turnID)
    }
    func processorDidUpdateStatus(_ message: String) {}
    func processorDidUpdateBriefing(_ briefing: InterviewBriefing) {}
    func processorDidUpdateCodingTask(_ content: String) {}
}

@main
private struct CaptureProcessorTests {
    @MainActor private static var checks = 0

    @MainActor private static func expect(_ condition: @autoclosure () -> Bool, _ message: String,
                                          file: StaticString = #file, line: UInt = #line) {
        checks += 1
        guard condition() else { fatalError("FAIL: \(message)", file: file, line: line) }
    }

    @MainActor private static func setup(groq: FakeGroqClient = FakeGroqClient(), clock: BufferClock = BufferClock())
        -> (VoiceInterviewProcessor, RecordingDelegate, FakeAnthropicClient) {
        let processor = VoiceInterviewProcessor(bufferNow: clock.now)
        let delegate = RecordingDelegate()
        let anthropic = FakeAnthropicClient()
        processor.delegate = delegate
        processor.configure(groqClient: groq, anthropicClient: anthropic)
        return (processor, delegate, anthropic)
    }

    @MainActor private static func begin(_ text: String, device: CaptureDevice, processor: VoiceInterviewProcessor,
                                         delegate: RecordingDelegate) async -> UUID {
        processor.processAudioSegment(Data(text.utf8), source: device)
        return await delegate.started.next()
    }

    @MainActor private static func checkExport(_ delegate: RecordingDelegate, device: CaptureDevice) throws {
        let json = ExportInterviewUseCase().execute(messages: delegate.messages, format: .json)
        let decoded = try JSONDecoder().decode(ExportData.self, from: Data(json.utf8))
        expect(decoded.messages.count == 1, "Exactly one exported question")
        expect(decoded.messages.first?.audioSource == device.rawValue, "Export retains immutable capture provenance")
        expect(json.contains("\"audioSource\""), "Export keeps the existing field name")
        expect(!json.contains("captureDevice"), "Export does not introduce a renamed JSON field")
    }

    @MainActor private static func testProvenance(device: CaptureDevice, directFallback: Bool) async throws {
        let groq = FakeGroqClient(answerMode: directFallback ? .empty : .success)
        let (processor, delegate, anthropic) = setup(groq: groq)
        let turn = await begin("What is a hash map?", device: device, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: turn)
        expect(delegate.messages.count == 1, "Audio reaches an answer path for \(device)")
        expect(delegate.messages.first?.audioSource == device, "Direct answer publishes the captured device")
        expect(delegate.messages.first?.turnSequence == 1, "First accepted turn has sequence one")
        expect(delegate.answers[turn]?.isEmpty == false, "Answer body is populated")
        try checkExport(delegate, device: device)
        expect(groq.cancellationCount == 0 && anthropic.cancellationCount == 0, "No shared API cancellation")
    }

    @MainActor private static func testDelayedClassifierProvenance(device: CaptureDevice) async throws {
        let (processor, delegate, anthropic) = setup()
        let turn = await begin("A distributed service", device: device, processor: processor, delegate: delegate)
        let call = await anthropic.classificationCalls.next()
        processor.resetCaptureBuffers()
        call.finish(status: "question", answer: "- Keep independent workers behind a queue.")
        await delegate.hidden.wait(for: turn)
        expect(delegate.messages.first?.audioSource == device, "An accepted old classifier keeps its device after switching")
        expect(delegate.answers[turn]?.isEmpty == false, "Accepted old classifier still finishes")
        try checkExport(delegate, device: device)
    }

    @MainActor private static func testStaleIncomplete(device: CaptureDevice, status: String, comma: Bool) async {
        let (processor, delegate, anthropic) = setup()
        let oldText = comma ? "Consider a design," : "Consider a design with"
        let oldTurn = await begin(oldText, device: device, processor: processor, delegate: delegate)
        let oldCall = await anthropic.classificationCalls.next()
        processor.resetCaptureBuffers()
        oldCall.finish(status: status)
        await delegate.hidden.wait(for: oldTurn)

        let nextDevice: CaptureDevice = device == .microphone ? .systemAudio : .microphone
        let newTurn = await begin("A separate server", device: nextDevice, processor: processor, delegate: delegate)
        let newCall = await anthropic.classificationCalls.next()
        expect(newCall.buffer.isEmpty, "Late old incomplete result cannot cross the capture boundary (\(status), comma=\(comma))")
        newCall.finish(status: "statement")
        await delegate.hidden.wait(for: newTurn)
        expect(delegate.messages.isEmpty, "Old incomplete fragments must return without generating answers")
    }

    @MainActor private static func testStaleSTTCannotReadOrExpireNewBuffer() async {
        let oldText = "Consider the earlier plan with"
        let groq = FakeGroqClient(heldTranscription: oldText)
        let clock = BufferClock()
        let (processor, delegate, anthropic) = setup(groq: groq, clock: clock)
        let oldTurn = await begin(oldText, device: .systemAudio, processor: processor, delegate: delegate)
        let oldSTT = await groq.transcriptionCalls.next()
        processor.resetCaptureBuffers()

        let newText = "Assume a service with"
        let newTurn = await begin(newText, device: .microphone, processor: processor, delegate: delegate)
        let newCall = await anthropic.classificationCalls.next()
        newCall.finish(status: "incomplete")
        await delegate.hidden.wait(for: newTurn)
        let readsBeforeOldWork = clock.readCount

        oldSTT.response.send(oldText)
        let oldCall = await anthropic.classificationCalls.next()
        expect(oldCall.buffer.isEmpty, "Old STT cannot read new-source continuation")
        oldCall.finish(status: "incomplete")
        await delegate.hidden.wait(for: oldTurn)
        expect(clock.readCount == readsBeforeOldWork, "Stale work cannot expire or refresh the new buffer's timestamp")

        let continuation = await begin("separate retry queues", device: .microphone, processor: processor, delegate: delegate)
        let continuationCall = await anthropic.classificationCalls.next()
        expect(continuationCall.buffer == newText, "New continuation survives late old-source work")
        continuationCall.finish(status: "statement")
        await delegate.hidden.wait(for: continuation)
    }

    @MainActor private static func testOldSnapshotCannotConsumeNewBuffer() async {
        let (processor, delegate, anthropic) = setup()
        let prefix = "Consider a design with"
        let prefixTurn = await begin(prefix, device: .systemAudio, processor: processor, delegate: delegate)
        let prefixCall = await anthropic.classificationCalls.next()
        prefixCall.finish(status: "incomplete")
        await delegate.hidden.wait(for: prefixTurn)
        let oldTurn = await begin("persistent work queues", device: .systemAudio, processor: processor, delegate: delegate)
        let oldCall = await anthropic.classificationCalls.next()
        expect(oldCall.buffer == prefix, "Old turn captures its local continuation before switching")
        processor.resetCaptureBuffers()

        let newPrefix = "Assume a service with"
        let newTurn = await begin(newPrefix, device: .microphone, processor: processor, delegate: delegate)
        let newCall = await anthropic.classificationCalls.next()
        newCall.finish(status: "incomplete")
        await delegate.hidden.wait(for: newTurn)
        oldCall.finish(status: "question", answer: "- Persist jobs before acknowledging them.")
        await delegate.hidden.wait(for: oldTurn)
        expect(delegate.messages.first?.content == "\(prefix) persistent work queues", "Accepted old local snapshot may finish")
        expect(delegate.messages.first?.audioSource == .systemAudio, "Old snapshot retains provenance")
        expect(delegate.messages.first?.turnSequence == 2, "Source switching does not restart sequence allocation")

        let nextTurn = await begin("separate retry queues", device: .microphone, processor: processor, delegate: delegate)
        let nextCall = await anthropic.classificationCalls.next()
        expect(nextCall.buffer == newPrefix, "Old local snapshot cannot consume the new source's buffer")
        nextCall.finish(status: "statement")
        await delegate.hidden.wait(for: nextTurn)
    }

    @MainActor private static func testStreamingAndDedupeSurviveSwitch() async {
        let groq = FakeGroqClient(answerMode: .held)
        let (processor, delegate, anthropic) = setup(groq: groq)
        let turn = await begin("What is a hash map?", device: .microphone, processor: processor, delegate: delegate)
        let call = await groq.answerCalls.next()
        call.onChunk("- Store keys in buckets.")
        _ = await delegate.chunks.next()
        processor.resetCaptureBuffers()
        call.onChunk("\n- Resolve collisions explicitly.")
        call.completion.send(.success(()))
        await delegate.hidden.wait(for: turn)
        expect(delegate.answers[turn]?.contains("Resolve collisions") == true, "Existing answer finishes across switch")
        expect(delegate.messages.first?.audioSource == .microphone, "Streaming turn keeps its original device")
        expect(groq.cancellationCount == 0 && anthropic.cancellationCount == 0, "Switch never calls shared request cancellation")

        let duplicate = await begin("What is a hash map?", device: .systemAudio, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: duplicate)
        expect(delegate.messages.count == 1, "Dedupe history survives source switch")
        let nextTurn = await begin("What is inheritance?", device: .systemAudio, processor: processor, delegate: delegate)
        let nextCall = await groq.answerCalls.next()
        nextCall.onChunk("- Derive behavior from a parent type.")
        nextCall.completion.send(.success(()))
        await delegate.hidden.wait(for: nextTurn)
        expect(delegate.messages.last?.turnSequence == 3, "Turn numbering stays monotonic after a deduped turn")
    }

    @MainActor private static func testPreviewCancellationPreservesAcceptedTurn() async {
        let audioText = "What is a hash map?"
        let groq = FakeGroqClient(heldTranscription: audioText)
        let (processor, delegate, anthropic) = setup(groq: groq)
        processor.prefetchTranscription(Data(audioText.utf8), source: .systemAudio)
        let preview = await groq.transcriptionCalls.next()
        let turn = await begin(audioText, device: .systemAudio, processor: processor, delegate: delegate)
        processor.resetCaptureBuffers()
        preview.response.send("What is inheritance?")
        let committedSTT = await groq.transcriptionCalls.next()
        committedSTT.response.send(audioText)
        await delegate.hidden.wait(for: turn)
        expect(delegate.messages.first?.content == audioText, "Invalidated preview is not reused by an accepted turn")
        expect(delegate.answers[turn]?.isEmpty == false, "Accepted turn retranscribes after preview cancellation")
        expect(groq.cancellationCount == 0 && anthropic.cancellationCount == 0, "Preview cancellation is task scoped")
    }

    @MainActor private static func testCurrentBufferStillExpires() async {
        let clock = BufferClock()
        let (processor, delegate, anthropic) = setup(clock: clock)
        let turn = await begin("Consider a design with", device: .systemAudio, processor: processor, delegate: delegate)
        let call = await anthropic.classificationCalls.next()
        call.finish(status: "incomplete")
        await delegate.hidden.wait(for: turn)
        clock.advance(by: AppConstants.Thresholds.bufferTimeout + 1)
        let nextTurn = await begin("A separate server", device: .systemAudio, processor: processor, delegate: delegate)
        let nextCall = await anthropic.classificationCalls.next()
        expect(nextCall.buffer.isEmpty, "Current-generation buffer timeout behavior is preserved")
        nextCall.finish(status: "statement")
        await delegate.hidden.wait(for: nextTurn)
    }

    @MainActor static func main() async throws {
        // Fail boundedly if a route unexpectedly stops reaching a controlled callback.
        // This is a suite timeout, not an ordering mechanism or test sleep.
        let watchdog = DispatchWorkItem { fatalError("Processor integration suite timed out") }
        DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: watchdog)
        defer { watchdog.cancel() }
        UserDefaults.standard.setVolatileDomain([
            "InterviewMaster.Role": "software_engineer",
            "InterviewMaster.ProgrammingLanguage": "swift",
            "InterviewMaster.ListeningLanguage": "en",
            "InterviewMaster.ResponseLanguage": "en"
        ], forName: UserDefaults.argumentDomain)

        for device in CaptureDevice.allCases {
            expect(CaptureDevice(rawValue: device.rawValue) == device, "Existing source raw value round-trips")
            try await testProvenance(device: device, directFallback: false)
            try await testProvenance(device: device, directFallback: true)
            try await testDelayedClassifierProvenance(device: device)
            await testStaleIncomplete(device: device, status: "incomplete", comma: false)
            await testStaleIncomplete(device: device, status: "question", comma: false)
            await testStaleIncomplete(device: device, status: "question", comma: true)
        }
        await testStaleSTTCannotReadOrExpireNewBuffer()
        await testOldSnapshotCannotConsumeNewBuffer()
        await testStreamingAndDedupeSurviveSwitch()
        await testPreviewCancellationPreservesAcceptedTurn()
        await testCurrentBufferStillExpires()
        print("Capture processor integration: \(checks) checks passed")
    }
}
