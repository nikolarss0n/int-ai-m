using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Tracks conversation history for follow-up detection and context-aware responses.
    /// Migrated from Swift: ConversationContext.swift
    /// </summary>
    public class ConversationContext
    {
        public class Utterance
        {
            public string Text { get; set; }
            public Speaker Speaker { get; set; }
            public string? Topic { get; set; }
            public DateTime Timestamp { get; set; }

            public Utterance(string text, Speaker speaker, string? topic, DateTime timestamp)
            {
                Text = text;
                Speaker = speaker;
                Topic = topic;
                Timestamp = timestamp;
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
            public string Role { get; set; }  // "user" or "assistant"
            public string Content { get; set; }

            public MultiTurnMessage(string role, string content)
            {
                Role = role;
                Content = content;
            }
        }

        private List<Utterance> _history = new();
        private string? _currentTopic;
        private readonly int _maxHistory = 50;  // AppConstants.Thresholds.maxConversationHistory
        private readonly object _lock = new object();

        private string? _conversationSummary;
        private readonly int _slidingWindowSize = 6;
        private readonly int _summarizationThreshold = 10;

        // MARK: - Properties

        public string? CurrentTopic => _currentTopic;
        public string? LastTopic => _currentTopic;
        public IReadOnlyList<Utterance> History => _history.AsReadOnly();
        public bool NeedsSummarization => _conversationSummary == null && _history.Count > _summarizationThreshold;

        // MARK: - Speaker Classification

        /// <summary>
        /// Classify speaker based on heuristics.
        /// </summary>
        public Speaker ClassifySpeaker(string text, bool isQuestion = false)
        {
            var trimmed = (text ?? "").Trim();
            var words = trimmed.Split(' ');
            var wordCount = words.Length;
            var lowercased = trimmed.ToLower();

            // If LLM already classified as question, it's the interviewer
            if (isQuestion)
                return Speaker.Interviewer;

            // Question indicators
            var hasQuestionMark = trimmed.Contains("?");
            var startsWithQuestion = lowercased.StartsWith("what ") ||
                                      lowercased.StartsWith("how ") ||
                                      lowercased.StartsWith("why ") ||
                                      lowercased.StartsWith("can you ") ||
                                      lowercased.StartsWith("could you ") ||
                                      lowercased.StartsWith("tell me ") ||
                                      lowercased.StartsWith("explain ") ||
                                      lowercased.StartsWith("describe ") ||
                                      lowercased.StartsWith("walk me ");

            var isFollowUp = lowercased.Contains("tell me more") ||
                             lowercased.Contains("dig deeper") ||
                             lowercased.Contains("elaborate") ||
                             lowercased.Contains("can you expand") ||
                             lowercased.Contains("more details");

            // Interview greetings/transitions - likely interviewer
            var isInterviewerPhrase = lowercased.Contains("welcome to") ||
                                       lowercased.Contains("good evening") ||
                                       lowercased.Contains("good morning") ||
                                       lowercased.Contains("let me ask");

            // Short questions = interviewer
            if (wordCount < 25 && (hasQuestionMark || startsWithQuestion || isFollowUp || isInterviewerPhrase))
                return Speaker.Interviewer;

            // Long explanations = interviewee
            if (wordCount > 30)
                return Speaker.Interviewee;

            // Medium length with technical terms might be interviewee answering
            if (wordCount > 15)
                return Speaker.Interviewee;

            return Speaker.Unknown;
        }

        // MARK: - Follow-Up Detection

        /// <summary>
        /// Check if this is a follow-up request.
        /// </summary>
        public bool IsFollowUp(string text)
        {
            var lowercased = (text ?? "").ToLower();
            var followUpPhrases = new[]
            {
                "tell me more", "dig deeper", "elaborate", "expand on",
                "more details", "give me an example", "can you explain",
                "what else", "go deeper", "more about", "continue"
            };

            return followUpPhrases.Any(phrase => lowercased.Contains(phrase));
        }

        // MARK: - History Management

        /// <summary>
        /// Add utterance to history.
        /// </summary>
        public void AddUtterance(string text, string? topic, bool isQuestion = false)
        {
            lock (_lock)
            {
                var speaker = ClassifySpeaker(text, isQuestion);
                var utterance = new Utterance(text, speaker, topic, DateTime.UtcNow);

                _history.Add(utterance);

                var topicLower = topic?.ToLower();
                if (!string.IsNullOrEmpty(topic) &&
                    topicLower != "unknown" &&
                    topicLower != "followup" &&
                    topicLower != "answer")
                {
                    _currentTopic = topic;
                }

                if (_history.Count > _maxHistory)
                    _history.RemoveAt(0);

                System.Diagnostics.Debug.WriteLine(
                    $"📝 [{speaker}] {text.Substring(0, Math.Min(50, text.Length))}... | Topic: {topic ?? "none"}"
                );
            }
        }

        // MARK: - Context Building

        /// <summary>
        /// Get recent context for LLM (last 5 utterances).
        /// </summary>
        public string GetContextForLlm()
        {
            lock (_lock)
            {
                if (_history.Count == 0)
                    return "No previous conversation.";

                var recent = _history.Skip(Math.Max(0, _history.Count - 5)).ToList();
                var sb = new StringBuilder();

                foreach (var utterance in recent)
                {
                    var topicStr = !string.IsNullOrEmpty(utterance.Topic) ? $" [topic: {utterance.Topic}]" : "";
                    sb.AppendLine($"[{utterance.Speaker}]: {utterance.Text}{topicStr}");
                }

                return sb.ToString();
            }
        }

        /// <summary>
        /// Get full conversation history for comprehensive context.
        /// </summary>
        public string GetFullConversation()
        {
            lock (_lock)
            {
                if (_history.Count == 0)
                    return "";

                var sb = new StringBuilder();
                foreach (var utterance in _history)
                {
                    var role = utterance.Speaker == Speaker.Interviewer ? "Q" : "A";
                    sb.AppendLine($"{role}: {utterance.Text}");
                }

                return sb.ToString();
            }
        }

        /// <summary>
        /// Get conversation summary (topics discussed).
        /// </summary>
        public string GetTopicsSummary()
        {
            lock (_lock)
            {
                var topics = _history
                    .Where(u => u.Topic != null)
                    .Select(u => u.Topic!.ToLower())
                    .Where(t => t != "unknown" && t != "followup" && t != "answer")
                    .Distinct()
                    .ToList();

                return topics.Count == 0 ? "" : $"Topics discussed: {string.Join(", ", topics)}";
            }
        }

        /// <summary>
        /// Get messages older than sliding window (for summarization).
        /// </summary>
        public List<Utterance> GetMessagesForSummarization()
        {
            lock (_lock)
            {
                if (_history.Count <= _slidingWindowSize)
                    return new List<Utterance>();

                var count = _history.Count - _slidingWindowSize;
                return _history.Take(count).ToList();
            }
        }

        /// <summary>
        /// Get formatted text of old messages for summarization.
        /// </summary>
        public string GetTextForSummarization()
        {
            var oldMessages = GetMessagesForSummarization();
            var sb = new StringBuilder();

            foreach (var utterance in oldMessages)
            {
                var role = utterance.Speaker == Speaker.Interviewer ? "Interviewer" : "Candidate";
                sb.AppendLine($"{role}: {utterance.Text}");
            }

            return sb.ToString();
        }

        /// <summary>
        /// Set the conversation summary (called after LLM summarizes).
        /// </summary>
        public void SetConversationSummary(string summary)
        {
            lock (_lock)
            {
                _conversationSummary = summary;
            }
        }

        /// <summary>
        /// Clear all conversation state.
        /// </summary>
        public void Clear()
        {
            lock (_lock)
            {
                _history.Clear();
                _currentTopic = null;
                _conversationSummary = null;
            }
        }

        // MARK: - Multi-Turn Message Building

        /// <summary>
        /// Build multi-turn messages for API context from conversation history.
        /// </summary>
        public List<MultiTurnMessage> BuildMultiTurnMessages(string currentQuestion, string? pinnedSolution)
        {
            lock (_lock)
            {
                var messages = new List<MultiTurnMessage>();

                // Add conversation summary if available
                if (!string.IsNullOrEmpty(_conversationSummary))
                {
                    messages.Add(new MultiTurnMessage("user", $"Previous conversation summary: {_conversationSummary}"));
                    messages.Add(new MultiTurnMessage("assistant", "Understood. I'll use that context."));
                }

                // Add recent history (sliding window)
                var recentHistory = _history.Skip(Math.Max(0, _history.Count - _slidingWindowSize)).ToList();
                foreach (var utterance in recentHistory)
                {
                    var role = utterance.Speaker == Speaker.Interviewer ? "user" : "assistant";
                    messages.Add(new MultiTurnMessage(role, utterance.Text));
                }

                // Add pinned solution if available
                if (!string.IsNullOrEmpty(pinnedSolution))
                {
                    messages.Add(new MultiTurnMessage("user", $"Reference solution:\n{pinnedSolution}"));
                    messages.Add(new MultiTurnMessage("assistant", "I'll reference this solution in my answers."));
                }

                // Add current question
                messages.Add(new MultiTurnMessage("user", currentQuestion));

                return messages;
            }
        }

        /// <summary>
        /// Convert multi-turn messages to API format (list of dictionaries).
        /// </summary>
        public List<object> MessagesToAPIFormat(List<MultiTurnMessage> messages)
        {
            var result = new List<object>();
            foreach (var msg in messages)
            {
                result.Add(new Dictionary<string, string>
                {
                    ["role"] = msg.Role,
                    ["content"] = msg.Content
                });
            }
            return result;
        }

        public override string ToString()
        {
            return $"ConversationContext(History={_history.Count}, CurrentTopic={_currentTopic}, " +
                   $"NeedsSummarization={NeedsSummarization})";
        }
    }
}
