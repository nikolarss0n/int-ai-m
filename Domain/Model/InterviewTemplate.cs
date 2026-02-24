using System;
using System.Collections.Generic;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Interview template with questions.
    /// Migrated from Swift: InterviewTemplate.swift
    /// </summary>
    public class InterviewTemplate
    {
        public enum Category
        {
            Behavioral,
            SystemDesign,
            Coding,
            LanguageSpecific
        }

        public string Id { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public Category TemplateCategory { get; set; }
        public List<TemplateQuestion> Questions { get; set; }

        public string CategoryDisplayName
        {
            get
            {
                return TemplateCategory switch
                {
                    Category.Behavioral => "Behavioral",
                    Category.SystemDesign => "System Design",
                    Category.Coding => "Coding",
                    Category.LanguageSpecific => "Language-Specific",
                    _ => TemplateCategory.ToString()
                };
            }
        }

        public InterviewTemplate()
        {
            Questions = new List<TemplateQuestion>();
        }

        public override string ToString()
        {
            return $"InterviewTemplate(Name={Name}, Questions={Questions.Count})";
        }
    }

    /// <summary>
    /// A question within an interview template.
    /// Migrated from Swift: TemplateQuestion.swift
    /// </summary>
    public class TemplateQuestion
    {
        public enum Difficulty
        {
            Easy,
            Medium,
            Hard
        }

        public string Text { get; set; } = string.Empty;
        public string Topic { get; set; } = string.Empty;
        public Difficulty QuestionDifficulty { get; set; }
        public List<string> Hints { get; set; }

        public string DifficultyDisplayName
        {
            get
            {
                return QuestionDifficulty switch
                {
                    Difficulty.Easy => "Easy",
                    Difficulty.Medium => "Medium",
                    Difficulty.Hard => "Hard",
                    _ => QuestionDifficulty.ToString()
                };
            }
        }

        public TemplateQuestion()
        {
            Hints = new List<string>();
        }

        public TemplateQuestion(string text, string topic, Difficulty difficulty, List<string>? hints = null)
        {
            Text = text ?? string.Empty;
            Topic = topic ?? string.Empty;
            QuestionDifficulty = difficulty;
            Hints = hints ?? new List<string>();
        }

        public override string ToString()
        {
            var safeText = Text ?? string.Empty;
            return $"TemplateQuestion(Text={safeText.Substring(0, Math.Min(30, safeText.Length))}, " +
                   $"Difficulty={DifficultyDisplayName})";
        }
    }
}

