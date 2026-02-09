import Foundation

struct BuiltInTemplates {

    static let all: [InterviewTemplate] = behavioral + systemDesign + coding + languageSpecific

    // MARK: - Behavioral

    static let behavioral: [InterviewTemplate] = [
        InterviewTemplate(
            id: "behavioral-general",
            name: "General Behavioral",
            description: "Common behavioral interview questions using STAR method",
            category: .behavioral,
            questions: [
                TemplateQuestion(text: "Tell me about yourself", topic: "Introduction", difficulty: .easy, hints: [
                    "2-3 minutes max", "Present → Past → Future structure", "Tailor to the role"
                ]),
                TemplateQuestion(text: "Tell me about a time you had a conflict with a team member", topic: "Conflict Resolution", difficulty: .medium, hints: [
                    "Use STAR: Situation, Task, Action, Result", "Focus on resolution, not blame", "Show empathy and communication skills"
                ]),
                TemplateQuestion(text: "Describe a situation where you had to meet a tight deadline", topic: "Time Management", difficulty: .medium, hints: [
                    "Explain prioritization strategy", "Mention trade-offs you made", "Highlight the outcome"
                ]),
                TemplateQuestion(text: "What is your greatest technical achievement?", topic: "Achievement", difficulty: .medium, hints: [
                    "Quantify the impact", "Explain technical challenges", "Show leadership or initiative"
                ]),
                TemplateQuestion(text: "How do you handle disagreements about technical decisions?", topic: "Decision Making", difficulty: .medium, hints: [
                    "Show data-driven approach", "Mention prototyping or proof of concept", "Emphasize team alignment"
                ]),
                TemplateQuestion(text: "Tell me about a time you failed and what you learned", topic: "Growth", difficulty: .hard, hints: [
                    "Be genuine about the failure", "Focus on lessons learned", "Show how you applied those lessons"
                ])
            ]
        )
    ]

    // MARK: - System Design

    static let systemDesign: [InterviewTemplate] = [
        InterviewTemplate(
            id: "sysdesign-url-shortener",
            name: "URL Shortener",
            description: "Design a URL shortening service like bit.ly",
            category: .systemDesign,
            questions: [
                TemplateQuestion(text: "Design a URL shortener like bit.ly", topic: "System Design", difficulty: .medium, hints: [
                    "Step 1: Clarify requirements (read vs write ratio, scale, analytics)",
                    "Step 2: API design (POST /shorten, GET /:code)",
                    "Step 3: Encoding strategy (base62, hash, counter)",
                    "Step 4: Storage (NoSQL for key-value, cache layer)",
                    "Step 5: Scale (horizontal scaling, CDN, rate limiting)"
                ])
            ]
        ),
        InterviewTemplate(
            id: "sysdesign-chat",
            name: "Chat System",
            description: "Design a real-time chat application like Slack",
            category: .systemDesign,
            questions: [
                TemplateQuestion(text: "Design a real-time chat system like Slack", topic: "System Design", difficulty: .hard, hints: [
                    "Step 1: Requirements (1:1, group chat, channels, presence)",
                    "Step 2: Protocol choice (WebSocket for real-time, HTTP fallback)",
                    "Step 3: Message storage (partitioned by channel/time)",
                    "Step 4: Delivery guarantees (at-least-once, idempotency)",
                    "Step 5: Scale (connection servers, message queue, read replicas)"
                ])
            ]
        ),
        InterviewTemplate(
            id: "sysdesign-twitter",
            name: "Twitter/X Feed",
            description: "Design a social media feed like Twitter",
            category: .systemDesign,
            questions: [
                TemplateQuestion(text: "Design a Twitter-like social media feed", topic: "System Design", difficulty: .hard, hints: [
                    "Step 1: Requirements (post, follow, timeline, search)",
                    "Step 2: Fan-out approaches (push vs pull vs hybrid)",
                    "Step 3: Timeline generation and caching",
                    "Step 4: Storage (posts, social graph, media)",
                    "Step 5: Scale (celebrity problem, sharding, CDN)"
                ])
            ]
        )
    ]

    // MARK: - Coding

