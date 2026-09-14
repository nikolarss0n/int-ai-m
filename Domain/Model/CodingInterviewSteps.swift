import Foundation

struct CodingInterviewStep: Equatable {
    var number: Int
    var fileName: String
    var why: String
    var language: String
    var code: String
}

func isImplementationCodingRequest(_ text: String) -> Bool {
    let normalized = text.lowercased()
        .replacingOccurrences(of: "’", with: "'")
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

    if normalized.contains("what is") || normalized.contains("what's") {
        return false
    }

    let explicit = [
        "write a fastapi", "fastapi service", "implement a fastapi",
        "build a fastapi", "create a fastapi", "code a fastapi",
        "write an endpoint", "implement an endpoint", "add an endpoint",
        "write a service", "implement a service", "build a service",
        "live coding", "code up"
    ]
    if explicit.contains(where: { normalized.contains($0) }) {
        return true
    }

    let verbs = ["write", "implement", "create", "build", "scaffold", "code"]
    let nouns = ["service", "endpoint", "fastapi", "handler", "route", "crud", "rest api"]
    let hasVerb = verbs.contains { normalized.contains($0) }
    let hasNoun = nouns.contains { normalized.contains($0) }
    return hasVerb && hasNoun
}

func codingInterviewStepsPrompt(language: String, task: String) -> String {
    """
    You are a live coding interview copilot. The candidate must type this while speaking.

    TASK:
    \(task)

    OUTPUT FORMAT — follow exactly:

    STEP 1 — file: relative/path.ext
    Why: one short line of what this chunk does.
    ```\(language)
    code to type now
    ```

    STEP 2 — file: relative/path.ext
    Why: one short line.
    ```\(language)
    next chunk (may be the SAME file)
    ```

    RULES:
    - Split into 2-5 steps the candidate can type in order.
    - Prefer small chunks even in the same file (imports, app setup, one route, a test).
    - Each Why is one sentence, under 80 characters.
    - No preamble before STEP 1. No recap after the last step.
    - Real runnable code. No TODO / pass placeholders unless the task is tiny.

    SIMPLEST CODE ONLY:
    - The easiest thing a mid-level engineer would type in 2 minutes. Boring on purpose.
    - One file when that is enough (usually main.py). Extra files only if they asked.
    - No classes unless required. No ABC/Protocol, DI containers, factories, middleware stacks, auth, Docker, or CI.
    - FastAPI: `FastAPI()`, a Pydantic model if there is a body, one route, `return` a dict. Skip Depends, routers, lifespan, background tasks, Redis, and vector DBs unless the task names them.
    - Python literals: True, False, None — never JSON true/false/null.
    - Prefer stdlib + FastAPI/Pydantic. No LangChain/LangGraph wrappers for a basic endpoint.
    - Short names. No type gymnastics. No comments except `#` when a line is not obvious.
    - Algorithm tasks: the obvious loop or dict. No clever one-liners.
    """
}

func formatCodingInterviewSteps(_ steps: [CodingInterviewStep]) -> String {
    steps.map { step in
        """
        STEP \(step.number) — file: \(step.fileName)
        Why: \(step.why)
        ```\(step.language)
        \(step.code)
        ```
        """
    }.joined(separator: "\n\n")
}

/// Tokens that mean the snippet is too heavy for a live typed interview answer.
func codingStepsSimplicityViolations(_ steps: [CodingInterviewStep]) -> [String] {
    let blob = steps
        .map { "\($0.fileName) \($0.why) \($0.code)" }
        .joined(separator: "\n")
        .lowercased()
    let forbidden = [
        "depends",
        "apirouter",
        "langchain",
        "langgraph",
        "docker",
        "dockerfile"
    ]
    return forbidden.filter { token in
        let pattern = "(^|[^a-z0-9])\(NSRegularExpression.escapedPattern(for: token))($|[^a-z0-9])"
        return blob.range(of: pattern, options: .regularExpression) != nil
    }
}

func parseCodingInterviewSteps(_ markdown: String) -> [CodingInterviewStep] {
    let pattern = #"STEP\s+(\d+)\s*[—\-]\s*file:\s*(\S+)\s*\nWhy:\s*(.+)\n```(\w+)?\n([\s\S]*?)```"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let ns = markdown as NSString
    let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: ns.length))
    return matches.compactMap { match in
        guard match.numberOfRanges >= 6 else { return nil }
        let number = Int(ns.substring(with: match.range(at: 1))) ?? 0
        let fileName = ns.substring(with: match.range(at: 2))
        let why = ns.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
        let languageRange = match.range(at: 4)
        let language = languageRange.location != NSNotFound ? ns.substring(with: languageRange) : "text"
        let code = ns.substring(with: match.range(at: 5)).trimmingCharacters(in: .whitespacesAndNewlines)
        return CodingInterviewStep(number: number, fileName: fileName, why: why, language: language, code: code)
    }
}
