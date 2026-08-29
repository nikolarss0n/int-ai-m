import Foundation

enum PracticeHelpMark: String, Codable, Equatable {
    case none
    case yellow
}

enum PracticeScoring {
    /// Scored interview answers that explicitly use prepared Help are worth 0.4×.
    /// Active Recall repairs are tracked as assisted learning, not grade penalties.
    static let helpMultiplier = 0.4
}

struct PracticeScoreResult: Equatable {
    let rawScore: Double
    let usedHelp: Bool
    let mark: PracticeHelpMark
    let finalScore: Double
}

func applyHelpPenalty(rawScore: Double, usedHelp: Bool) -> PracticeScoreResult {
    let raw = min(1.0, max(0.0, rawScore))
    if usedHelp {
        return PracticeScoreResult(
            rawScore: raw,
            usedHelp: true,
            mark: .yellow,
            finalScore: raw * PracticeScoring.helpMultiplier
        )
    }
    return PracticeScoreResult(
        rawScore: raw,
        usedHelp: false,
        mark: .none,
        finalScore: raw
    )
}

struct PracticeQuestion: Equatable, Codable {
    let id: String
    let packId: String
    let text: String
    var groupId: String
    var topicId: String
    var topicTitle: String
    var hints: [String]
    var rubric: String
    var answer: String

    init(
        id: String,
        packId: String,
        text: String,
        groupId: String = "",
        topicId: String = "",
        topicTitle: String = "",
        hints: [String] = [],
        rubric: String = "",
        answer: String = ""
    ) {
        self.id = id
        self.packId = packId
        self.text = text
        self.groupId = groupId
        self.topicId = topicId
        self.topicTitle = topicTitle
        self.hints = hints
        self.rubric = rubric
        self.answer = answer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        packId = try container.decode(String.self, forKey: .packId)
        text = try container.decode(String.self, forKey: .text)
        groupId = try container.decodeIfPresent(String.self, forKey: .groupId) ?? ""
        topicId = try container.decodeIfPresent(String.self, forKey: .topicId) ?? ""
        topicTitle = try container.decodeIfPresent(String.self, forKey: .topicTitle) ?? ""
        hints = try container.decodeIfPresent([String].self, forKey: .hints) ?? []
        rubric = try container.decodeIfPresent(String.self, forKey: .rubric) ?? ""
        answer = try container.decodeIfPresent(String.self, forKey: .answer) ?? ""
    }
}

struct PracticeGroup: Equatable, Codable {
    let id: String
    let title: String
}

struct PracticePosition: Equatable, Codable {
    let id: String
    let title: String
    let packId: String
    /// Empty means every group in the pack.
    let groupIds: [String]
}

struct PracticeBankFile: Equatable, Codable {
    let packs: [PracticeTopicPack]
    let positions: [PracticePosition]

    init(packs: [PracticeTopicPack], positions: [PracticePosition] = []) {
        self.packs = packs
        self.positions = positions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packs = try container.decode([PracticeTopicPack].self, forKey: .packs)
        positions = try container.decodeIfPresent([PracticePosition].self, forKey: .positions) ?? []
    }
}

/// Chip labels: interview topics, not study-book chapter names.
func practiceGroupDisplayTitle(id: String, fallback: String = "") -> String {
    switch id {
    case "foundations": return "LLM internals"
    case "classical-ml": return "Tabular ML"
    case "ml-in-production": return "MLOps"
    case "genai-and-llm": return "RAG & agents"
    case "system-design": return "System design"
    case "python-engineering": return "Python"
    case "java-and-jvm": return "Java"
    case "engineering-practice": return "Design patterns"
    case "quant-and-domain": return "Time series"
    case "agentic-sme-s-and-p": return "Agents & security"
    case "interview-prep": return "Whiteboard & DSA"
    case "jr-javascript": return "JavaScript · junior"
    case "mid-javascript": return "JavaScript · mid"
    case "senior-javascript": return "JavaScript · senior"
    case "coding-tasks": return "Coding"
    case "logical-tasks": return "Logic puzzles"
    default: return fallback.isEmpty ? id : fallback
    }
}

func practiceBankGroups(from bank: PracticeBankFile) -> [PracticeGroup] {
    var groups: [PracticeGroup] = []
    var seen = Set<String>()
    for pack in bank.packs {
        let packGroups = pack.groups.isEmpty ? [PracticeGroup(id: pack.id, title: pack.title)] : pack.groups
        for group in packGroups where seen.insert(group.id).inserted {
            groups.append(PracticeGroup(
                id: group.id,
                title: practiceGroupDisplayTitle(id: group.id, fallback: group.title)
            ))
        }
    }
    return groups
}

struct PracticeTopicPack: Equatable, Codable {
    let id: String
    let title: String
    let blurb: String
    var groups: [PracticeGroup]
    let questions: [PracticeQuestion]

    static let all: [PracticeTopicPack] = [aws, models, angular]

    static let aws = PracticeTopicPack(
        id: "aws",
        title: "AWS",
        blurb: "IAM, networking, storage, and compute trade-offs",
        groups: [PracticeGroup(id: "aws", title: "AWS")],
        questions: [
            PracticeQuestion(id: "aws-iam", packId: "aws", text: "What is the difference between an IAM user and an IAM role?"),
            PracticeQuestion(id: "aws-s3", packId: "aws", text: "When would you choose S3 Intelligent-Tiering over S3 Standard?"),
            PracticeQuestion(id: "aws-sqs-sns", packId: "aws", text: "How does SQS differ from SNS, and when would you use both?"),
            PracticeQuestion(id: "aws-vpc", packId: "aws", text: "How does VPC peering differ from Transit Gateway?"),
            PracticeQuestion(id: "aws-lambda-ecs", packId: "aws", text: "When would you run a workload on Lambda instead of ECS?"),
            PracticeQuestion(id: "aws-dynamo", packId: "aws", text: "Explain eventual consistency in DynamoDB and when it is acceptable."),
            PracticeQuestion(id: "aws-multi-az", packId: "aws", text: "How would you design a multi-AZ architecture for a public API on AWS?")
        ]
    )

    static let models = PracticeTopicPack(
        id: "models",
        title: "Models",
        blurb: "Transformers, sampling, RAG, and serving trade-offs",
        groups: [PracticeGroup(id: "models", title: "Models")],
        questions: [
            PracticeQuestion(id: "models-encoder-decoder", packId: "models", text: "What is the difference between a transformer encoder and a decoder?"),
            PracticeQuestion(id: "models-sampling", packId: "models", text: "Explain temperature versus top-p when sampling from an LLM."),
            PracticeQuestion(id: "models-rag", packId: "models", text: "What is RAG, and when would you use it instead of fine-tuning?"),
            PracticeQuestion(id: "models-embeddings", packId: "models", text: "How do embeddings enable semantic search?"),
            PracticeQuestion(id: "models-context", packId: "models", text: "What is a context window, and what breaks when you exceed it?"),
            PracticeQuestion(id: "models-quant", packId: "models", text: "What is weight quantization, and what do you trade away for speed?"),
            PracticeQuestion(id: "models-eval", packId: "models", text: "How would you evaluate whether a smaller model is good enough for a production assistant?")
        ]
    )

