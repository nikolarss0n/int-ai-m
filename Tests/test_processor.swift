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
    let incompleteEndings = [" so", " and", " but", " the", " a", " an", " to", " of", " that", " if", " when", " is", " are", " have", " can", " will", " for", " with", " on", " in", ","]
    let endsIncomplete = incompleteEndings.contains { textForCheck.hasSuffix($0) }
    let hasQuestionMark = textForCheck.contains("?")

    return endsIncomplete && !hasQuestionMark
}

// SOURCE: Application/VoiceInterviewProcessor.swift:106
func checkForQuestionMarkers(_ text: String) -> Bool {
    let lowerText = text.lowercased()
    let markers = [
        "?",
        "what is", "what are", "what's", "whats", "what did", "what do",
        "how do", "how does", "how is", "how would", "how can", "how to",
        "why do", "why does", "why is", "why would",
        "can you explain", "could you explain", "can you tell", "could you tell",
        "tell me about", "tell me more",
        "explain ", "describe ",
        "what about", "how about",
        "difference between", "differences between",
        "when do", "when does", "when would", "when should",
        "where do", "where does", "where is",
        "which ", "who ", "whose ",
        "какво", "как", "защо", "кога", "къде", "кой", "коя", "кое", "кои",
        "разкажи", "обясни", "опиши",
        "was ", "wie ", "warum", "wann", "wo ", "wer ", "welche",
        "qu'est", "comment", "pourquoi", "quand", "où ", "qui ",
        "qué ", "cómo", "por qué", "cuándo", "dónde", "quién"
    ]
    return markers.contains { lowerText.contains($0) }
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

section("isLocallyIncomplete")
assert(isLocallyIncomplete("I was working on the") == true, "Ends with article")
assert(isLocallyIncomplete("The system uses a") == true, "Ends with 'a'")
assert(isLocallyIncomplete("We implemented it and") == true, "Ends with conjunction")
assert(isLocallyIncomplete("What is a binary tree?") == false, "Complete question")
assert(isLocallyIncomplete("The algorithm runs in O(n) time") == false, "Complete statement")
assert(isLocallyIncomplete("I optimized the database,") == true, "Ends with comma")
assert(isLocallyIncomplete("We tried to optimize the query but") == true, "Ends with 'but'")

section("checkForQuestionMarkers")
assert(checkForQuestionMarkers("What is a hash map?") == true, "English question with ?")
assert(checkForQuestionMarkers("How does garbage collection work") == true, "How does")
assert(checkForQuestionMarkers("Tell me about your experience") == true, "Tell me about")
assert(checkForQuestionMarkers("Explain the SOLID principles") == true, "Explain")
assert(checkForQuestionMarkers("I have 5 years of experience") == false, "Statement")
assert(checkForQuestionMarkers("The system handles 10k requests per second") == false, "Technical statement")
assert(checkForQuestionMarkers("какво е хеш таблица") == true, "Bulgarian question")
assert(checkForQuestionMarkers("wie funktioniert Garbage Collection") == true, "German question")
assert(checkForQuestionMarkers("comment fonctionne le garbage collector") == true, "French question")

section("classifySpeaker")
assert(classifySpeaker(text: "What is polymorphism?") == .interviewer, "Short question = interviewer")
assert(classifySpeaker(text: "anything", isQuestion: true) == .interviewer, "LLM classified question = interviewer")
assert(classifySpeaker(text: "Polymorphism is a concept in object-oriented programming that allows objects of different types to be treated as objects of a common base type. It enables you to write code that can work with objects of multiple classes through a single interface, promoting flexibility and extensibility in your software design.") == .interviewee, "Long answer = interviewee")
assert(classifySpeaker(text: "I have experience building distributed systems with microservices architecture using Docker and Kubernetes for container orchestration and service discovery") == .interviewee, "Medium-length technical answer (>15 words) = interviewee")
assert(classifySpeaker(text: "Tell me about your experience") == .interviewer, "Tell me = interviewer")
assert(classifySpeaker(text: "Welcome to the interview") == .interviewer, "Welcome phrase = interviewer")
assert(classifySpeaker(text: "ok") == .unknown, "Very short ambiguous = unknown")

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
