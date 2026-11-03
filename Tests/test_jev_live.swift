import Foundation

/// Explicit opt-in evaluation; never linked into the app or default unit tests.
@main struct JevLiveEvaluation {
    struct Sample {
        let text: String
        let expected: String
        var buffer = ""
        var topic: String? = nil
    }
    static func main() async throws {
        let samples = [
            Sample(text: "What is dependency injection?", expected: "question"),
            Sample(text: "I have experience with hash maps and used them in production", expected: "statement"),
            Sample(text: "What is the", expected: "incomplete"),
            Sample(text: "um", expected: "filler"),
            Sample(text: "А как работи hash map?", expected: "question"),
            Sample(text: "Tell me more", expected: "question", topic: "rag"),
            Sample(text: "Great answer", expected: "statement"),
            Sample(text: "difference between a process and a thread?", expected: "question", buffer: "What is the"),
            Sample(text: "Implement a FastAPI service with a health route", expected: "question"),
            Sample(text: "I usually start with smoke testing before regression", expected: "statement"),
            Sample(text: "Explain the difference between RAG and fine tuning", expected: "question"),
            Sample(text: "So when you ha-", expected: "incomplete")
        ]
        if CommandLine.arguments.contains("--replay-playground") {
            var matched = 0, accepted = 0, fallback = 0, invalid = 0
            var ids = Set<String>()
            for run in 1...5 {
                let data = try Data(contentsOf: URL(fileURLWithPath: ".codex-loop/jev-live/playground-\(run).json"))
                let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                guard let id = root["request_id"] as? String, ids.insert(id).inserted else { fatalError("Repeated request ID") }
                let answers = root["answers"] as! [String: Any]
                for (index, sample) in samples.enumerated() {
                    let raw = answers["case_\(index)"] as! [String: Any]
                    if raw["choice"] as? String == sample.expected { matched += 1 }
                    let envelope = try JSONSerialization.data(withJSONObject: ["model": root["model"]!, "answers": ["intent": raw]])
                    do {
                        let answer = try JevDecisionClient.validatedAnswer(envelope)
                        if JevDecisionClient.acceptedStatus(answer) != nil { accepted += 1 } else { fallback += 1 }
                    } catch { invalid += 1 }
                }
            }
            let summary: [String: Any] = ["decisions": 60, "matched": matched, "accepted": accepted,
                "fallback": fallback, "invalid": invalid, "distinct_requests": ids.count]
            try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
                .write(to: URL(fileURLWithPath: ".codex-loop/jev-live/playground-summary.json"))
            print(summary)
            return
        }
        if CommandLine.arguments.contains("--export-playground") {
            var questions: [String: Any] = [:]
            var labels: [String: String] = [:]
            for (index, sample) in samples.enumerated() {
                let body = try JevDecisionClient.requestBody(transcription: sample.text, buffer: sample.buffer, lastTopic: sample.topic, history: [])
                let request = try JSONSerialization.jsonObject(with: body) as! [String: Any]
                let original = (request["questions"] as! [String: [String: Any]])["intent"]!
                questions["case_\(index)"] = ["type": "choice", "criteria": original["criteria"]!,
                    "instructions": ["rubric": original["instructions"]!, "state": request["state"]!,
                                     "scope": "Evaluate only the state inside this question using the rubric."]]
                labels["case_\(index)"] = sample.expected
            }
            for (name, object) in [("questions", questions), ("labels", labels as [String: Any])] {
                try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
                    .write(to: URL(fileURLWithPath: ".codex-loop/jev-live/\(name).json"))
            }
            return
        }
        guard ProcessInfo.processInfo.environment["IM_RUN_LIVE_CLASSIFICATION"] == "1",
              let client = JevDecisionClient.configured() else {
            print("Live Jev evaluation requires IM_RUN_LIVE_CLASSIFICATION=1, IM_JEV_ENABLED=1 and TYPESAFE_API_KEY.")
            exit(2)
        }
        var results: [[String: Any]] = []
        for run in 1...5 {
            for (index, sample) in samples.enumerated() {
                let start = Date()
                var row: [String: Any] = ["run": run, "case": index, "expected": sample.expected]
                do {
                    let answer = try await client.evaluate(transcription: sample.text, buffer: sample.buffer, lastTopic: sample.topic, history: [])
                    row["choice"] = answer.choice.rawValue
                    row["confidence"] = answer.confidence
                    row["probabilities"] = answer.probabilities
                    row["accepted"] = JevDecisionClient.acceptedStatus(answer)?.rawValue ?? "fallback"
                } catch {
                    row["error"] = "transport_or_validation_failure"
                }
                row["round_trip_ms"] = Int(Date().timeIntervalSince(start) * 1000)
                results.append(row)
                try JSONSerialization.data(withJSONObject: ["model": JevDecisionClient.model, "results": results], options: [.prettyPrinted, .sortedKeys])
                    .write(to: URL(fileURLWithPath: ".codex-loop/jev-live/results.json"), options: .atomic)
            }
        }
        let correct = results.filter { ($0["choice"] as? String) == ($0["expected"] as? String) }.count
        let errors = results.filter { $0["error"] != nil }.count
        print("Jev live: \(correct)/\(results.count) labels matched; \(errors) transport/validation failures. Curated cases, not production accuracy. Results: .codex-loop/jev-live/results.json")
        if errors > 0 { exit(1) }
    }
}
