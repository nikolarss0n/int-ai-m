using System;
using System.Collections.Generic;

namespace InterviewMasterApp.Domain.Model
{
    public enum FeedbackKind
    {
        Info,
        Success,
        Warning,
        Error
    }

    public static class FeedbackKindExtensions
    {
        public static int Rank(this FeedbackKind kind) => kind switch
        {
            FeedbackKind.Info or FeedbackKind.Success => 0,
            FeedbackKind.Warning => 1,
            FeedbackKind.Error => 2,
            _ => 0
        };
    }

    public sealed record FeedbackNotice(
        string Key,
        FeedbackKind Kind,
        string Message,
        string? Detail = null,
        string? ActionTitle = null,
        double? LastsSeconds = null)
    {
        public const double ConfirmationHold = 3.5;
        public const double UndoHold = 8.0;

        public static FeedbackNotice Confirmation(string key, string message, string? detail = null, string? actionTitle = null) =>
            new(key, FeedbackKind.Success, message, detail, actionTitle, actionTitle == null ? ConfirmationHold : UndoHold);

        public static FeedbackNotice Info(string key, string message, string? detail = null, string? actionTitle = null) =>
            new(key, FeedbackKind.Info, message, detail, actionTitle, actionTitle == null ? ConfirmationHold : UndoHold);

        public static FeedbackNotice Error(string key, string message, string? detail = null, string? actionTitle = null) =>
            new(key, FeedbackKind.Error, message, detail, actionTitle, null);
    }

    public sealed class NoticeBoard
    {
        public FeedbackNotice? Current { get; private set; }
        private DateTime? _shownAt;

        public bool Show(FeedbackNotice notice, DateTime now)
        {
            Expire(now);
            if (Current != null && Current.Key != notice.Key && Current.Kind.Rank() > notice.Kind.Rank())
                return false;
            Current = notice;
            _shownAt = now;
            return true;
        }

        public void Dismiss()
        {
            Current = null;
            _shownAt = null;
        }

        public void Resolve(string key)
        {
            if (Current?.Key == key) Dismiss();
        }

        public void Expire(DateTime now)
        {
            if (Current?.LastsSeconds is double lasts && _shownAt.HasValue && (now - _shownAt.Value).TotalSeconds >= lasts)
                Dismiss();
        }

        public DateTime? Expiry =>
            Current?.LastsSeconds is double lasts && _shownAt.HasValue
                ? _shownAt.Value.AddSeconds(lasts)
                : null;
    }

    public static class FeedbackCopy
    {
        public enum Cause
        {
            Network,
            Timeout,
            KeyRejected,
            Busy,
            NoText,
            Other
        }

        public const string OpenSettings = "Open Settings";
        public const string TryAgain = "Try again";
        public const string ShowInExplorer = "Show in Explorer";
        public const string Export = "Export";
        public const string LastQuestionMissed = "The last question may not have been captured.";
        public const string DidntCatchThat = "Didn't catch that. Ask again.";

        public static Cause CauseOf(string message)
        {
            var lower = ReasonIn(message).ToLowerInvariant();
            if (lower.Contains("no answer text")) return Cause.NoText;
            if (lower.Contains("timed out") || lower.Contains("timeout")) return Cause.Timeout;
            if (lower.Contains("network") || lower.Contains("offline") || lower.Contains("connection") || lower.Contains("internet")) return Cause.Network;
            if (lower.Contains("401") || lower.Contains("unauthorized") || lower.Contains("api key") || lower.Contains("x-api-key")) return Cause.KeyRejected;
            if (lower.Contains("429") || lower.Contains("rate limit") || lower.Contains("overloaded")) return Cause.Busy;
            return Cause.Other;
        }