    static let angular = PracticeTopicPack(
        id: "angular",
        title: "Angular",
        blurb: "Components, change detection, forms, and routing",
        groups: [PracticeGroup(id: "angular", title: "Angular")],
        questions: [
            PracticeQuestion(id: "angular-component-directive", packId: "angular", text: "What is the difference between an Angular component and a directive?"),
            PracticeQuestion(id: "angular-change-detection", packId: "angular", text: "How does Angular change detection work, and what does OnPush change?"),
            PracticeQuestion(id: "angular-signals", packId: "angular", text: "What are Angular signals, and why were they added?"),
            PracticeQuestion(id: "angular-state", packId: "angular", text: "When would you share state with a service versus NgRx?"),
            PracticeQuestion(id: "angular-forms", packId: "angular", text: "What is the difference between template-driven and reactive forms?"),
            PracticeQuestion(id: "angular-router", packId: "angular", text: "How does the Angular router lazy-load a feature module?"),
            PracticeQuestion(id: "angular-pipes", packId: "angular", text: "When should a pipe be pure, and what goes wrong if it is not?")
        ]
    )
}

func practicePackIDs() -> [String] {
    PracticeTopicPack.all.map(\.id)
}

func practicePack(id: String) -> PracticeTopicPack? {
    PracticeTopicPack.all.first { $0.id == id }
}

func questionsForPracticePack(id: String) -> [PracticeQuestion] {
    practicePack(id: id)?.questions ?? []
}

func questionsMatching(pack: PracticeTopicPack, groupIds: [String]) -> [PracticeQuestion] {
    if groupIds.isEmpty { return pack.questions }
    let allowed = Set(groupIds)
    return pack.questions.filter { allowed.contains($0.groupId) }
}

func practiceNormalizeQuestionText(_ text: String) -> String {
    var s = text
    if let tags = try? NSRegularExpression(pattern: "<[^>]+>") {
        s = tags.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
    }
    let entities = [
        ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
        ("&#39;", "'"), ("&quot;", "\"")
    ]
    for (entity, replacement) in entities {
        s = s.replacingOccurrences(of: entity, with: replacement)
    }
    if let space = try? NSRegularExpression(pattern: "\\s+") {
        s = space.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
    }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

func practiceQuestionPool(from bank: PracticeBankFile, groupIDs: Set<String> = []) -> [PracticeQuestion] {
    let questions = bank.packs.flatMap(\.questions)
    if groupIDs.isEmpty { return questions }
    return questions.filter { groupIDs.contains($0.groupId) }
}

func practiceStudyBookPack(from bank: PracticeBankFile) -> PracticeTopicPack? {
    bank.packs.first { $0.id == "study-book" }
}

func practiceTopicKey(for question: PracticeQuestion, groupIds: [String]) -> String {
    if groupIds.count == 1 {
        let topic = question.topicId
        return topic.isEmpty ? question.groupId : topic
    }
    let group = question.groupId
    return group.isEmpty ? question.packId : group
}

struct PracticeRole: Equatable {
    let id: String
    let title: String
    let groupIds: [String]

    static let all: [PracticeRole] = [aiEngineer, frontend, fullStack, qaAutomation]

    static let aiEngineer = PracticeRole(
        id: "ai-engineer",
        title: "AI Engineer",
        groupIds: [
            "python-engineering", "foundations", "classical-ml", "genai-and-llm",
            "ml-in-production", "system-design", "models", "interview-prep", "agentic-sme-s-and-p",
            "aws", "devops"
        ]
    )

    static let frontend = PracticeRole(
        id: "frontend",
        title: "Frontend engineer",
        groupIds: [
            "jr-javascript", "mid-javascript", "senior-javascript", "typescript",
            "angular", "oop", "json", "networking", "engineering-practice", "system-design"
        ]
    )

    static let fullStack = PracticeRole(
        id: "full-stack",
        title: "Full stack",
        groupIds: [
            "python-engineering", "jr-javascript", "mid-javascript", "senior-javascript",
            "typescript", "angular", "oop", "system-design", "engineering-practice",
            "aws", "networking", "json", "devops", "genai-and-llm", "interview-prep"
        ]
    )

    static let qaAutomation = PracticeRole(
        id: "qa-automation",
        title: "QA automation",
        groupIds: [
            "qa", "coding-tasks", "logical-tasks", "python-engineering",
            "engineering-practice", "java-and-jvm", "system-design", "interview-prep"
        ]
    )
}

func practiceRole(id: String) -> PracticeRole? {
    PracticeRole.all.first { $0.id == id }
}

func practiceGroupIDs(forRole role: PracticeRole, available: [String]) -> [String] {
    let allowed = Set(available)
    return role.groupIds.filter { allowed.contains($0) }
}

/// Interview flow after skipping background: language fundamentals, then models, then applied AI.
let practiceInterviewTopicOrder = [
    "jr-javascript",
    "mid-javascript",
    "senior-javascript",
    "typescript",
    "python-engineering",
    "oop",
    "foundations",
    "classical-ml",
    "genai-and-llm",
    "ml-in-production",
    "system-design",
    "engineering-practice",
    "java-and-jvm",
    "quant-and-domain",
    "agentic-sme-s-and-p",
    "interview-prep",
    "qa",
    "coding-tasks",
    "logical-tasks",
    "networking",
    "json",
    "devops",
    "aws",
    "models",
    "angular"
]

/// Round-robin across topics so a 100-question run is as even as the bank allows.
func balancedPracticeSelection(
    questions: [PracticeQuestion],
    count: Int,
    topicOf: (PracticeQuestion) -> String,
    shuffle: ([PracticeQuestion]) -> [PracticeQuestion] = { $0.shuffled() }
) -> [PracticeQuestion] {
    let want = min(max(0, count), questions.count)
    guard want > 0 else { return [] }

    var order: [String] = []
    var buckets: [String: [PracticeQuestion]] = [:]
    for question in questions {
        let topic = topicOf(question)
        if buckets[topic] == nil {
            order.append(topic)
            buckets[topic] = []
        }
        buckets[topic]?.append(question)
    }
    for topic in order {
        buckets[topic] = shuffle(buckets[topic] ?? [])
    }

    var nextIndex: [String: Int] = Dictionary(uniqueKeysWithValues: order.map { ($0, 0) })
    var selected: [PracticeQuestion] = []
    selected.reserveCapacity(want)
    var progressed = true
    while selected.count < want && progressed {
        progressed = false
        for topic in order {
            guard selected.count < want else { break }
            let index = nextIndex[topic] ?? 0
            let pool = buckets[topic] ?? []
            if index < pool.count {
                selected.append(pool[index])
                nextIndex[topic] = index + 1
                progressed = true
            }
        }
    }
    return selected
}

/// Same even split, but questions stay in interview order: finish Python, then models, not mixed.
func interviewOrderedPracticeSelection(
    questions: [PracticeQuestion],
    count: Int,
    topicOf: (PracticeQuestion) -> String,
    topicOrder: [String] = practiceInterviewTopicOrder,
    shuffle: ([PracticeQuestion]) -> [PracticeQuestion] = { $0.shuffled() }
) -> [PracticeQuestion] {
    let picked = balancedPracticeSelection(
        questions: questions,
        count: count,
        topicOf: topicOf,
        shuffle: shuffle
    )
    var buckets: [String: [PracticeQuestion]] = [:]
    var appearance: [String] = []
    for question in picked {
        let key = topicOf(question)
        if buckets[key] == nil {
            appearance.append(key)
        }
        buckets[key, default: []].append(question)
    }
    var result: [PracticeQuestion] = []
    var leftover = Set(appearance)
    for topic in topicOrder where leftover.contains(topic) {
        result.append(contentsOf: buckets[topic] ?? [])
        leftover.remove(topic)
    }
    for topic in appearance where leftover.contains(topic) {
        result.append(contentsOf: buckets[topic] ?? [])
    }
    return result
}

func practiceQuestionSourceLine(_ question: PracticeQuestion, groupTitle: String) -> String {
    let origin: String
    switch question.packId {
    case "study-book": origin = "Study book"
    case "interview-guide": origin = "Interview guide"
    case "ai-engineer-interview": origin = "AI engineer interview"
    case "ai-engineer-prep": origin = "AI interview prep"
    case "ai-engineer-interviewer": origin = "AI interviewer view"
    case "python-interview": origin = "Python interview"
    case "typescript-interview": origin = "TypeScript interview"
    case "oop-interview": origin = "OOP interview"
    case "llm-interview": origin = "LLM interview"
    case "aws-interview": origin = "AWS interview"
    case "devops-interview": origin = "DevOps interview"
    case "aws": origin = "AWS pack"
    case "models": origin = "Models pack"
    case "angular": origin = "Angular pack"
    default: origin = question.packId.isEmpty ? "Practice" : question.packId
    }
    var parts = [origin]
    if !groupTitle.isEmpty {
        parts.append(groupTitle)
    }
    if !question.topicTitle.isEmpty, question.topicTitle != groupTitle {
        parts.append(question.topicTitle)
    }
    return parts.joined(separator: " · ")
}

func practiceHelpText(for question: PracticeQuestion) -> String? {
    let answer = question.answer.trimmingCharacters(in: .whitespacesAndNewlines)
    if !answer.isEmpty { return answer }
    let rubric = question.rubric.trimmingCharacters(in: .whitespacesAndNewlines)
    if !rubric.isEmpty { return rubric }
    return nil
}

enum PracticeRunMode: String, CaseIterable, Equatable, Codable {
    case learn
    case rehearse
    case interview

    var title: String {
        switch self {
        case .learn: return "Active Recall"
        case .rehearse: return "Voice Rehearsal"
        case .interview: return "Interview"
        }
    }
}

func practiceRunMode(id: String) -> PracticeRunMode {
    PracticeRunMode(rawValue: id) ?? .learn
}

func practiceHelpAllowed(in mode: PracticeRunMode) -> Bool {
    mode != .interview
}

func practiceShowsMultipleChoice(in mode: PracticeRunMode) -> Bool {
    false
}

func practiceShowsSubmitButton(in mode: PracticeRunMode) -> Bool {
    true
}

/// Full Help is only the stored bank answer, and only after a Learn choice.
func practiceRevealedHelp(
    mode: PracticeRunMode,
    hasSelection: Bool,
    question: PracticeQuestion
) -> String? {
    guard practiceHelpAllowed(in: mode), hasSelection else { return nil }
    return practiceHelpText(for: question)
}

enum PracticeRecallRating: String, CaseIterable, Codable, Equatable {
    case again
    case hard
    case gotIt

    var title: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .gotIt: return "Got it"
        }
    }

    var intervalTitle: String {
        switch self {
        case .again: return "in a few minutes"
        case .hard: return "tomorrow"
        case .gotIt: return "in 3 days"
        }
    }

    var fallbackScore: Double {
        switch self {
        case .again: return 0.25
        case .hard: return 0.65
        case .gotIt: return 1.0
        }
    }
}

