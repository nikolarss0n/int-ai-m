using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace InterviewMasterApp.Application
{
    public sealed class SessionAnalysisResult
    {
        public List<string> Topics { get; set; } = new();
        public List<string> Insights { get; set; } = new();
        public List<string> Strengths { get; set; } = new();
        public List<string> Weaknesses { get; set; } = new();
    }

    public sealed record ClassifyAndStreamResult(
        UtteranceClassification Classification,
        string FullAnswer,
        bool FormatDrift);

    public interface IAnthropicClient
    {
        Task WarmupConnectionAsync();
        void CancelCurrentRequest();

        Task StreamAnswerAsync(
            string question,
            List<object> messages,
            string userBackground,
            Action<string> onChunk,
            CancellationToken ct = default);

        Task<ClassifyAndStreamResult> ClassifyAndStreamAnswerAsync(
            string utterance,
            string recentContext,
            string userBackground,
            string? resumeText,
            string? memoryContext,
            string? pinnedSolution,
            string? lastTopic,
            Action<UtteranceClassification> onClassification,
            Action<string> onAnswerChunk,
            CancellationToken ct = default);

        Task<string> StreamCodingSolutionAsync(
            string task,
            string language,
            bool spoken,
            string? currentCode,
            string? changeRequest,
            Action<string> onChunk,
            CancellationToken ct = default);

        Task<string> SummarizeConversationAsync(string conversationText, CancellationToken ct = default);

        Task<SessionAnalysisResult> AnalyzeSessionAsync(string transcript, CancellationToken ct = default);

        Task<(string Text, double LatencyMs)> SendMessageAsync(string prompt, int maxTokens = 300, CancellationToken ct = default);
    }
}
