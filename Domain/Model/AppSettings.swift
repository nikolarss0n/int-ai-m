import Foundation

// MARK: - Interview Role

/// Role/position being interviewed for
enum InterviewRole: String, CaseIterable {
    case seniorQAEngineer = "senior_qa_engineer"
    case qaEngineer = "qa_engineer"
    case qaAutomationEngineer = "qa_automation_engineer"
    case sdet = "sdet"
    case backendDeveloper = "backend_developer"
    case seniorBackendDeveloper = "senior_backend_developer"
    case frontendDeveloper = "frontend_developer"
    case seniorFrontendDeveloper = "senior_frontend_developer"
    case fullStackDeveloper = "fullstack_developer"
    case seniorFullStackDeveloper = "senior_fullstack_developer"
    case devOpsEngineer = "devops_engineer"
    case dataEngineer = "data_engineer"
    case mlEngineer = "ml_engineer"
    case aiEngineer = "ai_engineer"
    case seniorAIEngineer = "senior_ai_engineer"
    case softwareEngineer = "software_engineer"
    case seniorSoftwareEngineer = "senior_software_engineer"

    static let selectableCases: [InterviewRole] = [
        .qaEngineer,
        .qaAutomationEngineer,
        .seniorQAEngineer,
        .backendDeveloper,
        .seniorBackendDeveloper,
        .frontendDeveloper,
        .seniorFrontendDeveloper,
        .fullStackDeveloper,
        .seniorFullStackDeveloper,
        .devOpsEngineer,
        .dataEngineer,
        .mlEngineer,
        .aiEngineer,
        .seniorAIEngineer,
        .softwareEngineer,
        .seniorSoftwareEngineer
    ]

    var canonicalRole: InterviewRole {
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
        case .seniorBackendDeveloper: return "Senior Backend Developer"
        case .frontendDeveloper: return "Frontend Developer"
        case .seniorFrontendDeveloper: return "Senior Frontend Developer"
        case .fullStackDeveloper: return "Full Stack Developer"
        case .seniorFullStackDeveloper: return "Senior Full Stack Developer"
        case .devOpsEngineer: return "DevOps Engineer"
        case .dataEngineer: return "Data Engineer"
        case .mlEngineer: return "ML Engineer"
        case .aiEngineer: return "AI Engineer"
        case .seniorAIEngineer: return "Senior AI Engineer"
        case .softwareEngineer: return "Software Engineer"
        case .seniorSoftwareEngineer: return "Senior Software Engineer"
        }
    }

    var isSenior: Bool {
        return canonicalRole.rawValue.contains("senior")
    }

    var isQA: Bool {
        switch canonicalRole {
        case .qaEngineer, .qaAutomationEngineer, .seniorQAEngineer:
            return true
        default:
            return false
        }
    }

    var qaProfileLabel: String {
        switch canonicalRole {
        case .qaEngineer:
            return "QA Engineer"
        case .qaAutomationEngineer:
            return "QA Automation / SDET"
        case .seniorQAEngineer:
            return "Senior QA / SDET"
        default:
            return displayName
        }
    }

    var qaSeniorityInstruction: String {
        switch canonicalRole {
        case .qaEngineer:
            return "QA EMPHASIS: practical testing judgment, clear bug reporting, API/UI basics, and when manual exploration is better than automation."
        case .qaAutomationEngineer:
            return "QA EMPHASIS: Playwright implementation, fixtures, locators, CI, API setup, mocking, and stable automation design."
        case .seniorQAEngineer:
            return "QA EMPHASIS: quality strategy, ownership, release risk, automation architecture, mentoring, observability, and maintainable CI feedback loops."
        default:
            return ""
        }
    }
}

// MARK: - Programming Language

/// Primary programming language for code solutions
enum ProgrammingLanguage: String, CaseIterable {
    case python = "python"
    case typescript = "typescript"
    case javascript = "javascript"
    case java = "java"
    case csharp = "csharp"
    case go = "go"
    case rust = "rust"
    case cpp = "cpp"
    case kotlin = "kotlin"
    case swift = "swift"

    var displayName: String {
        switch self {
        case .python: return "Python"
        case .typescript: return "TypeScript"
        case .javascript: return "JavaScript"
        case .java: return "Java"
        case .csharp: return "C#"
        case .go: return "Go"
        case .rust: return "Rust"
        case .cpp: return "C++"
        case .kotlin: return "Kotlin"
        case .swift: return "Swift"
        }
    }

