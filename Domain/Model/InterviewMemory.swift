import Foundation

struct InterviewMemory: Codable {
    var userProfile: UserProfile
    var sessionSummaries: [SessionSummary]
    var knowledgeEntries: [KnowledgeEntry]

    init() {
        self.userProfile = UserProfile()
        self.sessionSummaries = []
        self.knowledgeEntries = []
    }
}

struct UserProfile: Codable {
    var strengths: [String]
    var weaknesses: [String]
    var experience: [String]
    var lastUpdated: Date

    init() {
        self.strengths = []
        self.weaknesses = []
        self.experience = []
        self.lastUpdated = Date()
    }
}

struct SessionSummary: Codable {
    let id: String
    let date: Date
    let topics: [String]
    let questionsAsked: Int
    let keyInsights: [String]
    let sourceFile: String
}

struct KnowledgeEntry: Codable {
    let id: String
    var topic: String
    var content: String
    var keywords: [String]
    let createdDate: Date
    var lastUsedDate: Date?
}
