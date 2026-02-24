using System;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Domain.ValueObjects
{
    /// <summary>
    /// Value Object: Analysis Mode
    /// Smart analysis that adapts to screenshot content
    /// Migrated from Swift: AnalysisMode.swift
    /// </summary>
    public enum AnalysisMode
    {
        Smart
    }

    public static class AnalysisModeExtensions
    {
        /// <summary>
        /// Prefill to force model to start solution immediately (prevents preamble)
        /// Empty prefill since task type varies - prompt handles format
        /// </summary>
        public static string Prefill(this AnalysisMode mode) => string.Empty;

        /// <summary>
        /// Prompt template used for code-only output; uses AppSettings for language.
        /// </summary>
        public static string Prompt(this AnalysisMode mode)
        {
            var settings = AppSettings.Shared;
            var codeLang = settings.ProgrammingLanguage.GetCodeBlockLanguage();

            return $@"OUTPUT ONLY CODE. Nothing else.

```{codeLang}
[your solution here]
```
**Time:** O(...) | **Space:** O(...)

FORBIDDEN:
- Text before the code block (no headers, no explanation)
- Text after complexity (no Key Points, no summary)
- Docstrings (no triple-quote comments)
- Questions back to user

STYLE: Use # inline comments to explain logic. Clean code. Standard variable names.
{settings.LanguageInstruction}";
        }
    }
}

