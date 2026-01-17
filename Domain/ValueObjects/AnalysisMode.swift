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
        let codeLang = settings.programmingLanguage.codeBlockLang

        return """
        OUTPUT ONLY CODE. Nothing else.

        ```\(codeLang)
        [your solution here]
        ```
        **Time:** O(...) | **Space:** O(...)

        FORBIDDEN:
        - Text before the code block (no headers, no explanation)
        - Text after complexity (no "Key Points", no summary)
        - Docstrings (no triple-quote \"\"\" comments)
        - Questions back to user

        STYLE: Use # inline comments to explain logic. Clean code. Standard variable names.
        \(settings.languageInstruction)
        """
    }
}
