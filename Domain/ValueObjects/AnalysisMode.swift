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
        FIRST: Classify the screenshot:
        • CODING PROBLEM = problem statement, requirements, examples, constraints
        • CODE REVIEW = existing class/function with method bodies

        ═══════════════════════════════════════════════════════════
        IF CODING PROBLEM → use this format:
        ═══════════════════════════════════════════════════════════

        **🎯 Pattern:** [Name] - [why this pattern fits]
        (Sliding Window, Two Pointers, Hash Map, BFS/DFS, DP, Binary Search, etc.)

        ```\(codeLang)
        # Step-by-step comments explaining WHY each part
        [solution code]
        ```

        **⏱️ Complexity:** Time O(?) | Space O(?)

        ═══════════════════════════════════════════════════════════
        IF CODE REVIEW → use this format:
        ═══════════════════════════════════════════════════════════

        **🔍 ISSUES FOUND:**

        1️⃣ **[PRINCIPLE]** → `methodName()`
           ⚠️ Problem: [what's wrong]
           ✅ Fix: [simple solution]

        2️⃣ **[PRINCIPLE]** → `methodName()`
           ⚠️ Problem: [what's wrong]
           ✅ Fix: [simple solution]

        (continue for each issue)

        **📝 REFACTOR:**
        ```\(codeLang)
        // key improvement snippet
        ```

        ───────────────────────────────────────────────────────────
        CHECK: SOLID (SRP, OCP, DIP) | OOP (Encapsulation, Polymorphism)
               Patterns (Strategy, Factory) | Smells (magic numbers, god class)
        ───────────────────────────────────────────────────────────

        FORBIDDEN: No docstrings, no preamble, no questions back.
        \(settings.languageInstruction)
        """
    }
}
