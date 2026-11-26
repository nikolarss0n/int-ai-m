using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using InterviewMasterApp.Application;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Infrastructure.Storage
{
    public sealed class MemoryStore : IMemoryStore
    {
        private static readonly Lazy<MemoryStore> _lazy = new(() => new MemoryStore());
        public static MemoryStore Shared => _lazy.Value;

        private readonly object _lock = new();
        private readonly string _filePath;
        private InterviewMemory _memory = new();

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            WriteIndented = true,
            PropertyNameCaseInsensitive = true
        };

        private MemoryStore()
            : this(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "InterviewMaster"))
        {
        }

        public MemoryStore(string directoryPath)
        {
            try { Directory.CreateDirectory(directoryPath); } catch { }
            _filePath = Path.Combine(directoryPath, "memory.json");
            Load();
        }

        private void Load()
        {
            lock (_lock)
            {
                try
                {
                    if (!File.Exists(_filePath)) return;
                    var json = File.ReadAllText(_filePath);
                    _memory = JsonSerializer.Deserialize<InterviewMemory>(json, JsonOptions) ?? new InterviewMemory();
                }
                catch
                {
                    _memory = new InterviewMemory();
                }
            }
        }

        private void SaveLocked()
        {
            try
            {
                var dir = Path.GetDirectoryName(_filePath);
                if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
                var tmp = _filePath + ".tmp";
                File.WriteAllText(tmp, JsonSerializer.Serialize(_memory, JsonOptions));
                File.Move(tmp, _filePath, overwrite: true);
            }
            catch { }
        }

        public void AddSessionSummary(SessionSummary summary)
        {
            lock (_lock)
            {
                _memory.SessionSummaries.Add(summary);
                SaveLocked();
            }
        }

        public IReadOnlyList<SessionSummary> GetSessionSummaries()
        {
            lock (_lock) return _memory.SessionSummaries.ToList();
        }

        public bool HasSessionForFile(string filename)
        {
            lock (_lock) return _memory.SessionSummaries.Any(s => string.Equals(s.SourceFile, filename, StringComparison.OrdinalIgnoreCase));
        }

        public UserProfile GetUserProfile()
        {
            lock (_lock) return _memory.UserProfile;
        }

        public void UpdateUserProfile(IEnumerable<string>? strengths, IEnumerable<string>? weaknesses)
        {
            lock (_lock)
            {
                if (strengths != null)
                {
                    foreach (var s in strengths)
                    {
                        if (!string.IsNullOrWhiteSpace(s) && !_memory.UserProfile.Strengths.Any(e => e.Equals(s, StringComparison.OrdinalIgnoreCase)))
                            _memory.UserProfile.Strengths.Add(s.Trim());
                    }
                }
                if (weaknesses != null)
                {
                    foreach (var w in weaknesses)
                    {
                        if (!string.IsNullOrWhiteSpace(w) && !_memory.UserProfile.Weaknesses.Any(e => e.Equals(w, StringComparison.OrdinalIgnoreCase)))
                            _memory.UserProfile.Weaknesses.Add(w.Trim());
                    }
                }
                _memory.UserProfile.LastUpdated = DateTime.UtcNow;
                SaveLocked();
            }
        }

        public void AddKnowledge(string topic, string content, IEnumerable<string> keywords)
        {
            lock (_lock)
            {
                _memory.KnowledgeEntries.Add(new KnowledgeEntry
                {
                    Id = Guid.NewGuid().ToString(),
                    Topic = topic,
                    Content = content,
                    Keywords = keywords.ToList(),
                    CreatedDate = DateTime.UtcNow
                });
                SaveLocked();
            }
        }

        public (List<SessionSummary> Sessions, List<KnowledgeEntry> Knowledge, UserProfile Profile) SearchByTopics(IReadOnlyList<string> topics)
        {
            lock (_lock)
            {
                var set = new HashSet<string>(topics.Select(t => t.ToLowerInvariant()));
                var sessions = _memory.SessionSummaries
                    .Where(s => s.Topics.Any(t => set.Contains(t.ToLowerInvariant())))
                    .TakeLast(3)
                    .ToList();
                var knowledge = _memory.KnowledgeEntries
                    .Where(k => set.Contains(k.Topic.ToLowerInvariant()) || k.Keywords.Any(kw => set.Contains(kw.ToLowerInvariant())))
                    .ToList();
                return (sessions, knowledge, _memory.UserProfile);
            }
        }
    }

    public sealed class ResumeStore : IResumeStore
    {
        private static readonly Lazy<ResumeStore> _lazy = new(() => new ResumeStore());
        public static ResumeStore Shared => _lazy.Value;

        private readonly object _lock = new();
        private readonly string _filePath;
        private ResumeRecord _record = new();

        private sealed class ResumeRecord
        {
            public string ExtractedText { get; set; } = string.Empty;
            public string FileName { get; set; } = string.Empty;
            public string SourcePath { get; set; } = string.Empty;
        }

        private ResumeStore()
            : this(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "InterviewMaster"))
        {
        }

        public ResumeStore(string directoryPath)
        {
            try { Directory.CreateDirectory(directoryPath); } catch { }
            _filePath = Path.Combine(directoryPath, "resume.json");
            Load();
        }

        public string ExtractedText { get { lock (_lock) return _record.ExtractedText; } }
        public string FileName { get { lock (_lock) return _record.FileName; } }
        public string SourcePath { get { lock (_lock) return _record.SourcePath; } }
        public bool HasResume { get { lock (_lock) return !string.IsNullOrWhiteSpace(_record.ExtractedText); } }

        public void SetText(string text, string fileName = "CV")
        {
            var extracted = InterviewBriefingHelper.ExtractResumeText(text ?? string.Empty);
            lock (_lock)
            {
                _record = new ResumeRecord
                {
                    ExtractedText = extracted,
                    FileName = fileName,
                    SourcePath = string.Empty
                };
                SaveLocked();
            }
            AppNotifications.RaiseResumeChanged();
        }

        public void AttachFile(string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath) || !File.Exists(filePath))
                throw new FileNotFoundException("Resume file not found.", filePath);

            var raw = File.ReadAllText(filePath);
            var extracted = InterviewBriefingHelper.ExtractResumeText(raw);
            if (string.IsNullOrWhiteSpace(extracted))
                throw new InvalidOperationException("Could not read any text from that file.");

            lock (_lock)
            {
                _record = new ResumeRecord
                {
                    ExtractedText = extracted,
                    FileName = Path.GetFileName(filePath),
                    SourcePath = filePath
                };
                SaveLocked();
            }
            AppNotifications.RaiseResumeChanged();
        }

        public void Clear()
        {
            lock (_lock)
            {
                _record = new ResumeRecord();
                try { if (File.Exists(_filePath)) File.Delete(_filePath); } catch { }
            }
            AppNotifications.RaiseResumeChanged();
        }

        private void Load()
        {
            lock (_lock)
            {
                try
                {
                    if (!File.Exists(_filePath)) return;
                    var json = File.ReadAllText(_filePath);
                    _record = JsonSerializer.Deserialize<ResumeRecord>(json) ?? new ResumeRecord();
                }
                catch { _record = new ResumeRecord(); }
            }
        }

        private void SaveLocked()
        {
            try
            {
                var dir = Path.GetDirectoryName(_filePath);
                if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
                File.WriteAllText(_filePath, JsonSerializer.Serialize(_record, new JsonSerializerOptions { WriteIndented = true }));
            }
            catch { }
        }
    }
}
