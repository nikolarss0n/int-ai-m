using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace InterviewMasterApp.Domain.Model
{
    public sealed record InterviewBriefing(string Thread, string Digest, List<string> TalkingPoints);

    public sealed record ResumeRole(string Heading, int StartYear, int? EndYear, List<string> EmployerKeywords);

    public static class InterviewBriefingHelper
    {
        private static readonly (string Thread, string[] Keywords)[] ThreadKeywords =
        {
            ("rag", new[] { "graph rag", "hybrid search", "multi hop", "multi-hop", "chunking", "chunk", "embedding", "embeddings", "rerank", "reranking", "citation", "citations", "retrieval", "vector db", "vector database", "rag" }),
            ("agents", new[] { "langgraph", "langchain", "multi agent", "multi-agent", "tool calling", "hitl", "human in the loop", "react", "agents", "agent" }),
            ("evals", new[] { "faithfulness", "grounding", "mrr", "precision", "recall", "evals", "eval" }),
            ("production", new[] { "fastapi", "pydantic", "langsmith", "mlflow", "serverless", "kubernetes", "aks", "k8s", "timeouts", "retries", "production" }),
            ("personal", new[] { "tell me about yourself", "your background", "your experience", "last project", "introduce yourself" })
        };

        private static readonly Dictionary<string, string> ThreadLabels = new(StringComparer.OrdinalIgnoreCase)
        {
            ["rag"] = "RAG / retrieval",
            ["agents"] = "Agents / orchestration",
            ["evals"] = "Evals / grounding",
            ["production"] = "Production / serving",
            ["personal"] = "Background / experience"
        };

        public static InterviewBriefing? NextBriefing(string utterance, bool isQuestion, string resumeText, InterviewBriefing? prior)
        {
            _ = isQuestion;
            var trimmed = (utterance ?? string.Empty).Trim();
            if (trimmed.Length < 8) return null;

            var thread = DetectThread(trimmed);
            if (thread == "unknown") thread = prior?.Thread ?? "unknown";
            if (thread == "unknown") return null;

            var next = new InterviewBriefing(
                thread,
                BuildDigest(trimmed, thread),
                TalkingPointsFromResume(resumeText, thread));

            if (prior != null && prior.Thread == next.Thread && prior.Digest == next.Digest &&
                prior.TalkingPoints.SequenceEqual(next.TalkingPoints))
                return null;

            return next;
        }

        public static string FormatBriefingContent(InterviewBriefing briefing)
        {
            var lines = new List<string> { briefing.Digest };
            if (briefing.TalkingPoints.Count == 0)
                lines.Add("No matching resume points for this thread.");
            else
                lines.AddRange(briefing.TalkingPoints.Select(p => $"- [CV] {p}"));
            return string.Join("\n", lines);
        }

        public static string ExtractResumeText(string markdown)
        {
            if (string.IsNullOrEmpty(markdown)) return string.Empty;
            var text = markdown.Replace("\r\n", "\n");
            text = Regex.Replace(text, @"```[\s\S]*?```", " ");
            text = Regex.Replace(text, @"!\[[^\]]*\]\([^)]+\)", " ");
            text = Regex.Replace(text, @"\[([^\]]+)\]\([^)]+\)", "$1");
            text = Regex.Replace(text, @"[*_`#>]+", " ");
            var lines = text.Split('\n').Select(raw =>
            {
                var t = raw.Trim();
                while (t.StartsWith("- ", StringComparison.Ordinal) || t.StartsWith("* ", StringComparison.Ordinal))
                    t = t[2..].Trim();
                return t;
            });
            var joined = string.Join("\n", lines);
            return Regex.Replace(joined, @"\n{3,}", "\n\n").Trim();
        }

        public static bool IsExperienceCueCardQuestion(string text, string topic)
        {
            if (string.Equals(topic, "personal", StringComparison.OrdinalIgnoreCase)) return true;
            var norm = NormalizeText(text);
            string[] pastMarkers =
            {
                "did you", "have you", "have you used", "how have you",
                "your experience", "your background", "your last",
                "you used", "you do with", "you did",
                "walk me through your", "tell me about yourself",
                "in your last", "in your role",
                "side project", "personal project", "hobby project", "outside of work", "in your free time",
                "your projects", "any projects"
            };
            if (pastMarkers.Any(m => norm.Contains(m, StringComparison.Ordinal))) return true;

            string[] hypothetical = { "would you", "could you", "should you", "imagine", "suppose", "let's say", "you've got", "you have a ", "you're given" };
            if (hypothetical.Any(m => norm.Contains(m, StringComparison.Ordinal))) return false;

            string[] present = { "you use", "you've", "you have" };
            return present.Any(m => norm.Contains(m, StringComparison.Ordinal));
        }

        public static string ResumeGroundingInstruction(string resumeText, string questionText, string topic, string recentContext = "")
        {
            var acrossRoles = AsksAcrossResumeRoles(questionText);
            var isExperience = IsExperienceCueCardQuestion(questionText, topic) || acrossRoles;
            var askedRole = acrossRoles
                ? null
                : ResumeRoleMentioned(questionText, resumeText) ??
                  (isExperience ? ResumeRoleMostRecentlyMentioned(recentContext, resumeText) : null);

            if (!isExperience && askedRole == null) return string.Empty;

            var trimmed = (resumeText ?? string.Empty).Trim();
            if (string.IsNullOrEmpty(trimmed))
            {
                return "Do not invent personal experience, jobs, or tools the candidate has not listed.\nDo not tell a first-person story about shipping this work.";
            }

            var instruction =
$@"CANDIDATE RESUME (only source of personal experience):
{trimmed}
Use ONLY this resume for personal/experience answers.
Do not invent jobs, tools, or projects that are not listed.
If the asked tool or project is not in the resume, do not tell a first-person story about using it.
Never invent numbers, percentages, dataset sizes, labels, or outcomes that the resume does not state.
Keep tools and methods true to the dates of the role being described; never put newer technology into an older job.";

            if (askedRole != null)
                instruction += "\n" + ResumeEraInstruction(askedRole, questionText);

            if (acrossRoles)
            {
                instruction += "\nACROSS ROLES: the interviewer wants the candidate's other or all companies, not one job. One bullet per relevant company from the resume with the years.";
            }

            return instruction;
        }

        public static bool AsksAcrossResumeRoles(string text)
        {
            var tokens = new HashSet<string>(WordTokens(text), StringComparer.OrdinalIgnoreCase);
            if (tokens.Contains("besides")) return true;
            string[] roleNouns = { "companies", "company", "roles", "jobs", "employers", "positions", "places" };
            string[] spanWords = { "other", "others", "another", "every", "all", "each", "besides", "else", "previous", "rest" };
            return roleNouns.Any(tokens.Contains) && spanWords.Any(tokens.Contains);
        }

        private static readonly Regex RoleRegex = new(
            @"^(.+?)\s+[-–—]\s+(.+?)\s*\((\d{4})(?:\s*[-–—]\s*(\d{4}|current|present))?[^)]*\)\s*$",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly HashSet<string> GenericEmployerWords = new(StringComparer.OrdinalIgnoreCase)
        {
            "group", "inc", "ltd", "gmbh", "corp", "company", "the", "and", "aerospace", "technologies", "systems", "solutions", "ai"
        };

        public static List<ResumeRole> ParseResumeRoles(string resumeText)
        {
            var roles = new List<ResumeRole>();
            foreach (var rawLine in ExtractResumeText(resumeText).Split('\n'))
            {
                var line = rawLine.Trim();
                var m = RoleRegex.Match(line);
                if (!m.Success || !int.TryParse(m.Groups[3].Value, out var startYear)) continue;
                int? endYear = startYear;
                if (m.Groups[4].Success)
                    endYear = int.TryParse(m.Groups[4].Value, out var ey) ? ey : null;
                var keywords = WordTokens(m.Groups[2].Value)
                    .Where(w => w.Length >= 2 && !GenericEmployerWords.Contains(w))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList();
                if (keywords.Count > 0)
                    roles.Add(new ResumeRole(line, startYear, endYear, keywords));
            }
            return roles;
        }

        public static ResumeRole? ResumeRoleMentioned(string questionText, string resumeText)
        {
            var words = new HashSet<string>(WordTokens(questionText), StringComparer.OrdinalIgnoreCase);
            return ParseResumeRoles(resumeText).FirstOrDefault(r => r.EmployerKeywords.Any(words.Contains));
        }

        public static ResumeRole? ResumeRoleMostRecentlyMentioned(string text, string resumeText)
        {
            var tokens = WordTokens(text);
            var roles = ParseResumeRoles(resumeText);
            for (int i = tokens.Count - 1; i >= 0; i--)
            {
                var role = roles.FirstOrDefault(r => r.EmployerKeywords.Contains(tokens[i], StringComparer.OrdinalIgnoreCase));
                if (role != null) return role;
            }
            return null;
        }

        public static string ResumeEraInstruction(ResumeRole role, string questionText = "")
        {
            var period = role.EndYear.HasValue ? $"{role.StartYear}-{role.EndYear.Value}" : $"{role.StartYear}-present";
            if (!role.EndYear.HasValue)
                return $"ASKED ROLE: {role.Heading}. This is a current role; modern tools are fine if the resume lists them.";

            var tokens = new HashSet<string>(WordTokens(questionText), StringComparer.OrdinalIgnoreCase);
            string[] todayWords = { "today", "now", "nowadays", "modern", "differently", "redo" };
            if (todayWords.Any(tokens.Contains))
            {
                return $"ASKED ROLE: {role.Heading} ({period}). Keep what was actually done true to {role.EndYear.Value}-era tools, then clearly label modern improvements with \"Today I would...\".";
            }

            return $"ASKED ROLE: {role.Heading}.\nERA ({period}): describe only tools, libraries, and methods that existed by {role.EndYear.Value}. Do not mention anything released after {role.EndYear.Value}.";
        }

        public static string DetectThread(string utterance)
        {
            var norm = NormalizeText(utterance);
            var bestThread = "unknown";
            var bestScore = 0;
            foreach (var (thread, keywords) in ThreadKeywords)
            {
                var score = keywords.Count(k => ContainsKeyword(norm, k));
                if (score > bestScore) { bestScore = score; bestThread = thread; }
            }
            return bestScore > 0 ? bestThread : "unknown";
        }

        public static string BuildDigest(string utterance, string thread)
        {
            var label = ThreadLabels.TryGetValue(thread, out var l) ? l : thread;
            var trimmed = (utterance ?? string.Empty).Trim();
            var snippet = trimmed.Length > 140 ? trimmed[..137] + "..." : trimmed;
            return $"{label}: {snippet}";
        }

        public static List<string> TalkingPointsFromResume(string resumeText, string thread)
        {
            var extracted = ExtractResumeText(resumeText);
            if (string.IsNullOrEmpty(extracted)) return new List<string>();
            var entry = ThreadKeywords.FirstOrDefault(t => t.Thread == thread);
            if (entry.Keywords == null) return new List<string>();

            var points = new List<string>();
            foreach (var chunk in ResumeChunks(extracted))
            {
                var norm = NormalizeText(chunk);
                if (!entry.Keywords.Any(k => ContainsKeyword(norm, k))) continue;
                if (IsNegatedChunk(norm)) continue;
                var point = CompactPoint(chunk);
                if (string.IsNullOrEmpty(point) || points.Contains(point)) continue;
                points.Add(point);
                if (points.Count == 4) break;
            }
            return points;
        }

        private static string NormalizeText(string text) =>
            Regex.Replace((text ?? string.Empty).ToLowerInvariant().Replace('\u2019', '\'').Replace('-', ' '), @"\s+", " ").Trim();

        private static bool ContainsKeyword(string haystack, string keyword)
        {
            var needle = keyword.ToLowerInvariant();
            if (needle.Contains(' ')) return haystack.Contains(needle, StringComparison.Ordinal);
            return Regex.IsMatch(haystack, $@"(^|[^a-z0-9]){Regex.Escape(needle)}($|[^a-z0-9])");
        }

        private static List<string> WordTokens(string text) =>
            Regex.Split((text ?? string.Empty).ToLowerInvariant(), @"[^\p{L}\p{N}]+")
                .Where(w => !string.IsNullOrEmpty(w))
                .ToList();

        private static List<string> ResumeChunks(string text)
        {
            var chunks = new List<string>();
            foreach (var raw in text.Split('\n'))
            {
                var line = raw.Trim();
                if (line.Length < 12) continue;
                if (line.Length > 180)
                {
                    foreach (var s in line.Split('.', StringSplitOptions.RemoveEmptyEntries))
                    {
                        var piece = s.Trim();
                        if (piece.Length >= 12) chunks.Add(piece);
                    }
                }
                else
                {
                    chunks.Add(line);
                }
            }
            return chunks;
        }

        private static bool IsNegatedChunk(string norm) =>
            norm.StartsWith("no ", StringComparison.Ordinal) ||
            norm.StartsWith("not ", StringComparison.Ordinal) ||
            norm.StartsWith("none ", StringComparison.Ordinal) ||
            norm.Contains("no experience", StringComparison.Ordinal) ||
            norm.Contains("not used", StringComparison.Ordinal) ||
            norm.Contains("haven't used", StringComparison.Ordinal) ||
            norm.Contains("have not used", StringComparison.Ordinal);

        private static string CompactPoint(string chunk)
        {
            var p = chunk.Trim();
            if (p.EndsWith('.')) p = p[..^1];
            if (p.Length > 110) p = p[..107].TrimEnd() + "...";
            return p;
        }
    }
}
