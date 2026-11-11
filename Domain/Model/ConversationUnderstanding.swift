import Foundation

/// Pure helpers for reading a live interview transcript: who is probably speaking, and whether an
/// utterance stands on its own or leans on the previous turn. No UI or network, so the test runner
/// compiles this file directly instead of keeping a copy.
enum ConversationUnderstanding {
    static func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Foreign-language question markers

    /// Cyrillic markers cannot collide with English, so plain substring matching is safe.
    private static let cyrillicQuestionMarkers = [
        "какво", "как ", "защо", "кога", "къде", "кой", "коя", "кое", "кои",
        "разкажи", "раскажи", "обясни", "опиши"
    ]

    /// Latin-script question words must match whole words. As substrings they fire inside English:
    /// "wo " in "two ", "wer " in "answer ", "wann" in "wanna".
    private static let latinQuestionWords = try! NSRegularExpression(
        pattern: #"(^|[^\p{L}])(wie|warum|wann|wo|wer|welche|qu'est|pourquoi|quand|où|qui|qué|cómo|por qué|cuándo|dónde|quién)($|[^\p{L}])"#
    )

    /// Foreign question words that are also ordinary English words ("it was", "add a comment").
    /// They only count as the first word of the utterance.
    private static let leadingOnlyQuestionWords: Set<String> = ["was", "comment"]

    static func hasForeignQuestionMarker(in normalized: String) -> Bool {
        if cyrillicQuestionMarkers.contains(where: { normalized.contains($0) }) { return true }
        let range = NSRange(normalized.startIndex..., in: normalized)
        if latinQuestionWords.firstMatch(in: normalized, range: range) != nil { return true }
        guard let first = normalized.split(separator: " ").first else { return false }
        return leadingOnlyQuestionWords.contains(String(first))
    }

    /// "Which database have you used?" asks a question; "...a project, which was about agents" does not.
    /// Only a wh-word among the first few words counts, and not when a pronoun subject follows it
    /// ("which I like", "who we hired"), which marks a relative clause.
    static func hasQuestioningWhWord(in words: [String]) -> Bool {
        let cleaned = words.prefix(5).map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
        for (index, word) in cleaned.enumerated() where index < 4 && ["which", "who", "whose"].contains(word) {
            let next = index + 1 < cleaned.count ? cleaned[index + 1] : ""
            var relativeStarts: Set<String> = ["i", "we", "he", "she", "they", "it", "you"]
            if index >= 2 { relativeStarts.formUnion(["was", "were"]) }
            if !relativeStarts.contains(next) { return true }
        }
        return false
    }

    // MARK: - Candidate speech

    private static let candidateStallPhrases = [
        "give me a second", "give me a moment", "give me a minute", "give me one second",
        "just a second", "just a moment", "one second", "one moment", "one sec",
        "hold on", "hang on", "bear with me", "wait a second", "wait a moment",
        "let me think", "let me share", "let me open", "let me create", "let me check",
        "let me see", "let me try", "let me look", "let me find", "let me just",
        "just let me", "sorry about that", "my bad"
    ]

    private static let candidateCheckPhrases = [
        "does that make sense", "is that what you're looking for", "is that what you are looking for",
        "is that okay", "is this okay", "is that clear", "i hope that helps", "i hope that answers",
        "does that answer your question", "that's all i have", "that is all i have"
    ]

    /// "Sorry, can you repeat?" is the candidate asking the interviewer, not a question to answer.
    private static let repeatRequestPhrases = [
        "can you repeat", "could you repeat", "can i repeat", "can you say that again",
        "could you say that again", "say that again", "i didn't catch that", "i didn't hear you", "come again"
    ]
    private static let repeatFillerWords: Set<String> = [
        "sorry", "please", "okay", "ok", "uh", "um", "the", "that", "again", "question", "it", "what", "so", "oh"
    ]

