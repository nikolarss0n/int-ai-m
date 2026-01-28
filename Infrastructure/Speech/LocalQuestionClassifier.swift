import Foundation

/// Classification result from local analysis
struct LocalClassification {
    enum Status {
        case question       // Direct question or request for information
        case incomplete     // Sentence cut off mid-way
        case statement      // Complete statement, not asking anything
        case filler         // Noise, greetings, fillers
    }

    let status: Status
    let confidence: Double  // 0.0 - 1.0
    let reason: String      // Debug info
}

/// Ultra-fast local question classifier
/// Runs in <1ms, no API calls
/// Designed to sit between Deepgram streaming and Claude
class LocalQuestionClassifier {

    // MARK: - Main Classification

    /// Classify text instantly (<1ms)
    /// Returns whether this is a question that should be sent to Claude
    func classify(_ text: String) -> LocalClassification {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        guard !trimmed.isEmpty else {
            return LocalClassification(status: .filler, confidence: 1.0, reason: "empty")
        }

        // 1. Check for fillers first (fastest rejection)
        if let fillerResult = checkFiller(lower, original: trimmed) {
            return fillerResult
        }

        // 2. Check for incomplete sentences
        if let incompleteResult = checkIncomplete(lower, original: trimmed) {
            return incompleteResult
        }

        // 3. Check for questions (main logic)
        if let questionResult = checkQuestion(lower, original: trimmed) {
            return questionResult
        }

        // 4. Default: statement
        return LocalClassification(status: .statement, confidence: 0.6, reason: "no question markers")
    }

    // MARK: - Filler Detection

    private func checkFiller(_ lower: String, original: String) -> LocalClassification? {
        // Very short = likely filler
        if original.count < 4 {
            return LocalClassification(status: .filler, confidence: 0.9, reason: "too short")
        }

        // Common fillers
        let fillers = [
            "um", "uh", "hmm", "hm", "ah", "oh", "mhm", "uh-huh", "mm-hmm",
            "okay", "ok", "alright", "right", "yeah", "yes", "no", "sure",
            "got it", "i see", "i understand", "sounds good", "makes sense",
            "thank you", "thanks", "hello", "hi", "hey", "bye", "goodbye"
        ]

        let normalized = lower
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        if fillers.contains(normalized) {
            return LocalClassification(status: .filler, confidence: 0.95, reason: "common filler: \(normalized)")
        }

        // Greeting patterns (without question)
        let greetings = ["hello", "hi ", "hey ", "good morning", "good afternoon", "good evening", "welcome"]
        if greetings.contains(where: { lower.hasPrefix($0) }) && !lower.contains("?") && original.count < 50 {
            return LocalClassification(status: .filler, confidence: 0.85, reason: "greeting")
        }

        return nil
    }

    // MARK: - Incomplete Detection

    private func checkIncomplete(_ lower: String, original: String) -> LocalClassification? {
        // Ends with continuation words
        let incompleteEndings = [
            " so", " and", " but", " or", " the", " a", " an", " to", " of",
            " that", " if", " when", " is", " are", " have", " has", " can",
            " will", " for", " with", " on", " in", " about", " like", ","
        ]

        // Don't mark as incomplete if it has a question mark
        if original.contains("?") {
            return nil
        }

        if incompleteEndings.contains(where: { lower.hasSuffix($0) }) {
            return LocalClassification(status: .incomplete, confidence: 0.85, reason: "ends with continuation word")
        }

        // Very short without punctuation
        let hasEndPunctuation = original.hasSuffix(".") || original.hasSuffix("?") || original.hasSuffix("!")
        if original.count < 15 && !hasEndPunctuation {
            // But could still be a short question
            let questionWords = ["what", "how", "why", "when", "where", "which", "who"]
            if questionWords.contains(where: { lower.hasPrefix($0) }) {
                return nil // Let question check handle it
            }
            return LocalClassification(status: .incomplete, confidence: 0.7, reason: "short without punctuation")
        }

        return nil
    }

    // MARK: - Question Detection

