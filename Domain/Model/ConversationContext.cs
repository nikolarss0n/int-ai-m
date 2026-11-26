using System;
using System.Collections.Generic;
using System.Linq;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Tracks conversation history for follow-up detection, topic tracking, and context-aware prompts.
    /// </summary>
    public class ConversationContext
    {
        public class Utterance
        {
            public string Text { get; set; }
            public Speaker Speaker { get; set; }
            public string? Topic { get; set; }
            public DateTime Timestamp { get; set; }
            public int? Sequence { get; set; }

            public Utterance(string text, Speaker speaker, string? topic, DateTime timestamp, int? sequence = null)
            {
                Text = text;
                Speaker = speaker;
                Topic = topic;
                Timestamp = timestamp;
                Sequence = sequence;
            }
        }

        public enum Speaker
        {
            Interviewer,
            Interviewee,
            Unknown
        }

        public class MultiTurnMessage
        {
            public string Role { get; set; }
            public string Content { get; set; }

            public MultiTurnMessage(string role, string content)
            {
                Role = role;
                Content = content;
            }
        }

        private readonly List<Utterance> _history = new();
        private string? _currentTopic;
        private int? _currentTopicSequence;
        private readonly int _maxHistory = AppConstants.Thresholds.MaxConversationHistory;
        private readonly object _lock = new();

        private string? _conversationSummary;
        private readonly int _slidingWindowSize = AppConstants.Thresholds.SlidingWindowSize;
        private readonly int _summarizationThreshold = AppConstants.Thresholds.SummarizationThreshold;

        public string? CurrentTopic { get { lock (_lock) return _currentTopic; } }
        public string? LastTopic { get { lock (_lock) return _currentTopic; } }
        public string? ConversationSummary { get { lock (_lock) return _conversationSummary; } }

        public IReadOnlyList<Utterance> History
        {
            get { lock (_lock) return _history.ToList().AsReadOnly(); }
        }

        public string? LastInterviewerQuestion
        {
            get
            {
                lock (_lock)
                {
                    for (int i = _history.Count - 1; i >= 0; i--)
                    {
                        if (_history[i].Speaker == Speaker.Interviewer)
                            return _history[i].Text;
                    }
                    return null;
                }
            }
        }

        public bool NeedsSummarization
        {
            get { lock (_lock) return _conversationSummary == null && _history.Count > _summarizationThreshold; }
        }

        public Speaker ClassifySpeaker(string text, bool isQuestion = false)
        {
            var trimmed = (text ?? string.Empty).Trim();
            var words = trimmed.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var wordCount = words.Length;
            var lower = trimmed.ToLowerInvariant();

            if (isQuestion) return Speaker.Interviewer;

            var hasQuestionMark = trimmed.Contains('?');
            var startsWithQuestion =
                lower.StartsWith("what") || lower.StartsWith("how") || lower.StartsWith("why") ||
                lower.StartsWith("can you") || lower.StartsWith("could you") || lower.StartsWith("tell me") ||
                lower.StartsWith("explain") || lower.StartsWith("describe") || lower.StartsWith("walk me") ||
                lower.StartsWith("so ") || lower.StartsWith("let's assume");

            var isFollowUp =
                lower.Contains("tell me more") || lower.Contains("dig deeper") ||
                lower.Contains("elaborate") || lower.Contains("can you expand") ||
                lower.Contains("more details") || lower.Contains("give me an example");

            var isInterviewerPhrase =
                lower.Contains("welcome to") || lower.Contains("good evening") ||
                lower.Contains("good morning") || lower.Contains("shall proceed") ||
                lower.Contains("gone through your resume") || lower.Contains("let me ask");

            if (wordCount < 25 && (hasQuestionMark || startsWithQuestion || isFollowUp || isInterviewerPhrase))
                return Speaker.Interviewer;

            if (wordCount > 15)
                return Speaker.Interviewee;

            return Speaker.Unknown;
        }

        public bool IsFollowUp(string text)
        {
            var lower = (text ?? string.Empty).ToLowerInvariant();
            string[] phrases =
            {
                "tell me more", "dig deeper", "elaborate", "expand on",
                "more details", "give me an example", "can you explain",
                "what else", "go deeper", "more about", "continue"
            };
            return phrases.Any(p => lower.Contains(p));
        }

        public void AddUtterance(string text, string? topic, bool isQuestion = false, int? sequence = null)
        {
            var speaker = ClassifySpeaker(text, isQuestion);
            var utterance = new Utterance(text, speaker, topic, DateTime.UtcNow, sequence);

            lock (_lock)
            {
                if (sequence.HasValue)
                {
                    var insertIdx = _history.FindIndex(u => (u.Sequence ?? int.MinValue) > sequence.Value);
                    if (insertIdx >= 0) _history.Insert(insertIdx, utterance);
                    else _history.Add(utterance);
                }
                else
                {
                    _history.Add(utterance);
                }

                var topicLower = topic?.ToLowerInvariant();
                if (!string.IsNullOrWhiteSpace(topic) &&
                    topicLower != "unknown" &&
                    topicLower != "followup" &&
                    topicLower != "answer")
                {
                    if (sequence.HasValue)
                    {
                        if (!_currentTopicSequence.HasValue || sequence.Value >= _currentTopicSequence.Value)
                        {
                            _currentTopic = topic;
                            _currentTopicSequence = sequence;
                        }
                    }
                    else
                    {
                        _currentTopic = topic;
                    }
                }

                while (_history.Count > _maxHistory)
                    _history.RemoveAt(0);
            }
        }

        public string GetContextForLLM()
        {
            lock (_lock)
            {
                if (_history.Count == 0) return "No previous conversation.";

                var recent = _history.TakeLast(5);
                return string.Join("\n", recent.Select(u =>
                {
                    var label = u.Speaker switch
                    {
                        Speaker.Interviewer => "Interviewer",
                        Speaker.Interviewee => "Candidate",
                        _ => "Other"
                    };
                    var text = u.Text.Length > 260 ? u.Text[..260] + "…" : u.Text;
                    return $"{label}: {text}";
                }));
            }
        }

        public string GetFullConversation()
        {
            lock (_lock)
            {
                if (_history.Count == 0) return string.Empty;
                return string.Join("\n", _history.Select(u =>
                    $"{(u.Speaker == Speaker.Interviewer ? "Q" : "A")}: {u.Text}"));
            }
        }

        public string GetTopicsSummary()
        {
            lock (_lock)
            {
                var topics = _history
                    .Select(u => u.Topic)
                    .Where(t => !string.IsNullOrWhiteSpace(t) &&
                                !t.Equals("unknown", StringComparison.OrdinalIgnoreCase) &&
                                !t.Equals("followup", StringComparison.OrdinalIgnoreCase) &&
                                !t.Equals("answer", StringComparison.OrdinalIgnoreCase))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList();
                return topics.Count == 0 ? string.Empty : "Topics discussed: " + string.Join(", ", topics);
            }
        }

        public void Clear()
        {
            lock (_lock)
            {
                _history.Clear();
                _currentTopic = null;
                _currentTopicSequence = null;
                _conversationSummary = null;
            }
        }

        public List<Utterance> GetMessagesForSummarization()
        {
            lock (_lock)
            {
                if (_history.Count <= _slidingWindowSize) return new List<Utterance>();
                return _history.Take(_history.Count - _slidingWindowSize).ToList();
            }
        }

        public string GetTextForSummarization()
        {
            var oldMessages = GetMessagesForSummarization();
            return string.Join("\n", oldMessages.Select(u =>
                $"{(u.Speaker == Speaker.Interviewer ? "Interviewer" : "Candidate")}: {u.Text}"));
        }

        public void SetSummary(string summary)
        {
            lock (_lock)
            {
                _conversationSummary = summary;
                if (_history.Count > _slidingWindowSize)
                {
                    var keep = _history.TakeLast(_slidingWindowSize).ToList();
                    _history.Clear();
                    _history.AddRange(keep);
                }
            }
        }

        public List<MultiTurnMessage> BuildMultiTurnMessages(string currentUtterance, string? pinnedSolution = null)
        {
            lock (_lock)
            {
                var messages = new List<MultiTurnMessage>();

                if (!string.IsNullOrWhiteSpace(_conversationSummary))
                {
                    var contextContent = $"Previous interview context: {_conversationSummary}";
                    if (!string.IsNullOrWhiteSpace(pinnedSolution))
                        contextContent += $"\n\nCurrent code solution being discussed:\n{pinnedSolution}";
                    messages.Add(new MultiTurnMessage("user", contextContent));
                    messages.Add(new MultiTurnMessage("assistant", "I understand the context. I'll help with the interview questions."));
                }
                else if (!string.IsNullOrWhiteSpace(pinnedSolution))
                {
                    messages.Add(new MultiTurnMessage("user", $"Current code solution being discussed:\n{pinnedSolution}"));
                    messages.Add(new MultiTurnMessage("assistant", "I see the code. I'll help with questions about it."));
                }

                var recentHistory = _conversationSummary != null
                    ? _history
                    : _history.TakeLast(_slidingWindowSize).ToList();

                foreach (var u in recentHistory)
                {
                    var role = u.Speaker == Speaker.Interviewer ? "user" : "assistant";
                    messages.Add(new MultiTurnMessage(role, u.Text));
                }

                messages.Add(new MultiTurnMessage("user", currentUtterance));
                return messages;
            }
        }

        public List<object> MessagesToAPIFormat(List<MultiTurnMessage> messages)
        {
            var result = new List<Dictionary<string, string>>();
            string? lastRole = null;

            foreach (var msg in messages)
            {
                if (msg.Role == lastRole && result.Count > 0)
                {
                    result[^1]["content"] = result[^1]["content"] + "\n\n" + msg.Content;
                }
                else
                {
                    result.Add(new Dictionary<string, string>
                    {
                        ["role"] = msg.Role,
                        ["content"] = msg.Content
                    });
                    lastRole = msg.Role;
                }
            }

            if (result.Count == 0 || result[0]["role"] != "user")
            {
                result.Insert(0, new Dictionary<string, string>
                {
                    ["role"] = "user",
                    ["content"] = "(Interview in progress)"
                });
            }

            return result.Cast<object>().ToList();
        }
    }
}
