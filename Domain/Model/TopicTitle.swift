import Foundation

/// The words for a topic the classifier named in camelCase ("systemDesign", "llm", "ragCag"). The answer
/// card, the timeline pill and an export all show it, and `capitalized` alone turns those into
/// "Systemdesign", "Llm" and "Rag Cag".
enum TopicTitle {
    /// The card's title before any topic is known.
    static let unknown = "Live answer"

    /// Whole topics that read better as a phrase than as their words joined.
    private static let phrases: [String: String] = [
        "ragcag": "RAG and CAG",
        "followup": "Follow-up",
        "kmeans": "K-means",
        "genai": "Generative AI",
        "finetuning": "Fine-tuning",
        "biasvariance": "Bias-variance",
        "crossvalidation": "Cross-validation",
        "precisionrecall": "Precision and recall",
        "webfirstassertions": "Web-first assertions",
        "autowaiting": "Auto-waiting",
        "langchain": "LangChain",
        "huggingface": "Hugging Face",
        "playwrighttest": "Playwright Test"
    ]

    /// Words that are names or acronyms, written the way they are written everywhere else.
    private static let words: [String: String] = [
        "ai": "AI", "api": "API", "aws": "AWS", "cag": "CAG", "cicd": "CI/CD", "cpp": "C++", "csharp": "C#",
        "dbscan": "DBSCAN", "devops": "DevOps", "dotnet": ".NET", "e2e": "E2E", "fastapi": "FastAPI",
        "graphql": "GraphQL", "javascript": "JavaScript", "jvm": "JVM", "linq": "LINQ", "llm": "LLM",
        "ml": "ML", "mlops": "MLOps", "nlp": "NLP", "nosql": "NoSQL", "oop": "OOP", "auc": "AUC", "pr": "PR",
        "rag": "RAG", "rest": "REST", "roc": "ROC", "solid": "SOLID", "sql": "SQL", "stl": "STL",
        "swiftui": "SwiftUI", "typescript": "TypeScript", "ui": "UI", "uikit": "UIKit"
    ]

    /// "systemDesign" becomes "System design", "llmEvaluation" "LLM evaluation", "csharp" "C#".
    static func display(_ topic: String) -> String {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "unknown" else { return unknown }
        let key = trimmed.lowercased().filter { $0.isLetter || $0.isNumber }
        if let phrase = phrases[key] { return phrase }
        let parts = split(trimmed)
        return parts.enumerated().map { index, part in
            let lowered = part.lowercased()
            if let name = words[lowered] { return name }
            return index == 0 ? lowered.prefix(1).uppercased() + lowered.dropFirst() : lowered
        }.joined(separator: " ")
    }

    /// The words of a camelCase or snake_case name. A run of capitals is one word ("genAI" is "gen", "AI"),
    /// and digits stay with the letters before them ("f1Score" is "f1", "Score").
    static func split(_ topic: String) -> [String] {
        var parts: [String] = []
        var current = ""
        let characters = Array(topic)
        for (index, character) in characters.enumerated() {
            if character == "_" || character == "-" || character == " " {
                if !current.isEmpty { parts.append(current) }
                current = ""
                continue
            }
            if character.isUppercase, let previous = current.last {
                let next = index + 1 < characters.count ? characters[index + 1] : nil
                let endsWord = previous.isLowercase || previous.isNumber || (previous.isUppercase && next?.isLowercase == true)
                if endsWord {
                    parts.append(current)
                    current = ""
                }
            }
            current.append(character)
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }
}
