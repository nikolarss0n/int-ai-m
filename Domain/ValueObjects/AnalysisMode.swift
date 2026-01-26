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

    /// Build prompt with detected line numbers for accurate AR overlay positioning
    func buildPrompt(ocrLines: [(lineNumber: Int, text: String)]? = nil) -> String {
        let settings = AppSettings.shared
        let codeLang = settings.programmingLanguage.codeBlockLang
        let langName = settings.programmingLanguage.displayName

        // Tell Claude which line numbers are visible (from Tesseract gutter detection)
        // We pass the line NUMBERS but not the text content (which may have OCR errors)
        var visibleLinesContext = ""
        if let lines = ocrLines, !lines.isEmpty {
            let lineNums = lines.map { $0.lineNumber }.sorted()
            visibleLinesContext = """

            VISIBLE LINE NUMBERS (from editor gutter): \(lineNums.map { "L\($0)" }.joined(separator: ", "))
            ⚠️ IMPORTANT: Use ONLY these line numbers in your response. They are detected from the gutter.

            """
        }

        return """
        ⚠️ CRITICAL: Write ALL code in \(langName.uppercased()) only. Never use any other language.
        Even if screenshot shows Java/Python/other, convert to \(langName).
        \(visibleLinesContext)
        Read the code DIRECTLY from the screenshot image.

        FIRST: Classify the screenshot:
        • CODING PROBLEM = problem statement, requirements, examples, constraints
        • CODE REVIEW = existing code (convert fixes to \(langName))

        ═══════════════════════════════════════════════════════════
        IF CODING PROBLEM → use this format (for AR overlay):
        ═══════════════════════════════════════════════════════════

        ⚠️ GIVE ONLY ONE SOLUTION - the optimal one. No alternatives.

        **🎯 Pattern:** <accurate technique name> - <why optimal for this problem>

        **📝 SOLUTION (line by line for AR overlay):**

        CODE_START: 6
        L1: int left = 0, right = n - 1; // WHY: two pointers bracket the search range
        L2: while (left < right) { // WHY: binary search terminates when range collapses
        L3:     int mid = left + (right - left) / 2; // WHY: avoids integer overflow vs (left+right)/2
        L4:     if (nums[mid] < target) left = mid + 1; // WHY: target cannot be in left half
        L5: }
        L6: return left; // WHY: left equals right at the answer position
        ... continue for ALL lines

        FORMAT RULES:
        - CODE_START: <line number where code typing area begins>
        - L1, L2, L3... sequential (L1 = first line of code)
        - L<num>: <code> // WHY: <reasoning/justification, NOT description of what code does>
        - SKIP comments on closing braces (just "L5: }" not "L5: } // WHY: ends loop")
        - WHY must answer "why this approach?" not "what does this do?"
          BAD: "// WHY: iterate from 2 to n" (describes WHAT)
          GOOD: "// WHY: F(0) and F(1) are base cases, start building from F(2)"

        **⏱️ Complexity:** (REQUIRED - always include this section)
        Time: O(?) - <explain why, e.g., "single pass through array">
        Space: O(?) - <explain why, e.g., "only two pointers, no extra data structures">

        📋 HOW TO USE:
        ```\(codeLang)
        [2-3 lines showing how to call the solution]
        ```

        ═══════════════════════════════════════════════════════════
        IF CODE REVIEW → use this format (for AR overlay):
        ═══════════════════════════════════════════════════════════

        **🔍 ISSUES FOUND:**

        ➤ L[number]: `exact line text from screenshot`
        FIX: [detailed explanation - WHY this is wrong, what rule it violates]
        ```\(codeLang)
        [correct \(langName) code - 1-3 lines]
        ```

        ➤ L[number]: `next problematic line`
        FIX: [detailed explanation]
        ```\(codeLang)
        [fix in \(langName)]
        ```

        (continue for ALL issues - check for:)
        • Syntax errors, typos, missing semicolons
        • Code that can't run in current context (e.g., loops in class body must be in method)
        • SOLID principles violations
        • OOP best practices
        • Code smells (magic numbers, long methods, etc.)
        • Missing error handling

        ───────────────────────────────────────────────────────────
        ✅ CORRECTED CODE (full working version):
        ───────────────────────────────────────────────────────────
        ```\(codeLang)
        [complete fixed code with all issues resolved]
        ```

        📋 HOW TO USE:
        ```\(codeLang)
        [2-3 lines showing how to instantiate and call methods]
        ```

        FORBIDDEN: No other languages except \(langName). No docstrings. No preamble.
        \(settings.languageInstruction)
        """
    }

    /// Legacy prompt without OCR context
    var prompt: String {
        return buildPrompt(ocrLines: nil)
    }
}
