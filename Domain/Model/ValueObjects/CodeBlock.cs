using System;
using System.Collections.Generic;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Value object representing a code block with language and content.
    /// Migrated from Swift: CodeBlock.swift
    /// </summary>
    public class CodeBlock
    {
        public string Language { get; }
        public string Code { get; }

        public CodeBlock(string language, string code)
        {
            Language = (language ?? "text").Trim();
            Code = code ?? "";
        }

        /// <summary>
        /// Check if code block is empty.
        /// </summary>
        public bool IsEmpty => string.IsNullOrWhiteSpace(Code);

        /// <summary>
        /// Get language display name.
        /// </summary>
        public string DisplayLanguage
        {
            get
            {
                return Language.ToLower() switch
                {
                    "python" or "py" => "Python",
                    "javascript" or "js" => "JavaScript",
                    "typescript" or "ts" => "TypeScript",
                    "java" => "Java",
                    "cpp" or "c++" => "C++",
                    "csharp" or "c#" => "C#",
                    "swift" => "Swift",
                    "go" => "Go",
                    "rust" or "rs" => "Rust",
                    "kotlin" => "Kotlin",
                    _ => char.ToUpper(Language[0]) + Language.Substring(1)
                };
            }
        }

        public override bool Equals(object? obj)
        {
            return obj is CodeBlock other &&
                   Language == other.Language &&
                   Code == other.Code;
        }

        public override int GetHashCode()
        {
            return HashCode.Combine(Language, Code);
        }

        public override string ToString()
        {
            return $"CodeBlock({DisplayLanguage}, {Code.Length} chars)";
        }
    }
}
