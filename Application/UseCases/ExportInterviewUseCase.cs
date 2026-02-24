using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Application.UseCases
{
    /// <summary>
    /// Enum for export formats.
    /// Migrated from Swift: ExportInterviewUseCase.swift
    /// </summary>
    public enum ExportFormat
    {
        Markdown,
        Json
    }

    /// <summary>
    /// Data structure for exported interview data (JSON serializable).
    /// </summary>
    public class ExportData
    {
        public string Version { get; set; }
        public string ExportDate { get; set; }
        public ExportSettings Settings { get; set; }
        public List<ExportMessage> Messages { get; set; }

        public class ExportSettings
        {
            public string Role { get; set; }
            public string ProgrammingLanguage { get; set; }
            public string SpeakingLanguage { get; set; }
            public string Frameworks { get; set; }
        }

        public class ExportMessage
        {
            public string Type { get; set; }
            public string Content { get; set; }
            public string Topic { get; set; }
            public string Timestamp { get; set; }
            public string AudioSource { get; set; }
            public int? LatencyMs { get; set; }
        }
    }

    /// <summary>
    /// Use case for exporting interview transcript to Markdown or JSON format.
    /// Migrated from Swift: ExportInterviewUseCase.swift
    /// </summary>
    public class ExportInterviewUseCase
    {
        /// <summary>
        /// Execute export operation.
        /// </summary>
        /// <param name="messages">Interview messages to export</param>
        /// <param name="format">Export format (Markdown or JSON)</param>
        /// <returns>Formatted export string</returns>
        public string Execute(List<InterviewMessage> messages, ExportFormat format)
        {
            // Filter for exportable message types
            var exportable = messages
                .Where(msg => msg.Type is InterviewMessage.MessageType.Question
                           or InterviewMessage.MessageType.Answer
                           or InterviewMessage.MessageType.FollowUp
                           or InterviewMessage.MessageType.CodingTask)
                .ToList();

            return format switch
            {
                ExportFormat.Markdown => FormatMarkdown(exportable),
                ExportFormat.Json => FormatJson(exportable),
                _ => "{}"
            };
        }

        /// <summary>
        /// Format messages as Markdown.
        /// </summary>
        private static string FormatMarkdown(List<InterviewMessage> messages)
        {
            var settings = AppSettings.Shared; // or AppSettings.Shared equivalent
            var sb = new StringBuilder();

            sb.AppendLine("# Interview Transcript\n");
            sb.AppendLine($"**Date:** {DateTime.Now:G}");
            sb.AppendLine($"**Role:** {settings.RoleDisplayName}");
            sb.AppendLine($"**Language:** {settings.LanguageDisplayName}");
            sb.AppendLine($"**Response Language:** {settings.ResponseLanguageDisplayName}");

            if (!string.IsNullOrEmpty(settings.Frameworks))
            {
                sb.AppendLine($"**Frameworks:** {settings.Frameworks}");
            }

            sb.AppendLine("\n**Legend:**");
            sb.AppendLine("- 🎙️ **Interviewer** - Questions from the interviewer");
            sb.AppendLine("- 💡 **Suggested Answer** - AI-generated answer hints\n");
            sb.AppendLine("---\n");

            string currentTopic = null;

            foreach (var msg in messages)
            {
                // Add topic header if changed
                if (!string.IsNullOrEmpty(msg.Topic) && msg.Topic != currentTopic && msg.Topic != "unknown")
                {
                    sb.AppendLine($"## {CapitalizeFirstLetter(msg.Topic)}\n");
                    currentTopic = msg.Topic;
                }

                var time = msg.DisplayTime;

                switch (msg.Type)
                {
                    case InterviewMessage.MessageType.Question:
                        sb.AppendLine($"### 🎙️ Interviewer <small>({time})</small>\n");
                        sb.AppendLine($"> {msg.Content}\n");
                        break;

                    case InterviewMessage.MessageType.Answer:
                    case InterviewMessage.MessageType.FollowUp:
                        var header = "### 💡 Suggested Answer";
                        if (msg.DisplayLatency != null)
                        {
                            header += $" <small>({msg.DisplayLatency})</small>";
                        }
                        sb.AppendLine(header + "\n");
                        sb.AppendLine($"{msg.Content}\n");
                        break;

                    case InterviewMessage.MessageType.CodingTask:
                        sb.AppendLine("### 💻 Coding Solution\n");
                        sb.AppendLine($"{msg.Content}\n");
                        break;
                }
            }

            sb.AppendLine("---\n");
            sb.AppendLine("*Exported from Interview Master*");

            return sb.ToString();
        }

        /// <summary>
        /// Format messages as JSON.
        /// </summary>
        private static string FormatJson(List<InterviewMessage> messages)
        {
            var settings = AppSettings.Shared;
            var exportMessages = messages.Select(msg => new ExportData.ExportMessage
            {
                Type = GetTypeString(msg.Type),
                Content = msg.Content,
                Topic = msg.Topic,
                Timestamp = msg.Timestamp.ToUniversalTime().ToString("O"),
                AudioSource = msg.AudioSource?.ToString(),
                LatencyMs = msg.ResponseLatencyMs
            }).ToList();

            var data = new ExportData
            {
                Version = "1.0",
                ExportDate = DateTime.UtcNow.ToString("O"),
                Settings = new ExportData.ExportSettings
                {
                    Role = settings.RoleDisplayName,
                    ProgrammingLanguage = settings.LanguageDisplayName,
                    SpeakingLanguage = settings.ResponseLanguageDisplayName,
                    Frameworks = settings.Frameworks
                },
                Messages = exportMessages
            };

            var options = new JsonSerializerOptions
            {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };

            return JsonSerializer.Serialize(data, options);
        }

        /// <summary>
        /// Get string representation of message type.
        /// </summary>
        private static string GetTypeString(InterviewMessage.MessageType type)
        {
            return type switch
            {
                InterviewMessage.MessageType.Question => "question",
                InterviewMessage.MessageType.Answer => "answer",
                InterviewMessage.MessageType.FollowUp => "followUp",
                InterviewMessage.MessageType.CodingTask => "codingTask",
                InterviewMessage.MessageType.UserResponse => "userResponse",
                InterviewMessage.MessageType.Status => "status",
                InterviewMessage.MessageType.Screenshot => "screenshot",
                _ => "unknown"
            };
        }

        /// <summary>
        /// Capitalize first letter of string.
        /// </summary>
        private static string CapitalizeFirstLetter(string text)
        {
            if (string.IsNullOrEmpty(text))
                return text;

            return char.ToUpper(text[0]) + text.Substring(1);
        }
    }
}

