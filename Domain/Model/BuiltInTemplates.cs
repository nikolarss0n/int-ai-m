using System;
using System.Collections.Generic;
using System.Linq;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Built-in interview templates migrated from Swift: BuiltInTemplates.swift
    /// Provides ready-made templates grouped by category.
    /// </summary>
    public static class BuiltInTemplates
    {
        public static readonly List<InterviewTemplate> Behavioral = new()
        {
            new InterviewTemplate
            {
                Id = "behavioral-general",
                Name = "General Behavioral",
                Description = "Common behavioral interview questions using STAR method",
                TemplateCategory = InterviewTemplate.Category.Behavioral,
                Questions = new List<TemplateQuestion>
                {
                    new TemplateQuestion("Tell me about yourself", "Introduction", TemplateQuestion.Difficulty.Easy, new List<string>
                    {
                        "2-3 minutes max",
                        "Present → Past → Future structure",
                        "Tailor to the role"
                    }),
                    new TemplateQuestion("Tell me about a time you had a conflict with a team member", "Conflict Resolution", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Use STAR: Situation, Task, Action, Result",
                        "Focus on resolution, not blame",
                        "Show empathy and communication skills"
                    }),
                    new TemplateQuestion("Describe a situation where you had to meet a tight deadline", "Time Management", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Explain prioritization strategy",
                        "Mention trade-offs you made",
                        "Highlight the outcome"
                    }),
                    new TemplateQuestion("What is your greatest technical achievement?", "Achievement", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Quantify the impact",
                        "Explain technical challenges",
                        "Show leadership or initiative"
                    }),
                    new TemplateQuestion("How do you handle disagreements about technical decisions?", "Decision Making", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Show data-driven approach",
                        "Mention prototyping or proof of concept",
                        "Emphasize team alignment"
                    }),
                    new TemplateQuestion("Tell me about a time you failed and what you learned", "Growth", TemplateQuestion.Difficulty.Hard, new List<string>
                    {
                        "Be genuine about the failure",
                        "Focus on lessons learned",
                        "Show how you applied those lessons"
                    })
                }
            }
        };

        public static readonly List<InterviewTemplate> SystemDesign = new()
        {
            new InterviewTemplate
            {
                Id = "sysdesign-url-shortener",
                Name = "URL Shortener",
                Description = "Design a URL shortening service like bit.ly",
                TemplateCategory = InterviewTemplate.Category.SystemDesign,
                Questions = new List<TemplateQuestion>
                {
                    new TemplateQuestion("Design a URL shortener like bit.ly", "System Design", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Step 1: Clarify requirements (read vs write ratio, scale, analytics)",
                        "Step 2: API design (POST /shorten, GET /:code)",
                        "Step 3: Encoding strategy (base62, hash, counter)",
                        "Step 4: Storage (NoSQL for key-value, cache layer)",
                        "Step 5: Scale (horizontal scaling, CDN, rate limiting)"
                    })
                }
            },
            new InterviewTemplate
            {
                Id = "sysdesign-chat",
                Name = "Chat System",
                Description = "Design a real-time chat application like Slack",
                TemplateCategory = InterviewTemplate.Category.SystemDesign,
                Questions = new List<TemplateQuestion>
                {
                    new TemplateQuestion("Design a real-time chat system like Slack", "System Design", TemplateQuestion.Difficulty.Hard, new List<string>
                    {
                        "Step 1: Requirements (1:1, group chat, channels, presence)",
                        "Step 2: Protocol choice (WebSocket for real-time, HTTP fallback)",
                        "Step 3: Message storage (partitioned by channel/time)",
                        "Step 4: Delivery guarantees (at-least-once, idempotency)",
                        "Step 5: Scale (connection servers, message queue, read replicas)"
                    })
                }
            },
            new InterviewTemplate
            {
                Id = "sysdesign-twitter",
                Name = "Twitter/X Feed",
                Description = "Design a social media feed like Twitter",
                TemplateCategory = InterviewTemplate.Category.SystemDesign,
                Questions = new List<TemplateQuestion>
                {
                    new TemplateQuestion("Design a Twitter-like social media feed", "System Design", TemplateQuestion.Difficulty.Hard, new List<string>
                    {
                        "Step 1: Requirements (post, follow, timeline, search)",
                        "Step 2: Fan-out approaches (push vs pull vs hybrid)",
                        "Step 3: Timeline generation and caching",
                        "Step 4: Storage (posts, social graph, media)",
                        "Step 5: Scale (celebrity problem, sharding, CDN)"
                    })
                }
            }
        };

        public static readonly List<InterviewTemplate> Coding = new()
        {
            new InterviewTemplate
            {
                Id = "coding-arrays-strings",
                Name = "Arrays & Strings",
                Description = "Common array and string manipulation problems",
                TemplateCategory = InterviewTemplate.Category.Coding,
                Questions = new List<TemplateQuestion>
                {
                    new TemplateQuestion("Two Sum: Find indices of two numbers that add up to target", "Arrays", TemplateQuestion.Difficulty.Easy, new List<string>
                    {
                        "Hash map for O(n) solution",
                        "Store complement as key"
                    }),
                    new TemplateQuestion("Longest Substring Without Repeating Characters", "Strings", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Sliding window technique",
                        "Hash set to track characters"
                    }),
                    new TemplateQuestion("Merge Intervals: Merge overlapping intervals", "Arrays", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Sort by start time",
                        "Compare current end with next start"
                    }),
                    new TemplateQuestion("Trapping Rain Water", "Arrays", TemplateQuestion.Difficulty.Hard, new List<string>
                    {
                        "Two pointer approach",
                        "Track max left and max right"
                    })
                }
            },
            new InterviewTemplate
            {
                Id = "coding-trees-graphs",
                Name = "Trees & Graphs",
                Description = "Tree traversal, graph search, and related problems",
                TemplateCategory = InterviewTemplate.Category.Coding,
                Questions = new List<TemplateQuestion>
                {
                    new TemplateQuestion("Validate Binary Search Tree", "Trees", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "In-order traversal should be sorted",
                        "Pass min/max bounds recursively"
                    }),
                    new TemplateQuestion("Lowest Common Ancestor of a Binary Tree", "Trees", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Post-order traversal",
                        "If both sides return non-null, current node is LCA"
                    }),
                    new TemplateQuestion("Number of Islands (grid BFS/DFS)", "Graphs", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "BFS or DFS from each unvisited land cell",
                        "Mark visited cells"
                    }),
                    new TemplateQuestion("Course Schedule (topological sort)", "Graphs", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Build adjacency list",
                        "Detect cycle with DFS or use Kahn's algorithm"
                    })
                }
            },
            new InterviewTemplate
            {
                Id = "coding-dp",
                Name = "Dynamic Programming",
                Description = "Classic DP problems from easy to hard",
                TemplateCategory = InterviewTemplate.Category.Coding,
                Questions = new List<TemplateQuestion>
                {
                    new TemplateQuestion("Climbing Stairs: How many ways to reach the top?", "DP", TemplateQuestion.Difficulty.Easy, new List<string>
                    {
                        "Similar to Fibonacci",
                        "dp[i] = dp[i-1] + dp[i-2]"
                    }),
                    new TemplateQuestion("Longest Common Subsequence", "DP", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "2D DP table",
                        "If chars match: dp[i][j] = dp[i-1][j-1] + 1"
                    }),
                    new TemplateQuestion("Coin Change: Minimum coins to make amount", "DP", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Bottom-up DP",
                        "dp[amount] = min(dp[amount], dp[amount - coin] + 1)"
                    }),
                    new TemplateQuestion("Edit Distance between two strings", "DP", TemplateQuestion.Difficulty.Hard, new List<string>
                    {
                        "2D DP: insert, delete, replace operations",
                        "dp[i][j] = min of three options"
                    })
                }
            }
        };

        public static readonly List<InterviewTemplate> LanguageSpecific = new()
        {
            new InterviewTemplate
            {
                Id = "lang-python",
                Name = "Python Deep Dive",
                Description = "Python-specific interview questions",
                TemplateCategory = InterviewTemplate.Category.LanguageSpecific,
                Questions = new List<TemplateQuestion>
                {
                    new TemplateQuestion("Explain the GIL (Global Interpreter Lock) in Python", "Python Internals", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Mutex that protects access to Python objects",
                        "Prevents true multithreading for CPU-bound tasks",
                        "Use multiprocessing or asyncio instead"
                    }),
                    new TemplateQuestion("What are Python decorators and how do they work?", "Python", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Functions that modify other functions",
                        "Use @syntax sugar",
                        "Common: @property, @staticmethod, @cache"
                    }),
                    new TemplateQuestion("Explain list comprehension vs generator expression", "Python", TemplateQuestion.Difficulty.Easy, new List<string>
                    {
                        "List: [x for x in range(10)] - creates full list in memory",
                        "Generator: (x for x in range(10)) - lazy evaluation"
                    })
                }
            },
            new InterviewTemplate
            {
                Id = "lang-javascript",
                Name = "JavaScript/TypeScript",
                Description = "JS/TS specific interview questions",
                TemplateCategory = InterviewTemplate.Category.LanguageSpecific,
                Questions = new List<TemplateQuestion>
                {
                    new TemplateQuestion("Explain the event loop in JavaScript", "JS Runtime", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Call stack → Microtask queue → Macrotask queue",
                        "Promises go to microtask queue",
                        "setTimeout goes to macrotask queue"
                    }),
                    new TemplateQuestion("What is closure and why is it useful?", "JavaScript", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Function that captures variables from outer scope",
                        "Used for data privacy, factories, callbacks"
                    }),
                    new TemplateQuestion("Explain Promise.all vs Promise.allSettled vs Promise.race", "JavaScript", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "all: fails fast on first rejection",
                        "allSettled: waits for all, returns status",
                        "race: resolves/rejects with first settled"
                    })
                }
            },
            new InterviewTemplate
            {
                Id = "lang-java",
                Name = "Java Core",
                Description = "Core Java interview questions",
                TemplateCategory = InterviewTemplate.Category.LanguageSpecific,
                Questions = new List<TemplateQuestion>
                {
                    new TemplateQuestion("Explain the difference between HashMap and ConcurrentHashMap", "Java Collections", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "HashMap: not thread-safe, allows null key",
                        "ConcurrentHashMap: segment-level locking, no null keys"
                    }),
                    new TemplateQuestion("What is the Java Memory Model? Explain heap vs stack", "JVM", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "Stack: method frames, local variables, thread-local",
                        "Heap: objects, shared across threads, GC managed"
                    }),
                    new TemplateQuestion("Explain Spring dependency injection and IoC", "Spring", TemplateQuestion.Difficulty.Medium, new List<string>
                    {
                        "IoC: framework controls object lifecycle",
                        "DI: objects receive dependencies, don't create them",
                        "@Autowired, @Component, @Service"
                    })
                }
            }
        };

        public static readonly List<InterviewTemplate> All = Behavioral
            .Concat(SystemDesign)
            .Concat(Coding)
            .Concat(LanguageSpecific)
            .ToList();

        public static List<InterviewTemplate> TemplatesForCategory(InterviewTemplate.Category category)
        {
            return All.Where(t => t.TemplateCategory == category).ToList();
        }
    }
}

