using System;
using System.Collections.Generic;
using System.Linq;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Role/position being interviewed for.
    /// Migrated from Swift: InterviewRole enum
    /// </summary>
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

    /// <summary>
    /// Primary programming language for code solutions.
    /// Migrated from Swift: ProgrammingLanguage enum
    /// </summary>
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

    /// <summary>
    /// Language for AI responses (code stays in English).
    /// Migrated from Swift: SpeakingLanguage enum
    /// </summary>
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

    /// <summary>
    /// Extension methods for enum display names.
    /// </summary>
    public static class EnumExtensions
    {
        public static string GetDisplayName(this InterviewRole role)
        {
            return role switch
            {
                InterviewRole.SeniorQaEngineer => "Senior QA Engineer",
                InterviewRole.QaEngineer => "QA Engineer",
                InterviewRole.QaAutomationEngineer => "QA Automation Engineer",
                InterviewRole.Sdet => "SDET",
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
        }

        public static bool IsSenior(this InterviewRole role)
        {
            return role.GetDisplayName().Contains("Senior");
        }

        public static string GetDisplayName(this ProgrammingLanguage language)
        {
            return language switch
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
                _ => language.ToString()
            };
        }

        public static string GetCodeBlockLanguage(this ProgrammingLanguage language)
        {
            return language switch
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
                _ => language.ToString().ToLower()
            };
        }

        public static string GetDisplayName(this SpeakingLanguage language)
        {
            return language switch
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
                _ => language.ToString()
            };
        }

        public static string GetLanguageCode(this SpeakingLanguage language)
        {
            return language switch
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
        }
    }
}