    /// Stalling and check-in phrases the candidate says while thinking or typing. They are never
    /// questions, so they must not open an answer card. A real question in the same breath wins.
    static func isCandidateMetaUtterance(_ text: String) -> Bool {
        let normalized = normalized(text)
        let cleaned = normalized.trimmingCharacters(in: CharacterSet(charactersIn: " .,!?:;"))
        guard !cleaned.isEmpty, cleaned.split(separator: " ").count <= 16 else { return false }
        if cleaned == "sorry" { return true }
        if let repeatPhrase = repeatRequestPhrases.first(where: { cleaned.contains($0) }) {
            let remainder = cleaned.replacingOccurrences(of: repeatPhrase, with: " ")
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { !repeatFillerWords.contains($0) }
            return remainder.count <= 2
        }
        guard let phrase = (candidateStallPhrases + candidateCheckPhrases).first(where: { cleaned.contains($0) }) else {
            return false
        }
        // "give me a second" would otherwise trip the "give me ..." interviewer wording.
        return !hasInterviewerFrame(cleaned.replacingOccurrences(of: phrase, with: " "))
    }

    private static let interviewerFrame = try! NSRegularExpression(
        pattern: #"\b(what|how|why|when|where|which|who)\s+(is|are|was|were|do|does|did|would|will|can|could|should|has|have|about|kind|type|else|exactly|if)\b|\b(why|how)\s+(this|that|your)\b|\b(can|could|would|will|do|did|have|are|is)\s+(you|your)\b|\b(would|could|can|will|should|is|are|was|were)\s+(it|this|that|there|we|i|they)\b|\b(tell|show|give|walk|talk)\s+(me|us)\b|\b(explain|describe|compare|elaborate)\b|\b(let's|lets|let us)\s+(start|begin|talk|discuss|go|move|proceed|jump)\b"#
    )

    /// Wording that only an interviewer aims at the candidate ("how do you", "can you", "tell me").
    /// Deliberately generous: a miss here only means a candidate remark still gets an answer card,
    /// while a false hit on a real question would drop it.
    static func hasInterviewerFrame(_ normalized: String) -> Bool {
        let range = NSRange(normalized.startIndex..., in: normalized)
        return interviewerFrame.firstMatch(in: normalized, range: range) != nil
    }

    private static let firstPersonWord = try! NSRegularExpression(
        pattern: #"\b(i|i'm|im|i've|ive|i'd|i'll|we|we're|we've|we'd|my|our|me|myself)\b"#
    )

    private static let answerOpeners = [
        "yeah", "yes", "yep", "well", "nope", "mostly", "basically", "actually", "honestly",
        "to be honest", "for me", "in my", "for example", "like for example", "something like",
        "so basically", "i think", "i guess", "i believe", "probably", "it depends", "depending on"
    ]

    /// Transcription often puts a question mark after these ("...and what?"), so it does not finish them.
    private static let trailingQuestionWords = ["and what", "and how", "and why", "and which", "and where", "and when"]
    private static let trailingConnectives = trailingQuestionWords + ["let's say", "kind of", "sort of"]
    private static let trailingPunctuation = CharacterSet(charactersIn: ".,…? ")
    private static let questionOpeners: Set<String> = [
        "what", "how", "why", "when", "where", "which", "who", "whose",
        "can", "could", "do", "does", "did", "is", "are", "should", "would"
    ]
    /// Short names a real spoken list is made of, which the technical token table does not cover.
    private static let familiarListWords: Set<String> = [
        "python", "java", "go", "rust", "swift", "kotlin", "ruby", "scala", "php", "perl", "c", "sql",
        "react", "vue", "node", "docker", "redis", "kafka", "aws", "azure", "gcp", "linux", "git"
    ]

    /// Speech that stops mid-thought: an ellipsis, or a connective with nothing after it.
    private static let followUpPhrases = [
        "tell me more", "dig deeper", "go deeper", "elaborate", "expand on", "more details", "more about",
        "what about", "how about", "what else", "anything else", "give me an example"
    ]

