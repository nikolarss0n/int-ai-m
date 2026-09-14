import Foundation

/// Value Object: Analysis Mode
/// Smart analysis that adapts to screenshot content
enum AnalysisMode {
    case smart

    /// Prefill to force model to start solution immediately (prevents preamble)
    /// Empty prefill since task type varies - prompt handles format
    var prefill: String {
        return ""
    }

    var prompt: String {
        let settings = AppSettings.shared
        return codingInterviewStepsPrompt(
            language: settings.programmingLanguage.codeBlockLang,
            task: "Read the screenshot(s) and implement the asked coding task as typed steps."
        ) + "\n\(settings.languageInstruction)"
    }
}
