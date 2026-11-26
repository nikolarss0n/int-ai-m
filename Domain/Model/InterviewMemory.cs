using System;
using System.Collections.Generic;

namespace InterviewMasterApp.Domain.Model
{
    public sealed class InterviewMemory
    {
        public UserProfile UserProfile { get; set; } = new();
        public List<SessionSummary> SessionSummaries { get; set; } = new();
        public List<KnowledgeEntry> KnowledgeEntries { get; set; } = new();
    }

    public sealed class UserProfile
    {
        public List<string> Strengths { get; set; } = new();
        public List<string> Weaknesses { get; set; } = new();
        public List<string> Experience { get; set; } = new();
        public DateTime LastUpdated { get; set; } = DateTime.UtcNow;
    }

    public sealed class SessionSummary
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public DateTime Date { get; set; } = DateTime.UtcNow;
        public List<string> Topics { get; set; } = new();
        public int QuestionsAsked { get; set; }
        public List<string> KeyInsights { get; set; } = new();
        public string SourceFile { get; set; } = string.Empty;
    }

    public sealed class KnowledgeEntry
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public string Topic { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public List<string> Keywords { get; set; } = new();
        public DateTime CreatedDate { get; set; } = DateTime.UtcNow;
        public DateTime? LastUsedDate { get; set; }
    }
}