    private func checkQuestion(_ lower: String, original: String) -> LocalClassification? {

        // Tier 1: Explicit question mark (highest confidence)
        if original.contains("?") {
            return LocalClassification(status: .question, confidence: 1.0, reason: "has ?")
        }

        // Tier 2: WH-questions (English)
        let whPatterns = [
            "what ", "what's ", "whats ",
            "how ", "how's ", "hows ",
            "why ", "why's ", "whys ",
            "when ", "when's ",
            "where ", "where's ",
            "which ", "who ", "who's ", "whose "
        ]
        if whPatterns.contains(where: { lower.hasPrefix($0) }) {
            return LocalClassification(status: .question, confidence: 0.95, reason: "WH-question")
        }

        // Tier 3: Auxiliary verb questions
        let auxPatterns = [
            "is ", "are ", "was ", "were ",
            "do ", "does ", "did ",
            "can ", "can't ", "cannot ",
            "could ", "couldn't ",
            "would ", "wouldn't ",
            "should ", "shouldn't ",
            "will ", "won't ",
            "have ", "has ", "had ",
            "am i", "is it", "are you", "are there"
        ]
        if auxPatterns.contains(where: { lower.hasPrefix($0) }) {
            return LocalClassification(status: .question, confidence: 0.85, reason: "auxiliary verb question")
        }

        // Tier 4: Imperative requests (question-like, want information)
        let requestPatterns = [
            "tell me", "tell us",
            "explain", "describe", "define",
            "walk me through", "walk us through",
            "give me an example", "give us an example", "give an example",
            "show me", "show us",
            "help me understand",
            "elaborate", "clarify",
            "talk about", "go over",
            "let's discuss", "let's talk about",
            "can you tell", "could you tell", "would you tell",
            "can you explain", "could you explain", "would you explain"
        ]
        if requestPatterns.contains(where: { lower.contains($0) }) {
            return LocalClassification(status: .question, confidence: 0.90, reason: "imperative request")
        }

        // Tier 5: Interview-specific patterns
        let interviewPatterns = [
            "difference between", "differences between",
            "compare ", "comparison ",
            "what about", "how about",
            "what if", "what would happen",
            "have you ever", "have you worked",
            "do you have experience", "do you know"
        ]
        if interviewPatterns.contains(where: { lower.contains($0) }) {
            return LocalClassification(status: .question, confidence: 0.88, reason: "interview pattern")
        }

        // Tier 6: Question words anywhere (lower confidence)
        let questionWordsAnywhere = ["what", "how", "why", "difference"]
        let containsQuestionWord = questionWordsAnywhere.contains { lower.contains($0) }

        // If contains question word AND reasonably long, might be a question
        if containsQuestionWord && original.count > 20 {
            return LocalClassification(status: .question, confidence: 0.70, reason: "contains question word")
        }

        // Tier 7: Multilingual question detection
        let multilingualPatterns = [
            // Bulgarian
            "какво", "как", "защо", "кога", "къде", "кой", "коя", "кое", "кои",
            "разкажи", "обясни", "опиши",
            // German
            "was ", "wie ", "warum", "wann", "wo ", "wer ", "welche",
            // French
            "qu'est", "comment", "pourquoi", "quand", "où ", "qui ",
            // Spanish
            "qué ", "cómo", "por qué", "cuándo", "dónde", "quién"
        ]
        if multilingualPatterns.contains(where: { lower.contains($0) }) {
            return LocalClassification(status: .question, confidence: 0.90, reason: "multilingual question")
        }

        return nil
    }

    // MARK: - Convenience

    /// Quick check: is this a question that should trigger Claude?
    func isQuestion(_ text: String) -> Bool {
        let result = classify(text)
        return result.status == .question
    }

    /// Quick check: is this incomplete and should be buffered?
    func isIncomplete(_ text: String) -> Bool {
        let result = classify(text)
        return result.status == .incomplete
    }

    /// Quick check: should this be skipped entirely?
    func shouldSkip(_ text: String) -> Bool {
        let result = classify(text)
        return result.status == .filler
    }
}
