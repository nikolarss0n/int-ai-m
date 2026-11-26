using System;
using System.Collections.Generic;

namespace InterviewMasterApp.Domain.Model
{
    public enum InterviewRole
    {
        SeniorQaEngineer,
        QaEngineer,
        QaAutomationEngineer,
        Sdet,
        BackendDeveloper,
        SeniorBackendDeveloper,
        FrontendDeveloper,
        SeniorFrontendDeveloper,
        FullStackDeveloper,
        SeniorFullStackDeveloper,
        DevOpsEngineer,
        DataEngineer,
        MlEngineer,
        AiEngineer,
        SeniorAiEngineer,
        SoftwareEngineer,
        SeniorSoftwareEngineer
    }

    public enum ProgrammingLanguage
    {
        Python,
        TypeScript,
        JavaScript,
        Java,
        CSharp,
        Go,
        Rust,
        Cpp,
        Kotlin,
        Swift
    }

    public enum SpeakingLanguage
    {
        English,
        Bulgarian,
        German,
        Spanish,
        French,
        Italian,
        Portuguese,
        Russian,
        Chinese,
        Japanese,
        Korean,
        Dutch,
        Polish,
        Turkish,
        Hindi
    }

    public enum CaptureDevice
    {
        Microphone,
        SystemAudio,
        Both
    }

    public enum AnswerModel
    {
        Claude,
        Grok,
        Gpt
    }

    public enum InterviewLlmProvider
    {
        Anthropic,
        Xai,
        OpenAi
    }

    public static class EnumExtensions
    {
        public static readonly IReadOnlyList<InterviewRole> SelectableRoles = new[]
        {
            InterviewRole.QaEngineer,
            InterviewRole.QaAutomationEngineer,
            InterviewRole.SeniorQaEngineer,
            InterviewRole.BackendDeveloper,
            InterviewRole.SeniorBackendDeveloper,
            InterviewRole.FrontendDeveloper,
            InterviewRole.SeniorFrontendDeveloper,
            InterviewRole.FullStackDeveloper,
            InterviewRole.SeniorFullStackDeveloper,
            InterviewRole.DevOpsEngineer,
            InterviewRole.DataEngineer,
            InterviewRole.MlEngineer,
            InterviewRole.AiEngineer,
            InterviewRole.SeniorAiEngineer,
            InterviewRole.SoftwareEngineer,
            InterviewRole.SeniorSoftwareEngineer
        };

        public static InterviewRole CanonicalRole(this InterviewRole role) =>
            role == InterviewRole.Sdet ? InterviewRole.QaAutomationEngineer : role;

        public static string GetDisplayName(this InterviewRole role) => role.CanonicalRole() switch
        {
            InterviewRole.SeniorQaEngineer => "Senior QA / SDET",
            InterviewRole.QaEngineer => "QA Engineer",
            InterviewRole.QaAutomationEngineer => "QA Automation / SDET",
            InterviewRole.BackendDeveloper => "Backend Developer",
            InterviewRole.SeniorBackendDeveloper => "Senior Backend Developer",
            InterviewRole.FrontendDeveloper => "Frontend Developer",
            InterviewRole.SeniorFrontendDeveloper => "Senior Frontend Developer",
            InterviewRole.FullStackDeveloper => "Full Stack Developer",
            InterviewRole.SeniorFullStackDeveloper => "Senior Full Stack Developer",
            InterviewRole.DevOpsEngineer => "DevOps Engineer",
            InterviewRole.DataEngineer => "Data Engineer",
            InterviewRole.MlEngineer => "ML Engineer",
            InterviewRole.AiEngineer => "AI Engineer",
            InterviewRole.SeniorAiEngineer => "Senior AI Engineer",
            InterviewRole.SoftwareEngineer => "Software Engineer",
            InterviewRole.SeniorSoftwareEngineer => "Senior Software Engineer",
            _ => role.ToString()
        };

        public static bool IsSenior(this InterviewRole role) => role.CanonicalRole() switch
        {
            InterviewRole.SeniorQaEngineer or
            InterviewRole.SeniorBackendDeveloper or
            InterviewRole.SeniorFrontendDeveloper or
            InterviewRole.SeniorFullStackDeveloper or
            InterviewRole.SeniorAiEngineer or
            InterviewRole.SeniorSoftwareEngineer => true,
            _ => false
        };

        public static bool IsQa(this InterviewRole role) => role.CanonicalRole() switch
        {
            InterviewRole.QaEngineer or
            InterviewRole.QaAutomationEngineer or
            InterviewRole.SeniorQaEngineer => true,
            _ => false
        };

        public static bool IsAiOrData(this InterviewRole role) => role.CanonicalRole() switch
        {
            InterviewRole.DataEngineer or
            InterviewRole.MlEngineer or
            InterviewRole.AiEngineer or
            InterviewRole.SeniorAiEngineer => true,
            _ => false
        };

