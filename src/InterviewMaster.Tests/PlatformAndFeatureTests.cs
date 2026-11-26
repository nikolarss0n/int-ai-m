using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Xunit;
using InterviewMasterApp.Application;
using InterviewMasterApp.Application.UseCases;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Domain.Practice;
using InterviewMasterApp.Domain.Speech;
using InterviewMasterApp.Infrastructure.Practice;
using InterviewMasterApp.Infrastructure.Storage;

namespace InterviewMasterApp.Tests
{
    public class PlatformAndFeatureTests
    {
        [Fact]
        public void NoticeBoard_PrioritizesErrorsAndExpiresConfirmations()
        {
            var board = new NoticeBoard();
            var t0 = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);

            Assert.True(board.Show(FeedbackNotice.Error("pipeline", "Net down"), t0));
            // Confirmation must not overwrite higher-rank error
            Assert.False(board.Show(FeedbackNotice.Confirmation("copy", "Copied"), t0.AddSeconds(1)));
            Assert.Equal("pipeline", board.Current?.Key);

            board.Resolve("pipeline");
            Assert.Null(board.Current);

            Assert.True(board.Show(FeedbackNotice.Confirmation("copy", "Copied"), t0));
            board.Expire(t0.AddSeconds(FeedbackNotice.ConfirmationHold + 0.1));
            Assert.Null(board.Current);
        }

        [Fact]
        public void WaitProgressAndDelayedActivity_BehaveDeterministically()
        {
            Assert.Equal("Generating", WaitProgress.AnswerStatus(false, 2));
            Assert.Equal("Generating · 6s", WaitProgress.AnswerStatus(false, 6));
            Assert.Equal("Still generating · 12s", WaitProgress.AnswerStatus(false, 12));
            Assert.Equal("Queued", WaitProgress.AnswerStatus(true, 15));
            Assert.Equal("1m 05s", WaitProgress.Format(65));

            var act = new DelayedActivity(0.2, 20.0);
            var id = Guid.NewGuid();
            var t0 = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            act.Begin(id, t0);
            Assert.False(act.IsShowing(t0.AddSeconds(0.1)));
            Assert.True(act.IsShowing(t0.AddSeconds(0.5)));
            Assert.False(act.IsShowing(t0.AddSeconds(21.0)));
        }

        [Fact]
        public void TopicTitle_FormatsCamelCaseAndAcronyms()
        {
            Assert.Equal("System design", TopicTitle.Display("systemDesign"));
            Assert.Equal("RAG and CAG", TopicTitle.Display("ragCag"));
            Assert.Equal("LLM evaluation", TopicTitle.Display("llmEvaluation"));
            Assert.Equal("C#", TopicTitle.Display("csharp"));
            Assert.Equal(TopicTitle.Unknown, TopicTitle.Display("unknown"));
        }

        [Fact]
        public void InterviewBriefing_ExtractsMatchingResumePointsAndRoleEra()
        {
            var cv = "Software Engineer - Honeywell Aerospace (2016 - 2018)\nBuilt hybrid search RAG chunking and reranking pipelines.";
            var briefing = InterviewBriefingHelper.NextBriefing("Tell me about chunking and reranking in RAG", true, cv, null);
            Assert.NotNull(briefing);
            Assert.Equal("rag", briefing!.Thread);
            Assert.NotEmpty(briefing.TalkingPoints);

            var grounding = InterviewBriefingHelper.ResumeGroundingInstruction(cv, "What did you build at Honeywell?", "personal");
            Assert.Contains("2016-2018", grounding);
            Assert.Contains("2018", grounding);
        }

        [Fact]
        public void SpeechTurnDetector_EmitsSpeculativePreviewAndFinalWav()
        {
            var now = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);
            var emits = new List<(SpeechTurnEmit Kind, int Bytes)>();
            var detector = new SpeechTurnDetector(
                SpeechTurnDetector.Labels.SystemAudio,
                SpeechTurnDetector.Tuning.SystemAudio,
                (emit, data) => emits.Add((emit, data?.Length ?? 0)),
                (_, _) => { },
                _ => { },
                () => now);

            var loud = Enumerable.Repeat(0.4f, 512).ToArray();
            var quiet = new float[512];

            // Speech burst lasting 0.8s
            for (int i = 0; i < 8; i++)
            {
                detector.Ingest(loud);
                now = now.AddMilliseconds(100);
            }
            // Silence crossing speculative (0.25s) and final (0.65s)
            now = now.AddMilliseconds(300);
            detector.Ingest(quiet);
            now = now.AddMilliseconds(450);
            detector.Ingest(quiet);

