using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Application
{
    public interface IMemoryStore
    {
        void AddSessionSummary(SessionSummary summary);
        IReadOnlyList<SessionSummary> GetSessionSummaries();
        bool HasSessionForFile(string filename);
        UserProfile GetUserProfile();
        void UpdateUserProfile(IEnumerable<string>? strengths, IEnumerable<string>? weaknesses);
        void AddKnowledge(string topic, string content, IEnumerable<string> keywords);
        (List<SessionSummary> Sessions, List<KnowledgeEntry> Knowledge, UserProfile Profile) SearchByTopics(IReadOnlyList<string> topics);
    }

    public interface IResumeStore
    {
        string ExtractedText { get; }
        string FileName { get; }
        string SourcePath { get; }
        bool HasResume { get; }
        void SetText(string text, string fileName = "Manual CV");
        void AttachFile(string filePath);
        void Clear();
    }

    public interface IAnthropicVisionClient
    {
        Task<(bool IsSuccess, string Value, string? ErrorMessage)> SendMessageStreamAsync(
            List<string> imagesBase64,
            string prompt,
            Action<string> onChunk,
            string? model = null,
            CancellationToken ct = default);
    }

    public interface IAudioSourceCapture : IDisposable
    {
        CaptureDevice Device { get; }
        bool IsCapturing { get; }
        Action<float, bool>? OnLevelUpdate { get; set; }
        Action<byte[], AudioSource>? OnSpeechSegment { get; set; }
        Action<string>? OnStatusChange { get; set; }

        Task StartAsync(CancellationToken ct = default);
        Task StopAsync();
        void SetMuted(bool muted);
    }
}
