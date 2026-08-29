import Foundation

// Standalone test runner for pure functions
// Copies function implementations to test them in isolation

var passed = 0
var failed = 0

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        passed += 1
    } else {
        failed += 1
        print("  FAIL [\(file.split(separator: "/").last ?? ""):\(line)]: \(message)")
    }
}

func section(_ name: String) {
    print("\n--- \(name) ---")
}

// ============================================================
// SOURCE: Application/VoiceInterviewProcessor.swift:70
// ============================================================
func stringSimilarity(_ a: String, _ b: String) -> Double {
    let wordsA = Set(a.lowercased().split(separator: " ").map { String($0) })
    let wordsB = Set(b.lowercased().split(separator: " ").map { String($0) })
    guard !wordsA.isEmpty || !wordsB.isEmpty else { return 0 }
    let intersection = wordsA.intersection(wordsB).count
    let union = wordsA.union(wordsB).count
    return union > 0 ? Double(intersection) / Double(union) : 0
}

// SOURCE: Application/VoiceInterviewProcessor.swift:462
func isWhisperHallucination(_ trimmed: String) -> Bool {
    let whisperHallucinations = [
        "thank you", "thank you for watching", "thank you for listening",
        "thanks", "thanks for watching", "thanks for listening",
        "please subscribe", "like and subscribe", "see you next time",
        "bye", "goodbye", "bye bye", "bye-bye", "take care",
        "see you", "see you later", "see you soon",
        "you", "the end", "so", "okay", "ok", "right",
        "hmm", "hm", "um", "uh", "ah", "oh", "mhm", "uh-huh",
        "music", "applause", "laughter", "silence", "crickets",
        "[music]", "[applause]", "[laughter]", "[silence]",
        "(music)", "(applause)", "(laughter)", "(silence)",
        "subtitles by", "captions by", "translated by",
        "danke", "danke fürs zuschauen", "abonnieren", "abonniert", "tschüss", "auf wiedersehen", "bis bald",
        "gracias", "gracias por ver", "suscríbete", "suscribirse", "adiós", "hasta luego", "hasta pronto",
        "merci", "merci d'avoir regardé", "abonnez-vous", "s'abonner", "au revoir", "à bientôt", "salut",
        "grazie", "grazie per la visione", "iscriviti", "iscrivetevi", "ciao", "arrivederci", "a presto",
        "obrigado", "obrigada", "inscreva-se", "se inscreva", "tchau", "adeus", "até logo", "até mais",
        "благодаря", "благодаря ви", "абонирайте се", "абонирай се", "харесайте", "довиждане", "чао",
        "спасибо", "спасибо за просмотр", "подписывайтесь", "подпишитесь", "пока", "до свидания", "до скорого",
        "谢谢", "谢谢观看", "订阅", "请订阅", "再见", "拜拜",
        "xièxiè", "dìngyuè", "zàijiàn",
        "ありがとう", "ありがとうございます", "チャンネル登録", "登録", "さようなら", "バイバイ", "じゃね",
        "감사합니다", "구독", "구독해주세요", "좋아요", "안녕", "안녕하세요", "다음에 봐요"
    ]

    let lowerTrimmed = trimmed.lowercased()
        .replacingOccurrences(of: "!", with: "")
        .replacingOccurrences(of: ".", with: "")
        .replacingOccurrences(of: ",", with: "")
        .trimmingCharacters(in: .whitespaces)

    return trimmed.count < 30 && whisperHallucinations.contains(where: { lowerTrimmed == $0 })
}

// SOURCE: Application/VoiceInterviewProcessor.swift:512
func shouldSkipAsFillerOrGreeting(_ trimmed: String) -> Bool {
    let normalizedText = trimmed.lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "[.!?,']", with: "", options: .regularExpression)

    let greetingStarts = ["hello", "hi ", "hey ", "good morning", "good afternoon", "good evening", "welcome to"]
    let isGreeting = greetingStarts.contains { normalizedText.hasPrefix($0) }

    let fillerPatterns = ["thank you", "thanks", "yes sure", "yeah sure", "okay", "sure", "sounds good", "got it", "i see", "i understand", "alright"]
    let isFiller = fillerPatterns.contains { normalizedText.hasPrefix($0) || normalizedText == $0 }

    let questionWords = ["what", "how", "why", "when", "where", "which", "who", "can you", "could you", "would you", "tell me", "explain", "describe", "give me", "show me", "walk me"]
    let hasQuestionWord = questionWords.contains { normalizedText.contains($0) }

    if (isGreeting || isFiller) && normalizedText.count < 50 && !hasQuestionWord {
        return true
    }

    return false
}

// SOURCE: Application/VoiceInterviewProcessor.swift:535
func isLocallyIncomplete(_ trimmed: String) -> Bool {
    let textForCheck = trimmed.lowercased().trimmingCharacters(in: .whitespaces)
    let incompleteEndings = [" so", " and", " but", " the", " a", " an", " to", " of", " that", " if", " when", " is", " are", " have", " can", " will", " for", " with", " on", " in", " between", ","]
    let endsIncomplete = incompleteEndings.contains { textForCheck.hasSuffix($0) }
    let hasQuestionMark = textForCheck.contains("?")

    return endsIncomplete && !hasQuestionMark
}

struct QuestionSignal {
    let score: Int
    let reasons: [String]
    let topicHint: String?
    let isFollowUp: Bool
    let isBareIncomplete: Bool

    var protectsFromSkip: Bool {
        score >= 3 && !isBareIncomplete
    }
}

func checkForQuestionMarkers(_ text: String) -> Bool {
    questionSignal(for: text, lastTopic: nil).protectsFromSkip
}

func questionSignal(for text: String, lastTopic: String?) -> QuestionSignal {
    let normalized = normalizedQuestionText(text)
    let words = normalized.split(separator: " ").map(String.init)
    let wordCount = words.count
    var score = 0
    var reasons: [String] = []

    func add(_ points: Int, _ reason: String) {
        score += points
        reasons.append(reason)
    }

    let isCandidateStatement =
        normalized.hasPrefix("i ") ||
        normalized.hasPrefix("i'm ") ||
        normalized.hasPrefix("ive ") ||
        normalized.hasPrefix("i've ") ||
        normalized.hasPrefix("we ") ||
        normalized.hasPrefix("my ") ||
        normalized.contains("i have ") ||
        normalized.contains("i worked ") ||
        normalized.contains("we used ") ||
        normalized.contains("we implemented ")

    let bareIncomplete = isBareIncompletePrompt(normalized)

    if normalized.contains("?") {
        add(3, "question_mark")
    }

    let directQuestionPatterns = [
        "what is", "what are", "what's", "whats", "what did", "what do", "what does",
        "what exactly",
        "how do", "how does", "how is", "how would", "how can", "how to",
        "why do", "why does", "why is", "why would",
        "when do", "when does", "when would", "when should",
        "where do", "where does", "where is", "where exactly",
        "which ", "who ", "whose "
    ]
    if directQuestionPatterns.contains(where: { normalized.contains($0) }) {
        add(3, "direct_question")
    }

    let requestPatterns = [
        "can you explain", "could you explain", "can you tell", "could you tell",
        "tell me about", "tell me more", "walk me through", "walk us through",
        "could you walk through", "talk me through ", "talk us through ",
        "show me", "give me", "give us ",
        "help me understand", "help us understand",
        "explain ", "describe ", "let's talk about", "lets talk about",
        "let's discuss ", "lets discuss ", "let's go over ", "lets go over ",
        "introduce yourself", "please introduce", "can we start with your", "can we begin with your",
        "would like to know", "i want to know", "i'd like to know", "id like to know"
    ]
    if requestPatterns.contains(where: { normalized.contains($0) }) {
        add(3, "request")
    }

    let mixedLanguagePatterns = [
        "какво", "как ", "защо", "кога", "къде", "кой", "коя", "кое", "кои",
        "разкажи", "раскажи", "обясни", "опиши",
        "was ", "wie ", "warum", "wann", "wo ", "wer ", "welche",
        "qu'est", "comment", "pourquoi", "quand", "où ", "qui ",
        "qué ", "cómo", "por qué", "cuándo", "dónde", "quién"
    ]
    if mixedLanguagePatterns.contains(where: { normalized.contains($0) }) {
        add(3, "question_language_marker")
    }

    let comparisonPatterns = [
        " vs ", " versus ", "difference between", "differences between",
        "compare ", "pros and cons", "tradeoff", "trade-off", "trade off"
    ]
    if comparisonPatterns.contains(where: { normalized.contains($0) }) {
        add(2, "comparison")
    }

    let followUpPatterns = [
        "what about", "how about", "what else", "anything else", "tell me more",
        "can you elaborate", "could you elaborate", "elaborate",
        "can you expand", "expand on that", "go deeper", "more details",
        "give me an example", "example", "edge cases", "corner cases",
        "complexity", "time complexity", "space complexity", "drawbacks",
        "risks", "retry", "retries", "mocking"
    ]
    let hasFollowUpPhrase = !isCandidateStatement && followUpPatterns.contains { normalized.contains($0) }
    let technicalTokens = technicalQuestionTokens(in: normalized)
    let isShortTechnicalPrompt = wordCount <= 7 && !technicalTokens.isEmpty && !isCandidateStatement
    let isContextualShortFollowUp = lastTopic != nil && wordCount <= 6 && (hasFollowUpPhrase || isShortTechnicalPrompt)
    let isFollowUp = hasFollowUpPhrase || isContextualShortFollowUp

    if isFollowUp {
        add(lastTopic == nil ? 2 : 3, "follow_up")
    }

    if !technicalTokens.isEmpty {
        add(1, "technical_term")
        if isShortTechnicalPrompt {
            add(2, "short_technical_prompt")
        }
    }

    let topicHint = isVagueFollowUpPrompt(normalized, technicalTokens: technicalTokens)
        ? "followUp"
        : bestTopicHint(from: normalized, technicalTokens: technicalTokens)
    return QuestionSignal(
        score: score,
        reasons: reasons,
        topicHint: topicHint,
        isFollowUp: isFollowUp,
        isBareIncomplete: bareIncomplete
    )
}