/// The learner's confidence before revealing the prepared answer.
/// Kept separate from the post-reveal rating so confident mistakes remain visible.
enum PracticeRecallConfidence: String, CaseIterable, Codable, Equatable {
    case unsure
    case mostly
    case very

    var title: String {
        switch self {
        case .unsure: return "Unsure"
        case .mostly: return "Mostly sure"
        case .very: return "Very sure"
        }
    }

    fileprivate var reviewIntervalMultiplier: Double {
        switch self {
        case .unsure: return 0.6
        case .mostly: return 1.0
        case .very: return 1.25
        }
    }
}

/// Retains what the learner produced before feedback as well as any repair attempt.
/// `answer` on legacy score records remains supported; new recall records can attach this value.
struct PracticeRecallResponse: Codable, Equatable {
    let initial: String
    let revised: String?

    init(initial: String, revised: String? = nil) {
        self.initial = initial
        let cleanedRevision = revised?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.revised = cleanedRevision?.isEmpty == false ? revised : nil
    }

    var current: String {
        revised ?? initial
    }

    var wasRevised: Bool {
        revised != nil
    }
}

/// A learner correction to the estimated coverage of one Key Idea.
struct PracticeCoverageOverride: Codable, Equatable {
    let ideaIndex: Int
    let isCovered: Bool
}

/// Applies learner corrections in order. Invalid indices are ignored and the last
/// correction for an idea wins, which makes repeated toggles deterministic.
func practiceApplyCoverageOverrides(
    automaticCoverage: [Bool],
    overrides: [PracticeCoverageOverride]
) -> [Bool] {
    var result = automaticCoverage
    for override in overrides where result.indices.contains(override.ideaIndex) {
        result[override.ideaIndex] = override.isCovered
    }
    return result
}

struct PracticeRecallReview: Equatable {
    let keyIdeas: [String]
    let automaticCovered: [Bool]
    let covered: [Bool]
    let coverageOverrides: [PracticeCoverageOverride]

    init(keyIdeas: [String], covered: [Bool]) {
        self.keyIdeas = keyIdeas
        self.automaticCovered = covered
        self.covered = covered
        self.coverageOverrides = []
    }

    init(
        keyIdeas: [String],
        automaticCovered: [Bool],
        coverageOverrides: [PracticeCoverageOverride]
    ) {
        self.keyIdeas = keyIdeas
        self.automaticCovered = automaticCovered
        self.coverageOverrides = coverageOverrides
        self.covered = practiceApplyCoverageOverrides(
            automaticCoverage: automaticCovered,
            overrides: coverageOverrides
        )
    }

    var coveredCount: Int {
        covered.filter { $0 }.count
    }

    var score: Double {
        guard !keyIdeas.isEmpty else { return 0 }
        return Double(coveredCount) / Double(keyIdeas.count)
    }
}

func practiceNextReviewDate(
    for rating: PracticeRecallRating,
    from date: Date = Date()
) -> Date {
    let interval: TimeInterval
    switch rating {
    case .again: interval = 5 * 60
    case .hard: interval = 24 * 60 * 60
    case .gotIt: interval = 3 * 24 * 60 * 60
    }
    return date.addingTimeInterval(interval)
}

/// Calculates a review interval that grows with demonstrated recall, is shortened
/// by low pre-reveal confidence, and leaves another review opportunity before an
/// interview/target date. The existing fixed scheduler above remains unchanged for
/// compatibility with completed runs and current UI copy.
func practiceAdaptiveReviewInterval(
    for rating: PracticeRecallRating,
    priorAttempts: [PracticeScoredAnswer],
    confidence: PracticeRecallConfidence?,
    from date: Date = Date(),
    targetDate: Date? = nil
) -> TimeInterval {
    let day: TimeInterval = 24 * 60 * 60
    let unassistedAttempts = priorAttempts.filter { !$0.usedHelp }
    let successfulReviews = unassistedAttempts.filter {
        $0.recallRating == .gotIt && $0.finalScore >= 0.75 && !$0.usedHelp
    }.count
    let attemptBonus = 1.0 + min(Double(unassistedAttempts.count), 6.0) * 0.08

    var interval: TimeInterval
    switch rating {
    case .again:
        interval = 5 * 60
    case .hard:
        interval = day * min(2.0, 1.0 + Double(successfulReviews) * 0.15)
    case .gotIt:
        let growth = pow(1.8, Double(min(successfulReviews, 4)))
        interval = 3 * day * growth * attemptBonus
    }

    if rating != .again, let confidence {
        interval *= confidence.reviewIntervalMultiplier
    }
    interval = min(interval, 45 * day)

    if let targetDate {
        let remaining = targetDate.timeIntervalSince(date)
        if remaining > 0 {
            // Keep at least one more retrieval opportunity before the target when possible.
            let targetCap = remaining >= 10 * 60 ? max(5 * 60, remaining / 2) : remaining
            interval = min(interval, targetCap, remaining)
        }
    }
    return max(0, interval)
}

