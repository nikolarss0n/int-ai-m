import Foundation

struct CodingInterviewStep: Equatable {
    var number: Int
    var fileName: String
    var why: String
    var language: String
    var code: String
}

// MARK: - Detecting "write this code"

/// True when the interviewer asks the candidate to write code ("write a function that reverses a
/// string", "implement an LRU cache", "let's do some live coding"). Conceptual questions such as
/// "what is FastAPI?" and candidate narration such as "I wrote a service" are not requests.
func isImplementationCodingRequest(_ text: String) -> Bool {
    CodingRequestDetector.isTaskRequest(text)
}

enum CodingRequestDetector {
    static func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let verbs = "write|implement|code|create|build|develop|scaffold|solve|complete"

    private static let objects = "function|method|class|program|script|algorithm|endpoint|api|service|route|handler|query|regex|regular expression|loop|snippet|solution|code|unit tests?|test cases?|tests? for|module|component|hook|decorator|generator|parser|calculator|validator|cache|stack|queue|linked list|tree|trie|graph|heap|matrix|iterator|crud|fastapi|rest api|problem|exercise|challenge|task|binary search|search|sort|merge sort|quick sort|fibonacci|factorial|fizz ?buzz|palindrome|anagram|two sum|hash ?map|hash table|counter|scraper|crawler|app|application|pipeline|classifier|chatbot|agent|retriever|rate limiter|limiter|logger|context manager|state machine"

    /// A coding verb followed, within a few words, by something that can be written.
    private static let verbObject = try! NSRegularExpression(
        pattern: #"\b("# + verbs + #")\s+(me\s+|us\s+)?((a|an|the|some|this|that|your own|one|another)\s+)?([\w'/]+\s+){0,3}?("# + objects + #")\b"#
    )

    private static let requestFrame = try! NSRegularExpression(
        pattern: #"\b(can|could|would|will)\s+you\s+(please\s+|just\s+|now\s+|also\s+)?("# + verbs + #")\b|\bplease\s+("# + verbs + #")\b|\b(let's|lets|let us)\s+("# + verbs + #")\b|\bi\s+(want|need|would like|'d like|d like)\s+you\s+to\s+("# + verbs + #")\b|\byou\s+(need|have|should|must|are going|'re going)\s+to\s+("# + verbs + #")\b|\b(you|just)\s+(wanna|want to|gonna|going to)\s+("# + verbs + #")\b|\byou('re| are)\s+(going to|gonna)\s+("# + verbs + #")\b|^(so\s+|okay\s+|now\s+)*(wanna|want to|gonna)\s+("# + verbs + #")\b|\byour task\b|\bgo ahead and\s+("# + verbs + #")\b"#
    )

    /// "How would you implement ..." asks how, not for code, even though "would you implement" also
    /// appears in polite requests. Question words are cut out before the request frame is tested.
    private static let questionWordBeforeModal = try! NSRegularExpression(
        pattern: #"\b(how|what|why|when|where|which)\s+(can|could|would|will|do|does|did|should)\s+you\b"#
    )

    private static let leadingFiller = try! NSRegularExpression(
        pattern: #"^(okay|ok|so|now|alright|all right|right|well|then|and|great|perfect|cool|good|nice|next)\b[,.]?\s*"#
    )

