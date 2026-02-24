using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace InterviewMasterApp.Infrastructure
{
    /// <summary>
    /// Simple JSON-based Q&A database for instant answers
    /// </summary>
    public sealed class QADatabase
    {
        private static readonly Lazy<QADatabase> _lazy = new(() => new QADatabase());
        public static QADatabase Shared => _lazy.Value;

        private readonly Dictionary<string, QAEntry> _database = new(StringComparer.OrdinalIgnoreCase);

        public record QAEntry(string Question, string Answer);

        private QADatabase()
        {
            LoadDatabase();
        }

        private void LoadDatabase()
        {
            var possiblePaths = new List<string?>
            {
                // App bundle or executable directory
                Path.Combine(AppContext.BaseDirectory, "qa_database.json"),
                Path.Combine(Directory.GetCurrentDirectory(), "Resources", "qa_database.json"),
                Path.Combine(AppContext.BaseDirectory, "Resources", "qa_database.json")
            };

            foreach (var path in possiblePaths.Where(p => !string.IsNullOrEmpty(p)))
            {
                if (File.Exists(path))
                {
                    try
                    {
                        var data = File.ReadAllBytes(path);
                        var doc = JsonSerializer.Deserialize<Dictionary<string, QAEntry>>(data);
                        if (doc != null)
                        {
                            foreach (var kv in doc)
                                _database[kv.Key] = kv.Value;

                            Console.WriteLine($"📚 QA Database loaded: {_database.Count} topics from {path}");
                            return;
                        }
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"❌ Failed to decode QA database: {ex.Message}");
                    }
                }
            }

            Console.WriteLine("⚠️ QA Database not found, will use LLM for all answers");
        }

        /// <summary>
        /// Get answer for a topic. Returns null if not found (use LLM fallback)
        /// </summary>
        public string GetAnswer(string topic)
        {
            if (string.IsNullOrWhiteSpace(topic)) return null;

            if (_database.TryGetValue(topic, out var entry)) return entry.Answer;

            var lower = topic.ToLowerInvariant();
            foreach (var kv in _database)
            {
                if (kv.Key.Equals(lower, StringComparison.OrdinalIgnoreCase)) return kv.Value.Answer;
            }

            return null;
        }

        /// <summary>
        /// Check if topic exists in database
        /// </summary>
        public bool HasTopic(string topic) => GetAnswer(topic) != null;

        /// <summary>
        /// Get all available topics
        /// </summary>
        public List<string> Topics => _database.Keys.OrderBy(k => k).ToList();
    }
}