    private static let codeReferencePhrases = [
        "did you", "you used", "you chose", "you wrote", "your solution", "your code", "this code", "that code",
        "the code", "this function", "the function", "version", "complexity"
    ]

    /// Whether a question carries on from the one before it: the classifier called it a follow-up, it
    /// stays on the same topic, or it only makes sense after something ("what about…", "write it in…").
    static func followsPrevious(question: String, topic: String, previousTopic: String?) -> Bool {
        guard let previousTopic else { return false }
        let topic = topic.lowercased()
        if topic == "followup" { return true }
        if topic != "unknown", topic != "answer", topic == previousTopic.lowercased() { return true }
        let lowered = question.lowercased()
        // After code, a question about what was written ("why did you use slicing") is about that code.
        if previousTopic.lowercased() == "coding", codeReferencePhrases.contains(where: { lowered.contains($0) }) { return true }
        return followUpPhrases.contains { lowered.contains($0) } || refersBackToConversation(question)
    }

    static func trailsOff(_ text: String) -> Bool {
        let lowered = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowered.isEmpty else { return false }
        let bare = lowered.trimmingCharacters(in: trailingPunctuation)
        if lowered.hasSuffix("?") { return trailingQuestionWords.contains { bare.hasSuffix(" \($0)") } }
        if lowered.hasSuffix("...") || lowered.hasSuffix("…") { return true }
        return trailingConnectives.contains { bare.hasSuffix(" \($0)") }
    }

    /// A question that stops on a comma or trails off may go on, or may be all the interviewer says. It
    /// waits for more speech, and is answered without the unfinished tail if silence follows.
    static func heldQuestion(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix(",") || trailsOff(trimmed) else { return nil }
        var question = trimmed.trimmingCharacters(in: trailingPunctuation)
        while let tail = trailingConnectives.first(where: { question.lowercased().hasSuffix(" \($0)") }) {
            question = String(question.dropLast(tail.count + 1)).trimmingCharacters(in: trailingPunctuation)
        }
        return question.isEmpty ? nil : question
    }

    /// A short fragment right after a question carries that question on ("kind of, let's say,"), so it
    /// is heard as part of it. Anything that opens a question of its own stands alone.
    static func continuedQuestion(
        previous: String?,
        fragment: String,
        secondsSincePrevious: TimeInterval?,
        window: TimeInterval
    ) -> String? {
        guard let previous, !previous.isEmpty,
              let secondsSincePrevious, secondsSincePrevious <= window,
              !fragment.contains("?") else { return nil }
        let words = normalized(fragment).split(separator: " ").map(String.init)
        guard let first = words.first, words.count <= 6, !questionOpeners.contains(first) else { return nil }
        return "\(previous) \(fragment)"
    }

    /// Transcription that broke mumbled speech into a run of scraps: "Aki, di, sari, u, gontu, yus?" or
    /// "Aki, D, sorry, U, gone to, yas?". The caller rules out real lists by their topic.
    static func looksGarbled(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        let pieces = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard pieces.count >= 4 else { return false }
        let allScraps = pieces.allSatisfy { piece in
            let words = piece.split(separator: " ")
            return (1...2).contains(words.count) && words.allSatisfy { word in
                word.count <= 6 && word.allSatisfy { $0.isASCII && $0.isLetter }
            }
        }
        let words = pieces.flatMap { $0.split(separator: " ").map(String.init) }
        return allScraps && questionOpeners.union(familiarListWords).isDisjoint(with: words)
    }