    /// Code block language identifier
    var codeBlockLang: String {
        return rawValue
    }
}

// MARK: - Speaking Language

/// Language for AI responses (code stays in English)
enum SpeakingLanguage: String, CaseIterable {
    case english = "en"
    case bulgarian = "bg"
    case german = "de"
    case spanish = "es"
    case french = "fr"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case dutch = "nl"
    case polish = "pl"
    case turkish = "tr"
    case hindi = "hi"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .bulgarian: return "Bulgarian"
        case .german: return "German"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .russian: return "Russian"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .dutch: return "Dutch"
        case .polish: return "Polish"
        case .turkish: return "Turkish"
        case .hindi: return "Hindi"
        }
    }
}

// MARK: - App Settings

/// Global app settings with UserDefaults persistence
class AppSettings {
    static let shared = AppSettings()

    private let roleKey = "InterviewMaster.Role"
    private let programmingLanguageKey = "InterviewMaster.ProgrammingLanguage"
    private let listeningLanguageKey = "InterviewMaster.ListeningLanguage"
    private let responseLanguageKey = "InterviewMaster.ResponseLanguage"
    private let speakingLanguageKey = "InterviewMaster.SpeakingLanguage"
    private let frameworksKey = "InterviewMaster.Frameworks"

    // Legacy keys for migration
    private let legacyLanguageKey = "InterviewMaster.Language"
    private let legacyTechStackKey = "InterviewMaster.TechStack"

    private init() {
        migrateIfNeeded()
        migrateLanguageSplitIfNeeded()
        normalizeRoleIfNeeded()
    }

    // MARK: - Role

    var role: InterviewRole {
        get {
            guard let code = UserDefaults.standard.string(forKey: roleKey),
                  let role = InterviewRole(rawValue: code) else {
                return .seniorQAEngineer
            }
            return role.canonicalRole
        }
        set {
            UserDefaults.standard.set(newValue.canonicalRole.rawValue, forKey: roleKey)
        }
    }

    // MARK: - Programming Language