    private static let imperativeStart = try! NSRegularExpression(pattern: #"^("# + verbs + #")\b"#)

    private static let firstPersonStart = try! NSRegularExpression(pattern: #"^(i|we|my|our)\s"#)

    private static let pastNarration = try! NSRegularExpression(
        pattern: #"\b(i|we)\s+(have\s+|had\s+|just\s+|also\s+|usually\s+|always\s+|often\s+|recently\s+|really\s+)?(wrote|written|implemented|built|created|developed|coded|did|used|worked)\b"#
    )

    private static let conceptualFrame = try! NSRegularExpression(
        pattern: #"\b(what is|what's|what are|what does|how does|how do|why|difference between|explain|describe|tell me about|walk me through)\b"#
    )

    /// Phrases that ask for code by themselves. The task itself is usually on the screen, so these are
    /// "deictic" requests (see `isDeicticRequest`) unless the sentence adds detail.
    private static let alwaysCodingPhrases = [
        "write some code", "write the code", "write this code", "write that code",
        "show me the code", "type it out"
    ]

    /// Object phrases that mean a coding task unless the sentence is conceptual.
    private static let objectPhrases = [
        "write a fastapi", "fastapi service", "implement a fastapi", "build a fastapi", "create a fastapi",
        "code a fastapi", "write an endpoint", "implement an endpoint", "add an endpoint",
        "write a service", "implement a service", "build a service"
    ]

    private static func matches(_ regex: NSRegularExpression, in text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func strippingLeadingFillers(_ text: String) -> String {
        var current = text
        while matches(leadingFiller, in: current) {
            let range = NSRange(current.startIndex..., in: current)
            let next = leadingFiller.stringByReplacingMatches(in: current, range: range, withTemplate: "")
            if next == current { break }
            current = next
        }
        return current
    }

    static func isTaskRequest(_ text: String) -> Bool {
        let normalized = normalized(text)
        guard !normalized.isEmpty else { return false }

        // "Write a function ..." is a request; "how would you write a function" is a cue-card question.
        let hasVerbObject = matches(verbObject, in: normalized)
        let withoutQuestionModals = questionWordBeforeModal.stringByReplacingMatches(
            in: normalized, range: NSRange(normalized.startIndex..., in: normalized), withTemplate: " "
        )
        if hasVerbObject,
           matches(requestFrame, in: withoutQuestionModals) || matches(imperativeStart, in: strippingLeadingFillers(normalized)) {
            return true
        }

        if matches(firstPersonStart, in: normalized) || matches(pastNarration, in: normalized)
            || matches(conceptualFrame, in: normalized) { return false }
        if alwaysCodingPhrases.contains(where: { normalized.contains($0) }) { return true }
        return objectPhrases.contains { normalized.contains($0) }
    }

    private static let genericObjects: Set<String> = ["code", "solution", "problem", "exercise", "challenge", "task"]

    /// "Write this code" / "solve this problem": the task is on the interviewer's screen, not in
    /// their words. There is nothing to generate from, so the candidate is pointed at the
    /// screenshot shortcut instead of the model inventing a task.
    static func isDeicticRequest(_ text: String) -> Bool {
        let normalized = normalized(text)
        guard isTaskRequest(text), !matches(detailCues, in: normalized) else { return false }
        let ns = normalized as NSString
        for match in verbObject.matches(in: normalized, range: NSRange(location: 0, length: ns.length)) {
            let object = ns.substring(with: match.range(at: match.numberOfRanges - 1))
            if !genericObjects.contains(object) { return false }
        }
        return true
    }

    // MARK: Follow-ups while code is on screen

    /// What an interviewer asks for once code is already on the panel.
    enum FollowUp: Equatable {
        /// Change the code that is there: another language, an improvement, another way, a constraint.
        case change
        /// A fresh example of a technique ("show me sliding window"). It replaces the panel.
        case example
    }

    private static let languages = #"python|javascript|typescript|java|kotlin|golang|rust|swift|c\+\+|c#|csharp|cpp|ruby|php|scala|sql|bash|node(?:\.?js)?|js|ts"#

    /// "in TypeScript", "to Java", "using Rust" - never "for" ("we use TypeScript for the frontend").
    private static let languageReference = try! NSRegularExpression(
        pattern: #"\b(?:in|into|to|with|using)\s+(?:the\s+)?(?:"# + languages + #")(?![\w+#])|\bin\s+go\s*[?.!]*$"#
    )

    /// A bare language answer to "what language?" or a rewrite request: "In TypeScript, please".
    private static let languageOnly = try! NSRegularExpression(
        pattern: #"^(?:(?:and|now|okay|ok|so)\s+)*(?:in\s+|with\s+|using\s+)?(?:"# + languages + #")(?:\s+(?:please|now|too|instead|as well))*[?.!]*$"#
    )

    /// Verbs that ask for code to be produced or changed. Deliberately narrow: "do you have experience
    /// with TypeScript" must not read as a rewrite request.
    private static let rewriteVerbs = try! NSRegularExpression(
        pattern: #"\b(?:write|rewrite|convert|translate|port|switch|redo|implement|code|show|give|make|try)\b|\b(?:can|could|would|will)\s+you\s+(?:please\s+)?(?:do|use|see)\b|\bhow\s+(?:would|does|will)\s+(?:it|this|that)\s+look\b|\b(?:need|want|prefer)\s+(?:it|this)\b"#
    )

    private static let referent = try! NSRegularExpression(
        pattern: #"\b(?:it|this|that|these|the\s+(?:function|code|solution|loop|method|class|implementation|program|script)|your\s+(?:code|solution|function|approach|implementation))\b"#
    )

    private static let improveVerbs = try! NSRegularExpression(
        pattern: #"\b(?:improve|optimi[sz]e|refactor|simplify|shorten|clean(?:\s+it)?\s+up|tidy|speed\s+(?:it\s+)?up)\b"#
    )

    private static let makeBetter = try! NSRegularExpression(
        pattern: #"\bmake\s+(?:it|this|that|the\s+\w+)\s+(?:a\s+bit\s+|a\s+little\s+|much\s+)?(?:faster|quicker|shorter|cleaner|simpler|better|smaller|more\s+\w+|less\s+\w+|recursive|iterative|in.?place|async|generic|thread.?safe|readable|efficient)\b"#
    )

    private static let addOrHandle = try! NSRegularExpression(
        pattern: #"\badd\s+(?:some\s+|a\s+|an\s+)?(?:error\s+handling|type\s+hints?|types?|tests?|unit\s+tests?|comments?|docstrings?|logging|validation|input\s+validation|main)\b|\bhandle\s+(?:the\s+)?(?:edge\s+cases?|empty|none|null|nil|errors?|exceptions?|unicode|invalid|negative|large|big|special)\b|\b(?:write|create|generate)\s+(?:a\s+|some\s+)?(?:unit\s+)?tests?\b"#
    )

    private static let alternatives = try! NSRegularExpression(
        pattern: #"\b(?:another|different|alternative|other|better|easier|simpler|shorter|cleaner|faster|quicker|nicer|smarter|more\s+(?:pythonic|idiomatic|efficient|readable|concise))\s+(?:way|approach|solution|method|implementation|version|technique|algorithm|option)\b|\bdifferently\b|\bwithout\s+(?:using\s+)?\w+"#
    )

    private static let constraints = try! NSRegularExpression(
        pattern: #"\b(?:use|using|try|with)\s+(?:a\s+|an\s+|the\s+)?(?:for\s+loop|while\s+loop|loop|recursion|recursive|stack|queue|two\s+pointers?|sliding\s+window|dict(?:ionary)?|hash\s?map|set|generator|regex|list\s+comprehension|built.?in|itertools|collections|numpy|pandas)\b"#
    )

    private static let constraintCue = try! NSRegularExpression(
        pattern: #"\b(?:can|could|would|will)\s+you\b|\bhow\s+about\b|\bwhat\s+about\b|\btry\b|\blet's\b|\bnow\b|\binstead\b|^use\b"#
    )

    private static let techniques = #"sliding\s+window|two\s+pointers?|binary\s+search|recursion|memoi[sz]ation|dynamic\s+programming|backtracking|greedy|divide\s+and\s+conquer|bfs|dfs|breadth.?first|depth.?first|union.?find|trie|prefix\s+sum|kadane|bit\s+manipulation|monotonic\s+stack"#

    private static let techniqueExample = try! NSRegularExpression(
        pattern: #"\b(?:show|demonstrate|give|write|code|implement)\b[^.?!]{0,40}\b(?:"# + techniques + #")\b|\bhow\s+(?:(?:do|would|can|could|might)\s+)?(?:you|we|i|one)\s+(?:use|apply|implement|code|write|do)\b[^.?!]{0,30}\b(?:"# + techniques + #")\b|\b(?:"# + techniques + #")\s+(?:example|code|implementation|snippet|demo)\b|\bexamples?\s+of\s+(?:a\s+|an\s+|the\s+)?(?:"# + techniques + #")\b"#
    )

    /// "How about using recursion?" and "what about a loop?" are suggestions, not questions about the code.
    private static let questionStart = try! NSRegularExpression(pattern: #"^(?:what|why|how|when|where|which|who)\b(?!\s+about\b)"#)
    private static let strictExplain = try! NSRegularExpression(
        pattern: #"\b(?:explain|describe|tell me about|walk me through|difference between|why)\b"#
    )
    private static let definitionFrame = try! NSRegularExpression(pattern: #"\b(?:what is|what's|what are|what does)\b"#)
    private static let hypotheticalLook = try! NSRegularExpression(pattern: #"^how\s+(?:would|does|will)\s+(?:it|this|that)\s+look"#)
    private static let politeRequest = try! NSRegularExpression(pattern: #"\b(?:can|could|would|will)\s+you\b|\bplease\b|\blet's\b"#)
    private static let improveAtStart = try! NSRegularExpression(
        pattern: #"^(?:improve|optimi[sz]e|refactor|simplify|shorten|clean|tidy|speed)\b"#
    )

    /// Classifies an interviewer remark made while code is on screen, or nil when it is an ordinary
    /// question (which the answer card handles, with the code as context).
    static func followUp(_ text: String) -> FollowUp? {
        let normalized = normalized(text)
        let wordCount = normalized.split(separator: " ").count
        guard (2...24).contains(wordCount) else { return nil }
        guard !matches(firstPersonStart, in: normalized), !matches(pastNarration, in: normalized),
              !ConversationUnderstanding.looksLikeCandidateNarrative(normalized),
              !matches(strictExplain, in: normalized) else { return nil }
        let asksForAlternative = matches(alternatives, in: normalized)
        if matches(definitionFrame, in: normalized), !asksForAlternative { return nil }

        // A technique demo may be phrased as a how-question ("how do you use two pointers").
        if matches(techniqueExample, in: normalized) { return .example }

        let asksHow = matches(questionStart, in: normalized)
        if matches(languageOnly, in: normalized) { return .change }
        if matches(languageReference, in: normalized), matches(rewriteVerbs, in: normalized),
           !asksHow || matches(hypotheticalLook, in: normalized) {
            return .change
        }
        if asksForAlternative { return .change }
        guard !asksHow else { return nil }

        // "How would you improve the database?" asks for an opinion; "improve it" asks for code.
        let startsWithImproveVerb = matches(improveAtStart, in: strippingLeadingFillers(normalized))
        if matches(improveVerbs, in: normalized),
           matches(referent, in: normalized) || startsWithImproveVerb || matches(politeRequest, in: normalized) {
            return .change
        }
        if matches(makeBetter, in: normalized) || matches(addOrHandle, in: normalized) { return .change }
        if matches(constraints, in: normalized), matches(constraintCue, in: normalized) { return .change }
        return nil
    }

    // MARK: A code example of something already said

    /// "Show me an example in code", "can you show that in code?", "give me a code snippet": the
    /// interviewer wants code for a concept, not an explanation of it.
    private static let codeExample = try! NSRegularExpression(
        pattern: #"\b(?:show|give|write|share|demonstrate|sketch|put)\b[^.?!]{0,40}(?:\b(?:in|as|with)\s+(?:some\s+|a\s+little\s+|a\s+bit\s+of\s+|actual\s+|real\s+)?code\b|\bcode\s+(?:examples?|snippets?|samples?)\b|\bexamples?\s+(?:in|of)\s+code\b)"#
    )

    /// Words that say how to show something, not what to show.
    private static let exampleFrameWords: Set<String> = [
        "okay", "ok", "so", "now", "alright", "right", "well", "then", "and", "also", "maybe", "yeah", "great", "good",
        "can", "could", "would", "will", "you", "please", "just", "me", "us", "quickly", "quick", "briefly",
        "show", "give", "write", "share", "demonstrate", "sketch", "put", "an", "a", "the", "some", "any", "one",
        "this", "that", "it", "these", "those", "how", "what", "works", "work", "looks", "look", "like",
        "example", "examples", "in", "as", "with", "of", "for", "to", "code", "snippet", "snippets", "sample", "samples",
        "little", "bit", "actual", "real", "simple", "small", "short", "kind", "sort"
    ]

    static func asksForCodeExample(_ text: String) -> Bool {
        let normalized = normalized(text)
        guard !normalized.isEmpty, !matches(firstPersonStart, in: normalized), !matches(pastNarration, in: normalized) else { return false }
        return matches(codeExample, in: normalized)
    }

    /// "Can you show me that in code?" names nothing: its subject is the question before it.
    /// "Cache, can you show me an example in code?" names its own.
    static func codeExampleNamesItsSubject(_ text: String) -> Bool {
        let words = normalized(text).split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map(String.init)
        return words.contains { !exampleFrameWords.contains($0) }
    }

    // MARK: Coding session

    private static let sessionCues = try! NSRegularExpression(
        pattern: #"\bnew (python |java |javascript |typescript |go |kotlin |swift )?(file|notebook|project)\b|\bopen (up )?(your|an|a|the) (editor|ide|terminal|notebook|repl|vs ?code|pycharm|intellij)\b|\bshare (your|the) screen\b|\bscreen shar(e|ing)\b|\bstart coding\b|\blet's code\b|\bpair program|\bcode together\b|\bpractical (task|exercise)\b|\blive coding\b|\bsome coding\b|\bcoding (exercise|challenge|task|problem|question|round|test|part|session)\b"#
    )

    private static let detailCues = try! NSRegularExpression(
        pattern: #"\b(input|output|return|returns|returning|parameter|parameters|param|argument|arguments|string|strings|list|lists|array|arrays|number|numbers|integer|integers|float|dictionary|dict|tuple|character|characters|char|chars|print|reverse|reversed|sort|sorted|count|sum|filter|unique|duplicate|duplicates|empty|edge case|edge cases|recursive|recursion|iterative|complexity|without|instead|given|takes|gets|accepts|receives|should|must|text|word|words|palindrome)\b"#
    )

    /// Words that start or continue a coding exercise without yet naming the task.
    static func startsCodingSession(_ text: String) -> Bool {
        let normalized = normalized(text)
        guard !matches(pastNarration, in: normalized) else { return false }
        return matches(sessionCues, in: normalized)
    }

    /// A fragment that adds detail to a task already being spoken ("like text, return string").
    static func looksLikeTaskDetail(_ text: String) -> Bool {
        let normalized = normalized(text)
        // Real fragments are short. A long run of speech is conversation, not a clarification.
        let wordCount = normalized.split(separator: " ").count
        guard (3...16).contains(wordCount), !normalized.contains("?") else { return false }
        guard !matches(firstPersonStart, in: normalized),
              !ConversationUnderstanding.hasInterviewerFrame(normalized),
              !ConversationUnderstanding.looksLikeCandidateNarrative(normalized) else { return false }
        return matches(detailCues, in: normalized)
    }
}

/// What the interviewer has said about the current coding exercise. Speech arrives in fragments
/// ("write a function that gets a string and ... returns it reversed"), so the task is accumulated
/// across turns instead of being judged one utterance at a time.
struct CodingSessionState: Equatable {
    /// Interviews talk about the code for a while before the next change; ten minutes of quiet ends the exercise.
    static let freshnessWindow: TimeInterval = 600
    static let maxTaskCharacters = 900

    private(set) var armedAt: Date?
    private(set) var updatedAt: Date?
    private(set) var task = ""
    private(set) var cardTurnID: UUID?
    /// The STEP blocks currently on the code panel. Follow-ups change this code instead of starting over.
    private(set) var currentCode = ""

    func isFresh(at now: Date) -> Bool {
        guard let last = [armedAt, updatedAt].compactMap({ $0 }).max() else { return false }
        return now.timeIntervalSince(last) <= Self.freshnessWindow
    }

    mutating func arm(at now: Date) {
        armedAt = now
    }

    mutating func begin(task: String, cardTurnID: UUID, at now: Date) {
        self.task = Self.capped(task)
        self.cardTurnID = cardTurnID
        updatedAt = now
    }

    mutating func refine(task: String, at now: Date) {
        self.task = Self.capped(task)
        updatedAt = now
    }

    /// A spoken change to the code on screen ("write it in TypeScript") opens its own card.
    mutating func applyChange(_ instruction: String, cardTurnID: UUID, at now: Date) {
        task = Self.capped(task + " Then: " + instruction)
        self.cardTurnID = cardTurnID
        updatedAt = now
    }

    mutating func store(code: String) {
        currentCode = code
    }

    /// Keeps the exercise fresh without touching its task, for a retry of the request that built it.
    mutating func touch(at now: Date) {
        updatedAt = now
    }

    mutating func clear() {
        self = CodingSessionState()
    }

    /// Keeps the most recent words when the spoken task grows past the cap.
    private static func capped(_ task: String) -> String {
        let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxTaskCharacters else { return trimmed }
        return String(trimmed.suffix(maxTaskCharacters))
    }
}

/// What the code panel needs to know when code starts streaming in.
struct CodingTaskInfo: Equatable {
    /// The answer card this code belongs to. The panel keeps one version of the code per card.
    let turnID: UUID
    /// What was asked, shown under the panel title ("Okay, now can you write it in TypeScript?").
    let request: String
    /// A dictated detail that updates the version in place instead of adding one.
    let isRefinement: Bool
    /// Spoken exercises can be changed from the panel; a screenshot analysis cannot.
    let allowsChanges: Bool
}

enum CodingTaskOutcome: Equatable {
    case complete
    /// The code stopped early: a dropped connection or the length limit. The panel offers a retry.
    case incomplete(String)
}

/// One-click changes on the code panel. Each is worded like the request an interviewer would speak,
/// so a click and a spoken request take the same path.
enum CodeQuickAction: CaseIterable, Equatable {
    case anotherWay, optimize, addTests, otherLanguage

    /// The language a click on "Use <language>" switches to, given the language of the code on screen.
    static func otherLanguage(than current: String?) -> String {
        switch current {
        case "Python": return "TypeScript"
        case "TypeScript": return "Python"
        case "JavaScript": return "TypeScript"
        case "Java": return "Python"
        case "Kotlin": return "Java"
        case "C#": return "Java"
        default: return current == nil ? "TypeScript" : "Python"
        }
    }

    func title(currentLanguage: String?) -> String {
        switch self {
        case .anotherWay: return "Try another way"
        case .optimize: return "Optimize"
        case .addTests: return "Add tests"
        case .otherLanguage: return "Use \(Self.otherLanguage(than: currentLanguage))"
        }
    }

    func instruction(currentLanguage: String?) -> String {
        switch self {
        case .anotherWay: return "Show me another way to do it"
        case .optimize: return "Optimize it"
        case .addTests: return "Add tests for it"
        case .otherLanguage: return "Write it in \(Self.otherLanguage(than: currentLanguage))"
        }
    }
}

enum CodingTurnDecision: Equatable {
    /// A coding exercise is starting ("let's start a new Python file") but no task is stated yet.
    case armSession
    /// "Write this code": the task is on the screen, not in the words. No model call.
    case needsScreenContext
    /// A fresh task. The text is what the interviewer just said.
    case newTask(String)
    /// More detail for the task in progress. The text is the whole accumulated task.
    case refineTask(String)
    /// A change to the code already on the panel. The text is what the interviewer just said.
    case changeCode(String)
}

/// `previousQuestion` is the interviewer's last question before this one: "show me that in code" is
/// about it, so it becomes the task.
func codingTurnDecision(text: String, session: CodingSessionState, now: Date, previousQuestion: String? = nil) -> CodingTurnDecision? {
    let hasCodeOnScreen = session.isFresh(at: now) && !session.currentCode.isEmpty
    // "Write tests for it" and "write it in TypeScript" change the code that is there; they do not start a task.
    if hasCodeOnScreen, CodingRequestDetector.followUp(text) == .change { return .changeCode(text) }
    if isImplementationCodingRequest(text) {
        return CodingRequestDetector.isDeicticRequest(text) ? .needsScreenContext : .newTask(text)
    }
    if CodingRequestDetector.asksForCodeExample(text) {
        let subject = previousQuestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !CodingRequestDetector.codeExampleNamesItsSubject(text), !subject.isEmpty else { return .newTask(text) }
        return .newTask("\(subject) \(text)")
    }
    if CodingRequestDetector.startsCodingSession(text) { return .armSession }
    guard session.isFresh(at: now) else { return nil }
    if CodingRequestDetector.followUp(text) == .example { return .newTask(text) }
    guard CodingRequestDetector.looksLikeTaskDetail(text) else { return nil }
    guard !session.task.isEmpty else { return .newTask(text) }
    return .refineTask(session.task + " " + text)
}

// MARK: - Prompt

/// `spoken` is for a task taken from live speech: it is noisy and fragmentary, and the reply opens
/// with a few lines the candidate can say aloud before typing. Screenshot analysis keeps the
/// original prompt (`spoken == false`).
///
/// `currentCode` is the STEP blocks already on the panel. With a `changeRequest` the model must apply
/// that request to the code instead of starting over ("write it in TypeScript", "another way").
/// Without one, the code is a draft written from an earlier, shorter version of the dictated task.
func codingInterviewStepsPrompt(
    language: String,
    task: String,
    spoken: Bool = false,
    currentCode: String? = nil,
    changeRequest: String? = nil
) -> String {
    let code = currentCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let request = changeRequest?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let isChange = spoken && !code.isEmpty && !request.isEmpty

    let taskBlock: String
    if isChange {
        taskBlock = """
        ORIGINAL TASK:
        \(task)

        CURRENT CODE (already on the candidate's screen):
        \(code)

        CHANGE REQUEST (raw speech-to-text of what the interviewer just said):
        \(request)
        """
    } else if spoken && !code.isEmpty {
        taskBlock = """
        TASK:
        \(task)

        CURRENT CODE (written from an earlier, shorter version of the task; update it to fit the full TASK):
        \(code)
        """
    } else {
        taskBlock = """
        TASK:
        \(task)
        """
    }

    let speechNote: String
    if isChange {
        speechNote = """

        Apply the CHANGE REQUEST to the CURRENT CODE and output the FULL updated solution in the format below, replacing the current code. Keep what still fits and change only what the request needs. Keep the current language unless the request asks for another one; when it does, rewrite everything in that language and tag every code fence with it. If it asks for another way, use a genuinely different approach, not a cosmetic rewrite. If it asks to improve or optimize, make a real improvement and say what changed in SAY. The request is speech-to-text and may be garbled or partial: infer what the interviewer most likely wants. The simplicity rules below still apply unless the request says otherwise.

        """
    } else if spoken {
        speechNote = """

        The TASK is raw speech-to-text from a live interview. It may be fragmented, may include the candidate's own words, and may mishear terms ("PYTOM" is Python). Infer the single most likely coding task. When details conflict, trust the latest. If the task is still underspecified, take the simplest reasonable reading and say the assumption in SAY. Use \(language) unless the task names another language, and tag the code fences with the language actually used.

        """
    } else {
        speechNote = ""
    }

    let sayLine = isChange
        ? "- 2-3 short lines the candidate says out loud before typing: what changes and why, and the new time and space complexity if it changed."
        : "- 2-3 short lines the candidate says out loud before typing: restate the task, name one assumption, give time and space complexity."
    let sayBlock = spoken ? """
    SAY:
    \(sayLine)


    """ : ""
    let stepRule = spoken
        ? "Split into 1-5 steps the candidate can type in order. Use ONE step when the whole solution is under about 15 lines."
        : "Split into 2-5 steps the candidate can type in order."
    let preambleRule = spoken
        ? "- No preamble before SAY. No recap after the last step. SAY lines start with \"- \" and stay under 90 characters."
        : "- No preamble before STEP 1. No recap after the last step."

    return """
    You are a live coding interview copilot. The candidate must type this while speaking.

    \(taskBlock)
    \(speechNote)
    OUTPUT FORMAT — follow exactly:

    \(sayBlock)STEP 1 — file: relative/path.ext
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
    - \(stepRule)
    - Prefer small chunks even in the same file (imports, app setup, one route, a test).
    - Each Why is one sentence, under 80 characters.
    \(preambleRule)
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

// MARK: - Reading the reply

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

/// Drops blank lines around a code block. The first line keeps its indentation: a chunk that continues
/// a class or function body starts indented, and pasting it flush left would break the file.
func trimmedCodeBlock(_ code: String) -> String {
    var lines = code.components(separatedBy: "\n")
    while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeFirst() }
    while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeLast() }
    return lines.joined(separator: "\n")
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
        let code = trimmedCodeBlock(ns.substring(with: match.range(at: 5)))
        return CodingInterviewStep(number: number, fileName: fileName, why: why, language: language, code: code)
    }
}

/// Steps read from a reply that may still be streaming.
struct CodingStepProgress: Equatable {
    var steps: [CodingInterviewStep]
    /// The last step has no closing fence yet, so its code is still growing.
    var lastStepIsOpen: Bool
}

/// Reads STEP blocks line by line so a half-streamed step shows up as soon as its code starts.
func parseCodingInterviewStepsStreaming(_ markdown: String) -> CodingStepProgress {
    let header = try! NSRegularExpression(pattern: #"^\s*STEP\s+(\d+)\s*[—–:\-]?\s*(?:file:)?\s*(\S+)?"#, options: [.caseInsensitive])
    var steps: [CodingInterviewStep] = []
    var current: CodingInterviewStep?
    var codeLines: [String] = []
    var inFence = false

    func finishCurrent() {
        guard var step = current else { return }
        step.code = trimmedCodeBlock(codeLines.joined(separator: "\n"))
        steps.append(step)
        current = nil
        codeLines = []
    }

    for rawLine in markdown.components(separatedBy: "\n") {
        let line = rawLine.trimmingCharacters(in: .newlines)
        if inFence {
            if line.trimmingCharacters(in: .whitespaces) == "```" {
                inFence = false
            } else {
                codeLines.append(line)
            }
            continue
        }
        let ns = line as NSString
        if let match = header.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) {
            finishCurrent()
            let number = Int(ns.substring(with: match.range(at: 1))) ?? steps.count + 1
            let fileRange = match.range(at: 2)
            let fileName = fileRange.location != NSNotFound ? ns.substring(with: fileRange) : "main"
            current = CodingInterviewStep(number: number, fileName: fileName, why: "", language: "text", code: "")
            continue
        }
        guard current != nil else { continue }
        if line.hasPrefix("```") {
            inFence = true
            let language = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
            if !language.isEmpty { current?.language = language }
            continue
        }
        if line.lowercased().hasPrefix("why:") {
            current?.why = line.dropFirst(4).trimmingCharacters(in: .whitespaces)
        }
    }
    let lastStepIsOpen = inFence || (current != nil && codeLines.isEmpty && current?.code.isEmpty == true)
    finishCurrent()
    return CodingStepProgress(steps: steps, lastStepIsOpen: lastStepIsOpen)
}

/// Display name for a code fence tag ("ts" becomes "TypeScript"), or nil when the tag is unknown.
func codingLanguageDisplayName(forFence fence: String) -> String? {
    switch fence.lowercased() {
    case "python", "py": return "Python"
    case "typescript", "ts", "tsx": return "TypeScript"
    case "javascript", "js", "jsx", "node", "nodejs": return "JavaScript"
    case "java": return "Java"
    case "kotlin", "kt": return "Kotlin"
    case "go", "golang": return "Go"
    case "rust", "rs": return "Rust"
    case "swift": return "Swift"
    case "csharp", "cs", "c#": return "C#"
    case "cpp", "c++": return "C++"
    case "c": return "C"
    case "ruby", "rb": return "Ruby"
    case "php": return "PHP"
    case "scala": return "Scala"
    case "sql": return "SQL"
    case "bash", "sh", "shell", "zsh": return "Shell"
    default: return nil
    }
}

struct CodingResponse: Equatable {
    /// The talking points the candidate says before typing.
    var sayBullets: [String]
    /// Everything from the first STEP onward.
    var stepsMarkdown: String
}

/// Splits a spoken-task reply into the SAY lines (shown on the answer card) and the STEP blocks
/// (shown in the code panel).
func splitCodingResponse(_ text: String) -> CodingResponse {
    let firstStep = text.range(of: #"(?m)^[ \t]*STEP\s+\d+"#, options: [.regularExpression, .caseInsensitive])
    let sayText = firstStep.map { String(text[..<$0.lowerBound]) } ?? text
    let steps = firstStep.map { String(text[$0.lowerBound...]) } ?? ""

    let bullets: [String] = sayText.components(separatedBy: "\n").compactMap { rawLine in
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        for marker in ["- ", "* ", "• "] where line.hasPrefix(marker) {
            let bullet = String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
            return bullet.isEmpty ? nil : bullet
        }
        return nil
    }
    return CodingResponse(sayBullets: bullets, stepsMarkdown: steps)
}

/// The first thing to say from an answer, for the one line above the code.
func firstTalkingPoint(_ answer: String) -> String? {
    for rawLine in answer.components(separatedBy: "\n") {
        var line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("- ") { line = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        if !line.isEmpty { return line }
    }
    return nil
}

/// The answer card text that goes with the code panel.
func codingCardBullets(for response: CodingResponse, stepCount: Int, isComplete: Bool) -> String {
    var lines = response.sayBullets.map { "- \($0)" }
    // With talking points on the card the open panel speaks for itself; an empty card still points to it.
    guard lines.isEmpty, isComplete, stepCount > 0 else { return lines.joined(separator: "\n") }
    lines.append("- Code is in the code panel (\(stepCount) step\(stepCount == 1 ? "" : "s")).")
    return lines.joined(separator: "\n")
}
