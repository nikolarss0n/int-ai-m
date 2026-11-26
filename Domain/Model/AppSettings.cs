using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Global app settings persisted to %APPDATA%\InterviewMaster\settings.json.
    /// </summary>
    public class AppSettings
    {
        private static AppSettings? _instance;
        private static readonly object _lock = new();

        private const string RoleKey = "InterviewMaster.Role";
        private const string ProgrammingLanguageKey = "InterviewMaster.ProgrammingLanguage";
        private const string ListeningLanguageKey = "InterviewMaster.ListeningLanguage";
        private const string ResponseLanguageKey = "InterviewMaster.ResponseLanguage";
        private const string SpeakingLanguageKey = "InterviewMaster.SpeakingLanguage";
        private const string FrameworksKey = "InterviewMaster.Frameworks";
        private const string CaptureDeviceKey = "InterviewMaster.CaptureDevice";
        private const string AnswerModelKey = "InterviewMaster.AnswerModel";
        private const string OpenAiModelKey = "InterviewMaster.OpenAIModel";
        private const string OpenAiReasoningKey = "InterviewMaster.OpenAIReasoningEffort";
        private const string OpenAiPriorityKey = "InterviewMaster.OpenAIPriority";
        private const string BackgroundTransparencyKey = "InterviewMaster.BackgroundTransparency";

        private InterviewRole _role = InterviewRole.SeniorQaEngineer;
        private ProgrammingLanguage _programmingLanguage = ProgrammingLanguage.Python;
        private SpeakingLanguage _listeningLanguage = SpeakingLanguage.English;
        private SpeakingLanguage _responseLanguage = SpeakingLanguage.English;
        private string _frameworks = string.Empty;
        private CaptureDevice _captureDevice = CaptureDevice.Both;
        private AnswerModel _answerModel = AnswerModel.Claude;
        private string _openAiAnswerModel = AppConstants.Models.OpenAiDefault;
        private string _openAiReasoningEffort = "low";
        private bool _openAiPriority;
        private double _backgroundTransparency = 0.25;

        public static AppSettings Shared
        {
            get
            {
                if (_instance == null)
                {
                    lock (_lock)
                    {
                        if (_instance == null)
                        {
                            _instance = new AppSettings();
                            _instance.Load();
                        }
                    }
                }
                return _instance;
            }
        }

        private AppSettings() { }

        public InterviewRole Role
        {
            get => _role.CanonicalRole();
            set { _role = value.CanonicalRole(); SaveAll(); OnSettingsChanged?.Invoke(); }
        }

        public ProgrammingLanguage ProgrammingLanguage
        {
            get => _programmingLanguage;
            set { _programmingLanguage = value; SaveAll(); OnSettingsChanged?.Invoke(); }
        }

        public SpeakingLanguage ListeningLanguage
        {
            get => _listeningLanguage;
            set { _listeningLanguage = value; SaveAll(); OnSettingsChanged?.Invoke(); }
        }

        public SpeakingLanguage ResponseLanguage
        {
            get => _responseLanguage;
            set { _responseLanguage = value; SaveAll(); OnSettingsChanged?.Invoke(); }
        }

        /// <summary>Legacy alias for ResponseLanguage.</summary>
        public SpeakingLanguage SpeakingLanguage
        {
            get => _responseLanguage;
            set => ResponseLanguage = value;
        }

        public string Frameworks
        {
            get => _frameworks;
            set { _frameworks = value ?? string.Empty; SaveAll(); OnSettingsChanged?.Invoke(); }
        }

        public CaptureDevice CaptureDevice
        {
            get => _captureDevice;
            set { _captureDevice = value; SaveAll(); OnSettingsChanged?.Invoke(); }
        }

        public AnswerModel AnswerModel
        {
            get => _answerModel;
            set { _answerModel = value; SaveAll(); OnSettingsChanged?.Invoke(); }
        }

        public string OpenAiAnswerModel
        {
            get => _openAiAnswerModel;
            set { _openAiAnswerModel = string.IsNullOrWhiteSpace(value) ? AppConstants.Models.OpenAiDefault : value.Trim(); SaveAll(); OnSettingsChanged?.Invoke(); }
        }

        public string OpenAiReasoningEffort
        {
            get => _openAiReasoningEffort;
            set { _openAiReasoningEffort = string.IsNullOrWhiteSpace(value) ? "low" : value.Trim(); SaveAll(); OnSettingsChanged?.Invoke(); }
        }

        public bool OpenAiPriority
        {
            get => _openAiPriority;
            set { _openAiPriority = value; SaveAll(); OnSettingsChanged?.Invoke(); }
        }

        public double BackgroundTransparency
        {
            get => _backgroundTransparency;
            set { _backgroundTransparency = Math.Clamp(value, 0.0, 1.0); SaveAll(); OnSettingsChanged?.Invoke(); }
        }

        public IReadOnlyList<string> FrameworksList =>
            _frameworks.Split(',', StringSplitOptions.RemoveEmptyEntries)
                .Select(s => s.Trim())
                .Where(s => !string.IsNullOrEmpty(s))
                .ToList();

        public string RoleDisplayName => Role.GetDisplayName();
        public string LanguageDisplayName => _programmingLanguage.GetDisplayName();
        public string ListeningLanguageDisplayName => _listeningLanguage.GetDisplayName();
        public string ResponseLanguageDisplayName => _responseLanguage.GetDisplayName();
        public bool IsSeniorRole => Role.IsSenior();
        public bool IsTestAutomationRole => Role.IsQa();
        public bool IsAiOrDataRole => Role.IsAiOrData();
        public string CodeLanguage => _programmingLanguage.GetCodeBlockLanguage();
        public string LanguageCode => _listeningLanguage.GetLanguageCode();

        public string EffectiveFrameworks
        {
            get
            {
                var trimmed = _frameworks.Trim();
                if (string.IsNullOrEmpty(trimmed) && IsTestAutomationRole)
                    return "Playwright, TypeScript, API Testing, CI";
                return trimmed;
            }
        }

        public bool IsPlaywrightFocused
        {
            get
            {
                var lower = _frameworks.Trim().ToLowerInvariant();
                return IsTestAutomationRole && (string.IsNullOrEmpty(lower) || lower.Contains("playwright"));
            }
        }

        public string InterviewContext
        {
            get
            {
                var sb = new StringBuilder();
                sb.AppendLine($"Position: {RoleDisplayName}");
                if (IsTestAutomationRole)
                {
                    sb.AppendLine("Prompt Profile: Shared QA/SDET Playwright");
                    sb.AppendLine($"QA Level: {Role.GetQaProfileLabel()}");
                }
                sb.AppendLine($"Programming Language: {LanguageDisplayName}");
                sb.AppendLine($"Listening Language: {ListeningLanguageDisplayName}");
                sb.Append($"Response Language: {ResponseLanguageDisplayName}");
                if (!string.IsNullOrEmpty(EffectiveFrameworks))
                {
                    sb.Append($"\nTech Stack: {EffectiveFrameworks}");
                }
                return sb.ToString();
            }
        }

        public string CandidateVoiceInstruction => AnswerPromptBlocks.CandidateVoice;

        public string AnswerStyleInstruction
        {
            get
            {
                var sb = new StringBuilder();
                sb.AppendLine("INTERVIEW ANSWER STYLE:");
                sb.AppendLine("- Answer as a spoken candidate answer, not as a textbook note.");
                sb.AppendLine("- Return cue-card bullets only: 3-5 lines, every line starts with \"- \".");
                sb.AppendLine("- Each bullet should be short enough to read while speaking, ideally under 90 characters.");
                sb.AppendLine("- Plain text only. No markdown, no **bold**, no headings, no numbered lists.");
                sb.AppendLine("- For acronyms like SOLID, one bullet per letter as \"S - Single Responsibility: ...\".");
                sb.AppendLine("- Only for \"tell me about yourself\" or overall-background questions, open with a years-of-experience headline.");
                sb.AppendLine("- For \"What is X?\" concept questions, first bullet defines X plainly with the acronym expansion when useful.");
                sb.AppendLine("- Prefer concrete trade-offs, examples, and one senior signal over textbook lists.");
                sb.AppendLine("- If the transcript is noisy, answer the likely topic confidently.");
                sb.AppendLine();
                sb.AppendLine(CandidateVoiceInstruction);

                if (IsAiOrDataRole)
                {
                    sb.AppendLine();
                    sb.AppendLine("AI/ML FOCUS:");
                    sb.AppendLine("- For RAG/CAG, explain the retrieval flow: source data -> chunks/embeddings -> vector DB -> semantic search -> LLM answer with context.");
                    sb.AppendLine("- For core ML questions, give the plain definition first, then intuition/formula, when to use it, and one pitfall.");
                    sb.AppendLine("- Metrics: precision = TP/(TP+FP), recall = TP/(TP+FN), F1 = harmonic mean; prefer PR-AUC/F1 over accuracy on imbalanced data.");
                    sb.AppendLine("- For overfitting, leakage, or tuning, mention train/validation/test splits, cross-validation, and fitting preprocessing on train only.");
                    sb.AppendLine("- Only claim hands-on use of a model if the resume shows it; otherwise say how you would use and evaluate it.");
                }

                if (IsTestAutomationRole)
                {
                    sb.AppendLine();
                    sb.AppendLine("TEST AUTOMATION FOCUS:");
                    sb.AppendLine($"- {Role.GetQaSeniorityInstruction()}");
                    sb.AppendLine("- Default to Playwright unless the question names another automation framework.");
                    sb.AppendLine("- Mention locators, fixtures/test data, page objects, mocking, flake prevention, traces, or app-vs-test triage when relevant.");
                }

                if (IsPlaywrightFocused)
                {
                    sb.AppendLine();
                    sb.AppendLine("PLAYWRIGHT DEFAULTS:");
                    sb.AppendLine("- Prefer web-first assertions like `await expect(locator).toBeVisible()` over manual waits.");
                    sb.AppendLine("- Prefer `getByRole`, `getByLabel`, and stable `data-testid` locators over CSS/XPath.");
                    sb.AppendLine("- For flaky tests: remove `waitForTimeout`, isolate data, check async UI state, and inspect trace/network artifacts.");
                }

                return sb.ToString().TrimEnd();
            }
        }

        public string LanguageInstruction
        {
            get
            {
                if (_responseLanguage == SpeakingLanguage.English)
                    return "OUTPUT LANGUAGE: English. Answer every candidate-facing bullet in English.";

                return $"OUTPUT LANGUAGE: {_responseLanguage.GetDisplayName()}.\n" +
                       $"Answer every candidate-facing bullet in {_responseLanguage.GetDisplayName()}, even if the transcript, previous cards, or examples are in another language.\n" +
                       "Keep code, commands, API names, framework names, and short technical identifiers in English.";
            }
        }

        public string LlmLanguageInstruction => LanguageInstruction;

        public string WhisperVocabulary
        {
            get
            {
                const string common = "API, REST, SQL, NoSQL, Redis, Kafka, Docker, Kubernetes, microservices, CI/CD, Git, AWS, Azure, Big O, hash map, tree, graph";
                var langVocab = _programmingLanguage switch
                {
                    ProgrammingLanguage.Python => "Python, Django, Flask, FastAPI, dictionary, generator, decorator, async await, asyncio, pytest, Pydantic, ",
                    ProgrammingLanguage.TypeScript or ProgrammingLanguage.JavaScript => "TypeScript, JavaScript, Node.js, React, Next.js, event loop, Promise, async await, npm, Jest, ",
                    ProgrammingLanguage.Java => "Java, JVM, Spring Boot, Hibernate, JPA, Maven, Gradle, JUnit, HashMap, polymorphism, ",
                    ProgrammingLanguage.CSharp => "C#, .NET, ASP.NET, Entity Framework, LINQ, async await, Task, WPF, ",
                    ProgrammingLanguage.Go => "Go, Golang, goroutine, channel, interface, struct, slice, defer, ",
                    ProgrammingLanguage.Rust => "Rust, borrow checker, ownership, lifetime, trait, Option, Result, Tokio, ",
                    _ => string.Empty
                };
                var roleVocab = IsAiOrDataRole
                    ? "LLM, RAG, CAG, embeddings, vector database, chunking, reranking, LangChain, LangGraph, PyTorch, Hugging Face, fine-tuning, LoRA, evals, "
                    : IsTestAutomationRole
                        ? "Playwright, locator, fixture, storageState, flaky test, CI pipeline, Selenium, Cypress, API testing, "
                        : string.Empty;
                var stack = string.IsNullOrWhiteSpace(EffectiveFrameworks) ? string.Empty : EffectiveFrameworks + ", ";
                var full = $"{langVocab}{roleVocab}{stack}{common}";
                return full.Length > AppConstants.Limits.GroqWhisperPromptBytes
                    ? full.Substring(0, AppConstants.Limits.GroqWhisperPromptBytes)
                    : full;
            }
        }

        public event Action? OnSettingsChanged;

        private static string SettingsFilePath
        {
            get
            {
                var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                return Path.Combine(appData, "InterviewMaster", "settings.json");
            }
        }

        private void Load()
        {
            try
            {
                if (!File.Exists(SettingsFilePath)) return;
                var json = File.ReadAllText(SettingsFilePath);
                var dict = JsonSerializer.Deserialize<Dictionary<string, string>>(json);
                if (dict == null) return;

                if (dict.TryGetValue(RoleKey, out var roleStr) && Enum.TryParse<InterviewRole>(roleStr, true, out var role))
                    _role = role.CanonicalRole();
                if (dict.TryGetValue(ProgrammingLanguageKey, out var langStr) && Enum.TryParse<ProgrammingLanguage>(langStr, true, out var lang))
                    _programmingLanguage = lang;
                if (dict.TryGetValue(ListeningLanguageKey, out var listenStr) && Enum.TryParse<SpeakingLanguage>(listenStr, true, out var listen))
                    _listeningLanguage = listen;
                if (dict.TryGetValue(ResponseLanguageKey, out var respStr) && Enum.TryParse<SpeakingLanguage>(respStr, true, out var resp))
                    _responseLanguage = resp;
                else if (dict.TryGetValue(SpeakingLanguageKey, out var speakStr) && Enum.TryParse<SpeakingLanguage>(speakStr, true, out var speak))
                    _responseLanguage = speak;
                if (dict.TryGetValue(FrameworksKey, out var frameworks))
                    _frameworks = frameworks ?? string.Empty;
                if (dict.TryGetValue(CaptureDeviceKey, out var capStr) && Enum.TryParse<CaptureDevice>(capStr, true, out var cap))
                    _captureDevice = cap;
                if (dict.TryGetValue(AnswerModelKey, out var modelStr) && Enum.TryParse<AnswerModel>(modelStr, true, out var model))
                    _answerModel = model;
                if (dict.TryGetValue(OpenAiModelKey, out var oaModel) && !string.IsNullOrWhiteSpace(oaModel))
                    _openAiAnswerModel = oaModel;
                if (dict.TryGetValue(OpenAiReasoningKey, out var oaReason) && !string.IsNullOrWhiteSpace(oaReason))
                    _openAiReasoningEffort = oaReason;
                if (dict.TryGetValue(OpenAiPriorityKey, out var oaPrio) && bool.TryParse(oaPrio, out var prio))
                    _openAiPriority = prio;
                if (dict.TryGetValue(BackgroundTransparencyKey, out var transStr) &&
                    double.TryParse(transStr, NumberStyles.Float, CultureInfo.InvariantCulture, out var trans))
                    _backgroundTransparency = Math.Clamp(trans, 0.0, 1.0);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to load settings: {ex.Message}");
            }
        }

        private void SaveAll()
        {
            try
            {
                var dir = Path.GetDirectoryName(SettingsFilePath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                    Directory.CreateDirectory(dir);

                var json = JsonSerializer.Serialize(ExportSettings(), new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(SettingsFilePath, json);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to save settings: {ex.Message}");
            }
        }

        public void ResetToDefaults()
        {
            _role = InterviewRole.SeniorQaEngineer;
            _programmingLanguage = ProgrammingLanguage.Python;
            _listeningLanguage = SpeakingLanguage.English;
            _responseLanguage = SpeakingLanguage.English;
            _frameworks = string.Empty;
            _captureDevice = CaptureDevice.Both;
            _answerModel = AnswerModel.Claude;
            _openAiAnswerModel = AppConstants.Models.OpenAiDefault;
            _openAiReasoningEffort = "low";
            _openAiPriority = false;
            _backgroundTransparency = 0.25;
            SaveAll();
            OnSettingsChanged?.Invoke();
        }

        public Dictionary<string, string> ExportSettings() => new()
        {
            [RoleKey] = _role.ToString(),
            [ProgrammingLanguageKey] = _programmingLanguage.ToString(),
            [ListeningLanguageKey] = _listeningLanguage.ToString(),
            [ResponseLanguageKey] = _responseLanguage.ToString(),
            [SpeakingLanguageKey] = _responseLanguage.ToString(),
            [FrameworksKey] = _frameworks,
            [CaptureDeviceKey] = _captureDevice.ToString(),
            [AnswerModelKey] = _answerModel.ToString(),
            [OpenAiModelKey] = _openAiAnswerModel,
            [OpenAiReasoningKey] = _openAiReasoningEffort,
            [OpenAiPriorityKey] = _openAiPriority.ToString(),
            [BackgroundTransparencyKey] = _backgroundTransparency.ToString(CultureInfo.InvariantCulture)
        };

        public void ImportSettings(Dictionary<string, string> settings)
        {
            if (settings == null) return;
            if (settings.TryGetValue(RoleKey, out var roleStr) && Enum.TryParse<InterviewRole>(roleStr, true, out var role))
                _role = role.CanonicalRole();
            if (settings.TryGetValue(ProgrammingLanguageKey, out var langStr) && Enum.TryParse<ProgrammingLanguage>(langStr, true, out var lang))
                _programmingLanguage = lang;
            if (settings.TryGetValue(ListeningLanguageKey, out var listenStr) && Enum.TryParse<SpeakingLanguage>(listenStr, true, out var listen))
                _listeningLanguage = listen;
            if (settings.TryGetValue(ResponseLanguageKey, out var respStr) && Enum.TryParse<SpeakingLanguage>(respStr, true, out var resp))
                _responseLanguage = resp;
            else if (settings.TryGetValue(SpeakingLanguageKey, out var speakStr) && Enum.TryParse<SpeakingLanguage>(speakStr, true, out var speak))
                _responseLanguage = speak;
            if (settings.TryGetValue(FrameworksKey, out var frameworks))
                _frameworks = frameworks ?? string.Empty;
            if (settings.TryGetValue(CaptureDeviceKey, out var capStr) && Enum.TryParse<CaptureDevice>(capStr, true, out var cap))
                _captureDevice = cap;
            if (settings.TryGetValue(AnswerModelKey, out var modelStr) && Enum.TryParse<AnswerModel>(modelStr, true, out var model))
                _answerModel = model;
            if (settings.TryGetValue(BackgroundTransparencyKey, out var transStr) &&
                double.TryParse(transStr, NumberStyles.Float, CultureInfo.InvariantCulture, out var trans))
                _backgroundTransparency = Math.Clamp(trans, 0.0, 1.0);

            SaveAll();
            OnSettingsChanged?.Invoke();
        }

        public override string ToString() =>
            $"AppSettings(Role={RoleDisplayName}, Lang={LanguageDisplayName}, Listen={ListeningLanguageDisplayName}, Response={ResponseLanguageDisplayName}, Model={AnswerModel.GetDisplayName()}, Frameworks={Frameworks})";
    }
}