    static let coding: [InterviewTemplate] = [
        InterviewTemplate(
            id: "coding-arrays-strings",
            name: "Arrays & Strings",
            description: "Common array and string manipulation problems",
            category: .coding,
            questions: [
                TemplateQuestion(text: "Two Sum: Find indices of two numbers that add up to target", topic: "Arrays", difficulty: .easy, hints: [
                    "Hash map for O(n) solution", "Store complement as key"
                ]),
                TemplateQuestion(text: "Longest Substring Without Repeating Characters", topic: "Strings", difficulty: .medium, hints: [
                    "Sliding window technique", "Hash set to track characters"
                ]),
                TemplateQuestion(text: "Merge Intervals: Merge overlapping intervals", topic: "Arrays", difficulty: .medium, hints: [
                    "Sort by start time", "Compare current end with next start"
                ]),
                TemplateQuestion(text: "Trapping Rain Water", topic: "Arrays", difficulty: .hard, hints: [
                    "Two pointer approach", "Track max left and max right"
                ])
            ]
        ),
        InterviewTemplate(
            id: "coding-trees-graphs",
            name: "Trees & Graphs",
            description: "Tree traversal, graph search, and related problems",
            category: .coding,
            questions: [
                TemplateQuestion(text: "Validate Binary Search Tree", topic: "Trees", difficulty: .medium, hints: [
                    "In-order traversal should be sorted", "Pass min/max bounds recursively"
                ]),
                TemplateQuestion(text: "Lowest Common Ancestor of a Binary Tree", topic: "Trees", difficulty: .medium, hints: [
                    "Post-order traversal", "If both sides return non-null, current node is LCA"
                ]),
                TemplateQuestion(text: "Number of Islands (grid BFS/DFS)", topic: "Graphs", difficulty: .medium, hints: [
                    "BFS or DFS from each unvisited land cell", "Mark visited cells"
                ]),
                TemplateQuestion(text: "Course Schedule (topological sort)", topic: "Graphs", difficulty: .medium, hints: [
                    "Build adjacency list", "Detect cycle with DFS or use Kahn's algorithm"
                ])
            ]
        ),
        InterviewTemplate(
            id: "coding-dp",
            name: "Dynamic Programming",
            description: "Classic DP problems from easy to hard",
            category: .coding,
            questions: [
                TemplateQuestion(text: "Climbing Stairs: How many ways to reach the top?", topic: "DP", difficulty: .easy, hints: [
                    "Similar to Fibonacci", "dp[i] = dp[i-1] + dp[i-2]"
                ]),
                TemplateQuestion(text: "Longest Common Subsequence", topic: "DP", difficulty: .medium, hints: [
                    "2D DP table", "If chars match: dp[i][j] = dp[i-1][j-1] + 1"
                ]),
                TemplateQuestion(text: "Coin Change: Minimum coins to make amount", topic: "DP", difficulty: .medium, hints: [
                    "Bottom-up DP", "dp[amount] = min(dp[amount], dp[amount - coin] + 1)"
                ]),
                TemplateQuestion(text: "Edit Distance between two strings", topic: "DP", difficulty: .hard, hints: [
                    "2D DP: insert, delete, replace operations", "dp[i][j] = min of three options"
                ])
            ]
        )
    ]

    // MARK: - Language-Specific

    static let languageSpecific: [InterviewTemplate] = [
        InterviewTemplate(
            id: "lang-python",
            name: "Python Deep Dive",
            description: "Python-specific interview questions",
            category: .languageSpecific,
            questions: [
                TemplateQuestion(text: "Explain the GIL (Global Interpreter Lock) in Python", topic: "Python Internals", difficulty: .medium, hints: [
                    "Mutex that protects access to Python objects", "Prevents true multithreading for CPU-bound tasks", "Use multiprocessing or asyncio instead"
                ]),
                TemplateQuestion(text: "What are Python decorators and how do they work?", topic: "Python", difficulty: .medium, hints: [
                    "Functions that modify other functions", "Use @syntax sugar", "Common: @property, @staticmethod, @cache"
                ]),
                TemplateQuestion(text: "Explain list comprehension vs generator expression", topic: "Python", difficulty: .easy, hints: [
                    "List: [x for x in range(10)] - creates full list in memory", "Generator: (x for x in range(10)) - lazy evaluation"
                ])
            ]
        ),
        InterviewTemplate(
            id: "lang-javascript",
            name: "JavaScript/TypeScript",
            description: "JS/TS specific interview questions",
            category: .languageSpecific,
            questions: [
                TemplateQuestion(text: "Explain the event loop in JavaScript", topic: "JS Runtime", difficulty: .medium, hints: [
                    "Call stack → Microtask queue → Macrotask queue", "Promises go to microtask queue", "setTimeout goes to macrotask queue"
                ]),
                TemplateQuestion(text: "What is closure and why is it useful?", topic: "JavaScript", difficulty: .medium, hints: [
                    "Function that captures variables from outer scope", "Used for data privacy, factories, callbacks"
                ]),
                TemplateQuestion(text: "Explain Promise.all vs Promise.allSettled vs Promise.race", topic: "JavaScript", difficulty: .medium, hints: [
                    "all: fails fast on first rejection", "allSettled: waits for all, returns status", "race: resolves/rejects with first settled"
                ])
            ]
        ),
        InterviewTemplate(
            id: "lang-java",
            name: "Java Core",
            description: "Core Java interview questions",
            category: .languageSpecific,
            questions: [
                TemplateQuestion(text: "Explain the difference between HashMap and ConcurrentHashMap", topic: "Java Collections", difficulty: .medium, hints: [
                    "HashMap: not thread-safe, allows null key", "ConcurrentHashMap: segment-level locking, no null keys"
                ]),
                TemplateQuestion(text: "What is the Java Memory Model? Explain heap vs stack", topic: "JVM", difficulty: .medium, hints: [
                    "Stack: method frames, local variables, thread-local", "Heap: objects, shared across threads, GC managed"
                ]),
                TemplateQuestion(text: "Explain Spring dependency injection and IoC", topic: "Spring", difficulty: .medium, hints: [
                    "IoC: framework controls object lifecycle", "DI: objects receive dependencies, don't create them", "@Autowired, @Component, @Service"
                ])
            ]
        )
    ]

    static func templatesForCategory(_ category: InterviewTemplate.Category) -> [InterviewTemplate] {
        return all.filter { $0.category == category }
    }
}
