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
    private let requestLock = NSLock()
    private var recorded: [AnswerRequest] = []

    private func record(_ request: AnswerRequest) {
        requestLock.lock()
        recorded.append(request)
        requestLock.unlock()
    }

    struct AnswerRequest {
        let topic: String
        let topicInherited: Bool
        let context: String?
        let pinnedSolution: String?
    }

    var requests: [AnswerRequest] {
        requestLock.lock()
        defer { requestLock.unlock() }
        return recorded
    }

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
                               context: String? = nil, contextIsFollowUp: Bool = true, topicInherited: Bool = false,
                               pinnedSolution: String? = nil,
                               onChunk: @escaping (String) -> Void) async -> Result<Void, Error> {
        record(AnswerRequest(topic: topic, topicInherited: topicInherited, context: context, pinnedSolution: pinnedSolution))
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
    private let logLock = NSLock()
    private var loggedPrompts: [String] = []
    private var classifications = 0
    var directReply = "- The answer comes from the deterministic direct transport."
    var codingReply = ""
    /// Replies for consecutive coding prompts, oldest first; `codingReply` answers once they run out.
    var codingReplies: [String] = []

    private func nextCodingReply() -> String {
        logLock.lock()
        defer { logLock.unlock() }
        return codingReplies.isEmpty ? codingReply : codingReplies.removeFirst()
    }

    private func logPrompt(_ prompt: String) {
        logLock.lock()
        loggedPrompts.append(prompt)
        logLock.unlock()
    }

    private func countClassification() {
        logLock.lock()
        classifications += 1
        logLock.unlock()
    }

    var prompts: [String] {
        logLock.lock()
        defer { logLock.unlock() }
        return loggedPrompts
    }

    var classificationCount: Int {
        logLock.lock()
        defer { logLock.unlock() }
        return classifications
    }

    init() { super.init(apiKey: "test-no-network") }
    override func warmupConnection() async {}
    override func cancelCurrentRequest() { cancellationCount += 1 }
    override func summarizeConversation(conversationText: String) async throws -> String { "Test conversation summary" }

    override func streamTextMessage(prompt: String, maxTokens: Int = 300,
                                    onChunk: @escaping (String) -> Void) async -> Result<Void, Error> {
        logPrompt(prompt)
        let isCodingPrompt = prompt.contains("live coding interview copilot")
        // Deliver the reply in small pieces, the way a real stream arrives.
        let codingAnswer = isCodingPrompt ? nextCodingReply() : ""
        let reply = isCodingPrompt && !codingAnswer.isEmpty ? codingAnswer : directReply
        var index = reply.startIndex
        while index < reply.endIndex {
            let end = reply.index(index, offsetBy: 24, limitedBy: reply.endIndex) ?? reply.endIndex
            onChunk(String(reply[index..<end]))
            index = end
        }
        return .success(())
    }

    override func classifyAndStreamAnswer(transcription: String, buffer: String, lastTopic: String?,
                                         userBackground: String?, multiTurnMessages: [[String: String]],
                                         jevMaySuppressAnswer: Bool = false,
                                         onClassification: @escaping (UtteranceClassification) -> Void,
                                         onAnswerChunk: @escaping (String) -> Void) async -> Result<Void, Error> {
        countClassification()
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
    private(set) var codingUpdates: [String] = []
    private(set) var codingStarts: [CodingTaskInfo] = []
    private(set) var codingOutcomes: [CodingTaskOutcome] = []
    let codingFinished = Channel<CodingTaskOutcome>()

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
    var statuses: [String] = []
    func processorDidUpdateStatus(_ message: String) { statuses.append(message) }
    func processorDidUpdateBriefing(_ briefing: InterviewBriefing) {}
    func processorDidUpdateCodingTask(_ content: String) { codingUpdates.append(content) }
    func processorDidStartCodingTask(_ info: CodingTaskInfo) { codingStarts.append(info) }
    func processorDidFinishCodingTask(_ outcome: CodingTaskOutcome) {
        codingOutcomes.append(outcome)
        codingFinished.send(outcome)
    }
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

    // MARK: - Speech in pieces

    /// The sequence from a real run: a question cut at a pause, a filler tail, then garbled speech.
    @MainActor private static func testMumbledQuestionIsAnsweredOnce() async {
        let (processor, delegate, _) = setup()
        for piece in ["Okay, how to read a huge Python file with 10,000 rows and what...", "kind of, let's say,", "Aki, di, sari, u, gontu, yus?"] {
            let turn = await begin(piece, device: .microphone, processor: processor, delegate: delegate)
            await delegate.hidden.wait(for: turn)
            expect(delegate.messages.isEmpty, "Nothing is answered while the question is still going: \(piece)")
        }
        for _ in 0..<40 where delegate.messages.isEmpty {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        expect(delegate.messages.count == 1, "The pieces become one question")
        let question = delegate.messages.first?.content ?? ""
        expect(question == "Okay, how to read a huge Python file with 10,000 rows", "It is answered without the tail or the garbled words: \(question)")
        expect(delegate.statuses.isEmpty, "A held question needs no 'didn't catch that'")
    }

    /// The same speech as Whisper wrote it from clean system audio: other punctuation, other scraps.
    @MainActor private static func testMumbledQuestionSurvivesTranscriptionPunctuation() async {
        let (processor, delegate, _) = setup()
        for piece in ["Okay, how to read a huge python file with 10,000 rows and what?", "Kind of, let's say.", "Aki, D, sorry, U, gone to, yas?"] {
            let turn = await begin(piece, device: .systemAudio, processor: processor, delegate: delegate)
            await delegate.hidden.wait(for: turn)
            expect(delegate.messages.isEmpty, "Nothing is answered while the question is still going: \(piece)")
        }
        for _ in 0..<40 where delegate.messages.isEmpty {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        expect(delegate.messages.map(\.content) == ["Okay, how to read a huge python file with 10,000 rows"], "One question, without the tail")
    }

    /// From a real run: the missing space hides the question from the local signal, so only the model hears it.
    @MainActor private static func testCommaEndedQuestionTheModelHeardIsAnsweredAfterSilence() async {
        let (processor, delegate, anthropic) = setup()
        let turn = await begin("whatisObject.freeze,", device: .microphone, processor: processor, delegate: delegate)
        let call = await anthropic.classificationCalls.next()
        call.finish(status: "question", topic: "typescript", answer: "- It makes an object read-only.")
        await delegate.hidden.wait(for: turn)
        expect(delegate.messages.isEmpty, "It waits in case the question goes on")
        for _ in 0..<40 where delegate.messages.isEmpty {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        expect(delegate.messages.first?.content == "whatisObject.freeze", "Silence answers it without the comma")
        expect(delegate.messages.count == 1, "It is answered once")
    }

    @MainActor private static func testCommaEndedQuestionStillJoinsTheNextPiece() async {
        let (processor, delegate, anthropic) = setup()
        let turn = await begin("whatisObject.freeze,", device: .microphone, processor: processor, delegate: delegate)
        let call = await anthropic.classificationCalls.next()
        call.finish(status: "question", topic: "typescript")
        await delegate.hidden.wait(for: turn)
        let next = await begin("and when would you use it", device: .microphone, processor: processor, delegate: delegate)
        let nextCall = await anthropic.classificationCalls.next()
        expect(nextCall.buffer == "whatisObject.freeze,", "The next piece takes the held question over")
        nextCall.finish(status: "question", topic: "typescript", answer: "- Use it for shared config.")
        await delegate.hidden.wait(for: next)
        try? await Task.sleep(nanoseconds: UInt64((AppConstants.Thresholds.bufferedQuestionSilence + 0.5) * 1_000_000_000))
        expect(delegate.messages.count == 1, "The timer does not answer it a second time")
        expect(delegate.messages.first?.content == "whatisObject.freeze, and when would you use it", "It is one question")
    }

    @MainActor private static func testGarbledSpeechIsNeverGuessedAt() async {
        let (processor, delegate, _) = setup()
        let turn = await begin("Aki, di, sari, u, gontu, yus?", device: .microphone, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: turn)
        expect(delegate.messages.isEmpty, "Garbled speech opens no card")
        expect(delegate.statuses == [FeedbackCopy.didntCatchThat], "It says so instead")
    }

    @MainActor private static func testFragmentJoinsTheQuestionBeforeIt() async {
        let (processor, delegate, anthropic) = setup()
        let question = await begin("What is a hash map?", device: .microphone, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: question)
        let fragment = await begin("kind of, let's say,", device: .microphone, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: fragment)
        let next = await begin("with a lot of collisions", device: .microphone, processor: processor, delegate: delegate)
        let nextCall = await anthropic.classificationCalls.next()
        expect(nextCall.buffer == "What is a hash map? kind of, let's say,", "The next piece is heard with the question: \(nextCall.buffer)")
        nextCall.finish(status: "statement")
        await delegate.hidden.wait(for: next)
    }

    // MARK: - Conversation understanding

    @MainActor private static func testCandidateSpeechDoesNotOpenACard() async {
        let (processor, delegate, anthropic) = setup()
        let text = "Yeah, of course, for me, like I have 10 plus years experience in software engineering, now focusing more on AI engineering, but in the past I started working with neural networks"
        let turn = await begin(text, device: .microphone, processor: processor, delegate: delegate)
        let call = await anthropic.classificationCalls.next()
        call.finish(status: "question", answer: "- I have ten years of experience.")
        await delegate.hidden.wait(for: turn)
        expect(delegate.messages.isEmpty, "The candidate's own answer never becomes an interviewer question card")
        expect(delegate.answers[turn] == nil, "No answer is generated for the candidate's own speech")
    }

    @MainActor private static func testStallingIsSkippedBeforeAnyModelCall() async {
        let (processor, delegate, anthropic) = setup()
        for phrase in ["Okay, just give me a second.", "Sorry, can you repeat?"] {
            let turn = await begin(phrase, device: .microphone, processor: processor, delegate: delegate)
            await delegate.hidden.wait(for: turn)
        }
        expect(delegate.messages.isEmpty, "Stalling and repeat requests open no card")
        expect(anthropic.classificationCount == 0, "Stalling costs no classification call")
    }

    @MainActor private static func testStaleTopicNeverSteersAFreshQuestion() async {
        let groq = FakeGroqClient()
        let (processor, delegate, _) = setup(groq: groq)
        for question in ["What is RAG and CAG?", "So how do you evaluate a classifier?", "Have you used any of these?"] {
            let turn = await begin(question, device: .microphone, processor: processor, delegate: delegate)
            await delegate.hidden.wait(for: turn)
        }
        let requests = groq.requests
        expect(requests.count == 3, "All three clear questions take the fast path")
        expect(requests[0].topic == "ragCag" && !requests[0].topicInherited, "A named topic is used as named")
        expect(requests[1].topic == "unknown" && !requests[1].topicInherited, "A new concrete question is not forced onto the RAG topic")
        expect(requests[0].context == nil, "The first question of a session has no conversation to borrow")
        expect(requests[1].context?.contains("RAG and CAG") == true, "Later questions see the conversation so references resolve")
        expect(requests[2].topic == "ragCag" && requests[2].topicInherited, "A back-reference inherits the topic and says so")
        expect(requests[2].context?.contains("classifier") == true, "A back-reference receives the recent conversation")
    }

    @MainActor private static func testDirectPromptKeepsStaleTopicOut() async {
        let groq = FakeGroqClient(answerMode: .empty)
        let (processor, delegate, anthropic) = setup(groq: groq)
        for question in ["What is RAG and CAG?", "So how do you evaluate a classifier?", "Have you used any of these?"] {
            let turn = await begin(question, device: .microphone, processor: processor, delegate: delegate)
            await delegate.hidden.wait(for: turn)
        }
        let prompts = anthropic.prompts
        expect(prompts.count == 3, "Each question reaches the direct answer prompt")
        expect(prompts[0].contains("RAG/CAG ANSWER SHAPE") && prompts[0].contains("TOPIC: ragCag"), "A RAG question keeps the RAG answer shape")
        expect(!prompts[1].contains("RAG/CAG ANSWER SHAPE"), "A classifier question does not get the RAG answer shape")
        expect(!prompts[1].contains("\nTOPIC:") && !prompts[1].contains("PREVIOUS TOPIC"), "A classifier question carries no topic line")
        expect(prompts[1].contains("Answer the question as asked."), "A classifier question is answered as asked")
        expect(prompts[1].contains("=== CONVERSATION SO FAR ===") && prompts[1].contains("CURRENT question"), "The conversation is context for the current question only")
        expect(prompts[2].contains("PREVIOUS TOPIC (only if the question refers back to it): ragCag"), "A back-reference names the previous topic as a hint only")
        expect(prompts[2].contains("=== CONVERSATION SO FAR ==="), "A back-reference carries the recent conversation")
        expect(!prompts[2].contains("RAG/CAG ANSWER SHAPE"), "An inherited topic never imposes an answer shape")
    }

    @MainActor private static func testEmptyCombinedAnswerIsRecoveredOnTheOpenCard() async {
        let (processor, delegate, anthropic) = setup()
        let turn = await begin("A distributed service", device: .systemAudio, processor: processor, delegate: delegate)
        let call = await anthropic.classificationCalls.next()
        call.finish(status: "question", answer: "")
        await delegate.hidden.wait(for: turn)
        expect(delegate.messages.count == 1, "Recovery reuses the open card instead of opening another")
        expect(delegate.answers[turn]?.contains("deterministic direct transport") == true, "The direct stream fills the card")
        expect(delegate.answers[turn]?.lowercased().contains("error") == false, "No 'No answer text received' error is left behind")
    }

    @MainActor private static func testRetryFillsTheCardThatFailed() async {
        let (processor, delegate, _) = setup()
        let turn = UUID()
        processor.retryAnswer(turnID: turn, question: "What is a hash map?", topic: "hashMap", sequence: 3)
        await delegate.hidden.wait(for: turn)
        expect(delegate.messages.isEmpty, "A retry fills the card that failed; it opens no second question")
        expect(delegate.answers[turn]?.contains("deterministic direct transport") == true, "The answer streams onto the card that failed")
        expect(delegate.answers[turn]?.lowercased().contains("error") == false, "A retry that worked leaves no error behind")
    }

    // MARK: - Live coding

    private static let reverseReply = """
    SAY:
    - Restating: take a string, return it reversed.
    - Assumption: an empty string returns an empty string.
    - O(n) time, O(n) space.

    STEP 1 — file: main.py
    Why: Slice the string backwards.
    ```python
    def reverse(text):
        return text[::-1]
    ```
    """

    @MainActor private static func testCodingRequestFillsBothSides() async {
        let groq = FakeGroqClient()
        let (processor, delegate, anthropic) = setup(groq: groq)
        anthropic.codingReply = reverseReply

        let turn = await begin("Write a function that reverses a string", device: .systemAudio, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: turn)
        expect(delegate.messages.count == 1 && delegate.messages.first?.topic == "coding", "The coding request appears as a question on the left")
        let card = delegate.answers[turn] ?? ""
        expect(card.contains("Restating: take a string") && card.contains("O(n) time"), "Talking points go to the answer card")
        expect(!card.contains("Code is in the panel"), "Talking points need no pointer to the open panel")
        expect(!card.contains("def reverse"), "Code stays out of the answer card")
        expect(delegate.codingUpdates.last?.hasPrefix("STEP 1") == true, "Steps go to the code panel")
        expect(delegate.codingUpdates.last?.contains("def reverse(text):") == true, "The panel receives the code")
        expect(delegate.codingUpdates.allSatisfy { !$0.contains("SAY:") }, "Talking points never leak into the panel")
        expect(anthropic.classificationCount == 0 && groq.requests.isEmpty, "A coding request skips the cue-card paths")

        // The interviewer keeps dictating: the same card and panel update, no second card opens.
        let detail = await begin("like text, return string", device: .systemAudio, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: detail)
        expect(delegate.messages.count == 1, "A refinement does not open another card")
        expect(anthropic.prompts.last?.contains("Write a function that reverses a string like text, return string") == true, "The refined task carries everything said so far")
        expect(delegate.codingUpdates.count >= 2, "The panel is updated again")

        // A normal question in the middle of the exercise is answered on the left with the code as context.
        let question = await begin("What is polymorphism?", device: .systemAudio, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: question)
        expect(delegate.messages.count == 2 && delegate.messages.last?.topic == "polymorphism", "Questions keep getting answered on the left")
        expect(groq.requests.last?.topic == "polymorphism", "The question takes the normal fast path")
    }

    private static let typeScriptReply = """
    SAY:
    - Same logic in TypeScript: split, reverse, join.
    - Strings are immutable there too, so it is O(n) space.

    STEP 1 — file: reverse.ts
    Why: Split into characters, reverse, join.
    ```typescript
    function reverse(text: string): string {
      return text.split("").reverse().join("");
    }
    ```
    """

    /// The exact sequence that failed live: the panel showed Python while the interviewer asked for
    /// TypeScript, another way, and technique examples.
    @MainActor private static func testFollowUpsChangeTheCodeOnScreen() async {
        let groq = FakeGroqClient()
        let (processor, delegate, anthropic) = setup(groq: groq)
        anthropic.codingReplies = [reverseReply, typeScriptReply, reverseReply, reverseReply]

        let first = await begin("Write me a reverse function in Python.", device: .microphone, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: first)
        expect(delegate.codingUpdates.last?.contains("def reverse(text):") == true, "The first request puts Python on the panel")

        let language = await begin("Okay, now can you write it in TypeScript?", device: .microphone, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: language)
        expect(delegate.messages.count == 2 && delegate.messages.last?.content == "Okay, now can you write it in TypeScript?", "A language change opens its own card")
        expect(delegate.codingUpdates.last?.contains("function reverse(text: string)") == true, "The panel now holds the TypeScript version")
        let languagePrompt = anthropic.prompts.last ?? ""
        expect(languagePrompt.contains("CURRENT CODE (already on the candidate's screen)") && languagePrompt.contains("def reverse(text):"), "The model is shown the Python it has to convert")
        expect(languagePrompt.contains("CHANGE REQUEST") && languagePrompt.contains("write it in TypeScript"), "The model is told what to change")
        expect(delegate.answers[language]?.contains("Same logic in TypeScript") == true, "The card explains the change")
        expect(groq.requests.isEmpty && anthropic.classificationCount == 0, "A code change never falls through to a cue card")

        let alternative = await begin("Is there another way in Python to reverse it?", device: .microphone, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: alternative)
        expect(delegate.messages.count == 3, "Asking for another way opens a card")
        expect((anthropic.prompts.last ?? "").contains("function reverse(text: string)"), "Another way builds on the code that is on the panel now")

        let technique = await begin("Can you show me sliding window technique?", device: .microphone, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: technique)
        let techniquePrompt = anthropic.prompts.last ?? ""
        expect(delegate.messages.count == 4, "A technique example opens a card")
        expect(techniquePrompt.contains("sliding window") && !techniquePrompt.contains("CURRENT CODE"), "A technique example starts clean instead of editing the last code")

        let concept = await begin("What is polymorphism?", device: .microphone, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: concept)
        expect(groq.requests.count == 1 && groq.requests.last?.topic == "polymorphism", "A concept question in the middle is still a cue card")
    }

    private static let cutOffReply = """
    SAY:
    - Swap characters from both ends.

    STEP 1 — file: main.py
    Why: Walk the string from both ends.
    ```python
    def reverse(text):
        chars = list(text)
        left, right = 0, len(chars) - 1
        while left < right:
    """

    /// Panel actions: a one-click change, code that stops early, and Retry on the same card.
    @MainActor private static func testPanelActionsAndOutcomes() async {
        let groq = FakeGroqClient()
        let (processor, delegate, anthropic) = setup(groq: groq)
        anthropic.codingReplies = [reverseReply, cutOffReply, cutOffReply, reverseReply]

        // Nothing on screen yet: a panel action has nothing to change.
        processor.requestCodeChange("Optimize it")

        let first = await begin("Write a function that reverses a string", device: .microphone, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: first)
        _ = await delegate.codingFinished.next()
        expect(anthropic.prompts.count == 1, "A panel action without code sends nothing")
        expect(delegate.codingStarts.first?.request == "Write a function that reverses a string" && delegate.codingStarts.first?.allowsChanges == true, "The panel is told what was asked and that it can be changed")
        expect(delegate.codingStarts.first?.turnID == first && delegate.codingStarts.first?.isRefinement == false, "The code belongs to the card that asked for it")
        expect(delegate.codingOutcomes == [.complete], "Finished code reports complete")

        processor.requestCodeChange("Optimize it")
        let optimizeOutcome = await delegate.codingFinished.next()
        expect(delegate.messages.count == 2 && delegate.messages.last?.content == "Optimize it", "A panel action opens its own card, worded like a spoken request")
        let optimizePrompt = anthropic.prompts.last ?? ""
        expect(optimizePrompt.contains("CURRENT CODE") && optimizePrompt.contains("text[::-1]") && optimizePrompt.contains("Optimize it"), "The action is applied to the code on screen")
        guard case .incomplete(let reason) = optimizeOutcome else {
            expect(false, "Code that ends inside a fence is reported as incomplete")
            return
        }
        expect(!reason.isEmpty, "An incomplete outcome says why")
        let optimizeCard = delegate.answers[delegate.codingStarts[1].turnID] ?? ""
        expect(optimizeCard.contains("Use Try again in the panel"), "The card points at the way out, by the name on the button")

        // Cut-off code is not remembered as the code on screen.
        processor.requestCodeChange("Add tests for it")
        _ = await delegate.codingFinished.next()
        let testsPrompt = anthropic.prompts.last ?? ""
        expect(testsPrompt.contains("text[::-1]") && !testsPrompt.contains("chars = list(text)"), "The next change builds on the last complete code, not the fragment")

        // Retry runs the same request again on the same card.
        let cardsBeforeRetry = delegate.messages.count
        processor.retryLastCodingRequest()
        let retryOutcome = await delegate.codingFinished.next()
        expect(retryOutcome == .complete, "The retry finishes the code")
        expect(delegate.messages.count == cardsBeforeRetry, "A retry does not open another card")
        expect(delegate.codingStarts.last?.turnID == delegate.codingStarts[delegate.codingStarts.count - 2].turnID && delegate.codingStarts.last?.isRefinement == false, "A retry restarts the version it belongs to")
        expect(delegate.codingUpdates.last?.contains("return text[::-1]") == true, "The retry puts full code on the panel")
    }

    @MainActor private static func testScreenOnlyRequestPointsAtTheShortcut() async {
        let (processor, delegate, anthropic) = setup()
        let turn = await begin("Write this code", device: .systemAudio, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: turn)
        expect(delegate.messages.count == 1, "The request still appears on the left")
        expect(delegate.answers[turn]?.contains("⌘S") == true, "The card says how to get the task in")
        expect(anthropic.prompts.isEmpty && anthropic.classificationCount == 0, "No model invents a task that is only on the screen")
        expect(delegate.codingUpdates.isEmpty, "Nothing is sent to the code panel")
    }

    @MainActor private static func testSessionStartOpensNoCardButCollectsTheTask() async {
        let (processor, delegate, anthropic) = setup()
        anthropic.codingReply = reverseReply
        let arm = await begin("Okay, let's start a new Python file.", device: .systemAudio, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: arm)
        expect(delegate.messages.isEmpty && anthropic.classificationCount == 0, "Starting a file is logistics, not a question")

        let task = await begin("Given a string, return its reverse", device: .systemAudio, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: task)
        expect(delegate.messages.count == 1 && delegate.codingUpdates.last?.hasPrefix("STEP 1") == true, "The first task statement in an armed session produces code")
    }

    @MainActor private static func testConversationalMlDiscussionIsNotCoding() async {
        let groq = FakeGroqClient()
        let (processor, delegate, anthropic) = setup(groq: groq)
        anthropic.codingReply = reverseReply
        let turn = await begin("Let's say we want to create a spam classifier. How would you evaluate it?", device: .systemAudio, processor: processor, delegate: delegate)
        let call = await anthropic.classificationCalls.next()
        call.finish(status: "question", topic: "classification", answer: "- Precision, recall, and F1 on a held-out set.")
        await delegate.hidden.wait(for: turn)
        expect(delegate.answers[turn]?.contains("Precision") == true, "The scenario question is answered as a normal cue card")
        expect(delegate.codingUpdates.isEmpty, "An ML scenario question does not open the code panel")
        expect(anthropic.prompts.allSatisfy { !$0.contains("live coding interview copilot") }, "No coding prompt is sent for a conceptual question")
    }

    /// From a live run: "show me that in code" and "is there an easier way?" got text cards.
    @MainActor private static func testCodeExampleAndEasierWay() async {
        let groq = FakeGroqClient()
        let (processor, delegate, anthropic) = setup(groq: groq)
        anthropic.codingReplies = [reverseReply, typeScriptReply]

        let concept = await begin("What is polymorphism?", device: .microphone, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: concept)
        expect(delegate.codingUpdates.isEmpty, "A concept question is a cue card")

        let example = await begin("Can you show me that in code?", device: .microphone, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: example)
        let examplePrompt = anthropic.prompts.last ?? ""
        expect(!delegate.codingUpdates.isEmpty, "Asking for it in code opens the code panel")
        expect(examplePrompt.contains("polymorphism"), "The code is about the question it points back at")
        expect(groq.requests.count == 1, "It does not become a second cue card")

        let easier = await begin("Is there some easier way?", device: .microphone, processor: processor, delegate: delegate)
        await delegate.hidden.wait(for: easier)
        let easierPrompt = anthropic.prompts.last ?? ""
        expect(easierPrompt.contains("CURRENT CODE (already on the candidate's screen)") && easierPrompt.contains("CHANGE REQUEST"), "An easier way changes the code on screen")
        expect(groq.requests.count == 1, "An easier way does not become a cue card")
    }

    /// The timeline keeps earlier interviews and their turn numbers start again at 1, so a save holds one.
    @MainActor private static func testSaveHoldsOnlyTheLatestInterview() {
        let earlier = [
            InterviewMessage(type: .question, content: "Write me a reverse function in Python.", turnSequence: 1),
            InterviewMessage(type: .answer, content: "- Slice it.", turnSequence: 1)
        ]
        Thread.sleep(forTimeInterval: 0.01)
        let startedAt = Date()
        let latest = [
            InterviewMessage(type: .question, content: "REST, SQL, K", turnSequence: 1),
            InterviewMessage(type: .answer, content: "- REST is HTTP APIs over resources.", turnSequence: 1)
        ]
        let kept = ExportInterviewUseCase.messages(earlier + latest, ofInterviewStartedAt: startedAt)
        expect(kept.map(\.content) == latest.map(\.content), "Only the latest interview is saved")
        expect(ExportInterviewUseCase.messages(earlier + latest, ofInterviewStartedAt: nil).count == 4, "Before any interview everything is kept")
        let json = ExportInterviewUseCase().execute(messages: kept, format: .json)
        expect(json.contains("REST, SQL, K") && !json.contains("reverse function in Python"), "The saved file has no question from the earlier interview")

        let context = ConversationContext()
        expect(context.lastInterviewerQuestion == nil, "No question yet")
        context.addUtterance(text: "What is polymorphism?", topic: "polymorphism", isQuestion: true, sequence: 1)
        context.addUtterance(text: "I used it in a payments service.", topic: nil, isQuestion: false, sequence: 2)
        expect(context.lastInterviewerQuestion == "What is polymorphism?", "The last question is the interviewer's, not the candidate's reply")
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
        await testMumbledQuestionIsAnsweredOnce()
        await testMumbledQuestionSurvivesTranscriptionPunctuation()
        await testCommaEndedQuestionTheModelHeardIsAnsweredAfterSilence()
        await testCommaEndedQuestionStillJoinsTheNextPiece()
        await testGarbledSpeechIsNeverGuessedAt()
        await testFragmentJoinsTheQuestionBeforeIt()
        await testCandidateSpeechDoesNotOpenACard()
        await testStallingIsSkippedBeforeAnyModelCall()
        await testStaleTopicNeverSteersAFreshQuestion()
        await testDirectPromptKeepsStaleTopicOut()
        await testEmptyCombinedAnswerIsRecoveredOnTheOpenCard()
        await testRetryFillsTheCardThatFailed()
        await testCodingRequestFillsBothSides()
        await testFollowUpsChangeTheCodeOnScreen()
        await testPanelActionsAndOutcomes()
        await testScreenOnlyRequestPointsAtTheShortcut()
        await testSessionStartOpensNoCardButCollectsTheTask()
        await testConversationalMlDiscussionIsNotCoding()
        await testCodeExampleAndEasierWay()
        testSaveHoldsOnlyTheLatestInterview()
        print("Capture processor integration: \(checks) checks passed")
    }
}
