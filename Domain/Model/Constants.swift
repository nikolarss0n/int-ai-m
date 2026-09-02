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
        static let horizontalInset: CGFloat = 20
        static let badgeSize: CGFloat = 22
        static let badgeGap: CGFloat = 8
        static let answerIndent: CGFloat = 20
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
        /// xAI Grok used for classification + answer streaming (Haiku replacement).
        /// Non-reasoning variant prioritizes time-to-first-token for live interview cues.
        static let xaiGrok = "grok-4.20-0309-non-reasoning"
        static let groqWhisper = "whisper-large-v3-turbo"
        static let groqFastClassification = "openai/gpt-oss-20b"
        /// 20B is faster to first/last token than 120B on cue-card answers
        /// without a quality drop on the voice bench.
        static let groqFastAnswer = "openai/gpt-oss-20b"
        static let groqChatModel = groqFastAnswer
    }
    struct APIURLs {
        static let anthropicMessages = "https://api.anthropic.com/v1/messages"
        static let xaiChat = "https://api.x.ai/v1/chat/completions"
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
        /// Start STT as soon as silence looks real so transcription overlaps
        /// the remaining end-of-speech wait. Keep this below silenceTimeout.
        static let speculativeSilenceTimeout: TimeInterval = 0.25
        static let minSpeechDuration: TimeInterval = 0.5
        static let directHaikuFirstChunkTimeout: TimeInterval = 1.1
        static let slidingWindowSize = 6
        static let summarizationThreshold = 10
        static let maxConversationHistory = 50
    }
    struct MaxTokens {
        static let classification = 320
        static let answerStream = 450
        static let summarization = 150
        static let imageAnalysis = 4096
        static let groqAnswer = 280
        static let groqClassification = 240
        static let followUp = 350
        static let memoryContext = 200
        static let sessionAnalysis = 300
    }
    struct Limits {
        static let groqWhisperPromptBytes = 896
    }
}

enum SpeechTurnEmit: Equatable {
    case speculativePreview
    case speechResumedAfterPreview
    case finalSilence
}

enum SpeechTurnAction: Equatable {
    case prefetchTranscriptionOnly
    case cancelInFlightWork
    case commitAnswer
}

enum SpeechTurnPolicy {
    static func action(for emit: SpeechTurnEmit) -> SpeechTurnAction {
        switch emit {
        case .speculativePreview:
            return .prefetchTranscriptionOnly
        case .speechResumedAfterPreview:
            return .cancelInFlightWork
        case .finalSilence:
            return .commitAnswer
        }
    }

    static func startsAnswerCard(_ action: SpeechTurnAction) -> Bool {
        action == .commitAnswer
    }
}

enum GroqRequestTuning {
    static let cueCardPrefill = "- "

    static func transcriptionUpload(for audioData: Data) -> (filename: String, mimeType: String) {
        if audioData.count >= 12 {
            let header = audioData.prefix(12)
            if header.starts(with: Data("RIFF".utf8)),
               header.suffix(4) == Data("WAVE".utf8) {
                return ("audio.wav", "audio/wav")
            }
        }
        if audioData.count >= 8 {
            let brand = audioData.subdata(in: 4..<8)
            if brand == Data("ftyp".utf8) {
                return ("audio.m4a", "audio/mp4")
            }
        }
        return ("audio.wav", "audio/wav")
    }

    static func chatReasoningFields(for model: String) -> [String: Any] {
        if model.hasPrefix("openai/gpt-oss") {
            return [
                "reasoning_effort": "low",
                "include_reasoning": false
            ]
        }
        if model.hasPrefix("qwen/") {
            return ["reasoning_effort": "none"]
        }
        return [:]
    }

    static func chatMessages(userPrompt: String) -> [[String: String]] {
        [
            ["role": "user", "content": userPrompt],
            ["role": "assistant", "content": cueCardPrefill]
        ]
    }

    static func visibleCueCardPrefix(for firstChunk: String) -> String {
        let trimmed = firstChunk.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("-") {
            return ""
        }
        return cueCardPrefill
    }
}
