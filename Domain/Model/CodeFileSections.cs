using System;
using System.Collections.Generic;
using System.Linq;

namespace InterviewMasterApp.Domain.Model
{
    public sealed record CodeChunk(int Number, string Why, string Code, int FirstLine, bool RepeatsEarlierCode);

    public sealed class CodeFileSection
    {
        public string FileName { get; }
        public string Language { get; }
        public List<CodeChunk> Chunks { get; }

        public CodeFileSection(string fileName, string language, List<CodeChunk>? chunks = null)
        {
            FileName = fileName;
            Language = language;
            Chunks = chunks ?? new List<CodeChunk>();
        }

        public string Code => string.Join("\n\n", Chunks.Select(c => c.Code).Where(c => !string.IsNullOrEmpty(c)));
    }

    public sealed class CodeLineChanges
    {
        public HashSet<int> Changed { get; } = new();
        public HashSet<int> RemovedBefore { get; } = new();
    }

    public static class CodeFileSectionsHelper
    {
        public static List<CodeFileSection> GroupCodeSteps(IReadOnlyList<CodingInterviewStep> steps)
        {
            var sections = new List<CodeFileSection>();
            int nextLine = 0;
            var seenLines = new HashSet<string>(StringComparer.Ordinal);

            foreach (var step in steps)
            {
                if (sections.Count == 0 || !string.Equals(sections[^1].FileName, step.FileName, StringComparison.Ordinal))
                {
                    sections.Add(new CodeFileSection(step.FileName, step.Language));
                    nextLine = 0;
                    seenLines.Clear();
                }

                var lines = string.IsNullOrEmpty(step.Code)
                    ? Array.Empty<string>()
                    : step.Code.Replace("\r\n", "\n").Split('\n');
                var meaningful = lines.Select(l => l.Trim()).Where(l => l.Length > 2).ToList();
                var repeated = meaningful.Count(seenLines.Contains);
                var repeatsEarlier = meaningful.Count >= 2 && repeated * 2 >= meaningful.Count;

                sections[^1].Chunks.Add(new CodeChunk(step.Number, step.Why, step.Code, nextLine, repeatsEarlier));
                foreach (var m in meaningful) seenLines.Add(m);
                if (lines.Length > 0) nextLine += lines.Length + 1;
            }

            return sections;
        }

        public static CodeLineChanges? ComputeLineChanges(string oldCode, string newCode)
        {
            var oldLines = (oldCode ?? string.Empty).Replace("\r\n", "\n").Split('\n');
            var newLines = (newCode ?? string.Empty).Replace("\r\n", "\n").Split('\n');
            if ((long)oldLines.Length * newLines.Length > 400_000) return null;

            var lengths = new int[oldLines.Length + 1, newLines.Length + 1];
            for (int i = oldLines.Length - 1; i >= 0; i--)
            {
                for (int j = newLines.Length - 1; j >= 0; j--)
                {
                    lengths[i, j] = oldLines[i] == newLines[j]
                        ? lengths[i + 1, j + 1] + 1
                        : Math.Max(lengths[i + 1, j], lengths[i, j + 1]);
                }
            }

            var changes = new CodeLineChanges();
            int keptLines = 0, oi = 0, ni = 0, removedInGap = 0, addedInGap = 0;

            void CloseGap(int line)
            {
                if (removedInGap > addedInGap) changes.RemovedBefore.Add(line);
                removedInGap = 0;
                addedInGap = 0;
            }

            while (oi < oldLines.Length || ni < newLines.Length)
            {
                if (oi < oldLines.Length && ni < newLines.Length && oldLines[oi] == newLines[ni])
                {
                    CloseGap(ni);
                    if (!string.IsNullOrWhiteSpace(newLines[ni])) keptLines++;
                    oi++;
                    ni++;
                }
                else if (ni < newLines.Length && (oi == oldLines.Length || lengths[oi, ni + 1] >= lengths[oi + 1, ni]))
                {
                    if (!string.IsNullOrWhiteSpace(newLines[ni]))
                    {
                        changes.Changed.Add(ni);
                        addedInGap++;
                    }
                    ni++;
                }
                else
                {
                    if (!string.IsNullOrWhiteSpace(oldLines[oi])) removedInGap++;
                    oi++;
                }
            }
            CloseGap(newLines.Length);

            var total = keptLines + changes.Changed.Count;
            if (total == 0 || keptLines * 10 < total * 4) return null;
            return changes;
        }
    }
}