func practiceAdaptiveNextReviewDate(
    for rating: PracticeRecallRating,
    priorAttempts: [PracticeScoredAnswer],
    confidence: PracticeRecallConfidence?,
    from date: Date = Date(),
    targetDate: Date? = nil
) -> Date {
    date.addingTimeInterval(practiceAdaptiveReviewInterval(
        for: rating,
        priorAttempts: priorAttempts,
        confidence: confidence,
        from: date,
        targetDate: targetDate
    ))
}

private func practiceCleanKeyIdea(_ raw: String, maxLength: Int = 132) -> String {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let marker = try? NSRegularExpression(pattern: "^\\s*(?:[-*•]+|\\d+[.)])\\s+") {
        value = marker.stringByReplacingMatches(
            in: value,
            range: NSRange(value.startIndex..., in: value),
            withTemplate: ""
        )
    }
    if let whitespace = try? NSRegularExpression(pattern: "\\s+") {
        value = whitespace.stringByReplacingMatches(
            in: value,
            range: NSRange(value.startIndex..., in: value),
            withTemplate: " "
        )
    }
    value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, !practiceAnswerLineIsHeading(value) else { return "" }
    if value.count <= maxLength { return value }

    let prefix = String(value.prefix(maxLength - 1))
    if let boundary = prefix.lastIndex(of: " ") {
        return String(prefix[..<boundary]).trimmingCharacters(in: .whitespaces) + "…"
    }
    return prefix + "…"
}

/// Extracts short, local-first review points from the prepared answer or rubric.
/// Structured bullets win; sentence and non-question hint fallbacks keep sparse banks useful.
func practiceKeyIdeas(for question: PracticeQuestion, limit: Int = 3) -> [String] {
    guard limit > 0 else { return [] }
    let body = practiceHelpText(for: question) ?? ""
    let lines = body
        .split(separator: "\n", omittingEmptySubsequences: true)
        .map(String.init)
    var candidates: [String] = []

    let markerPattern = try? NSRegularExpression(pattern: "^\\s*(?:[-*•]+|\\d+[.)])\\s+")
    for line in lines {
        let range = NSRange(line.startIndex..., in: line)
        guard markerPattern?.firstMatch(in: line, range: range) != nil else { continue }
        let idea = practiceCleanKeyIdea(line)
        if !idea.isEmpty { candidates.append(idea) }
    }

    if candidates.count < limit {
        let sentenceParts = body.components(separatedBy: CharacterSet(charactersIn: ".!?;\n"))
        for part in sentenceParts {
            let idea = practiceCleanKeyIdea(part)
            let wordCount = idea.split { $0.isWhitespace }.count
            if wordCount >= 3 { candidates.append(idea) }
        }
    }

    if candidates.count < limit {
        for hint in question.hints where !hint.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") {
            let idea = practiceCleanKeyIdea(hint)
            if !idea.isEmpty { candidates.append(idea) }
        }
    }

    var seen = Set<String>()
    var result: [String] = []
    for candidate in candidates {
        let key = candidate.lowercased().filter { $0.isLetter || $0.isNumber }
        guard !key.isEmpty, seen.insert(key).inserted else { continue }
        result.append(candidate)
        if result.count == limit { break }
    }
    return result
}

private let practiceRecallStopWords: Set<String> = [
    "and", "are", "but", "can", "for", "from", "has", "have", "into", "its", "not",
    "that", "the", "their", "then", "this", "through", "use", "using", "was", "were",
    "when", "which", "with", "you", "your"
]

private func practiceRecallTermKey(_ word: Substring) -> String? {
    var value = word.lowercased()
    guard value.count > 2, !practiceRecallStopWords.contains(value) else { return nil }
    let suffixes = ["ments", "ment", "ations", "ation", "ions", "tion", "ally", "ingly", "edly", "ity", "ing", "ed", "es", "ly", "s"]
    for suffix in suffixes where value.hasSuffix(suffix) && value.count - suffix.count >= 4 {
        value.removeLast(suffix.count)
        break
    }
    return String(value.prefix(6))
}

private func practiceRecallTermKeys(_ text: String) -> Set<String> {
    Set(
        text.split { !$0.isLetter }
            .compactMap(practiceRecallTermKey)
    )
}

func practiceCoveredKeyIdeas(
    answer: String,
    keyIdeas: [String],
    coverageOverrides: [PracticeCoverageOverride] = []
) -> [Bool] {
    let answerTerms = practiceRecallTermKeys(answer)
    let automatic = keyIdeas.map { idea in
        guard !answerTerms.isEmpty else { return false }
        let ideaTerms = practiceRecallTermKeys(idea)
        guard !ideaTerms.isEmpty else { return false }
        let overlap = answerTerms.intersection(ideaTerms).count
        let needed = ideaTerms.count <= 3 ? 1 : 2
        return overlap >= needed
    }
    return practiceApplyCoverageOverrides(
        automaticCoverage: automatic,
        overrides: coverageOverrides
    )
}

func practiceRecallReview(
    for question: PracticeQuestion,
    answer: String,
    coverageOverrides: [PracticeCoverageOverride] = []
) -> PracticeRecallReview {
    let ideas = practiceKeyIdeas(for: question)
    let automatic = practiceCoveredKeyIdeas(answer: answer, keyIdeas: ideas)
    return PracticeRecallReview(
        keyIdeas: ideas,
        automaticCovered: automatic,
        coverageOverrides: coverageOverrides
    )
}

struct PracticeLearnChoice: Equatable {
    let text: String
    let isCorrect: Bool
}

enum PracticeLearnOptionMark: Equatable {
    case unmarked
    case selectedCorrect
    case selectedWrong
    case revealedCorrect
}

func practiceLearnOptionMark(index: Int, selected: Int?, correct: Int?) -> PracticeLearnOptionMark {
    guard let selected, let correct else { return .unmarked }
    if index == selected {
        return index == correct ? .selectedCorrect : .selectedWrong
    }
    if index == correct {
        return .revealedCorrect
    }
    return .unmarked
}

