import Foundation

private final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status,
                httpVersion: nil, headerFields: ["Content-Type": request.url!.host == "api.typesafe.ai" ? "application/json" : "text/event-stream"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@main struct JevTests {
    static var checks = 0
    static func check(_ value: Bool, _ name: String) {
        checks += 1
        if !value { fatalError("FAIL: \(name)") }
    }
    static func response(_ status: String, confidence: Double = 0.95, probability: Double = 0.96) -> Data {
        let probabilities = Dictionary(uniqueKeysWithValues: JevDecisionClient.criteria.keys.map {
            ($0, $0 == status ? probability : (1 - probability) / 4)
        })
        return try! JSONSerialization.data(withJSONObject: ["model": JevDecisionClient.model, "answers": ["intent": [
            "type": "choice", "choice": status, "confidence": confidence, "probabilities": probabilities
        ]]])
    }
    static func stream(_ text: String) -> Data {
        let data = try! JSONSerialization.data(withJSONObject: ["choices": [["delta": ["content": text]]]])
        return Data("data: \(String(data: data, encoding: .utf8)!)\n\ndata: [DONE]\n\n".utf8)
    }
    static func main() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let jev = JevDecisionClient(apiKey: "test-only", session: session)
        for status in JevDecisionClient.Status.allCases {
            let answer = try JevDecisionClient.validatedAnswer(response(status.rawValue))
            check(JevDecisionClient.acceptedStatus(answer) == (status == .uncertain ? nil : status), "decision \(status)")
        }
        check(JevDecisionClient.acceptedStatus(try JevDecisionClient.validatedAnswer(response("question", confidence: 0.2))) == nil, "uncertainty falls back")
        check(JevDecisionClient.acceptedStatus(try JevDecisionClient.validatedAnswer(response("question", probability: 0.6))) == nil, "diffuse distribution falls back")
        for data in [Data("{}".utf8), response("invented"), response("question", confidence: 2)] {
            do { _ = try JevDecisionClient.validatedAnswer(data); check(false, "reject invalid response") }
            catch { check(true, "invalid rejected") }
        }
        do { _ = try JevDecisionClient.requestBody(transcription: String(repeating: "я", count: 7000), buffer: "", lastTopic: nil, history: []); check(false, "oversize") }
        catch { check(true, "oversize falls back without clipping speech") }
        let bounded = try JevDecisionClient.requestBody(transcription: "А как работи?", buffer: "", lastTopic: "rag", history: Array(repeating: ["role": "user", "content": String(repeating: "x", count: 2000)], count: 20))
        check(bounded.count < 12000, "history bounded")

        // Link and run the real combined client: only HTTP transport is replaced.
        for scenario in ["question", "statement", "protected", "uncertain", "http", "malformed", "timeout"] {
            var modelCalls = 0
            StubProtocol.handler = { request in
                if request.url!.host == "api.typesafe.ai" {
                    if scenario == "http" { return (429, Data()) }
                    if scenario == "malformed" { return (200, Data("{}".utf8)) }
                    if scenario == "timeout" { throw URLError(.timedOut) }
                    return (200, response(scenario == "protected" ? "statement" : scenario))
                }
                modelCalls += 1
                return (200, stream(scenario == "question" ? "- A grounded answer." : "STATUS:question|TOPIC:unknown\n---\n- Fallback answer."))
            }
            let turnSession = URLSession(configuration: config)
            let client = AnthropicClient(apiKey: "test-only", session: turnSession)
            client.jevDecisionClient = JevDecisionClient(apiKey: "test-only", session: turnSession)
            var statuses: [String] = []
            var text = ""
            let result = await client.classifyAndStreamAnswer(transcription: "And that approach", buffer: "", lastTopic: nil,
                userBackground: nil, multiTurnMessages: [], jevMaySuppressAnswer: scenario != "protected",
                onClassification: { statuses.append($0.status) }, onAnswerChunk: { text += $0 })
            if case .failure = result { check(false, "scenario completed \(scenario)") }
            check(statuses == [scenario == "statement" ? "statement" : "question"], "one classification \(scenario)")
            check(modelCalls == (scenario == "statement" ? 0 : 1), "generation call count \(scenario)")
            check(scenario == "statement" ? text.isEmpty : text.hasPrefix("- "), "visible answer \(scenario)")
        }
        // Cancellation must not turn into an expensive fallback request.
        var calls = 0
        StubProtocol.handler = { _ in calls += 1; return (200, response("question")) }
        let cancelled = Task { () -> Bool in
            withUnsafeCurrentTask { $0?.cancel() }
            do { _ = try await jev.classify(transcription: "test", buffer: "", lastTopic: nil, history: []); return false }
            catch { return error is CancellationError }
        }
        check(await cancelled.value, "cancelled task exits")
        check(calls == 0, "cancelled task has no HTTP request")
        print("Jev: \(checks) checks passed")
    }
}
