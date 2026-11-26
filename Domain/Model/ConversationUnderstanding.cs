using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Pure helpers for reading a live interview transcript: speaker/candidate guards,
    /// foreign-language markers, held/continued questions, garbled speech detection, and back-references.
    /// </summary>
    public static class ConversationUnderstanding
    {
        public static string Normalized(string text)
        {
            if (string.IsNullOrEmpty(text)) return string.Empty;
            var s = text.ToLowerInvariant()
                .Replace('\u2019', '\'')
                .Replace('-', ' ')
                .Replace('_', ' ');
            s = Regex.Replace(s, @"\s+", " ").Trim();
            return s;
        }

        // MARK: - Foreign-language question markers

        private static readonly string[] CyrillicQuestionMarkers =
        {
            "какво", "как ", "защо", "кога", "къде", "кой", "коя", "кое", "кои",
            "разкажи", "раскажи", "обясни", "опиши"
        };

        private static readonly Regex LatinQuestionWords = new(
            @"(^|[^\p{L}])(wie|warum|wann|wo|wer|welche|qu'est|pourquoi|quand|où|qui|qué|cómo|por qué|cuándo|dónde|quién)($|[^\p{L}])",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly HashSet<string> LeadingOnlyQuestionWords = new(StringComparer.OrdinalIgnoreCase)
        {
            "was", "comment"
        };

        public static bool HasForeignQuestionMarker(string normalized)
        {
            if (string.IsNullOrEmpty(normalized)) return false;
            if (CyrillicQuestionMarkers.Any(m => normalized.Contains(m, StringComparison.Ordinal))) return true;
            if (LatinQuestionWords.IsMatch(normalized)) return true;
            var first = normalized.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
            return first != null && LeadingOnlyQuestionWords.Contains(first);
        }

        public static bool HasQuestioningWhWord(IReadOnlyList<string> words)
        {
            var cleaned = words.Take(5)
                .Select(w => w.Trim('.', ',', '!', '?', ':', ';', '"', '\'').ToLowerInvariant())
                .ToList();

            for (int i = 0; i < cleaned.Count && i < 4; i++)
            {
                var word = cleaned[i];
                if (word is not ("which" or "who" or "whose")) continue;
                var next = i + 1 < cleaned.Count ? cleaned[i + 1] : string.Empty;
                var relativeStarts = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                {
                    "i", "we", "he", "she", "they", "it", "you"
                };
                if (i >= 2)
                {
                    relativeStarts.Add("was");
                    relativeStarts.Add("were");
                }
                if (!relativeStarts.Contains(next)) return true;
            }
            return false;
        }

        // MARK: - Candidate speech

        private static readonly string[] CandidateStallPhrases =
        {
            "give me a second", "give me a moment", "give me a minute", "give me one second",
            "just a second", "just a moment", "one second", "one moment", "one sec",
            "hold on", "hang on", "bear with me", "wait a second", "wait a moment",
            "let me think", "let me share", "let me open", "let me create", "let me check",
            "let me see", "let me try", "let me look", "let me find", "let me just",
            "just let me", "sorry about that", "my bad"
        };

        private static readonly string[] CandidateCheckPhrases =
        {
            "does that make sense", "is that what you're looking for", "is that what you are looking for",
            "is that okay", "is this okay", "is that clear", "i hope that helps", "i hope that answers",
            "does that answer your question", "that's all i have", "that is all i have"
        };

        private static readonly string[] RepeatRequestPhrases =
        {
            "can you repeat", "could you repeat", "can i repeat", "can you say that again",
            "could you say that again", "say that again", "i didn't catch that", "i didn't hear you", "come again"
        };

        private static readonly HashSet<string> RepeatFillerWords = new(StringComparer.OrdinalIgnoreCase)
        {
            "sorry", "please", "okay", "ok", "uh", "um", "the", "that", "again", "question", "it", "what", "so", "oh"
        };

        public static bool IsCandidateMetaUtterance(string text)
        {
            var norm = Normalized(text);
            var cleaned = norm.Trim(' ', '.', ',', '!', '?', ':', ';');
            if (string.IsNullOrEmpty(cleaned)) return false;
            var wordCount = cleaned.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length;
            if (wordCount > 16) return false;
            if (cleaned == "sorry") return true;

            var repeatPhrase = RepeatRequestPhrases.FirstOrDefault(p => cleaned.Contains(p, StringComparison.Ordinal));
            if (repeatPhrase != null)
            {
                var remainder = Regex.Split(cleaned.Replace(repeatPhrase, " "), @"[^\p{L}\p{N}]+")
                    .Where(w => !string.IsNullOrEmpty(w) && !RepeatFillerWords.Contains(w))
                    .ToList();
                return remainder.Count <= 2;
            }

            var phrase = CandidateStallPhrases.Concat(CandidateCheckPhrases)
                .FirstOrDefault(p => cleaned.Contains(p, StringComparison.Ordinal));
            if (phrase == null) return false;

            return !HasInterviewerFrame(cleaned.Replace(phrase, " "));
        }

        private static readonly Regex InterviewerFrameRegex = new(
            @"\b(what|how|why|when|where|which|who)\s+(is|are|was|were|do|does|did|would|will|can|could|should|has|have|about|kind|type|else|exactly|if)\b|\b(why|how)\s+(this|that|your)\b|\b(can|could|would|will|do|did|have|are|is)\s+(you|your)\b|\b(would|could|can|will|should|is|are|was|were)\s+(it|this|that|there|we|i|they)\b|\b(tell|show|give|walk|talk)\s+(me|us)\b|\b(explain|describe|compare|elaborate)\b|\b(let's|lets|let us)\s+(start|begin|talk|discuss|go|move|proceed|jump)\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        public static bool HasInterviewerFrame(string normalized) =>
            !string.IsNullOrEmpty(normalized) && InterviewerFrameRegex.IsMatch(normalized);

        private static readonly Regex FirstPersonWord = new(
            @"\b(i|i'm|im|i've|ive|i'd|i'll|we|we're|we've|we'd|my|our|me|myself)\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly string[] AnswerOpeners =
        {
            "yeah", "yes", "yep", "well", "nope", "mostly", "basically", "actually", "honestly",
            "to be honest", "for me", "in my", "for example", "like for example", "something like",
            "so basically", "i think", "i guess", "i believe", "probably", "it depends", "depending on"
        };

        private static readonly string[] TrailingQuestionWords =
        {
            "and what", "and how", "and why", "and which", "and where", "and when"
        };

        private static readonly string[] TrailingConnectives =
            TrailingQuestionWords.Concat(new[] { "let's say", "kind of", "sort of" }).ToArray();

        private static readonly char[] TrailingPunctuation = { '.', ',', '\u2026', '?', ' ' };

        private static readonly HashSet<string> QuestionOpeners = new(StringComparer.OrdinalIgnoreCase)
        {
            "what", "how", "why", "when", "where", "which", "who", "whose",
            "can", "could", "do", "does", "did", "is", "are", "should", "would"
        };

        private static readonly HashSet<string> FamiliarListWords = new(StringComparer.OrdinalIgnoreCase)
        {
            "python", "java", "go", "rust", "swift", "kotlin", "ruby", "scala", "php", "perl", "c", "sql",
            "react", "vue", "node", "docker", "redis", "kafka", "aws", "azure", "gcp", "linux", "git"
        };

        private static readonly string[] FollowUpPhrases =
        {
            "tell me more", "dig deeper", "go deeper", "elaborate", "expand on", "more details", "more about",
            "what about", "how about", "what else", "anything else", "give me an example"
        };

        private static readonly string[] CodeReferencePhrases =
        {
            "did you", "you used", "you chose", "you wrote", "your solution", "your code", "this code", "that code",
            "the code", "this function", "the function", "version", "complexity"
        };

        public static bool FollowsPrevious(string question, string topic, string? previousTopic)
        {
            if (string.IsNullOrEmpty(previousTopic)) return false;
            var t = (topic ?? string.Empty).ToLowerInvariant();
            if (t == "followup") return true;
            if (t != "unknown" && t != "answer" && t == previousTopic.ToLowerInvariant()) return true;
            var lower = (question ?? string.Empty).ToLowerInvariant();
            if (previousTopic.Equals("coding", StringComparison.OrdinalIgnoreCase) &&
                CodeReferencePhrases.Any(p => lower.Contains(p, StringComparison.Ordinal)))
                return true;
            return FollowUpPhrases.Any(p => lower.Contains(p, StringComparison.Ordinal)) ||
                   RefersBackToConversation(question ?? string.Empty);
        }

        public static bool TrailsOff(string text)
        {
            var lower = (text ?? string.Empty).ToLowerInvariant().Trim();
            if (string.IsNullOrEmpty(lower)) return false;
            var bare = lower.TrimEnd(TrailingPunctuation);
            if (lower.EndsWith('?'))
                return TrailingQuestionWords.Any(w => bare.EndsWith(" " + w, StringComparison.Ordinal));
            if (lower.EndsWith("...", StringComparison.Ordinal) || lower.EndsWith('\u2026'))
                return true;
            return TrailingConnectives.Any(c => bare.EndsWith(" " + c, StringComparison.Ordinal));
        }

        public static string? HeldQuestion(string text)
        {
            var trimmed = (text ?? string.Empty).Trim();
            if (!trimmed.EndsWith(',') && !TrailsOff(trimmed)) return null;
            var question = trimmed.TrimEnd(TrailingPunctuation);
            while (true)
            {
                var tail = TrailingConnectives.FirstOrDefault(c =>
                    question.EndsWith(" " + c, StringComparison.OrdinalIgnoreCase));
                if (tail == null) break;
                question = question[..^(tail.Length + 1)].TrimEnd(TrailingPunctuation);
            }
            return string.IsNullOrEmpty(question) ? null : question;
        }

        public static string? ContinuedQuestion(string? previous, string fragment, double? secondsSincePrevious, double window)
        {
            if (string.IsNullOrEmpty(previous) || !secondsSincePrevious.HasValue || secondsSincePrevious.Value > window)
                return null;
            if (string.IsNullOrEmpty(fragment) || fragment.Contains('?'))
                return null;
            var words = Normalized(fragment).Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (words.Length == 0 || words.Length > 6 || QuestionOpeners.Contains(words[0]))
                return null;
            return $"{previous} {fragment}";
        }

        public static bool LooksGarbled(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return false;
            var cleaned = text.Trim().Trim('.', ',', '!', '?', ':', ';', '"', '\'', '\u2026');
            var pieces = cleaned.Split(',')
                .Select(p => p.Trim().ToLowerInvariant())
                .Where(p => !string.IsNullOrEmpty(p))
                .ToList();
            if (pieces.Count < 4) return false;

            var allScraps = pieces.All(piece =>
            {
                var words = piece.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                return words.Length is >= 1 and <= 2 &&
                       words.All(w => w.Length <= 6 && w.All(ch => ch < 128 && char.IsLetter(ch)));
            });
            if (!allScraps) return false;

            var allWords = pieces.SelectMany(p => p.Split(' ', StringSplitOptions.RemoveEmptyEntries));
            return !allWords.Any(w => QuestionOpeners.Contains(w) || FamiliarListWords.Contains(w));
        }

        public static bool LooksLikeCandidateNarrative(string normalized)
        {
            if (string.IsNullOrEmpty(normalized)) return false;
            var words = normalized.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (words.Length < 12 || normalized.Contains('?') || HasInterviewerFrame(normalized)) return false;
            var firstPerson = FirstPersonWord.Matches(normalized).Count;
            var hasOpener = AnswerOpeners.Any(o => normalized.StartsWith(o, StringComparison.Ordinal));
            return firstPerson >= 2 || (hasOpener && (firstPerson >= 1 || words.Length >= 16));
        }

        // MARK: - Back-references

        private static readonly string[] BackReferencePhrases =
        {
            "you mean", "you meant", "you said", "you mentioned", "we talked", "we discussed",
            "as we said", "as we discussed", "go on", "and then", "what next", "next step",
            "what do you mean", "which one", "which ones", "what else", "anything else",
            "what about", "how about"
        };

        private static readonly HashSet<string> AnaphoraWords = new(StringComparer.OrdinalIgnoreCase)
        {
            "it", "this", "these", "those", "them", "they", "same", "above", "earlier", "mentioned", "again"
        };

        private static readonly Regex AnaphoricThat = new(
            @"\b(by|about|of|on|with|for|is|does|do|did|explain|mean|use|used)\s+that\b|\bthat$",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly HashSet<string> SubjectlessWords = new(StringComparer.OrdinalIgnoreCase)
        {
            "i", "you", "we", "he", "she", "they", "it", "me", "us", "my", "your", "our", "their", "its",
            "is", "are", "was", "were", "be", "been", "being", "am", "do", "does", "did", "done",
            "have", "has", "had", "can", "could", "would", "will", "shall", "should", "may", "might", "must",
            "not", "no", "yes", "yeah", "yep", "ok", "okay", "so", "well", "anyway", "actually", "basically",
            "just", "really", "then", "now", "also", "still", "maybe", "please", "sorry", "thanks", "thank",
            "hi", "hello", "what", "how", "why", "when", "where", "which", "who", "whom", "whose", "whether",
            "if", "the", "and", "for", "with", "from", "about", "into", "over", "than", "but", "like", "that",
            "this", "these", "those", "there", "here", "some", "any", "all", "more", "other", "another",
            "get", "got", "go", "going", "gone", "come", "start", "starting", "begin", "next", "expect",
            "expecting", "approach", "handle", "deal", "think", "thinking", "see", "look", "say", "tell",
            "ask", "know", "want", "need", "make", "take", "put", "give", "work", "works", "working",
            "thing", "things", "stuff", "something", "anything", "everything", "way", "ways", "time",
            "explain", "describe", "elaborate", "expand", "details", "deeper", "detail", "example",
            "else", "same", "again", "mean", "meant", "kind", "sort", "let", "lets", "whats", "thats",
            "hows", "dont", "doesnt", "didnt", "cant", "wont", "isnt", "arent", "youre", "weve", "theres",
            "one", "ones", "much", "many", "very", "too", "out", "off", "under", "own"
        };

        public static bool RefersBackToConversation(string text)
        {
            var norm = Normalized(text);
            if (string.IsNullOrEmpty(norm)) return false;

            var letters = norm.Where(char.IsLetter).ToList();
            if (letters.Count > 0)
            {
                var nonLatin = letters.Count(c => c > 0x024F);
                if ((double)nonLatin / letters.Count > 0.3) return true;
            }

            if (BackReferencePhrases.Any(p => norm.Contains(p, StringComparison.Ordinal))) return true;

            var words = Regex.Split(norm.Replace("'", ""), @"[^\p{L}\p{N}]+")
                .Where(w => !string.IsNullOrEmpty(w))
                .ToList();

            var contentWords = words.Where(w => w.Length >= 3 && !SubjectlessWords.Contains(w)).ToList();
            if (contentWords.Count == 0) return true;

            if (words.Count <= 8 && words.Any(w => AnaphoraWords.Contains(w))) return true;
            if (words.Count <= 10 && !HasInterviewerFrame(norm)) return true;
            if (words.Count > 10) return false;

            var trimmed = norm.Trim(' ', '.', ',', '!', '?', ':', ';', '"', '\'');
            return AnaphoricThat.IsMatch(trimmed);
        }

        // MARK: - Whisper hallucination / filler / incomplete local guards

        private static readonly HashSet<string> WhisperHallucinations = new(StringComparer.OrdinalIgnoreCase)
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

        public static bool IsWhisperHallucination(string trimmed)
        {
            if (string.IsNullOrWhiteSpace(trimmed)) return true;
            var lower = trimmed.ToLowerInvariant()
                .Replace("!", "").Replace(".", "").Replace(",", "").Trim();
            return trimmed.Length < 30 && WhisperHallucinations.Contains(lower);
        }

        public static bool IsNonAsciiGarbageForEnglish(string trimmed, SpeakingLanguage listeningLanguage)
        {
            if (listeningLanguage != SpeakingLanguage.English || string.IsNullOrEmpty(trimmed)) return false;
            var nonAscii = trimmed.Count(c => c > 127);
            var ratio = (double)nonAscii / Math.Max(trimmed.Length, 1);
            return ratio > 0.15 && nonAscii > 3;
        }

        public static bool ShouldSkipAsFillerOrGreeting(string trimmed)
        {
            if (string.IsNullOrWhiteSpace(trimmed)) return true;
            var normalizedText = Regex.Replace(trimmed.ToLowerInvariant().Trim(), @"[.!?,']", "");
            string[] greetingStarts = { "hello", "hi ", "hey ", "good morning", "good afternoon", "good evening", "welcome to" };
            string[] fillerPatterns = { "thank you", "thanks", "yes sure", "yeah sure", "okay", "sure", "sounds good", "got it", "i see", "i understand", "alright" };
            string[] questionWords = { "what", "how", "why", "when", "where", "which", "who", "can you", "could you", "would you", "tell me", "explain", "describe", "give me", "show me", "walk me" };

            var isGreeting = greetingStarts.Any(g => normalizedText.StartsWith(g, StringComparison.Ordinal));
            var isFiller = fillerPatterns.Any(f => normalizedText.StartsWith(f, StringComparison.Ordinal) || normalizedText == f);
            var hasQuestionWord = questionWords.Any(q => normalizedText.Contains(q, StringComparison.Ordinal));

            return (isGreeting || isFiller) && normalizedText.Length < 50 && !hasQuestionWord;
        }

        public static bool IsLocallyIncomplete(string trimmed)
        {
            if (string.IsNullOrWhiteSpace(trimmed)) return true;
            var norm = Normalized(trimmed).TrimEnd('.', ',', '!', '?', ' ');
            var words = norm.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (words.Length == 0) return true;

            string[] bareStems =
            {
                "what is", "what is the", "what are", "what are the",
                "can you", "can you explain", "could you", "could you explain",
                "tell me", "tell me about", "how do", "how does", "how would",
                "why do", "why does", "explain", "describe"
            };
            return bareStems.Contains(norm);
        }

        public static bool HasQuestionMarkers(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return false;
            var norm = Normalized(text);
            if (text.Contains('?')) return true;
            if (HasInterviewerFrame(norm)) return true;
            if (HasForeignQuestionMarker(norm)) return true;
            var words = norm.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (HasQuestioningWhWord(words)) return true;
            string[] extraMarkers =
            {
                "difference between", "differences between",
                "what's", "whats", "tell me about", "tell me more"
            };
            return extraMarkers.Any(m => norm.Contains(m, StringComparison.Ordinal));
        }
    }

    public static class AnswerPromptBlocks
    {
        public const string CandidateVoice =
@"CANDIDATE VOICE:
- Point first. Short, direct sentences, everyday words, natural contractions.
- One point at a time. Give the action, then the reason or one concrete example.
- Sound like a colleague explaining their approach. No sales language or textbook padding.
- Say ""use"", ""check"", ""fix""; avoid ""leverage"", ""facilitate"", ""robust solution"".
- For an approach, say ""I'd check..."" or ""I'd use..."". State definitions directly.
- Say ""I use"" or ""I did"" only when the CV in this prompt supports it. Never invent experience.
- Keep technical terms exact and limitations that change the answer; skip generic hedges.
- No ""I'd say"", ""I would answer it as"", intros or closing summaries.
- Example: ""Keep the result in a cache so you don't fetch it again.""";

        public sealed record TopicPrompt(string Line, string GarbleNote, bool AllowsTopicSpecificShape);

        private const string AnswerAsAsked = "The transcript may contain speech-to-text errors. Answer the question as asked.";

        public static TopicPrompt Topic(string? topic, bool inherited)
        {
            var lower = (topic ?? string.Empty).Trim().ToLowerInvariant();
            if (string.IsNullOrEmpty(lower) || lower == "unknown")
                return new TopicPrompt(string.Empty, AnswerAsAsked, false);
            if (inherited)
                return new TopicPrompt($"PREVIOUS TOPIC (only if the question refers back to it): {topic}", AnswerAsAsked, false);
            return new TopicPrompt(
                $"TOPIC: {topic}",
                "The transcript may contain speech-to-text errors. Trust TOPIC when words are garbled.",
                true);
        }

        public static string RecentConversation(string? context, bool extendsPreviousAnswer)
        {
            var trimmed = (context ?? string.Empty).Trim();
            if (string.IsNullOrEmpty(trimmed) || trimmed == "No previous conversation.") return string.Empty;
            var instruction = extendsPreviousAnswer
                ? "This is a follow-up on the same topic. Add new, deeper points or a concrete example; do NOT repeat what was already covered."
                : "Use the conversation only to work out what words like \"it\", \"that\" or \"these\" refer to. Answer the CURRENT question, not an earlier one.";
            return $"\n=== CONVERSATION SO FAR ===\n{trimmed}\n=== END CONVERSATION ===\n\n{instruction}\n";
        }

        public static string PinnedCode(string? solution, int limit = 1800)
        {
            var trimmed = (solution ?? string.Empty).Trim();
            if (string.IsNullOrEmpty(trimmed)) return string.Empty;
            var body = trimmed.Length > limit ? trimmed[..limit] + "\n…" : trimmed;
            return $"\nCODE THE CANDIDATE IS WRITING (answer in this context when the question is about it):\n{body}\n";
        }
    }
}
