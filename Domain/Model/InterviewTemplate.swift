import Foundation

struct InterviewTemplate {
    let id: String
    let name: String
    let description: String
    let category: Category
    let questions: [TemplateQuestion]

    enum Category: String, CaseIterable {
        case behavioral
        case systemDesign
        case testAutomation
        case coding
        case languageSpecific

        var displayName: String {
            switch self {
            case .behavioral: return "Behavioral"
            case .systemDesign: return "System Design"
            case .testAutomation: return "QA/SDET"
            case .coding: return "Coding"
            case .languageSpecific: return "Language-Specific"
            }
        }
    }
}

struct TemplateQuestion {
    let text: String
    let topic: String
    let difficulty: Difficulty
    let hints: [String]

    enum Difficulty: String {
        case easy
        case medium
        case hard
    }
}
