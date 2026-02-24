using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Global app settings with persistent storage.
    /// Migrated from Swift: AppSettings.swift
    /// Windows: Uses IsolatedStorageSettings or registry for persistence
    /// </summary>
    public class AppSettings
    {
        private static AppSettings? _instance;
        private static readonly object _lock = new object();

        // Settings keys
        private const string RoleKey = "InterviewMaster.Role";
        private const string ProgrammingLanguageKey = "InterviewMaster.ProgrammingLanguage";
        private const string SpeakingLanguageKey = "InterviewMaster.SpeakingLanguage";
        private const string FrameworksKey = "InterviewMaster.Frameworks";

        // Default settings
        private InterviewRole _role = InterviewRole.BackendDeveloper;
        private ProgrammingLanguage _programmingLanguage = ProgrammingLanguage.Python;
        private SpeakingLanguage _speakingLanguage = SpeakingLanguage.English;
        private string _frameworks = "";

        /// <summary>
        /// Singleton instance following iOS pattern.
        /// </summary>
        public static AppSettings Shared
        {
            get
            {
                if (_instance == null)
                {
                    lock (_lock)
                    {
                        if (_instance == null)
                        {
                            _instance = new AppSettings();
                            _instance.Load();
                        }
                    }
                }
                return _instance;
            }
        }

        private AppSettings()
        {
        }

        // MARK: - Role Property

        public InterviewRole Role
        {
            get => _role;
            set
            {
                _role = value;
                SaveSetting(RoleKey, value.ToString());
                OnSettingsChanged?.Invoke();
            }
        }

        // MARK: - Programming Language Property

        public ProgrammingLanguage ProgrammingLanguage
        {
            get => _programmingLanguage;
            set
            {
                _programmingLanguage = value;
                SaveSetting(ProgrammingLanguageKey, value.ToString());
                OnSettingsChanged?.Invoke();
            }
        }

        // MARK: - Speaking Language Property

        public SpeakingLanguage SpeakingLanguage
        {
            get => _speakingLanguage;
            set
            {
                _speakingLanguage = value;
                SaveSetting(SpeakingLanguageKey, value.ToString());
                OnSettingsChanged?.Invoke();
            }
        }

        // MARK: - Frameworks Property

        public string Frameworks
        {
            get => _frameworks;
            set
            {
                _frameworks = value ?? "";
                SaveSetting(FrameworksKey, _frameworks);
                OnSettingsChanged?.Invoke();
            }
        }

        // MARK: - Computed Properties

        public string RoleDisplayName => _role.GetDisplayName();
        public string LanguageDisplayName => _programmingLanguage.GetDisplayName();
        public string ResponseLanguageDisplayName => _speakingLanguage.GetDisplayName();
        public bool IsSeniorRole => _role.IsSenior();
        /// <summary>
        /// Placeholder for language-specific instructions that are appended to prompts.
        /// In the Swift app this was `languageInstruction`; keep a simple placeholder until localization is implemented.
        /// </summary>
        public string LanguageInstruction => "";

        // MARK: - Events

        public event Action? OnSettingsChanged;

        // MARK: - Persistence Methods

        private static string SettingsFilePath
        {
            get
            {
                var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                return Path.Combine(appData, "InterviewMaster", "settings.json");
            }
        }

        /// <summary>
        /// Load settings from JSON file at %APPDATA%/InterviewMaster/settings.json.
        /// </summary>
        private void Load()
        {
            try
            {
                if (!File.Exists(SettingsFilePath)) return;

                var json = File.ReadAllText(SettingsFilePath);
                var dict = JsonSerializer.Deserialize<Dictionary<string, string>>(json);
                if (dict == null) return;

                if (dict.TryGetValue(RoleKey, out var roleStr) && Enum.TryParse<InterviewRole>(roleStr, out var role))
                    _role = role;
                if (dict.TryGetValue(ProgrammingLanguageKey, out var langStr) && Enum.TryParse<ProgrammingLanguage>(langStr, out var lang))
                    _programmingLanguage = lang;
                if (dict.TryGetValue(SpeakingLanguageKey, out var speakStr) && Enum.TryParse<SpeakingLanguage>(speakStr, out var speak))
                    _speakingLanguage = speak;
                if (dict.TryGetValue(FrameworksKey, out var frameworks))
                    _frameworks = frameworks;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to load settings: {ex.Message}");
            }
        }

        /// <summary>
        /// Save a setting to JSON file at %APPDATA%/InterviewMaster/settings.json.
        /// </summary>
        private void SaveSetting(string key, string value)
        {
            try
            {
                var dir = Path.GetDirectoryName(SettingsFilePath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                    Directory.CreateDirectory(dir);

                var dict = new Dictionary<string, string>
                {
                    { RoleKey, _role.ToString() },
                    { ProgrammingLanguageKey, _programmingLanguage.ToString() },
                    { SpeakingLanguageKey, _speakingLanguage.ToString() },
                    { FrameworksKey, _frameworks }
                };

                var json = JsonSerializer.Serialize(dict, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(SettingsFilePath, json);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to save setting {key}: {ex.Message}");
            }
        }

        /// <summary>
        /// Reset all settings to defaults.
        /// </summary>
        public void ResetToDefaults()
        {
            _role = InterviewRole.BackendDeveloper;
            _programmingLanguage = ProgrammingLanguage.Python;
            _speakingLanguage = SpeakingLanguage.English;
            _frameworks = "";
            OnSettingsChanged?.Invoke();
        }

        /// <summary>
        /// Export settings as dictionary.
        /// </summary>
        public Dictionary<string, string> ExportSettings()
        {
            return new Dictionary<string, string>
            {
                { RoleKey, _role.ToString() },
                { ProgrammingLanguageKey, _programmingLanguage.ToString() },
                { SpeakingLanguageKey, _speakingLanguage.ToString() },
                { FrameworksKey, _frameworks }
            };
        }

        /// <summary>
        /// Import settings from dictionary.
        /// </summary>
        public void ImportSettings(Dictionary<string, string> settings)
        {
            if (settings.TryGetValue(RoleKey, out var roleStr) &&
                Enum.TryParse<InterviewRole>(roleStr, out var role))
            {
                _role = role;
            }

            if (settings.TryGetValue(ProgrammingLanguageKey, out var langStr) &&
                Enum.TryParse<ProgrammingLanguage>(langStr, out var language))
            {
                _programmingLanguage = language;
            }

            if (settings.TryGetValue(SpeakingLanguageKey, out var speakStr) &&
                Enum.TryParse<SpeakingLanguage>(speakStr, out var speaking))
            {
                _speakingLanguage = speaking;
            }

            if (settings.TryGetValue(FrameworksKey, out var frameworks))
            {
                _frameworks = frameworks;
            }

            OnSettingsChanged?.Invoke();
        }

        public override string ToString()
        {
            return $"AppSettings(Role={RoleDisplayName}, Language={LanguageDisplayName}, " +
                   $"ResponseLanguage={ResponseLanguageDisplayName}, Frameworks={Frameworks})";
        }
    }
}

