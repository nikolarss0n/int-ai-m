import Foundation

struct LayoutConstants {
    struct Typography {
        static let hero: CGFloat = 24
        static let h1: CGFloat = 20
        static let h2: CGFloat = 18
        static let body: CGFloat = 15
        static let bodyLarge: CGFloat = 17
        static let caption: CGFloat = 13
        static let captionSmall: CGFloat = 11
        static let micro: CGFloat = 10
        static let code: CGFloat = 14
    }
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 30
    }
    struct CornerRadius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
        static let pill: CGFloat = 16
    }
    struct IconButton {
        static let size: CGFloat = 32
        static let iconSize: CGFloat = 16
        static let spacing: CGFloat = 8
    }
    struct Toolbar {
        static let height: CGFloat = 40
        static let dropdownHeight: CGFloat = 26
    }
    struct Timeline {
        static let messageSpacing: CGFloat = 15
        static let messagePadding: CGFloat = 10
        static let badgeSize: CGFloat = 22
        static let badgeGap: CGFloat = 8
        static let accentBarWidth: CGFloat = 3
    }
    struct Animation {
        static let fast: TimeInterval = 0.1
        static let normal: TimeInterval = 0.15
        static let slow: TimeInterval = 0.25
        static let pulse: TimeInterval = 0.5
    }
    struct Alpha {
        static let activeBackground: CGFloat = 0.15
        static let inactiveBackground: CGFloat = 0.08
        static let hoverBackground: CGFloat = 0.12
        static let subtleText: CGFloat = 0.5
        static let secondaryText: CGFloat = 0.7
    }
}

struct AppConstants {
    struct Models {
        static let anthropicHaiku = "claude-haiku-4-5-20251001"
        static let groqWhisper = "whisper-large-v3"
        static let groqLlama = "llama-3.3-70b-versatile"
    }
    struct APIURLs {
        static let anthropicMessages = "https://api.anthropic.com/v1/messages"
        static let groqTranscriptions = "https://api.groq.com/openai/v1/audio/transcriptions"
        static let groqChat = "https://api.groq.com/openai/v1/chat/completions"
    }
    struct Thresholds {
        static let dedupeWindow: TimeInterval = 5.0
        static let similarityThreshold: Double = 0.5
        static let bufferTimeout: TimeInterval = 10.0
        static let answerCooldown: TimeInterval = 12.0
        static let speechThreshold: Float = 0.5
        static let silenceTimeout: TimeInterval = 0.65
        static let minSpeechDuration: TimeInterval = 0.5
        static let slidingWindowSize = 6
        static let summarizationThreshold = 10
        static let maxConversationHistory = 50
    }
    struct MaxTokens {
        static let classification = 450
        static let answerStream = 250
        static let summarization = 150
        static let imageAnalysis = 4096
        static let groqAnswer = 200
        static let groqClassification = 20
        static let followUp = 200
    }
}