    /// A long, first-person, question-free run of speech is the candidate answering (or the
    /// interviewer setting a scenario), not something a cue card should answer.
    static func looksLikeCandidateNarrative(_ normalized: String) -> Bool {
        let wordCount = normalized.split(separator: " ").count
        guard wordCount >= 12, !normalized.contains("?"), !hasInterviewerFrame(normalized) else { return false }
        let range = NSRange(normalized.startIndex..., in: normalized)
        let firstPerson = firstPersonWord.numberOfMatches(in: normalized, range: range)
        let hasOpener = answerOpeners.contains { normalized.hasPrefix($0) }
        return firstPerson >= 2 || (hasOpener && (firstPerson >= 1 || wordCount >= 16))
    }

    // MARK: - Back-references

    private static let backReferencePhrases = [
        "you mean", "you meant", "you said", "you mentioned", "we talked", "we discussed",
        "as we said", "as we discussed", "go on", "and then", "what next", "next step",
        "what do you mean", "which one", "which ones", "what else", "anything else",
        "what about", "how about"
    ]

    private static let anaphoraWords: Set<String> = [
        "it", "this", "these", "those", "them", "they", "same", "above", "earlier",
        "mentioned", "again"
    ]

    private static let anaphoricThat = try! NSRegularExpression(
        pattern: #"\b(by|about|of|on|with|for|is|does|do|did|explain|mean|use|used)\s+that\b|\bthat$"#
    )

    /// Words that carry no subject of their own: pronouns, auxiliaries, question words, request
    /// verbs, and discourse filler. A question made only of these depends on the previous turn.
    private static let subjectlessWords: Set<String> = [
        "i", "you", "we", "he", "she", "they", "it", "me", "us", "my", "your", "our", "their", "its",
        "is", "are", "was", "were", "be", "been", "being", "am", "do", "does", "did", "done",
        "have", "has", "had", "can", "could", "would", "will", "shall", "should", "may", "might", "must",
        "not", "no", "yes", "yeah", "yep", "ok", "okay", "so", "well", "anyway", "actually", "basically",
        "just", "really", "then", "now", "also", "still", "maybe", "please", "sorry", "thanks", "thank",
        "hi", "hello", "what", "how", "why", "when", "where", "which", "who", "whom", "whose", "whether",
        "if", "the", "and", "for", "with", "from", "about", "into", "over", "than", "but", "like", "that",
        "this", "these", "those", "there", "here", "some", "any", "all", "more", "other", "another",
        "get", "got", "go", "going", "gone", "come", "start", "starting", "begin", "next", "expect",
        "expecting", "approach", "handle", "deal", "think", "thinking", "see", "look", "say", "tell",
        "ask", "know", "want", "need", "make", "take", "put", "give", "work", "works", "working",
        "thing", "things", "stuff", "something", "anything", "everything", "way", "ways", "time",
        "explain", "describe", "elaborate", "expand", "details", "deeper", "detail", "example",
        "else", "same", "again", "mean", "meant", "kind", "sort", "let", "lets", "whats", "thats",
        "hows", "dont", "doesnt", "didnt", "cant", "wont", "isnt", "arent", "youre", "weve", "theres",
        "one", "ones", "much", "many", "very", "too", "out", "off", "under", "own"
    ]

    /// True when the utterance has no subject of its own or points back at the last exchange
    /// ("Have you used any of these?", "Where do we start?", "Tell me more"). Such a prompt may
    /// inherit the previous topic; a concrete new question must be answered from its own words.
    static func refersBackToConversation(_ text: String) -> Bool {
        let normalized = normalized(text)
        guard !normalized.isEmpty else { return false }

        // Non-Latin scripts keep the earlier behaviour: the English word lists below cannot judge them.
        let letters = normalized.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        if !letters.isEmpty {
            let nonLatin = letters.filter { $0.value > 0x024F }.count
            if Double(nonLatin) / Double(letters.count) > 0.3 { return true }
        }

        if backReferencePhrases.contains(where: { normalized.contains($0) }) { return true }

        let words = normalized
            .replacingOccurrences(of: "'", with: "")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        let contentWords = words.filter { $0.count >= 3 && !subjectlessWords.contains($0) }
        if contentWords.isEmpty { return true }

        if words.count <= 8, words.contains(where: { anaphoraWords.contains($0) }) { return true }
        // A short fragment with no question wording ("Frameboards? Script, yeah. Well, used Spring")
        // is a clarification of what was just asked, not a new question.
        if words.count <= 10, !hasInterviewerFrame(normalized) { return true }
        guard words.count <= 10 else { return false }
        let trimmed = normalized.trimmingCharacters(in: CharacterSet(charactersIn: " .,!?:;\"'"))
        return anaphoricThat.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
    }
}

