using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using Xunit;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Tests
{
    /// <summary>
    /// Test suite for pure functions from Application/VoiceInterviewProcessor and Domain/Model/ConversationContext.
    /// Ported from Swift: Tests/test_processor.swift
    /// Tests string similarity, hallucination detection, question classification, and conversation context logic.
    /// </summary>
    public class ProcessorTests
    {
        // ============================================================
        // SOURCE: Application/VoiceInterviewProcessor.swift:70
        // ============================================================
        private double StringSimilarity(string a, string b)
        {
            var wordsA = new HashSet<string>(a.ToLowerInvariant().Split(' ').Where(w => !string.IsNullOrWhiteSpace(w)));
            var wordsB = new HashSet<string>(b.ToLowerInvariant().Split(' ').Where(w => !string.IsNullOrWhiteSpace(w)));

            if (wordsA.Count == 0 && wordsB.Count == 0) return 0;

            var intersection = wordsA.Intersect(wordsB).Count();
            var union = wordsA.Union(wordsB).Count();

            return union > 0 ? (double)intersection / union : 0;
        }

        // SOURCE: Application/VoiceInterviewProcessor.swift:462
        private bool IsWhisperHallucination(string trimmed)
        {
            var whisperHallucinations = new[]
            {
                "thank you", "thank you for watching", "thank you for listening",
                "thanks", "thanks for watching", "thanks for listening",
                "please subscribe", "like and subscribe", "see you next time",
                "bye", "goodbye", "bye bye", "bye-bye", "take care",
                "see you", "see you later", "see you soon",
                "you", "the end", "so", "okay", "ok", "right",
                "hmm", "hm", "um", "uh", "ah", "oh", "mhm", "uh-huh",
                "music", "applause", "laughter", "silence", "crickets",
                "[music]", "[applause]", "[laughter]", "[silence]",
                "(music)", "(applause)", "(laughter)", "(silence)",
                "subtitles by", "captions by", "translated by",
                "danke", "danke fürs zuschauen", "abonnieren", "abonniert", "tschüss", "auf wiedersehen", "bis bald",
                "gracias", "gracias por ver", "suscríbete", "suscribirse", "adiós", "hasta luego", "hasta pronto",
                "merci", "merci d'avoir regardé", "abonnez-vous", "s'abonner", "au revoir", "à bientôt", "salut",
                "grazie", "grazie per la visione", "iscriviti", "iscrivetevi", "ciao", "arrivederci", "a presto",
                "obrigado", "obrigada", "inscreva-se", "se inscreva", "tchau", "adeus", "até logo", "até mais",
                "благодаря", "благодаря ви", "абонирайте се", "абонирай се", "харесайте", "довиждане", "чао",
                "спасибо", "спасибо за просмотр", "подписывайтесь", "подпишитесь", "пока", "до свидания", "до скорого",
                "谢谢", "谢谢观看", "订阅", "请订阅", "再见", "拜拜",
                "xièxiè", "dìngyuè", "zàijiàn",
                "ありがとう", "ありがとうございます", "チャンネル登録", "登録", "さようなら", "バイバイ", "じゃね",
                "감사합니다", "구독", "구독해주세요", "좋아요", "안녕", "안녕하세요", "다음에 봐요"
            };

            var lowerTrimmed = trimmed.ToLowerInvariant()
                .Replace("!", "")
                .Replace(".", "")
                .Replace(",", "")
                .Trim();

            return trimmed.Length < 30 && whisperHallucinations.Any(h => lowerTrimmed == h);
        }

        // SOURCE: Application/VoiceInterviewProcessor.swift:512
        private bool ShouldSkipAsFillerOrGreeting(string trimmed)
        {
            var normalizedText = Regex.Replace(
                trimmed.ToLowerInvariant().Trim(),
                @"[.!?,']",
                ""
            );

            var greetingStarts = new[] { "hello", "hi ", "hey ", "good morning", "good afternoon", "good evening", "welcome to" };
            var isGreeting = greetingStarts.Any(g => normalizedText.StartsWith(g));

            var fillerPatterns = new[] { "thank you", "thanks", "yes sure", "yeah sure", "okay", "sure", "sounds good", "got it", "i see", "i understand", "alright" };
            var isFiller = fillerPatterns.Any(f => normalizedText.StartsWith(f) || normalizedText == f);

            var questionWords = new[] { "what", "how", "why", "when", "where", "which", "who", "can you", "could you", "would you", "tell me", "explain", "describe", "give me", "show me", "walk me" };
            var hasQuestionWord = questionWords.Any(q => normalizedText.Contains(q));

            if ((isGreeting || isFiller) && normalizedText.Length < 50 && !hasQuestionWord)
            {
                return true;
            }

            return false;
        }

        // SOURCE: Application/VoiceInterviewProcessor.swift:535
        private bool IsLocallyIncomplete(string trimmed)
        {
            var textForCheck = trimmed.ToLowerInvariant().Trim();
            var incompleteEndings = new[] { " so", " and", " but", " the", " a", " an", " to", " of", " that", " if", " when", " is", " are", " have", " can", " will", " for", " with", " on", " in", "," };
            var endsIncomplete = incompleteEndings.Any(e => textForCheck.EndsWith(e));
            var hasQuestionMark = textForCheck.Contains("?");

            return endsIncomplete && !hasQuestionMark;
        }

        // SOURCE: Application/VoiceInterviewProcessor.swift:106
        private bool CheckForQuestionMarkers(string text)
        {
            var lowerText = text.ToLowerInvariant();
            var markers = new[]
            {
                "?",
                "what is", "what are", "what's", "whats", "what did", "what do",
                "how do", "how does", "how is", "how would", "how can", "how to",
                "why do", "why does", "why is", "why would",
                "can you explain", "could you explain", "can you tell", "could you tell",
                "tell me about", "tell me more",
                "explain ", "describe ",
                "what about", "how about",
                "difference between", "differences between",
                "when do", "when does", "when would", "when should",
                "where do", "where does", "where is",
                "which ", "who ", "whose ",
                "какво", "як", "защо", "кога", "къде", "кой", "коя", "кое", "кои",
                "разкажи", "обясни", "опиши",
                "was ", "wie ", "warum", "wann", "wo ", "wer ", "welche",
                "qu'est", "comment", "pourquoi", "quand", "où ", "qui ",
                "qué ", "cómo", "por qué", "cuándo", "dónde", "quién"
            };
            return markers.Any(m => lowerText.Contains(m));
        }

        // ============================================================
        // SOURCE: Domain/Model/ConversationContext.swift
        // ============================================================

        private enum Speaker
        {
            Interviewer,
            Interviewee,
            Unknown
        }

        private class MultiTurnMessage
        {
            public string Role { get; set; }
            public string Content { get; set; }

            public MultiTurnMessage(string role, string content)
            {
                Role = role;
                Content = content;
            }
        }

        // SOURCE: Domain/Model/ConversationContext.swift:34
        private Speaker ClassifySpeaker(string text, bool isQuestion = false)
        {
            var trimmed = text.Trim();
            var words = trimmed.Split(' ');
            var wordCount = words.Length;
            var lowercased = trimmed.ToLowerInvariant();

            if (isQuestion)
            {
                return Speaker.Interviewer;
            }

            var hasQuestionMark = trimmed.Contains("?");
            var startsWithQuestion = lowercased.StartsWith("what") ||
                                      lowercased.StartsWith("how") ||
                                      lowercased.StartsWith("why") ||
                                      lowercased.StartsWith("can you") ||
                                      lowercased.StartsWith("could you") ||
                                      lowercased.StartsWith("tell me") ||
                                      lowercased.StartsWith("explain") ||
                                      lowercased.StartsWith("describe") ||
                                      lowercased.StartsWith("walk me") ||
                                      lowercased.StartsWith("so ") ||
                                      lowercased.StartsWith("let's assume");

            var isFollowUp = lowercased.Contains("tell me more") ||
                             lowercased.Contains("dig deeper") ||
                             lowercased.Contains("elaborate") ||
                             lowercased.Contains("can you expand") ||
                             lowercased.Contains("more details") ||
                             lowercased.Contains("give me an example");

            var isInterviewerPhrase = lowercased.Contains("welcome to") ||
                                       lowercased.Contains("good evening") ||
                                       lowercased.Contains("good morning") ||
                                       lowercased.Contains("shall proceed") ||
                                       lowercased.Contains("gone through your resume") ||
                                       lowercased.Contains("let me ask");

            if (wordCount < 25 && (hasQuestionMark || startsWithQuestion || isFollowUp || isInterviewerPhrase))
            {
                return Speaker.Interviewer;
            }

            if (wordCount > 30)
            {
                return Speaker.Interviewee;
            }

            if (wordCount > 15)
            {
                return Speaker.Interviewee;
            }

            return Speaker.Unknown;
        }

        // SOURCE: Domain/Model/ConversationContext.swift:93
        private bool IsFollowUp(string text)
        {
            var lowercased = text.ToLowerInvariant();
            var followUpPhrases = new[]
            {
                "tell me more", "dig deeper", "elaborate", "expand on",
                "more details", "give me an example", "can you explain",
                "what else", "go deeper", "more about", "continue"
            };
            return followUpPhrases.Any(p => lowercased.Contains(p));
        }

        // SOURCE: Domain/Model/ConversationContext.swift:230
        private List<Dictionary<string, string>> MessagesToAPIFormat(List<MultiTurnMessage> messages)
        {
            var result = new List<Dictionary<string, string>>();
            string? lastRole = null;

            foreach (var msg in messages)
            {
                if (msg.Role == lastRole && result.Count > 0)
                {
                    var lastMsg = result[result.Count - 1];
                    lastMsg["content"] = lastMsg["content"] + "\n\n" + msg.Content;
                }
                else
                {
                    result.Add(new Dictionary<string, string>
                    {
                        { "role", msg.Role },
                        { "content", msg.Content }
                    });
                    lastRole = msg.Role;
                }
            }

            if (result.Count == 0 || result[0]["role"] != "user")
            {
                result.Insert(0, new Dictionary<string, string>
                {
                    { "role", "user" },
                    { "content", "(Interview in progress)" }
                });
            }

            return result;
        }

        // ============================================================
        // TESTS
        // ============================================================

        [Fact]
        public void StringSimilarity_IdenticalStrings_ReturnsOne()
        {
            Assert.Equal(1.0, StringSimilarity("hello world", "hello world"));
        }

        [Fact]
        public void StringSimilarity_EmptyStrings_ReturnsZero()
        {
            Assert.Equal(0.0, StringSimilarity("", ""));
        }

        [Fact]
        public void StringSimilarity_PartialOverlap_ReturnsBetweenZeroAndOne()
        {
            var result = StringSimilarity("hello world", "hello there");
            Assert.True(result > 0.0);
            Assert.True(result < 1.0);
        }

        [Fact]
        public void StringSimilarity_NoOverlap_ReturnsZero()
        {
            Assert.Equal(0.0, StringSimilarity("abc def", "xyz qrs"));
        }

        [Fact]
        public void StringSimilarity_CaseInsensitive()
        {
            Assert.Equal(1.0, StringSimilarity("Hello World", "hello world"));
        }

        [Fact]
        public void StringSimilarity_SimilarQuestions_HighSimilarity()
        {
            var sim = StringSimilarity("what is a binary tree", "what is a binary search tree");
            Assert.True(sim > 0.5, $"Expected similarity > 0.5, got {sim}");
        }

        [Fact]
        public void IsWhisperHallucination_YouTubeOutro_ReturnsTrue()
        {
            Assert.True(IsWhisperHallucination("Thank you!"));
            Assert.True(IsWhisperHallucination("thank you for watching"));
        }

        [Fact]
        public void IsWhisperHallucination_MusicArtifact_ReturnsTrue()
        {
            Assert.True(IsWhisperHallucination("[music]"));
        }

        [Fact]
        public void IsWhisperHallucination_FillerSound_ReturnsTrue()
        {
            Assert.True(IsWhisperHallucination("um"));
        }

        [Fact]
        public void IsWhisperHallucination_RealQuestion_ReturnsFalse()
        {
            Assert.False(IsWhisperHallucination("What is a hash map?"));
        }

        [Fact]
        public void IsWhisperHallucination_LongAnswer_ReturnsFalse()
        {
            Assert.False(IsWhisperHallucination("I have 5 years of experience in distributed systems"));
        }

        [Fact]
        public void IsWhisperHallucination_MultilingualHallucinations()
        {
            Assert.True(IsWhisperHallucination("благодаря")); // Bulgarian
            Assert.True(IsWhisperHallucination("ありがとう")); // Japanese
            Assert.True(IsWhisperHallucination("감사합니다")); // Korean
        }

        [Fact]
        public void ShouldSkipAsFillerOrGreeting_SimpleGreeting_ReturnsTrue()
        {
            Assert.True(ShouldSkipAsFillerOrGreeting("Hello"));
            Assert.True(ShouldSkipAsFillerOrGreeting("Good morning"));
        }

        [Fact]
        public void ShouldSkipAsFillerOrGreeting_FillerPhrases_ReturnsTrue()
        {
            Assert.True(ShouldSkipAsFillerOrGreeting("Thanks"));
            Assert.True(ShouldSkipAsFillerOrGreeting("Sounds good"));
            Assert.True(ShouldSkipAsFillerOrGreeting("I see"));
        }

        [Fact]
        public void ShouldSkipAsFillerOrGreeting_GreetingWithQuestion_ReturnsFalse()
        {
            Assert.False(ShouldSkipAsFillerOrGreeting("Hello, what is your experience with microservices?"));
            Assert.False(ShouldSkipAsFillerOrGreeting("Hi, can you tell me about your background?"));
        }

        [Fact]
        public void ShouldSkipAsFillerOrGreeting_RealQuestion_ReturnsFalse()
        {
            Assert.False(ShouldSkipAsFillerOrGreeting("Can you explain the difference between TCP and UDP?"));
        }

        [Fact]
        public void IsLocallyIncomplete_EndsWithArticle_ReturnsTrue()
        {
            Assert.True(IsLocallyIncomplete("I was working on the"));
            Assert.True(IsLocallyIncomplete("The system uses a"));
        }

        [Fact]
        public void IsLocallyIncomplete_EndsWithConjunction_ReturnsTrue()
        {
            Assert.True(IsLocallyIncomplete("We implemented it and"));
            Assert.True(IsLocallyIncomplete("We tried to optimize the query but"));
        }

        [Fact]
        public void IsLocallyIncomplete_EndsWithComma_ReturnsTrue()
        {
            Assert.True(IsLocallyIncomplete("I optimized the database,"));
        }

        [Fact]
        public void IsLocallyIncomplete_CompleteQuestion_ReturnsFalse()
        {
            Assert.False(IsLocallyIncomplete("What is a binary tree?"));
        }

        [Fact]
        public void IsLocallyIncomplete_CompleteStatement_ReturnsFalse()
        {
            Assert.False(IsLocallyIncomplete("The algorithm runs in O(n) time"));
        }

        [Fact]
        public void CheckForQuestionMarkers_EnglishQuestions()
        {
            Assert.True(CheckForQuestionMarkers("What is a hash map?"));
            Assert.True(CheckForQuestionMarkers("How does garbage collection work"));
            Assert.True(CheckForQuestionMarkers("Tell me about your experience"));
            Assert.True(CheckForQuestionMarkers("Explain the SOLID principles"));
        }

        [Fact]
        public void CheckForQuestionMarkers_Statements_ReturnsFalse()
        {
            Assert.False(CheckForQuestionMarkers("I have 5 years of experience"));
            Assert.False(CheckForQuestionMarkers("The system handles 10k requests per second"));
        }

        [Fact]
        public void CheckForQuestionMarkers_MultilingualQuestions()
        {
            Assert.True(CheckForQuestionMarkers("какво е хеш таблица")); // Bulgarian
            Assert.True(CheckForQuestionMarkers("wie funktioniert Garbage Collection")); // German
            Assert.True(CheckForQuestionMarkers("comment fonctionne le garbage collector")); // French
        }

        [Fact]
        public void ClassifySpeaker_ShortQuestion_ReturnsInterviewer()
        {
            Assert.Equal(Speaker.Interviewer, ClassifySpeaker("What is polymorphism?"));
        }

        [Fact]
        public void ClassifySpeaker_LLMClassifiedQuestion_ReturnsInterviewer()
        {
            Assert.Equal(Speaker.Interviewer, ClassifySpeaker("anything", isQuestion: true));
        }

        [Fact]
        public void ClassifySpeaker_LongAnswer_ReturnsInterviewee()
        {
            Assert.Equal(Speaker.Interviewee, ClassifySpeaker(
                "Polymorphism is a concept in object-oriented programming that allows objects of different types to be treated as objects of a common base type. " +
                "It enables you to write code that can work with objects of multiple classes through a single interface, promoting flexibility and extensibility in your software design."));
        }

        [Fact]
        public void ClassifySpeaker_MediumTechnicalAnswer_ReturnsInterviewee()
        {
            Assert.Equal(Speaker.Interviewee, ClassifySpeaker(
                "I have experience building distributed systems with microservices architecture using Docker and Kubernetes for container orchestration and service discovery"));
        }

        [Fact]
        public void ClassifySpeaker_TellMePhrase_ReturnsInterviewer()
        {
            Assert.Equal(Speaker.Interviewer, ClassifySpeaker("Tell me about your experience"));
        }

        [Fact]
        public void ClassifySpeaker_WelcomePhrase_ReturnsInterviewer()
        {
            Assert.Equal(Speaker.Interviewer, ClassifySpeaker("Welcome to the interview"));
        }

        [Fact]
        public void ClassifySpeaker_VeryShortAmbiguous_ReturnsUnknown()
        {
            Assert.Equal(Speaker.Unknown, ClassifySpeaker("ok"));
        }

        [Fact]
        public void IsFollowUp_TellMeMore_ReturnsTrue()
        {
            Assert.True(IsFollowUp("Tell me more about that"));
        }

        [Fact]
        public void IsFollowUp_Elaborate_ReturnsTrue()
        {
            Assert.True(IsFollowUp("Can you elaborate?"));
        }

        [Fact]
        public void IsFollowUp_GiveExample_ReturnsTrue()
        {
            Assert.True(IsFollowUp("Give me an example"));
        }

        [Fact]
        public void IsFollowUp_GoDeeper_ReturnsTrue()
        {
            Assert.True(IsFollowUp("Go deeper into that topic"));
        }

        [Fact]
        public void IsFollowUp_NewQuestion_ReturnsFalse()
        {
            Assert.False(IsFollowUp("What is a binary tree?"));
        }

        [Fact]
        public void IsFollowUp_Statement_ReturnsFalse()
        {
            Assert.False(IsFollowUp("I have experience with React"));
        }

        [Fact]
        public void MessagesToAPIFormat_AlternatingMessages_StaysThree()
        {
            var msgs = new List<MultiTurnMessage>
            {
                new MultiTurnMessage("user", "What is REST?"),
                new MultiTurnMessage("assistant", "REST is..."),
                new MultiTurnMessage("user", "Tell me more")
            };
            var result = MessagesToAPIFormat(msgs);
            Assert.Equal(3, result.Count);
            Assert.Equal("user", result[0]["role"]);
        }

        [Fact]
        public void MessagesToAPIFormat_ConsecutiveSameRole_Merges()
        {
            var msgs = new List<MultiTurnMessage>
            {
                new MultiTurnMessage("user", "Hello"),
                new MultiTurnMessage("user", "What is REST?")
            };
            var result = MessagesToAPIFormat(msgs);
            Assert.Equal(1, result.Count);
            Assert.Contains("Hello", result[0]["content"]);
            Assert.Contains("REST", result[0]["content"]);
        }

        [Fact]
        public void MessagesToAPIFormat_StartsWithAssistant_PrependsUser()
        {
            var msgs = new List<MultiTurnMessage>
            {
                new MultiTurnMessage("assistant", "Welcome"),
                new MultiTurnMessage("user", "Thanks")
            };
            var result = MessagesToAPIFormat(msgs);
            Assert.Equal(3, result.Count);
            Assert.Equal("user", result[0]["role"]);
            Assert.Equal("(Interview in progress)", result[0]["content"]);
        }
    }
}

