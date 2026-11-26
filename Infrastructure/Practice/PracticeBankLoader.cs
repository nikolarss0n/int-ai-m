using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using InterviewMasterApp.Domain.Practice;

namespace InterviewMasterApp.Infrastructure.Practice
{
    public static class PracticeBankLoader
    {
        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNameCaseInsensitive = true
        };

        public static PracticeBankFile Decode(string json) =>
            JsonSerializer.Deserialize<PracticeBankFile>(json, JsonOptions) ?? new PracticeBankFile();

        public static PracticeBankFile LoadFromFile(string path) => Decode(File.ReadAllText(path));

        public static PracticeBankFile LoadDirectory(string directory)
        {
            if (string.IsNullOrEmpty(directory) || !Directory.Exists(directory))
                return new PracticeBankFile();

            var packs = new List<PracticeTopicPack>();
            var positions = new List<PracticePosition>();
            var seen = new HashSet<string>(StringComparer.Ordinal);

            foreach (var file in Directory.GetFiles(directory, "*.json").OrderBy(f => f, StringComparer.OrdinalIgnoreCase))
            {
                try
                {
                    var bank = LoadFromFile(file);
                    foreach (var pack in bank.Packs)
                    {
                        if (seen.Add(pack.Id)) packs.Add(pack);
                    }
                    positions.AddRange(bank.Positions);
                }
                catch { }
            }

            return new PracticeBankFile { Packs = packs, Positions = positions };
        }

        public static PracticeBankFile Load()
        {
            string[] candidates =
            {
                Path.Combine(AppContext.BaseDirectory, "Resources", "practice"),
                Path.Combine(AppContext.BaseDirectory, "practice"),
                Path.Combine(Directory.GetCurrentDirectory(), "Resources", "practice")
            };

            foreach (var dir in candidates)
            {
                var bank = LoadDirectory(dir);
                if (bank.Packs.Count > 0) return bank;
            }

            return new PracticeBankFile
            {
                Packs = PracticeTopicPack.BuiltInAll,
                Positions = PracticeTopicPack.BuiltInAll.Select(p => new PracticePosition
                {
                    Id = p.Id,
                    Title = p.Title,
                    PackId = p.Id
                }).ToList()
            };
        }
    }

    /// <summary>
    /// Isolated practice history under Documents\InterviewMaster\practice\.
    /// Never overwrites corrupt history files; moves corrupt in-progress files to a recovery copy.
    /// </summary>
    public sealed class PracticeStore
    {
        private static readonly Lazy<PracticeStore> _lazy = new(() => new PracticeStore());
        public static PracticeStore Shared => _lazy.Value;

        private readonly object _lock = new();
        private readonly string _runsPath;
        private readonly string _inProgressPath;
        private List<PracticeRunRecord> _runs = new();
        private PracticeSessionSnapshot? _inProgress;
        private bool _runsLoadFailed;
        private bool _inProgressLoadFailed;

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            WriteIndented = true,
            PropertyNameCaseInsensitive = true
        };

        private PracticeStore()
            : this(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "InterviewMaster", "practice"))
        {
        }

        public PracticeStore(string directoryPath)
        {
            try { Directory.CreateDirectory(directoryPath); } catch { }
            _runsPath = Path.Combine(directoryPath, "runs.json");
            _inProgressPath = Path.Combine(directoryPath, "in-progress.json");
            LoadRuns();
            LoadInProgress();
        }

        public IReadOnlyList<PracticeRunRecord> AllRuns()
        {
            lock (_lock) return _runs.ToList();
        }

        public bool Append(PracticeRunRecord run)
        {
            lock (_lock)
            {
                if (_runsLoadFailed) return false;
                var idx = _runs.FindIndex(r => r.Id == run.Id);
                if (idx >= 0) _runs[idx] = run;
                else _runs.Add(run);
                return SaveAtomic(_runsPath, _runs);
            }
        }

        public PracticeSessionSnapshot? InProgressSession()
        {
            lock (_lock) return _inProgress;
        }

        public bool SaveInProgressSession(PracticeSessionSnapshot snapshot)
        {
            lock (_lock)
            {
                if (_inProgressLoadFailed) return false;
                if (!SaveAtomic(_inProgressPath, snapshot)) return false;
                _inProgress = snapshot;
                return true;
            }
        }

        public bool ClearInProgressSession()
        {
            lock (_lock)
            {
                try
                {
                    if (File.Exists(_inProgressPath)) File.Delete(_inProgressPath);
                    _inProgress = null;
                    _inProgressLoadFailed = false;
                    return true;
                }
                catch { return false; }
            }
        }

        private void LoadRuns()
        {
            if (!File.Exists(_runsPath)) return;
            try
            {
                _runs = JsonSerializer.Deserialize<List<PracticeRunRecord>>(File.ReadAllText(_runsPath), JsonOptions) ?? new();
            }
            catch
            {
                _runsLoadFailed = true;
            }
        }

        private void LoadInProgress()
        {
            if (!File.Exists(_inProgressPath)) return;
            try
            {
                _inProgress = JsonSerializer.Deserialize<PracticeSessionSnapshot>(File.ReadAllText(_inProgressPath), JsonOptions);
            }
            catch
            {
                try
                {
                    var recovery = Path.Combine(
                        Path.GetDirectoryName(_inProgressPath)!,
                        $"in-progress-recovery-{Guid.NewGuid()}.json");
                    File.Move(_inProgressPath, recovery);
                }
                catch
                {
                    _inProgressLoadFailed = true;
                }
            }
        }

        private static bool SaveAtomic<T>(string path, T value)
        {
            try
            {
                var dir = Path.GetDirectoryName(path);
                if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
                var tmp = path + ".tmp";
                File.WriteAllText(tmp, JsonSerializer.Serialize(value, JsonOptions));
                File.Move(tmp, path, overwrite: true);
                return true;
            }
            catch
            {
                return false;
            }
        }
    }
}
