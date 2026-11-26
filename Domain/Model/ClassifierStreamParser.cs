using System;
using System.Linq;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Incremental parser for combined classify-and-answer replies:
    /// STATUS:question|TOPIC:oop
    /// ---
    /// - answer bullet
    /// </summary>
    public static class ClassifierStreamParser
    {
        public sealed record ParseResult(string? StatusLine, bool FormatDrift, string Answer);

        private const int DriftProbeLength = 12;

        public static ParseResult Parse(string fullText, bool headerless = false, bool streamEnded = false)
        {
            var text = (fullText ?? string.Empty).TrimStart();
            if (headerless)
                return new ParseResult(null, false, VisibleAnswer(text, streamEnded));
            if (string.IsNullOrEmpty(text))
                return new ParseResult(null, false, string.Empty);

            var newline = text.IndexOf('\n');
            if (newline < 0)
            {
                if (IsStatusLine(text))
                    return new ParseResult(streamEnded ? text : null, false, string.Empty);

                var lowerPrefix = text.Length <= 7 ? text.ToLowerInvariant() : text[..7].ToLowerInvariant();
                var couldStillBeHeader = !streamEnded && text.Length < DriftProbeLength &&
                                         "status:".StartsWith(lowerPrefix, StringComparison.Ordinal);
                if (couldStillBeHeader)
                    return new ParseResult(null, false, string.Empty);

                return Drift(text, streamEnded);
            }

            var firstLine = text[..newline].TrimEnd('\r');
            if (IsStatusLine(firstLine))
            {
                var rest = text[(newline + 1)..];
                return new ParseResult(firstLine, false, VisibleAnswer(rest, streamEnded));
            }

            return Drift(text, streamEnded);
        }

        private static bool IsStatusLine(string line) =>
            line.Contains("status:", StringComparison.OrdinalIgnoreCase);

        private static ParseResult Drift(string text, bool streamEnded)
        {
            var kept = text.Split('\n').Where(rawLine =>
            {
                var trimmed = rawLine.Trim();
                if (IsStatusLine(trimmed)) return false;
                if (trimmed.Length >= 3 && trimmed.All(c => c == '-')) return false;
                return true;
            });
            var answer = VisibleAnswer(string.Join("\n", kept), streamEnded);
            return new ParseResult(null, true, answer);
        }

        private static string VisibleAnswer(string text, bool streamEnded)
        {
            var body = (text ?? string.Empty).TrimStart();
            if (body.StartsWith("---", StringComparison.Ordinal))
            {
                body = body.TrimStart('-').TrimStart();
                return body;
            }
            if (!streamEnded && (body == "-" || body == "--"))
                return string.Empty;
            return body;
        }
    }
}
