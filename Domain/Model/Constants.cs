using System;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Application constants for models, APIs, and thresholds.
    /// Migrated from Swift: Constants.swift
    /// </summary>
    public static class LayoutConstants
    {
        public static class Typography
        {
            public const double Hero = 24;
            public const double H1 = 20;
            public const double H2 = 18;
            public const double Body = 15;
            public const double BodyLarge = 17;
            public const double Caption = 13;
            public const double CaptionSmall = 11;
            public const double Micro = 10;
            public const double Code = 14;
        }

        public static class Spacing
        {
            public const double Xs = 4;
            public const double Sm = 8;
            public const double Md = 12;
            public const double Lg = 20;
            public const double Xl = 30;
        }

        public static class CornerRadius
        {
            public const double Small = 6;
            public const double Medium = 10;
            public const double Large = 14;
            public const double Pill = 16;
        }

        public static class IconButton
        {
            public const double Size = 32;
            public const double IconSize = 16;
            public const double Spacing = 8;
        }

        public static class Toolbar
        {
            public const double Height = 40;
            public const double DropdownHeight = 26;
        }

        public static class Timeline
        {
            public const double MessageSpacing = 15;
            public const double MessagePadding = 10;
            public const double BadgeSize = 22;
            public const double BadgeGap = 8;
            public const double AccentBarWidth = 3;
        }

        public static class Animation
        {
            public const double Fast = 0.1;
            public const double Normal = 0.15;
            public const double Slow = 0.25;
            public const double Pulse = 0.5;
        }

        public static class Alpha
        {
            public const double ActiveBackground = 0.15;
            public const double InactiveBackground = 0.08;
            public const double HoverBackground = 0.12;
            public const double SubtleText = 0.5;
            public const double SecondaryText = 0.7;
        }
    }

    /// <summary>
    /// Application-wide constants for models, APIs, and thresholds.
    /// </summary>
    public static class AppConstants
    {
        public static class Models
        {
            public const string AnthropicHaiku = "claude-haiku-4-5-20251001";
            public const string GroqWhisper = "whisper-large-v3";
            public const string GroqLlama = "llama-3.3-70b-versatile";
        }

        public static class ApiUrls
        {
            public const string AnthropicMessages = "https://api.anthropic.com/v1/messages";
            public const string GroqTranscriptions = "https://api.groq.com/openai/v1/audio/transcriptions";
            public const string GroqChat = "https://api.groq.com/openai/v1/chat/completions";
        }

        public static class Thresholds
        {
            public const double DedupeWindow = 5.0;          // seconds
            public const double SimilarityThreshold = 0.5;
            public const double BufferTimeout = 10.0;         // seconds
            public const double AnswerCooldown = 12.0;        // seconds
            public const float SpeechThreshold = 0.5f;
            public const double SilenceTimeout = 0.65;        // seconds
            public const double MinSpeechDuration = 0.5;      // seconds
            public const int SlidingWindowSize = 6;
            public const int SummarizationThreshold = 10;
            public const int MaxConversationHistory = 50;
        }

        public static class MaxTokens
        {
            public const int Classification = 450;
            public const int AnswerStream = 250;
            public const int Summarization = 150;
            public const int ImageAnalysis = 4096;
            public const int GroqAnswer = 200;
            public const int GroqClassification = 20;
            public const int FollowUp = 200;
        }
    }
}

