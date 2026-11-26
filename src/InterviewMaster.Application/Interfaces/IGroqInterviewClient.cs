using System;
using System.Threading;
using System.Threading.Tasks;

namespace InterviewMasterApp.Application
{
    public interface IGroqInterviewClient
    {
        Task WarmupConnectionAsync();
        void CancelCurrentRequest();

        Task<(string Text, double LatencyMs)> TranscribeAsync(
            byte[] audioData,
            string filename = "audio.wav",
            CancellationToken ct = default);

        Task<(UtteranceClassification Classification, double LatencyMs)> ClassifyUtteranceAsync(
            string text,
            string buffer,
            string? lastTopic,
            CancellationToken ct = default);

        Task<(string Answer, double LatencyMs)> GenerateAnswerAsync(
            string topic,
            string transcription,
            string? userBackground = null,
            CancellationToken ct = default);
    }

    public class UtteranceClassification
    {
        public string Status { get; set; } = "question";
        public string Topic { get; set; } = "unknown";
    }
}
