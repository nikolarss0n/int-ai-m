using System;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Audio source for speaker identification.
    /// Migrated from Swift: AudioSource enum
    /// </summary>
    public enum AudioSource
    {
        Microphone,     // Your voice (you speaking)
        SystemAudio     // Interviewer voice (Zoom/Teams output)
    }

    /// <summary>
    /// Represents a message in the interview timeline.
    /// Migrated from Swift: InterviewMessage.swift
    /// </summary>
    public class InterviewMessage
    {
        public enum MessageType
        {
            Question,       // Interviewer question
            Answer,         // Generated AI answer
            UserResponse,   // User's spoken response (detected as "answer")
            FollowUp,       // Follow-up answer
            Status,         // System status message
            Screenshot,     // Screenshot thumbnail in timeline
            CodingTask      // Pinned coding task solution (full width, larger)
        }

        public Guid Id { get; }
        public DateTime Timestamp { get; }
        public MessageType Type { get; }
        public string Content { get; }
        public string? Topic { get; }
        public Guid? ScreenshotId { get; set; }
        public AudioSource? AudioSource { get; set; }
        public bool IsCollapsed { get; set; }
        public int? ResponseLatencyMs { get; set; }

        public InterviewMessage(
            MessageType type,
            string content,
            string? topic = null,
            Guid? screenshotId = null,
            AudioSource? audioSource = null,
            int? responseLatencyMs = null)
        {
            Id = Guid.NewGuid();
            Timestamp = DateTime.UtcNow;
            Type = type;
            Content = content ?? throw new ArgumentNullException(nameof(content));
            Topic = topic;
            ScreenshotId = screenshotId;
            AudioSource = audioSource;
            IsCollapsed = (type == MessageType.UserResponse);  // Collapsed by default for user responses
            ResponseLatencyMs = responseLatencyMs;
        }

        // MARK: - Computed Properties

        public bool IsQuestion => Type == MessageType.Question;

        public bool IsAnswer => Type == MessageType.Answer || Type == MessageType.FollowUp;

        public string DisplayTime => Timestamp.ToString("h:mm:ss tt");

        public string? DisplayLatency
        {
            get
            {
                if (ResponseLatencyMs == null)
                    return null;

                if (ResponseLatencyMs >= 1000)
                {
                    var seconds = (double)ResponseLatencyMs / 1000.0;
                    return string.Format("{0:F1}s", seconds);
                }
                else
                {
                    return $"{ResponseLatencyMs}ms";
                }
            }
        }

        public override bool Equals(object? obj)
        {
            return obj is InterviewMessage other && Id == other.Id;
        }

        public override int GetHashCode()
        {
            return Id.GetHashCode();
        }

        public override string ToString()
        {
            var preview = Content.Length > 50 ? Content.Substring(0, 50) + "..." : Content;
            return $"InterviewMessage(Type={Type}, Topic={Topic}, Content='{preview}')";
        }
    }
}
