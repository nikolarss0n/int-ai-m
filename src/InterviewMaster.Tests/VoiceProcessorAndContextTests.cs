using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Xunit;
using InterviewMasterApp.Application;
using InterviewMasterApp.Application.UseCases;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Tests
{
    public class VoiceProcessorAndContextTests
    {
        private sealed class FakeDelegate : IVoiceInterviewProcessorDelegate
        {
            public string UserBackground { get; set; } = string.Empty;
            public string ResumeText { get; set; } = "Senior AI Engineer - Acme Corp (2022 - present)\nBuilt RAG pipelines with hybrid search and reranking.";
            public string? PinnedSolution { get; set; }
            public ConversationContext ConversationContext { get; } = new();
        }

        private sealed class FakeLlmClient : IAnthropicClient
        {
            public Func<string, ClassifyAndStreamResult>? OnClassify { get; set; }
            public string FallbackStreamText { get; set; } = "- Recovered answer bullet.";
            public string CodingResponse { get; set; } =
                "SAY:\n- I'll use slicing.\n\nSTEP 1 — file: main.py\nWhy: Reverse string.\n```python\ndef rev(s): return s[::-1]\n```";

            public Task WarmupConnectionAsync() => Task.CompletedTask;
            public void CancelCurrentRequest() { }

            public Task StreamAnswerAsync(string question, List<object> messages, string userBackground, Action<string> onChunk, CancellationToken ct = default)
            {
                onChunk(FallbackStreamText);
                return Task.CompletedTask;
            }

            public Task<ClassifyAndStreamResult> ClassifyAndStreamAnswerAsync(
                string utterance, string recentContext, string userBackground, string? resumeText,
                string? memoryContext, string? pinnedSolution, string? lastTopic,
                Action<UtteranceClassification> onClassification, Action<string> onAnswerChunk, CancellationToken ct = default)
            {
                var res = OnClassify != null
                    ? OnClassify(utterance)
                    : new ClassifyAndStreamResult(new UtteranceClassification { Status = "question", Topic = "rag" }, "- Retrieve relevant chunks first.", false);
                onClassification(res.Classification);
                if (!string.IsNullOrEmpty(res.FullAnswer)) onAnswerChunk(res.FullAnswer);
                return Task.FromResult(res);
            }

            public Task<string> StreamCodingSolutionAsync(string task, string language, bool spoken, string? currentCode, string? changeRequest, Action<string> onChunk, CancellationToken ct = default)
            {
                onChunk(CodingResponse);
                return Task.FromResult(CodingResponse);
            }

            public Task<string> SummarizeConversationAsync(string conversationText, CancellationToken ct = default) => Task.FromResult("Summary");
            public Task<SessionAnalysisResult> AnalyzeSessionAsync(string transcript, CancellationToken ct = default) => Task.FromResult(new SessionAnalysisResult());
            public Task<(string Text, double LatencyMs)> SendMessageAsync(string prompt, int maxTokens = 300, CancellationToken ct = default) => Task.FromResult(("ok", 10.0));
        }

        [Fact]
        public async Task GarbledSpeech_SetsStatusAndNeverOpensCard()
        {
            var del = new FakeDelegate();
            var llm = new FakeLlmClient();
            using var proc = new VoiceInterviewProcessor();
            proc.Configure(null, llm, del);

            string? status = null;
            bool opened = false;
            proc.StatusUpdated += (_, s) => status = s;
            proc.QuestionReceived += (_, _) => opened = true;

            await proc.ProcessInterviewerTranscriptAsync("Aki, di, sari, u, gontu, yus?", AudioSource.SystemAudio, DateTime.UtcNow, Guid.NewGuid(), 0);

            Assert.False(opened);
            Assert.Equal(FeedbackCopy.DidntCatchThat, status);
        }

        [Fact]
        public async Task EmptyClassifierAnswer_RecoversWithDirectStream()
        {
            var del = new FakeDelegate();
            var llm = new FakeLlmClient
            {
                OnClassify = _ => new ClassifyAndStreamResult(new UtteranceClassification { Status = "question", Topic = "oop" }, "", false),
                FallbackStreamText = "- Direct recovery works."
            };
            using var proc = new VoiceInterviewProcessor();
            proc.Configure(null, llm, del);

            string? finished = null;
            proc.AnswerFinished += (_, e) => finished = e.FullAnswer;

            await proc.ProcessInterviewerTranscriptAsync("What is polymorphism?", AudioSource.SystemAudio, DateTime.UtcNow, Guid.NewGuid(), 0);

            Assert.Equal("- Direct recovery works.", finished);
        }

        [Fact]
        public async Task SpokenCodingRequest_StreamsCodePanelAndTalkingPoints()
        {
            var del = new FakeDelegate();
            var llm = new FakeLlmClient();
            using var proc = new VoiceInterviewProcessor();
            proc.Configure(null, llm, del);

            CodingTaskInfo? started = null;
            CodingTaskOutcome? outcome = null;
            string? cardAnswer = null;
            proc.CodingTaskStarted += (_, info) => started = info;
            proc.CodingTaskFinished += (_, o) => outcome = o;
            proc.AnswerFinished += (_, e) => cardAnswer = e.FullAnswer;

            await proc.ProcessInterviewerTranscriptAsync("Write a function to reverse a string in Python", AudioSource.SystemAudio, DateTime.UtcNow, Guid.NewGuid(), 0);

            Assert.NotNull(started);
            Assert.NotNull(outcome);
            Assert.True(outcome!.IsComplete);
            Assert.Contains("slicing", cardAnswer);
        }

        [Fact]
        public void ConversationContext_TracksLastQuestionAndSummarizationThreshold()
        {
            var ctx = new ConversationContext();
            for (int i = 1; i <= 11; i++)
                ctx.AddUtterance($"Question {i}?", "rag", isQuestion: true, sequence: i);

            Assert.Equal("Question 11?", ctx.LastInterviewerQuestion);
            Assert.True(ctx.NeedsSummarization);
            ctx.SetSummary("Covered RAG basics.");
            Assert.False(ctx.NeedsSummarization);
            Assert.Equal(AppConstants.Thresholds.SlidingWindowSize, ctx.History.Count);
        }
    }
}
