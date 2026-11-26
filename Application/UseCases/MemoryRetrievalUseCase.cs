using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Application.UseCases
{
    public sealed class MemoryRetrievalUseCase
    {
        private readonly IMemoryStore? _memoryStore;
        private readonly int _maxTokenBudget = AppConstants.MaxTokens.MemoryContext;

        public MemoryRetrievalUseCase(IMemoryStore? memoryStore = null)
        {
            _memoryStore = memoryStore;
        }

        public string? Retrieve(IReadOnlyList<string> topics)
        {
            if (_memoryStore == null || topics == null || topics.Count == 0) return null;

            var (sessions, knowledge, profile) = _memoryStore.SearchByTopics(topics);
            var parts = new List<string>();

            if (sessions.Count > 0)
            {
                var topicName = topics[0];
                parts.Add($"You've been asked about {topicName} {sessions.Count} time{(sessions.Count == 1 ? "" : "s")} before");
                var latest = sessions[^1];
                foreach (var insight in latest.KeyInsights.Take(2))
                    parts.Add(insight);
            }

            var topicsLower = new HashSet<string>(topics.Select(t => t.ToLowerInvariant()));
            var strengths = profile.Strengths.Where(s => topicsLower.Any(t => s.Contains(t, StringComparison.OrdinalIgnoreCase))).ToList();
            var weaknesses = profile.Weaknesses.Where(w => topicsLower.Any(t => w.Contains(t, StringComparison.OrdinalIgnoreCase))).ToList();

            if (strengths.Count > 0) parts.Add("Strength: " + string.Join(", ", strengths));
            if (weaknesses.Count > 0) parts.Add("Area to improve: " + string.Join(", ", weaknesses));

            foreach (var entry in knowledge.Take(2))
                parts.Add($"Your note: \"{entry.Content}\"");

            if (parts.Count == 0) return null;

            var sb = new StringBuilder("MEMORY (from past sessions):\n");
            var maxChars = _maxTokenBudget * 4;
            foreach (var part in parts)
            {
                var line = $"• {part}\n";
                if (sb.Length + line.Length > maxChars) break;
                sb.Append(line);
            }
            return sb.ToString();
        }
    }
}
