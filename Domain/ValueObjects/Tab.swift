import Foundation

/// Value Object: Tab
/// Represents the different tabs/views in the application
enum Tab {
    case notes
    case coding
    case voice
    case practice

    var title: String {
        switch self {
        case .notes:
            return "📝 Interview Notes"
        case .coding:
            return "💻 Coding Task"
        case .voice:
            return "🎤 Voice Assistant"
        case .practice:
            return "Practice"
        }
    }

    var keyboardShortcut: String {
        switch self {
        case .notes:
            return "⌘1"
        case .coding:
            return "⌘2"
        case .voice:
            return "⌘3"
        case .practice:
            return "⌘4"
        }
    }
}
