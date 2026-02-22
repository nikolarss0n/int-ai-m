import Foundation

class MemoryStore {
    static let shared = MemoryStore()

    private var memory: InterviewMemory
    private let queue = DispatchQueue(label: "com.interviewmaster.memorystore")
    private let fileURL: URL

    private init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/InterviewMaster")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("memory.json")
        self.memory = InterviewMemory()
        load()
    }

    // MARK: - Load / Save

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            NSLog("🧠 No memory file found, starting fresh")
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            memory = try decoder.decode(InterviewMemory.self, from: data)
            NSLog("🧠 Loaded memory: %d sessions, %d knowledge entries", memory.sessionSummaries.count, memory.knowledgeEntries.count)
        } catch {
            NSLog("⚠️ Failed to load memory: %@", error.localizedDescription)
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(memory)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("⚠️ Failed to save memory: %@", error.localizedDescription)
        }
    }

    // MARK: - Session Summaries

    func addSessionSummary(_ summary: SessionSummary) {
        queue.sync {
            memory.sessionSummaries.append(summary)
            save()
        }
        NSLog("🧠 Saved session summary: %@ (%d topics)", summary.id, summary.topics.count)
    }

    func getSessionSummaries() -> [SessionSummary] {
        return queue.sync { memory.sessionSummaries }
    }

    func hasSessionForFile(_ filename: String) -> Bool {
        return queue.sync {
            memory.sessionSummaries.contains { $0.sourceFile == filename }
        }
    }

    // MARK: - User Profile

    func getUserProfile() -> UserProfile {
        return queue.sync { memory.userProfile }
    }

    func updateUserProfile(strengths: [String]?, weaknesses: [String]?) {
        queue.sync {
            if let strengths = strengths {
                for s in strengths {
                    let lower = s.lowercased()
                    if !memory.userProfile.strengths.contains(where: { $0.lowercased() == lower }) {
                        memory.userProfile.strengths.append(s)
                    }
                }
            }
            if let weaknesses = weaknesses {
                for w in weaknesses {
                    let lower = w.lowercased()
                    if !memory.userProfile.weaknesses.contains(where: { $0.lowercased() == lower }) {
                        memory.userProfile.weaknesses.append(w)
                    }
                }
            }
            memory.userProfile.lastUpdated = Date()
            save()
        }
    }

    // MARK: - Knowledge Entries

    func addKnowledge(topic: String, content: String, keywords: [String]) {
        let entry = KnowledgeEntry(
            id: UUID().uuidString,
            topic: topic,
            content: content,
            keywords: keywords,
            createdDate: Date(),
            lastUsedDate: nil
        )
        queue.sync {
            memory.knowledgeEntries.append(entry)
            save()
        }
    }

    // MARK: - Search

    func searchByTopics(_ topics: [String]) -> (sessions: [SessionSummary], knowledge: [KnowledgeEntry], profile: UserProfile) {
        return queue.sync {
            let topicsLower = topics.map { $0.lowercased() }

            let matchingSessions = memory.sessionSummaries.filter { session in
                session.topics.contains { topicsLower.contains($0.lowercased()) }
            }.suffix(3)

            let matchingKnowledge = memory.knowledgeEntries.filter { entry in
                topicsLower.contains(entry.topic.lowercased()) ||
                entry.keywords.contains { kw in topicsLower.contains(kw.lowercased()) }
            }

            return (Array(matchingSessions), matchingKnowledge, memory.userProfile)
        }
    }

    func sessionsDirectory() -> URL {
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/InterviewMaster/sessions")
    }
}
