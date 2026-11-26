using System;
using Xunit;
using InterviewMasterApp.Application.UseCases;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Tests
{
    public class ConversationUnderstandingTests
    {
        [Theory]
        [InlineData("two databases in sync", false)]
        [InlineData("answer the question carefully", false)]
        [InlineData("I wanna check the cache", false)]
        [InlineData("it was a great project", false)]
        [InlineData("add a comment in code", false)]
        [InlineData("was ist dependency injection", true)]
        [InlineData("comment fonctionne le cache", true)]
        [InlineData("wie funktioniert docker", true)]
        [InlineData("какво е полиморфизъм", true)]
        public void ForeignQuestionMarkers_MatchWholeWordsAndLeadingOnly(string text, bool expected)
        {
            var norm = ConversationUnderstanding.Normalized(text);
            Assert.Equal(expected, ConversationUnderstanding.HasForeignQuestionMarker(norm));
        }

        [Fact]
        public void QuestioningWhWords_DistinguishesRelativeClauses()
        {
            Assert.True(ConversationUnderstanding.HasQuestioningWhWord(new[] { "which", "database", "have", "you", "used" }));
            Assert.False(ConversationUnderstanding.HasQuestioningWhWord(new[] { "a", "project", "which", "i", "built" }));
            Assert.False(ConversationUnderstanding.HasQuestioningWhWord(new[] { "a", "team", "who", "we", "hired" }));
        }

        [Theory]
        [InlineData("Give me a second", true)]
        [InlineData("Sorry, can you repeat that?", true)]
        [InlineData("Does that make sense?", true)]
        [InlineData("Give me a second, how does Redis handle eviction?", false)]
        [InlineData("What is the difference between threads and processes?", false)]
        public void CandidateMetaUtterance_RespectsInterviewerFrame(string text, bool expected)
        {
            Assert.Equal(expected, ConversationUnderstanding.IsCandidateMetaUtterance(text));
        }

        [Fact]
        public void CandidateNarrative_VetoedUnlessQuestionOrInterviewerFrame()
        {
            var narrative = ConversationUnderstanding.Normalized(
                "Well I think in my last role I worked on a distributed pipeline and we used Kafka for event streaming across services");
            Assert.True(ConversationUnderstanding.LooksLikeCandidateNarrative(narrative));

            var realQuestion = ConversationUnderstanding.Normalized(
                "In my previous team we used Kafka, how would you design a dead letter queue for retries?");
            Assert.False(ConversationUnderstanding.LooksLikeCandidateNarrative(realQuestion));
        }

        [Fact]
        public void HeldAndContinuedQuestion_WorksAsExpected()
        {
            Assert.Equal("What is RAG", ConversationUnderstanding.HeldQuestion("What is RAG, and what?"));
            Assert.Equal("How do you handle caching", ConversationUnderstanding.HeldQuestion("How do you handle caching..."));
            Assert.Null(ConversationUnderstanding.HeldQuestion("What is RAG?"));

            var combined = ConversationUnderstanding.ContinuedQuestion("What is RAG", "in production systems", 2.0, 5.0);
            Assert.Equal("What is RAG in production systems", combined);
            Assert.Null(ConversationUnderstanding.ContinuedQuestion("What is RAG", "How does SQL work?", 2.0, 5.0));
            Assert.Null(ConversationUnderstanding.ContinuedQuestion("What is RAG", "in production", 8.0, 5.0));
        }

        [Fact]
        public void LooksGarbled_CatchesScrapsButNotRealTechLists()
        {
            Assert.True(ConversationUnderstanding.LooksGarbled("Aki, di, sari, u, gontu, yus?"));
            Assert.False(ConversationUnderstanding.LooksGarbled("Python, Java, Go, Rust"));
            Assert.False(ConversationUnderstanding.LooksGarbled("What is Docker?"));
        }

        [Fact]
        public void RefersBackToConversation_DistinguishesBackRefFromConcreteQuestion()
        {
            Assert.True(ConversationUnderstanding.RefersBackToConversation("Tell me more"));
            Assert.True(ConversationUnderstanding.RefersBackToConversation("Have you used any of these?"));
            Assert.False(ConversationUnderstanding.RefersBackToConversation("How does garbage collection work in the JVM?"));
        }

        [Fact]
        public void WhisperHallucinationsAndFillers_AreFiltered()
        {
            Assert.True(ConversationUnderstanding.IsWhisperHallucination("Thank you for watching!"));
            Assert.True(ConversationUnderstanding.IsWhisperHallucination("Subtitles by"));
            Assert.False(ConversationUnderstanding.IsWhisperHallucination("Explain SOLID principles"));
            Assert.True(ConversationUnderstanding.ShouldSkipAsFillerOrGreeting("Okay, sounds good."));
            Assert.False(ConversationUnderstanding.ShouldSkipAsFillerOrGreeting("Okay, what is dependency injection?"));
            Assert.True(ConversationUnderstanding.IsLocallyIncomplete("What is the"));
            Assert.False(ConversationUnderstanding.IsLocallyIncomplete("What is the CAP theorem?"));
            Assert.True(ConversationUnderstanding.IsNonAsciiGarbageForEnglish("谢谢观看再见订阅", SpeakingLanguage.English));
            Assert.False(ConversationUnderstanding.IsNonAsciiGarbageForEnglish("谢谢观看再见订阅", SpeakingLanguage.Chinese));
        }

        [Fact]
        public void ConversationalDisplayAnswer_CleansBulletsAndPreservesCodeBlocks()
        {
            var cleaned = VoiceInterviewProcessor.ConversationalDisplayAnswer(
                "Sure, here's the answer:\n1. **Cache**: keeps hot reads fast.\n* Avoid stale data with TTL.");
            Assert.Equal("- Cache: keeps hot reads fast.\n- Avoid stale data with TTL.", cleaned);

            var withCode = "```python\ndef f(x):\n    return x * 2\n```";
            Assert.Equal(withCode, VoiceInterviewProcessor.ConversationalDisplayAnswer(withCode));
        }
    }
}
