using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.Json;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Application.UseCases
{
    public enum ExportFormat
    {
        Markdown,
        Json
    }

    public class ExportData
    {
        public string Version { get; set; } = "1.0";
        public string ExportDate { get; set; } = string.Empty;
        public ExportSettings Settings { get; set; } = new();
        public List<ExportMessage> Messages { get; set; } = new();

        public class ExportSettings
        {
            public string Role { get; set; } = string.Empty;
            public string ProgrammingLanguage { get; set; } = string.Empty;
            public string ListeningLanguage { get; set; } = string.Empty;
            public string ResponseLanguage { get; set; } = string.Empty;
            public string SpeakingLanguage { get; set; } = string.Empty;
            public string Frameworks { get; set; } = string.Empty;
        }

        public class ExportMessage
        {
            public string Type { get; set; } = string.Empty;
            public string Content { get; set; } = string.Empty;
            public string? Topic { get; set; }
            public string Timestamp { get; set; } = string.Empty;
            public string? AudioSource { get; set; }
            public int? LatencyMs { get; set; }
        }
    }

    public class ExportInterviewUseCase
    {
        public static List<InterviewMessage> MessagesOfInterviewStartedAt(
            IEnumerable<InterviewMessage> messages,
            DateTime? startedAt)
        {
            if (messages == null) return new List<InterviewMessage>();
            return startedAt.HasValue
                ? messages.Where(m => m.Timestamp >= startedAt.Value).ToList()
                : messages.ToList();
        }

        public string Execute(List<InterviewMessage> messages, ExportFormat format, DateTime? interviewStartedAt = null)
        {
            var scoped = MessagesOfInterviewStartedAt(messages, interviewStartedAt);
            var exportable = scoped
                .Where(msg => msg.Type is InterviewMessage.MessageType.Question
                    or InterviewMessage.MessageType.Answer
                    or InterviewMessage.MessageType.FollowUp
                    or InterviewMessage.MessageType.CodingTask
                    or InterviewMessage.MessageType.Briefing)
                .OrderBy(m => m, Comparer<InterviewMessage>.Create(CompareMessages))
                .ToList();

            return format switch
            {
                ExportFormat.Markdown => FormatMarkdown(exportable),
                ExportFormat.Json => FormatJson(exportable),
                _ => throw new ArgumentException($"Unknown export format: {format}", nameof(format))
            };
        }

        private static int CompareMessages(InterviewMessage lhs, InterviewMessage rhs)
        {
            if (lhs.TurnSequence.HasValue && rhs.TurnSequence.HasValue)
            {
                if (lhs.TurnSequence.Value != rhs.TurnSequence.Value)
                    return lhs.TurnSequence.Value.CompareTo(rhs.TurnSequence.Value);
                return TypeOrder(lhs.Type).CompareTo(TypeOrder(rhs.Type));
            }
            return lhs.Timestamp.CompareTo(rhs.Timestamp);
        }

        private static int TypeOrder(InterviewMessage.MessageType type) => type switch
        {
            InterviewMessage.MessageType.Question => 0,
            InterviewMessage.MessageType.Answer or InterviewMessage.MessageType.FollowUp => 1,
            _ => 2
        };

        private static string FormatMarkdown(List<InterviewMessage> messages)
        {
            var settings = AppSettings.Shared;
            var sb = new StringBuilder();
            sb.AppendLine("# Interview Transcript\n");
            sb.AppendLine($"**Date:** {DateTime.Now.ToString("f", CultureInfo.InvariantCulture)}");
            sb.AppendLine($"**Role:** {settings.RoleDisplayName}");
            sb.AppendLine($"**Programming Language:** {settings.LanguageDisplayName}");
            sb.AppendLine($"**Listening Language:** {settings.ListeningLanguageDisplayName}");
            sb.AppendLine($"**Response Language:** {settings.ResponseLanguageDisplayName}");
            if (!string.IsNullOrWhiteSpace(settings.Frameworks))
                sb.AppendLine($"**Frameworks:** {settings.Frameworks}");

            sb.AppendLine("\n**Legend:**");
            sb.AppendLine("- **Interviewer** - Questions from the interviewer");
            sb.AppendLine("- **Suggested Answer** - AI-generated answer hints\n");
            sb.AppendLine("---\n");

            string? currentTopic = null;
            foreach (var msg in messages)
            {
                if (!string.IsNullOrWhiteSpace(msg.Topic) &&
                    !string.Equals(msg.Topic, currentTopic, StringComparison.OrdinalIgnoreCase) &&
                    !msg.Topic.Equals("unknown", StringComparison.OrdinalIgnoreCase))
                {
                    sb.AppendLine($"## {TopicTitle.Display(msg.Topic)}\n");
                    currentTopic = msg.Topic;
                }

                var time = msg.DisplayTime;
                switch (msg.Type)
                {
                    case InterviewMessage.MessageType.Question:
                        sb.AppendLine($"### Interviewer <small>({time})</small>\n");
                        sb.AppendLine($"> {msg.Content}\n");
                        break;
                    case InterviewMessage.MessageType.Answer:
                    case InterviewMessage.MessageType.FollowUp:
                        var header = msg.DisplayLatency != null
                            ? $"### Suggested Answer <small>({msg.DisplayLatency})</small>"
                            : "### Suggested Answer";
                        sb.AppendLine(header + "\n");
                        sb.AppendLine($"{msg.Content}\n");
                        break;
                    case InterviewMessage.MessageType.CodingTask:
                        sb.AppendLine("### Coding Solution\n");
                        sb.AppendLine($"{msg.Content}\n");
                        break;
                    case InterviewMessage.MessageType.Briefing:
                        sb.AppendLine("### Briefing\n");
                        sb.AppendLine($"{msg.Content}\n");
                        break;
                }
            }

            sb.AppendLine("---\n");
            sb.AppendLine("*Exported from Interview Master*");
            return sb.ToString();
        }

        private static string FormatJson(List<InterviewMessage> messages)
        {
            var settings = AppSettings.Shared;
            var data = new ExportData
            {
                Version = "1.0",
                ExportDate = DateTime.UtcNow.ToString("O"),
                Settings = new ExportData.ExportSettings
                {
                    Role = settings.RoleDisplayName,
                    ProgrammingLanguage = settings.LanguageDisplayName,
                    ListeningLanguage = settings.ListeningLanguageDisplayName,
                    ResponseLanguage = settings.ResponseLanguageDisplayName,
                    SpeakingLanguage = settings.ResponseLanguageDisplayName,
                    Frameworks = settings.Frameworks
                },
                Messages = messages.Select(msg => new ExportData.ExportMessage
                {
                    Type = GetTypeString(msg.Type),
                    Content = msg.Content,
                    Topic = msg.Topic,
                    Timestamp = msg.Timestamp.ToUniversalTime().ToString("O"),
                    AudioSource = msg.AudioSource?.ToString(),
                    LatencyMs = msg.ResponseLatencyMs
                }).ToList()
            };

            return JsonSerializer.Serialize(data, new JsonSerializerOptions
            {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            });
        }

        private static string GetTypeString(InterviewMessage.MessageType type) => type switch
        {
            InterviewMessage.MessageType.Question => "question",
            InterviewMessage.MessageType.Answer => "answer",
            InterviewMessage.MessageType.FollowUp => "followUp",
            InterviewMessage.MessageType.CodingTask => "codingTask",
            InterviewMessage.MessageType.UserResponse => "userResponse",
            InterviewMessage.MessageType.Status => "status",
            InterviewMessage.MessageType.Screenshot => "screenshot",
            InterviewMessage.MessageType.Briefing => "briefing",
            _ => "unknown"
        };
    }
}