        public static string GetQaProfileLabel(this InterviewRole role) => role.CanonicalRole() switch
        {
            InterviewRole.QaEngineer => "QA Engineer",
            InterviewRole.QaAutomationEngineer => "QA Automation / SDET",
            InterviewRole.SeniorQaEngineer => "Senior QA / SDET",
            _ => role.GetDisplayName()
        };

        public static string GetQaSeniorityInstruction(this InterviewRole role) => role.CanonicalRole() switch
        {
            InterviewRole.QaEngineer => "QA EMPHASIS: practical testing judgment, clear bug reporting, API/UI basics, and when manual exploration is better than automation.",
            InterviewRole.QaAutomationEngineer => "QA EMPHASIS: Playwright implementation, fixtures, locators, CI, API setup, mocking, and stable automation design.",
            InterviewRole.SeniorQaEngineer => "QA EMPHASIS: quality strategy, ownership, release risk, automation architecture, mentoring, observability, and maintainable CI feedback loops.",
            _ => string.Empty
        };

        public static string GetDisplayName(this ProgrammingLanguage lang) => lang switch
        {
            ProgrammingLanguage.Python => "Python",
            ProgrammingLanguage.TypeScript => "TypeScript",
            ProgrammingLanguage.JavaScript => "JavaScript",
            ProgrammingLanguage.Java => "Java",
            ProgrammingLanguage.CSharp => "C#",
            ProgrammingLanguage.Go => "Go",
            ProgrammingLanguage.Rust => "Rust",
            ProgrammingLanguage.Cpp => "C++",
            ProgrammingLanguage.Kotlin => "Kotlin",
            ProgrammingLanguage.Swift => "Swift",
            _ => lang.ToString()
        };

        public static string GetCodeBlockLanguage(this ProgrammingLanguage lang) => lang switch
        {
            ProgrammingLanguage.Python => "python",
            ProgrammingLanguage.TypeScript => "typescript",
            ProgrammingLanguage.JavaScript => "javascript",
            ProgrammingLanguage.Java => "java",
            ProgrammingLanguage.CSharp => "csharp",
            ProgrammingLanguage.Go => "go",
            ProgrammingLanguage.Rust => "rust",
            ProgrammingLanguage.Cpp => "cpp",
            ProgrammingLanguage.Kotlin => "kotlin",
            ProgrammingLanguage.Swift => "swift",
            _ => lang.ToString().ToLowerInvariant()
        };

        public static string GetDisplayName(this SpeakingLanguage lang) => lang switch
        {
            SpeakingLanguage.English => "English",
            SpeakingLanguage.Bulgarian => "Bulgarian",
            SpeakingLanguage.German => "German",
            SpeakingLanguage.Spanish => "Spanish",
            SpeakingLanguage.French => "French",
            SpeakingLanguage.Italian => "Italian",
            SpeakingLanguage.Portuguese => "Portuguese",
            SpeakingLanguage.Russian => "Russian",
            SpeakingLanguage.Chinese => "Chinese",
            SpeakingLanguage.Japanese => "Japanese",
            SpeakingLanguage.Korean => "Korean",
            SpeakingLanguage.Dutch => "Dutch",
            SpeakingLanguage.Polish => "Polish",
            SpeakingLanguage.Turkish => "Turkish",
            SpeakingLanguage.Hindi => "Hindi",
            _ => lang.ToString()
        };

        public static string GetLanguageCode(this SpeakingLanguage lang) => lang switch
        {
            SpeakingLanguage.English => "en",
            SpeakingLanguage.Bulgarian => "bg",
            SpeakingLanguage.German => "de",
            SpeakingLanguage.Spanish => "es",
            SpeakingLanguage.French => "fr",
            SpeakingLanguage.Italian => "it",
            SpeakingLanguage.Portuguese => "pt",
            SpeakingLanguage.Russian => "ru",
            SpeakingLanguage.Chinese => "zh",
            SpeakingLanguage.Japanese => "ja",
            SpeakingLanguage.Korean => "ko",
            SpeakingLanguage.Dutch => "nl",
            SpeakingLanguage.Polish => "pl",
            SpeakingLanguage.Turkish => "tr",
            SpeakingLanguage.Hindi => "hi",
            _ => "en"
        };

        public static string GetDisplayName(this CaptureDevice device) => device switch
        {
            CaptureDevice.Microphone => "Microphone",
            CaptureDevice.SystemAudio => "System audio",
            CaptureDevice.Both => "System + Mic",
            _ => device.ToString()
        };

        public static string GetDisplayName(this AnswerModel model) => model switch
        {
            AnswerModel.Claude => "Claude (Anthropic)",
            AnswerModel.Grok => "Grok (xAI)",
            AnswerModel.Gpt => "GPT (OpenAI)",
            _ => model.ToString()
        };
    }
}