/// Prompt fragments shared by the fast answer paths, so a stale topic can never steer a new question.
enum AnswerPromptBlocks {
    /// Shared voice for interview prose; each caller keeps its own answer or coding format.
    static let candidateVoice = """
    CANDIDATE VOICE:
    - Point first. Short, direct sentences, everyday words, natural contractions.
    - One point at a time. Give the action, then the reason or one concrete example.
    - Sound like a colleague explaining their approach. No sales language or textbook padding.
    - Say "use", "check", "fix"; avoid "leverage", "facilitate", "robust solution".
    - For an approach, say "I'd check..." or "I'd use...". State definitions directly.
    - Say "I use" or "I did" only when the CV in this prompt supports it. Never invent experience.
    - Keep technical terms exact and limitations that change the answer; skip generic hedges.
    - No "I'd say", "I would answer it as", intros or closing summaries.
    - Example: "Keep the result in a cache so you don't fetch it again."
    """

    struct Topic: Equatable {
        /// The "TOPIC: x" line, or nothing when there is no reliable topic.
        let line: String
        /// What the model should do when the transcript looks garbled.
        let garbleNote: String
        /// Topic-specific answer shapes (SOLID letters, RAG flow) only fit a topic named in this question.
        let allowsTopicSpecificShape: Bool
    }

    private static let answerAsAsked = "The transcript may contain speech-to-text errors. Answer the question as asked."

    static func topic(_ topic: String, inherited: Bool) -> Topic {
        let lower = topic.lowercased()
        if lower.isEmpty || lower == "unknown" {
            return Topic(line: "", garbleNote: answerAsAsked, allowsTopicSpecificShape: false)
        }
        if inherited {
            return Topic(
                line: "PREVIOUS TOPIC (only if the question refers back to it): \(topic)",
                garbleNote: answerAsAsked,
                allowsTopicSpecificShape: false
            )
        }
        return Topic(
            line: "TOPIC: \(topic)",
            garbleNote: "The transcript may contain speech-to-text errors. Trust TOPIC when words are garbled.",
            allowsTopicSpecificShape: true
        )
    }

    /// `extendsPreviousAnswer` is for "tell me more"; otherwise the conversation only resolves references.
    static func recentConversation(_ context: String?, extendsPreviousAnswer: Bool) -> String {
        guard let trimmed = context?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, trimmed != "No previous conversation." else { return "" }
        let instruction = extendsPreviousAnswer
            ? "This is a follow-up on the same topic. Add new, deeper points or a concrete example; do NOT repeat what was already covered."
            : "Use the conversation only to work out what words like \"it\", \"that\" or \"these\" refer to. Answer the CURRENT question, not an earlier one."
        return "\n=== CONVERSATION SO FAR ===\n\(trimmed)\n=== END CONVERSATION ===\n\n\(instruction)\n"
    }

    /// The code the candidate is typing, so "why did you use a dict?" is answered about that code.
    static func pinnedCode(_ solution: String?, limit: Int = 1800) -> String {
        guard let trimmed = solution?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return "" }
        let body = trimmed.count > limit ? String(trimmed.prefix(limit)) + "\n…" : trimmed
        return "\nCODE THE CANDIDATE IS WRITING (answer in this context when the question is about it):\n\(body)\n"
    }
}