    var programmingLanguage: ProgrammingLanguage {
        get {
            guard let code = UserDefaults.standard.string(forKey: programmingLanguageKey),
                  let lang = ProgrammingLanguage(rawValue: code) else {
                return .python
            }
            return lang
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: programmingLanguageKey)
        }
    }

    // MARK: - Listening / Response Language

    var listeningLanguage: SpeakingLanguage {
        get {
            guard let code = UserDefaults.standard.string(forKey: listeningLanguageKey),
                  let lang = SpeakingLanguage(rawValue: code) else {
                return .english
            }
            return lang
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: listeningLanguageKey)
        }
    }

    var responseLanguage: SpeakingLanguage {
        get {
            guard let code = UserDefaults.standard.string(forKey: responseLanguageKey),
                  let lang = SpeakingLanguage(rawValue: code) else {
                return .english
            }
            return lang
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: responseLanguageKey)
            UserDefaults.standard.set(newValue.rawValue, forKey: speakingLanguageKey)
        }
    }

    /// Legacy name kept for existing call sites and stored sessions.
    var speakingLanguage: SpeakingLanguage {
        get { return responseLanguage }
        set { responseLanguage = newValue }
    }

    // MARK: - Frameworks/Tech Stack

    /// Comma-separated list of frameworks/tools (e.g., "Playwright, Pytest, AWS")
    var frameworks: String {
        get {
            return UserDefaults.standard.string(forKey: frameworksKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: frameworksKey)
        }
    }

    /// Frameworks as array
    var frameworksList: [String] {
        return frameworks
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var isTestAutomationRole: Bool {
        return role.isQA
    }

    var effectiveFrameworks: String {
        let trimmed = frameworks.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && isTestAutomationRole {
            return "Playwright, TypeScript, API Testing, CI"
        }
        return trimmed
    }

    var isPlaywrightFocused: Bool {
        let lowerFrameworks = frameworks.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return isTestAutomationRole && (lowerFrameworks.isEmpty || lowerFrameworks.contains("playwright"))
    }

    // MARK: - Convenience Properties

    /// Full context string for prompts
    var interviewContext: String {
        var context = "Position: \(role.displayName)\n"
        if isTestAutomationRole {
            context += "Prompt Profile: Shared QA/SDET Playwright\n"
            context += "QA Level: \(role.qaProfileLabel)\n"
        }
        context += "Programming Language: \(programmingLanguage.displayName)\n"
        context += "Listening Language: \(listeningLanguage.displayName)\n"
        context += "Response Language: \(responseLanguage.displayName)"
        let stack = effectiveFrameworks
        if !stack.isEmpty {
            context += "\nTech Stack: \(stack)"
        }
        return context
    }

    var answerStyleInstruction: String {
        var instruction = """
        INTERVIEW ANSWER STYLE:
        - Answer as a spoken candidate answer, not as a textbook note.
        - Return cue-card bullets only: 3-5 lines, every line starts with "- ".
        - Each bullet should be short enough to read while speaking, ideally under 90 characters.
        - No paragraphs. No long explanations. No markdown headings.
        - For experience/profile questions, first bullet must be the headline: "8+ years..." or similar.
        - No headings, markdown section labels, preambles, or filler.
        - Prefer concrete trade-offs, examples, and one senior signal over textbook lists.
        - If the transcript is noisy, answer the likely topic confidently.

        CANDIDATE VOICE:
        - Keep it plain, practical, and concise, like I would say it in an interview.
        - Use first person when natural: "I usually...", "I would...", "For me...".
        - Do not over-polish. Avoid corporate wording, long definitions, and generic buzzwords.
        - Give the point first, then one example, trade-off, or real testing/coding habit.
        - If there are several points, pick the strongest 2-3 instead of listing everything.
        """

        if isTestAutomationRole {
            instruction += """

            TEST AUTOMATION FOCUS:
            - Use the shared QA/SDET Playwright profile for every QA role.
            - \(role.qaSeniorityInstruction)
            - Default to Playwright unless the question names another automation framework.
            - Mention locators, fixtures/test data, page objects, mocking, flake prevention, traces, or app-vs-test triage when relevant.
            - For strategy questions, cover risk, coverage level, maintainability, and pipeline feedback speed.
            """
        }

        if isPlaywrightFocused {
            instruction += """

            PLAYWRIGHT DEFAULTS:
            - Prefer web-first assertions like `await expect(locator).toBeVisible()` over manual waits.
            - Prefer `getByRole`, `getByLabel`, and stable `data-testid` locators over CSS/XPath.
            - Mention fixtures, `storageState`, browser contexts, `page.route`, trace viewer, projects, workers, retries, and sharding when relevant.
            - For flaky tests: remove `waitForTimeout`, isolate data, check async UI state, and use trace/network artifacts to separate app bugs from test bugs.
            """
        }

        return instruction
    }

    /// Language instruction for LLM
    var languageInstruction: String {
        if responseLanguage == .english {
            return "OUTPUT LANGUAGE: English. Answer every candidate-facing bullet in English."
        }
        return """
        OUTPUT LANGUAGE: \(responseLanguage.displayName).
        Answer every candidate-facing bullet in \(responseLanguage.displayName), even if the transcript, previous cards, or examples are in another language.
        Keep code, commands, API names, framework names, and short technical identifiers in English.
        """
    }

    /// Code block language for solutions
    var codeLanguage: String {
        return programmingLanguage.codeBlockLang
    }

    /// Language code for Whisper API (e.g., "en", "bg", "de")
    var languageCode: String {
        return listeningLanguage.rawValue
    }

    // MARK: - Legacy Compatibility

    /// Legacy property for backwards compatibility
    var language: SpeakingLanguage {
        get { return responseLanguage }
        set { responseLanguage = newValue }
    }

    /// Legacy property - maps to programming language
    var techStack: LegacyTechStack {
        get {
            // Map programming language to legacy tech stack
            switch programmingLanguage {
            case .python:
                return isTestAutomationRole ? .qaPython : .python
            case .typescript:
                return isTestAutomationRole ? .qaTypeScript : .typescript
            case .javascript: return .javascript
            case .java: return .java
            case .csharp: return .csharp
            case .go: return .go
            case .rust: return .rust
            case .cpp: return .cpp
            default: return .general
            }
        }
        set {
            // Map legacy tech stack to new settings
            switch newValue {
            case .qaPython:
                programmingLanguage = .python
                if !role.isQA { role = .qaAutomationEngineer }
            case .qaTypeScript:
                programmingLanguage = .typescript
                if !role.isQA { role = .qaAutomationEngineer }
            case .python: programmingLanguage = .python
            case .typescript: programmingLanguage = .typescript
            case .javascript: programmingLanguage = .javascript
            case .java: programmingLanguage = .java
            case .csharp: programmingLanguage = .csharp
            case .go: programmingLanguage = .go
            case .rust: programmingLanguage = .rust
            case .cpp: programmingLanguage = .cpp
            case .general: break
            }
        }
    }

    var llmLanguageInstruction: String {
        return languageInstruction
    }

    /// Vocabulary hints for Whisper based on role and tech stack
    var whisperVocabulary: String {
        let common = "API, REST, SQL, NoSQL, Redis, Kafka, Docker, Kubernetes, microservices, CI/CD, Git, AWS, Azure, Big O, hash map, tree, graph"

        var vocab = ""

        // Add language-specific vocabulary
        switch programmingLanguage {
        case .python:
            vocab = "Python, Django, Flask, FastAPI, dictionary, generator, decorator, async await, asyncio, pytest, Pydantic, "
        case .typescript, .javascript:
            vocab = "TypeScript, JavaScript, Node.js, React, Next.js, event loop, Promise, async await, npm, Jest, "
        case .java:
            vocab = "Java, JVM, Spring Boot, Hibernate, JPA, Maven, Gradle, JUnit, HashMap, polymorphism, "
        case .csharp:
            vocab = "C#, .NET, ASP.NET, Entity Framework, LINQ, async await, Task, NuGet, xUnit, "
        case .go:
            vocab = "Go, Golang, goroutine, channel, defer, interface, struct, pointer, gin, GORM, "
        case .rust:
            vocab = "Rust, ownership, borrowing, lifetime, trait, Option, Result, tokio, cargo, "
        case .cpp:
            vocab = "C++, STL, vector, map, pointer, smart pointer, template, virtual function, CMake, "
        case .kotlin:
            vocab = "Kotlin, coroutines, suspend, data class, sealed class, Spring, Android, "
        case .swift:
            vocab = "Swift, SwiftUI, UIKit, optional, guard, protocol, extension, Combine, "
        }

        // Add role-specific vocabulary
        if isTestAutomationRole {
            vocab += "Selenium, Playwright, Cypress, locator, test id, auto-waiting, trace viewer, E2E, API testing, mocking, fixtures, test data, POM, regression, flaky test, retries, CI pipeline, "
        }

        if isPlaywrightFocused {
            vocab += "Playwright Test, getByRole, getByLabel, locator, toBeVisible, toHaveText, web-first assertion, browser context, storageState, global setup, page.route, route.fulfill, HAR, test.step, workers, sharding, codegen, "
        }

        if role.rawValue.contains("ai") || role.rawValue.contains("ml") || role.rawValue.contains("data") {
            vocab += "LLM, RAG, embeddings, vector database, LangChain, fine-tuning, prompt engineering, transformer, backpropagation, PyTorch, TensorFlow, Hugging Face, MLOps, neural network, CNN, RNN, LSTM, "
        }

        // Add custom frameworks
        if !frameworks.isEmpty {
            vocab += frameworks + ", "
        }

        if !localizedWhisperVocabulary.isEmpty {
            vocab += localizedWhisperVocabulary + ", "
        }

        return vocab + common
    }

    private var localizedWhisperVocabulary: String {
        switch listeningLanguage {
        case .bulgarian:
            return "какво е, как работи, защо, обясни, разкажи, раскажи, разлика между, хеш мап, хешмапа, хеш таблица, хеш код, ООП, ОП, обектно-ориентирано, полиморфизъм, наследяване, капсулация, автоматизация на тестове, API тестове, регресия, нестабилен тест, мокване, фикстури, локатор"
        case .german:
            return "was ist, wie funktioniert, warum, erklaere, erkläre, erzaehl, erzähl, unterschied zwischen, kannst du, koennen sie, können sie, was bedeutet, wann benutzt man, hash map, hash table, hashmap, objektorientiert, vererbung, kapselung, polymorphismus, testautomatisierung, API tests, regression, instabiler test, flaky test, mocking, fixtures, locator"
        default:
            return ""
        }
    }

    // MARK: - Migration

    private func migrateIfNeeded() {
        // Check if already migrated
        if UserDefaults.standard.string(forKey: roleKey) != nil {
            return
        }

        // Migrate from legacy tech stack
        if let legacyStack = UserDefaults.standard.string(forKey: legacyTechStackKey),
           let legacy = LegacyTechStack(rawValue: legacyStack) {
            switch legacy {
            case .qaPython:
                role = .seniorQAEngineer
                programmingLanguage = .python
                frameworks = "Playwright, Pytest, API Testing"
            case .qaTypeScript:
                role = .seniorQAEngineer
                programmingLanguage = .typescript
                frameworks = "Playwright, Jest, API Testing"
            case .python:
                role = .backendDeveloper
                programmingLanguage = .python
                frameworks = "Django, FastAPI"
            case .typescript:
                role = .frontendDeveloper
                programmingLanguage = .typescript
                frameworks = "React, Next.js"
            case .javascript:
                role = .fullStackDeveloper
                programmingLanguage = .javascript
                frameworks = "Node.js, Express, React"
            case .java:
                role = .backendDeveloper
                programmingLanguage = .java
                frameworks = "Spring Boot, Hibernate"
            case .csharp:
                role = .backendDeveloper
                programmingLanguage = .csharp
                frameworks = ".NET, Entity Framework"
            case .go:
                role = .backendDeveloper
                programmingLanguage = .go
                frameworks = "Gin, GORM"
            case .rust:
                role = .backendDeveloper
                programmingLanguage = .rust
                frameworks = "Tokio, Actix"
            case .cpp:
                role = .softwareEngineer
                programmingLanguage = .cpp
                frameworks = "STL, CMake"
            case .general:
                role = .softwareEngineer
                programmingLanguage = .python
            }
            print("✅ Migrated legacy settings to new format")
        }

        // Migrate speaking language
        if let legacyLang = UserDefaults.standard.string(forKey: legacyLanguageKey),
           let lang = SpeakingLanguage(rawValue: legacyLang) {
            listeningLanguage = lang
            responseLanguage = lang
        }
    }

    private func migrateLanguageSplitIfNeeded() {
        let defaults = UserDefaults.standard
        let legacyLanguage = defaults.string(forKey: speakingLanguageKey)
            .flatMap { SpeakingLanguage(rawValue: $0) }
            ?? defaults.string(forKey: legacyLanguageKey).flatMap { SpeakingLanguage(rawValue: $0) }
            ?? .english

        if defaults.string(forKey: listeningLanguageKey) == nil {
            defaults.set(legacyLanguage.rawValue, forKey: listeningLanguageKey)
        }

        if defaults.string(forKey: responseLanguageKey) == nil {
            defaults.set(legacyLanguage.rawValue, forKey: responseLanguageKey)
        }
    }

    private func normalizeRoleIfNeeded() {
        guard let code = UserDefaults.standard.string(forKey: roleKey),
              let storedRole = InterviewRole(rawValue: code) else { return }

        let canonical = storedRole.canonicalRole
        if canonical.rawValue != code {
            UserDefaults.standard.set(canonical.rawValue, forKey: roleKey)
        }
    }
}

// MARK: - Legacy Tech Stack (for backwards compatibility)

/// Legacy tech stack enum - kept for backwards compatibility
enum LegacyTechStack: String, CaseIterable {
    case java = "java"
    case python = "python"
    case javascript = "javascript"
    case typescript = "typescript"
    case go = "go"
    case csharp = "csharp"
    case cpp = "cpp"
    case rust = "rust"
    case qaPython = "qa_python"
    case qaTypeScript = "qa_typescript"
    case general = "general"

    var displayName: String {
        switch self {
        case .java: return "Java/Spring"
        case .python: return "Python/Django"
        case .javascript: return "JavaScript/Node"
        case .typescript: return "TypeScript/React"
        case .go: return "Go/Golang"
        case .csharp: return "C#/.NET"
        case .cpp: return "C++"
        case .rust: return "Rust"
        case .qaPython: return "QA/Python"
        case .qaTypeScript: return "QA/TypeScript"
        case .general: return "General/Mixed"
        }
    }

    var rawValue_: String { return rawValue }
}

// Legacy type aliases
typealias TechStack = LegacyTechStack
typealias AppLanguage = SpeakingLanguage