        public static FeedbackNotice? NoticeForStatus(string message)
        {
            var text = (message ?? string.Empty).Trim();
            if (text == DidntCatchThat) return FeedbackNotice.Confirmation("heard", text);
            if (!text.StartsWith("error:", StringComparison.OrdinalIgnoreCase)) return null;
            var detail = ReasonIn(text);

            return CauseOf(detail) switch
            {
                Cause.Network => FeedbackNotice.Error("pipeline", "Couldn't transcribe. Check your connection.", $"Transcription needs a connection to Groq. {LastQuestionMissed}"),
                Cause.Timeout => FeedbackNotice.Error("pipeline", "Transcription timed out. Ask again.", $"{LastQuestionMissed} If it keeps happening, check your connection."),
                Cause.KeyRejected => FeedbackNotice.Error("pipeline", "Groq API key rejected", $"{LastQuestionMissed} Check the key in Settings.", OpenSettings),
                Cause.Busy => FeedbackNotice.Error("pipeline", "Transcription is busy. Ask again in a moment.", $"{LastQuestionMissed} The service is handling too many requests."),
                _ => FeedbackNotice.Error("pipeline", "Couldn't transcribe. Ask again.",
                    string.IsNullOrEmpty(detail) ? LastQuestionMissed : $"{Sentence(detail)} {LastQuestionMissed}")
            };
        }

        public static string FailureReason(string message)
        {
            var text = ReasonIn(message);
            switch (CauseOf(text))
            {
                case Cause.NoText: return "The model sent back no text.";
                case Cause.Timeout: return "The model took too long to answer.";
                case Cause.Network: return "The network connection failed. Check it, then try again.";
                case Cause.KeyRejected: return "The API key was rejected. Check it in Settings.";
                case Cause.Busy: return "The service is busy. Wait a moment and try again.";
            }

            if (string.IsNullOrEmpty(text)) return "The model did not answer.";
            var dotIdx = text.IndexOf('.');
            var firstSentence = dotIdx > 0 ? text[..dotIdx] : text;
            var clipped = firstSentence.Length > 90 ? firstSentence[..89] + "…" : firstSentence;
            return Sentence(clipped);
        }

        public static readonly FeedbackNotice NothingToAnalyze = FeedbackNotice.Info(
            "analyze", "No screenshots yet. Press Ctrl+Alt+S to capture one.", "Then press Ctrl+Alt+Enter to analyze.");

        public static readonly FeedbackNotice ClickThroughOn = FeedbackNotice.Info(
            "clickThrough", "Click-through is on. Press Ctrl+Alt+I to use this window.");

        public static readonly FeedbackNotice NothingToExport = FeedbackNotice.Info(
            "export", "Nothing to export yet", "Export saves the questions and answers from an interview. Start one first.");

        public static FeedbackNotice Exported(string fileName, string path) =>
            FeedbackNotice.Confirmation("export", $"Exported {fileName}", path, ShowInExplorer);

        public static FeedbackNotice SessionSaved(string path) =>
            FeedbackNotice.Confirmation("session", "Session saved", path, ShowInExplorer);

        public static FeedbackNotice SessionNotSaved(string reason) =>
            FeedbackNotice.Error("session", "Couldn't save the session", $"{Sentence(reason)} Export keeps a copy somewhere else.", Export);

        public static FeedbackNotice ScreenshotFailed(string detail) =>
            FeedbackNotice.Error("screenshot", "Couldn't capture the screenshot", detail, TryAgain);

        public static string? Cleared(int screenshots, bool pinnedCode) => Summary("Cleared", screenshots, pinnedCode);
        public static string? Restored(int screenshots, bool pinnedCode) => Summary("Restored", screenshots, pinnedCode);

        public static string Sentence(string text)
        {
            var trimmed = (text ?? string.Empty).Trim();
            if (string.IsNullOrEmpty(trimmed)) return string.Empty;
            var last = trimmed[^1];
            return (last is '.' or '!' or '?' or '…') ? trimmed : trimmed + ".";
        }

        private static string ReasonIn(string message)
        {
            var text = (message ?? string.Empty).Trim();
            return text.StartsWith("error:", StringComparison.OrdinalIgnoreCase)
                ? text[6..].Trim()
                : text;
        }

        private static string? Summary(string verb, int screenshots, bool pinnedCode)
        {
            var parts = new List<string>();
            if (screenshots > 0) parts.Add(screenshots == 1 ? "1 screenshot" : $"{screenshots} screenshots");
            if (pinnedCode) parts.Add("the pinned code");
            return parts.Count == 0 ? null : $"{verb} {string.Join(" and ", parts)}";
        }
    }
}
