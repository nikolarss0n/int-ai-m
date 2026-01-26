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

    var displayName: String {
        switch self {
        case .seniorQAEngineer: return "Senior QA Engineer"
        case .qaEngineer: return "QA Engineer"
        case .qaAutomationEngineer: return "QA Automation Engineer"
        case .sdet: return "SDET"
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
        return rawValue.contains("senior")
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

    /// Language code for Deepgram STT API
    var deepgramCode: String {
        switch self {
        case .english: return "en"
        case .bulgarian: return "bg"
        case .german: return "de"
        case .spanish: return "es"
        case .french: return "fr"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .russian: return "ru"
        case .chinese: return "zh"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .dutch: return "nl"
        case .polish: return "pl"
        case .turkish: return "tr"
        case .hindi: return "hi"
        }
    }
}

// MARK: - App Settings

/// Global app settings with UserDefaults persistence
class AppSettings {
    static let shared = AppSettings()

    private let roleKey = "InterviewMaster.Role"
    private let programmingLanguageKey = "InterviewMaster.ProgrammingLanguage"
    private let speakingLanguageKey = "InterviewMaster.SpeakingLanguage"
    private let frameworksKey = "InterviewMaster.Frameworks"

    // Legacy keys for migration
    private let legacyLanguageKey = "InterviewMaster.Language"
    private let legacyTechStackKey = "InterviewMaster.TechStack"

    private init() {
        migrateIfNeeded()
    }

    // MARK: - Role

    var role: InterviewRole {
        get {
            guard let code = UserDefaults.standard.string(forKey: roleKey),
                  let role = InterviewRole(rawValue: code) else {
                return .seniorQAEngineer
            }
            return role
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: roleKey)
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

    // MARK: - Speaking Language

    var speakingLanguage: SpeakingLanguage {
        get {
            guard let code = UserDefaults.standard.string(forKey: speakingLanguageKey),
                  let lang = SpeakingLanguage(rawValue: code) else {
                return .english
            }
            return lang
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: speakingLanguageKey)
        }
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

    // MARK: - Convenience Properties

    /// Full context string for prompts
    var interviewContext: String {
        var context = "Position: \(role.displayName)\n"
        context += "Programming Language: \(programmingLanguage.displayName)\n"
        context += "Response Language: \(speakingLanguage.displayName)"
        if !frameworks.isEmpty {
            context += "\nTech Stack: \(frameworks)"
        }
        return context
    }

    /// Language instruction for LLM
    var languageInstruction: String {
        if speakingLanguage == .english {
            return "Respond in English."
        }
        return "Respond in \(speakingLanguage.displayName). Code and technical terms stay in English."
    }

    /// Code block language for solutions
    var codeLanguage: String {
        return programmingLanguage.codeBlockLang
    }

    /// Language code for Whisper API (e.g., "en", "bg", "de")
    var languageCode: String {
        return speakingLanguage.rawValue
    }

    /// Language code for Deepgram - use actual language code for best recognition
    /// Note: "multi" only supports EN/ES/FR/DE/HI/RU/PT/JA/IT/NL - Bulgarian is NOT supported in multi mode
    var deepgramLanguageCode: String {
        // Use the actual language code - Deepgram supports Bulgarian as "bg"
        // English technical terms will be handled via keyterms + Claude normalization
        return speakingLanguage.deepgramCode
    }

    /// Key technical terms for Deepgram vocabulary boosting
    /// Limit: 100 keyterms, 500 tokens total
    /// Priority: English technical terms that may be spoken in non-English contexts
    /// Claude's normalization prompt will handle phonetic variations
    var deepgramKeyterms: [String] {
        // TEST: Disable keyterms for non-English to check if that's causing the error
        if speakingLanguage != .english {
            return []
        }

        var terms: [String] = []

        // ===========================================
        // TIER 1: Java Collections (most interview questions)
        // ===========================================
        let collections = [
            // Core collections with variations
            "HashMap", "hashmap", "hash map",
            "LinkedList", "linked list",
            "ArrayList", "array list",
            "TreeMap", "tree map",
            "HashSet", "hash set",
            "TreeSet", "tree set",
            "LinkedHashMap", "linked hash map",
            "ConcurrentHashMap", "concurrent hash map",
            "PriorityQueue", "priority queue",

            // Methods (often mispronounced)
            "hashCode", "hash code",
            "equals",
            "compareTo", "compare to",
            "Comparable", "Comparator"
        ]
        terms.append(contentsOf: collections)

        // ===========================================
        // TIER 2: HashMap internals (favorite drill topic)
        // ===========================================
        let hashmapInternals = [
            "bucket", "buckets",
            "collision", "hash collision",
            "load factor",
            "treeification",
            "Red-Black Tree", "red black tree",
            "rehashing", "rehash",
            "capacity", "initial capacity",
            "threshold"
        ]
        terms.append(contentsOf: hashmapInternals)

        // ===========================================
        // TIER 3: Complexity (very common in interviews)
        // ===========================================
        let complexity = [
            "Big O", "big O notation",
            "O of 1", "O of one", "constant time",
            "O of n", "O of N", "linear time",
            "O of log n", "logarithmic",
            "O of n log n",
            "O of n squared", "quadratic",
            "amortized", "amortized complexity",
            "time complexity", "space complexity",
            "worst case", "average case", "best case"
        ]
        terms.append(contentsOf: complexity)

        // ===========================================
        // TIER 4: Algorithms
        // ===========================================
        let algorithms = [
            "quicksort", "quick sort",
            "mergesort", "merge sort",
            "heapsort", "heap sort",
            "binary search",
            "depth first", "DFS", "depth first search",
            "breadth first", "BFS", "breadth first search",
            "recursion", "recursive",
            "iteration", "iterative"
        ]
        terms.append(contentsOf: algorithms)

        // ===========================================
        // TIER 2: Programming language specific (most mispronounced)
        // ===========================================
        switch programmingLanguage {
        case .python:
            terms.append(contentsOf: [
                "Python", "Pythonic",
                "dict", "dictionary",
                "tuple", "tuples",
                "list comprehension",
                "generator", "generators",
                "decorator", "decorators",
                "dunder", "dunder method",  // __init__ etc
                "async", "await", "asyncio",
                "pytest", "unittest",
                "FastAPI", "Django", "Flask",
                "Pydantic", "NumPy", "pandas"
            ])
        case .typescript, .javascript:
            terms.append(contentsOf: [
                "TypeScript", "JavaScript",
                "Promise", "promises",
                "async", "await",
                "callback", "callbacks",
                "closure", "closures",
                "hoisting",
                "prototype", "prototypal",
                "React", "Vue", "Angular",
                "Node.js", "Express", "Next.js",
                "npm", "yarn", "pnpm",
                "Jest", "Vitest", "Mocha"
            ])
        case .java:
            terms.append(contentsOf: [
                "Java", "JVM", "JDK", "JRE",
                "ArrayList", "HashMap", "TreeMap", "LinkedHashMap",
                "interface", "abstract class",
                "polymorphism", "inheritance", "encapsulation",
                "Spring", "Spring Boot", "Hibernate",
                "JPA", "JDBC",
                "JUnit", "Mockito",
                "Maven", "Gradle"
            ])
        case .csharp:
            terms.append(contentsOf: [
                "C#", "C sharp",
                ".NET", "dot NET", "ASP.NET",
                "LINQ", "link",
                "Entity Framework",
                "async", "await", "Task",
                "delegate", "delegates",
                "NuGet", "xUnit", "NUnit"
            ])
        case .go:
            terms.append(contentsOf: [
                "Go", "Golang",
                "goroutine", "goroutines",
                "channel", "channels",
                "defer", "panic", "recover",
                "struct", "interface",
                "pointer", "pointers",
                "slice", "slices"
            ])
        case .rust:
            terms.append(contentsOf: [
                "Rust", "Rustacean",
                "ownership", "borrowing", "borrow checker",
                "lifetime", "lifetimes",
                "trait", "traits",
                "Option", "Result",
                "unwrap", "expect",
                "cargo", "crate", "crates",
                "tokio", "async", "await"
            ])
        case .cpp:
            terms.append(contentsOf: [
                "C++", "C plus plus",
                "STL", "standard template library",
                "vector", "map", "unordered map",
                "pointer", "smart pointer",
                "unique pointer", "shared pointer",
                "template", "templates",
                "virtual", "override",
                "RAII", "move semantics"
            ])
        case .kotlin:
            terms.append(contentsOf: [
                "Kotlin",
                "coroutine", "coroutines",
                "suspend", "suspend function",
                "data class", "sealed class",
                "nullable", "null safety",
                "lateinit", "lazy"
            ])
        case .swift:
            terms.append(contentsOf: [
                "Swift", "SwiftUI", "UIKit",
                "optional", "optionals",
                "guard", "guard let",
                "if let", "unwrap",
                "protocol", "extension",
                "Combine", "async", "await"
            ])
        }

        // ===========================================
        // TIER 3: Role-specific terms
        // ===========================================
        if role.rawValue.contains("qa") {
            terms.append(contentsOf: [
                "Selenium", "WebDriver",
                "Playwright",
                "Cypress",
                "E2E", "end to end",
                "page object", "page object model", "POM",
                "fixture", "fixtures",
                "mock", "stub", "spy",
                "assertion", "assertions",
                "test pyramid",
                "regression", "smoke test"
            ])
        }

        if role.rawValue.contains("ai") || role.rawValue.contains("ml") || role.rawValue.contains("data") {
            terms.append(contentsOf: [
                "LLM", "large language model",
                "RAG", "retrieval augmented generation",
                "embedding", "embeddings",
                "vector", "vector database",
                "LangChain", "LangGraph",
                "transformer", "attention",
                "fine tuning", "fine-tuning",
                "prompt", "prompt engineering",
                "PyTorch", "TensorFlow",
                "Hugging Face"
            ])
        }

        // ===========================================
        // TIER 4: Database terms (SQL/NoSQL interview favorites)
        // ===========================================
        let database = [
            // General
            "SQL", "NoSQL",
            "MongoDB", "Mongo",
            "Postgres", "PostgreSQL",
            "MySQL", "Redis",

            // Indexes (composite index is key topic)
            "index", "indexes", "indices",
            "composite index",
            "clustered index",
            "non-clustered index", "nonclustered index",
            "covering index",
            "partial index",
            "B-tree", "B tree",

            // Transactions & ACID
            "ACID",
            "atomicity", "consistency", "isolation", "durability",
            "transaction", "transactions",
            "isolation level",
            "dirty read",
            "phantom read",
            "repeatable read",
            "read committed",
            "serializable",
            "MVCC",
            "optimistic locking", "pessimistic locking",
            "SELECT FOR UPDATE",

            // Normalization
            "normalization", "denormalization",
            "first normal form", "1NF",
            "second normal form", "2NF",
            "third normal form", "3NF"
        ]
        terms.append(contentsOf: database)

        // ===========================================
        // TIER 5: Distributed Systems
        // ===========================================
        let distributed = [
            // CAP theorem
            "CAP theorem", "CAP",
            "consistency", "availability", "partition tolerance",
            "eventual consistency",
            "strong consistency",

            // Transactions
            "two-phase commit", "2PC", "two phase commit",
            "SAGA", "SAGA pattern",
            "choreography", "orchestration",
            "outbox pattern",
            "idempotency", "idempotent",

            // Messaging
            "Kafka", "RabbitMQ",
            "message queue",
            "at least once", "at most once", "exactly once",
            "dead letter queue", "DLQ",

            // Patterns
            "circuit breaker",
            "bulkhead", "bulkhead pattern",
            "retry", "exponential backoff",
            "rate limiter", "rate limiting",
            "load balancer"
        ]
        terms.append(contentsOf: distributed)

        // ===========================================
        // TIER 6: Design patterns & concepts
        // ===========================================
        let designPatterns = [
            "LRU cache", "LRU",
            "LFU cache", "LFU",
            "singleton", "factory",
            "dependency injection",
            "SOLID",
            "single responsibility",
            "open closed",
            "Liskov substitution",
            "interface segregation",
            "dependency inversion"
        ]
        terms.append(contentsOf: designPatterns)

        // ===========================================
        // TIER 7: Common infrastructure
        // ===========================================
        let infrastructure = [
            "API", "REST", "RESTful",
            "GraphQL",
            "Docker", "Kubernetes", "K8s",
            "microservices", "microservice",
            "CI/CD", "CI CD",
            "Git", "GitHub", "GitLab",
            "AWS", "Azure", "GCP"
        ]
        terms.append(contentsOf: infrastructure)

        // ===========================================
        // TIER 8: Custom frameworks from settings
        // ===========================================
        terms.append(contentsOf: frameworksList)

        // Deduplicate and limit to 100 terms (Deepgram limit)
        let uniqueTerms = Array(Set(terms))
        return Array(uniqueTerms.prefix(100))
    }

    // MARK: - Legacy Compatibility

    /// Legacy property for backwards compatibility
    var language: SpeakingLanguage {
        get { return speakingLanguage }
        set { speakingLanguage = newValue }
    }

    /// Legacy property - maps to programming language
    var techStack: LegacyTechStack {
        get {
            // Map programming language to legacy tech stack
            switch programmingLanguage {
            case .python:
                return role.rawValue.contains("qa") ? .qaPython : .python
            case .typescript:
                return role.rawValue.contains("qa") ? .qaTypeScript : .typescript
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
                if !role.rawValue.contains("qa") { role = .seniorQAEngineer }
            case .qaTypeScript:
                programmingLanguage = .typescript
                if !role.rawValue.contains("qa") { role = .seniorQAEngineer }
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
        let common = "API, REST, GraphQL, SQL, NoSQL, MongoDB, Redis, Kafka, Docker, Kubernetes, microservices, CI/CD, Git, AWS, Azure, GCP, Big O notation, binary search, recursion, dynamic programming, linked list, hash map, tree, graph, queue, stack, heap"

        var vocab = ""

        // Add language-specific vocabulary
        switch programmingLanguage {
        case .python:
            vocab = "Python, Django, Flask, FastAPI, list comprehension, dictionary, tuple, set, generator, decorator, async await, asyncio, pip, pytest, Pydantic, "
        case .typescript, .javascript:
            vocab = "TypeScript, JavaScript, Node.js, React, Angular, Vue, Next.js, closure, hoisting, event loop, Promise, async await, npm, Jest, "
        case .java:
            vocab = "Java, JVM, Spring Boot, Hibernate, JPA, Maven, Gradle, JUnit, ArrayList, HashMap, polymorphism, inheritance, "
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
        if role.rawValue.contains("qa") {
            vocab += "Selenium, Playwright, Cypress, WebDriver, test automation, E2E, end-to-end testing, integration testing, unit testing, mocking, fixtures, page object model, POM, test strategy, regression testing, smoke testing, test pyramid, BDD, TDD, "
        }

        if role.rawValue.contains("ai") || role.rawValue.contains("ml") || role.rawValue.contains("data") {
            vocab += "LLM, RAG, embeddings, vector database, LangChain, fine-tuning, prompt engineering, transformer, backpropagation, PyTorch, TensorFlow, Hugging Face, MLOps, neural network, CNN, RNN, LSTM, "
        }

        // Add common English interview phrases (always useful as Whisper context)
        vocab += "what is, how does, explain, describe, tell me about, difference between, compare, implement, optimize, complexity, principles, pattern, design pattern, data structure, algorithm, "

        // Add language-specific question words (Bulgarian for now, others can be added)
        if language == .bulgarian {
            vocab += "какво, какви, как, защо, разкажи, обясни, знаеш, принципи, "
        }

        // Add custom frameworks
        if !frameworks.isEmpty {
            vocab += frameworks + ", "
        }

        return vocab + common
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
            speakingLanguage = lang
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
