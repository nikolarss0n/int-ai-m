using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace InterviewMasterApp.Tests
{
    /// <summary>
    /// Classification API test suite.
    /// Ported from Swift: test_classification.swift
    /// Tests LLM-based utterance classification (question, incomplete, answer, filler) and topic detection.
    ///
    /// Usage:
    ///   Set GROQ_API_KEY environment variable
    ///   OR create ~/.interview-master-keys file with: GROQ_API_KEY=your_key
    ///
    /// Run: dotnet run --project Tests/ClassificationTests.cs
    /// </summary>
    public class ClassificationTests
    {
        // Test cases: (input, expectedStatus, expectedTopic, description)
        // Note: for incomplete/filler/answer, topic can be "none", "unknown", or actual topic - we accept any
        private static readonly List<(string Input, string ExpectedStatus, string ExpectedTopic, string Description)> TestCases = new()
        {
            // Basic questions - should detect specific topics
            ("What is the difference between array and arraylist?", "question", "array", "Array vs ArrayList comparison"),
            ("What is ArrayList?", "question", "arraylist", "ArrayList definition"),
            ("What is a LinkedList?", "question", "linkedlist", "LinkedList definition"),
            ("What is HashMap?", "question", "hashmap", "HashMap definition"),
            ("How does garbage collection work?", "question", "garbagecollection", "GC question"),
            ("What is the difference between JDK and JVM?", "question", "jdk|jvm", "JDK vs JVM"),

            // Linux questions
            ("How do I list processes in Linux?", "question", "linux", "Linux processes"),
            ("What is the ps command?", "question", "linux", "ps command"),
            ("How do I find a file in Linux?", "question", "linux|bash", "Linux find"),

            // Topic switching - should NOT stick to previous topic
            ("What is polymorphism?", "question", "polymorphism", "OOP concept"),
            ("What is a closure in JavaScript?", "question", "closure", "JS closure"),
            ("Explain the event loop", "question", "eventloop", "JS event loop"),

            // Incomplete sentences - should detect incomplete
            ("What is the", "incomplete", "*", "Cut off mid-sentence"),
            ("Can you explain", "incomplete", "*", "Missing object"),
            ("Tell me about", "incomplete", "*", "Incomplete request"),

            // Fillers - should detect filler
            ("Hmm", "filler", "*", "Thinking sound"),
            ("Um", "filler", "*", "Filler word"),
            ("Okay", "filler", "*", "Acknowledgment"),

            // User answering - should detect answer (topic optional)
            ("Well I think HashMap uses hashing to store key value pairs in buckets and when there is a collision it uses linked list or tree structure to handle it", "answer", "*", "User explaining HashMap"),
            ("So basically polymorphism means that the same method can behave differently based on the object that calls it and there are two types compile time and runtime polymorphism", "answer", "*", "User explaining polymorphism"),

            // Follow-ups - should detect followUp when vague
            ("Tell me more", "question", "followup", "Vague follow-up"),
            ("Can you elaborate?", "question", "followup", "Elaborate request"),
            ("What else?", "question", "followup", "What else"),

            // Edge cases - questions that look like statements
            ("The four pillars of OOP", "question", "oop", "Statement as question"),
            ("Singleton pattern", "question", "singleton", "Topic mention"),
            ("HashMap vs HashSet", "question", "hashmap|hashset", "Comparison without question mark"),

            // Multi-language hints (should still work)
            ("What is dependency injection?", "question", "dependencyinjection", "DI question"),
            ("Explain SOLID principles", "question", "solid", "SOLID question"),
            ("What is Docker?", "question", "docker", "Docker question"),

            // Tricky cases
            ("Okay, now tell me about threads", "question", "threads", "Acknowledgment + new topic"),
            ("Right, what about deadlock?", "question", "deadlock", "Agreement + new topic"),
        };

        private static readonly HttpClient HttpClient = new();

        static async Task Main(string[] args)
        {
            await RunTests();
        }

        /// <summary>
        /// Classify utterance using Groq API.
        /// </summary>
        private static async Task<(string Status, string Topic)> ClassifyUtteranceAsync(string text, string? lastTopic = null)
        {
            // Try environment variable first, then ~/.interview-master-keys
            var apiKey = Environment.GetEnvironmentVariable("GROQ_API_KEY") ?? "";

            if (string.IsNullOrEmpty(apiKey))
            {
                // Try reading from ~/.interview-master-keys (same as main app)
                var keysPath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                    ".interview-master-keys");

                if (File.Exists(keysPath))
                {
                    var contents = await File.ReadAllTextAsync(keysPath);
                    foreach (var line in contents.Split('\n'))
                    {
                        var trimmed = line.Trim();
                        if (trimmed.StartsWith("GROQ_API_KEY="))
                        {
                            apiKey = trimmed.Substring("GROQ_API_KEY=".Length);
                            break;
                        }
                    }
                }
            }

            if (string.IsNullOrEmpty(apiKey))
            {
                throw new Exception("GROQ_API_KEY not found. Set it in ~/.interview-master-keys as GROQ_API_KEY=your_key");
            }

            var lastTopicNote = lastTopic != null ? $"Last topic: {lastTopic}" : "";

            var prompt = $@"Classify this utterance. Return: STATUS,TOPIC

Text: ""{text}""
{lastTopicNote}

STATUS (pick one):
- question = asking about something OR mentioning a topic (wants info)
- incomplete = cut off mid-sentence (""What is the"", ""Can you"")
- answer = user explaining (20+ words, detailed explanation)
- filler = ONLY ""um"", ""okay"", ""hmm"", ""right"" (1-2 meaningless words)

IMPORTANT: Short topic mentions like ""polymorphism"", ""singleton pattern"", ""the four pillars"" = question (user wants info)

TOPIC - return the SPECIFIC topic name, not the category:
array, arrayList, linkedList, hashMap, hashSet, treeMap, queue, collections
threads, process, synchronized, volatile, deadlock, locks
jvm, jdk, jre, garbageCollection, heap, stack
oop, inheritance, polymorphism, encapsulation, abstraction, abstractClass, interface
lambda, streamApi, optional, functionalInterface
exceptions, checkedExceptions, uncheckedExceptions
closure, hoisting, eventLoop, promises, asyncAwait, this, scope
reactHooks, useState, useEffect, useContext, virtualDOM, redux
typescript, generics, interfaces, types
bigO, sorting, binarySearch, recursion, dynamicProgramming, bfs, dfs
systemDesign, caching, redis, loadBalancing, database, sql, nosql, microservices, rest
singleton, factory, builder, observer, strategy, dependencyInjection, solid
testing, unitTest, tdd, mocking
docker, kubernetes, ci, cd, git, aws
linux, bash, ssh, networking
background, experience, tellMeAboutYourself, projects
followUp (for ""tell me more"" with no new topic)
unknown (if no match)

IMPORTANT MAPPINGS:
- ""array vs arraylist"", ""difference array arraylist"", ""list vs arraylist"" → array
- ""ArrayList"" alone → arrayList
- ""LinkedList"" → linkedList
- ""hash map"", ""hashmap"" → hashMap
- ""garbage collection"" → garbageCollection
- ""list processes"", ""find processes"", ""ps command"" → linux
- ""tell me about yourself"" → tellMeAboutYourself

EXAMPLES:
""What is the difference between array and arraylist?"" → question,array
""What is ArrayList?"" → question,arrayList
""How do I list processes in Linux?"" → question,linux
""What is the"" → incomplete,none
""Hmm"" → filler,none
""Tell me more"" → question,followUp

Return ONLY: STATUS,TOPIC (e.g., ""question,array"")
";

            var requestBody = new
            {
                model = "llama-3.3-70b-versatile",
                messages = new[] { new { role = "user", content = prompt } },
                max_tokens = 20,
                temperature = 0
            };

            var request = new HttpRequestMessage(HttpMethod.Post, "https://api.groq.com/openai/v1/chat/completions");
            request.Headers.Add("Authorization", $"Bearer {apiKey}");
            request.Content = new StringContent(
                JsonSerializer.Serialize(requestBody),
                Encoding.UTF8,
                "application/json");

            var response = await HttpClient.SendAsync(request);

            // Check for rate limiting
            if ((int)response.StatusCode == 429)
            {
                // Wait and retry once
                await Task.Delay(2000); // 2 seconds
                response = await HttpClient.SendAsync(request);
            }

            var responseJson = await response.Content.ReadAsStringAsync();
            return ParseResponse(responseJson);
        }

        /// <summary>
        /// Parse Groq API response.
        /// </summary>
        private static (string Status, string Topic) ParseResponse(string json)
        {
            var response = JsonSerializer.Deserialize<ChatResponse>(json);

            // Check for error
            if (response?.Error != null)
            {
                throw new Exception(response.Error.Message);
            }

            var raw = response?.Choices?.FirstOrDefault()?.Message?.Content?.Trim().ToLowerInvariant() ?? "question,unknown";

            // Handle different separators: "status,topic" or "status:topic" or "status, topic"
            var cleaned = raw.Replace(":", ",").Replace(" ", "");
            var parts = cleaned.Split(',');
            var status = parts.FirstOrDefault() ?? "question";
            var topic = parts.Length > 1 ? parts[1] : "unknown";

            return (status, topic == "none" ? "none" : topic);
        }

        /// <summary>
        /// Run all classification tests.
        /// </summary>
        private static async Task RunTests()
        {
            Console.WriteLine("🧪 Testing Classification API\n");
            Console.WriteLine(new string('=', 100));

            var passed = 0;
            var failed = 0;
            var results = new List<(string Description, bool Success, string Detail)>();

            foreach (var (input, expectedStatus, expectedTopic, description) in TestCases)
            {
                try
                {
                    var (status, topic) = await ClassifyUtteranceAsync(input, null);

                    var statusMatch = status == expectedStatus;

                    // Handle wildcard "*" for topic (accept anything)
                    // Handle "a|b" for multiple acceptable topics
                    bool topicMatch;
                    if (expectedTopic == "*")
                    {
                        topicMatch = true;
                    }
                    else if (expectedTopic.Contains("|"))
                    {
                        var acceptableTopics = expectedTopic.Split('|');
                        topicMatch = acceptableTopics.Contains(topic);
                    }
                    else
                    {
                        topicMatch = topic == expectedTopic;
                    }

                    var success = statusMatch && topicMatch;

                    if (success)
                    {
                        passed++;
                        results.Add((description, true, ""));
                    }
                    else
                    {
                        failed++;
                        var detail = $"Expected: {expectedStatus},{expectedTopic} | Got: {status},{topic}";
                        results.Add((description, false, detail));
                    }

                    // Rate limiting - 500ms between requests to avoid Groq limits
                    await Task.Delay(500);
                }
                catch (Exception ex)
                {
                    failed++;
                    results.Add((description, false, $"Error: {ex.Message}"));
                }
            }

            // Print results
            Console.WriteLine("\n📊 RESULTS\n");

            foreach (var (desc, success, detail) in results)
            {
                var icon = success ? "✅" : "❌";
                Console.WriteLine($"{icon} {desc}");
                if (!string.IsNullOrEmpty(detail))
                {
                    Console.WriteLine($"   └─ {detail}");
                }
            }

            Console.WriteLine("\n" + new string('=', 100));
            var percentage = (int)(passed / (double)TestCases.Count * 100);
            Console.WriteLine($"📈 Summary: {passed}/{TestCases.Count} passed ({percentage}%)");

            if (failed > 0)
            {
                Console.WriteLine($"❌ {failed} tests failed");
            }
            else
            {
                Console.WriteLine("🎉 All tests passed!");
            }
        }

        // JSON response models
        private class ChatResponse
        {
            public Choice[]? Choices { get; set; }
            public ErrorResponse? Error { get; set; }

            public class Choice
            {
                public Message? Message { get; set; }
            }

            public class Message
            {
                public string? Content { get; set; }
            }

            public class ErrorResponse
            {
                public string Message { get; set; } = "";
            }
        }
    }
}

