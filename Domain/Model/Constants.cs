using System;
using System.Collections.Generic;
using System.Text;

namespace InterviewMasterApp.Domain.Model
{
    public enum SurfaceTransparency
    {
        Solid,
        Balanced
    }

    public static class SurfaceTransparencyExtensions
    {
        public static string GetTitle(this SurfaceTransparency value) => value switch
        {
            SurfaceTransparency.Solid => "Solid",
            SurfaceTransparency.Balanced => "Floating",
            _ => "Floating"
        };
    }

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
            public const double HorizontalInset = 20;
            public const double BadgeSize = 22;
            public const double BadgeGap = 8;
            public const double AnswerIndent = 20;
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

    public static class AppConstants
    {
        public static class Models
        {
            public const string AnthropicHaiku = "claude-haiku-4-5-20251001";
            public const string XaiGrok = "grok-4.20-0309-non-reasoning";
            public const string OpenAiDefault = "gpt-5.5";
            public const string GroqWhisper = "whisper-large-v3-turbo";
            public const string GroqFastClassification = "openai/gpt-oss-20b";
            public const string GroqFastAnswer = "openai/gpt-oss-20b";
            public const string GroqLlama = "llama-3.3-70b-versatile";
            public const string GroqChatModel = GroqFastAnswer;
        }

        public static class ApiUrls
        {
            public const string AnthropicMessages = "https://api.anthropic.com/v1/messages";
            public const string XaiChat = "https://api.x.ai/v1/chat/completions";
            public const string OpenAiChat = "https://api.openai.com/v1/chat/completions";
            public const string GroqTranscriptions = "https://api.groq.com/openai/v1/audio/transcriptions";
            public const string GroqChat = "https://api.groq.com/openai/v1/chat/completions";
        }

        public static class Thresholds
        {
            public const double DedupeWindow = 5.0;
            public const double SimilarityThreshold = 0.5;
            public const double BufferTimeout = 10.0;
            public const double BufferedQuestionSilence = 2.5;
            public const double QuestionContinuationWindow = 5.0;
            public const double AnswerCooldown = 12.0;
            public const float SpeechThreshold = 0.5f;
            public const double SilenceTimeout = 0.65;
            public const double SpeculativeSilenceTimeout = 0.25;
            public const double MinSpeechDuration = 0.5;
            public const double DirectHaikuFirstChunkTimeout = 1.1;
            public const double DirectGptFirstChunkTimeout = 4.0;
            public const int SlidingWindowSize = 6;
            public const int SummarizationThreshold = 10;
            public const int MaxConversationHistory = 50;
        }

        public static class MaxTokens
        {
            public const int Classification = 320;
            public const int OpenAiReasoningAllowance = 4000;
            public const int AnswerStream = 450;
            public const int Summarization = 150;
            public const int ImageAnalysis = 4096;
            public const int CodingSteps = 1800;
            public const int GroqAnswer = 280;
            public const int GroqClassification = 240;
            public const int FollowUp = 350;
            public const int MemoryContext = 200;
            public const int SessionAnalysis = 300;
        }

        public static class Limits
        {
            public const int GroqWhisperPromptBytes = 896;
        }
    }

    public enum SpeechTurnEmit
    {
        SpeculativePreview,
        SpeechResumedAfterPreview,
        FinalSilence
    }

    public enum SpeechTurnAction
    {
        PrefetchTranscriptionOnly,
        CancelInFlightWork,
        CommitAnswer
    }

    public static class SpeechTurnPolicy
    {
        public static SpeechTurnAction Action(SpeechTurnEmit emit) => emit switch
        {
            SpeechTurnEmit.SpeculativePreview => SpeechTurnAction.PrefetchTranscriptionOnly,
            SpeechTurnEmit.SpeechResumedAfterPreview => SpeechTurnAction.CancelInFlightWork,
            SpeechTurnEmit.FinalSilence => SpeechTurnAction.CommitAnswer,
            _ => SpeechTurnAction.CommitAnswer
        };

        public static bool StartsAnswerCard(SpeechTurnAction action) => action == SpeechTurnAction.CommitAnswer;
    }

    public static class GroqRequestTuning
    {
        public const string CueCardPrefill = "- ";

        public static (string Filename, string MimeType) TranscriptionUpload(byte[] audioData)
        {
            if (audioData != null && audioData.Length >= 12)
            {
                if (audioData[0] == 'R' && audioData[1] == 'I' && audioData[2] == 'F' && audioData[3] == 'F' &&
                    audioData[8] == 'W' && audioData[9] == 'A' && audioData[10] == 'V' && audioData[11] == 'E')
                {
                    return ("audio.wav", "audio/wav");
                }
            }
            if (audioData != null && audioData.Length >= 8)
            {
                if (audioData[4] == 'f' && audioData[5] == 't' && audioData[6] == 'y' && audioData[7] == 'p')
                {
                    return ("audio.m4a", "audio/mp4");
                }
            }
            return ("audio.wav", "audio/wav");
        }

        public static Dictionary<string, object> ChatReasoningFields(string model)
        {
            if (string.IsNullOrEmpty(model)) return new Dictionary<string, object>();
            if (model.StartsWith("openai/gpt-oss", StringComparison.OrdinalIgnoreCase))
            {
                return new Dictionary<string, object>
                {
                    ["reasoning_effort"] = "low",
                    ["include_reasoning"] = false
                };
            }
            if (model.StartsWith("qwen/", StringComparison.OrdinalIgnoreCase))
            {
                return new Dictionary<string, object>
                {
                    ["reasoning_effort"] = "none"
                };
            }
            return new Dictionary<string, object>();
        }

        public static List<Dictionary<string, string>> ChatMessages(string userPrompt) => new()
        {
            new Dictionary<string, string> { ["role"] = "user", ["content"] = userPrompt },
            new Dictionary<string, string> { ["role"] = "assistant", ["content"] = CueCardPrefill }
        };

        public static string VisibleCueCardPrefix(string firstChunk)
        {
            var trimmed = (firstChunk ?? string.Empty).Trim();
            return trimmed.StartsWith("-", StringComparison.Ordinal) ? string.Empty : CueCardPrefill;
        }
    }
}
