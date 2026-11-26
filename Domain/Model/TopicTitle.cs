using System;
using System.Collections.Generic;
using System.Text;

namespace InterviewMasterApp.Domain.Model
{
    public static class TopicTitle
    {
        public const string Unknown = "Live answer";

        private static readonly Dictionary<string, string> Phrases = new(StringComparer.OrdinalIgnoreCase)
        {
            ["ragcag"] = "RAG and CAG",
            ["followup"] = "Follow-up",
            ["kmeans"] = "K-means",
            ["genai"] = "Generative AI",
            ["finetuning"] = "Fine-tuning",
            ["biasvariance"] = "Bias-variance",
            ["crossvalidation"] = "Cross-validation",
            ["precisionrecall"] = "Precision and recall",
            ["webfirstassertions"] = "Web-first assertions",
            ["autowaiting"] = "Auto-waiting",
            ["langchain"] = "LangChain",
            ["huggingface"] = "Hugging Face",
            ["playwrighttest"] = "Playwright Test"
        };

        private static readonly Dictionary<string, string> Words = new(StringComparer.OrdinalIgnoreCase)
        {
            ["ai"] = "AI", ["api"] = "API", ["aws"] = "AWS", ["cag"] = "CAG", ["cicd"] = "CI/CD", ["cpp"] = "C++", ["csharp"] = "C#",
            ["dbscan"] = "DBSCAN", ["devops"] = "DevOps", ["dotnet"] = ".NET", ["e2e"] = "E2E", ["fastapi"] = "FastAPI",
            ["graphql"] = "GraphQL", ["javascript"] = "JavaScript", ["jvm"] = "JVM", ["linq"] = "LINQ", ["llm"] = "LLM",
            ["ml"] = "ML", ["mlops"] = "MLOps", ["nlp"] = "NLP", ["nosql"] = "NoSQL", ["oop"] = "OOP", ["auc"] = "AUC", ["pr"] = "PR",
            ["rag"] = "RAG", ["rest"] = "REST", ["roc"] = "ROC", ["solid"] = "SOLID", ["sql"] = "SQL", ["stl"] = "STL",
            ["swiftui"] = "SwiftUI", ["typescript"] = "TypeScript", ["ui"] = "UI", ["uikit"] = "UIKit"
        };

        public static string Display(string? topic)
        {
            var trimmed = (topic ?? string.Empty).Trim();
            if (string.IsNullOrEmpty(trimmed) || trimmed.Equals("unknown", StringComparison.OrdinalIgnoreCase))
                return Unknown;

            var key = new StringBuilder();
            foreach (var c in trimmed.ToLowerInvariant())
            {
                if (char.IsLetterOrDigit(c)) key.Append(c);
            }
            if (Phrases.TryGetValue(key.ToString(), out var phrase)) return phrase;

            var parts = Split(trimmed);
            for (int i = 0; i < parts.Count; i++)
            {
                var lower = parts[i].ToLowerInvariant();
                if (Words.TryGetValue(lower, out var exact))
                    parts[i] = exact;
                else if (i == 0 && lower.Length > 0)
                    parts[i] = char.ToUpperInvariant(lower[0]) + lower[1..];
                else
                    parts[i] = lower;
            }
            return string.Join(" ", parts);
        }

        public static List<string> Split(string topic)
        {
            var parts = new List<string>();
            var current = new StringBuilder();
            for (int i = 0; i < topic.Length; i++)
            {
                var ch = topic[i];
                if (ch is '_' or '-' or ' ')
                {
                    if (current.Length > 0) { parts.Add(current.ToString()); current.Clear(); }
                    continue;
                }
                if (char.IsUpper(ch) && current.Length > 0)
                {
                    var prev = current[^1];
                    char? next = i + 1 < topic.Length ? topic[i + 1] : null;
                    var endsWord = char.IsLower(prev) || char.IsDigit(prev) ||
                                   (char.IsUpper(prev) && next.HasValue && char.IsLower(next.Value));
                    if (endsWord)
                    {
                        parts.Add(current.ToString());
                        current.Clear();
                    }
                }
                current.Append(ch);
            }
            if (current.Length > 0) parts.Add(current.ToString());
            return parts;
        }
    }

    public static class ScreenshotPresentation
    {
        public static bool ShouldPresentOverlay(bool mainWindowVisible) => true;

        public static string LiveScreenshotStatusText(int count) => count switch
        {
            <= 0 => string.Empty,
            1 => "1 screenshot · Ctrl+Alt+Enter analyze",
            _ => $"{count} screenshots · Ctrl+Alt+Enter analyze"
        };
    }
}
