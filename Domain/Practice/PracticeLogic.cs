using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace InterviewMasterApp.Domain.Practice
{
    public enum PracticeHelpMark { None, Yellow }
    public enum PracticeRunMode { Learn, Rehearse, Interview }
    public enum PracticeRecallRating { Again, Hard, GotIt }
    public enum PracticeRecallConfidence { Unsure, Mostly, Very }

    public sealed record PracticeScoreResult(double RawScore, bool UsedHelp, PracticeHelpMark Mark, double FinalScore);

    public sealed class PracticeCardOption
    {
        [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
        [JsonPropertyName("text")] public string Text { get; set; } = string.Empty;
        [JsonPropertyName("rationale")] public string Rationale { get; set; } = string.Empty;
    }

    public sealed class PracticeCardContent
    {
        [JsonPropertyName("options")] public List<PracticeCardOption> Options { get; set; } = new();
        [JsonPropertyName("correctOptionID")] public string CorrectOptionId { get; set; } = string.Empty;
        [JsonPropertyName("explanation")] public string Explanation { get; set; } = string.Empty;
        [JsonPropertyName("sourceURL")] public string SourceUrl { get; set; } = string.Empty;
        [JsonPropertyName("contentVersion")] public int ContentVersion { get; set; } = 1;

        [JsonIgnore]
        public bool IsValid =>
            Options.Count == 4 &&
            Options.Select(o => o.Id).Distinct(StringComparer.Ordinal).Count() == 4 &&
            Options.Select(o => o.Text.Trim().ToLowerInvariant()).Distinct(StringComparer.Ordinal).Count() == 4 &&
            Options.All(o => !string.IsNullOrEmpty(o.Id) && !string.IsNullOrWhiteSpace(o.Text) && !string.IsNullOrEmpty(o.Rationale)) &&
            Options.Any(o => o.Id == CorrectOptionId) &&
            !string.IsNullOrEmpty(Explanation) &&
            ContentVersion > 0;
    }

    public sealed class PracticeCardResult
    {
        public string SelectedOptionId { get; set; } = string.Empty;
        public string CorrectOptionId { get; set; } = string.Empty;
        public string CorrectAnswer { get; set; } = string.Empty;
        public string Explanation { get; set; } = string.Empty;
        public string Topic { get; set; } = string.Empty;
        public int ContentVersion { get; set; } = 1;
    }

    public sealed class PracticeQuestion
    {
        [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
        [JsonPropertyName("packId")] public string PackId { get; set; } = string.Empty;
        [JsonPropertyName("text")] public string Text { get; set; } = string.Empty;
        [JsonPropertyName("groupId")] public string GroupId { get; set; } = string.Empty;
        [JsonPropertyName("topicId")] public string TopicId { get; set; } = string.Empty;
        [JsonPropertyName("topicTitle")] public string TopicTitle { get; set; } = string.Empty;
        [JsonPropertyName("hints")] public List<string> Hints { get; set; } = new();
        [JsonPropertyName("rubric")] public string Rubric { get; set; } = string.Empty;
        [JsonPropertyName("answer")] public string Answer { get; set; } = string.Empty;
        [JsonPropertyName("card")] public PracticeCardContent? Card { get; set; }
    }

    public sealed class PracticeGroup
    {
        [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
        [JsonPropertyName("title")] public string Title { get; set; } = string.Empty;
    }

    public sealed class PracticePosition
    {
        [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
        [JsonPropertyName("title")] public string Title { get; set; } = string.Empty;
        [JsonPropertyName("packId")] public string PackId { get; set; } = string.Empty;
        [JsonPropertyName("groupIds")] public List<string> GroupIds { get; set; } = new();
    }

    public sealed class PracticeTopicPack
    {
        [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
        [JsonPropertyName("title")] public string Title { get; set; } = string.Empty;
        [JsonPropertyName("blurb")] public string Blurb { get; set; } = string.Empty;
        [JsonPropertyName("groups")] public List<PracticeGroup> Groups { get; set; } = new();
        [JsonPropertyName("questions")] public List<PracticeQuestion> Questions { get; set; } = new();

        public static List<PracticeTopicPack> BuiltInAll => new()
        {
            new PracticeTopicPack
            {
                Id = "aws", Title = "AWS", Blurb = "IAM, networking, storage, and compute trade-offs",
                Groups = new() { new PracticeGroup { Id = "aws", Title = "AWS" } },
                Questions = new()
                {
                    new() { Id = "aws-iam", PackId = "aws", GroupId = "aws", Text = "What is the difference between an IAM user and an IAM role?" },
                    new() { Id = "aws-s3", PackId = "aws", GroupId = "aws", Text = "When would you choose S3 Intelligent-Tiering over S3 Standard?" },
                    new() { Id = "aws-sqs-sns", PackId = "aws", GroupId = "aws", Text = "How does SQS differ from SNS, and when would you use both?" },
                    new() { Id = "aws-vpc", PackId = "aws", GroupId = "aws", Text = "How does VPC peering differ from Transit Gateway?" },
                    new() { Id = "aws-lambda-ecs", PackId = "aws", GroupId = "aws", Text = "When would you run a workload on Lambda instead of ECS?" }
                }
            },
            new PracticeTopicPack
            {
                Id = "models", Title = "Models", Blurb = "Transformers, sampling, RAG, and serving trade-offs",
                Groups = new() { new PracticeGroup { Id = "models", Title = "Models" } },
                Questions = new()
                {
                    new() { Id = "models-encoder-decoder", PackId = "models", GroupId = "models", Text = "What is the difference between a transformer encoder and a decoder?" },
                    new() { Id = "models-sampling", PackId = "models", GroupId = "models", Text = "Explain temperature versus top-p when sampling from an LLM." },
                    new() { Id = "models-rag", PackId = "models", GroupId = "models", Text = "What is RAG, and when would you use it instead of fine-tuning?" },
                    new() { Id = "models-embeddings", PackId = "models", GroupId = "models", Text = "How do embeddings enable semantic search?" },
                    new() { Id = "models-quant", PackId = "models", GroupId = "models", Text = "What is weight quantization, and what do you trade away for speed?" }
                }
            }
        };
    }

    public sealed class PracticeBankFile
    {
        [JsonPropertyName("packs")] public List<PracticeTopicPack> Packs { get; set; } = new();
        [JsonPropertyName("positions")] public List<PracticePosition> Positions { get; set; } = new();
    }

    public sealed class PracticeScoredAnswer
    {
        public string QuestionId { get; set; } = string.Empty;
        public string QuestionText { get; set; } = string.Empty;
        public string Answer { get; set; } = string.Empty;
        public double RawScore { get; set; }
        public double FinalScore { get; set; }
        public bool UsedHelp { get; set; }
        public PracticeHelpMark Mark { get; set; } = PracticeHelpMark.None;
        public PracticeRecallRating? RecallRating { get; set; }
        public PracticeRecallConfidence? Confidence { get; set; }
        public PracticeCardResult? CardResult { get; set; }
        public DateTime AnsweredAt { get; set; } = DateTime.UtcNow;
        public DateTime? NextReviewAt { get; set; }
    }

    public sealed class PracticeRunRecord
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public string PackId { get; set; } = string.Empty;
        public string PackTitle { get; set; } = string.Empty;
        public PracticeRunMode Mode { get; set; } = PracticeRunMode.Learn;
        public DateTime StartedAt { get; set; } = DateTime.UtcNow;
        public DateTime FinishedAt { get; set; } = DateTime.UtcNow;
        public double OverallScore { get; set; }
        public List<PracticeScoredAnswer> Answers { get; set; } = new();
    }

    public sealed class PracticeSessionSnapshot
    {
        public string RunId { get; set; } = Guid.NewGuid().ToString();
        public string PackId { get; set; } = string.Empty;
        public string PackTitle { get; set; } = string.Empty;
        public PracticeRunMode Mode { get; set; } = PracticeRunMode.Learn;
        public int CurrentIndex { get; set; }
        public List<string> QuestionIds { get; set; } = new();
        public List<PracticeScoredAnswer> Answers { get; set; } = new();
        public DateTime SavedAt { get; set; } = DateTime.UtcNow;
    }

    public sealed record PracticeRole(string Id, string Title, string[] GroupIds, string? CardPackId = null)
    {
        public static readonly PracticeRole ClaudeArchitect = new("claude-architect", "Claude Architect",
            new[] { "claude-agents", "claude-tools", "claude-code", "claude-prompts", "claude-context" }, "claude-architect");
        public static readonly PracticeRole AiEngineerCards = new("ai-engineer-cards", "AI Engineer Cards",
            new[] { "cards-agents", "cards-coding", "cards-evaluation", "cards-fastapi-and-production", "cards-llm-foundations", "cards-python-oop", "cards-python-runtime", "cards-rag", "cards-submitted-project" }, "ai-engineer-cards");
        public static readonly PracticeRole MlCoreCards = new("ml-core-cards", "Core ML Cards",
            new[] { "cards-ml-metrics", "cards-ml-data", "cards-ml-models", "cards-ml-validation", "cards-ml-deep" }, "ml-core-cards");
        public static readonly PracticeRole TypescriptCards = new("typescript-cards", "TypeScript Cards",
            new[] { "cards-typescript" }, "typescript-cards");
        public static readonly PracticeRole AiEngineer = new("ai-engineer", "AI Engineer",
            new[] { "python-engineering", "foundations", "classical-ml", "genai-and-llm", "ml-in-production", "system-design", "models", "interview-prep", "agentic-sme-s-and-p", "aws", "devops" });
        public static readonly PracticeRole Frontend = new("frontend", "Frontend engineer",
            new[] { "jr-javascript", "mid-javascript", "senior-javascript", "typescript", "angular", "oop", "json", "networking", "engineering-practice", "system-design" });
        public static readonly PracticeRole FullStack = new("full-stack", "Full stack",
            new[] { "python-engineering", "jr-javascript", "mid-javascript", "senior-javascript", "typescript", "angular", "oop", "system-design", "engineering-practice", "aws", "networking", "json", "devops", "genai-and-llm", "interview-prep" });
        public static readonly PracticeRole QaAutomation = new("qa-automation", "QA automation",
            new[] { "qa", "coding-tasks", "logical-tasks", "python-engineering", "engineering-practice", "java-and-jvm", "system-design", "interview-prep" });

        public static readonly IReadOnlyList<PracticeRole> All = new[]
        {
            AiEngineer, ClaudeArchitect, AiEngineerCards, MlCoreCards, TypescriptCards, Frontend, FullStack, QaAutomation
        };
    }

    public static class PracticeLogic
    {
        public const double HelpMultiplier = 0.4;

        public static PracticeScoreResult ApplyHelpPenalty(double rawScore, bool usedHelp)
        {
            var raw = Math.Clamp(rawScore, 0.0, 1.0);
            return usedHelp
                ? new PracticeScoreResult(raw, true, PracticeHelpMark.Yellow, raw * HelpMultiplier)
                : new PracticeScoreResult(raw, false, PracticeHelpMark.None, raw);
        }

        public static bool HelpAllowed(PracticeRunMode mode) => mode != PracticeRunMode.Interview;

        public static string? HelpText(PracticeQuestion question)
        {
            if (!string.IsNullOrWhiteSpace(question.Answer)) return question.Answer.Trim();
            if (!string.IsNullOrWhiteSpace(question.Rubric)) return question.Rubric.Trim();
            return null;
        }

        public static string NormalizeQuestionText(string text)
        {
            var s = Regex.Replace(text ?? string.Empty, "<[^>]+>", string.Empty);
            s = s.Replace("&nbsp;", " ").Replace("&amp;", "&").Replace("&lt;", "<").Replace("&gt;", ">")
                 .Replace("&#39;", "'").Replace("&quot;", "\"");
            return Regex.Replace(s, @"\s+", " ").Trim();
        }

        public static List<PracticeQuestion> BalancedSelection(
            IReadOnlyList<PracticeQuestion> questions,
            int count,
            Func<PracticeQuestion, string> topicOf,
            Func<List<PracticeQuestion>, List<PracticeQuestion>>? shuffle = null)
        {
            var want = Math.Min(Math.Max(0, count), questions.Count);
            if (want == 0) return new List<PracticeQuestion>();

            var order = new List<string>();
            var buckets = new Dictionary<string, List<PracticeQuestion>>(StringComparer.Ordinal);
            foreach (var q in questions)
            {
                var topic = topicOf(q);
                if (!buckets.ContainsKey(topic))
                {
                    order.Add(topic);
                    buckets[topic] = new List<PracticeQuestion>();
                }
                buckets[topic].Add(q);
            }

            var rng = new Random();
            shuffle ??= list => list.OrderBy(_ => rng.Next()).ToList();
            foreach (var t in order) buckets[t] = shuffle(buckets[t]);

            var nextIdx = order.ToDictionary(t => t, _ => 0);
            var selected = new List<PracticeQuestion>(want);
            bool progressed = true;
            while (selected.Count < want && progressed)
            {
                progressed = false;
                foreach (var t in order)
                {
                    if (selected.Count >= want) break;
                    var idx = nextIdx[t];
                    if (idx < buckets[t].Count)
                    {
                        selected.Add(buckets[t][idx]);
                        nextIdx[t] = idx + 1;
                        progressed = true;
                    }
                }
            }
            return selected;
        }

        public static List<PracticeQuestion> CurriculumOrdered(IReadOnlyList<PracticeQuestion> questions)
        {
            static int[] Key(PracticeQuestion q)
            {
                var topicNums = Regex.Matches(q.TopicId ?? "", @"\d+").Select(m => int.Parse(m.Value));
                var idNums = Regex.Matches(q.Id ?? "", @"\d+").Select(m => int.Parse(m.Value));
                return topicNums.Append(int.MaxValue).Concat(idNums).ToArray();
            }

            return questions.Select((q, i) => (q, i, key: Key(q)))
                .OrderBy(x => x, Comparer<(PracticeQuestion q, int i, int[] key)>.Create((a, b) =>
                {
                    var len = Math.Min(a.key.Length, b.key.Length);
                    for (int k = 0; k < len; k++)
                    {
                        var cmp = a.key[k].CompareTo(b.key[k]);
                        if (cmp != 0) return cmp;
                    }
                    var lenCmp = a.key.Length.CompareTo(b.key.Length);
                    return lenCmp != 0 ? lenCmp : a.i.CompareTo(b.i);
                }))
                .Select(x => x.q)
                .ToList();
        }

        public static DateTime NextReviewDate(PracticeRecallRating rating, DateTime? from = null)
        {
            var start = from ?? DateTime.UtcNow;
            var span = rating switch
            {
                PracticeRecallRating.Again => TimeSpan.FromMinutes(5),
                PracticeRecallRating.Hard => TimeSpan.FromDays(1),
                PracticeRecallRating.GotIt => TimeSpan.FromDays(3),
                _ => TimeSpan.FromDays(1)
            };
            return start.Add(span);
        }

        public static PracticeCardResult EvaluateCardChoice(PracticeQuestion question, string selectedOptionId)
        {
            var card = question.Card ?? throw new InvalidOperationException("Question has no four-choice card.");
            var correctOpt = card.Options.FirstOrDefault(o => o.Id == card.CorrectOptionId);
            return new PracticeCardResult
            {
                SelectedOptionId = selectedOptionId,
                CorrectOptionId = card.CorrectOptionId,
                CorrectAnswer = correctOpt?.Text ?? string.Empty,
                Explanation = card.Explanation,
                Topic = string.IsNullOrEmpty(question.TopicTitle) ? question.GroupId : question.TopicTitle,
                ContentVersion = card.ContentVersion
            };
        }

        public static double ScoreCardChoice(PracticeQuestion question, string selectedOptionId) =>
            question.Card != null && selectedOptionId == question.Card.CorrectOptionId ? 1.0 : 0.0;
    }
}