            Assert.Contains(emits, e => e.Kind == SpeechTurnEmit.SpeculativePreview && e.Bytes > 44);
            Assert.Contains(emits, e => e.Kind == SpeechTurnEmit.FinalSilence && e.Bytes > 44);
        }

        [Fact]
        public void PracticeLogicAndStore_ScoreAndPreserveCorruptFiles()
        {
            var penalty = PracticeLogic.ApplyHelpPenalty(1.0, usedHelp: true);
            Assert.Equal(0.4, penalty.FinalScore, 3);
            Assert.Equal(PracticeHelpMark.Yellow, penalty.Mark);

            // Load real copied practice decks from repo Resources/practice
            var repoPracticeDir = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "Resources", "practice"));
            if (Directory.Exists(repoPracticeDir))
            {
                var bank = PracticeBankLoader.LoadDirectory(repoPracticeDir);
                Assert.True(bank.Packs.Count >= 4);
                var cardQuestions = bank.Packs.SelectMany(p => p.Questions).Where(q => q.Card != null).ToList();
                Assert.NotEmpty(cardQuestions);
                Assert.All(cardQuestions, q => Assert.True(q.Card!.IsValid));
            }

            // Corrupt in-progress file must be moved to recovery copy
            var tmpDir = Path.Combine(Path.GetTempPath(), "im_practice_test_" + Guid.NewGuid());
            Directory.CreateDirectory(tmpDir);
            try
            {
                File.WriteAllText(Path.Combine(tmpDir, "in-progress.json"), "{ invalid json");
                var store = new PracticeStore(tmpDir);
                Assert.Null(store.InProgressSession());
                Assert.Contains(Directory.GetFiles(tmpDir), f => Path.GetFileName(f).StartsWith("in-progress-recovery-"));
            }
            finally { Directory.Delete(tmpDir, true); }
        }

        [Fact]
        public void ExportInterviewUseCase_ScopesToLatestInterviewStart()
        {
            var t1 = new DateTime(2026, 1, 1, 10, 0, 0);
            var t2 = new DateTime(2026, 1, 1, 11, 0, 0);
            var msgs = new List<InterviewMessage>
            {
                new(InterviewMessage.MessageType.Question, "Old question?", "sql", timestamp: t1),
                new(InterviewMessage.MessageType.Question, "New question?", "rag", timestamp: t2.AddSeconds(1))
            };

            var md = new ExportInterviewUseCase().Execute(msgs, ExportFormat.Markdown, interviewStartedAt: t2);
            Assert.DoesNotContain("Old question?", md);
            Assert.Contains("New question?", md);
        }

        private sealed class InMemoryVault : ICredentialVault
        {
            public Dictionary<string, string> Store { get; } = new();
            public bool Save(string target, string secret) { Store[target] = secret; return true; }
            public string? Retrieve(string target) => Store.TryGetValue(target, out var v) ? v : null;
            public bool Delete(string target) => Store.Remove(target);
        }

        [Fact]
        public void ApiKeyManager_UsesVaultPrimaryAndFallbackFileAndEnvPriority()
        {
            var tmpFile = Path.Combine(Path.GetTempPath(), "im_keys_" + Guid.NewGuid());
            File.WriteAllText(tmpFile, "GROQ_API_KEY=from-file\nANTHROPIC_API_KEY=anth-file\n");
            try
            {
                var vault = new InMemoryVault();
                vault.Save(ApiKeyManager.TargetName("ANTHROPIC_API_KEY"), "anth-vault");

                var mgr = new ApiKeyManager(vault, tmpFile, key => key == "OPENAI_API_KEY" ? "oa-env" : null);
                Assert.Equal("from-file", mgr.GetKey(ApiKeyType.Groq));
                Assert.Equal("anth-vault", mgr.GetKey(ApiKeyType.Anthropic));
                Assert.Equal("oa-env", mgr.GetKey(ApiKeyType.OpenAi));

                mgr.SetKey("new-groq-vault", ApiKeyType.Groq);
                Assert.Equal("new-groq-vault", vault.Retrieve(ApiKeyManager.TargetName("GROQ_API_KEY")));
                // Plaintext fallback file was NOT overwritten
                Assert.Contains("GROQ_API_KEY=from-file", File.ReadAllText(tmpFile));
            }
            finally { if (File.Exists(tmpFile)) File.Delete(tmpFile); }
        }

        private sealed class FakeCapture : IAudioSourceCapture
        {
            public CaptureDevice Device { get; }
            public bool IsCapturing { get; private set; }
            public bool IsMuted { get; private set; }
            public Action<float, bool>? OnLevelUpdate { get; set; }
            public Action<byte[], AudioSource>? OnSpeechSegment { get; set; }
            public Action<string>? OnStatusChange { get; set; }
            public FakeCapture(CaptureDevice dev) => Device = dev;
            public Task StartAsync(CancellationToken ct = default) { IsCapturing = true; return Task.CompletedTask; }
            public Task StopAsync() { IsCapturing = false; return Task.CompletedTask; }
            public void SetMuted(bool muted) => IsMuted = muted;
            public void Dispose() { IsCapturing = false; }
        }

        [Fact]
        public async Task AudioCaptureCoordinator_SwitchesDevicesAndMutesCleanly()
        {
            using var coord = new AudioCaptureCoordinator(d => new FakeCapture(d), CaptureDevice.SystemAudio);
            await coord.StartAsync();
            Assert.Equal(CaptureDevice.SystemAudio, coord.ActiveDevice);
            Assert.Equal(CapturePresentationKind.Listening, coord.CurrentPresentation.Kind);

            coord.ToggleMute();
            Assert.True(coord.IsMuted);
            Assert.Equal(CapturePresentationKind.Muted, coord.CurrentPresentation.Kind);

            await coord.SwitchDeviceAsync(CaptureDevice.Microphone);
            Assert.Equal(CaptureDevice.Microphone, coord.ActiveDevice);

            await coord.StopAsync();
            Assert.Null(coord.ActiveDevice);
            Assert.Equal(CapturePresentationKind.Idle, coord.CurrentPresentation.Kind);
        }
    }
}
