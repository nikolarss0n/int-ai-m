using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Application.UseCases
{
    public sealed class SessionAnalysisUseCase
    {
        private readonly IMemoryStore _memoryStore;

        public SessionAnalysisUseCase(IMemoryStore memoryStore)
        {
            _memoryStore = memoryStore ?? throw new ArgumentNullException(nameof(memoryStore));
        }

        public async Task AnalyzeAsync(
            IReadOnlyList<InterviewMessage> messages,
            string sourceFile,
            IAnthropicClient llmClient,
            CancellationToken ct = default)
        {
            if (messages == null || llmClient == null) return;

            var exportable = messages.Where(m => m.Type is InterviewMessage.MessageType.Question
                or InterviewMessage.MessageType.Answer
                or InterviewMessage.MessageType.FollowUp
                or InterviewMessage.MessageType.CodingTask).ToList();

            if (exportable.Count < 2) return;

            var transcript = string.Join("\n", exportable.Select(msg =>
            {
                var role = msg.Type switch
                {
                    InterviewMessage.MessageType.Question => "Interviewer",
                    InterviewMessage.MessageType.Answer or InterviewMessage.MessageType.FollowUp => "Answer",
                    InterviewMessage.MessageType.CodingTask => "Code Solution",
                    _ => "Other"
                };
                var topicStr = !string.IsNullOrWhiteSpace(msg.Topic) ? $" [{msg.Topic}]" : string.Empty;
                return $"{role}{topicStr}: {msg.Content}";
            }));

            var result = await llmClient.AnalyzeSessionAsync(transcript, ct).ConfigureAwait(false);
            var summary = new SessionSummary
            {
                Id = Guid.NewGuid().ToString(),
                Date = DateTime.UtcNow,
                Topics = result.Topics,
                QuestionsAsked = exportable.Count(m => m.Type == InterviewMessage.MessageType.Question),
                KeyInsights = result.Insights,
                SourceFile = sourceFile
            };

            _memoryStore.AddSessionSummary(summary);
            _memoryStore.UpdateUserProfile(result.Strengths, result.Weaknesses);
        }
    }
}
