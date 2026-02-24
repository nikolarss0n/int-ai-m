using System;
using System.Collections.Generic;
using System.Linq;

namespace InterviewMasterApp.Infrastructure.Speech
{
    public class KeywordMatcher
    {
        public class Match
        {
            public string Keyword { get; set; }
            public InterviewTopic Topic { get; set; }
            public double Confidence { get; set; }
        }

        public Match FindMatch(string text)
        {
            var normalized = (text ?? string.Empty).ToLowerInvariant();
            var words = new HashSet<string>(normalized.Split(new[] { ' ', '\n', '\r', '\t' }, StringSplitOptions.RemoveEmptyEntries));

            Match best = null;
            double bestScore = 0;

            foreach (var topic in InterviewTopicValues.All)
            {
                foreach (var keyword in topic.Keywords)
                {
                    var score = CalculateMatchScore(keyword, normalized, words);
                    if (score > bestScore && score >= 0.5)
                    {
                        bestScore = score;
                        best = new Match { Keyword = keyword, Topic = topic.Topic, Confidence = score };
                    }
                }
            }

            return best;
        }

        public List<Match> FindAllMatches(string text, double minConfidence = 0.5)
        {
            var normalized = (text ?? string.Empty).ToLowerInvariant();
            var words = new HashSet<string>(normalized.Split(new[] { ' ', '\n', '\r', '\t' }, StringSplitOptions.RemoveEmptyEntries));
            var matches = new List<Match>();
            var seen = new HashSet<InterviewTopic>();

            foreach (var topic in InterviewTopicValues.All)
            {
                foreach (var keyword in topic.Keywords)
                {
                    var score = CalculateMatchScore(keyword, normalized, words);
                    if (score >= minConfidence && !seen.Contains(topic.Topic))
                    {
                        matches.Add(new Match { Keyword = keyword, Topic = topic.Topic, Confidence = score });
                        seen.Add(topic.Topic);
                    }
                }
            }

            return matches.OrderByDescending(m => m.Confidence).ToList();
        }

        private double CalculateMatchScore(string keyword, string text, HashSet<string> words)
        {
            var k = keyword.ToLowerInvariant();
            if (text.Contains(k)) return 1.0;

            var keywordWords = k.Split(' ');
            if (keywordWords.Length > 1)
            {
                var matched = keywordWords.Count(w => words.Contains(w));
                var ratio = (double)matched / keywordWords.Length;
                if (ratio >= 0.5) return ratio * 0.8;
            }

            if (words.Contains(k)) return 0.9;

            foreach (var w in words)
            {
                if (LevenshteinDistance(w, k) <= 2 && k.Length > 4) return 0.6;
            }

            return 0.0;
        }

        private int LevenshteinDistance(string s1, string s2)
        {
            var n = s1.Length;
            var m = s2.Length;
            var d = new int[n + 1, m + 1];
            for (int i = 0; i <= n; i++) d[i, 0] = i;
            for (int j = 0; j <= m; j++) d[0, j] = j;
            for (int i = 1; i <= n; i++)
            {
                for (int j = 1; j <= m; j++)
                {
                    int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
                    d[i, j] = Math.Min(Math.Min(d[i - 1, j] + 1, d[i, j - 1] + 1), d[i - 1, j - 1] + cost);
                }
            }
            return d[n, m];
        }
    }

    // Small helper to hold topic data (mirrors InterviewTopic enum in Swift)
    public enum InterviewTopic
    {
        Closure, Hoisting, EventLoop, Promises, AsyncAwait, Prototypes, ThisKeyword,
        ReactHooks, UseState, UseEffect, VirtualDOM, ReactLifecycle,
        TypeScript, Generics, Interfaces,
        Arrays, LinkedList, HashMap, Trees, Graphs, Stack, Queue,
        BigO, Sorting, Searching, Recursion, DynamicProgramming,
        SystemDesign, Scalability, Caching, LoadBalancing, Database, Microservices, API,
        SOLID, DesignPatterns, Testing
    }

    public class InterviewTopicRecord
    {
        public InterviewTopic Topic { get; set; }
        public List<string> Keywords { get; set; }
        public string DisplayName { get; set; }
        public string QuickSummary { get; set; }
    }

    public static class InterviewTopicValues
    {
        public static List<InterviewTopicRecord> All { get; } = CreateAll();

        private static List<InterviewTopicRecord> CreateAll()
        {
            var list = new List<InterviewTopicRecord>();
            list.Add(new InterviewTopicRecord { Topic = InterviewTopic.Closure, Keywords = new List<string>{"closure","closures","lexical scope"}, DisplayName = "Closures", QuickSummary = "A closure captures variables from its outer scope." });
            // ... add more mappings as needed (abbreviated for brevity)
            list.Add(new InterviewTopicRecord { Topic = InterviewTopic.HashMap, Keywords = new List<string>{"hash map","hashmap","hash table","dictionary"}, DisplayName = "Hash Maps", QuickSummary = "Key-value associative data structure." });
            return list;
        }
    }
}
