import Foundation

// Compiles against production PracticeLogic + PracticeBankLoader.
// Drives the shipped decode/load path — not a copy of the bank schema.

var passed = 0
var failed = 0

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        passed += 1
    } else {
        failed += 1
        print("  FAIL [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]: \(message)")
    }
}

func section(_ name: String) {
    print("\n--- \(name) ---")
}

func sourceInterviewQuestions(from url: URL) -> [(tab: String, question: String, answer: String)] {
    guard let data = try? Data(contentsOf: url),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tabs = root["tabs"] as? [[String: Any]] else { return [] }
    var items: [(String, String, String)] = []
    for tab in tabs {
        let name = tab["name"] as? String ?? ""
        for item in (tab["items"] as? [[String: Any]]) ?? [] {
            let question = (item["question"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if question.isEmpty { continue }
            let answer = item["answer"] as? String ?? ""
            items.append((name, question, answer))
        }
    }
    return items
}

func loadedTextCoversSource(source: String, loadedTexts: [String]) -> Bool {
    let src = practiceNormalizeQuestionText(source)
    let firstLine = practiceNormalizeQuestionText(
        source.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? source
    )
    for text in loadedTexts {
        let loaded = practiceNormalizeQuestionText(text)
        if loaded == src || loaded.contains(firstLine) || src.contains(loaded) {
            return true
        }
    }
    return false
}

let spokenStarters = ["what ", "what's ", "whats ", "how ", "why ", "when ", "explain ", "describe "]

func isSpokenInterviewPrompt(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return false }
    if trimmed.hasSuffix("…") || trimmed.hasSuffix("...") { return false }
    if trimmed.contains("?") { return true }
    let lower = trimmed.lowercased()
    return spokenStarters.contains { lower.hasPrefix($0) }
}

let expectedStudyBookTopicIDs: Set<String> = [
    "agentic-aws", "agentic-security", "agents", "api-engineering", "capital-markets",
    "cloud-infra", "data-ingestion", "data-quality", "data-science-stack",
    "deep-learning-frameworks", "design-patterns", "docker-ci", "drills", "dsa-sql",
    "evals", "evals-ci", "fastapi", "feature-engineering", "genai-challenges",
    "gradient-boosting", "graphrag", "java-collections", "java-concurrency", "java-core",
    "jd-gap", "langgraph", "llm-internals", "llmops", "markov-chains", "mcp",
    "ml-fundamentals", "mlops-tooling", "model-adaptation", "model-serving", "optimization",
    "pyspark-data", "python-concurrency", "python-idioms", "python-oop", "python-performance",
    "rag", "sa-craft", "security", "semantic-layer", "senior-python-interview", "spring",
    "transformers", "ways-of-working"
]

@main
enum TestPracticeBank {
    static func main() {
        let cwd = FileManager.default.currentDirectoryPath
        let bankURL = URL(fileURLWithPath: cwd).appendingPathComponent("Resources/practice/bank.json")

        section("Shipped practice bank load")
        assert(FileManager.default.fileExists(atPath: bankURL.path), "Practice bank file exists at Resources/practice/bank.json")

        let loaded: PracticeBankFile
        do {
            loaded = try PracticeBankLoader.load(fromFile: bankURL)
        } catch {
            assert(false, "Shipped PracticeBankLoader.load(fromFile:) failed: \(error)")
            return
        }

        assert(loaded.packs.contains(where: { $0.id == "study-book" }), "bank.json still decodes a study-book pack")
        let viaLoad = PracticeBankLoader.load()
        assert(!viaLoad.packs.isEmpty, "PracticeBankLoader.load() finds the on-disk bank from the repo cwd")
        assert(viaLoad.packs.contains(where: { $0.id == "study-book" }), "Loaded bank includes the study-book pack, not only built-in extras")

        section("Study-book pack vs built-in extras")
        guard let study = practiceStudyBookPack(from: viaLoad) else {
            assert(false, "Loaded bank has a study-book pack")
            return
        }
        let builtinExtraIDs: Set<String> = ["aws", "models", "angular"]
        let extraCount = viaLoad.packs
            .filter { builtinExtraIDs.contains($0.id) }
            .reduce(0) { $0 + $1.questions.count }
        assert(study.questions.count == 102, "Study-book pack still has 102 questions (got \(study.questions.count))")
        assert(study.questions.count > extraCount, "Study-book pack is larger than AWS+Models+Angular combined")
        assert(viaLoad.packs.contains(where: { $0.id == "interview-guide" }), "Directory load also merges interview-guide.json")
        assert(study.questions.allSatisfy {
            !$0.answer.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
                || !$0.rubric.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
        }, "Every study-book question has a stored answer or rubric for Help")

        section("Study-book coverage and spoken register")
        let studyTopicIDs = Set(study.questions.map(\.topicId))
        assert(studyTopicIDs == expectedStudyBookTopicIDs, "Every study-book topicId from the bank still exists")
        let notSpoken = study.questions.filter { !isSpokenInterviewPrompt($0.text) }.map(\.id)
        assert(notSpoken.isEmpty, "Study-book prompts are spoken interview questions, not quiz stems. Failed: \(notSpoken.joined(separator: ", "))")
        section("Practice topic chips are interview subjects")
        let chipTitles = Dictionary(uniqueKeysWithValues: practiceBankGroups(from: viaLoad).map { ($0.id, $0.title) })
        assert(chipTitles["interview-prep"] == "Whiteboard & DSA", "Interview-prep bucket is labeled as Whiteboard & DSA")
        assert(chipTitles["classical-ml"] == "Tabular ML", "Classical ML is labeled as Tabular ML")
        assert(chipTitles["genai-and-llm"] == "RAG & agents", "GenAI & LLM is labeled as RAG & agents")
        assert(chipTitles["ml-in-production"] == "MLOps", "ML in production is labeled as MLOps")
        assert(chipTitles["foundations"] == "LLM internals", "Foundations is labeled as LLM internals")
        assert(chipTitles["agentic-sme-s-and-p"] == "Agents & security", "S&P SME bucket is labeled as Agents & security")
        assert(chipTitles["python-engineering"] == "Python", "Python engineering is labeled Python")
        assert(chipTitles.values.allSatisfy { !$0.localizedCaseInsensitiveContains("interview prep") }, "No chip is named Interview prep — the whole tab is interview prep")
        assert(Set(study.questions.map(\.groupId)).isSubset(of: Set(chipTitles.keys)), "Group ids are unchanged so role filters still work")

        assert(study.questions.filter { $0.id.contains("-quiz-") }.count == 88, "Coverage keeps 88 study-book quizzes")
        assert(study.questions.filter { $0.id.contains("-drill-") }.count == 14, "Coverage keeps 14 study-book drills")

        func helpBody(for id: String) -> String {
            guard let question = study.questions.first(where: { $0.id == id }) else { return "" }
            let answer = question.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !answer.isEmpty { return answer }
            return question.rubric.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func firstParagraph(_ text: String) -> String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let range = trimmed.range(of: "\n\n") {
                return String(trimmed[..<range.lowerBound])
            }
            return trimmed
        }
        func startsWithKeyParagraph(_ text: String, _ key: String) -> Bool {
            let first = firstParagraph(text)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
            let bareKey = key.trimmingCharacters(in: CharacterSet(charactersIn: ".!?").union(.whitespaces))
            return first.localizedCaseInsensitiveCompare(bareKey) == .orderedSame
        }
        let autoregressive = helpBody(for: "llm-internals-quiz-0")
        let attention = helpBody(for: "transformers-quiz-0")
        let approval = helpBody(for: "agents-quiz-0")
        let crossEntropy = helpBody(for: "ml-fundamentals-quiz-0")
        let recallAtK = helpBody(for: "rag-quiz-0")
        let tdd = helpBody(for: "ways-of-working-quiz-0")
        assert(autoregressive.localizedCaseInsensitiveContains("autoregressive"), "LLM Help still names autoregressive generation")
        assert(autoregressive.localizedCaseInsensitiveContains("one token at a time"), "LLM Help still names one-token generation")
        assert(!startsWithKeyParagraph(autoregressive, "One token at a time"), "LLM Help does not start with the leftover MCQ key paragraph")
        assert(attention.localizedCaseInsensitiveContains("attention"), "Attention Help still names attention scores")
        assert(!startsWithKeyParagraph(attention, "Attention scores"), "Attention Help does not start with the leftover MCQ key paragraph")
        assert(approval.localizedCaseInsensitiveContains("approval"), "Agent Help still names human approval")
        assert(!startsWithKeyParagraph(approval, "Require human approval"), "Agent Help does not start with the leftover MCQ key paragraph")
        assert(crossEntropy.localizedCaseInsensitiveContains("cross-entropy"), "Loss Help still names cross-entropy")
        assert(!startsWithKeyParagraph(crossEntropy, "Cross-entropy"), "Loss Help does not start with the leftover MCQ key paragraph")
        assert(recallAtK.contains("Recall@k"), "Retrieval Help still names Recall@k")
        assert(!startsWithKeyParagraph(recallAtK, "Recall@k"), "Retrieval Help does not start with the leftover MCQ key paragraph")
        let leftoverKeyLeads = study.questions.filter { question in
            let body = helpBody(for: question.id)
            let first = firstParagraph(body)
            guard body != first else { return false }
            return first.split(whereSeparator: { $0.isWhitespace }).count <= 8
        }.map(\.id)
        assert(leftoverKeyLeads.isEmpty, "No study-book Help starts with a leftover MCQ key paragraph. Still: \(leftoverKeyLeads.joined(separator: ", "))")
        assert(tdd.contains("Red → Green → Refactor"), "TDD slogan stays an inline Red → Green → Refactor chain")
        assert(!tdd.contains("Walk through it in this order"), "TDD is not split into a fake drill list")
        assert(helpBody(for: "drills-drill-0").contains("hybrid retrieve"), "RAG drill Help keeps the original steps")

        section("Practice pool uses the loaded bank")
        let fullPool = practiceQuestionPool(from: viaLoad)
        assert(fullPool.contains(where: { $0.packId == "study-book" }), "Selectable pool includes study-book questions from the loaded file")
        assert(fullPool.count == viaLoad.packs.flatMap(\PracticeTopicPack.questions).count, "Unfiltered pool is the merged loaded bank")
        let pythonPool = practiceQuestionPool(from: viaLoad, groupIDs: ["python-engineering"])
        assert(!pythonPool.isEmpty, "Role/topic filter still returns questions from the loaded bank")
        assert(pythonPool.allSatisfy { $0.groupId == "python-engineering" }, "Pool filter keeps only selected Python groups")
        assert(pythonPool.contains(where: { $0.packId == "study-book" }), "Python topic still includes study-book questions")
        assert(pythonPool.contains(where: { $0.id == "ai-eng-video-6" }), "Python topic includes the GIL interview question")

        section("Interview-guide pack from the exported Q&A JSON")
        let sourceURL = URL(fileURLWithPath: cwd)
            .appendingPathComponent("Resources/practice/sources/interview-questions-qa.json")
        let guideURL = URL(fileURLWithPath: cwd)
            .appendingPathComponent("Resources/practice/interview-guide.json")
        assert(FileManager.default.fileExists(atPath: sourceURL.path), "Copied interview-questions-qa.json is next to the bank")
        assert(FileManager.default.fileExists(atPath: guideURL.path), "interview-guide.json is a top-level practice bank file")

        guard let guide = viaLoad.packs.first(where: { $0.id == "interview-guide" }) else {
            assert(false, "Merged bank includes the interview-guide pack")
            return
        }
        let sourceItems = sourceInterviewQuestions(from: sourceURL)
        assert(sourceItems.count == 183, "Source export has 183 questions (got \(sourceItems.count))")
        assert(guide.questions.count == sourceItems.count, "Imported pack keeps every source question (\(guide.questions.count) vs \(sourceItems.count))")
        assert(guide.groups.map(\.id) == [
            "jr-javascript", "mid-javascript", "senior-javascript", "typescript",
            "networking", "json", "qa", "oop", "coding-tasks", "logical-tasks", "devops"
        ], "Interview-guide groups follow the export tabs")

        let keepGuideTabs: Set<String> = [
            "Jr Javascript", "Mid Javascript", "Senior Javascript", "TypeScript",
            "Networking", "JSON", "QA", "OOP"
        ]
        let guideTexts = guide.questions.map(\.text)
        var missingSpoken: [String] = []
        for item in sourceItems where keepGuideTabs.contains(item.tab) {
            if !loadedTextCoversSource(source: item.question, loadedTexts: guideTexts) {
                let first = item.question.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? item.question
                missingSpoken.append(first)
            }
        }
        assert(missingSpoken.isEmpty, "Guide items that already had real questions keep their wording. Missing: \(missingSpoken.joined(separator: " | "))")

        let leftoverGuide = guide.questions.filter { ["coding-tasks", "devops"].contains($0.groupId) }
        let leftoverNotSpoken = leftoverGuide.filter { !isSpokenInterviewPrompt($0.text) }.map(\.id)
        assert(leftoverNotSpoken.isEmpty, "Leftover coding-task and DevOps titles are spoken interview prompts. Failed: \(leftoverNotSpoken.joined(separator: ", "))")
        assert(guide.questions.contains(where: { $0.id == "coding-tasks-2" && $0.text.contains("sum of an array") }), "Sum of array is now a spoken coding prompt")
        assert(!(guide.questions.contains { $0.text == "Sum of array" || $0.text == "findDuplicates" || $0.text == "ALGO EXPERT" }), "Title-only coding names are gone")

        let jsQuestion = guide.questions.first { $0.text == "What is JavaScript?" }
        assert(jsQuestion != nil, "Junior JS keeps 'What is JavaScript?' wording")
        assert(jsQuestion?.groupId == "jr-javascript", "What is JavaScript? is in jr-javascript")
        let jsAnswer = jsQuestion?.answer ?? ""
        assert(jsAnswer.contains("JavaScript is a high-level, dynamic programming language"), "JS answer keeps the original explanation")
        assert(!jsAnswer.lowercased().contains("core explanation:"), "Help text drops the 'Core Explanation:' label only")

        let dataTypes = guide.questions.first { $0.text == "Explain Data Types." }
        assert(dataTypes != nil, "Heading-only prompts become 'Explain Data Types.' without rewriting the topic")
        assert((dataTypes?.answer ?? "").contains("Primitive Types"), "Data Types answer stays the original body")

        let puzzle = guide.questions.first { $0.text.contains("Missionaries and Cannibals") }
        assert(puzzle != nil, "Logic puzzles are imported")
        assert(puzzle?.text.contains("\n") == true, "Logic puzzles keep the original title and problem on separate lines")
        assert(!(puzzle?.text.contains("Explain") ?? true), "Logic puzzles are not rewritten as Explain-prompts")

        let linux = guide.questions.first { $0.id == "devops-2" }
        assert(linux != nil && isSpokenInterviewPrompt(linux?.text ?? ""), "DevOps Linux heading is a spoken interview prompt")
        assert((linux?.answer ?? "").localizedCaseInsensitiveContains("linux"), "DevOps Linux Help is no longer empty")

        let available = practiceBankGroups(from: viaLoad).map(\.id)
        assert(practiceGroupIDs(forRole: .frontend, available: available).contains("jr-javascript"), "Frontend role includes Jr Javascript")
        assert(practiceGroupIDs(forRole: .frontend, available: available).contains("typescript"), "Frontend role includes TypeScript")
        assert(practiceGroupIDs(forRole: .fullStack, available: available).contains("devops"), "Full stack includes DevOps")
        assert(practiceGroupIDs(forRole: .qaAutomation, available: available).contains("qa"), "QA automation includes the QA tab")
        assert(practiceGroupIDs(forRole: .qaAutomation, available: available).contains("coding-tasks"), "QA automation includes coding tasks")
        let frontendPool = practiceQuestionPool(
            from: viaLoad,
            groupIDs: Set(practiceGroupIDs(forRole: .frontend, available: available))
        )
        assert(frontendPool.contains(where: { $0.text == "What is JavaScript?" }), "Frontend pool can draw the interview-guide JS questions")
        assert(
            practiceQuestionSourceLine(
                PracticeQuestion(
                    id: "jr-javascript-0",
                    packId: "interview-guide",
                    text: "What is JavaScript?",
                    groupId: "jr-javascript",
                    topicTitle: "1. Core JavaScript Fundamentals"
                ),
                groupTitle: "Jr Javascript"
            ) == "Interview guide · Jr Javascript · 1. Core JavaScript Fundamentals",
            "Practice source line names the interview guide"
        )

        section("Learn vs Interview practice modes")
        assert(PracticeRunMode.allCases.map(\.rawValue) == ["learn", "rehearse", "interview"], "Practice exposes Active Recall, Voice Rehearsal, and Interview")
        assert(PracticeRunMode.learn.title == "Active Recall", "The legacy Learn value is presented as Active Recall")
        assert(PracticeRunMode.rehearse.title == "Voice Rehearsal", "Practice exposes the voice-first rehearsal rung")
        assert(practiceHelpAllowed(in: .learn), "Active Recall may reveal prepared learning help")
        assert(practiceHelpAllowed(in: .rehearse), "Voice Rehearsal may reveal prepared learning help")
        assert(!practiceHelpAllowed(in: .interview), "Interview mode reports Help disabled")
        assert(!practiceShowsMultipleChoice(in: .learn), "Active Recall uses a typed response instead of multiple choice")
        assert(!practiceShowsMultipleChoice(in: .rehearse), "Voice Rehearsal uses a spoken free response")
        assert(!practiceShowsMultipleChoice(in: .interview), "Interview does not attach options")
        assert(practiceShowsSubmitButton(in: .learn), "Active Recall has a reveal action after the typed response")
        assert(practiceShowsSubmitButton(in: .interview), "Interview still submits a free-response answer")

        let availableGroups = practiceBankGroups(from: viaLoad).map(\.id)
        let aiGroups = Set(practiceGroupIDs(forRole: .aiEngineer, available: availableGroups))
        assert(!aiGroups.contains("typescript"), "AI Engineer does not include TypeScript")
        assert(!aiGroups.contains("jr-javascript"), "AI Engineer does not include junior JavaScript")
        assert(!aiGroups.contains("oop"), "AI Engineer does not include the JS/Java OOP pack")
        let aiPool = practiceQuestionPool(from: viaLoad, groupIDs: aiGroups)
        assert(!aiPool.isEmpty, "AI Engineer still has a question pool")
        assert(aiPool.allSatisfy { !["typescript", "jr-javascript", "mid-javascript", "senior-javascript", "oop"].contains($0.groupId) }, "AI Engineer questions are not TypeScript/JS/OOP-pack items")
        let aiOrdered = interviewOrderedPracticeSelection(
            questions: aiPool,
            count: min(10, aiPool.count),
            topicOf: { $0.groupId },
            shuffle: { $0 }
        )
        assert(aiOrdered.first?.groupId == "python-engineering", "AI Engineer runs start with Python, not TypeScript")

        section("AI engineer interview video pack")
        guard let videoPack = viaLoad.packs.first(where: { $0.id == "ai-engineer-interview" }) else {
            assert(false, "Merged bank includes ai-engineer-interview.json")
            return
        }
        assert(videoPack.questions.count == 11, "Video pack has all 11 questions (got \(videoPack.questions.count))")
        let gil = videoPack.questions.first { $0.id == "ai-eng-video-6" }
        assert(gil?.text.contains("Global Interpreter Lock") == true, "GIL is a spoken Practice question")
        assert(gil?.groupId == "python-engineering", "GIL sits in the Python topic")
        assert(gil?.answer.localizedCaseInsensitiveContains("gil") == true, "GIL Help names the lock")
        assert(aiPool.contains(where: { $0.id == "ai-eng-video-6" }), "AI Engineer pool includes the GIL question")
        assert(aiPool.contains(where: { $0.text.contains("RLHF") }), "AI Engineer pool includes RLHF")
        assert(aiPool.contains(where: { $0.text.contains("Generative AI and traditional programming") }), "AI Engineer pool includes GenAI vs traditional programming")
        assert(
            practiceQuestionSourceLine(
                PracticeQuestion(
                    id: "ai-eng-video-6",
                    packId: "ai-engineer-interview",
                    text: "Explain concurrency, parallelism, and the Global Interpreter Lock (GIL) in Python.",
                    groupId: "python-engineering",
                    topicTitle: "Python concurrency & the GIL"
                ),
                groupTitle: "Python"
            ) == "AI engineer interview · Python · Python concurrency & the GIL",
            "GIL source line names the video pack"
        )

        section("AI engineer interview prep pack")
        guard let prepPack = viaLoad.packs.first(where: { $0.id == "ai-engineer-prep" }) else {
            assert(false, "Merged bank includes ai-engineer-prep.json")
            return
        }
        assert(prepPack.questions.count == 5, "Prep pack has 5 questions (got \(prepPack.questions.count))")
        assert(prepPack.questions.contains(where: { $0.text.contains("three software archetypes") }), "Prep pack covers the three AI Engineer role types")
        assert(aiPool.contains(where: { $0.id == "ai-eng-prep-1" }), "AI Engineer pool includes the three-role question")
        assert(aiPool.contains(where: { $0.id == "ai-eng-prep-2" }), "AI Engineer pool includes the OSINT prep question")
        assert(aiPool.contains(where: { $0.text.contains("voice-based AI mock interviews") }), "AI Engineer pool includes voice mock interviews")
        let rolesHelp = prepPack.questions.first { $0.id == "ai-eng-prep-1" }?.answer ?? ""
        assert(rolesHelp.contains("LangGraph") && rolesHelp.contains("PyTorch"), "Role-types Help keeps the video stacks")
        assert(
            practiceQuestionSourceLine(
                PracticeQuestion(
                    id: "ai-eng-prep-1",
                    packId: "ai-engineer-prep",
                    text: "The title AI Engineer on a job board is generic. What three software archetypes usually sit behind it?",
                    groupId: "genai-and-llm",
                    topicTitle: "Types of AI Engineer roles"
                ),
                groupTitle: "RAG & agents"
            ) == "AI interview prep · RAG & agents · Types of AI Engineer roles",
            "Prep source line names the cracking-the-interview pack"
        )

        section("AI engineer interviewer-perspective pack")
        guard let interviewerPack = viaLoad.packs.first(where: { $0.id == "ai-engineer-interviewer" }) else {
            assert(false, "Merged bank includes ai-engineer-interviewer.json")
            return
        }
        assert(interviewerPack.questions.count == 12, "Interviewer pack has 12 questions (got \(interviewerPack.questions.count))")
        assert(interviewerPack.questions.contains(where: { $0.text == "How do LLMs work?" }), "Pack includes How do LLMs work?")
        assert(interviewerPack.questions.contains(where: { $0.text == "How do Transformers work?" }), "Pack includes How do Transformers work?")
        assert(aiPool.contains(where: { $0.id == "ai-eng-iv-7" }), "AI Engineer pool includes the interviewer GIL question")
        assert(aiPool.contains(where: { $0.text.contains("AI engineering trilemma") }), "AI Engineer pool includes the latency/cost/relevancy trilemma")
        let hyde = interviewerPack.questions.first { $0.id == "ai-eng-iv-10" }?.answer ?? ""
        assert(hyde.contains("HyDE"), "Embedding Help keeps HyDE from the video")
        assert(
            practiceQuestionSourceLine(
                PracticeQuestion(
                    id: "ai-eng-iv-1",
                    packId: "ai-engineer-interviewer",
                    text: "How do LLMs work?",
                    groupId: "foundations",
                    topicTitle: "LLM & transformer fundamentals"
                ),
                groupTitle: "LLM internals"
            ) == "AI interviewer view · LLM internals · LLM & transformer fundamentals",
            "Interviewer source line names the pack"
        )

        section("Top Python and TypeScript interview pools")
        let pythonPool100 = practiceQuestionPool(from: viaLoad, groupIDs: ["python-engineering"])
        let tsPool100 = practiceQuestionPool(from: viaLoad, groupIDs: ["typescript"])
        assert(pythonPool100.count >= 100, "Python pool has at least 100 questions (got \(pythonPool100.count))")
        assert(tsPool100.count >= 100, "TypeScript pool has at least 100 questions (got \(tsPool100.count))")
        assert(pythonPool100.allSatisfy {
            !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !$0.rubric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }, "Every Python question has Help")
        assert(tsPool100.allSatisfy {
            !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !$0.rubric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }, "Every TypeScript question has Help")
        let gilFact = pythonPool100.first { $0.text.localizedCaseInsensitiveContains("global interpreter lock") }
        assert(gilFact != nil, "Python pool includes a GIL question")
        assert((gilFact?.answer ?? "").localizedCaseInsensitiveContains("gil"), "GIL Help still names the lock")
        let listTuple = pythonPool100.first { $0.text.localizedCaseInsensitiveContains("list") && $0.text.localizedCaseInsensitiveContains("tuple") }
        assert(listTuple != nil, "Python pool includes list vs tuple")
        assert((listTuple?.answer ?? "").localizedCaseInsensitiveContains("mutable"), "List-vs-tuple Help names mutability")
        let iface = tsPool100.first { $0.text.localizedCaseInsensitiveContains("interface") && $0.text.localizedCaseInsensitiveContains("type") }
        assert(iface != nil, "TypeScript pool includes interface vs type")
        assert((iface?.answer ?? "").localizedCaseInsensitiveContains("interface"), "interface-vs-type Help keeps the fact")
        let generics = tsPool100.first { $0.text.localizedCaseInsensitiveContains("generic") }
        assert(generics != nil, "TypeScript pool includes generics")
        assert((generics?.answer ?? "").localizedCaseInsensitiveContains("type"), "Generics Help is non-empty and typed")
        assert(!aiGroups.contains("typescript"), "AI Engineer still excludes TypeScript")
        assert(practiceGroupIDs(forRole: .frontend, available: availableGroups).contains("typescript"), "Frontend still includes TypeScript")
        assert(practiceGroupIDs(forRole: .fullStack, available: availableGroups).contains("python-engineering"), "Full stack still includes Python")
        assert(practiceGroupIDs(forRole: .fullStack, available: availableGroups).contains("typescript"), "Full stack still includes TypeScript")
        assert(pythonPool100.contains(where: { $0.packId == "python-interview" }), "Merged load includes the researched Python pack")
        assert(tsPool100.contains(where: { $0.packId == "typescript-interview" }), "Merged load includes the researched TypeScript pack")
        if let python = aiPool.first(where: { $0.id == "python-oop-quiz-0" }) {
            let pythonChoices = practiceLearnChoices(for: python, in: Array(aiPool), shuffle: { $0 })
            assert(pythonChoices.count == 4, "Python Learn options still have four choices from the AI pool")
            assert(pythonChoices.allSatisfy { choice in
                !choice.text.localizedCaseInsensitiveContains("typescript")
            }, "Python Learn distractors are not TypeScript stems")
        }

        section("Top OOP, LLM, AWS, and DevOps interview pools")
        let oopPool100 = practiceQuestionPool(from: viaLoad, groupIDs: ["oop"])
        let llmPool100 = practiceQuestionPool(from: viaLoad, groupIDs: ["genai-and-llm"])
        let awsPool100 = practiceQuestionPool(from: viaLoad, groupIDs: ["aws"])
        let devopsPool100 = practiceQuestionPool(from: viaLoad, groupIDs: ["devops"])
        assert(oopPool100.count >= 100, "OOP pool has at least 100 questions (got \(oopPool100.count))")
        assert(llmPool100.count >= 100, "LLM/embeddings pool has at least 100 questions (got \(llmPool100.count))")
        assert(awsPool100.count >= 100, "AWS pool has at least 100 questions (got \(awsPool100.count))")
        assert(devopsPool100.count >= 100, "DevOps pool has at least 100 questions (got \(devopsPool100.count))")
        func hasHelp(_ question: PracticeQuestion) -> Bool {
            !question.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !question.rubric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        assert(oopPool100.allSatisfy(hasHelp), "Every OOP question has Help")
        assert(llmPool100.allSatisfy(hasHelp), "Every LLM question has Help")
        assert(awsPool100.allSatisfy(hasHelp), "Every AWS question has Help")
        assert(devopsPool100.allSatisfy(hasHelp), "Every DevOps question has Help")
        let solid = oopPool100.first {
            $0.packId == "oop-interview" && $0.text.localizedCaseInsensitiveContains("single responsibility")
        }
        assert(solid != nil, "OOP pool includes Single Responsibility")
        assert((solid?.answer ?? "").localizedCaseInsensitiveContains("one reason"), "SRP Help names one reason to change")
        let embedding = llmPool100.first {
            $0.packId == "llm-interview" && $0.text.localizedCaseInsensitiveContains("what is a text embedding")
        }
        assert(embedding != nil, "LLM pool includes embeddings")
        assert((embedding?.answer ?? "").localizedCaseInsensitiveContains("vector"), "Embedding Help names vectors")
        let pinecone = llmPool100.first {
            $0.packId == "llm-interview" && $0.text.localizedCaseInsensitiveContains("pinecone")
        }
        assert(pinecone != nil, "LLM pool includes a hosted vector DB (Pinecone)")
        assert((pinecone?.answer ?? "").localizedCaseInsensitiveContains("vector"), "Pinecone Help stays on vector search")
        let iam = awsPool100.first {
            $0.text.localizedCaseInsensitiveContains("iam")
                && $0.text.localizedCaseInsensitiveContains("user")
                && $0.text.localizedCaseInsensitiveContains("role")
        }
        assert(iam != nil, "AWS pool includes IAM user vs role")
        assert((iam?.answer ?? "").localizedCaseInsensitiveContains("role"), "IAM Help names roles")
        let cicd = devopsPool100.first {
            $0.text.localizedCaseInsensitiveContains("ci")
                && $0.text.localizedCaseInsensitiveContains("cd")
        }
        assert(cicd != nil, "DevOps pool includes CI vs CD")
        assert((cicd?.answer ?? "").localizedCaseInsensitiveContains("continuous"), "CI/CD Help names continuous delivery")
        assert(oopPool100.contains(where: { $0.packId == "oop-interview" }), "Merged load includes the researched OOP pack")
        assert(llmPool100.contains(where: { $0.packId == "llm-interview" }), "Merged load includes the researched LLM pack")
        assert(awsPool100.contains(where: { $0.packId == "aws-interview" }), "Merged load includes the researched AWS pack")
        assert(devopsPool100.contains(where: { $0.packId == "devops-interview" }), "Merged load includes the researched DevOps pack")
        let researchedPackIDs: Set<String> = ["oop-interview", "llm-interview", "aws-interview", "devops-interview"]
        let researched = viaLoad.packs.flatMap(\.questions).filter { researchedPackIDs.contains($0.packId) }
        let notSpokenNew = researched.filter { !isSpokenInterviewPrompt($0.text) }.map(\.id)
        assert(notSpokenNew.isEmpty, "New OOP/LLM/AWS/DevOps prompts are spoken interview questions. Failed: \(notSpokenNew.joined(separator: ", "))")
        assert(practiceGroupIDs(forRole: .frontend, available: availableGroups).contains("oop"), "Frontend still includes OOP")
        assert(practiceGroupIDs(forRole: .fullStack, available: availableGroups).contains("oop"), "Full stack includes OOP")
        assert(practiceGroupIDs(forRole: .fullStack, available: availableGroups).contains("aws"), "Full stack includes AWS")
        assert(practiceGroupIDs(forRole: .fullStack, available: availableGroups).contains("devops"), "Full stack includes DevOps")
        assert(aiGroups.contains("genai-and-llm"), "AI Engineer includes RAG & agents")
        assert(aiGroups.contains("aws"), "AI Engineer includes AWS")
        assert(aiGroups.contains("devops"), "AI Engineer includes DevOps")
        assert(!aiGroups.contains("oop"), "AI Engineer still excludes the JS/Java OOP pack")
        assert(aiPool.contains(where: { $0.packId == "llm-interview" }), "AI Engineer pool includes the LLM interview pack")
        assert(aiPool.contains(where: { $0.packId == "aws-interview" }), "AI Engineer pool includes the AWS interview pack")
        assert(aiPool.contains(where: { $0.packId == "devops-interview" }), "AI Engineer pool includes the DevOps interview pack")
        assert(!aiPool.contains(where: { $0.packId == "oop-interview" }), "AI Engineer pool does not include the OOP interview pack")
        if let srp = solid {
            assert(
                practiceQuestionSourceLine(srp, groupTitle: "OOP").hasPrefix("OOP interview"),
                "OOP source line names the OOP interview pack"
            )
        }
        if let vec = llmPool100.first(where: { $0.packId == "llm-interview" }) {
            assert(
                practiceQuestionSourceLine(vec, groupTitle: "RAG & agents").hasPrefix("LLM interview"),
                "LLM source line names the LLM interview pack"
            )
        }
        if let awsQ = awsPool100.first(where: { $0.packId == "aws-interview" }) {
            assert(
                practiceQuestionSourceLine(awsQ, groupTitle: "AWS").hasPrefix("AWS interview"),
                "AWS source line names the AWS interview pack"
            )
        }
        if let doQ = devopsPool100.first(where: { $0.packId == "devops-interview" }) {
            assert(
                practiceQuestionSourceLine(doQ, groupTitle: "DevOps").hasPrefix("DevOps interview"),
                "DevOps source line names the DevOps interview pack"
            )
        }

        let bankQuestions = viaLoad.packs.flatMap(\.questions)
        guard let llm = bankQuestions.first(where: { $0.id == "llm-internals-quiz-0" }) else {
            assert(false, "Loaded bank still has llm-internals-quiz-0")
            return
        }
        let keepOrder: ([PracticeLearnChoice]) -> [PracticeLearnChoice] = { $0 }
        let choices = practiceLearnChoices(for: llm, in: bankQuestions, shuffle: keepOrder)
        assert(choices.count == 4, "Learn builds four options (got \(choices.count))")
        assert(Set(choices.map(\.text)).count == 4, "Learn options are four distinct strings")
        assert(choices.filter(\.isCorrect).count == 1, "Exactly one option is the stored-answer stem")
        assert(choices[0].isCorrect, "Unshuffled builder places the correct stem first")
        assert(choices[0].text == practiceAnswerStem(for: llm), "Correct option is the stem from the stored answer")
        assert(!choices[0].text.isEmpty, "Correct stem is non-empty")

        assert(practiceRevealedHelp(mode: .learn, hasSelection: false, question: llm) == nil, "Learn does not reveal Help as part of the option list")
        let revealed = practiceRevealedHelp(mode: .learn, hasSelection: true, question: llm)
        assert(revealed != nil, "Learn reveals Help after a selection")
        assert(revealed == practiceHelpText(for: llm), "Post-choice Help is the full stored bank answer")
        assert(revealed?.localizedCaseInsensitiveContains("autoregressive") == true, "Full Help still names autoregressive generation")
        assert(choices.filter { !$0.isCorrect }.allSatisfy { $0.text != revealed }, "Distractors are bank near-misses, not the full Help")
        assert(
            choices.filter { $0.text.localizedCaseInsensitiveContains("autoregressive") }.allSatisfy(\.isCorrect),
            "The sample fact is not used as a distractor"
        )
        assert(practiceRevealedHelp(mode: .interview, hasSelection: true, question: llm) == nil, "Interview never reveals Help")

        if let rag = bankQuestions.first(where: { $0.id == "rag-quiz-0" }) {
            let ragChoices = practiceLearnChoices(for: rag, in: bankQuestions, shuffle: keepOrder)
            assert(ragChoices.count == 4, "RAG question also gets four Learn options")
            assert(practiceRevealedHelp(mode: .learn, hasSelection: true, question: rag)?.contains("Recall@k") == true, "RAG Help after a choice still names Recall@k")
            assert(practiceRevealedHelp(mode: .learn, hasSelection: false, question: rag) == nil, "RAG options are shown without Help")
        } else {
            assert(false, "Loaded bank still has rag-quiz-0")
        }

        let headingQuestion = PracticeQuestion(
            id: "heading-closures",
            packId: "interview-guide",
            text: "Explain Closures.",
            groupId: "mid-javascript",
            answer: "Core Concept:\nClosures are functions that maintain access to their outer scope's variables."
        )
        let headingStem = practiceAnswerStem(for: headingQuestion)
        assert(headingStem.localizedCaseInsensitiveContains("closures"), "Heading-prefixed answers yield the closures fact, not the label")
        assert(headingStem != "Core Concept:", "Correct stem is not the 'Core Concept:' heading")
        let headingBank = [
            headingQuestion,
            PracticeQuestion(id: "h1", packId: "interview-guide", text: "Q1", groupId: "mid-javascript", answer: "An IIFE runs as soon as it is defined."),
            PracticeQuestion(id: "h2", packId: "interview-guide", text: "Q2", groupId: "mid-javascript", answer: "The event loop drains the microtask queue before macrotasks."),
            PracticeQuestion(id: "h3", packId: "interview-guide", text: "Q3", groupId: "mid-javascript", answer: "Debouncing waits for a pause before running the handler.")
        ]
        let headingChoices = practiceLearnChoices(for: headingQuestion, in: headingBank, shuffle: keepOrder)
        let headingCorrect = headingChoices.first(where: \.isCorrect)
        assert(headingChoices.count == 4, "Heading-prefixed Learn item still gets four options")
        assert(headingCorrect?.text.localizedCaseInsensitiveContains("closures") == true, "Correct option contains the closures fact")
        assert(headingCorrect?.text != "Core Concept:", "Correct option is not 'Core Concept:'")

        if let closures = bankQuestions.first(where: { $0.id == "mid-javascript-0" }) {
            let shippedStem = practiceAnswerStem(for: closures)
            assert(shippedStem.localizedCaseInsensitiveContains("closures"), "Shipped Explain Closures. stem is the fact")
            assert(shippedStem != "Core Concept:", "Shipped stem skips the Core Concept heading")
        } else {
            assert(false, "Loaded bank still has mid-javascript-0")
        }

        section("Practice active recall review")
        let recallQuestion = PracticeQuestion(
            id: "rag-recall",
            packId: "study-book",
            text: "What problem does a vector database solve in RAG?",
            groupId: "genai-and-llm",
            answer: "Key ideas:\n- Semantic similarity search\n- Fast retrieval over large collections\n- Metadata filtering for relevant context"
        )
        let recallIdeas = practiceKeyIdeas(for: recallQuestion)
        assert(
            recallIdeas == [
                "Semantic similarity search",
                "Fast retrieval over large collections",
                "Metadata filtering for relevant context"
            ],
            "Active Recall extracts three stable, marker-free key ideas"
        )
        let recallAnswer = "It retrieves semantically similar documents fast at scale."
        let recallCoverage = practiceCoveredKeyIdeas(answer: recallAnswer, keyIdeas: recallIdeas)
        assert(recallCoverage == [true, true, false], "Recall coverage matches morphology and preserves idea order")
        let recallReview = practiceRecallReview(for: recallQuestion, answer: recallAnswer)
        assert(recallReview.coveredCount == 2, "Recall review reports two covered ideas")
        assert(abs(recallReview.score - (2.0 / 3.0)) < 0.0001, "Recall score is the covered-idea ratio")
        assert(practiceKeyIdeas(for: recallQuestion) == recallIdeas, "Key-idea extraction is deterministic")

        let sparseQuestion = PracticeQuestion(
            id: "sparse-recall",
            packId: "study-book",
            text: "Why use idempotency keys?",
            hints: ["A retry will not act twice", "What happens on retries?"],
            rubric: "Retries are inevitable. Idempotency prevents duplicate side effects."
        )
        let sparseIdeas = practiceKeyIdeas(for: sparseQuestion)
        assert(sparseIdeas.contains(where: { $0.localizedCaseInsensitiveContains("retries") }), "Recall falls back to rubric sentences")
        assert(!sparseIdeas.contains(where: { $0.hasSuffix("?") }), "Question-shaped hints are not presented as key ideas")

        let recallNow = Date(timeIntervalSince1970: 1_700_000_000)
        assert(practiceNextReviewDate(for: .again, from: recallNow).timeIntervalSince(recallNow) == 300, "Again is due in five minutes")
        assert(practiceNextReviewDate(for: .hard, from: recallNow).timeIntervalSince(recallNow) == 86_400, "Hard is due tomorrow")
        assert(practiceNextReviewDate(for: .gotIt, from: recallNow).timeIntervalSince(recallNow) == 259_200, "Got it is due in three days")

        func recallAnswerRecord(id: String, score: Double, rating: PracticeRecallRating, due: Date) -> PracticeScoredAnswer {
            PracticeScoredAnswer(
                questionId: id,
                packId: "study-book",
                question: "Q",
                answer: "A",
                usedHelp: false,
                mark: .none,
                rawScore: score,
                finalScore: score,
                feedback: rating.title,
                strengths: [],
                gaps: [],
                recallRating: rating,
                nextReviewAt: due
            )
        }

        let repeatedLow = recallAnswerRecord(id: "repeat", score: 0.0, rating: .again, due: recallNow)
        let repeatedHigh = recallAnswerRecord(id: "repeat", score: 1.0, rating: .gotIt, due: recallNow.addingTimeInterval(259_200))
        let otherAnswer = recallAnswerRecord(id: "other", score: 0.5, rating: .hard, due: recallNow.addingTimeInterval(86_400))
        assert(abs(practiceRunOverallScore([repeatedLow, repeatedHigh, otherAnswer]) - 0.75) < 0.0001, "Run score uses the latest same-run retry")

        let dueQuestion = PracticeQuestion(id: "due", packId: "study-book", text: "Due")
        let newQuestion = PracticeQuestion(id: "new", packId: "study-book", text: "New")
        let futureQuestion = PracticeQuestion(id: "future", packId: "study-book", text: "Future")
        let priority = practicePrioritizedRecallQuestions(
            [futureQuestion, newQuestion, dueQuestion],
            latestAnswers: [
                practiceRecallReviewKey(packId: "study-book", questionId: "due"):
                    recallAnswerRecord(id: "due", score: 0.0, rating: .again, due: recallNow.addingTimeInterval(-1)),
                practiceRecallReviewKey(packId: "study-book", questionId: "future"):
                    recallAnswerRecord(id: "future", score: 1.0, rating: .gotIt, due: recallNow.addingTimeInterval(100))
            ],
            now: recallNow
        )
        assert(priority.map(\.id) == ["due", "new", "future"], "Due recall questions come before unseen and future questions")

        let legacyJSON = """
        {
          "id": "legacy",
          "packId": "study-book",
          "packTitle": "Study book",
          "startedAt": "2026-08-28T10:00:00Z",
          "finishedAt": "2026-08-28T10:05:00Z",
          "answers": [{
            "questionId": "legacy-q",
            "packId": "study-book",
            "question": "Q",
            "answer": "A",
            "usedHelp": false,
            "mark": "none",
            "rawScore": 1,
            "finalScore": 1,
            "feedback": "Correct option",
            "strengths": [],
            "gaps": []
          }],
          "overallScore": 1,
          "helpedCount": 0
        }
        """
        let legacyDecoder = JSONDecoder()
        legacyDecoder.dateDecodingStrategy = .iso8601
        if let legacyRun = try? legacyDecoder.decode(PracticeRunRecord.self, from: Data(legacyJSON.utf8)) {
            assert(legacyRun.mode == nil, "Legacy run JSON decodes without a mode")
            assert(legacyRun.answers.first?.recallRating == nil, "Legacy answer JSON decodes without recall metadata")
            assert(legacyRun.answers.first?.recallResponse == nil, "Legacy answer JSON decodes without response revisions")
            assert(legacyRun.answers.first?.recallConfidence == nil, "Legacy answer JSON decodes without confidence")
            assert(legacyRun.answers.first?.coverageOverrides == nil, "Legacy answer JSON decodes without coverage overrides")
            assert(legacyRun.targetDate == nil, "Legacy run JSON decodes without a target date")
        } else {
            assert(false, "Legacy practice JSON remains decodable")
        }

        section("Practice recall learning state")
        assert(PracticeRecallConfidence.allCases.map(\.rawValue) == ["unsure", "mostly", "very"], "Confidence has stable Codable values")
        assert(PracticeRecallConfidence.mostly.title == "Mostly sure", "Confidence has learner-facing copy")
        let revisedResponse = PracticeRecallResponse(
            initial: "RAG retrieves context.",
            revised: "RAG retrieves relevant context before generation."
        )
        assert(revisedResponse.wasRevised, "Recall responses retain a repair attempt")
        assert(revisedResponse.current.contains("relevant context"), "The revised response is the current response")
        let blankRevision = PracticeRecallResponse(initial: "Initial", revised: "  ")
        assert(!blankRevision.wasRevised && blankRevision.current == "Initial", "Blank revisions do not erase the initial recall")

        let correctedCoverage = practiceApplyCoverageOverrides(
            automaticCoverage: recallCoverage,
            overrides: [
                PracticeCoverageOverride(ideaIndex: 0, isCovered: false),
                PracticeCoverageOverride(ideaIndex: 2, isCovered: true),
                PracticeCoverageOverride(ideaIndex: 20, isCovered: true),
                PracticeCoverageOverride(ideaIndex: 0, isCovered: true)
            ]
        )
        assert(correctedCoverage == [true, true, true], "Manual coverage uses the final valid correction and ignores invalid indices")
        let correctedReview = practiceRecallReview(
            for: recallQuestion,
            answer: recallAnswer,
            coverageOverrides: [PracticeCoverageOverride(ideaIndex: 2, isCovered: true)]
        )
        assert(correctedReview.automaticCovered == [true, true, false], "Recall review retains estimated coverage")
        assert(correctedReview.covered == [true, true, true] && correctedReview.score == 1, "Manual coverage changes the displayed score")

        let firstAdaptive = practiceAdaptiveReviewInterval(
            for: .gotIt,
            priorAttempts: [],
            confidence: .mostly,
            from: recallNow
        )
        assert(firstAdaptive == 259_200, "First mostly-sure Got it keeps the three-day baseline")
        let growingAdaptive = practiceAdaptiveReviewInterval(
            for: .gotIt,
            priorAttempts: [repeatedHigh],
            confidence: .very,
            from: recallNow
        )
        let cautiousAdaptive = practiceAdaptiveReviewInterval(
            for: .gotIt,
            priorAttempts: [repeatedHigh],
            confidence: .unsure,
            from: recallNow
        )
        assert(growingAdaptive > firstAdaptive, "Successful prior attempts expand the review interval")
        assert(cautiousAdaptive < growingAdaptive, "Low confidence shortens the same review interval")
        let assistedHigh = PracticeScoredAnswer(
            questionId: "repeat",
            packId: "study-book",
            question: "Q",
            answer: "Revised after key ideas",
            usedHelp: true,
            mark: .yellow,
            rawScore: 1,
            finalScore: 1,
            feedback: "Assisted",
            strengths: [],
            gaps: [],
            recallRating: .gotIt,
            nextReviewAt: recallNow
        )
        assert(
            practiceAdaptiveReviewInterval(
                for: .gotIt,
                priorAttempts: [assistedHigh],
                confidence: .mostly,
                from: recallNow
            ) == firstAdaptive,
            "Assisted recall does not expand the independent-recall interval"
        )
        let targetCapped = practiceAdaptiveReviewInterval(
            for: .gotIt,
            priorAttempts: [repeatedHigh, repeatedHigh],
            confidence: .very,
            from: recallNow,
            targetDate: recallNow.addingTimeInterval(2 * 86_400)
        )
        assert(targetCapped == 86_400, "A target date keeps another review opportunity before the interview")
        let expiredTargetInterval = practiceAdaptiveReviewInterval(
            for: .gotIt,
            priorAttempts: [repeatedHigh, repeatedHigh],
            confidence: .very,
            from: recallNow,
            targetDate: recallNow.addingTimeInterval(-86_400)
        )
        assert(expiredTargetInterval > 0, "An expired target date no longer makes every review immediately due")
        assert(
            practiceAdaptiveNextReviewDate(
                for: .again,
                priorAttempts: [],
                confidence: .very,
                from: recallNow
            ).timeIntervalSince(recallNow) == 300,
            "Adaptive Again remains an immediate five-minute retry"
        )

        let firstState = PracticeSessionQuestionState(
            reference: PracticeQuestionReference(packId: "study-book", questionId: "due"),
            draftResponse: revisedResponse.current,
            recallResponse: revisedResponse,
            confidence: .mostly,
            hasRevealedKeyIdeas: true,
            coverageOverrides: [PracticeCoverageOverride(ideaIndex: 2, isCovered: true)],
            usedHelp: true,
            repairDraft: "Add metadata filtering.",
            isRepairingGap: true,
            repairIdeaIndex: 2
        )
        let secondState = PracticeSessionQuestionState(
            reference: PracticeQuestionReference(packId: "study-book", questionId: "new"),
            draftResponse: "Draft in progress"
        )
        let undoMetadata = PracticeRatingUndoMetadata(
            question: firstState.reference,
            questionIndex: 0,
            answerCountBeforeRating: 0,
            questionCountBeforeRating: 2,
            previousQuestionState: firstState,
            ratedAt: recallNow,
            requeuedQuestionKeysBeforeRating: []
        )
        let snapshot = PracticeSessionSnapshot(
            id: "resume-me",
            packId: "study-book",
            packTitle: "Study book",
            roleId: "ai-engineer",
            groupIds: ["genai-and-llm"],
            mode: .learn,
            questionStates: [firstState, secondState],
            currentQuestionIndex: 1,
            startedAt: recallNow,
            updatedAt: recallNow.addingTimeInterval(30),
            answers: [repeatedLow],
            requeuedQuestionKeys: [practiceRecallReviewKey(packId: "study-book", questionId: "due")],
            lastRatingUndo: undoMetadata,
            targetDate: recallNow.addingTimeInterval(14 * 86_400)
        )
        assert(snapshot.canResume && snapshot.questionReferences.map(\.questionId) == ["due", "new"], "Snapshot contains enough ordered state to resume")
        assert(snapshot.questionStates[0].isRepairingGap && snapshot.questionStates[0].repairIdeaIndex == 2 && !snapshot.questionStates[0].repairDraft.isEmpty, "Snapshot preserves an unfinished one-gap repair and its target idea")
        let snapshotEncoder = JSONEncoder()
        snapshotEncoder.dateEncodingStrategy = .iso8601
        let snapshotDecoder = JSONDecoder()
        snapshotDecoder.dateDecodingStrategy = .iso8601
        if let snapshotData = try? snapshotEncoder.encode(snapshot),
           let roundTripped = try? snapshotDecoder.decode(PracticeSessionSnapshot.self, from: snapshotData) {
            assert(roundTripped == snapshot, "Full in-progress state survives Codable persistence")
        } else {
            assert(false, "Full in-progress state encodes and decodes")
        }
        if let restored = practiceSnapshotAfterUndoingLastRating(snapshot) {
            assert(restored.answers.isEmpty, "Rating Undo removes only the newly rated answer")
            assert(restored.currentQuestionIndex == 0, "Rating Undo returns to the rated question")
            assert(restored.questionStates[0] == firstState, "Rating Undo restores the exact pre-rating learner state")
            assert(restored.requeuedQuestionKeys.isEmpty, "Rating Undo restores the pre-Again retry-key set")
            assert(restored.lastRatingUndo == nil, "Rating Undo is single-level")
        } else {
            assert(false, "Valid rating metadata can be undone")
        }

        let retryKeyBeforeRating = practiceRecallReviewKey(packId: "study-book", questionId: "due")
        let retryUndo = PracticeRatingUndoMetadata(
            question: firstState.reference,
            questionIndex: 0,
            answerCountBeforeRating: 0,
            questionCountBeforeRating: 2,
            previousQuestionState: firstState,
            ratedAt: recallNow,
            requeuedQuestionKeysBeforeRating: [retryKeyBeforeRating]
        )
        let retrySnapshot = PracticeSessionSnapshot(
            id: "retry-undo",
            packId: "study-book",
            packTitle: "Study book",
            mode: .learn,
            questionStates: [firstState, secondState],
            currentQuestionIndex: 1,
            startedAt: recallNow,
            updatedAt: recallNow,
            answers: [repeatedLow],
            requeuedQuestionKeys: [retryKeyBeforeRating],
            lastRatingUndo: retryUndo
        )
        assert(
            practiceSnapshotAfterUndoingLastRating(retrySnapshot)?.requeuedQuestionKeys == [retryKeyBeforeRating],
            "Undoing Again on an already-requeued retry preserves the one-retry bound"
        )

        let legacySnapshotJSON = """
        {
          "packId": "study-book",
          "packTitle": "Study book",
          "questionIds": ["legacy-q", "legacy-q-2"],
          "currentQuestionIndex": 1,
          "startedAt": "2026-08-28T10:00:00Z"
        }
        """
        if let legacySnapshot = try? snapshotDecoder.decode(PracticeSessionSnapshot.self, from: Data(legacySnapshotJSON.utf8)) {
            assert(legacySnapshot.mode == .learn, "Early snapshots default to Active Recall")
            assert(legacySnapshot.questionReferences.map(\.questionId) == ["legacy-q", "legacy-q-2"], "Early questionIds migrate into question states")
            assert(legacySnapshot.updatedAt == legacySnapshot.startedAt, "Early snapshots default updatedAt to startedAt")
        } else {
            assert(false, "Early resumable-session JSON remains decodable")
        }

        section("Practice mastery and today's plan")
        let learningQuestion = PracticeQuestion(
            id: "learning",
            packId: "study-book",
            text: "How does metadata filtering constrain retrieval?",
            groupId: "genai-and-llm",
            topicId: "retrieval"
        )
        let groupedDue = PracticeQuestion(
            id: "due",
            packId: "study-book",
            text: "When should RAG be used?",
            groupId: "genai-and-llm",
            topicId: "retrieval"
        )
        let groupedNew = PracticeQuestion(
            id: "new",
            packId: "study-book",
            text: "What is fine-tuning?",
            groupId: "genai-and-llm",
            topicId: "adaptation"
        )
        let groupedSolid = PracticeQuestion(
            id: "future",
            packId: "study-book",
            text: "How does semantic retrieval work?",
            groupId: "genai-and-llm",
            topicId: "retrieval"
        )
        let masteryAnswers = [
            practiceRecallReviewKey(packId: "study-book", questionId: "due"): repeatedLow,
            practiceRecallReviewKey(packId: "study-book", questionId: "future"): repeatedHigh,
            practiceRecallReviewKey(packId: "study-book", questionId: "learning"):
                recallAnswerRecord(id: "learning", score: 0.5, rating: .hard, due: recallNow.addingTimeInterval(86_400))
        ]
        let masteryQuestions = [groupedDue, groupedNew, groupedSolid, learningQuestion]
        assert(
            practiceMasteryState(latestAnswer: repeatedHigh, attempts: [repeatedHigh], now: recallNow) == .learning,
            "One strong recall remains Learning until it is repeated"
        )
        assert(
            practiceMasteryState(latestAnswer: repeatedHigh, attempts: [repeatedHigh, repeatedHigh], now: recallNow) == .solid,
            "Two strong unassisted recalls establish Solid mastery"
        )
        let latestFailure = recallAnswerRecord(
            id: "repeat",
            score: 0.3,
            rating: .hard,
            due: recallNow.addingTimeInterval(86_400)
        )
        assert(
            practiceMasteryState(
                latestAnswer: latestFailure,
                attempts: [repeatedHigh, repeatedHigh, latestFailure],
                now: recallNow
            ) == .learning,
            "A latest failed recall returns a previously solid question to Learning"
        )
        let masteryAttempts = [
            practiceRecallReviewKey(packId: "study-book", questionId: "due"): [repeatedLow],
            practiceRecallReviewKey(packId: "study-book", questionId: "future"): [repeatedHigh, repeatedHigh],
            practiceRecallReviewKey(packId: "study-book", questionId: "learning"): [masteryAnswers[practiceRecallReviewKey(packId: "study-book", questionId: "learning")]!]
        ]
        let mastery = practiceTopicMasterySummaries(
            questions: masteryQuestions,
            latestAnswers: masteryAnswers,
            attemptsByQuestion: masteryAttempts,
            now: recallNow
        )
        assert(mastery.count == 1 && mastery[0].topic.title == "RAG & agents", "Mastery groups questions into learner-facing topics")
        assert(mastery[0].newCount == 1, "Mastery counts unseen questions as New")
        assert(mastery[0].learningCount == 1, "Mastery counts difficult future reviews as Learning")
        assert(mastery[0].solidCount == 1, "Mastery counts strong future reviews as Solid")
        assert(mastery[0].dueCount == 1 && mastery[0].totalCount == 4, "Mastery counts elapsed reviews as Due")

        let today = practiceTodaysPlan(
            questions: masteryQuestions,
            latestAnswers: masteryAnswers,
            attemptsByQuestion: masteryAttempts,
            now: recallNow,
            maximumQuestions: 3,
            estimatedSecondsPerQuestion: 60
        )
        assert(today.dueCount == 1 && today.weakCount == 1 && today.newCount == 1, "Today's Plan exposes due, weak, and new counts")
        assert(today.solidCount == 1, "Today's Plan reports already-solid questions separately")
        assert(today.recommendedCount == 3 && today.estimatedMinutes == 3, "Today's Plan bounds the session and estimates its duration")

        section("Practice contrast pairs")
        let ragContrast = PracticeQuestion(
            id: "rag-contrast",
            packId: "study-book",
            text: "When would you use RAG instead of fine-tuning?",
            groupId: "genai-and-llm",
            topicId: "rag-vs-fine-tuning"
        )
        let tuningContrast = PracticeQuestion(
            id: "tuning-contrast",
            packId: "study-book",
            text: "How does fine-tuning change model behavior compared with retrieval?",
            groupId: "genai-and-llm",
            topicId: "rag-vs-fine-tuning"
        )
        let unrelatedContrast = PracticeQuestion(
            id: "cache",
            packId: "study-book",
            text: "Explain prompt caching costs.",
            groupId: "genai-and-llm",
            topicId: "caching"
        )
        let contrastPairs = practiceContrastPairs(
            from: [unrelatedContrast, ragContrast, tuningContrast],
            now: recallNow,
            limit: 2
        )
        assert(contrastPairs.count == 1, "Contrast selection does not invent unrelated pairs")
        assert(Set([contrastPairs.first?.first.id, contrastPairs.first?.second.id].compactMap { $0 }) == ["rag-contrast", "tuning-contrast"], "Contrast selection pairs confusable concepts")
        assert(practiceContrastQuestionSelection(from: [unrelatedContrast, ragContrast, tuningContrast]).count == 2, "Contrast selection can flatten pairs into a practice queue")
        let broadTopicOnly = [
            PracticeQuestion(id: "ts-overview", packId: "study-book", text: "What is TypeScript?", groupId: "python-engineering", topicId: "typescript"),
            PracticeQuestion(id: "ts-types", packId: "study-book", text: "Name the basic primitive types.", groupId: "python-engineering", topicId: "typescript")
        ]
        assert(
            practiceContrastPairs(from: broadTopicOnly).isEmpty,
            "A shared broad topic id alone does not invent a contrast exercise"
        )

        let solidPair = [
            PracticeQuestion(id: "solid-a", packId: "study-book", text: "Describe alpha quorum behavior.", groupId: "genai-and-llm", topicId: "alpha"),
            PracticeQuestion(id: "solid-b", packId: "study-book", text: "When choose alpha quorum consensus?", groupId: "genai-and-llm", topicId: "alpha")
        ]
        let learningPair = [
            PracticeQuestion(id: "learning-a", packId: "study-book", text: "Describe beta index behavior.", groupId: "genai-and-llm", topicId: "beta"),
            PracticeQuestion(id: "learning-b", packId: "study-book", text: "When use beta index retrieval?", groupId: "genai-and-llm", topicId: "beta")
        ]
        let rankedQuestions = solidPair + learningPair
        var rankedLatest: [String: PracticeScoredAnswer] = [:]
        var rankedAttempts: [String: [PracticeScoredAnswer]] = [:]
        for question in rankedQuestions {
            let answer = recallAnswerRecord(
                id: question.id,
                score: 1,
                rating: .gotIt,
                due: recallNow.addingTimeInterval(259_200)
            )
            let key = practiceRecallReviewKey(packId: question.packId, questionId: question.id)
            rankedLatest[key] = answer
            rankedAttempts[key] = question.topicId == "alpha" ? [answer, answer] : [answer]
        }
        let weakestContrast = practiceContrastPairs(
            from: rankedQuestions,
            latestAnswers: rankedLatest,
            attemptsByQuestion: rankedAttempts,
            now: recallNow,
            limit: 1
        )
        assert(
            Set([weakestContrast.first?.first.id, weakestContrast.first?.second.id].compactMap { $0 }) == ["learning-a", "learning-b"],
            "Contrast ranking uses full mastery evidence and prioritizes the learning pair over a solid pair"
        )

        #if PRACTICE_STORE_TESTS
        section("Practice store resume persistence")
        let temporaryStoreDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("interview-master-practice-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temporaryStoreDirectory) }
        let temporaryStore = PracticeStore(directoryURL: temporaryStoreDirectory)
        assert(temporaryStore.saveInProgressSession(snapshot), "PracticeStore reports successful snapshot persistence")
        let completedRun = PracticeRunRecord(
            id: "store-run",
            packId: "study-book",
            packTitle: "Study book",
            startedAt: recallNow,
            finishedAt: recallNow.addingTimeInterval(60),
            answers: [repeatedHigh],
            overallScore: 1,
            helpedCount: 0,
            mode: .learn
        )
        assert(temporaryStore.append(completedRun), "PracticeStore reports successful run persistence")
        let runsURL = temporaryStoreDirectory.appendingPathComponent("runs.json")
        let beforeIdenticalAppend = try? Data(contentsOf: runsURL)
        assert(temporaryStore.append(completedRun), "PracticeStore treats a repeated completed session id as already saved")
        assert((try? Data(contentsOf: runsURL)) == beforeIdenticalAppend, "An identical idempotent append does not rewrite history")

        let revisedRun = PracticeRunRecord(
            id: completedRun.id,
            packId: completedRun.packId,
            packTitle: completedRun.packTitle,
            startedAt: completedRun.startedAt,
            finishedAt: recallNow.addingTimeInterval(120),
            answers: [repeatedLow],
            overallScore: 0,
            helpedCount: 0,
            mode: .learn
        )
        assert(temporaryStore.append(revisedRun), "PracticeStore upserts changed content for an existing session id")
        assert(temporaryStore.allRuns() == [revisedRun], "A same-id upsert replaces rather than duplicates the run")
        let reloadedStore = PracticeStore(directoryURL: temporaryStoreDirectory)
        assert(reloadedStore.allRuns() == [revisedRun], "A same-id upsert survives disk reload")
        assert(reloadedStore.inProgressSession() == snapshot, "PracticeStore reloads the separate resumable snapshot")
        assert(reloadedStore.clearInProgressSession(), "PracticeStore reports successful snapshot cleanup")
        assert(reloadedStore.inProgressSession() == nil, "Clearing a completed/cancelled session removes resumable state")
        assert(PracticeStore(directoryURL: temporaryStoreDirectory).allRuns() == [revisedRun], "Clearing resumable state never clears history")

        let failedUpsertDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("interview-master-practice-upsert-failure-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: failedUpsertDirectory) }
        let failedUpsertStore = PracticeStore(directoryURL: failedUpsertDirectory)
        assert(failedUpsertStore.append(completedRun), "Upsert rollback fixture starts with a persisted run")
        try? FileManager.default.removeItem(at: failedUpsertDirectory)
        try? Data("not a directory".utf8).write(to: failedUpsertDirectory)
        assert(!failedUpsertStore.append(revisedRun), "PracticeStore reports a failed same-id upsert")
        assert(failedUpsertStore.allRuns() == [completedRun], "A failed same-id upsert restores the previous in-memory run")

        let malformedStoreDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("interview-master-practice-malformed-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: malformedStoreDirectory) }
        try? FileManager.default.createDirectory(at: malformedStoreDirectory, withIntermediateDirectories: true)
        let malformedRunsURL = malformedStoreDirectory.appendingPathComponent("runs.json")
        let malformedRunsData = Data("{ definitely-not-valid-json".utf8)
        try? malformedRunsData.write(to: malformedRunsURL)
        let malformedStore = PracticeStore(directoryURL: malformedStoreDirectory)
        assert(malformedStore.allRuns().isEmpty, "Malformed history is not exposed as valid runs")
        assert(!malformedStore.append(completedRun), "PracticeStore fails closed after malformed history cannot load")
        assert((try? Data(contentsOf: malformedRunsURL)) == malformedRunsData, "A failed-closed append preserves the malformed history file byte-for-byte")

        let malformedSnapshotDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("interview-master-practice-malformed-snapshot-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: malformedSnapshotDirectory) }
        try? FileManager.default.createDirectory(at: malformedSnapshotDirectory, withIntermediateDirectories: true)
        let malformedSnapshotURL = malformedSnapshotDirectory.appendingPathComponent("in-progress.json")
        let malformedSnapshotData = Data("[ definitely-not-a-session".utf8)
        try? malformedSnapshotData.write(to: malformedSnapshotURL)
        let recoveredSnapshotStore = PracticeStore(directoryURL: malformedSnapshotDirectory)
        assert(recoveredSnapshotStore.inProgressSession() == nil, "Malformed snapshot is not exposed as a resumable session")
        let recoveryFiles = ((try? FileManager.default.contentsOfDirectory(
            at: malformedSnapshotDirectory,
            includingPropertiesForKeys: nil
        )) ?? []).filter {
            $0.lastPathComponent.hasPrefix("in-progress-recovery-") && $0.pathExtension == "json"
        }
        assert(recoveryFiles.count == 1, "Malformed snapshot is quarantined under one unique adjacent recovery name")
        assert(recoveryFiles.first.flatMap { try? Data(contentsOf: $0) } == malformedSnapshotData, "Snapshot quarantine preserves the malformed bytes exactly")
        assert(!FileManager.default.fileExists(atPath: malformedSnapshotURL.path), "Quarantine frees the canonical snapshot path")
        assert(recoveredSnapshotStore.saveInProgressSession(snapshot), "A new snapshot can be saved after malformed data is quarantined")
        assert(
            PracticeStore(directoryURL: malformedSnapshotDirectory).inProgressSession() == snapshot,
            "The replacement snapshot reloads while quarantined recovery data remains adjacent"
        )
        assert(recoveryFiles.first.flatMap { try? Data(contentsOf: $0) } == malformedSnapshotData, "Saving a replacement never modifies quarantined recovery data")

        let blockedStorePath = FileManager.default.temporaryDirectory
            .appendingPathComponent("interview-master-practice-blocked-" + UUID().uuidString)
        try? Data("not a directory".utf8).write(to: blockedStorePath)
        defer { try? FileManager.default.removeItem(at: blockedStorePath) }
        let blockedStore = PracticeStore(directoryURL: blockedStorePath)
        assert(!blockedStore.saveInProgressSession(snapshot), "PracticeStore reports snapshot write failure")
        assert(!blockedStore.append(completedRun), "PracticeStore reports run write failure")
        assert(blockedStore.allRuns().isEmpty, "Failed run persistence rolls back the in-memory append")
        #endif

        let uiSource = (try? String(
            contentsOf: URL(fileURLWithPath: cwd).appendingPathComponent("Presentation/Practice/PracticeTabController.swift"),
            encoding: .utf8
        )) ?? ""
        assert(practiceLearnOptionMark(index: 0, selected: nil, correct: 1) == .unmarked, "Options stay unmarked until a choice")
        assert(practiceLearnOptionMark(index: 1, selected: 1, correct: 1) == .selectedCorrect, "A correct click is marked green")
        assert(practiceLearnOptionMark(index: 2, selected: 2, correct: 0) == .selectedWrong, "A wrong click is marked red")
        assert(practiceLearnOptionMark(index: 0, selected: 2, correct: 0) == .revealedCorrect, "The right option still turns green after a miss")
        assert(practiceLearnOptionMark(index: 3, selected: 2, correct: 0) == .unmarked, "Untouched options stay unmarked")

        let markSource = (try? String(
            contentsOf: URL(fileURLWithPath: cwd).appendingPathComponent("Presentation/Practice/PracticeFocusViews.swift"),
            encoding: .utf8
        )) ?? ""
        assert(markSource.contains("PracticeRecallCard"), "Practice ships the selected Active Recall review surface")
        assert(markSource.contains("KEY IDEAS"), "Active Recall renders Key Ideas on the right")
        assert(markSource.contains("checkmark.circle") && markSource.contains("lightbulb.fill"), "Recall review uses native semantic symbols")

        assert(uiSource.contains("modePopup"), "Practice setup exposes a mode control")
        assert(uiSource.contains("PracticeRunMode.learn") || uiSource.contains("selectedMode = PracticeRunMode.learn"), "Practice setup includes Learn")
        assert(uiSource.contains(".interview"), "Practice setup includes Interview")
        assert(uiSource.contains("recallRevealButton"), "Active Recall exposes a learner-controlled reveal action")
        assert(uiSource.contains("recallAgainButton") && uiSource.contains("recallHardButton") && uiSource.contains("recallGotItButton"), "Active Recall exposes all three review ratings")
        assert(uiSource.contains("recallEditButton"), "Active Recall lets the learner edit a response")
        assert(!uiSource.contains("scheduleLearnAdvance"), "Active Recall never auto-advances after revealing feedback")
        assert(uiSource.contains("saveSessionSnapshot") && uiSource.contains("resumeSavedSession"), "Practice controller persists and resumes in-progress sessions")
        assert(uiSource.contains("undoLastRating"), "Practice controller exposes rating Undo")
        assert(uiSource.contains("beginGapRepair") && uiSource.contains("completeGapRepair"), "Practice controller integrates one-gap repair")
        assert(uiSource.contains("Cancel repair") && uiSource.contains("recallAgainButton.isEnabled = !isRepairing"), "One-gap repair cannot silently discard a draft through rating")
        assert(uiSource.contains("recallRecordButton"), "Active Recall and Voice Rehearsal expose spoken answering")
        assert(uiSource.contains("targetDatePicker"), "Practice setup exposes adaptive scheduling against an interview date")
        assert(uiSource.contains("startContrastPractice"), "Practice exposes targeted concept comparison rounds")
        assert(uiSource.contains("expectedSnapshotID") && uiSource.contains("expectedQuestionIndex"), "Async Practice callbacks are guarded by session and question identity")
        assert(uiSource.contains("shouldAllowWindowClose") && uiSource.contains("prepareForApplicationTermination"), "Practice protects resumable work on Close and Quit")

        let windowSource = (try? String(
            contentsOf: URL(fileURLWithPath: cwd).appendingPathComponent("Presentation/Windows/WindowFactory.swift"),
            encoding: .utf8
        )) ?? ""
        let hotkeySource = (try? String(
            contentsOf: URL(fileURLWithPath: cwd).appendingPathComponent("Presentation/HotkeyManager.swift"),
            encoding: .utf8
        )) ?? ""
        assert(windowSource.contains("beginPracticeInteraction") && windowSource.contains("endPracticeInteraction"), "Practice temporarily enables key-window interaction and restores stealth")
        assert(hotkeySource.contains("practiceTabController.performPrimaryAction"), "Practice owns its Command-Return primary action")

        print("\n=== Practice bank results ===")
        print("Passed: \(passed)")
        print("Failed: \(failed)")
        print(failed == 0 ? "ALL TESTS PASSED" : "SOME TESTS FAILED")
        if failed > 0 {
            exit(1)
        }
    }
}
