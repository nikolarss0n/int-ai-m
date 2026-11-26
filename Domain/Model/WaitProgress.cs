using System;
using System.Collections.Generic;
using System.Linq;

namespace InterviewMasterApp.Domain.Model
{
    public enum WaitStage
    {
        Brief,
        Counting,
        Stalled
    }

    public static class WaitProgress
    {
        public const double ShowSecondsAfter = 4.0;
        public const double StalledAfter = 10.0;

        public static WaitStage Stage(double elapsedSeconds)
        {
            if (elapsedSeconds >= StalledAfter) return WaitStage.Stalled;
            if (elapsedSeconds >= ShowSecondsAfter) return WaitStage.Counting;
            return WaitStage.Brief;
        }

        public static string Format(double elapsedSeconds)
        {
            var whole = Math.Max(0, (int)elapsedSeconds);
            return whole < 60 ? $"{whole}s" : $"{whole / 60}m {whole % 60:D2}s";
        }

        public static string AnswerStatus(bool queued, double elapsedSeconds, string separator = " · ")
        {
            if (queued) return "Queued";
            return Status("Generating", "Still generating", elapsedSeconds, separator);
        }

        public static string AnswerStatusShort(bool queued, double elapsedSeconds)
        {
            if (queued) return "Queued";
            return Stage(elapsedSeconds) == WaitStage.Brief ? "Generating" : Format(elapsedSeconds);
        }

        public static string CodeStatus(double elapsedSeconds, string separator = " · ") =>
            Status("Writing", "Still writing", elapsedSeconds, separator);

        private static string Status(string brief, string stalled, double elapsedSeconds, string separator) =>
            Stage(elapsedSeconds) switch
            {
                WaitStage.Brief => brief,
                WaitStage.Counting => brief + separator + Format(elapsedSeconds),
                WaitStage.Stalled => stalled + separator + Format(elapsedSeconds),
                _ => brief
            };
    }

    public sealed class DelayedActivity
    {
        public double ShowAfterSeconds { get; }
        public double ExpireAfterSeconds { get; }
        private readonly Dictionary<Guid, DateTime> _starts = new();

        public DelayedActivity(double showAfterSeconds, double expireAfterSeconds)
        {
            ShowAfterSeconds = showAfterSeconds;
            ExpireAfterSeconds = expireAfterSeconds;
        }

        public bool IsEmpty => _starts.Count == 0;

        public void Begin(Guid id, DateTime now)
        {
            if (!_starts.ContainsKey(id)) _starts[id] = now;
        }

        public void End(Guid id) => _starts.Remove(id);

        public void RemoveAll() => _starts.Clear();

        public bool IsShowing(DateTime now) =>
            _starts.Values.Any(start =>
            {
                var age = (now - start).TotalSeconds;
                return age >= ShowAfterSeconds && age < ExpireAfterSeconds;
            });

        public DateTime? NextChange(DateTime now)
        {
            DateTime? earliest = null;
            foreach (var start in _starts.Values)
            {
                var t1 = start.AddSeconds(ShowAfterSeconds);
                if (t1 > now && (!earliest.HasValue || t1 < earliest.Value)) earliest = t1;
                var t2 = start.AddSeconds(ExpireAfterSeconds);
                if (t2 > now && (!earliest.HasValue || t2 < earliest.Value)) earliest = t2;
            }
            return earliest;
        }
    }
}
