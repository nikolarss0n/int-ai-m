using System;
using System.Collections.Generic;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Domain entity representing AI analysis of a coding task.
    /// Migrated from Swift: Analysis.swift
    /// </summary>
    public class Analysis
    {
        public string Content { get; }
        public List<CodeBlock> CodeBlocks { get; }
        public DateTime CreatedAt { get; }

        public Analysis(string content, List<CodeBlock>? codeBlocks = null, DateTime? createdAt = null)
        {
            Content = content ?? throw new ArgumentNullException(nameof(content));
            CodeBlocks = codeBlocks ?? new List<CodeBlock>();
            CreatedAt = createdAt ?? DateTime.UtcNow;
        }

        /// <summary>
        /// Extract code blocks from markdown content using regex.
        /// Pattern: ```language\ncode\n```
        /// </summary>
        public static Analysis FromMarkdown(string markdownContent)
        {
            var codeBlocks = new List<CodeBlock>();

            if (string.IsNullOrWhiteSpace(markdownContent))
                return new Analysis(markdownContent ?? string.Empty, codeBlocks);

            // Regex pattern for markdown code blocks: ```language\ncode\n```
            var pattern = @"```(\w+)?\n([\s\S]*?)```";

            try
            {
                var regex = new System.Text.RegularExpressions.Regex(pattern);
                var matches = regex.Matches(markdownContent);

                foreach (System.Text.RegularExpressions.Match match in matches)
                {
                    var languageGroup = match.Groups[1];
                    var codeGroup = match.Groups[2];

                    var language = languageGroup.Success ? languageGroup.Value : "text";
                    var code = codeGroup.Success ? codeGroup.Value : "";

                    codeBlocks.Add(new CodeBlock(language, code));
                }
            }
            catch
            {
                // If regex parsing fails, return analysis without code blocks
            }

            return new Analysis(markdownContent ?? string.Empty, codeBlocks);
        }

        /// <summary>
        /// Get plain text without code blocks.
        /// </summary>
        public string TextOnly
        {
            get
            {
                if (string.IsNullOrWhiteSpace(Content))
                    return Content;

                var pattern = @"```(\w+)?\n[\s\S]*?```";
                var regex = new System.Text.RegularExpressions.Regex(pattern);
                var textWithoutCode = regex.Replace(Content, "");
                return textWithoutCode.Trim();
            }
        }

        /// <summary>
        /// Check if analysis has any code blocks.
        /// </summary>
        public bool HasCode => CodeBlocks.Count > 0;
    }
}