func normalizedQuestionText(_ text: String) -> String {
    text.lowercased()
        .replacingOccurrences(of: "’", with: "'")
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func repairNoisyTechnicalTranscript(_ text: String, favorsAIAcronyms: Bool = true) -> String {
    guard favorsAIAcronyms else { return text }

    let normalized = normalizedQuestionText(text)
    func hasWord(_ word: String) -> Bool {
        let pattern = "(^|[^a-z0-9])\(word)($|[^a-z0-9])"
        return normalized.range(of: pattern, options: .regularExpression) != nil
    }

    let hasRack = hasWord("rack")
    let hasRag = hasWord("rag")
    let hasCAC = hasWord("cac")
    let hasCAG = hasWord("cag")
    let rackLooksLikeRAG = hasRack && (
        hasCAC ||
        hasCAG ||
        normalized.range(of: #"\brack\s+(system|pipeline|architecture)\b"#, options: .regularExpression) != nil
    )
    let cacLooksLikeCAG = hasCAC && (
        hasRack ||
        hasRag ||
        normalized.contains("cache augmented") ||
        normalized.contains("context augmented")
    )

    guard rackLooksLikeRAG || cacLooksLikeCAG else { return text }

    var repaired = text
    if rackLooksLikeRAG {
        repaired = repaired.replacingOccurrences(
            of: #"\brack\b"#,
            with: "RAG",
            options: [.regularExpression, .caseInsensitive]
        )
    }
    if cacLooksLikeCAG {
        repaired = repaired.replacingOccurrences(
            of: #"\bcac\b"#,
            with: "CAG",
            options: [.regularExpression, .caseInsensitive]
        )
    }
    return repaired
}

func isBareIncompletePrompt(_ normalized: String) -> Bool {
    let cleaned = normalized.trimmingCharacters(in: CharacterSet(charactersIn: " .,!?:;"))
    let incompleteStems: Set<String> = [
        "what is the", "what is a", "what are the", "how do you", "how does the",
        "can you", "can you explain", "could you", "could you explain",
        "tell me about", "explain", "describe", "walk me through"
    ]
    if incompleteStems.contains(cleaned) {
        return true
    }

    let incompleteComparisonSuffixes = [
        "difference between", "differences between",
        "compare", "compare between", "versus", "vs"
    ]
    return incompleteComparisonSuffixes.contains { cleaned.hasSuffix($0) }
}

func technicalQuestionTokens(in normalized: String) -> Set<String> {
    let tokenMap: [(String, String)] = [
        ("hash map", "hashMap"), ("hashmap", "hashMap"), ("hash table", "hashMap"),
        ("hash set", "hashSet"), ("hashset", "hashSet"),
        ("hash code", "hashCode"), ("hashcode", "hashCode"),
        ("arraylist", "arrayList"), ("array list", "arrayList"),
        ("linkedlist", "linkedList"), ("linked list", "linkedList"),
        ("oop", "oop"), ("o o p", "oop"), ("object oriented", "oop"),
        ("solid", "solid"), ("polymorphism", "polymorphism"), ("inheritance", "inheritance"),
        ("encapsulation", "encapsulation"), ("abstraction", "abstraction"),
        ("singleton", "singleton"), ("factory", "factory"), ("dependency injection", "dependencyInjection"),
        ("playwright", "playwright"), ("selenium", "selenium"), ("cypress", "cypress"),
        ("pytest", "pytest"), ("test automation", "testAutomation"), ("e2e", "e2eTesting"),
        ("end to end", "e2eTesting"), ("api testing", "apiTesting"), ("contract testing", "contractTesting"),
        ("accessibility testing", "accessibilityTesting"), ("a11y", "accessibilityTesting"),
        ("wcag", "accessibilityTesting"), ("screen reader", "accessibilityTesting"),
        ("keyboard navigation", "accessibilityTesting"),
        ("cross browser", "crossBrowserTesting"), ("browser compatibility", "crossBrowserTesting"),
        ("page object", "pageObjects"), ("locator", "playwrightLocators"), ("locators", "playwrightLocators"),
        ("fixture", "playwrightFixtures"), ("fixtures", "playwrightFixtures"),
        ("test data", "testData"), ("mocking", "mocking"), ("mock", "mocking"),
        ("flaky", "flakyTests"), ("flake", "flakyTests"), ("trace viewer", "traceViewer"),
        ("trace", "traceViewer"), ("ci pipeline", "cicd"), ("pipeline", "cicd"),
        ("ci/cd", "cicd"), ("ci cd", "cicd"), ("cicd", "cicd"),
        ("continuous integration", "cicd"), ("continuous delivery", "cicd"),
        ("continuous deployment", "cicd"),
        ("regression", "regression"), ("getbyrole", "playwrightLocators"),
        ("get by role", "playwrightLocators"), ("web first", "webFirstAssertions"),
        ("auto wait", "autoWaiting"), ("storage state", "storageState"),
        ("browser context", "browserContext"), ("page route", "pageRoute"),
        ("network intercept", "networkMocking"), ("har", "networkMocking"),
        ("workers", "workers"), ("worker", "workers"), ("sharding", "sharding"),
        ("retry", "retries"), ("retries", "retries"), ("codegen", "codegen"),
        ("thread", "threads"), ("threads", "threads"), ("deadlock", "deadlock"),
        ("lock", "locks"), ("locks", "locks"), ("jvm", "jvm"), ("jdk", "jdk"),
        ("garbage collection", "garbageCollection"), ("heap", "heap"), ("stack", "stack"),
        ("closure", "closure"), ("event loop", "eventLoop"), ("promise", "promises"),
        ("promises", "promises"), ("async await", "asyncAwait"),
        ("big o", "bigO"), ("complexity", "bigO"), ("binary search", "binarySearch"),
        ("recursion", "recursion"), ("dynamic programming", "dynamicProgramming"),
        ("docker", "docker"), ("kubernetes", "kubernetes"), ("linux", "linux"),
        ("bash", "bash"), ("rest", "rest"), ("microservices", "microservices"),
        ("database", "database"), ("sql", "sql"), ("nosql", "nosql"),
        ("llm", "llm"), ("large language model", "llm"),
        ("rag", "rag"), ("retrieval augmented generation", "rag"),
        ("cag", "cag"), ("cache augmented generation", "cag"),
        ("context augmented generation", "cag"),
        ("vector database", "vectorDatabase"),
        ("embedding", "embeddings"), ("embeddings", "embeddings"),
        ("prompt engineering", "promptEngineering"),
        ("fine tune", "fineTuning"), ("fine tuning", "fineTuning"),
        ("transformer", "transformers"), ("attention", "attention"),
        // Common interview topics that were missing from local detection. Adding them
        // lets clear questions on these topics resolve a concrete topic locally and take
        // the direct Haiku answer path instead of waiting on the slower classifier path.
        ("interface", "interface"),
        ("abstract class", "abstractClass"), ("abstractclass", "abstractClass"),
        ("lambda", "lambda"), ("stream api", "streamApi"), ("streams", "streamApi"),
        ("generics", "generics"), ("typescript", "typescript"),
        ("exception", "exceptions"), ("exceptions", "exceptions"),
        ("volatile", "volatile"), ("synchronized", "synchronized"), ("synchronization", "synchronized"),
        ("caching", "caching"), ("cache", "caching"), ("redis", "redis"),
        ("load balancing", "loadBalancing"), ("load balancer", "loadBalancing"),
        ("redux", "redux"), ("react hooks", "reactHooks"),
        ("usestate", "useState"), ("useeffect", "useEffect"),
        // More high-frequency interview topics. The short/ambiguous tokens below
        // (aws, git, css, dom, orm, jwt, tcp, udp) are matched on word boundaries
        // via `wordBoundaryNeedles` so they never fire inside unrelated words
        // (e.g. "performance" must not match "orm", "random" must not match "dom").
        ("graphql", "graphql"), ("oauth", "oauth"), ("kafka", "kafka"),
        ("websocket", "websockets"), ("web socket", "websockets"),
        ("middleware", "middleware"),
        ("aws", "aws"), ("git", "git"), ("css", "css"), ("dom", "dom"),
        ("orm", "orm"), ("jwt", "jwt"), ("tcp", "tcp"), ("udp", "udp"),
        // High-frequency QA/SDET and backend interview topics that were missing from
        // local detection. Resolving them locally lets clear questions take the fast
        // direct answer path instead of the slower model classification path that adds
        // visible answer latency. All are
        // multi-word or distinctive tokens, so they are word-boundary-safe; only "acid"
        // is guarded via `wordBoundaryNeedles` (it is a substring of "placid").
        ("test pyramid", "testPyramid"), ("test strategy", "testStrategy"),
        ("test plan", "testStrategy"), ("test case", "testDesign"), ("test design", "testDesign"),
        ("boundary value", "boundaryValue"), ("equivalence partition", "equivalencePartitioning"),
        ("smoke test", "smokeTesting"), ("sanity test", "sanityTesting"), ("sanity check", "sanityTesting"),
        ("cucumber", "bdd"), ("gherkin", "bdd"), ("behavior driven", "bdd"), ("behaviour driven", "bdd"),
        // Test-methodology fundamentals — among the most common interview openers and
        // previously absent from local detection, so clear questions ("What is unit
        // testing?", "What is TDD?") fell through to the slow Haiku classify+answer path.
        // Multi-word phrases are substring-safe; the bare abbreviations "tdd"/"bdd" are
        // guarded via `wordBoundaryNeedles` so they never fire inside another word.
        ("unit test", "unitTesting"), ("integration test", "integrationTesting"),
        ("test driven", "tdd"), ("tdd", "tdd"), ("bdd", "bdd"),
        ("design pattern", "designPatterns"),
        ("rest assured", "apiTesting"), ("restassured", "apiTesting"),
        ("soft assert", "assertions"), ("headless", "headless"), ("xpath", "playwrightLocators"),
        ("performance testing", "performanceTesting"), ("load testing", "performanceTesting"),
        ("stress testing", "performanceTesting"),
        ("database index", "indexing"), ("db index", "indexing"), ("indexing", "indexing"),
        ("acid", "transactions"), ("transaction", "transactions"),
        ("message queue", "messageQueue"), ("rate limit", "rateLimiting"),
        ("memory leak", "memoryLeak"), ("cap theorem", "capTheorem"),
        ("idempoten", "idempotency"), ("normalization", "normalization"), ("normalisation", "normalization"),
        // Core data-structure and system-design openers that were missing from local
        // detection, so clear questions ("What is a queue?", "How does sorting work?",
        // "Walk me through a system design problem") fell through to the slow Haiku
        // classify+answer path. All three are distinct, substring-safe tokens already in
        // the model's TOPICS list, so resolving them locally lets clear questions take the
        // direct answer path without changing classification behavior.
        // "message queue" stays the more specific messageQueue topic (it sorts before
        // bare "queue").
        ("queue", "queue"), ("sorting", "sorting"), ("system design", "systemDesign"),
        // High-frequency DSA patterns and concurrency openers that were missing from
        // local detection, so clear questions ("What is an array?", "What is
        // backtracking?", "What is a race condition?") fell through to the slow
        // Haiku classify+answer path (~930ms to first visible text) instead of the fast
        // direct answer path. "array" is guarded in `wordBoundaryNeedles`
        // so it never fires inside "disarray"/"arrayed" and never shadows arrayList
        // (disambiguated in `bestTopicHint`); the rest are multi-word or distinctive
        // tokens that are inherently substring-safe. ("two pointer" is intentionally
        // omitted: "two" contains the German "wo " question marker, which would let a
        // candidate statement mentioning it score as a question and get fast-pathed.)
        ("array", "array"),
        ("sliding window", "slidingWindow"),
        ("backtracking", "backtracking"), ("memoization", "memoization"),
        ("concurrency", "concurrency"), ("race condition", "raceCondition"),
        ("хешмап", "hashMap"), ("хеш мап", "hashMap"), ("хеш таблиц", "hashMap"),
        ("хеш код", "hashCode"), ("ооп", "oop"), ("оп,", "oop"), ("оп ", "oop"),
        ("обектно", "oop"), ("полиморф", "polymorphism"),
        ("наследяване", "inheritance"), ("капсулация", "encapsulation")
    ]

    // Short or ambiguous tokens that must match on a word boundary so they do not
    // fire as substrings of unrelated words (e.g. "har" in "share", "orm" in
    // "performance", "dom" in "random", "aws" in "flaws", "git" in "legitimate").
    let wordBoundaryNeedles: Set<String> = ["har", "aws", "git", "css", "dom", "orm", "jwt", "tcp", "udp", "acid", "tdd", "bdd", "array", "llm", "rag", "cag"]
    var result = Set<String>()
    func containsNeedle(_ needle: String) -> Bool {
        if wordBoundaryNeedles.contains(needle) {
            let pattern = "(^|[^a-z0-9])" + needle + "($|[^a-z0-9])"
            return normalized.range(of: pattern, options: .regularExpression) != nil
        }
        return normalized.contains(needle)
    }

    for (needle, token) in tokenMap where containsNeedle(needle) {
        result.insert(token)
    }
    return result
}

func bestTopicHint(from normalized: String, technicalTokens: Set<String>) -> String? {
    if normalized.contains("хешмап") ||
        normalized.contains("хеш мап") ||
        normalized.contains("хеш таблиц") ||
        normalized.contains("hash map") ||
        normalized.contains("hashmap") ||
        normalized.contains("hash table") {
        return "hashMap"
    }
    if normalized.contains("хеш код") ||
        normalized.contains("hash code") ||
        normalized.contains("hashcode") {
        return "hashCode"
    }
    if normalized.contains("ооп") ||
        normalized.contains("обектно") ||
        normalized.contains("object oriented") ||
        normalized.contains("object-oriented") ||
        normalized.contains("полиморф") ||
        normalized.contains("наследяване") ||
        normalized.contains("капсулация") {
        return "oop"
    }
    if technicalTokens.contains("rag") && technicalTokens.contains("cag") {
        return "ragCag"
    }
    if normalized.contains("introduce yourself") ||
        normalized.contains("please introduce") ||
        normalized.contains("your introduction") ||
        normalized.contains("quick intro") ||
        normalized.contains("brief intro") ||
        normalized.contains("about yourself") ||
        normalized.contains("your background") ||
        normalized.contains("your experience") ||
        normalized.contains("your project") ||
        normalized.contains("your projects") ||
        normalized.contains("recent project") ||
        normalized.contains("last project") ||
        normalized.contains("project you worked on") ||
        normalized.contains("current role") ||
        normalized.contains("last role") {
        return "personal"
    }
    // "array list"/"arraylist" matches both the bare "array" token and the more
    // specific arrayList needle; prefer arrayList so it is never shadowed by the
    // alphabetically-earlier "array" in the fallback below.
    if normalized.contains("array list") || normalized.contains("arraylist") {
        return "arrayList"
    }
    return technicalTokens.sorted().first
}

func isVagueFollowUpPrompt(_ normalized: String, technicalTokens: Set<String>) -> Bool {
    guard technicalTokens.isEmpty else { return false }

    let cleaned = normalized.trimmingCharacters(in: CharacterSet(charactersIn: " .,!?:;"))
    let exactFollowUps: Set<String> = [
        "tell me more", "can you elaborate", "could you elaborate", "elaborate",
        "what else", "anything else", "go deeper", "more details",
        "can you expand", "expand on that", "continue"
    ]
    if exactFollowUps.contains(cleaned) {
        return true
    }

    return cleaned.contains("give me an example") ||
        cleaned.contains("more about that") ||
        cleaned.contains("expand on this")
}

func shouldSkipAsSocialPleasantry(_ trimmed: String) -> Bool {
    let normalized = normalizedQuestionText(trimmed)
    let cleaned = normalized
        .replacingOccurrences(of: #"[^a-z0-9\s']+"#, with: " ", options: .regularExpression)
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return false }

    let contentMarkers = [
        "experience", "background", "project", "role", "testing", "automation",
        "framework", "code", "implement", "design", "architecture", "system",
        "api", "test", "strength", "weakness", "company", "last role",
        "introduction", "introduce"
    ]
    if !technicalQuestionTokens(in: normalized).isEmpty ||
        contentMarkers.contains(where: { cleaned.contains($0) }) {
        return false
    }

    let interviewRequestPhrases = [
        "tell me about", "tell us about",
        "walk me through", "walk us through",
        "talk me through", "talk us through",
        "let's talk about", "lets talk about",
        "let's discuss", "lets discuss",
        "let's go over", "lets go over",
        "explain your", "describe your",
        "introduce yourself", "please introduce"
    ]
    if interviewRequestPhrases.contains(where: { cleaned.contains($0) }) {
        return false
    }

    let exactSocialPrompts: Set<String> = [
        "how are you", "how are you doing", "how's it going", "how is it going",
        "how have you been", "how have you been doing",
        "can you hear me", "are you there", "are you able to hear me",
        "can you see my screen", "shall we start", "are you ready", "what's up"
    ]
    if exactSocialPrompts.contains(cleaned) {
        return true
    }

    let setupCheckPhrases = [
        "can you hear me", "can you hear us", "can you hear okay", "can you hear clearly",
        "do you hear me", "do you hear us", "hear us okay", "hear us clearly",
        "is the audio okay", "audio okay", "audio working", "audio is working",
        "can you confirm your audio", "can you confirm audio",
        "is the sound okay", "sound okay", "sound working", "sound is working",
        "can you see my screen",
        "are you able to see my screen", "see my screen",
        "can you see the screen", "are you able to see the screen",
        "see the screen", "see this screen", "see shared screen",
        "see the shared screen", "see the screen share",
        "is my screen visible", "is the screen visible",
        "is the shared screen visible", "screen visible",
        "shared screen visible", "screen share visible"
    ]
    let wordCount = cleaned.split(separator: " ").count
    if wordCount <= 12 && setupCheckPhrases.contains(where: { cleaned.contains($0) }) {
        return true
    }

    let readySetupPhrases = [
        "are you ready to start", "are you ready to begin", "are you ready to proceed",
        "ready to start", "ready to begin", "ready to proceed", "shall we begin",
        "shall we proceed", "can we start", "can we begin", "can we proceed",
        "are you comfortable to start", "are you comfortable to begin",
        "are you comfortable to proceed", "comfortable to start",
        "comfortable to begin", "comfortable to proceed"
    ]
    if wordCount <= 8 && readySetupPhrases.contains(where: { cleaned.contains($0) }) {
        return true
    }

    let reciprocalSocialPrompts = ["how about you", "what about you", "and you"]
    if wordCount <= 10,
       reciprocalSocialPrompts.contains(where: { cleaned == $0 || cleaned.hasSuffix(" \($0)") }) {
        let socialReplyMarkers = [
            "i'm good", "im good", "i am good", "doing good", "doing well",
            "all good", "i'm fine", "im fine", "thanks", "thank you", "on my side"
        ]
        return wordCount <= 4 || socialReplyMarkers.contains(where: { cleaned.contains($0) })
    }

    let hasSocialHowQuestion = cleaned.contains("how are you") || cleaned.contains("how have you been")
    if hasSocialHowQuestion {
        let contentfulHowAreYouPhrases = [
            "how are you handling", "how are you using", "how are you testing",
            "how are you implementing", "how are you designing", "how are you managing",
            "how are you debugging", "how are you solving", "how are you approaching",
            "how are you dealing", "how are you working", "how are you doing with",
            "how are you doing in", "how are you doing on", "how are you doing for",
            "how have you been handling", "how have you been using", "how have you used",
            "how have you been testing", "how have you been implementing",
            "how have you been designing", "how have you been managing",
            "how have you been debugging", "how have you been solving",
            "how have you been approaching", "how have you been dealing",
            "how have you been working"
        ]
        if contentfulHowAreYouPhrases.contains(where: { cleaned.contains($0) }) {
            return false
        }

        let socialLeadIns = [
            "hi ", "hello ", "hey ", "so hi", "so hello",
            "nice to meet you", "good to meet you", "great to meet you",
            "pleasure to meet you",
            "before we start", "before we begin", "before we get started",
            "before getting started", "before we jump in"
        ]
        let socialWellnessPhrases = [
            "how are you today", "how are you doing", "how are you doing today",
            "how are you feeling", "how are you feeling today",
            "how have you been", "how have you been doing",
            "how have you been today", "how have you been feeling"
        ]
        let socialReplyMarkers = [
            "doing good", "doing well", "i'm good", "im good", "i am good",
            "i'm fine", "im fine", "all good"
        ]

        return socialReplyMarkers.contains(where: { cleaned.contains($0) }) ||
            socialLeadIns.contains(where: { cleaned.hasPrefix($0) || cleaned.contains(" \($0)") }) ||
            (wordCount <= 12 && socialWellnessPhrases.contains(where: { cleaned.contains($0) }))
    }

    return false
}

func shouldVetoQuestionAsCandidateStatement(_ text: String, signal: QuestionSignal) -> Bool {
    let normalized = normalizedQuestionText(text)
    let wordCount = normalized.split(separator: " ").count
    guard wordCount >= 5 else { return false }

    let firstPersonStarts = [
        "i ", "i'm ", "im ", "ive ", "i've ", "we ", "my ",
        "in my last role", "in my current role"
    ]
    let answerPhrases = [
        "i have ", "i worked ", "i use ", "i used ", "i usually ",
        "i was ", "we used ", "we implemented ", "we have ",
        "my experience", "my main strength", "the system uses ",
        "let me explain", "let me describe", "let me walk through"
    ]

    let looksLikeCandidateStatement = firstPersonStarts.contains(where: { normalized.hasPrefix($0) }) ||
        answerPhrases.contains(where: { normalized.contains($0) })
    guard looksLikeCandidateStatement else { return false }

    let interviewerRequestPhrases = [
        "i would like to know", "i'd like to know", "id like to know",
        "i want to know", "i wanted to ask",
        "i would like you to", "i'd like you to", "id like you to"
    ]
    if interviewerRequestPhrases.contains(where: { normalized.contains($0) }) {
        return false
    }

    let candidateAbilityLeadIns = [
        "i can explain", "i could explain", "i can tell", "i could tell",
        "i can describe", "i could describe", "i can walk through", "i could walk through",
        "i can show", "i could show", "i would explain", "i'd explain", "id explain",
        "i will explain", "i'll explain", "ill explain",
        "i would describe", "i'd describe", "id describe",
        "i will describe", "i'll describe", "ill describe",
        "i will walk through", "i'll walk through", "ill walk through",
        "let me explain", "let me describe", "let me walk through",
        "we can explain", "we could explain", "we can walk through", "we could walk through"
    ]
    if let leadIn = candidateAbilityLeadIns.first(where: { normalized.hasPrefix($0) }) {
        if leadIn.hasPrefix("let me ") {
            let candidateNarrationMarkers = [
                " i ", " i'm ", " im ", " i've ", " ive ",
                " my ", " we ", " our ", " in my ", " in our "
            ]
            if candidateNarrationMarkers.contains(where: { normalized.contains($0) }) {
                return true
            }
        } else {
            return true
        }
    }

    if signal.protectsFromSkip {
        let interviewerReasonMarkers = [
            "direct_question", "request", "question_language_marker",
            "comparison", "follow_up", "short_technical_prompt"
        ]
        if signal.reasons.contains(where: { interviewerReasonMarkers.contains($0) }) {
            return false
        }
    }

    return true
}

func shouldTreatLocalSignalAsClearQuestion(_ text: String, signal: QuestionSignal) -> Bool {
    signal.protectsFromSkip && !shouldVetoQuestionAsCandidateStatement(text, signal: signal)
}

// SOURCE: Application/VoiceInterviewProcessor.swift
func correctedTopic(for text: String, classifiedTopic: String?) -> String {
    let normalized = text.lowercased()
    let topic = classifiedTopic?.isEmpty == false ? classifiedTopic! : "unknown"
    let topicLower = topic.lowercased()

    if normalized.contains("хешмап") ||
        normalized.contains("хеш мап") ||
        normalized.contains("хеш таблиц") ||
        normalized.contains("hash map") ||
        normalized.contains("hashmap") ||
        normalized.contains("hash table") {
        return "hashMap"
    }

    if normalized.contains("хеш код") ||
        normalized.contains("hash code") ||
        normalized.contains("hashcode") {
        return "hashCode"
    }

    if normalized.contains("ооп") ||
        normalized.contains("обектно") ||
        normalized.contains("object oriented") ||
        normalized.contains("object-oriented") ||
        normalized.contains(" полиморф") ||
        normalized.contains(" наследяване") ||
        normalized.contains(" капсулация") ||
        normalized.hasPrefix("оп,") ||
        normalized.hasPrefix("оп ") ||
        normalized.contains(" оп,") ||
        normalized.contains(" оп ") {
        return "oop"
    }

    if topicLower == "unknown" || topicLower == "none" {
        let normalizedForSignal = normalizedQuestionText(text)
        let localTokens = technicalQuestionTokens(in: normalizedForSignal)
        if isVagueFollowUpPrompt(normalizedForSignal, technicalTokens: localTokens) {
            return "followUp"
        }
        if let topicHint = bestTopicHint(from: normalizedForSignal, technicalTokens: localTokens) {
            return topicHint
        }
    }

    return topic
}

// SOURCE: Application/VoiceInterviewProcessor.swift provisionalAnswerTopic
let provisionalDeferredTopics: Set<String> = ["followup", "unknown", "none"]
let backgroundDependentTopics: Set<String> = ["personal"]

func provisionalAnswerTopic(for text: String, lastTopic: String?, hasBackground: Bool = false) -> String? {
    let signal = questionSignal(for: text, lastTopic: lastTopic)
    guard shouldTreatLocalSignalAsClearQuestion(text, signal: signal) else { return nil }
    guard !signal.isBareIncomplete, !isLocallyIncomplete(text) else { return nil }

    var topic = correctedTopic(for: text, classifiedTopic: signal.topicHint)
    if topic.lowercased() == "unknown", let hint = signal.topicHint {
        topic = hint
    }
    let topicLower = topic.lowercased()

    // Vague follow-ups AND clear questions with no concrete topic of their own resolve
    // onto the concrete prior topic so they take the fast path (mirrors the slow path's
    // unknown-topic-with-prior-context follow-up routing). Orphans still defer.
    if provisionalDeferredTopics.contains(topicLower) {
        guard let priorTopic = lastTopic,
              !provisionalDeferredTopics.contains(priorTopic.lowercased()),
              !backgroundDependentTopics.contains(priorTopic.lowercased()) else { return nil }
        return priorTopic
    }

    if backgroundDependentTopics.contains(topicLower) {
        return hasBackground ? topic : nil
    }
    return topic
}

// SOURCE: Application/VoiceInterviewProcessor.swift:489
func cleanConversationalLine(_ line: String) -> String {
    var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return "" }

    var marker = ""
    if cleaned.hasPrefix("- ") || cleaned.hasPrefix("* ") {
        marker = String(cleaned.prefix(2))
        cleaned = String(cleaned.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    } else if cleaned.count > 3,
              let first = cleaned.first,
              first.isNumber,
              cleaned.dropFirst().hasPrefix(". ") {
        marker = "- "
        cleaned = String(cleaned.dropFirst(3)).trimmingCharacters(in: .whitespaces)
    }

    cleaned = stripInlineMarkdownForCueCard(cleaned)
    let withoutBold = cleaned
    let lowerWithoutBold = withoutBold.lowercased()
    let discardableIntroPrefixes = [
        "sure, here's", "sure here's", "here's a concise", "here is a concise",
        "here are", "of course", "absolutely"
    ]
    if discardableIntroPrefixes.contains(where: { lowerWithoutBold.hasPrefix($0) }) &&
        (lowerWithoutBold.contains("answer") ||
         lowerWithoutBold.contains("bullet") ||
         lowerWithoutBold.contains("cue")) {
        if let inlineCueTail = inlineCueTail(in: withoutBold) {
            return inlineCueTail
        }
        return ""
    }

    let answerLeadInPrefixes = [
        "i would answer it as:", "i'd answer it as:", "id answer it as:",
        "i would say:", "i'd say:", "id say:",
        "my answer would be:",
        "for this one, i would say:", "for this one, i'd say:", "for this one, id say:"
    ]
    for prefix in answerLeadInPrefixes where lowerWithoutBold.hasPrefix(prefix) {
        cleaned = String(withoutBold.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        break
    }

    let softLeadInPatterns = [
        #"^(for this one,\s*)?i would say\s+(?=[a-z0-9])"#,
        #"^(for this one,\s*)?i'd say\s+(?=[a-z0-9])"#,
        #"^(for this one,\s*)?id say\s+(?=[a-z0-9])"#,
        #"^i would answer it as\s+(?=[a-z0-9])"#,
        #"^my answer would be\s+(?=[a-z0-9])"#
    ]
    for pattern in softLeadInPatterns
        where cleaned.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
        cleaned = cleaned
            .replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespaces)
        break
    }

    let headingPrefixes = [
        "definition:", "key point:", "key points:", "gotcha:", "senior tip:",
        "answer:", "short answer:", "direct answer:", "summary:",
        "approach:", "trade-off:", "tradeoff:", "example:", "for example:"
    ]

    for prefix in headingPrefixes {
        if withoutBold.lowercased().hasPrefix(prefix) {
            cleaned = String(withoutBold.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            break
        }
    }

    guard !cleaned.isEmpty else { return "" }
    return marker + cleaned
}

func inlineCueTail(in text: String) -> String? {
    let markerPatterns = [
        #"\s+[-*]\s+"#,
        #"\s+\d+\.\s+"#
    ]

    for pattern in markerPatterns {
        if let range = text.range(of: pattern, options: .regularExpression) {
            var start = range.lowerBound
            while start < text.endIndex && text[start].isWhitespace {
                start = text.index(after: start)
            }
            let tail = String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return tail.isEmpty ? nil : tail
        }
    }

    return nil
}

func conversationalDisplayAnswer(_ answer: String) -> String {
    let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return trimmed }
    guard !trimmed.contains("```") else { return trimmed }

    var cueItems: [String] = []
    for rawLine in trimmed.components(separatedBy: .newlines) {
        let cleaned = cleanConversationalLine(rawLine)
        guard !cleaned.isEmpty else { continue }
        let unbulleted = stripCueMarker(from: cleaned)
        cueItems.append(contentsOf: cueFragments(from: unbulleted))
    }

    var uniqueItems: [String] = []
    var seen = Set<String>()
    for item in cueItems {
        let compact = compactCueLine(item)
        guard !compact.isEmpty else { continue }
        let key = compact.lowercased()
        guard !seen.contains(key) else { continue }
        seen.insert(key)
        uniqueItems.append(compact)
        if uniqueItems.count == 5 { break }
    }

    guard !uniqueItems.isEmpty else { return trimmed }
    return uniqueItems.map { "- \($0)" }.joined(separator: "\n")
}

func stripInlineMarkdownForCueCard(_ text: String) -> String {
    var cleaned = text
    cleaned = cleaned.replacingOccurrences(
        of: #"\*\*([A-Za-z])\*\*([A-Za-z]+)"#,
        with: "$1 - $1$2",
        options: .regularExpression
    )
    cleaned = cleaned.replacingOccurrences(
        of: #"\b([A-Za-z])\*\*\s*"#,
        with: "$1 - ",
        options: .regularExpression
    )
    cleaned = cleaned.replacingOccurrences(
        of: #"\*\*([^*]+)\*\*"#,
        with: "$1",
        options: .regularExpression
    )
    cleaned = cleaned.replacingOccurrences(of: "**", with: "")
    cleaned = cleaned.replacingOccurrences(of: "__", with: "")
    cleaned = cleaned.replacingOccurrences(
        of: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#,
        with: "$1",
        options: .regularExpression
    )
    cleaned = cleaned.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}

func stripCueMarker(from line: String) -> String {
    var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.hasPrefix("- ") || text.hasPrefix("* ") {
        text = String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    } else if text.count > 3,
              let first = text.first,
              first.isNumber,
              text.dropFirst().hasPrefix(". ") {
        text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
    }
    return text
}

func cueFragments(from text: String) -> [String] {
    let marker = "\u{1E}"
    let acronymLock = "\u{1F}"
    let lockedAcronyms = text.replacingOccurrences(
        of: #"\b([A-Za-z]) - "#,
        with: "$1\(acronymLock)",
        options: .regularExpression
    )
    let prepared = lockedAcronyms
        .replacingOccurrences(of: #"\s+[-*]\s+"#, with: marker, options: .regularExpression)
        .replacingOccurrences(of: #"\s+\d+\.\s+"#, with: marker, options: .regularExpression)
        .replacingOccurrences(of: #"\s+/\s+"#, with: marker, options: .regularExpression)
        .replacingOccurrences(of: "—", with: ". ")
        .replacingOccurrences(of: " - ", with: ". ")
        .replacingOccurrences(of: acronymLock, with: " - ")
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !prepared.isEmpty else { return [] }

    return prepared
        .replacingOccurrences(of: #";\s+"#, with: marker, options: .regularExpression)
        .replacingOccurrences(of: #"(?<=[.!?])\s+"#, with: marker, options: .regularExpression)
        .components(separatedBy: marker)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .flatMap(splitLongCommaCueFragment)
        .filter { !$0.isEmpty }
}

func splitLongCommaCueFragment(_ text: String) -> [String] {
    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleaned.count > 140 else { return [cleaned] }

    let marker = "\u{1E}"
    let splitPattern = #",\s+(?=(?:and\s+)?(?:i|we|then|also|use|set|keep|review|report|focus|make|start|build|write|run|debug|validate|separate)\b)"#
    let splitText = cleaned.replacingOccurrences(
        of: splitPattern,
        with: marker,
        options: [.regularExpression, .caseInsensitive]
    )
    let parts = splitText
        .components(separatedBy: marker)
        .map { part -> String in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.lowercased().hasPrefix("and ")
                ? String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                : trimmed
        }
        .filter { !$0.isEmpty }

    return parts.count >= 2 ? parts : [cleaned]
}

func compactCueLine(_ text: String) -> String {
    let cleaned = text
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-*")))
    guard !cleaned.isEmpty else { return "" }

    let maxCharacters = 120
    guard cleaned.count > maxCharacters else { return cleaned }

    let limitIndex = cleaned.index(cleaned.startIndex, offsetBy: maxCharacters)
    let head = String(cleaned[..<limitIndex])
    let separators = [",", ";", " because ", " so ", " and ", " with "]
    for separator in separators {
        if let range = head.range(of: separator, options: .backwards),
           head.distance(from: head.startIndex, to: range.lowerBound) >= 55 {
            let shortened = String(head[..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return shortened.hasSuffix(".") ? shortened : "\(shortened)."
        }
    }

    let shortened = head.trimmingCharacters(in: .whitespacesAndNewlines)
    return shortened.hasSuffix(".") ? shortened : "\(shortened)..."
}

// SOURCE: Domain/Model/AppSettings.swift
enum TestInterviewRole: String, CaseIterable {
    case seniorQAEngineer = "senior_qa_engineer"
    case qaEngineer = "qa_engineer"
    case qaAutomationEngineer = "qa_automation_engineer"
    case sdet = "sdet"
    case backendDeveloper = "backend_developer"

    static let selectableCases: [TestInterviewRole] = [
        .qaEngineer,
        .qaAutomationEngineer,
        .seniorQAEngineer,
        .backendDeveloper
    ]

    var canonicalRole: TestInterviewRole {
        switch self {
        case .sdet:
            return .qaAutomationEngineer
        default:
            return self
        }
    }

    var displayName: String {
        switch canonicalRole {
        case .seniorQAEngineer: return "Senior QA / SDET"
        case .qaEngineer: return "QA Engineer"
        case .qaAutomationEngineer: return "QA Automation / SDET"
        case .sdet: return "QA Automation / SDET"
        case .backendDeveloper: return "Backend Developer"
        }
    }

    var isQA: Bool {
        switch canonicalRole {
        case .qaEngineer, .qaAutomationEngineer, .seniorQAEngineer:
            return true
        default:
            return false
        }
    }
}

// ============================================================
// SOURCE: Domain/Model/ConversationContext.swift
// ============================================================

enum Speaker: String {
    case interviewer
    case interviewee
    case unknown
}

struct MultiTurnMessage {
    let role: String
    let content: String
}

// SOURCE: Domain/Model/ConversationContext.swift:34
func classifySpeaker(text: String, isQuestion: Bool = false) -> Speaker {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let words = trimmed.split(separator: " ")
    let wordCount = words.count
    let lowercased = trimmed.lowercased()

    if isQuestion {
        return .interviewer
    }

    let hasQuestionMark = trimmed.contains("?")
    let startsWithQuestion = lowercased.hasPrefix("what") ||
                              lowercased.hasPrefix("how") ||
                              lowercased.hasPrefix("why") ||
                              lowercased.hasPrefix("can you") ||
                              lowercased.hasPrefix("could you") ||
                              lowercased.hasPrefix("tell me") ||
                              lowercased.hasPrefix("explain") ||
                              lowercased.hasPrefix("describe") ||
                              lowercased.hasPrefix("walk me") ||
                              lowercased.hasPrefix("so ") ||
                              lowercased.hasPrefix("let's assume")

    let isFollowUp = lowercased.contains("tell me more") ||
                     lowercased.contains("dig deeper") ||
                     lowercased.contains("elaborate") ||
                     lowercased.contains("can you expand") ||
                     lowercased.contains("more details") ||
                     lowercased.contains("give me an example")

    let isInterviewerPhrase = lowercased.contains("welcome to") ||
                               lowercased.contains("good evening") ||
                               lowercased.contains("good morning") ||
                               lowercased.contains("shall proceed") ||
                               lowercased.contains("gone through your resume") ||
                               lowercased.contains("let me ask")

    if wordCount < 25 && (hasQuestionMark || startsWithQuestion || isFollowUp || isInterviewerPhrase) {
        return .interviewer
    }

    if wordCount > 30 {
        return .interviewee
    }

    if wordCount > 15 {
        return .interviewee
    }

    return .unknown
}

// SOURCE: Domain/Model/ConversationContext.swift:93
func isFollowUp(text: String) -> Bool {
    let lowercased = text.lowercased()
    let followUpPhrases = [
        "tell me more", "dig deeper", "elaborate", "expand on",
        "more details", "give me an example", "can you explain",
        "what else", "go deeper", "more about", "continue"
    ]
    return followUpPhrases.contains { lowercased.contains($0) }
}

// SOURCE: Domain/Model/ConversationContext.swift:230
func messagesToAPIFormat(_ messages: [MultiTurnMessage]) -> [[String: String]] {
    var result: [[String: String]] = []
    var lastRole: String?

    for msg in messages {
        if msg.role == lastRole, var lastMsg = result.last {
            lastMsg["content"] = (lastMsg["content"] ?? "") + "\n\n" + msg.content
            result[result.count - 1] = lastMsg
        } else {
            result.append(["role": msg.role, "content": msg.content])
            lastRole = msg.role
        }
    }

    if result.first?["role"] != "user" {
        result.insert(["role": "user", "content": "(Interview in progress)"], at: 0)
    }

    return result
}

// ============================================================
// TESTS
// ============================================================

section("stringSimilarity")
assert(stringSimilarity("hello world", "hello world") == 1.0, "Identical strings = 1.0")
assert(stringSimilarity("", "") == 0.0, "Empty strings = 0.0")
assert(stringSimilarity("hello world", "hello there") > 0.0, "Partial overlap > 0")
assert(stringSimilarity("hello world", "hello there") < 1.0, "Partial overlap < 1")
assert(stringSimilarity("abc def", "xyz qrs") == 0.0, "No overlap = 0.0")
assert(stringSimilarity("Hello World", "hello world") == 1.0, "Case insensitive")
let sim = stringSimilarity("what is a binary tree", "what is a binary search tree")
assert(sim > 0.5, "Similar questions have high similarity: \(sim)")

section("isWhisperHallucination")
assert(isWhisperHallucination("Thank you!") == true, "YouTube outro")
assert(isWhisperHallucination("thank you for watching") == true, "YouTube outro 2")
assert(isWhisperHallucination("[music]") == true, "Music artifact")
assert(isWhisperHallucination("um") == true, "Filler sound")
assert(isWhisperHallucination("What is a hash map?") == false, "Real question")
assert(isWhisperHallucination("I have 5 years of experience in distributed systems") == false, "Real answer (long)")
assert(isWhisperHallucination("благодаря") == true, "Bulgarian thank you")
assert(isWhisperHallucination("ありがとう") == true, "Japanese thank you")
assert(isWhisperHallucination("감사합니다") == true, "Korean thank you")

section("shouldSkipAsFillerOrGreeting")
assert(shouldSkipAsFillerOrGreeting("Hello") == true, "Simple greeting")
assert(shouldSkipAsFillerOrGreeting("Good morning") == true, "Morning greeting")
assert(shouldSkipAsFillerOrGreeting("Thanks") == true, "Thanks filler")
assert(shouldSkipAsFillerOrGreeting("Sounds good") == true, "Filler")
assert(shouldSkipAsFillerOrGreeting("Hello, what is your experience with microservices?") == false, "Greeting + question")
assert(shouldSkipAsFillerOrGreeting("Can you explain the difference between TCP and UDP?") == false, "Real question")
assert(shouldSkipAsFillerOrGreeting("I see") == true, "Short filler")
assert(shouldSkipAsFillerOrGreeting("Hi, can you tell me about your background?") == false, "Greeting with tell me")
assert(shouldSkipAsSocialPleasantry("So, hi, how are you, Shubhadev? Yeah, I'm doing good. How are you?") == true, "Social greeting exchange is skipped")
assert(shouldSkipAsSocialPleasantry("Hi, how are you?") == true, "Short social question is skipped")
assert(shouldSkipAsSocialPleasantry("So before we get started, how are you doing today?") == true, "Longer pre-interview how-are-you pleasantry is skipped")
assert(shouldSkipAsSocialPleasantry("Nice to meet you, how are you?") == true, "Meet-and-greet how-are-you pleasantry is skipped")
assert(shouldSkipAsSocialPleasantry("Good to meet you. How have you been?") == true, "Meet-and-greet how-have-you-been pleasantry is skipped")
assert(shouldSkipAsSocialPleasantry("How have you been doing today?") == true, "Short how-have-you-been social question is skipped")
assert(shouldSkipAsSocialPleasantry("Nice to meet you, how are you? Great, let's talk about your biggest achievement.") == false, "Pleasantry followed by interview request is preserved")
assert(shouldSkipAsSocialPleasantry("How are you handling production incidents?") == false, "Contentful how-are-you handling question is preserved")
assert(shouldSkipAsSocialPleasantry("Nice to meet you, how are you using Playwright traces?") == false, "Meet-and-greet with technical how-are-you question is preserved")
assert(shouldSkipAsSocialPleasantry("How have you been using Playwright traces to debug flaky tests?") == false, "Technical how-have-you phrasing is preserved")
assert(shouldSkipAsSocialPleasantry("Yeah, I'm good, thanks. How about you?") == true, "Reciprocal how-about-you pleasantry is skipped")
assert(shouldSkipAsSocialPleasantry("All good on my side, and you?") == true, "Short and-you pleasantry is skipped")
assert(shouldSkipAsSocialPleasantry("Can you hear me?") == true, "Audio check is skipped")
assert(shouldSkipAsSocialPleasantry("Great, can you hear me and see my screen?") == true, "Combined audio/screen check is skipped")
assert(shouldSkipAsSocialPleasantry("Can you hear us okay?") == true, "Plural audio check is skipped")
assert(shouldSkipAsSocialPleasantry("Do you hear us clearly?") == true, "Plural hear-us check is skipped")
assert(shouldSkipAsSocialPleasantry("Is the audio okay on your side?") == true, "Audio-quality setup check is skipped")
assert(shouldSkipAsSocialPleasantry("Can you confirm your audio is working?") == true, "Audio-working setup check is skipped")
assert(shouldSkipAsSocialPleasantry("Are you able to see the screen?") == true, "The-screen visibility setup check is skipped")
assert(shouldSkipAsSocialPleasantry("Is the shared screen visible?") == true, "Shared-screen visibility setup check is skipped")
assert(shouldSkipAsSocialPleasantry("Can you see the screen share?") == true, "Screen-share visibility setup check is skipped")
assert(shouldSkipAsSocialPleasantry("Are you ready to start?") == true, "Ready-to-start setup check is skipped")
assert(shouldSkipAsSocialPleasantry("Can we start?") == true, "Can-we-start setup check is skipped")
assert(shouldSkipAsSocialPleasantry("Can we begin now?") == true, "Can-we-begin setup check is skipped")
assert(shouldSkipAsSocialPleasantry("Shall we proceed?") == true, "Shall-we-proceed setup check is skipped")
assert(shouldSkipAsSocialPleasantry("Are you comfortable to start?") == true, "Comfortable-to-start setup check is skipped")
assert(shouldSkipAsSocialPleasantry("How are you testing API contracts?") == false, "Technical how-are-you phrasing is preserved")
assert(shouldSkipAsSocialPleasantry("How do you test audio streaming?") == false, "Contentful audio-testing question is preserved")
assert(shouldSkipAsSocialPleasantry("How would you test screen sharing permissions?") == false, "Contentful screen-sharing test question is preserved")
assert(shouldSkipAsSocialPleasantry("How about test automation in your last role?") == false, "Technical how-about prompt is preserved")
assert(shouldSkipAsSocialPleasantry("Are you ready to discuss API testing strategy?") == false, "Contentful ready-to-discuss prompt is preserved")
assert(shouldSkipAsSocialPleasantry("Can we start with your background?") == false, "Contentful can-we-start prompt is preserved")
assert(shouldSkipAsSocialPleasantry("Can we begin with API testing strategy?") == false, "Contentful can-we-begin prompt is preserved")
assert(shouldSkipAsSocialPleasantry("Shall we proceed with API testing strategy?") == false, "Contentful shall-we-proceed prompt is preserved")
assert(shouldSkipAsSocialPleasantry("Are you comfortable discussing Playwright locators?") == false, "Contentful comfortable-discussing prompt is preserved")

section("isLocallyIncomplete")
assert(isLocallyIncomplete("I was working on the") == true, "Ends with article")
assert(isLocallyIncomplete("The system uses a") == true, "Ends with 'a'")
assert(isLocallyIncomplete("We implemented it and") == true, "Ends with conjunction")
assert(isLocallyIncomplete("What is a binary tree?") == false, "Complete question")
assert(isLocallyIncomplete("The algorithm runs in O(n) time") == false, "Complete statement")
assert(isLocallyIncomplete("I optimized the database,") == true, "Ends with comma")
assert(isLocallyIncomplete("We tried to optimize the query but") == true, "Ends with 'but'")
assert(isLocallyIncomplete("Can you explain the difference between") == true, "Missing comparison object is incomplete")
assert(isLocallyIncomplete("Can you explain the difference between TCP and UDP") == false, "Complete comparison request is not incomplete")

section("checkForQuestionMarkers")
assert(checkForQuestionMarkers("What is a hash map?") == true, "English question with ?")
assert(checkForQuestionMarkers("How does garbage collection work") == true, "How does")
assert(checkForQuestionMarkers("Tell me about your experience") == true, "Tell me about")
assert(checkForQuestionMarkers("Explain the SOLID principles") == true, "Explain")
assert(checkForQuestionMarkers("Playwright locators and fixtures") == true, "Automation topic mention")
assert(checkForQuestionMarkers("How do you triage flaky E2E tests?") == true, "Flaky E2E question")
assert(checkForQuestionMarkers("CI pipeline failure screenshots") == true, "CI automation marker")
assert(checkForQuestionMarkers("storage state and browser context setup") == true, "Playwright auth/isolation marker")
assert(checkForQuestionMarkers("getByRole with web-first assertions") == true, "Playwright locator/assertion marker")
assert(checkForQuestionMarkers("page.route and HAR mocking") == true, "Playwright network marker")
assert(checkForQuestionMarkers("workers sharding retries") == true, "Playwright CI scale marker")
assert(checkForQuestionMarkers("Next, CI/CD") == true, "Short CI/CD topic prompt is protected")
assert(checkForQuestionMarkers("Accessibility testing and WCAG checks") == true, "Accessibility testing topic prompt is protected")
assert(checkForQuestionMarkers("Cross-browser testing strategy") == true, "Cross-browser testing topic prompt is protected")
assert(checkForQuestionMarkers("Could you walk through how you set up storage state for authenticated Playwright tests") == true, "Could-you-walk-through request is protected")
assert(checkForQuestionMarkers("Walk us through your page object model in Playwright") == true, "Walk-us-through interview request is protected")
assert(checkForQuestionMarkers("Let's discuss the last project you worked on") == true, "Let's-discuss project request is protected")
assert(checkForQuestionMarkers("Give us a quick overview of your most recent project") == true, "Project overview opener is protected")
assert(checkForQuestionMarkers("Talk me through your approach to flaky test triage") == true, "Talk-me-through request is protected")
assert(checkForQuestionMarkers("Could you briefly introduce yourself and your current role") == true, "Self-introduction request without question mark is protected")
assert(checkForQuestionMarkers("Please introduce yourself and your testing background") == true, "Please-introduce opening prompt is protected")
assert(checkForQuestionMarkers("Can we start with your introduction") == true, "Contentful can-we-start introduction prompt is protected")
assert(checkForQuestionMarkers("Could you help me understand how you handle flaky tests in CI") == true, "Help-me-understand interviewer request is protected")
assert(checkForQuestionMarkers("What is RAG and CAG?") == true, "RAG/CAG AI question is protected")
assert(checkForQuestionMarkers("Let's move on") == false, "Move-on transition is not promoted")
assert(checkForQuestionMarkers("I have 5 years of experience") == false, "Statement")
assert(checkForQuestionMarkers("The system handles 10k requests per second") == false, "Technical statement")
assert(checkForQuestionMarkers("какво е хеш таблица") == true, "Bulgarian question")
assert(checkForQuestionMarkers("Раскажи ми, квоя, хешмапа.") == true, "Bulgarian hash map transcription")
assert(checkForQuestionMarkers("Раскажи ми за ООП") == true, "Russian-style Bulgarian tell-me transcription")
assert(checkForQuestionMarkers("Добре, а какво е, hash code?") == true, "Mixed Bulgarian hashCode question")
assert(checkForQuestionMarkers("ОП, в принципе, знаеш.") == true, "Bulgarian/Russian-ish OOP transcription")
assert(checkForQuestionMarkers("wie funktioniert Garbage Collection") == true, "German question")
assert(checkForQuestionMarkers("comment fonctionne le garbage collector") == true, "French question")

section("questionSignal")
let edgeCaseFollowUp = questionSignal(for: "edge cases", lastTopic: "hashMap")
assert(edgeCaseFollowUp.protectsFromSkip == true, "Short contextual follow-up is protected")
assert(edgeCaseFollowUp.isFollowUp == true, "Short contextual follow-up is marked as follow-up")
assert(questionSignal(for: "complexity", lastTopic: "playwright").protectsFromSkip == true, "Complexity follow-up is protected with prior topic")
assert(questionSignal(for: "what about retries", lastTopic: "playwright").protectsFromSkip == true, "What-about follow-up is protected")
assert(questionSignal(for: "Can you elaborate?", lastTopic: nil).topicHint == "followUp", "Vague elaborate request gets follow-up topic hint")
assert(questionSignal(for: "What else?", lastTopic: nil).topicHint == "followUp", "What else gets follow-up topic hint")
assert(questionSignal(for: "HashMap vs HashSet", lastTopic: nil).protectsFromSkip == true, "Comparison topic mention is protected")
assert(questionSignal(for: "What is the", lastTopic: nil).protectsFromSkip == false, "Bare incomplete stem is not promoted")
assert(questionSignal(for: "What is the", lastTopic: nil).isBareIncomplete == true, "Bare incomplete stem is recognized")
let incompleteComparisonSignal = questionSignal(for: "Can you explain the difference between", lastTopic: nil)
assert(incompleteComparisonSignal.protectsFromSkip == false, "Incomplete comparison request is not promoted")
assert(incompleteComparisonSignal.isBareIncomplete == true, "Incomplete comparison request is recognized")
assert(questionSignal(for: "Can you explain the difference between TCP and UDP", lastTopic: nil).protectsFromSkip == true, "Complete comparison request stays protected")
assert(questionSignal(for: "I have experience with microservices", lastTopic: nil).protectsFromSkip == false, "Candidate statement is not promoted")
let candidateRetryExplanationSignal = questionSignal(for: "I used retries to stabilize flaky Playwright tests", lastTopic: nil)
assert(candidateRetryExplanationSignal.protectsFromSkip == false, "First-person retry explanation is not promoted")
assert(shouldVetoQuestionAsCandidateStatement("I used retries to stabilize flaky Playwright tests", signal: candidateRetryExplanationSignal) == true, "First-person retry explanation is vetoed")
let candidateConfirmationSignal = questionSignal(for: "I used Playwright retries to stabilize flaky tests, right?", lastTopic: nil)
assert(candidateConfirmationSignal.protectsFromSkip == true, "Candidate confirmation can still have a strong question-mark signal")
assert(shouldVetoQuestionAsCandidateStatement("I used Playwright retries to stabilize flaky tests, right?", signal: candidateConfirmationSignal) == true, "First-person confirmation question is still vetoed")
assert(shouldTreatLocalSignalAsClearQuestion("I used Playwright retries to stabilize flaky tests, right?", signal: candidateConfirmationSignal) == false, "Candidate confirmation cannot locally override a non-question classification")
assert(questionSignal(for: "retries", lastTopic: "playwright").protectsFromSkip == true, "Short retry follow-up stays protected with prior context")
assert(questionSignal(for: "I would like to know what exactly you're doing in testing", lastTopic: nil).protectsFromSkip == true, "Interviewer would-like-to-know request is protected")
assert(shouldVetoQuestionAsCandidateStatement("I would like to know what exactly you're doing in testing", signal: questionSignal(for: "I would like to know what exactly you're doing in testing", lastTopic: nil)) == false, "Interviewer first-person request is not vetoed")
assert(shouldTreatLocalSignalAsClearQuestion("I would like to know what exactly you're doing in testing", signal: questionSignal(for: "I would like to know what exactly you're doing in testing", lastTopic: nil)) == true, "Interviewer first-person request can still locally override weak classification")
assert(shouldVetoQuestionAsCandidateStatement("I have experience with Playwright locators and fixtures", signal: questionSignal(for: "I have experience with Playwright locators and fixtures", lastTopic: nil)) == true, "First-person candidate explanation is vetoed")
assert(shouldVetoQuestionAsCandidateStatement("Can you explain Playwright locators and fixtures?", signal: questionSignal(for: "Can you explain Playwright locators and fixtures?", lastTopic: nil)) == false, "Real interviewer request is not vetoed")
assert(shouldTreatLocalSignalAsClearQuestion("Can you explain Playwright locators and fixtures?", signal: questionSignal(for: "Can you explain Playwright locators and fixtures?", lastTopic: nil)) == true, "Real interviewer request remains a clear local question")
assert(questionSignal(for: "I can walk through how I set up storage state in Playwright", lastTopic: nil).protectsFromSkip == false, "First-person walk-through statement is not promoted")
let candidateExplainStatementSignal = questionSignal(for: "I can explain Playwright locators and fixtures with examples from my project", lastTopic: nil)
assert(candidateExplainStatementSignal.protectsFromSkip == true, "First-person explain statement can carry strong local request markers")
assert(shouldVetoQuestionAsCandidateStatement("I can explain Playwright locators and fixtures with examples from my project", signal: candidateExplainStatementSignal) == true, "First-person explain statement is still vetoed")
let candidateWillExplainSignal = questionSignal(for: "I will explain how I used Playwright fixtures in my current project", lastTopic: nil)
assert(candidateWillExplainSignal.protectsFromSkip == true, "First-person future explain statement can carry strong local request markers")
assert(shouldVetoQuestionAsCandidateStatement("I will explain how I used Playwright fixtures in my current project", signal: candidateWillExplainSignal) == true, "First-person future explain statement is vetoed")
assert(shouldTreatLocalSignalAsClearQuestion("I will explain how I used Playwright fixtures in my current project", signal: candidateWillExplainSignal) == false, "First-person future explain statement cannot locally override a non-question classification")
let candidateLetMeExplainSignal = questionSignal(for: "Let me explain how I used Playwright fixtures in my current project", lastTopic: nil)
assert(candidateLetMeExplainSignal.protectsFromSkip == true, "Let-me-explain answer statement can carry strong local request markers")
assert(shouldVetoQuestionAsCandidateStatement("Let me explain how I used Playwright fixtures in my current project", signal: candidateLetMeExplainSignal) == true, "Let-me-explain answer statement is vetoed")
assert(shouldTreatLocalSignalAsClearQuestion("Let me explain how I used Playwright fixtures in my current project", signal: candidateLetMeExplainSignal) == false, "Let-me-explain answer statement cannot locally override a non-question classification")
let interviewerLetMeExplainSignal = questionSignal(for: "Let me explain the setup, how would you test this API flow?", lastTopic: nil)
assert(interviewerLetMeExplainSignal.protectsFromSkip == true, "Interviewer let-me-explain preface with real question has local signal")
assert(shouldVetoQuestionAsCandidateStatement("Let me explain the setup, how would you test this API flow?", signal: interviewerLetMeExplainSignal) == false, "Interviewer let-me-explain preface with real question is not vetoed")
assert(shouldTreatLocalSignalAsClearQuestion("Let me explain the setup, how would you test this API flow?", signal: interviewerLetMeExplainSignal) == true, "Interviewer let-me-explain preface can locally override weak classification")
assert(technicalQuestionTokens(in: normalizedQuestionText("Can you explain HashMap?")) != technicalQuestionTokens(in: normalizedQuestionText("Can you explain HashSet?")), "Topic tokens distinguish similar questions")
assert(technicalQuestionTokens(in: normalizedQuestionText("Is the shared screen visible?")).contains("networkMocking") == false, "Shared screen setup does not trigger HAR network token")
assert(technicalQuestionTokens(in: normalizedQuestionText("HAR mocking")).contains("networkMocking") == true, "Standalone HAR still maps to network mocking")
let cicdPromptSignal = questionSignal(for: "Next, CI/CD", lastTopic: nil)
assert(cicdPromptSignal.protectsFromSkip == true, "Short CI/CD prompt has enough local signal")
assert(cicdPromptSignal.topicHint == "cicd", "Short CI/CD prompt gets CI/CD topic hint")
let accessibilityPromptSignal = questionSignal(for: "Accessibility testing and WCAG checks", lastTopic: nil)
assert(accessibilityPromptSignal.protectsFromSkip == true, "Accessibility prompt has enough local signal")
assert(accessibilityPromptSignal.topicHint == "accessibilityTesting", "Accessibility prompt gets accessibility topic hint")
let candidateAccessibilityStatementSignal = questionSignal(for: "I used WCAG checks in my last project", lastTopic: nil)
assert(candidateAccessibilityStatementSignal.protectsFromSkip == false, "First-person accessibility statement is not promoted")
assert(shouldVetoQuestionAsCandidateStatement("I used WCAG checks in my last project", signal: candidateAccessibilityStatementSignal) == true, "First-person accessibility statement is vetoed")
let crossBrowserPromptSignal = questionSignal(for: "Cross-browser testing strategy", lastTopic: nil)
assert(crossBrowserPromptSignal.protectsFromSkip == true, "Cross-browser prompt has enough local signal")
assert(crossBrowserPromptSignal.topicHint == "crossBrowserTesting", "Cross-browser prompt gets cross-browser topic hint")
let selfIntroSignal = questionSignal(for: "Could you briefly introduce yourself and your current role", lastTopic: nil)
assert(selfIntroSignal.protectsFromSkip == true, "Self-introduction prompt has enough local signal")
assert(selfIntroSignal.topicHint == "personal", "Self-introduction prompt gets personal topic hint")
assert(shouldTreatLocalSignalAsClearQuestion("Could you briefly introduce yourself and your current role", signal: selfIntroSignal) == true, "Self-introduction request can locally override weak classification")
let projectOverviewSignal = questionSignal(for: "Give us a quick overview of your most recent project", lastTopic: nil)
assert(projectOverviewSignal.protectsFromSkip == true, "Project overview opener has enough local signal")
assert(projectOverviewSignal.topicHint == "personal", "Project overview opener gets personal topic hint")
assert(shouldTreatLocalSignalAsClearQuestion("Give us a quick overview of your most recent project", signal: projectOverviewSignal) == true, "Project overview opener can locally override weak classification")
let helpUnderstandSignal = questionSignal(for: "Could you help me understand how you handle flaky tests in CI", lastTopic: nil)
assert(helpUnderstandSignal.protectsFromSkip == true, "Help-me-understand request has enough local signal")
assert(shouldTreatLocalSignalAsClearQuestion("Could you help me understand how you handle flaky tests in CI", signal: helpUnderstandSignal) == true, "Help-me-understand request can locally override weak classification")
let repairedRagCagQuestion = repairNoisyTechnicalTranscript("Okay, tell me what is Rack system, Rack or CAC?")
assert(repairedRagCagQuestion == "Okay, tell me what is RAG system, RAG or CAG?", "Noisy AI acronym transcript is repaired in AI context")
assert(repairNoisyTechnicalTranscript("Okay, tell me what is Rack system, Rack or CAC?", favorsAIAcronyms: false) == "Okay, tell me what is Rack system, Rack or CAC?", "Noisy AI acronym repair is disabled outside AI context")
assert(repairNoisyTechnicalTranscript("What is a rack server?", favorsAIAcronyms: true) == "What is a rack server?", "Rack server is not rewritten to RAG")
let ragCagSignal = questionSignal(for: repairedRagCagQuestion, lastTopic: nil)
assert(ragCagSignal.protectsFromSkip == true, "Repaired RAG/CAG question has enough local signal")
assert(ragCagSignal.topicHint == "ragCag", "Repaired RAG/CAG question gets combined topic hint")

section("correctedTopic")
assert(correctedTopic(for: "Раскажи ми, квоя, хешмапа.", classifiedTopic: "unknown") == "hashMap", "Bulgarian hash map topic correction")
assert(correctedTopic(for: "Добре, а какво е, hash code?", classifiedTopic: "algorithms") == "hashCode", "Mixed hash code topic correction")
assert(correctedTopic(for: "ОП, в принципе, знаеш.", classifiedTopic: "unknown") == "oop", "OOP short transcription topic correction")
assert(correctedTopic(for: "Can you elaborate?", classifiedTopic: "unknown") == "followUp", "Unknown vague elaborate topic is corrected to followUp")
assert(correctedTopic(for: "What else?", classifiedTopic: "unknown") == "followUp", "Unknown what-else topic is corrected to followUp")
assert(correctedTopic(for: "Next, CI/CD", classifiedTopic: "unknown") == "cicd", "Unknown short CI/CD prompt is corrected to CI/CD")
assert(correctedTopic(for: "Accessibility testing and WCAG checks", classifiedTopic: "unknown") == "accessibilityTesting", "Unknown accessibility prompt is corrected to accessibility testing")
assert(correctedTopic(for: "Cross-browser testing strategy", classifiedTopic: "unknown") == "crossBrowserTesting", "Unknown cross-browser prompt is corrected to cross-browser testing")
assert(correctedTopic(for: "Could you briefly introduce yourself and your current role", classifiedTopic: "unknown") == "personal", "Unknown self-introduction prompt is corrected to personal")
assert(correctedTopic(for: "Give us a quick overview of your most recent project", classifiedTopic: "unknown") == "personal", "Unknown project overview opener is corrected to personal")
assert(correctedTopic(for: "Playwright fixtures", classifiedTopic: "playwrightFixtures") == "playwrightFixtures", "Keeps classified topic")
// Newly recognized common interview topics resolve locally (so the fast path can answer them).
assert(correctedTopic(for: "What is an interface?", classifiedTopic: "unknown") == "interface", "Unknown interface prompt resolves to interface")
assert(correctedTopic(for: "How does caching work?", classifiedTopic: "unknown") == "caching", "Unknown caching prompt resolves to caching")
assert(correctedTopic(for: "Explain Java generics", classifiedTopic: "none") == "generics", "Unknown generics prompt resolves to generics")
assert(correctedTopic(for: "What is a volatile variable?", classifiedTopic: "unknown") == "volatile", "Unknown volatile prompt resolves to volatile")
assert(correctedTopic(for: "How do you handle exceptions?", classifiedTopic: "unknown") == "exceptions", "Unknown exceptions prompt resolves to exceptions")
assert(correctedTopic(for: "Tell me about Redis", classifiedTopic: "redis") == "redis", "Keeps concrete redis topic")
assert(correctedTopic(for: repairedRagCagQuestion, classifiedTopic: "unknown") == "ragCag", "Noisy RAG/CAG question resolves to combined topic after repair")
assert(correctedTopic(for: "What is RAG?", classifiedTopic: "unknown") == "rag", "RAG question resolves to rag")
assert(correctedTopic(for: "What is CAG?", classifiedTopic: "unknown") == "cag", "CAG question resolves to cag")

section("provisionalAnswerTopic")
// Fires for clear, complete, concrete-topic interviewer questions -> direct answer path.
assert(provisionalAnswerTopic(for: "What is polymorphism?", lastTopic: nil) != nil, "Clear concrete technical question uses fast path")
assert(provisionalAnswerTopic(for: "Explain hash maps", lastTopic: nil) == "hashMap", "Hash map request resolves a concrete topic for the fast path")
assert(provisionalAnswerTopic(for: "How does a hash map handle collisions?", lastTopic: nil) == "hashMap", "Hash map how-question uses fast path")
assert(provisionalAnswerTopic(for: "Раскажи ми за хешмапа.", lastTopic: nil) == "hashMap", "Bulgarian hash map question uses fast path")
assert(provisionalAnswerTopic(for: "Какво е ООП?", lastTopic: nil) == "oop", "Bulgarian OOP question uses fast path")
assert(provisionalAnswerTopic(for: "What about flaky tests?", lastTopic: "testStrategy") == "flakyTests", "Concrete technical follow-up uses fast path")
assert(provisionalAnswerTopic(for: repairedRagCagQuestion, lastTopic: nil) == "ragCag", "Repaired RAG/CAG question uses fast path")
assert(provisionalAnswerTopic(for: "What is RAG and CAG?", lastTopic: nil) == "ragCag", "Clear RAG/CAG comparison uses fast path")

// Defers to the authoritative model path (incomplete, personal, vague, candidate, or no concrete topic).
assert(provisionalAnswerTopic(for: "What is the", lastTopic: nil) == nil, "Bare incomplete stem defers to model")
assert(provisionalAnswerTopic(for: "Tell me about yourself", lastTopic: nil, hasBackground: false) == nil, "Personal/background question defers to model when no background is available")
assert(provisionalAnswerTopic(for: "Can you walk me through your last project?", lastTopic: nil, hasBackground: false) == nil, "Project question defers to model when no background is available")
assert(provisionalAnswerTopic(for: "Tell me more", lastTopic: nil) == nil, "Orphan vague follow-up with no prior topic defers to model")
assert(provisionalAnswerTopic(for: "I have experience with hash maps and used them in production", lastTopic: nil) == nil, "Candidate statement is not fast-pathed")
assert(provisionalAnswerTopic(for: "Can you hear me?", lastTopic: nil) == nil, "Setup-check question without a concrete topic defers to model")
assert(provisionalAnswerTopic(for: "So, anyway, where do we start with?", lastTopic: nil) == nil, "Vague question without a concrete local topic defers to model")
assert(provisionalAnswerTopic(for: "and that's important for me to know. Okay.", lastTopic: "teststrategy") == nil, "Interviewer statement is not fast-pathed")

section("provisionalAnswerTopic follow-up reuse")
// LATENCY: vague follow-ups ("tell me more", "elaborate", "go deeper", "what else")
// carry no new topic, but with a concrete prior topic they now reuse it and take the
// direct answer path instead of waiting on the slow Haiku classify-then-answer path.
// Follow-ups are the most common per-interview utterance, so
// this moves a large share of real turns off the slow path.
assert(provisionalAnswerTopic(for: "Tell me more", lastTopic: "oop") == "oop", "Vague follow-up reuses the concrete prior topic for the fast path")
assert(provisionalAnswerTopic(for: "Can you elaborate?", lastTopic: "hashMap") == "hashMap", "Elaborate follow-up reuses the prior topic")
assert(provisionalAnswerTopic(for: "Elaborate", lastTopic: "binarySearch") == "binarySearch", "Bare elaborate follow-up reuses the prior topic")
assert(provisionalAnswerTopic(for: "Go deeper", lastTopic: "playwright") == "playwright", "Go-deeper follow-up reuses the prior topic")
assert(provisionalAnswerTopic(for: "What else?", lastTopic: "testStrategy") == "testStrategy", "What-else follow-up reuses the prior topic")
assert(provisionalAnswerTopic(for: "Anything else?", lastTopic: "docker") == "docker", "Anything-else follow-up reuses the prior topic")
assert(provisionalAnswerTopic(for: "More details", lastTopic: "kafka") == "kafka", "More-details follow-up reuses the prior topic")
// Prior topic casing is preserved so the fast model receives the same topic slug.
assert(provisionalAnswerTopic(for: "Tell me more", lastTopic: "loadBalancing") == "loadBalancing", "Prior topic casing is preserved for the fast path")
// Safeguards stay intact.
assert(provisionalAnswerTopic(for: "Tell me more", lastTopic: nil) == nil, "Orphan follow-up with no prior topic still defers")
assert(provisionalAnswerTopic(for: "Tell me more", lastTopic: "followUp") == nil, "Follow-up whose prior topic is itself vague defers")
assert(provisionalAnswerTopic(for: "Tell me more", lastTopic: "unknown") == nil, "Follow-up with an unknown prior topic defers")
assert(provisionalAnswerTopic(for: "Tell me more", lastTopic: "personal") == nil, "Follow-up on a background-dependent prior topic defers to the model path")
// A concrete technical follow-up still resolves its own named topic, not the prior one.
assert(provisionalAnswerTopic(for: "What about flaky tests?", lastTopic: "oop") == "flakyTests", "Concrete follow-up keeps its own named topic over the prior one")
// Candidate speech is never promoted into a follow-up answer, even with a prior topic.
assert(provisionalAnswerTopic(for: "I have used Redis for caching in production", lastTopic: "redis") == nil, "Candidate statement is not fast-pathed even with a prior topic")

section("provisionalAnswerTopic topicless question reuse")
// LATENCY: the slowest real-interview turns are clear questions ("?" or a direct what/how/
// where/why pattern) that local detection cannot map to a named topic — e.g. "where do we
// start with?", "what should we be expecting?". These used to always wait on the slow Haiku
// classify-then-answer round-trip (observed 800-2400ms to first visible text). With a concrete
// prior topic they now reuse it and take the direct answer path, matching what the slow
// path already does (unknown topic + prior context -> follow-up on the prior topic). The fast
// model still gets the verbatim question, so the prior-topic hint only frames the answer.
assert(provisionalAnswerTopic(for: "So, anyway, where do we start with?", lastTopic: "testStrategy") == "testStrategy", "Topicless clear question reuses the concrete prior topic for the fast path")
assert(provisionalAnswerTopic(for: "What should we be expecting?", lastTopic: "testStrategy") == "testStrategy", "Topicless expectation question reuses the prior topic")
assert(provisionalAnswerTopic(for: "Where do we go from here?", lastTopic: "oop") == "oop", "Topicless direction question reuses the prior topic")
assert(provisionalAnswerTopic(for: "How would you approach this?", lastTopic: "systemDesign") == "systemDesign", "Topicless how-question reuses the prior topic")
// Prior topic casing/slug is passed through unchanged to the fast model.
assert(provisionalAnswerTopic(for: "So where do we start?", lastTopic: "loadBalancing") == "loadBalancing", "Prior topic slug is preserved for topicless questions")
// Safeguards stay intact.
assert(provisionalAnswerTopic(for: "So, anyway, where do we start with?", lastTopic: nil) == nil, "Topicless question with no prior topic still defers to the model")
assert(provisionalAnswerTopic(for: "Where do we go from here?", lastTopic: "unknown") == nil, "Topicless question whose prior topic is itself unknown defers")
assert(provisionalAnswerTopic(for: "Where do we go from here?", lastTopic: "followUp") == nil, "Topicless question whose prior topic is itself vague defers")
assert(provisionalAnswerTopic(for: "Where do we go from here?", lastTopic: "personal") == nil, "Topicless question on a background-dependent prior topic defers to the model path")
assert(provisionalAnswerTopic(for: "What is the", lastTopic: "testStrategy") == nil, "Bare incomplete stem still defers even with a prior topic")
// Candidate speech that carries a real direct-question marker (score >= 3) is still vetoed
// as a first-person explanation, not fast-pathed onto the prior topic.
assert(provisionalAnswerTopic(for: "I can explain what is happening with our tests", lastTopic: "testStrategy") == nil, "Candidate ability lead-in with a direct-question marker is vetoed, not fast-pathed")
// A question with its own concrete topic keeps that topic; it does not collapse onto the prior one.
assert(provisionalAnswerTopic(for: "What is a hash map?", lastTopic: "testStrategy") == "hashMap", "Concrete question keeps its own topic instead of the prior one")

// Newly recognized common topics now take the direct answer path instead of waiting on the model.
assert(provisionalAnswerTopic(for: "What is an interface?", lastTopic: nil) == "interface", "Interface question uses fast path")
assert(provisionalAnswerTopic(for: "What is a lambda expression?", lastTopic: nil) == "lambda", "Lambda question uses fast path")
assert(provisionalAnswerTopic(for: "How do you handle exceptions in Java?", lastTopic: nil) == "exceptions", "Exceptions question uses fast path")
assert(provisionalAnswerTopic(for: "How does caching improve performance?", lastTopic: nil) == "caching", "Caching question uses fast path")
assert(provisionalAnswerTopic(for: "Explain TypeScript generics", lastTopic: nil) == "generics", "TypeScript generics request uses fast path")
assert(provisionalAnswerTopic(for: "What is a volatile field used for?", lastTopic: nil) == "volatile", "Volatile question uses fast path")
assert(provisionalAnswerTopic(for: "How does load balancing work?", lastTopic: nil) == "loadBalancing", "Load balancing question uses fast path")
// Safeguards stay intact: candidate statements that merely mention these topics still defer to the model.
assert(provisionalAnswerTopic(for: "I have used Redis for caching in production", lastTopic: nil) == nil, "Candidate statement mentioning new topics is not fast-pathed")
assert(provisionalAnswerTopic(for: "I usually rely on caching to speed up queries", lastTopic: nil) == nil, "First-person caching explanation is not fast-pathed")
assert(provisionalAnswerTopic(for: "What is the", lastTopic: nil) == nil, "Bare incomplete stem still defers even with broader topics")

// Personal / background openers are the most common slow-path case: with a background
// available they now take the direct answer path; without one they still defer so we
// never invent experience the candidate does not have.
assert(provisionalAnswerTopic(for: "Tell me about yourself", lastTopic: nil, hasBackground: true) == "personal", "Personal opener uses fast path when background is available")
assert(provisionalAnswerTopic(for: "Tell me about your background", lastTopic: nil, hasBackground: true) == "personal", "Background question uses fast path when background is available")
assert(provisionalAnswerTopic(for: "Can you tell me about your experience?", lastTopic: nil, hasBackground: true) == "personal", "Experience question uses fast path when background is available")
assert(provisionalAnswerTopic(for: "Can you walk me through your last project?", lastTopic: nil, hasBackground: true) == "personal", "Project walkthrough uses fast path when background is available")
assert(provisionalAnswerTopic(for: "Please introduce yourself", lastTopic: nil, hasBackground: true) == "personal", "Introduction request uses fast path when background is available")
assert(provisionalAnswerTopic(for: "Tell me about yourself", lastTopic: nil, hasBackground: false) == nil, "Personal opener still defers without a background")
assert(provisionalAnswerTopic(for: "Can you tell me about your experience?", lastTopic: nil, hasBackground: false) == nil, "Experience question still defers without a background")
// Background availability must not relax the question-detection safeguards.
assert(provisionalAnswerTopic(for: "I have five years of experience with test automation", lastTopic: nil, hasBackground: true) == nil, "Candidate describing their own experience is not fast-pathed even with a background")
assert(provisionalAnswerTopic(for: "My background is in backend development", lastTopic: nil, hasBackground: true) == nil, "Candidate first-person background statement is not fast-pathed even with a background")
assert(provisionalAnswerTopic(for: "Tell me about", lastTopic: nil, hasBackground: true) == nil, "Bare incomplete personal stem still defers even with a background")
// A concrete technical topic is unaffected by the background flag.
assert(provisionalAnswerTopic(for: "What is polymorphism?", lastTopic: nil, hasBackground: true) == "polymorphism", "Concrete technical question uses fast path regardless of background")

section("technicalQuestionTokens word-boundary tokens")
// High-frequency interview topics whose names are short/ambiguous. Each clear question
// now resolves a concrete topic locally and takes the direct answer path instead of
// waiting on the slower Haiku classification path.
assert(provisionalAnswerTopic(for: "What is AWS?", lastTopic: nil) == "aws", "AWS question uses fast path")
assert(provisionalAnswerTopic(for: "How do you use Git for version control?", lastTopic: nil) == "git", "Git question uses fast path")
assert(provisionalAnswerTopic(for: "How does CSS specificity work?", lastTopic: nil) == "css", "CSS question uses fast path")
assert(provisionalAnswerTopic(for: "How does the DOM work?", lastTopic: nil) == "dom", "DOM question uses fast path")
assert(provisionalAnswerTopic(for: "What is an ORM?", lastTopic: nil) == "orm", "ORM question uses fast path")
assert(provisionalAnswerTopic(for: "What is a JWT?", lastTopic: nil) == "jwt", "JWT question uses fast path")
assert(provisionalAnswerTopic(for: "What is GraphQL?", lastTopic: nil) == "graphql", "GraphQL question uses fast path")
assert(provisionalAnswerTopic(for: "How does OAuth work?", lastTopic: nil) == "oauth", "OAuth question uses fast path")
assert(provisionalAnswerTopic(for: "What is Kafka used for?", lastTopic: nil) == "kafka", "Kafka question uses fast path")
assert(provisionalAnswerTopic(for: "How do WebSockets work?", lastTopic: nil) == "websockets", "WebSocket question uses fast path")
assert(provisionalAnswerTopic(for: "What is middleware?", lastTopic: nil) == "middleware", "Middleware question uses fast path")
assert(provisionalAnswerTopic(for: "Can you explain the difference between TCP and UDP?", lastTopic: nil) == "tcp", "TCP/UDP comparison uses fast path")

// Direct token membership: the new tokens are detected (positives).
assert(technicalQuestionTokens(in: "what is aws").contains("aws"), "aws token detected as a word")
assert(technicalQuestionTokens(in: "the dom tree updates").contains("dom"), "dom token detected as a word")
assert(technicalQuestionTokens(in: "we use an orm here").contains("orm"), "orm token detected as a word")
assert(technicalQuestionTokens(in: "set up the git remote").contains("git"), "git token detected as a word")

// Word-boundary safeguards: short tokens must NOT fire inside unrelated words, so the
// fast path never misroutes ordinary speech onto a wrong topic.
assert(!technicalQuestionTokens(in: "how does caching improve performance").contains("orm"), "orm does not match inside 'performance'")
assert(!technicalQuestionTokens(in: "the platform transforms the format").contains("orm"), "orm does not match inside 'platform/transforms/format'")
assert(!technicalQuestionTokens(in: "i had a random thought about freedom").contains("dom"), "dom does not match inside 'random/freedom'")
assert(!technicalQuestionTokens(in: "what is your domain model").contains("dom"), "dom does not match inside 'domain'")
assert(!technicalQuestionTokens(in: "there were many flaws in the draws").contains("aws"), "aws does not match inside 'flaws/draws'")
assert(!technicalQuestionTokens(in: "that is a legitimate concern about github").contains("git"), "git does not match inside 'legitimate/github'")
// Existing topic detection is unchanged: a real token still wins, not a substring match.
assert(provisionalAnswerTopic(for: "How does caching improve performance?", lastTopic: nil) == "caching", "Real token still resolves the topic (caching, not a 'performance' substring)")

// Safeguards stay intact: candidate statements that merely mention these topics still defer.
assert(provisionalAnswerTopic(for: "I use AWS Lambda every day at work", lastTopic: nil) == nil, "Candidate statement mentioning AWS is not fast-pathed")
assert(provisionalAnswerTopic(for: "We use Kafka for our event pipeline", lastTopic: nil) == nil, "Candidate statement mentioning Kafka is not fast-pathed")

section("fast-path latency routing for QA/SDET + backend topics")
// LATENCY: each clear question below now resolves a concrete topic locally, so it takes
// the direct answer path instead of the Haiku classify+answer path. That moves visible
// answer latency off the slow classifier path.
assert(provisionalAnswerTopic(for: "What is the test pyramid?", lastTopic: nil) == "testPyramid", "Test pyramid question uses fast path")
assert(provisionalAnswerTopic(for: "What is a good test strategy?", lastTopic: nil) == "testStrategy", "Test strategy question uses fast path")
assert(provisionalAnswerTopic(for: "How do you do boundary value analysis?", lastTopic: nil) == "boundaryValue", "Boundary value question uses fast path")
assert(provisionalAnswerTopic(for: "What is equivalence partitioning?", lastTopic: nil) == "equivalencePartitioning", "Equivalence partitioning question uses fast path")
assert(provisionalAnswerTopic(for: "What is smoke testing?", lastTopic: nil) == "smokeTesting", "Smoke testing question uses fast path")
assert(provisionalAnswerTopic(for: "What is a sanity check?", lastTopic: nil) == "sanityTesting", "Sanity check question uses fast path")
assert(provisionalAnswerTopic(for: "What is Cucumber?", lastTopic: nil) == "bdd", "Cucumber question uses fast path")
assert(provisionalAnswerTopic(for: "How does Gherkin syntax work?", lastTopic: nil) == "bdd", "Gherkin question uses fast path")
assert(provisionalAnswerTopic(for: "What is behavior driven development?", lastTopic: nil) == "bdd", "BDD question uses fast path")
assert(provisionalAnswerTopic(for: "What is REST Assured?", lastTopic: nil) == "apiTesting", "REST Assured question uses fast path")
assert(provisionalAnswerTopic(for: "What is a soft assertion?", lastTopic: nil) == "assertions", "Soft assertion question uses fast path")
assert(provisionalAnswerTopic(for: "How do you run tests in headless mode?", lastTopic: nil) == "headless", "Headless question uses fast path")
assert(provisionalAnswerTopic(for: "When should you use an XPath locator?", lastTopic: nil) == "playwrightLocators", "XPath question maps to locators and uses fast path")
assert(provisionalAnswerTopic(for: "What is load testing?", lastTopic: nil) == "performanceTesting", "Load testing question uses fast path")
assert(provisionalAnswerTopic(for: "How does stress testing work?", lastTopic: nil) == "performanceTesting", "Stress testing question uses fast path")
assert(provisionalAnswerTopic(for: "How does indexing speed up queries?", lastTopic: nil) == "indexing", "Indexing question uses fast path")
assert(provisionalAnswerTopic(for: "How do you ensure transaction atomicity?", lastTopic: nil) == "transactions", "Transaction question uses fast path")
assert(provisionalAnswerTopic(for: "What are ACID properties?", lastTopic: nil) == "transactions", "ACID question uses fast path (acid matched on a word boundary)")
assert(provisionalAnswerTopic(for: "What is a message queue?", lastTopic: nil) == "messageQueue", "Message queue question uses fast path")
assert(provisionalAnswerTopic(for: "How does rate limiting work?", lastTopic: nil) == "rateLimiting", "Rate limiting question uses fast path")
assert(provisionalAnswerTopic(for: "What causes a memory leak?", lastTopic: nil) == "memoryLeak", "Memory leak question uses fast path")
assert(provisionalAnswerTopic(for: "What is the CAP theorem?", lastTopic: nil) == "capTheorem", "CAP theorem question uses fast path")
assert(provisionalAnswerTopic(for: "What does idempotent mean?", lastTopic: nil) == "idempotency", "Idempotency question uses fast path")
assert(provisionalAnswerTopic(for: "Why is normalization important?", lastTopic: nil) == "normalization", "Normalization question uses fast path")

// Direct token membership (positives) for the new tokens.
assert(technicalQuestionTokens(in: "explain the test pyramid").contains("testPyramid"), "test pyramid token detected")
assert(technicalQuestionTokens(in: "we write bdd specs in cucumber").contains("bdd"), "cucumber maps to bdd token")
assert(technicalQuestionTokens(in: "use a headless browser").contains("headless"), "headless token detected")
assert(technicalQuestionTokens(in: "what are acid properties").contains("transactions"), "acid (word) maps to transactions token")

// Word-boundary safeguard: "acid" must NOT fire inside unrelated words.
assert(!technicalQuestionTokens(in: "the placid lake looked acidic").contains("transactions"), "acid does not match inside 'placid/acidic'")

// Safeguards stay intact: candidate statements that merely mention the new topics still defer.
assert(provisionalAnswerTopic(for: "I usually start with smoke testing before the full regression suite", lastTopic: nil) == nil, "Candidate statement mentioning smoke testing is not fast-pathed")
assert(provisionalAnswerTopic(for: "We rely on a message queue for async processing", lastTopic: nil) == nil, "Candidate statement mentioning message queue is not fast-pathed")
assert(provisionalAnswerTopic(for: "My test strategy is usually risk based", lastTopic: nil) == nil, "Candidate statement describing own test strategy is not fast-pathed")
assert(provisionalAnswerTopic(for: "I have set up rate limiting in production", lastTopic: nil) == nil, "Candidate statement mentioning rate limiting is not fast-pathed")

// Incomplete stems on the new topics still buffer (no premature fast-path answer).
assert(provisionalAnswerTopic(for: "What is the", lastTopic: nil) == nil, "Bare incomplete stem still defers with the new topics added")

section("fast-path latency routing for test-methodology fundamentals")
// LATENCY: unit/integration testing, TDD, BDD, and design patterns are among the most
// common interview openers but were absent from local detection, so clear questions about
// them fell through to the slow Haiku classify+answer path. They now resolve a concrete
// topic locally and take the direct answer path.
assert(provisionalAnswerTopic(for: "What is unit testing?", lastTopic: nil) == "unitTesting", "Unit testing question uses fast path")
assert(provisionalAnswerTopic(for: "What is integration testing?", lastTopic: nil) == "integrationTesting", "Integration testing question uses fast path")
assert(provisionalAnswerTopic(for: "What is TDD?", lastTopic: nil) == "tdd", "TDD abbreviation question uses fast path")
assert(provisionalAnswerTopic(for: "What is BDD?", lastTopic: nil) == "bdd", "BDD abbreviation question uses fast path")
assert(provisionalAnswerTopic(for: "Can you explain test driven development?", lastTopic: nil) == "tdd", "Test-driven development request uses fast path")
assert(provisionalAnswerTopic(for: "What is a design pattern?", lastTopic: nil) == "designPatterns", "Design pattern question uses fast path")
assert(provisionalAnswerTopic(for: "What is the difference between unit testing and integration testing?", lastTopic: nil) == "integrationTesting", "Unit-vs-integration comparison resolves a concrete topic for the fast path")

// Direct token membership (positives) for the new tokens.
assert(technicalQuestionTokens(in: "what is unit testing").contains("unitTesting"), "unit testing maps to unitTesting token")
assert(technicalQuestionTokens(in: "how do you write integration tests").contains("integrationTesting"), "integration tests maps to integrationTesting token")
assert(technicalQuestionTokens(in: "is tdd worth it").contains("tdd"), "standalone tdd maps to tdd token")
assert(technicalQuestionTokens(in: "what is bdd").contains("bdd"), "standalone bdd maps to bdd token")
assert(technicalQuestionTokens(in: "explain test driven development").contains("tdd"), "test driven maps to tdd token")
assert(technicalQuestionTokens(in: "what is a design pattern").contains("designPatterns"), "design pattern maps to designPatterns token")

// Word-boundary safeguard: the bare abbreviations "tdd"/"bdd" must NOT fire inside a longer
// alphanumeric run (they are guarded the same way as aws/git/orm/acid).
assert(!technicalQuestionTokens(in: "guttddist code").contains("tdd"), "tdd does not match inside an unrelated word")
assert(!technicalQuestionTokens(in: "the subdded value").contains("bdd"), "bdd does not match inside an unrelated word")

section("fast-path latency routing for core data structures and system design")
// LATENCY: queues, sorting, and system design are among the most common interview openers
// but were absent from local detection, so clear questions about them fell through to the
// slow Haiku classify+answer path. They now resolve a concrete topic locally and take the
// direct answer path.
assert(provisionalAnswerTopic(for: "What is a queue?", lastTopic: nil) == "queue", "Queue question uses fast path")
assert(provisionalAnswerTopic(for: "How does a queue work?", lastTopic: nil) == "queue", "Queue how-question uses fast path")
assert(provisionalAnswerTopic(for: "How does sorting work?", lastTopic: nil) == "sorting", "Sorting question uses fast path")
assert(provisionalAnswerTopic(for: "What are common sorting algorithms?", lastTopic: nil) == "sorting", "Sorting algorithms question uses fast path")
assert(provisionalAnswerTopic(for: "Can you walk me through a system design problem?", lastTopic: nil) == "systemDesign", "System design request uses fast path")
assert(provisionalAnswerTopic(for: "How would you approach system design here?", lastTopic: nil) == "systemDesign", "System design question uses fast path")

// Specificity: "message queue" stays the more specific messageQueue topic over bare "queue".
assert(provisionalAnswerTopic(for: "What is a message queue?", lastTopic: nil) == "messageQueue", "Message queue keeps the specific topic over bare queue")

// Direct token membership (positives) for the new tokens.
assert(technicalQuestionTokens(in: "what is a queue").contains("queue"), "queue token detected")
assert(technicalQuestionTokens(in: "how does sorting work").contains("sorting"), "sorting token detected")
assert(technicalQuestionTokens(in: "walk me through a system design problem").contains("systemDesign"), "system design maps to systemDesign token")
assert(technicalQuestionTokens(in: "what is a message queue").contains("messageQueue"), "message queue maps to messageQueue token")

// Safeguards stay intact: candidate statements that merely mention the new topics still defer.
assert(provisionalAnswerTopic(for: "I implemented a priority queue in my last project", lastTopic: nil) == nil, "Candidate statement mentioning a queue is not fast-pathed")
assert(provisionalAnswerTopic(for: "We did the system design for our platform last year", lastTopic: nil) == nil, "Candidate statement mentioning system design is not fast-pathed")
assert(provisionalAnswerTopic(for: "I usually rely on sorting to organize the results", lastTopic: nil) == nil, "Candidate statement mentioning sorting is not fast-pathed")

// Safeguards stay intact: a candidate describing their own practice still defers to the model
// path (score < 3 / candidate-statement veto) even though it names a fast-path topic.
assert(provisionalAnswerTopic(for: "I write unit tests for every feature", lastTopic: nil) == nil, "Candidate statement mentioning unit tests is not fast-pathed")
assert(provisionalAnswerTopic(for: "We follow TDD on our team", lastTopic: nil) == nil, "Candidate statement mentioning TDD is not fast-pathed")
assert(provisionalAnswerTopic(for: "My team uses design patterns heavily", lastTopic: nil) == nil, "Candidate statement mentioning design patterns is not fast-pathed")

// Vague follow-up on one of the new topics reuses the prior topic for the fast path.
assert(provisionalAnswerTopic(for: "Tell me more", lastTopic: "unitTesting") == "unitTesting", "Follow-up reuses a unitTesting prior topic for the fast path")

section("fast-path latency routing for arrays, DSA patterns, and concurrency")
// LATENCY: arrays are the single most common DSA interview topic, and the sliding-window /
// backtracking / memoization patterns plus core concurrency topics were
// absent from local detection, so clear questions about them fell through to the slow
// Haiku classify+answer path. They now resolve a concrete topic locally and take the
// direct answer path.
assert(provisionalAnswerTopic(for: "What is an array?", lastTopic: nil) == "array", "Array question uses fast path")
assert(provisionalAnswerTopic(for: "How do you reverse an array in place?", lastTopic: nil) == "array", "Array how-question uses fast path")
assert(provisionalAnswerTopic(for: "How does the sliding window pattern work?", lastTopic: nil) == "slidingWindow", "Sliding-window question uses fast path")
assert(provisionalAnswerTopic(for: "What is backtracking?", lastTopic: nil) == "backtracking", "Backtracking question uses fast path")
assert(provisionalAnswerTopic(for: "What is memoization?", lastTopic: nil) == "memoization", "Memoization question uses fast path")
assert(provisionalAnswerTopic(for: "What is concurrency?", lastTopic: nil) == "concurrency", "Concurrency question uses fast path")
assert(provisionalAnswerTopic(for: "What is a race condition?", lastTopic: nil) == "raceCondition", "Race-condition question uses fast path")

// Specificity: "array list"/"arraylist" must resolve to the more specific arrayList and
// never be shadowed by the bare "array" token (regression guard for the tiebreak).
assert(provisionalAnswerTopic(for: "What is an ArrayList?", lastTopic: nil) == "arrayList", "ArrayList keeps its specific topic, not bare array")
assert(provisionalAnswerTopic(for: "What is an array list?", lastTopic: nil) == "arrayList", "Spaced 'array list' resolves to arrayList, not bare array")
assert(bestTopicHint(from: normalizedQuestionText("explain the array list api"), technicalTokens: technicalQuestionTokens(in: normalizedQuestionText("explain the array list api"))) == "arrayList", "bestTopicHint prefers arrayList over bare array")

// Direct token membership (positives) for the new tokens.
assert(technicalQuestionTokens(in: "what is an array").contains("array"), "array token detected as a whole word")
assert(technicalQuestionTokens(in: "use a sliding window here").contains("slidingWindow"), "sliding window maps to slidingWindow token")
assert(technicalQuestionTokens(in: "solve it with backtracking").contains("backtracking"), "backtracking token detected")
assert(technicalQuestionTokens(in: "add memoization to the recursion").contains("memoization"), "memoization token detected")
assert(technicalQuestionTokens(in: "explain concurrency in go").contains("concurrency"), "concurrency token detected")
assert(technicalQuestionTokens(in: "what causes a race condition").contains("raceCondition"), "race condition maps to raceCondition token")

// Word-boundary safeguard: bare "array" must NOT fire inside unrelated words, and must
// not fire inside "arraylist" (which keeps only the arrayList token).
assert(!technicalQuestionTokens(in: "the project was left in disarray").contains("array"), "array does not match inside 'disarray'")
assert(!technicalQuestionTokens(in: "the data was arrayed across the nodes").contains("array"), "array does not match inside 'arrayed'")
assert(technicalQuestionTokens(in: "what is an arraylist").contains("array") == false, "bare array token does not fire inside 'arraylist'")
assert(!technicalQuestionTokens(in: "storage state and browser context").contains("rag"), "rag does not match inside 'storage'")

// Safeguards stay intact: candidate statements that merely mention the new topics still defer.
assert(provisionalAnswerTopic(for: "We had a race condition in production once", lastTopic: nil) == nil, "Candidate statement mentioning a race condition is not fast-pathed")
assert(provisionalAnswerTopic(for: "I reversed an array in my coding test", lastTopic: nil) == nil, "Candidate statement mentioning an array is not fast-pathed")

// Incomplete stems on the new topics still buffer (no premature fast-path answer).
assert(provisionalAnswerTopic(for: "What is the", lastTopic: nil) == nil, "Bare incomplete stem still defers with the DSA topics added")

// Vague follow-up reuses a new DSA prior topic for the fast path.
assert(provisionalAnswerTopic(for: "Tell me more", lastTopic: "array") == "array", "Follow-up reuses an array prior topic for the fast path")

section("conversationalDisplayAnswer")
let verboseAnswer = """
**Definition**: Playwright is an E2E automation framework.
**Key points**:
- Auto-waits for elements before actions.
- Fixtures isolate setup and test data.
**Senior tip**: Use traces to separate app bugs from test flakes.
"""
let cleanedAnswer = conversationalDisplayAnswer(verboseAnswer)
assert(!cleanedAnswer.contains("**Definition**"), "Removes Definition label")
assert(!cleanedAnswer.contains("**Key points**"), "Removes Key points label")
assert(!cleanedAnswer.contains("**Senior tip**"), "Removes Senior tip label")
assert(cleanedAnswer.contains("Playwright is an E2E automation framework."), "Keeps direct answer")
assert(cleanedAnswer.components(separatedBy: "\n").allSatisfy { $0.hasPrefix("- ") }, "Formats non-code answers as cue bullets")
assert(cleanedAnswer.components(separatedBy: "\n").count <= 5, "Caps non-code answers")
let introAnswer = """
Sure, here's a concise answer:
- HashMap stores key-value pairs by hash.
- Collisions are handled by buckets.
- Lookup is usually O(1).
"""
let cleanedIntroAnswer = conversationalDisplayAnswer(introAnswer)
assert(!cleanedIntroAnswer.lowercased().contains("sure"), "Drops model intro line")
assert(cleanedIntroAnswer.components(separatedBy: "\n").allSatisfy { $0.hasPrefix("- ") }, "Intro cleanup keeps cue bullets")
let inlineIntroAnswer = "Sure, here's a concise answer: - HashMap stores key-value pairs by hashing. - Collisions stay in buckets or tree bins. - Lookup is usually O(1)."
let cleanedInlineIntroAnswer = conversationalDisplayAnswer(inlineIntroAnswer)
let inlineIntroLines = cleanedInlineIntroAnswer.components(separatedBy: "\n")
assert(!cleanedInlineIntroAnswer.lowercased().contains("sure"), "Drops inline model intro")
assert(inlineIntroLines.count == 3, "Inline intro bullets become separate cue bullets")
assert(inlineIntroLines.allSatisfy { $0.hasPrefix("- ") }, "Inline intro cleanup keeps bullet-only format")
assert(cleanedInlineIntroAnswer.contains("HashMap stores key-value pairs"), "Inline intro cleanup keeps content")
let longExperienceAnswer = """
Over the last eight years, I've built test automation from the ground up—starting with Selenium, then moving to Playwright for web-first testing. My main strength is designing stable, maintainable frameworks that actually catch real bugs without flaking.
In my last role, I owned end-to-end test coverage for a React dashboard. I used Playwright with TypeScript, set up fixtures for reusable test data and authenticated sessions via `storageState`, and built page objects to keep locators clean. I focused on web-first assertions like `expect(locator).toBeVisible()` to avoid flaky waits, and used `page.route` to mock backend calls so tests ran fast and isolated.
The biggest win was reducing flaky tests by 70% by tracing failures, separating app bugs from test bugs, and isolating data per test.
"""
let cueCard = conversationalDisplayAnswer(longExperienceAnswer)
let cueLines = cueCard.components(separatedBy: "\n")
assert(cueLines.count <= 5, "Long experience answer becomes max five bullets")
assert(cueLines.allSatisfy { $0.hasPrefix("- ") }, "Long experience answer is bullet-only")
assert(cueLines.allSatisfy { $0.count <= 122 }, "Long experience bullets are readable")
assert(cueCard.contains("eight years") || cueCard.contains("8"), "Experience headline is preserved")
let semicolonDenseAnswer = "Playwright auth flow: use `storageState` for logged-in sessions; create isolated accounts per worker; reset backend data before each test; keep traces and screenshots on retry."
let semicolonCueCard = conversationalDisplayAnswer(semicolonDenseAnswer)
let semicolonCueLines = semicolonCueCard.components(separatedBy: "\n")
assert(semicolonCueLines.count >= 3, "Semicolon-dense answer is split into multiple cue bullets")
assert(semicolonCueLines.count <= 5, "Semicolon-dense answer stays capped")
assert(semicolonCueLines.allSatisfy { $0.hasPrefix("- ") }, "Semicolon-dense answer remains bullet-only")
let slashDenseAnswer = "- For Playwright, I focus on stable locators / web-first assertions / fixtures for setup / storageState for auth / traces on retries."
let slashCueCard = conversationalDisplayAnswer(slashDenseAnswer)
let slashCueLines = slashCueCard.components(separatedBy: "\n")
assert(slashCueLines.count >= 4, "Slash-dense answer is split into multiple cue bullets")
assert(slashCueLines.count <= 5, "Slash-dense answer stays capped")
assert(slashCueLines.allSatisfy { $0.hasPrefix("- ") }, "Slash-dense answer remains bullet-only")
let commaDenseAnswer = "I would answer it as: I start with risk-based coverage, I map the critical user flows to stable E2E tests, I isolate test data per worker, I use traces and screenshots to debug failures, and I keep flaky-test triage separate from product bugs."
let commaCueCard = conversationalDisplayAnswer(commaDenseAnswer)
let commaCueLines = commaCueCard.components(separatedBy: "\n")
assert(commaCueLines.count >= 3, "Comma-dense answer is split into multiple cue bullets")
assert(commaCueLines.count <= 5, "Comma-dense answer stays capped")
assert(commaCueLines.allSatisfy { $0.hasPrefix("- ") }, "Comma-dense answer remains bullet-only")
assert(!commaCueCard.lowercased().contains("i would answer it as"), "Comma-dense answer drops lead-in")
let contextualLeadInAnswer = "For this one, I'd say: I use CI/CD to run tests on every PR; I keep Playwright workers isolated; I publish traces on retries."
let contextualCueCard = conversationalDisplayAnswer(contextualLeadInAnswer)
let contextualCueLines = contextualCueCard.components(separatedBy: "\n")
assert(!contextualCueCard.lowercased().contains("for this one"), "Contextual lead-in is removed")
assert(contextualCueLines.count == 3, "Contextual lead-in answer becomes three bullets")
assert(contextualCueLines.allSatisfy { $0.hasPrefix("- ") }, "Contextual lead-in cleanup keeps cue bullets")
let ragLeadInAnswer = "- I would say RAG is about vectorizing documents into a searchable knowledge base.\n- The app stores embeddings in a vector DB and searches semantically."
let ragLeadInCueCard = conversationalDisplayAnswer(ragLeadInAnswer)
assert(!ragLeadInCueCard.lowercased().contains("i would say"), "RAG answer lead-in is removed")
assert(ragLeadInCueCard.contains("RAG is about vectorizing documents"), "RAG answer keeps the direct definition")
let labeledModelAnswer = """
Approach:
- Start with risk-based coverage across the critical user flow.
Trade-off:
- Keep E2E small and push lower-level permutations into API tests.
Example:
- For payments, cover happy path, failed card, and retry handling.
"""
let labeledCueCard = conversationalDisplayAnswer(labeledModelAnswer)
let labeledCueLines = labeledCueCard.components(separatedBy: "\n")
assert(!labeledCueCard.lowercased().contains("approach:"), "Drops Approach label")
assert(!labeledCueCard.lowercased().contains("trade-off:"), "Drops Trade-off label")
assert(!labeledCueCard.lowercased().contains("example:"), "Drops Example label")
assert(labeledCueLines.count == 3, "Labeled model answer keeps only content bullets")
assert(labeledCueLines.allSatisfy { $0.hasPrefix("- ") }, "Labeled model answer remains bullet-only")
let codeAnswer = "Use this:\n```swift\nprint(\"ok\")\n```"
assert(conversationalDisplayAnswer(codeAnswer) == codeAnswer, "Preserves code blocks")
let solidMarkdownAnswer = """
- **S**ingle Responsibility: one class, one reason to change
- **O**pen/Closed: extend without modifying existing code
- S** Liskov Substitution: subtypes must replace their base type
"""
let solidCueCard = conversationalDisplayAnswer(solidMarkdownAnswer)
assert(!solidCueCard.contains("*"), "Strips markdown asterisks from SOLID answers")
assert(solidCueCard.contains("S - Single Responsibility"), "Expands **S**ingle into a readable S - Single line")
assert(solidCueCard.contains("O - Open"), "Expands **O**pen into a readable O - Open line")
assert(solidCueCard.contains("Liskov Substitution"), "Keeps Liskov content after leftover S** cleanup")
let alreadyStructuredSolid = """
- S - Single Responsibility: one class, one reason to change
- O - Open/Closed: extend without modifying existing code
"""
let structuredSolidCue = conversationalDisplayAnswer(alreadyStructuredSolid)
assert(structuredSolidCue.contains("S - Single Responsibility"), "Keeps already structured SOLID bullets")
assert(structuredSolidCue.contains("O - Open/Closed"), "Keeps already structured Open/Closed bullet")

section("InterviewRole QA profile consolidation")
assert(!TestInterviewRole.selectableCases.contains(.sdet), "Legacy SDET role is hidden from UI choices")
assert(TestInterviewRole.sdet.canonicalRole == .qaAutomationEngineer, "Legacy SDET maps to QA Automation / SDET")
assert(TestInterviewRole.sdet.displayName == "QA Automation / SDET", "Legacy SDET uses combined display name")
assert(TestInterviewRole.qaEngineer.isQA == true, "QA Engineer uses shared QA profile")
assert(TestInterviewRole.qaAutomationEngineer.isQA == true, "QA Automation uses shared QA profile")
assert(TestInterviewRole.seniorQAEngineer.isQA == true, "Senior QA uses shared QA profile")
assert(TestInterviewRole.backendDeveloper.isQA == false, "Non-QA role does not use QA profile")

section("classifySpeaker")
assert(classifySpeaker(text: "What is polymorphism?") == .interviewer, "Short question = interviewer")
assert(classifySpeaker(text: "anything", isQuestion: true) == .interviewer, "LLM classified question = interviewer")
assert(classifySpeaker(text: "Polymorphism is a concept in object-oriented programming that allows objects of different types to be treated as objects of a common base type. It enables you to write code that can work with objects of multiple classes through a single interface, promoting flexibility and extensibility in your software design.") == .interviewee, "Long answer = interviewee")
assert(classifySpeaker(text: "I have experience building distributed systems with microservices architecture using Docker and Kubernetes for container orchestration and service discovery") == .interviewee, "Medium-length technical answer (>15 words) = interviewee")
assert(classifySpeaker(text: "Tell me about your experience") == .interviewer, "Tell me = interviewer")
assert(classifySpeaker(text: "Welcome to the interview") == .interviewer, "Welcome phrase = interviewer")
assert(classifySpeaker(text: "ok") == .unknown, "Very short ambiguous = unknown")

// SOURCE: Domain/Model/Constants.swift SpeechTurnPolicy
enum SpeechTurnEmit: Equatable {
    case speculativePreview
    case speechResumedAfterPreview
    case finalSilence
}

enum SpeechTurnAction: Equatable {
    case prefetchTranscriptionOnly
    case cancelInFlightWork
    case commitAnswer
}

enum SpeechTurnPolicy {
    static func action(for emit: SpeechTurnEmit) -> SpeechTurnAction {
        switch emit {
        case .speculativePreview:
            return .prefetchTranscriptionOnly
        case .speechResumedAfterPreview:
            return .cancelInFlightWork
        case .finalSilence:
            return .commitAnswer
        }
    }

    static func startsAnswerCard(_ action: SpeechTurnAction) -> Bool {
        action == .commitAnswer
    }
}

// SOURCE: Domain/Model/Constants.swift GroqRequestTuning
func groqTranscriptionUpload(for audioData: Data) -> (filename: String, mimeType: String) {
    GroqRequestTuning.transcriptionUpload(for: audioData)
}

func groqChatReasoningFields(for model: String) -> [String: Any] {
    GroqRequestTuning.chatReasoningFields(for: model)
}

enum GroqRequestTuning {
    static let cueCardPrefill = "- "

    static func transcriptionUpload(for audioData: Data) -> (filename: String, mimeType: String) {
        if audioData.count >= 12 {
            let header = audioData.prefix(12)
            if header.starts(with: Data("RIFF".utf8)),
               header.suffix(4) == Data("WAVE".utf8) {
                return ("audio.wav", "audio/wav")
            }
        }
        if audioData.count >= 8 {
            let brand = audioData.subdata(in: 4..<8)
            if brand == Data("ftyp".utf8) {
                return ("audio.m4a", "audio/mp4")
            }
        }
        return ("audio.wav", "audio/wav")
    }

    static func chatReasoningFields(for model: String) -> [String: Any] {
        if model.hasPrefix("openai/gpt-oss") {
            return [
                "reasoning_effort": "low",
                "include_reasoning": false
            ]
        }
        if model.hasPrefix("qwen/") {
            return ["reasoning_effort": "none"]
        }
        return [:]
    }

    static func chatMessages(userPrompt: String) -> [[String: String]] {
        [
            ["role": "user", "content": userPrompt],
            ["role": "assistant", "content": cueCardPrefill]
        ]
    }

    static func visibleCueCardPrefix(for firstChunk: String) -> String {
        let trimmed = firstChunk.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("-") {
            return ""
        }
        return cueCardPrefill
    }
}

section("SpeechTurnPolicy")
assert(SpeechTurnPolicy.action(for: .speculativePreview) == .prefetchTranscriptionOnly, "0.25s silence overlaps STT only")
assert(SpeechTurnPolicy.startsAnswerCard(.prefetchTranscriptionOnly) == false, "Preview must not start an answer card")
assert(SpeechTurnPolicy.action(for: .speechResumedAfterPreview) == .cancelInFlightWork, "Speech resume cancels in-flight preview work")
assert(SpeechTurnPolicy.startsAnswerCard(.cancelInFlightWork) == false, "Cancel must not start an answer card")
assert(SpeechTurnPolicy.action(for: .finalSilence) == .commitAnswer, "0.65s silence commits the answer")
assert(SpeechTurnPolicy.startsAnswerCard(.commitAnswer) == true, "Final silence is the only emit that starts an answer card")

var previewCount = 0
var cancelCount = 0
var commitCount = 0
func routePauseResumeCommit(_ emit: SpeechTurnEmit) {
    switch SpeechTurnPolicy.action(for: emit) {
    case .prefetchTranscriptionOnly:
        previewCount += 1
    case .cancelInFlightWork:
        cancelCount += 1
    case .commitAnswer:
        commitCount += 1
    }
}
routePauseResumeCommit(.speculativePreview)
routePauseResumeCommit(.speechResumedAfterPreview)
routePauseResumeCommit(.speculativePreview)
routePauseResumeCommit(.finalSilence)
assert(previewCount == 2, "Mid-utterance pauses prefetch STT twice")
assert(cancelCount == 1, "Resume after preview cancels the first prefetch")
assert(commitCount == 1, "Only the final 0.65s silence commits an answer card")

section("GroqRequestTuning")
var wavBytes = Data("RIFF".utf8)
wavBytes.append(contentsOf: [16, 0, 0, 0])
wavBytes.append(contentsOf: "WAVE".utf8)
wavBytes.append(contentsOf: [0, 0, 0, 0])
let wavUpload = groqTranscriptionUpload(for: wavBytes)
assert(wavUpload.filename == "audio.wav", "WAV payload uses .wav filename")
assert(wavUpload.mimeType == "audio/wav", "WAV payload uses audio/wav")

var m4aBytes = Data([0, 0, 0, 24])
m4aBytes.append(contentsOf: "ftyp".utf8)
m4aBytes.append(contentsOf: "M4A ".utf8)
let m4aUpload = groqTranscriptionUpload(for: m4aBytes)
assert(m4aUpload.filename == "audio.m4a", "M4A payload keeps .m4a filename")
assert(m4aUpload.mimeType == "audio/mp4", "M4A payload keeps audio/mp4")

let ossFields = groqChatReasoningFields(for: "openai/gpt-oss-20b")
assert(ossFields["reasoning_effort"] as? String == "low", "GPT-OSS stays on low reasoning")
assert(ossFields["include_reasoning"] as? Bool == false, "GPT-OSS hides reasoning so first visible token is answer text")
assert(ossFields["reasoning_format"] == nil, "GPT-OSS does not send unsupported reasoning_format")

let qwenFields = groqChatReasoningFields(for: "qwen/qwen3.6-27b")
assert(qwenFields["reasoning_effort"] as? String == "none", "Qwen disables reasoning for live cue cards")
assert(groqChatReasoningFields(for: "llama-3.1-8b-instant").isEmpty, "Unknown models get no reasoning extras")

let prefillMessages = GroqRequestTuning.chatMessages(userPrompt: "Q: What is SOLID?")
assert(prefillMessages.count == 2, "Fast-path chat uses user prompt plus cue-card prefill")
assert(prefillMessages[0]["role"] == "user", "First chat message is the user prompt")
assert(prefillMessages[1]["role"] == "assistant", "Second chat message prefills the assistant")
assert(prefillMessages[1]["content"] == "- ", "Assistant prefill is a cue-card dash so the first token is answer text")
assert(GroqRequestTuning.visibleCueCardPrefix(for: "- SOLID is") == "", "Does not double the dash when the model already starts a bullet")
assert(GroqRequestTuning.visibleCueCardPrefix(for: "SOLID is") == "- ", "Adds the cue-card dash when the first chunk has no bullet")
assert(GroqRequestTuning.visibleCueCardPrefix(for: "  SOLID") == "- ", "Trims whitespace before deciding whether to add a dash")

section("provisionalAnswerTopic SOLID opener")
assert(provisionalAnswerTopic(for: "Tell me about the solid principles", lastTopic: nil) == "solid", "SOLID request uses fast path")
assert(provisionalAnswerTopic(for: "Okay, so tell me about the solid principles.", lastTopic: nil) == "solid", "Spoken SOLID opener with filler still uses fast path")
assert(provisionalAnswerTopic(for: "Explain SOLID principles", lastTopic: nil) == "solid", "Explain SOLID uses fast path")
assert(provisionalAnswerTopic(for: "Tell me about", lastTopic: nil) == nil, "Bare tell-me-about stem still defers")
assert(provisionalAnswerTopic(for: "I used SOLID in my last codebase", lastTopic: nil) == nil, "Candidate SOLID statement is not fast-pathed")

section("isFollowUp")
assert(isFollowUp(text: "Tell me more about that") == true, "Tell me more")
assert(isFollowUp(text: "Can you elaborate?") == true, "Elaborate")
assert(isFollowUp(text: "Give me an example") == true, "Give example")
assert(isFollowUp(text: "What is a binary tree?") == false, "New question")
assert(isFollowUp(text: "Go deeper into that topic") == true, "Go deeper")
assert(isFollowUp(text: "I have experience with React") == false, "Statement")

section("messagesToAPIFormat")
let msgs1 = [
    MultiTurnMessage(role: "user", content: "What is REST?"),
    MultiTurnMessage(role: "assistant", content: "REST is..."),
    MultiTurnMessage(role: "user", content: "Tell me more")
]
let result1 = messagesToAPIFormat(msgs1)
assert(result1.count == 3, "3 alternating messages stay as 3")
assert(result1[0]["role"] == "user", "First is user")

let msgs2 = [
    MultiTurnMessage(role: "user", content: "Hello"),
    MultiTurnMessage(role: "user", content: "What is REST?")
]
let result2 = messagesToAPIFormat(msgs2)
assert(result2.count == 1, "Consecutive same-role merged to 1")
assert(result2[0]["content"]!.contains("Hello"), "Merged content has first part")
assert(result2[0]["content"]!.contains("REST"), "Merged content has second part")

let msgs3 = [
    MultiTurnMessage(role: "assistant", content: "Welcome"),
    MultiTurnMessage(role: "user", content: "Thanks")
]
let result3 = messagesToAPIFormat(msgs3)
assert(result3.count == 3, "Prepends user message when starts with assistant")
assert(result3[0]["role"] == "user", "Prepended message is user role")
assert(result3[0]["content"] == "(Interview in progress)", "Prepended placeholder content")

// SOURCE: Presentation/Components/InterviewFocusComponents.swift
enum TestBurstPhase: Equatable {
    case queued, generating, answering, ready, failed
}

struct TestBurstEntry: Equatable {
    let id: UUID
    let sequence: Int
    var question: String
    var phase: TestBurstPhase
    var answer: String
}

struct TestBurstState {
    private(set) var entries: [TestBurstEntry] = []
    private(set) var selectedID: UUID?
    private(set) var activeAIWork: Set<UUID> = []

    var visibleEntries: [TestBurstEntry] { Array(entries.sorted(by: { $0.sequence > $1.sequence }).prefix(3)) }
    var isAIWorking: Bool { !activeAIWork.isEmpty }

    mutating func receive(_ id: UUID, sequence: Int, question: String) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].question = question
        } else {
            entries.append(TestBurstEntry(
                id: id,
                sequence: sequence,
                question: question,
                phase: activeAIWork.contains(id) ? .generating : .queued,
                answer: ""
            ))
        }

        selectedID = visibleEntries.first?.id
    }

    mutating func begin(_ id: UUID) {
        activeAIWork.insert(id)
        if let index = entries.firstIndex(where: { $0.id == id }), entries[index].phase != .ready {
            entries[index].phase = .generating
        }
    }

    mutating func stream(_ id: UUID, answer: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].phase = .answering
        entries[index].answer = answer
    }

    mutating func finish(_ id: UUID, answer: String) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].phase = .ready
            entries[index].answer = answer
        }
        activeAIWork.remove(id)
    }
}

section("QuestionBurstState")
let burstQ1 = UUID()
let burstQ2 = UUID()
let burstQ3 = UUID()
let burstQ4 = UUID()
var burst = TestBurstState()

burst.begin(burstQ1)
burst.receive(burstQ1, sequence: 1, question: "Design a rate limiter")
burst.begin(burstQ2)
burst.receive(burstQ2, sequence: 2, question: "Which failures matter?")
burst.begin(burstQ3)
burst.receive(burstQ3, sequence: 3, question: "How would you load test it?")
assert(burst.visibleEntries.map(\.id) == [burstQ3, burstQ2, burstQ1], "Burst presents newest question first")
assert(burst.selectedID == burstQ3, "Newest question always becomes the selected answer")
assert(burst.isAIWorking, "Any active turn keeps the gold AI-working state active")

burst.stream(burstQ1, answer: "A1 partial")
burst.stream(burstQ2, answer: "A2 partial")
burst.finish(burstQ1, answer: "A1 final")
assert(burst.isAIWorking, "Finishing one interleaved turn does not clear another active turn")
assert(burst.entries.first(where: { $0.id == burstQ1 })?.answer == "A1 final", "Q1 finalization updates only Q1")
assert(burst.entries.first(where: { $0.id == burstQ2 })?.answer == "A2 partial", "Q1 finalization does not overwrite Q2")

burst.receive(burstQ2, sequence: 2, question: "Which failure modes matter most?")
assert(burst.entries.filter { $0.id == burstQ2 }.count == 1, "Duplicate question event is idempotent by turn ID")

burst.begin(burstQ4)
burst.receive(burstQ4, sequence: 4, question: "What would you monitor?")
assert(burst.visibleEntries.map(\.id) == [burstQ4, burstQ3, burstQ2], "Visible burst is clipped to the newest three turns")
assert(burst.selectedID == burstQ4, "Newest question remains selected as prior questions shift to slots 2 and 3")

var outOfOrderBurst = TestBurstState()
outOfOrderBurst.begin(burstQ2)
outOfOrderBurst.receive(burstQ2, sequence: 2, question: "Second spoken question")
outOfOrderBurst.begin(burstQ1)
outOfOrderBurst.receive(burstQ1, sequence: 1, question: "First spoken question arrived from the model later")
assert(outOfOrderBurst.visibleEntries.map(\.id) == [burstQ2, burstQ1], "Speech sequence, not model callback completion, controls slot order")
assert(outOfOrderBurst.selectedID == burstQ2, "A late callback from an older turn cannot steal newest-question focus")

burst.finish(burstQ2, answer: "A2 final")
burst.finish(burstQ3, answer: "A3 final")
burst.finish(burstQ4, answer: "A4 final")
assert(!burst.isAIWorking, "Gold AI-working state clears only after every active turn finishes")

struct TestSequencedTopicContext {
    private(set) var lastTopic: String?
    private var lastSequence: Int?

    mutating func add(topic: String, sequence: Int) {
        if lastSequence == nil || sequence >= lastSequence! {
            lastSequence = sequence
            lastTopic = topic
        }
    }
}

section("Sequenced conversation context")
var sequencedContext = TestSequencedTopicContext()
sequencedContext.add(topic: "newer-topic", sequence: 2)
sequencedContext.add(topic: "older-topic-finished-late", sequence: 1)
assert(sequencedContext.lastTopic == "newer-topic", "Late completion from an older spoken turn cannot replace the newest topic")
sequencedContext.add(topic: "newest-topic", sequence: 3)
assert(sequencedContext.lastTopic == "newest-topic", "Higher speech sequence advances follow-up context")

// ============================================================
// SOURCE: Domain/Practice/PracticeLogic.swift
// Isolated practice scoring, packs, and progress — not live interview assist.
// ============================================================
enum PracticeHelpMark: String, Codable, Equatable {
    case none
    case yellow
}

enum PracticeScoring {
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

struct PracticeQuestion: Equatable {
    let id: String
    let packId: String
    let text: String
    var groupId: String = ""
    var topicId: String = ""
    var topicTitle: String = ""
    var hints: [String] = []
    var rubric: String = ""
    var answer: String = ""
}

struct PracticeTopicPack: Equatable {
    let id: String
    let title: String
    let questions: [PracticeQuestion]

    static let all: [PracticeTopicPack] = [aws, models, angular]

    static let aws = PracticeTopicPack(
        id: "aws",
        title: "AWS",
        questions: [
            PracticeQuestion(id: "aws-iam", packId: "aws", text: "What is the difference between an IAM user and an IAM role?")
        ]
    )

    static let models = PracticeTopicPack(
        id: "models",
        title: "Models",
        questions: [
            PracticeQuestion(id: "models-rag", packId: "models", text: "What is RAG, and when would you use it instead of fine-tuning?")
        ]
    )

    static let angular = PracticeTopicPack(
        id: "angular",
        title: "Angular",
        questions: [
            PracticeQuestion(id: "angular-signals", packId: "angular", text: "What are Angular signals, and why were they added?")
        ]
    )
}

func practicePackIDs() -> [String] {
    PracticeTopicPack.all.map(\.id)
}

func questionsForPracticePack(id: String) -> [PracticeQuestion] {
    PracticeTopicPack.all.first { $0.id == id }?.questions ?? []
}

func questionsMatching(pack: PracticeTopicPack, groupIds: [String]) -> [PracticeQuestion] {
    if groupIds.isEmpty { return pack.questions }
    let allowed = Set(groupIds)
    return pack.questions.filter { allowed.contains($0.groupId) }
}

func practiceTopicKey(for question: PracticeQuestion, groupIds: [String]) -> String {
    if groupIds.count == 1 {
        let topic = question.topicId
        return topic.isEmpty ? question.groupId : topic
    }
    let group = question.groupId
    return group.isEmpty ? question.packId : group
}

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

let practiceInterviewTopicOrder = [
    "python-engineering",
    "foundations",
    "classical-ml",
    "genai-and-llm"
]

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
    default: origin = question.packId
    }
    var parts = [origin]
    if !groupTitle.isEmpty { parts.append(groupTitle) }
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

section("Practice topic packs")
assert(practicePackIDs().contains("aws"), "AWS pack is available")
assert(practicePackIDs().contains("models"), "Models pack is available")
assert(practicePackIDs().contains("angular"), "Angular pack is available")
assert(!questionsForPracticePack(id: "aws").isEmpty, "AWS pack has questions")
assert(!questionsForPracticePack(id: "models").isEmpty, "Models pack has questions")
assert(!questionsForPracticePack(id: "angular").isEmpty, "Angular pack has questions")
assert(questionsForPracticePack(id: "aws").allSatisfy { $0.packId == "aws" }, "AWS questions belong to the AWS pack")
assert(questionsForPracticePack(id: "unknown").isEmpty, "Unknown pack has no questions")

section("Practice help scoring")
assert(PracticeScoring.helpMultiplier <= 0.5, "Help multiplier is at most half")
let helpedPerfect = applyHelpPenalty(rawScore: 1.0, usedHelp: true)
assert(helpedPerfect.finalScore == 0.4, "Help applies a 0.4× multiplier")
assert(helpedPerfect.mark == .yellow, "Helped answers are marked yellow")
assert(helpedPerfect.usedHelp, "Help flag is preserved")
let unaided = applyHelpPenalty(rawScore: 0.9, usedHelp: false)
assert(unaided.finalScore == 0.9, "Unaided answers keep full points")
assert(unaided.mark == .none, "Unaided answers are not marked yellow")
let helpedPartial = applyHelpPenalty(rawScore: 0.5, usedHelp: true)
assert(helpedPartial.finalScore == 0.2, "Help penalty scales the raw score, not a flat 0.4")
assert(applyHelpPenalty(rawScore: 2.0, usedHelp: true).finalScore == 0.4, "Raw scores clamp to 1 before the help penalty")

section("Practice progress series")
let day1 = Date(timeIntervalSince1970: 1_700_000_000)
let day2 = Date(timeIntervalSince1970: 1_700_086_400)
let day3 = Date(timeIntervalSince1970: 1_699_913_600)
let storedRuns = [
    PracticeProgressInput(finishedAt: day2, score: 0.7, packId: "aws"),
    PracticeProgressInput(finishedAt: day1, score: 0.4, packId: "angular"),
    PracticeProgressInput(finishedAt: day3, score: 0.55, packId: "models")
]
let overallSeries = practiceProgressSeries(from: storedRuns)
assert(overallSeries.map(\.score) == [0.55, 0.4, 0.7], "Progress points are ordered by run date")
assert(overallSeries.map(\.packId) == ["models", "angular", "aws"], "Progress keeps pack identity")
let awsSeries = practiceProgressSeries(from: storedRuns, packId: "aws")
assert(awsSeries.map(\.score) == [0.7], "Pack filter keeps only that pack's runs")

section("Practice balanced topic selection")
let bank = (0..<3).flatMap { topic in
    (0..<4).map { index in
        PracticeQuestion(id: "t\(topic)-\(index)", packId: "study-book", text: "Q\(topic).\(index)", groupId: "t\(topic)")
    }
}
let six = balancedPracticeSelection(questions: bank, count: 6, topicOf: { $0.groupId }, shuffle: { $0 })
assert(six.count == 6, "Requested count is honored when the bank is large enough")
let sixCounts = Dictionary(grouping: six, by: \.groupId).mapValues(\.count)
assert(sixCounts["t0"] == 2 && sixCounts["t1"] == 2 && sixCounts["t2"] == 2, "Six questions across three topics are 2 each")
assert(Set(six.map(\.id)) == Set(["t0-0", "t1-0", "t2-0", "t0-1", "t1-1", "t2-1"]), "Round-robin walks topics in lockstep")

let hundredPool = (0..<11).flatMap { topic in
    (0..<20).map { index in
        PracticeQuestion(id: "g\(topic)-\(index)", packId: "study-book", text: "Q", groupId: "g\(topic)")
    }
}
let hundred = balancedPracticeSelection(questions: hundredPool, count: 100, topicOf: { $0.groupId }, shuffle: { $0 })
assert(hundred.count == 100, "A 100-question run is filled when the bank allows it")
let hundredCounts = Dictionary(grouping: hundred, by: \.groupId).mapValues(\.count)
assert(hundredCounts.values.allSatisfy { $0 == 9 || $0 == 10 }, "100 across 11 topics is 9 or 10 each")
assert(hundredCounts.values.max()! - hundredCounts.values.min()! <= 1, "Topic counts differ by at most one")

let shortTopic = [
    PracticeQuestion(id: "short-0", packId: "p", text: "S", groupId: "short"),
    PracticeQuestion(id: "long-0", packId: "p", text: "L0", groupId: "long"),
    PracticeQuestion(id: "long-1", packId: "p", text: "L1", groupId: "long"),
    PracticeQuestion(id: "long-2", packId: "p", text: "L2", groupId: "long")
]
let redistributed = balancedPracticeSelection(questions: shortTopic, count: 4, topicOf: { $0.groupId }, shuffle: { $0 })
assert(redistributed.filter { $0.groupId == "short" }.count == 1, "A thin topic is exhausted then remainder goes to others")
assert(redistributed.filter { $0.groupId == "long" }.count == 3, "Larger topics absorb leftover slots")

let pythonPack = PracticeTopicPack(
    id: "study-book",
    title: "ML",
    questions: [
        PracticeQuestion(id: "a", packId: "study-book", text: "A", groupId: "python-engineering"),
        PracticeQuestion(id: "b", packId: "study-book", text: "B", groupId: "java-and-jvm")
    ]
)
assert(questionsMatching(pack: pythonPack, groupIds: ["python-engineering"]).map(\.id) == ["a"], "Position group filter keeps only selected topics")

section("Practice roles")
struct PracticeRole: Equatable {
    let id: String
    let title: String
    let groupIds: [String]
    static let all: [PracticeRole] = [aiEngineer, frontend, fullStack, qaAutomation]
    static let aiEngineer = PracticeRole(id: "ai-engineer", title: "AI Engineer", groupIds: [
        "python-engineering", "foundations", "classical-ml", "genai-and-llm",
        "ml-in-production", "system-design", "models", "interview-prep", "agentic-sme-s-and-p",
        "aws", "devops"
    ])
    static let frontend = PracticeRole(id: "frontend", title: "Frontend engineer", groupIds: [
        "jr-javascript", "mid-javascript", "senior-javascript", "typescript",
        "angular", "oop", "json", "networking", "engineering-practice", "system-design"
    ])
    static let fullStack = PracticeRole(id: "full-stack", title: "Full stack", groupIds: [
        "python-engineering", "jr-javascript", "mid-javascript", "senior-javascript",
        "typescript", "angular", "oop", "system-design", "engineering-practice",
        "aws", "networking", "json", "devops", "genai-and-llm", "interview-prep"
    ])
    static let qaAutomation = PracticeRole(id: "qa-automation", title: "QA automation", groupIds: [
        "qa", "coding-tasks", "logical-tasks", "python-engineering",
        "engineering-practice", "java-and-jvm", "system-design", "interview-prep"
    ])
}
func practiceGroupIDs(forRole role: PracticeRole, available: [String]) -> [String] {
    let allowed = Set(available)
    return role.groupIds.filter { allowed.contains($0) }
}
let availableTopics = [
    "python-engineering", "foundations", "angular", "engineering-practice", "java-and-jvm", "aws",
    "jr-javascript", "qa", "oop", "devops"
]
assert(PracticeRole.all.map(\.id) == ["ai-engineer", "frontend", "full-stack", "qa-automation"], "Four interview roles are selectable")
assert(practiceGroupIDs(forRole: .aiEngineer, available: availableTopics).contains("python-engineering"), "AI Engineer includes Python")
assert(practiceGroupIDs(forRole: .aiEngineer, available: availableTopics).contains("foundations"), "AI Engineer includes models/foundations")
assert(!practiceGroupIDs(forRole: .aiEngineer, available: availableTopics).contains("oop"), "AI Engineer does not use the JS/Java OOP pack")
assert(practiceGroupIDs(forRole: .aiEngineer, available: availableTopics).contains("aws"), "AI Engineer includes AWS")
assert(practiceGroupIDs(forRole: .aiEngineer, available: availableTopics).contains("devops"), "AI Engineer includes DevOps")
assert(!practiceGroupIDs(forRole: .aiEngineer, available: availableTopics).contains("angular"), "AI Engineer does not include Angular")
assert(practiceGroupIDs(forRole: .frontend, available: availableTopics) == ["jr-javascript", "angular", "oop", "engineering-practice"], "Frontend is filtered to UI topics that exist")
assert(practiceGroupIDs(forRole: .fullStack, available: availableTopics).contains("angular"), "Full stack includes frontend")
assert(practiceGroupIDs(forRole: .fullStack, available: availableTopics).contains("jr-javascript"), "Full stack includes the interview-guide JS topics")
assert(practiceGroupIDs(forRole: .fullStack, available: availableTopics).contains("python-engineering"), "Full stack includes backend Python")
assert(practiceGroupIDs(forRole: .qaAutomation, available: availableTopics).contains("qa"), "QA automation includes the interview-guide QA topic")
assert(practiceGroupIDs(forRole: .qaAutomation, available: availableTopics).contains("engineering-practice"), "QA automation includes testing craft")
assert(!practiceGroupIDs(forRole: .qaAutomation, available: availableTopics).contains("angular"), "QA automation does not include Angular")
assert(
    practiceHelpText(for: PracticeQuestion(
        id: "h",
        packId: "study-book",
        text: "Q",
        answer: "One token at a time.\n\nGeneration is autoregressive."
    )) == "One token at a time.\n\nGeneration is autoregressive.",
    "Help shows the prepared correct answer"
)
assert(
    practiceHelpText(for: PracticeQuestion(id: "r", packId: "p", text: "Q", rubric: "Fit the scaler on train only")) == "Fit the scaler on train only",
    "Help falls back to the bank rubric when answer is empty"
)

section("Practice interview order")
let pythonThenModels = [
    PracticeQuestion(id: "m0", packId: "study-book", text: "emb", groupId: "foundations", topicId: "llm-internals"),
    PracticeQuestion(id: "m1", packId: "study-book", text: "train", groupId: "foundations", topicId: "llm-internals"),
    PracticeQuestion(id: "p0", packId: "study-book", text: "gil", groupId: "python-engineering", topicId: "python-concurrency"),
    PracticeQuestion(id: "p1", packId: "study-book", text: "async", groupId: "python-engineering", topicId: "python-concurrency")
]
let ordered = interviewOrderedPracticeSelection(
    questions: pythonThenModels,
    count: 4,
    topicOf: { $0.groupId },
    shuffle: { $0 }
)
assert(ordered.map(\.groupId) == ["python-engineering", "python-engineering", "foundations", "foundations"], "A real loop finishes Python before models")
assert(ordered.filter { $0.groupId == "python-engineering" }.count == 2, "Equal split still holds")
assert(
    practiceQuestionSourceLine(
        PracticeQuestion(id: "x", packId: "study-book", text: "Q", groupId: "python-engineering", topicTitle: "Python concurrency & the GIL"),
        groupTitle: "Python engineering"
    ) == "Study book · Python engineering · Python concurrency & the GIL",
    "Question source names the study book chapter"
)

// ============================================================
// Summary
// ============================================================
print("\n=== Results ===")
print("Passed: \(passed)")
print("Failed: \(failed)")
print(failed == 0 ? "ALL TESTS PASSED" : "SOME TESTS FAILED")

if failed > 0 {
    exit(1)
}
