using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace InterviewMasterApp.Domain.Model
{
    public sealed record CodingInterviewStep(int Number, string FileName, string Why, string Language, string Code);

    public sealed record CodingStepProgress(List<CodingInterviewStep> Steps, bool LastStepIsOpen);

    public sealed record CodingResponse(List<string> SayBullets, string StepsMarkdown);

    public sealed record CodingTaskInfo(Guid TurnId, string Request, bool IsRefinement, bool AllowsChanges);

    public sealed record CodingTaskOutcome(bool IsComplete, string? IncompleteReason = null)
    {
        public static CodingTaskOutcome Complete() => new(true, null);
        public static CodingTaskOutcome Incomplete(string reason) => new(false, reason);
    }

    public enum CodeQuickAction
    {
        AnotherWay,
        Optimize,
        AddTests,
        OtherLanguage
    }

    public static class CodeQuickActionExtensions
    {
        public static string OtherLanguage(string? current) => current switch
        {
            "Python" => "TypeScript",
            "TypeScript" => "Python",
            "JavaScript" => "TypeScript",
            "Java" => "Python",
            "Kotlin" => "Java",
            "C#" => "Java",
            null => "TypeScript",
            _ => "Python"
        };

        public static string GetTitle(this CodeQuickAction action, string? currentLanguage) => action switch
        {
            CodeQuickAction.AnotherWay => "Try another way",
            CodeQuickAction.Optimize => "Optimize",
            CodeQuickAction.AddTests => "Add tests",
            CodeQuickAction.OtherLanguage => $"Use {OtherLanguage(currentLanguage)}",
            _ => action.ToString()
        };

        public static string GetInstruction(this CodeQuickAction action, string? currentLanguage) => action switch
        {
            CodeQuickAction.AnotherWay => "Show me another way to do it",
            CodeQuickAction.Optimize => "Optimize it",
            CodeQuickAction.AddTests => "Add tests for it",
            CodeQuickAction.OtherLanguage => $"Write it in {OtherLanguage(currentLanguage)}",
            _ => string.Empty
        };
    }

    public enum CodingFollowUpKind
    {
        Change,
        Example
    }

    public enum CodingTurnDecisionKind
    {
        ArmSession,
        NeedsScreenContext,
        NewTask,
        RefineTask,
        ChangeCode
    }

    public sealed record CodingTurnDecision(CodingTurnDecisionKind Kind, string Text = "");

    public static class CodingRequestDetector
    {
        public static string Normalized(string text)
        {
            if (string.IsNullOrEmpty(text)) return string.Empty;
            var s = text.ToLowerInvariant().Replace('\u2019', '\'').Replace('-', ' ');
            return Regex.Replace(s, @"\s+", " ").Trim();
        }

        private const string Verbs = "write|implement|code|create|build|develop|scaffold|solve|complete";
        private const string Objects = "function|method|class|program|script|algorithm|endpoint|api|service|route|handler|query|regex|regular expression|loop|snippet|solution|code|unit tests?|test cases?|tests? for|module|component|hook|decorator|generator|parser|calculator|validator|cache|stack|queue|linked list|tree|trie|graph|heap|matrix|iterator|crud|fastapi|rest api|problem|exercise|challenge|task|binary search|search|sort|merge sort|quick sort|fibonacci|factorial|fizz ?buzz|palindrome|anagram|two sum|hash ?map|hash table|counter|scraper|crawler|app|application|pipeline|classifier|chatbot|agent|retriever|rate limiter|limiter|logger|context manager|state machine";

        private static readonly Regex VerbObject = new(
            $@"\b({Verbs})\s+(me\s+|us\s+)?((a|an|the|some|this|that|your own|one|another)\s+)?([\w'/]+\s+){{0,3}}?({Objects})\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex RequestFrame = new(
            $@"\b(can|could|would|will)\s+you\s+(please\s+|just\s+|now\s+|also\s+)?({Verbs})\b|\bplease\s+({Verbs})\b|\b(let's|lets|let us)\s+({Verbs})\b|\bi\s+(want|need|would like|'d like|d like)\s+you\s+to\s+({Verbs})\b|\byou\s+(need|have|should|must|are going|'re going)\s+to\s+({Verbs})\b|\b(you|just)\s+(wanna|want to|gonna|going to)\s+({Verbs})\b|\byou('re| are)\s+(going to|gonna)\s+({Verbs})\b|^(so\s+|okay\s+|now\s+)*(wanna|want to|gonna)\s+({Verbs})\b|\byour task\b|\bgo ahead and\s+({Verbs})\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex QuestionWordBeforeModal = new(
            @"\b(how|what|why|when|where|which)\s+(can|could|would|will|do|does|did|should)\s+you\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex LeadingFiller = new(
            @"^(okay|ok|so|now|alright|all right|right|well|then|and|great|perfect|cool|good|nice|next)\b[,.]?\s*",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex ImperativeStart = new($@"^({Verbs})\b", RegexOptions.Compiled | RegexOptions.IgnoreCase);
        private static readonly Regex FirstPersonStart = new(@"^(i|we|my|our)\s", RegexOptions.Compiled | RegexOptions.IgnoreCase);
        private static readonly Regex PastNarration = new(
            @"\b(i|we)\s+(have\s+|had\s+|just\s+|also\s+|usually\s+|always\s+|often\s+|recently\s+|really\s+)?(wrote|written|implemented|built|created|developed|coded|did|used|worked)\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex ConceptualFrame = new(
            @"\b(what is|what's|what are|what does|how does|how do|why|difference between|explain|describe|tell me about|walk me through)\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly string[] AlwaysCodingPhrases =
        {
            "write some code", "write the code", "write this code", "write that code",
            "show me the code", "type it out"
        };

        private static readonly string[] ObjectPhrases =
        {
            "write a fastapi", "fastapi service", "implement a fastapi", "build a fastapi", "create a fastapi",
            "code a fastapi", "write an endpoint", "implement an endpoint", "add an endpoint",
            "write a service", "implement a service", "build a service"
        };

        private const string DoableVerbs = "reverse|sort|parse|read|write|merge|remove|find|count|check|convert|split|join|flatten|filter|swap|sum|loop|iterate|search|validate|format|print|open|fetch|call|create|declare|define|implement|make|build|generate|copy|delete|append|insert|replace|concatenate|compare|calculate|compute";

        private static readonly Regex HowToStart = new(
            $@"^(?:(?:how to|how (?:do|would|can|could|should) (?:you|i|we))\s+)?(?:{DoableVerbs})\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private const string Languages = @"python|javascript|typescript|java|kotlin|golang|rust|swift|c\+\+|c#|csharp|cpp|ruby|php|scala|sql|bash|node(?:\.?js)?|js|ts";

        private static readonly Regex LanguageReference = new(
            $@"\b(?:in|into|to|with|using)\s+(?:the\s+)?(?:{Languages})(?![\w+#])|\bin\s+go\s*[?.!]*$",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex LanguageOnly = new(
            $@"^(?:(?:and|now|okay|ok|so)\s+)*(?:in\s+|with\s+|using\s+)?(?:{Languages})(?:\s+(?:please|now|too|instead|as well))*[?.!]*$",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex RewriteVerbs = new(
            @"\b(?:write|rewrite|convert|translate|port|switch|redo|implement|code|show|give|make|try)\b|\b(?:can|could|would|will)\s+you\s+(?:please\s+)?(?:do|use|see)\b|\bhow\s+(?:would|does|will)\s+(?:it|this|that)\s+look\b|\b(?:need|want|prefer)\s+(?:it|this)\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex Referent = new(
            @"\b(?:it|this|that|these|the\s+(?:function|code|solution|loop|method|class|implementation|program|script)|your\s+(?:code|solution|function|approach|implementation))\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex ImproveVerbs = new(
            @"\b(?:improve|optimi[sz]e|refactor|simplify|shorten|clean(?:\s+it)?\s+up|tidy|speed\s+(?:it\s+)?up)\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex MakeBetter = new(
            @"\bmake\s+(?:it|this|that|the\s+\w+)\s+(?:a\s+bit\s+|a\s+little\s+|much\s+)?(?:faster|quicker|shorter|cleaner|simpler|better|smaller|more\s+\w+|less\s+\w+|recursive|iterative|in.?place|async|generic|thread.?safe|readable|efficient)\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex AddOrHandle = new(
            @"\badd\s+(?:some\s+|a\s+|an\s+)?(?:error\s+handling|type\s+hints?|types?|tests?|unit\s+tests?|comments?|docstrings?|logging|validation|input\s+validation|main)\b|\bhandle\s+(?:the\s+)?(?:edge\s+cases?|empty|none|null|nil|errors?|exceptions?|unicode|invalid|negative|large|big|special)\b|\b(?:write|create|generate)\s+(?:a\s+|some\s+)?(?:unit\s+)?tests?\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex Alternatives = new(
            @"\b(?:another|different|alternative|other|better|easier|simpler|shorter|cleaner|faster|quicker|nicer|smarter|more\s+(?:pythonic|idiomatic|efficient|readable|concise))\s+(?:way|approach|solution|method|implementation|version|technique|algorithm|option)\b|\bdifferently\b|\bwithout\s+(?:using\s+)?\w+",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex Constraints = new(
            @"\b(?:use|using|try|with)\s+(?:a\s+|an\s+|the\s+)?(?:for\s+loop|while\s+loop|loop|recursion|recursive|stack|queue|two\s+pointers?|sliding\s+window|dict(?:ionary)?|hash\s?map|set|generator|regex|list\s+comprehension|built.?in|itertools|collections|numpy|pandas)\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex ConstraintCue = new(
            @"\b(?:can|could|would|will)\s+you\b|\bhow\s+about\b|\bwhat\s+about\b|\btry\b|\blet's\b|\bnow\b|\binstead\b|^use\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private const string Techniques = @"sliding\s+window|two\s+pointers?|binary\s+search|recursion|memoi[sz]ation|dynamic\s+programming|backtracking|greedy|divide\s+and\s+conquer|bfs|dfs|breadth.?first|depth.?first|union.?find|trie|prefix\s+sum|kadane|bit\s+manipulation|monotonic\s+stack";

        private static readonly Regex TechniqueExample = new(
            $@"\b(?:show|demonstrate|give|write|code|implement)\b[^.?!]{{0,40}}\b(?:{Techniques})\b|\bhow\s+(?:(?:do|would|can|could|might)\s+)?(?:you|we|i|one)\s+(?:use|apply|implement|code|write|do)\b[^.?!]{{0,30}}\b(?:{Techniques})\b|\b(?:{Techniques})\s+(?:example|code|implementation|snippet|demo)\b|\bexamples?\s+of\s+(?:a\s+|an\s+|the\s+)?(?:{Techniques})\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex QuestionStart = new(@"^(?:what|why|how|when|where|which|who)\b(?!\s+about\b)", RegexOptions.Compiled | RegexOptions.IgnoreCase);
        private static readonly Regex StrictExplain = new(@"\b(?:explain|describe|tell me about|walk me through|difference between|why)\b", RegexOptions.Compiled | RegexOptions.IgnoreCase);
        private static readonly Regex DefinitionFrame = new(@"\b(?:what is|what's|what are|what does)\b", RegexOptions.Compiled | RegexOptions.IgnoreCase);
        private static readonly Regex HypotheticalLook = new(@"^how\s+(?:would|does|will)\s+(?:it|this|that)\s+look", RegexOptions.Compiled | RegexOptions.IgnoreCase);
        private static readonly Regex PoliteRequest = new(@"\b(?:can|could|would|will)\s+you\b|\bplease\b|\blet's\b", RegexOptions.Compiled | RegexOptions.IgnoreCase);
        private static readonly Regex ImproveAtStart = new(@"^(?:improve|optimi[sz]e|refactor|simplify|shorten|clean|tidy|speed)\b", RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex CodeExample = new(
            @"\b(?:show|give|write|share|demonstrate|sketch|put)\b[^.?!]{0,40}(?:\b(?:in|as|with)\s+(?:some\s+|a\s+little\s+|a\s+bit\s+of\s+|actual\s+|real\s+)?code\b|\bcode\s+(?:examples?|snippets?|samples?)\b|\bexamples?\s+(?:in|of)\s+code\b)",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly HashSet<string> ExampleFrameWords = new(StringComparer.OrdinalIgnoreCase)
        {
            "okay", "ok", "so", "now", "alright", "right", "well", "then", "and", "also", "maybe", "yeah", "great", "good",
            "can", "could", "would", "will", "you", "please", "just", "me", "us", "quickly", "quick", "briefly",
            "show", "give", "write", "share", "demonstrate", "sketch", "put", "an", "a", "the", "some", "any", "one",
            "this", "that", "it", "these", "those", "how", "what", "works", "work", "looks", "look", "like",
            "example", "examples", "in", "as", "with", "of", "for", "to", "code", "snippet", "snippets", "sample", "samples",
            "little", "bit", "actual", "real", "simple", "small", "short", "kind", "sort"
        };

        private static readonly Regex SessionCues = new(
            @"\bnew (python |java |javascript |typescript |go |kotlin |swift )?(file|notebook|project)\b|\bopen (up )?(your|an|a|the) (editor|ide|terminal|notebook|repl|vs ?code|pycharm|intellij)\b|\bshare (your|the) screen\b|\bscreen shar(e|ing)\b|\bstart coding\b|\blet's code\b|\bpair program|\bcode together\b|\bpractical (task|exercise)\b|\blive coding\b|\bsome coding\b|\bcoding (exercise|challenge|task|problem|question|round|test|part|session)\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly Regex DetailCues = new(
            @"\b(input|output|return|returns|returning|parameter|parameters|param|argument|arguments|string|strings|list|lists|array|arrays|number|numbers|integer|integers|float|dictionary|dict|tuple|character|characters|char|chars|print|reverse|reversed|sort|sorted|count|sum|filter|unique|duplicate|duplicates|empty|edge case|edge cases|recursive|recursion|iterative|complexity|without|instead|given|takes|gets|accepts|receives|should|must|text|word|words|palindrome)\b",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private static readonly HashSet<string> GenericObjects = new(StringComparer.OrdinalIgnoreCase)
        {
            "code", "solution", "problem", "exercise", "challenge", "task"
        };

        private static string StripLeadingFillers(string text)
        {
            var current = text;
            while (LeadingFiller.IsMatch(current))
            {
                var next = LeadingFiller.Replace(current, string.Empty, 1);
                if (next == current) break;
                current = next;
            }
            return current;
        }

        public static bool AsksHowToInLanguage(string text)
        {
            var norm = Normalized(text);
            return HowToStart.IsMatch(StripLeadingFillers(norm)) && LanguageReference.IsMatch(norm);
        }

        public static bool IsTaskRequest(string text)
        {
            var norm = Normalized(text);
            if (string.IsNullOrEmpty(norm)) return false;
            if (AsksHowToInLanguage(text)) return true;

            var hasVerbObject = VerbObject.IsMatch(norm);
            var withoutQuestionModals = QuestionWordBeforeModal.Replace(norm, " ");
            if (hasVerbObject && (RequestFrame.IsMatch(withoutQuestionModals) || ImperativeStart.IsMatch(StripLeadingFillers(norm))))
                return true;

            if (FirstPersonStart.IsMatch(norm) || PastNarration.IsMatch(norm) || ConceptualFrame.IsMatch(norm))
                return false;

            if (AlwaysCodingPhrases.Any(p => norm.Contains(p, StringComparison.Ordinal))) return true;
            return ObjectPhrases.Any(p => norm.Contains(p, StringComparison.Ordinal));
        }

        public static bool IsDeicticRequest(string text)
        {
            var norm = Normalized(text);
            if (!IsTaskRequest(text) || AsksHowToInLanguage(text) || DetailCues.IsMatch(norm)) return false;
            foreach (Match m in VerbObject.Matches(norm))
            {
                var obj = m.Groups[m.Groups.Count - 1].Value;
                if (!GenericObjects.Contains(obj)) return false;
            }
            return true;
        }

        public static CodingFollowUpKind? FollowUp(string text)
        {
            var norm = Normalized(text);
            var wordCount = norm.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length;
            if (wordCount is < 2 or > 24) return null;
            if (FirstPersonStart.IsMatch(norm) || PastNarration.IsMatch(norm) ||
                ConversationUnderstanding.LooksLikeCandidateNarrative(norm) || StrictExplain.IsMatch(norm))
                return null;

            var asksForAlternative = Alternatives.IsMatch(norm);
            if (DefinitionFrame.IsMatch(norm) && !asksForAlternative) return null;

            if (TechniqueExample.IsMatch(norm)) return CodingFollowUpKind.Example;

            var asksHow = QuestionStart.IsMatch(norm);
            if (LanguageOnly.IsMatch(norm)) return CodingFollowUpKind.Change;
            if (LanguageReference.IsMatch(norm) && RewriteVerbs.IsMatch(norm) &&
                (!asksHow || HypotheticalLook.IsMatch(norm)))
                return CodingFollowUpKind.Change;
            if (asksForAlternative) return CodingFollowUpKind.Change;
            if (asksHow) return null;

            var startsWithImprove = ImproveAtStart.IsMatch(StripLeadingFillers(norm));
            if (ImproveVerbs.IsMatch(norm) && (Referent.IsMatch(norm) || startsWithImprove || PoliteRequest.IsMatch(norm)))
                return CodingFollowUpKind.Change;
            if (MakeBetter.IsMatch(norm) || AddOrHandle.IsMatch(norm)) return CodingFollowUpKind.Change;
            if (Constraints.IsMatch(norm) && ConstraintCue.IsMatch(norm)) return CodingFollowUpKind.Change;
            return null;
        }

        public static bool AsksForCodeExample(string text)
        {
            var norm = Normalized(text);
            if (string.IsNullOrEmpty(norm) || FirstPersonStart.IsMatch(norm) || PastNarration.IsMatch(norm))
                return false;
            return CodeExample.IsMatch(norm);
        }

        public static bool CodeExampleNamesItsSubject(string text)
        {
            var words = Regex.Split(Normalized(text), @"[^\p{L}\p{N}']+")
                .Where(w => !string.IsNullOrEmpty(w));
            return words.Any(w => !ExampleFrameWords.Contains(w));
        }

        public static bool StartsCodingSession(string text)
        {
            var norm = Normalized(text);
            return !PastNarration.IsMatch(norm) && SessionCues.IsMatch(norm);
        }

        public static bool LooksLikeTaskDetail(string text)
        {
            var norm = Normalized(text);
            var wordCount = norm.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length;
            if (wordCount is < 3 or > 16 || norm.Contains('?')) return false;
            if (FirstPersonStart.IsMatch(norm) ||
                ConversationUnderstanding.HasInterviewerFrame(norm) ||
                ConversationUnderstanding.LooksLikeCandidateNarrative(norm))
                return false;
            return DetailCues.IsMatch(norm);
        }
    }

    public sealed class CodingSessionState
    {
        public const double FreshnessWindowSeconds = 600.0;
        public const int MaxTaskCharacters = 900;

        public DateTime? ArmedAt { get; private set; }
        public DateTime? UpdatedAt { get; private set; }
        public string Task { get; private set; } = string.Empty;
        public Guid? CardTurnId { get; private set; }
        public string CurrentCode { get; private set; } = string.Empty;

        public bool IsFresh(DateTime now)
        {
            DateTime? last = null;
            if (ArmedAt.HasValue && UpdatedAt.HasValue)
                last = ArmedAt.Value > UpdatedAt.Value ? ArmedAt.Value : UpdatedAt.Value;
            else
                last = ArmedAt ?? UpdatedAt;

            return last.HasValue && (now - last.Value).TotalSeconds <= FreshnessWindowSeconds;
        }

        public void Arm(DateTime now) => ArmedAt = now;

        public void Begin(string task, Guid cardTurnId, DateTime now)
        {
            Task = Capped(task);
            CardTurnId = cardTurnId;
            UpdatedAt = now;
        }

        public void Refine(string task, DateTime now)
        {
            Task = Capped(task);
            UpdatedAt = now;
        }

        public void ApplyChange(string instruction, Guid cardTurnId, DateTime now)
        {
            Task = Capped(Task + " Then: " + instruction);
            CardTurnId = cardTurnId;
            UpdatedAt = now;
        }

        public void StoreCode(string code) => CurrentCode = code ?? string.Empty;
        public void Touch(DateTime now) => UpdatedAt = now;

        public void Clear()
        {
            ArmedAt = null;
            UpdatedAt = null;
            Task = string.Empty;
            CardTurnId = null;
            CurrentCode = string.Empty;
        }

        private static string Capped(string task)
        {
            var trimmed = (task ?? string.Empty).Trim();
            return trimmed.Length > MaxTaskCharacters ? trimmed[^MaxTaskCharacters..] : trimmed;
        }
    }

    public static class CodingInterviewStepsHelper
    {
        public static bool IsImplementationCodingRequest(string text) => CodingRequestDetector.IsTaskRequest(text);

        public static CodingTurnDecision? DecideTurn(string text, CodingSessionState session, DateTime now, string? previousQuestion = null)
        {
            var hasCodeOnScreen = session.IsFresh(now) && !string.IsNullOrWhiteSpace(session.CurrentCode);
            if (hasCodeOnScreen && CodingRequestDetector.FollowUp(text) == CodingFollowUpKind.Change)
                return new CodingTurnDecision(CodingTurnDecisionKind.ChangeCode, text);

            if (IsImplementationCodingRequest(text))
            {
                return CodingRequestDetector.IsDeicticRequest(text)
                    ? new CodingTurnDecision(CodingTurnDecisionKind.NeedsScreenContext)
                    : new CodingTurnDecision(CodingTurnDecisionKind.NewTask, text);
            }

            if (CodingRequestDetector.AsksForCodeExample(text))
            {
                var subject = (previousQuestion ?? string.Empty).Trim();
                if (!CodingRequestDetector.CodeExampleNamesItsSubject(text) && !string.IsNullOrEmpty(subject))
                    return new CodingTurnDecision(CodingTurnDecisionKind.NewTask, $"{subject} {text}");
                return new CodingTurnDecision(CodingTurnDecisionKind.NewTask, text);
            }

            if (CodingRequestDetector.StartsCodingSession(text))
                return new CodingTurnDecision(CodingTurnDecisionKind.ArmSession);

            if (!session.IsFresh(now)) return null;

            if (CodingRequestDetector.FollowUp(text) == CodingFollowUpKind.Example)
                return new CodingTurnDecision(CodingTurnDecisionKind.NewTask, text);

            if (!CodingRequestDetector.LooksLikeTaskDetail(text)) return null;
            if (string.IsNullOrEmpty(session.Task))
                return new CodingTurnDecision(CodingTurnDecisionKind.NewTask, text);
            return new CodingTurnDecision(CodingTurnDecisionKind.RefineTask, $"{session.Task} {text}");
        }

        public static string BuildPrompt(
            string language,
            string task,
            bool spoken = false,
            string? currentCode = null,
            string? changeRequest = null)
        {
            var code = (currentCode ?? string.Empty).Trim();
            var request = (changeRequest ?? string.Empty).Trim();
            var isChange = spoken && !string.IsNullOrEmpty(code) && !string.IsNullOrEmpty(request);

            string taskBlock;
            if (isChange)
            {
                taskBlock = $"ORIGINAL TASK:\n{task}\n\nCURRENT CODE (already on the candidate's screen):\n{code}\n\nCHANGE REQUEST (raw speech-to-text of what the interviewer just said):\n{request}";
            }
            else if (spoken && !string.IsNullOrEmpty(code))
            {
                taskBlock = $"TASK:\n{task}\n\nCURRENT CODE (written from an earlier, shorter version of the task; update it to fit the full TASK):\n{code}";
            }
            else
            {
                taskBlock = $"TASK:\n{task}";
            }

            var speechNote = isChange
                ? "\nApply the CHANGE REQUEST to the CURRENT CODE and output the FULL updated solution in the format below, replacing the current code. Keep what still fits and change only what the request needs. Keep the current language unless the request asks for another one; when it does, rewrite everything in that language and tag every code fence with it.\n\n"
                : spoken
                    ? $"\nThe TASK is raw speech-to-text from a live interview. Infer the single most likely coding task. Use {language} unless the task names another language, and tag the code fences with the language actually used.\n\n"
                    : string.Empty;

            var sayLine = isChange
                ? "- 2-3 short lines the candidate says out loud before typing: what changes and why, and the new time and space complexity if it changed."
                : "- 2-3 short lines the candidate says out loud before typing: restate the task, name one assumption, give time and space complexity.";

            var sayBlock = spoken ? $"SAY:\n{sayLine}\n\n" : string.Empty;
            var stepRule = spoken
                ? "Split into 1-6 steps the candidate can type in order, each at most about 6 lines and a whole unit. Use ONE step when the whole solution is 6 lines or fewer."
                : "Split into 2-5 steps the candidate can type in order.";
            var preambleRule = spoken
                ? "- No preamble before SAY. No recap after the last step. SAY lines start with \"- \" and stay under 90 characters."
                : "- No preamble before STEP 1. No recap after the last step.";
            var voice = spoken ? $"For SAY and Why prose only:\n{AnswerPromptBlocks.CandidateVoice}\n" : string.Empty;

            return $@"You are a live coding interview copilot. The candidate must type this while speaking.

{taskBlock}
{speechNote}{voice}OUTPUT FORMAT — follow exactly:

{sayBlock}STEP 1 — file: relative/path.ext
Why: one short line of what this chunk does.
```{language}
code to type now
```

STEP 2 — file: relative/path.ext
Why: one short line.
```{language}
next chunk (may be the SAME file)
```

RULES:
- {stepRule}
- Prefer small chunks even in the same file (imports, app setup, one route, a test).
- Each Why is one sentence, under 80 characters.
- Keep every code line under 80 characters.
{preambleRule}
- Real runnable code. No TODO / pass placeholders unless the task is tiny.

SIMPLEST CODE ONLY:
- The easiest thing a mid-level engineer would type in 2 minutes. Boring on purpose.
- One file when that is enough. Extra files only if asked.
- No unnecessary classes, DI containers, factories, auth, Docker, or CI.
- Short names. Algorithm tasks: the obvious loop or dict.";
        }

        public static string TrimmedCodeBlock(string code)
        {
            if (string.IsNullOrEmpty(code)) return string.Empty;
            var lines = code.Replace("\r\n", "\n").Split('\n').ToList();
            while (lines.Count > 0 && string.IsNullOrWhiteSpace(lines[0])) lines.RemoveAt(0);
            while (lines.Count > 0 && string.IsNullOrWhiteSpace(lines[^1])) lines.RemoveAt(lines.Count - 1);
            return string.Join("\n", lines);
        }

        private static readonly Regex StepRegex = new(
            @"STEP\s+(\d+)\s*[—\-–]\s*file:\s*(\S+)\s*\r?\nWhy:\s*(.+)\r?\n```(\w+)?\r?\n([\s\S]*?)```",
            RegexOptions.Compiled);

        public static List<CodingInterviewStep> ParseSteps(string markdown)
        {
            var result = new List<CodingInterviewStep>();
            if (string.IsNullOrEmpty(markdown)) return result;
            foreach (Match m in StepRegex.Matches(markdown))
            {
                var number = int.TryParse(m.Groups[1].Value, out var n) ? n : result.Count + 1;
                var fileName = m.Groups[2].Value;
                var why = m.Groups[3].Value.Trim();
                var lang = m.Groups[4].Success && !string.IsNullOrEmpty(m.Groups[4].Value) ? m.Groups[4].Value : "text";
                var code = TrimmedCodeBlock(m.Groups[5].Value);
                result.Add(new CodingInterviewStep(number, fileName, why, lang, code));
            }
            return result;
        }

        private static readonly Regex StreamingHeaderRegex = new(
            @"^\s*STEP\s+(\d+)\s*[—–:\-]?\s*(?:file:)?\s*(\S+)?",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        public static CodingStepProgress ParseStepsStreaming(string markdown)
        {
            var steps = new List<CodingInterviewStep>();
            if (string.IsNullOrEmpty(markdown)) return new CodingStepProgress(steps, false);

            int? curNum = null;
            string curFile = "main";
            string curWhy = string.Empty;
            string curLang = "text";
            var codeLines = new List<string>();
            bool inFence = false;

            void FinishCurrent()
            {
                if (!curNum.HasValue) return;
                steps.Add(new CodingInterviewStep(curNum.Value, curFile, curWhy, curLang, TrimmedCodeBlock(string.Join("\n", codeLines))));
                curNum = null;
                curFile = "main";
                curWhy = string.Empty;
                curLang = "text";
                codeLines.Clear();
            }

            foreach (var rawLine in markdown.Replace("\r\n", "\n").Split('\n'))
            {
                var line = rawLine.TrimEnd('\r');
                if (inFence)
                {
                    if (line.Trim() == "```")
                        inFence = false;
                    else
                        codeLines.Add(line);
                    continue;
                }

                var headerMatch = StreamingHeaderRegex.Match(line);
                if (headerMatch.Success)
                {
                    FinishCurrent();
                    curNum = int.TryParse(headerMatch.Groups[1].Value, out var n) ? n : steps.Count + 1;
                    curFile = headerMatch.Groups[2].Success && !string.IsNullOrEmpty(headerMatch.Groups[2].Value)
                        ? headerMatch.Groups[2].Value
                        : "main";
                    continue;
                }

                if (!curNum.HasValue) continue;

                if (line.StartsWith("```", StringComparison.Ordinal))
                {
                    inFence = true;
                    var lang = line[3..].Trim();
                    if (!string.IsNullOrEmpty(lang)) curLang = lang;
                    continue;
                }

                if (line.StartsWith("why:", StringComparison.OrdinalIgnoreCase))
                {
                    curWhy = line[4..].Trim();
                }
            }

            var lastStepIsOpen = inFence || (curNum.HasValue && codeLines.Count == 0);
            FinishCurrent();
            return new CodingStepProgress(steps, lastStepIsOpen);
        }

        public static string? LanguageDisplayName(string? fence) => (fence ?? string.Empty).ToLowerInvariant() switch
        {
            "python" or "py" => "Python",
            "typescript" or "ts" or "tsx" => "TypeScript",
            "javascript" or "js" or "jsx" or "node" or "nodejs" => "JavaScript",
            "java" => "Java",
            "kotlin" or "kt" => "Kotlin",
            "go" or "golang" => "Go",
            "rust" or "rs" => "Rust",
            "swift" => "Swift",
            "csharp" or "cs" or "c#" => "C#",
            "cpp" or "c++" => "C++",
            "c" => "C",
            "ruby" or "rb" => "Ruby",
            "php" => "PHP",
            "scala" => "Scala",
            "sql" => "SQL",
            "bash" or "sh" or "shell" or "zsh" => "Shell",
            _ => null
        };

        private static readonly Regex FirstStepRegex = new(
            @"^[ \t]*STEP\s+\d+",
            RegexOptions.Compiled | RegexOptions.Multiline | RegexOptions.IgnoreCase);

        public static CodingResponse SplitCodingResponse(string text)
        {
            if (string.IsNullOrEmpty(text)) return new CodingResponse(new List<string>(), string.Empty);
            var match = FirstStepRegex.Match(text);
            var sayText = match.Success ? text[..match.Index] : text;
            var steps = match.Success ? text[match.Index..] : string.Empty;

            var bullets = new List<string>();
            foreach (var rawLine in sayText.Replace("\r\n", "\n").Split('\n'))
            {
                var line = rawLine.Trim();
                foreach (var marker in new[] { "- ", "* ", "• " })
                {
                    if (line.StartsWith(marker, StringComparison.Ordinal))
                    {
                        var bullet = line[marker.Length..].Trim();
                        if (!string.IsNullOrEmpty(bullet)) bullets.Add(bullet);
                        break;
                    }
                }
            }

            return new CodingResponse(bullets, steps);
        }

        public static string? FirstTalkingPoint(string? answer)
        {
            if (string.IsNullOrWhiteSpace(answer)) return null;
            foreach (var rawLine in answer.Replace("\r\n", "\n").Split('\n'))
            {
                var line = rawLine.Trim();
                if (string.IsNullOrEmpty(line)) continue;
                if (line.Equals("SAY:", StringComparison.OrdinalIgnoreCase)) continue;
                foreach (var marker in new[] { "- ", "* ", "• " })
                {
                    if (line.StartsWith(marker, StringComparison.Ordinal))
                    {
                        line = line[marker.Length..].Trim();
                        break;
                    }
                }
                if (!string.IsNullOrEmpty(line)) return line;
            }
            return null;
        }

        public static string CodingCardBullets(CodingResponse response, int stepCount, bool isComplete)
        {
            var lines = response.SayBullets.Select(b => $"- {b}").ToList();
            if (lines.Count == 0 && isComplete && stepCount > 0)
            {
                lines.Add($"- Code is in the code panel ({stepCount} step{(stepCount == 1 ? "" : "s")}).");
            }
            return string.Join("\n", lines);
        }
    }
}
