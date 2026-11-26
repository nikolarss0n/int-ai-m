using System;
using System.Globalization;

namespace InterviewMasterApp.Domain.Model
{
    public enum AudioSource
    {
        Microphone,
        SystemAudio
    }

    /// <summary>
    /// Represents a message in the interview timeline / focus stream.
    /// </summary>
    public class InterviewMessage
    {
        public Guid Id { get; }
        public DateTime Timestamp { get; }
        public MessageType Type { get; }
        public string Content { get; set; }
        public string? Topic { get; set; }
        public Guid? TurnId { get; }
        public int? TurnSequence { get; }
        public Guid? ScreenshotId { get; set; }
        public AudioSource? AudioSource { get; set; }
        public bool IsCollapsed { get; set; }
        public int? ResponseLatencyMs { get; set; }

        public enum MessageType
        {
            Question,
            Answer,
            UserResponse,
            FollowUp,
            Status,
            Screenshot,
            CodingTask,
            Briefing
        }

        public InterviewMessage(
            MessageType type,
            string content,
            string? topic = null,
            Guid? screenshotId = null,
            AudioSource? audioSource = null,
            int? responseLatencyMs = null,
            Guid? turnId = null,
            int? turnSequence = null,
            DateTime? timestamp = null)
        {
            Id = Guid.NewGuid();
            Timestamp = timestamp ?? DateTime.Now;
            Type = type;
            Content = content ?? string.Empty;
            Topic = topic;
            TurnId = turnId;
            TurnSequence = turnSequence;
            ScreenshotId = screenshotId;
            AudioSource = audioSource;
            IsCollapsed = type == MessageType.UserResponse;
            ResponseLatencyMs = responseLatencyMs;
        }

        public bool IsQuestion => Type == MessageType.Question;
        public bool IsAnswer => Type == MessageType.Answer || Type == MessageType.FollowUp;

        public string DisplayTime => Timestamp.ToString("HH:mm:ss", CultureInfo.InvariantCulture);

        public string? DisplayLatency => ResponseLatencyMs.HasValue ? FormatLatency(ResponseLatencyMs.Value) : null;

        public static string FormatLatency(int ms)
        {
            if (ms >= 1000)
                return string.Format(CultureInfo.InvariantCulture, "{0:0.0}s", ms / 1000.0);
            return $"{ms}ms";
        }

        public override string ToString() =>
            $"InterviewMessage({Type}, Topic={Topic ?? "none"}, Content={(Content.Length > 50 ? Content[..50] + "…" : Content)})";
    }
}