func practiceAnswerLineIsHeading(_ line: String) -> Bool {
    var s = line.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("- ") {
        s = String(s.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }
    guard s.hasSuffix(":") else { return false }
    if s.contains(".") { return false }
    let words = s.split { $0.isWhitespace }
    return words.count <= 6
}

func practiceAnswerStem(for question: PracticeQuestion, maxLength: Int = 160) -> String {
    let body = (practiceHelpText(for: question) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !body.isEmpty else { return "" }
    var lines = body
        .split(separator: "\n", omittingEmptySubsequences: true)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    while let first = lines.first, practiceAnswerLineIsHeading(first), lines.count > 1 {
        lines.removeFirst()
    }
    var line = lines.first ?? body
    if line.hasPrefix("- ") {
        line = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }
    if practiceAnswerLineIsHeading(line), lines.count > 1 {
        line = lines[1]
        if line.hasPrefix("- ") {
            line = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
    }
    if line.count > maxLength, let range = line.range(of: ". ") {
        line = String(line[..<range.lowerBound]) + "."
    }
    if line.count > maxLength {
        line = String(line.prefix(maxLength - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
    return line
}

func practiceLearnChoices(
    for question: PracticeQuestion,
    in bank: [PracticeQuestion],
    shuffle: ([PracticeLearnChoice]) -> [PracticeLearnChoice] = { $0.shuffled() }
) -> [PracticeLearnChoice] {
    let correct = practiceAnswerStem(for: question)
    guard !correct.isEmpty else { return [] }
    var seen: Set<String> = [correct.lowercased()]
    var distractors: [String] = []

    func consider(_ questions: [PracticeQuestion]) {
        for candidate in questions {
            if distractors.count >= 3 { return }
            if candidate.id == question.id { continue }
            let stem = practiceAnswerStem(for: candidate)
            let key = stem.lowercased()
            if stem.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            distractors.append(stem)
        }
    }

    let others = bank.filter { $0.id != question.id }
    if !question.topicId.isEmpty {
        consider(others.filter { $0.topicId == question.topicId })
    }
    if !question.groupId.isEmpty {
        consider(others.filter { $0.groupId == question.groupId })
    }
    consider(others.filter { $0.packId == question.packId })
    consider(others)
    guard distractors.count >= 3 else { return [] }
    let choices = [PracticeLearnChoice(text: correct, isCorrect: true)]
        + distractors.prefix(3).map { PracticeLearnChoice(text: $0, isCorrect: false) }
    return shuffle(choices)
}

func practiceLatestScoredAnswers(_ answers: [PracticeScoredAnswer]) -> [PracticeScoredAnswer] {
    var order: [String] = []
    var latest: [String: PracticeScoredAnswer] = [:]
    for answer in answers {
        let key = "\(answer.packId)\u{1f}\(answer.questionId)"
        if latest[key] == nil { order.append(key) }
        latest[key] = answer
    }
    return order.compactMap { latest[$0] }
}

func practiceRunOverallScore(_ answers: [PracticeScoredAnswer]) -> Double {
    let latest = practiceLatestScoredAnswers(answers)
    guard !latest.isEmpty else { return 0 }
    return latest.map(\.finalScore).reduce(0, +) / Double(latest.count)
}

struct PracticeProgressInput: Equatable {
    let finishedAt: Date
    let score: Double
    let packId: String
}

struct PracticeProgressPoint: Equatable {
    let finishedAt: Date
    let score: Double
    let packId: String
}

func practiceProgressSeries(from runs: [PracticeProgressInput], packId: String? = nil) -> [PracticeProgressPoint] {
    runs
        .filter { packId == nil || $0.packId == packId }
        .sorted { $0.finishedAt < $1.finishedAt }
        .map { PracticeProgressPoint(finishedAt: $0.finishedAt, score: $0.score, packId: $0.packId) }
}

struct PracticeScoredAnswer: Codable, Equatable {
    let questionId: String
    let packId: String
    let question: String
    let answer: String
    let usedHelp: Bool
    let mark: PracticeHelpMark
    let rawScore: Double
    let finalScore: Double
    let feedback: String
    let strengths: [String]
    let gaps: [String]
    let recallRating: PracticeRecallRating?
    let nextReviewAt: Date?
    /// Rich recall fields are optional so all pre-Active-Recall runs still decode.
    let recallResponse: PracticeRecallResponse?
    let recallConfidence: PracticeRecallConfidence?
    let coverageOverrides: [PracticeCoverageOverride]?
    let reviewedAt: Date?

    init(
        questionId: String,
        packId: String,
        question: String,
        answer: String,
        usedHelp: Bool,
        mark: PracticeHelpMark,
        rawScore: Double,
        finalScore: Double,
        feedback: String,
        strengths: [String],
        gaps: [String],
        recallRating: PracticeRecallRating? = nil,
        nextReviewAt: Date? = nil,
        recallResponse: PracticeRecallResponse? = nil,
        recallConfidence: PracticeRecallConfidence? = nil,
        coverageOverrides: [PracticeCoverageOverride]? = nil,
        reviewedAt: Date? = nil
    ) {
        self.questionId = questionId
        self.packId = packId
        self.question = question
        self.answer = answer
        self.usedHelp = usedHelp
        self.mark = mark
        self.rawScore = rawScore
        self.finalScore = finalScore
        self.feedback = feedback
        self.strengths = strengths
        self.gaps = gaps
        self.recallRating = recallRating
        self.nextReviewAt = nextReviewAt
        self.recallResponse = recallResponse
        self.recallConfidence = recallConfidence
        self.coverageOverrides = coverageOverrides
        self.reviewedAt = reviewedAt
    }

    var initialRecallAnswer: String {
        recallResponse?.initial ?? answer
    }

    var revisedRecallAnswer: String? {
        recallResponse?.revised
    }

    var effectiveRecallAnswer: String {
        recallResponse?.current ?? answer
    }
}

struct PracticeRunRecord: Codable, Equatable {
    let id: String
    let packId: String
    let packTitle: String
    let startedAt: Date
    let finishedAt: Date
    let answers: [PracticeScoredAnswer]
    let overallScore: Double
    let helpedCount: Int
    let mode: PracticeRunMode?
    let targetDate: Date?

    init(
        id: String,
        packId: String,
        packTitle: String,
        startedAt: Date,
        finishedAt: Date,
        answers: [PracticeScoredAnswer],
        overallScore: Double,
        helpedCount: Int,
        mode: PracticeRunMode? = nil,
        targetDate: Date? = nil
    ) {
        self.id = id
        self.packId = packId
        self.packTitle = packTitle
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.answers = answers
        self.overallScore = overallScore
        self.helpedCount = helpedCount
        self.mode = mode
        self.targetDate = targetDate
    }
}

struct PracticeQuestionReference: Codable, Equatable, Hashable {
    let packId: String
    let questionId: String
}

/// Everything needed to resume a particular prompt without losing learner work.
struct PracticeSessionQuestionState: Codable, Equatable {
    var reference: PracticeQuestionReference
    var draftResponse: String
    var recallResponse: PracticeRecallResponse?
    var confidence: PracticeRecallConfidence?
    var hasRevealedKeyIdeas: Bool
    var coverageOverrides: [PracticeCoverageOverride]
    var usedHelp: Bool
    var repairDraft: String
    var isRepairingGap: Bool
    var repairIdeaIndex: Int?

    init(
        reference: PracticeQuestionReference,
        draftResponse: String = "",
        recallResponse: PracticeRecallResponse? = nil,
        confidence: PracticeRecallConfidence? = nil,
        hasRevealedKeyIdeas: Bool = false,
        coverageOverrides: [PracticeCoverageOverride] = [],
        usedHelp: Bool = false,
        repairDraft: String = "",
        isRepairingGap: Bool = false,
        repairIdeaIndex: Int? = nil
    ) {
        self.reference = reference
        self.draftResponse = draftResponse
        self.recallResponse = recallResponse
        self.confidence = confidence
        self.hasRevealedKeyIdeas = hasRevealedKeyIdeas
        self.coverageOverrides = coverageOverrides
        self.usedHelp = usedHelp
        self.repairDraft = repairDraft
        self.isRepairingGap = isRepairingGap
        self.repairIdeaIndex = repairIdeaIndex
    }

    private enum CodingKeys: String, CodingKey {
        case reference
        case draftResponse
        case recallResponse
        case confidence
        case hasRevealedKeyIdeas
        case coverageOverrides
        case usedHelp
        case repairDraft
        case isRepairingGap
        case repairIdeaIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reference = try container.decode(PracticeQuestionReference.self, forKey: .reference)
        draftResponse = try container.decodeIfPresent(String.self, forKey: .draftResponse) ?? ""
        recallResponse = try container.decodeIfPresent(PracticeRecallResponse.self, forKey: .recallResponse)
        confidence = try container.decodeIfPresent(PracticeRecallConfidence.self, forKey: .confidence)
        hasRevealedKeyIdeas = try container.decodeIfPresent(Bool.self, forKey: .hasRevealedKeyIdeas) ?? false
        coverageOverrides = try container.decodeIfPresent([PracticeCoverageOverride].self, forKey: .coverageOverrides) ?? []
        usedHelp = try container.decodeIfPresent(Bool.self, forKey: .usedHelp) ?? false
        repairDraft = try container.decodeIfPresent(String.self, forKey: .repairDraft) ?? ""
        isRepairingGap = try container.decodeIfPresent(Bool.self, forKey: .isRepairingGap) ?? false
        repairIdeaIndex = try container.decodeIfPresent(Int.self, forKey: .repairIdeaIndex)
    }
}

/// Enough pre-rating state to reverse the most recent rating and restore the review card.
struct PracticeRatingUndoMetadata: Codable, Equatable {
    let question: PracticeQuestionReference
    let questionIndex: Int
    let answerCountBeforeRating: Int
    let questionCountBeforeRating: Int
    let previousQuestionState: PracticeSessionQuestionState
    let ratedAt: Date
    let requeuedQuestionKeysBeforeRating: [String]?

    init(
        question: PracticeQuestionReference,
        questionIndex: Int,
        answerCountBeforeRating: Int,
        questionCountBeforeRating: Int,
        previousQuestionState: PracticeSessionQuestionState,
        ratedAt: Date,
        requeuedQuestionKeysBeforeRating: [String]? = nil
    ) {
        self.question = question
        self.questionIndex = questionIndex
        self.answerCountBeforeRating = answerCountBeforeRating
        self.questionCountBeforeRating = questionCountBeforeRating
        self.previousQuestionState = previousQuestionState
        self.ratedAt = ratedAt
        self.requeuedQuestionKeysBeforeRating = requeuedQuestionKeysBeforeRating
    }
}

/// Autosaved, in-progress work. Versioned and default-decoded so early snapshots can
/// remain resumable as fields are added.
struct PracticeSessionSnapshot: Codable, Equatable {
    static let currentVersion = 2

    var version: Int
    var id: String
    var packId: String
    var packTitle: String
    var roleId: String?
    var groupIds: [String]
    var mode: PracticeRunMode
    var questionStates: [PracticeSessionQuestionState]
    var baseQuestionCount: Int
    var currentQuestionIndex: Int
    var startedAt: Date
    var updatedAt: Date
    var answers: [PracticeScoredAnswer]
    var requeuedQuestionKeys: [String]
    var lastRatingUndo: PracticeRatingUndoMetadata?
    var targetDate: Date?

    init(
        version: Int = PracticeSessionSnapshot.currentVersion,
        id: String = UUID().uuidString,
        packId: String,
        packTitle: String,
        roleId: String? = nil,
        groupIds: [String] = [],
        mode: PracticeRunMode,
        questionStates: [PracticeSessionQuestionState],
        baseQuestionCount: Int? = nil,
        currentQuestionIndex: Int = 0,
        startedAt: Date,
        updatedAt: Date,
        answers: [PracticeScoredAnswer] = [],
        requeuedQuestionKeys: [String] = [],
        lastRatingUndo: PracticeRatingUndoMetadata? = nil,
        targetDate: Date? = nil
    ) {
        self.version = version
        self.id = id
        self.packId = packId
        self.packTitle = packTitle
        self.roleId = roleId
        self.groupIds = groupIds
        self.mode = mode
        self.questionStates = questionStates
        self.baseQuestionCount = baseQuestionCount ?? questionStates.count
        self.currentQuestionIndex = currentQuestionIndex
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.answers = answers
        self.requeuedQuestionKeys = requeuedQuestionKeys
        self.lastRatingUndo = lastRatingUndo
        self.targetDate = targetDate
    }

    var canResume: Bool {
        questionStates.indices.contains(currentQuestionIndex)
    }

    var questionReferences: [PracticeQuestionReference] {
        questionStates.map(\.reference)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case id
        case packId
        case packTitle
        case roleId
        case groupIds
        case mode
        case questionStates
        case questionIds
        case baseQuestionCount
        case currentQuestionIndex
        case startedAt
        case updatedAt
        case answers
        case requeuedQuestionKeys
        case lastRatingUndo
        case targetDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "legacy-session"
        packId = try container.decodeIfPresent(String.self, forKey: .packId) ?? ""
        packTitle = try container.decodeIfPresent(String.self, forKey: .packTitle) ?? "Practice"
        roleId = try container.decodeIfPresent(String.self, forKey: .roleId)
        groupIds = try container.decodeIfPresent([String].self, forKey: .groupIds) ?? []
        mode = try container.decodeIfPresent(PracticeRunMode.self, forKey: .mode) ?? .learn
        if let states = try container.decodeIfPresent([PracticeSessionQuestionState].self, forKey: .questionStates) {
            questionStates = states
        } else {
            let legacyQuestionIds = try container.decodeIfPresent([String].self, forKey: .questionIds) ?? []
            let legacyPackId = packId
            questionStates = legacyQuestionIds.map {
                PracticeSessionQuestionState(reference: PracticeQuestionReference(packId: legacyPackId, questionId: $0))
            }
        }
        baseQuestionCount = try container.decodeIfPresent(Int.self, forKey: .baseQuestionCount) ?? questionStates.count
        currentQuestionIndex = try container.decodeIfPresent(Int.self, forKey: .currentQuestionIndex) ?? 0
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? startedAt
        answers = try container.decodeIfPresent([PracticeScoredAnswer].self, forKey: .answers) ?? []
        requeuedQuestionKeys = try container.decodeIfPresent([String].self, forKey: .requeuedQuestionKeys) ?? []
        lastRatingUndo = try container.decodeIfPresent(PracticeRatingUndoMetadata.self, forKey: .lastRatingUndo)
        targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(id, forKey: .id)
        try container.encode(packId, forKey: .packId)
        try container.encode(packTitle, forKey: .packTitle)
        try container.encodeIfPresent(roleId, forKey: .roleId)
        try container.encode(groupIds, forKey: .groupIds)
        try container.encode(mode, forKey: .mode)
        try container.encode(questionStates, forKey: .questionStates)
        try container.encode(baseQuestionCount, forKey: .baseQuestionCount)
        try container.encode(currentQuestionIndex, forKey: .currentQuestionIndex)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(answers, forKey: .answers)
        try container.encode(requeuedQuestionKeys, forKey: .requeuedQuestionKeys)
        try container.encodeIfPresent(lastRatingUndo, forKey: .lastRatingUndo)
        try container.encodeIfPresent(targetDate, forKey: .targetDate)
    }
}

/// Returns a restored value instead of mutating persistence, keeping Undo easy to test.
func practiceSnapshotAfterUndoingLastRating(
    _ snapshot: PracticeSessionSnapshot,
    updatedAt: Date? = nil
) -> PracticeSessionSnapshot? {
    guard let undo = snapshot.lastRatingUndo,
          undo.answerCountBeforeRating >= 0,
          undo.answerCountBeforeRating < snapshot.answers.count,
          undo.questionCountBeforeRating > 0,
          undo.questionCountBeforeRating <= snapshot.questionStates.count,
          undo.questionIndex >= 0,
          undo.questionIndex < undo.questionCountBeforeRating else { return nil }

    var restored = snapshot
    restored.answers = Array(snapshot.answers.prefix(undo.answerCountBeforeRating))
    restored.questionStates = Array(snapshot.questionStates.prefix(undo.questionCountBeforeRating))
    restored.questionStates[undo.questionIndex] = undo.previousQuestionState
    restored.currentQuestionIndex = undo.questionIndex
    if let keys = undo.requeuedQuestionKeysBeforeRating {
        restored.requeuedQuestionKeys = keys
    }
    restored.lastRatingUndo = nil
    restored.updatedAt = updatedAt ?? snapshot.updatedAt
    return restored
}

func practiceRecallReviewKey(packId: String, questionId: String) -> String {
    "\(packId)\u{1f}\(questionId)"
}

func practiceLatestRecallAnswers(from runs: [PracticeRunRecord]) -> [String: PracticeScoredAnswer] {
    var latest: [String: PracticeScoredAnswer] = [:]
    for run in runs.sorted(by: { $0.finishedAt < $1.finishedAt }) {
        for answer in run.answers where answer.recallRating != nil {
            latest[practiceRecallReviewKey(packId: answer.packId, questionId: answer.questionId)] = answer
        }
    }
    return latest
}

func practiceRecallAttempts(from runs: [PracticeRunRecord]) -> [String: [PracticeScoredAnswer]] {
    var attempts: [String: [PracticeScoredAnswer]] = [:]
    for run in runs.sorted(by: { $0.finishedAt < $1.finishedAt }) {
        for answer in run.answers where answer.recallRating != nil {
            let key = practiceRecallReviewKey(packId: answer.packId, questionId: answer.questionId)
            attempts[key, default: []].append(answer)
        }
    }
    return attempts
}

enum PracticeMasteryState: String, CaseIterable, Codable, Equatable {
    case new
    case learning
    case solid
    case due

    var title: String {
        switch self {
        case .new: return "New"
        case .learning: return "Learning"
        case .solid: return "Solid"
        case .due: return "Due"
        }
    }
}

func practiceMasteryState(
    latestAnswer: PracticeScoredAnswer?,
    attempts: [PracticeScoredAnswer] = [],
    now: Date = Date()
) -> PracticeMasteryState {
    guard let latestAnswer else { return .new }
    if let due = latestAnswer.nextReviewAt, due <= now { return .due }
    guard latestAnswer.recallRating == .gotIt,
          latestAnswer.finalScore >= 0.8,
          !latestAnswer.usedHelp else {
        return .learning
    }
    let evidence = attempts.isEmpty ? [latestAnswer] : attempts
    let successfulUnassisted = evidence.filter {
        $0.recallRating == .gotIt && $0.finalScore >= 0.8 && !$0.usedHelp
    }
    if successfulUnassisted.count >= 2 {
        return .solid
    }
    return .learning
}

struct PracticeTopicIdentity: Codable, Equatable, Hashable {
    let id: String
    let title: String
}

struct PracticeTopicMasterySummary: Codable, Equatable {
    let topic: PracticeTopicIdentity
    let newCount: Int
    let learningCount: Int
    let solidCount: Int
    let dueCount: Int

    var totalCount: Int {
        newCount + learningCount + solidCount + dueCount
    }

    var masteredFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(solidCount) / Double(totalCount)
    }
}

private func practiceDefaultTopicIdentity(for question: PracticeQuestion) -> PracticeTopicIdentity {
    let id = question.groupId.isEmpty ? question.packId : question.groupId
    let fallback = question.topicTitle.isEmpty ? id : question.topicTitle
    return PracticeTopicIdentity(
        id: id,
        title: practiceGroupDisplayTitle(id: id, fallback: fallback)
    )
}

func practiceTopicMasterySummaries(
    questions: [PracticeQuestion],
    latestAnswers: [String: PracticeScoredAnswer],
    attemptsByQuestion: [String: [PracticeScoredAnswer]] = [:],
    now: Date = Date(),
    topicOf: ((PracticeQuestion) -> PracticeTopicIdentity)? = nil
) -> [PracticeTopicMasterySummary] {
    var order: [PracticeTopicIdentity] = []
    var counts: [PracticeTopicIdentity: [PracticeMasteryState: Int]] = [:]
    for question in questions {
        let topic = topicOf?(question) ?? practiceDefaultTopicIdentity(for: question)
        if counts[topic] == nil {
            order.append(topic)
            counts[topic] = [:]
        }
        let key = practiceRecallReviewKey(packId: question.packId, questionId: question.id)
        let state = practiceMasteryState(
            latestAnswer: latestAnswers[key],
            attempts: attemptsByQuestion[key, default: []],
            now: now
        )
        counts[topic, default: [:]][state, default: 0] += 1
    }
    return order.map { topic in
        let topicCounts = counts[topic] ?? [:]
        return PracticeTopicMasterySummary(
            topic: topic,
            newCount: topicCounts[.new, default: 0],
            learningCount: topicCounts[.learning, default: 0],
            solidCount: topicCounts[.solid, default: 0],
            dueCount: topicCounts[.due, default: 0]
        )
    }
}

struct PracticeTodayPlan: Codable, Equatable {
    let dueCount: Int
    let learningCount: Int
    let newCount: Int
    let solidCount: Int
    let recommendedCount: Int
    let estimatedMinutes: Int

    var weakCount: Int { learningCount }
    var totalQuestionCount: Int { dueCount + learningCount + newCount + solidCount }
}

func practiceTodaysPlan(
    questions: [PracticeQuestion],
    latestAnswers: [String: PracticeScoredAnswer],
    attemptsByQuestion: [String: [PracticeScoredAnswer]] = [:],
    now: Date = Date(),
    maximumQuestions: Int = 10,
    estimatedSecondsPerQuestion: Int = 48
) -> PracticeTodayPlan {
    var counts: [PracticeMasteryState: Int] = [:]
    for question in questions {
        let key = practiceRecallReviewKey(packId: question.packId, questionId: question.id)
        let state = practiceMasteryState(
            latestAnswer: latestAnswers[key],
            attempts: attemptsByQuestion[key, default: []],
            now: now
        )
        counts[state, default: 0] += 1
    }
    let actionable = counts[.due, default: 0]
        + counts[.learning, default: 0]
        + counts[.new, default: 0]
    let recommended = min(max(0, maximumQuestions), actionable)
    let seconds = recommended * max(0, estimatedSecondsPerQuestion)
    let minutes = seconds == 0 ? 0 : Int(ceil(Double(seconds) / 60.0))
    return PracticeTodayPlan(
        dueCount: counts[.due, default: 0],
        learningCount: counts[.learning, default: 0],
        newCount: counts[.new, default: 0],
        solidCount: counts[.solid, default: 0],
        recommendedCount: recommended,
        estimatedMinutes: minutes
    )
}

func practicePrioritizedRecallQuestions(
    _ questions: [PracticeQuestion],
    latestAnswers: [String: PracticeScoredAnswer],
    now: Date = Date()
) -> [PracticeQuestion] {
    questions.enumerated().sorted { lhs, rhs in
        func priority(_ question: PracticeQuestion, index: Int) -> (Int, Date, Int) {
            let key = practiceRecallReviewKey(packId: question.packId, questionId: question.id)
            guard let answer = latestAnswers[key], let due = answer.nextReviewAt else {
                return (1, .distantFuture, index)
            }
            if due <= now {
                return (0, due, index)
            }
            return (2, due, index)
        }
        let left = priority(lhs.element, index: lhs.offset)
        let right = priority(rhs.element, index: rhs.offset)
        if left.0 != right.0 { return left.0 < right.0 }
        if left.1 != right.1 { return left.1 < right.1 }
        return left.2 < right.2
    }.map(\.element)
}

func tokenizePractice(_ text: String) -> Set<String> {
    Set(
        text.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count > 2 }
    )
}

struct PracticeContrastPair: Codable, Equatable {
    let topic: PracticeTopicIdentity
    let first: PracticeQuestion
    let second: PracticeQuestion
}

private func practiceContrastTerms(_ text: String) -> Set<String> {
    let generic: Set<String> = [
        "compare", "describe", "difference", "does", "explain", "how", "versus",
        "what", "when", "which", "why", "would"
    ]
    return Set(tokenizePractice(text).filter { !practiceRecallStopWords.contains($0) && !generic.contains($0) })
}

private func practiceContrastWeakness(
    for question: PracticeQuestion,
    latestAnswers: [String: PracticeScoredAnswer],
    attemptsByQuestion: [String: [PracticeScoredAnswer]],
    now: Date
) -> Int {
    let key = practiceRecallReviewKey(packId: question.packId, questionId: question.id)
    switch practiceMasteryState(
        latestAnswer: latestAnswers[key],
        attempts: attemptsByQuestion[key, default: []],
        now: now
    ) {
    case .due: return 3
    case .learning: return 2
    case .new: return 1
    case .solid: return 0
    }
}

/// Selects deterministic, non-overlapping pairs of related prompts. Pairs must share
/// a broad topic and either a more specific topic id or meaningful vocabulary; this
/// avoids turning ordinary random interleaving into a purported contrast exercise.
func practiceContrastPairs(
    from questions: [PracticeQuestion],
    latestAnswers: [String: PracticeScoredAnswer] = [:],
    attemptsByQuestion: [String: [PracticeScoredAnswer]] = [:],
    now: Date = Date(),
    limit: Int = 3,
    topicOf: ((PracticeQuestion) -> PracticeTopicIdentity)? = nil
) -> [PracticeContrastPair] {
    guard limit > 0, questions.count >= 2 else { return [] }

    struct Candidate {
        let firstIndex: Int
        let secondIndex: Int
        let topic: PracticeTopicIdentity
        let score: Int
    }
    var candidates: [Candidate] = []
    for firstIndex in questions.indices {
        for secondIndex in questions.indices where secondIndex > firstIndex {
            let first = questions[firstIndex]
            let second = questions[secondIndex]
            let firstTopic = topicOf?(first) ?? practiceDefaultTopicIdentity(for: first)
            let secondTopic = topicOf?(second) ?? practiceDefaultTopicIdentity(for: second)
            guard firstTopic.id == secondTopic.id else { continue }

            let overlap = practiceContrastTerms(first.text).intersection(practiceContrastTerms(second.text)).count
            let sharesSpecificTopic = !first.topicId.isEmpty && first.topicId == second.topicId
            let contrastLanguage = [first.text, second.text].contains { text in
                let lower = text.lowercased()
                return lower.contains("difference") || lower.contains("compare")
                    || lower.contains(" versus ") || lower.contains(" vs ")
                    || lower.contains("trade-off")
            }
            // A broad topic id is not evidence that two prompts are confusable.
            // Require either meaningful shared vocabulary or explicit comparison
            // language backed by at least one shared concept term.
            guard overlap >= 2 || (contrastLanguage && overlap >= 1) else { continue }
            let score = overlap * 3
                + (sharesSpecificTopic ? 4 : 0)
                + (contrastLanguage ? 2 : 0)
                + practiceContrastWeakness(
                    for: first,
                    latestAnswers: latestAnswers,
                    attemptsByQuestion: attemptsByQuestion,
                    now: now
                )
                + practiceContrastWeakness(
                    for: second,
                    latestAnswers: latestAnswers,
                    attemptsByQuestion: attemptsByQuestion,
                    now: now
                )
            candidates.append(Candidate(
                firstIndex: firstIndex,
                secondIndex: secondIndex,
                topic: firstTopic,
                score: score
            ))
        }
    }

    candidates.sort {
        if $0.score != $1.score { return $0.score > $1.score }
        if $0.firstIndex != $1.firstIndex { return $0.firstIndex < $1.firstIndex }
        return $0.secondIndex < $1.secondIndex
    }
    var used = Set<Int>()
    var result: [PracticeContrastPair] = []
    for candidate in candidates {
        guard !used.contains(candidate.firstIndex), !used.contains(candidate.secondIndex) else { continue }
        used.insert(candidate.firstIndex)
        used.insert(candidate.secondIndex)
        result.append(PracticeContrastPair(
            topic: candidate.topic,
            first: questions[candidate.firstIndex],
            second: questions[candidate.secondIndex]
        ))
        if result.count == limit { break }
    }
    return result
}

func practiceContrastQuestionSelection(
    from questions: [PracticeQuestion],
    latestAnswers: [String: PracticeScoredAnswer] = [:],
    attemptsByQuestion: [String: [PracticeScoredAnswer]] = [:],
    now: Date = Date(),
    pairLimit: Int = 3,
    topicOf: ((PracticeQuestion) -> PracticeTopicIdentity)? = nil
) -> [PracticeQuestion] {
    practiceContrastPairs(
        from: questions,
        latestAnswers: latestAnswers,
        attemptsByQuestion: attemptsByQuestion,
        now: now,
        limit: pairLimit,
        topicOf: topicOf
    ).flatMap { [$0.first, $0.second] }
}

func heuristicPracticeRawScore(question: String, answer: String) -> Double {
    let answerWords = tokenizePractice(answer)
    let questionWords = tokenizePractice(question)
    if answerWords.isEmpty { return 0 }
    if answerWords.count < 8 { return 0.25 }
    let overlap = Double(answerWords.intersection(questionWords).count)
    let topical = questionWords.isEmpty ? 0.5 : min(1.0, overlap / Double(max(2, questionWords.count / 3)))
    let lengthScore = min(1.0, Double(answerWords.count) / 50.0)
    return min(1.0, 0.3 + 0.45 * lengthScore + 0.25 * topical)
}

func makePracticeRunRecord(
    id: String = UUID().uuidString,
    pack: PracticeTopicPack,
    startedAt: Date,
    finishedAt: Date,
    answers: [PracticeScoredAnswer],
    mode: PracticeRunMode? = nil,
    targetDate: Date? = nil
) -> PracticeRunRecord {
    let latest = practiceLatestScoredAnswers(answers)
    return PracticeRunRecord(
        id: id,
        packId: pack.id,
        packTitle: pack.title,
        startedAt: startedAt,
        finishedAt: finishedAt,
        answers: answers,
        overallScore: practiceRunOverallScore(answers),
        helpedCount: latest.filter(\.usedHelp).count,
        mode: mode,
        targetDate: targetDate
    )
}
