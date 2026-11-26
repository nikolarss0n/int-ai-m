using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;

namespace InterviewMasterApp.Infrastructure.Storage
{
    public enum ApiKeyType
    {
        Anthropic, // ANTHROPIC_API_KEY
        Groq,      // GROQ_API_KEY
        Xai,       // XAI_API_KEY
        OpenAi     // OPENAI_API_KEY
    }

    public interface ICredentialVault
    {
        bool Save(string target, string secret);
        string? Retrieve(string target);
        bool Delete(string target);
    }

    internal sealed class WindowsCredentialVaultAdapter : ICredentialVault
    {
        public bool Save(string target, string secret) =>
            OperatingSystem.IsWindows() && new WindowsCredentialApiKeyStore(target).Save(secret);

        public string? Retrieve(string target) =>
            OperatingSystem.IsWindows() ? new WindowsCredentialApiKeyStore(target).Retrieve() : null;

        public bool Delete(string target) =>
            OperatingSystem.IsWindows() && new WindowsCredentialApiKeyStore(target).Delete();
    }

    /// <summary>
    /// Centralized API key management.
    /// Storage priority: Environment variable > Windows Credential Manager (primary) > ~/.interview-master-keys (read fallback).
    /// Writes go to Windows Credential Manager on Windows (never plaintext file unless explicitly running with a custom non-Windows store).
    /// </summary>
    public class ApiKeyManager
    {
        private static readonly Lazy<ApiKeyManager> _lazy = new(() => new ApiKeyManager());
        public static ApiKeyManager Shared => _lazy.Value;

        private readonly ReaderWriterLockSlim _lock = new();
        private readonly Dictionary<string, string> _keys = new(StringComparer.OrdinalIgnoreCase);
        private readonly ICredentialVault _vault;
        private readonly string _fallbackFilePath;
        private readonly Func<string, string?> _envReader;

        private ApiKeyManager()
            : this(
                new WindowsCredentialVaultAdapter(),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".interview-master-keys"),
                Environment.GetEnvironmentVariable)
        {
        }

        public ApiKeyManager(ICredentialVault vault, string fallbackFilePath, Func<string, string?>? envReader = null)
        {
            _vault = vault ?? throw new ArgumentNullException(nameof(vault));
            _fallbackFilePath = fallbackFilePath ?? string.Empty;
            _envReader = envReader ?? Environment.GetEnvironmentVariable;
            ReloadKeys();
        }

        public void ReloadKeys()
        {
            var loaded = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            // 1. Lowest priority: legacy plaintext fallback file ~/.interview-master-keys
            try
            {
                if (!string.IsNullOrEmpty(_fallbackFilePath) && File.Exists(_fallbackFilePath))
                {
                    foreach (var line in File.ReadAllLines(_fallbackFilePath))
                    {
                        var trimmed = line?.Trim();
                        if (string.IsNullOrEmpty(trimmed) || trimmed.StartsWith("#", StringComparison.Ordinal)) continue;
                        var idx = trimmed.IndexOf('=');
                        if (idx <= 0) continue;
                        var key = trimmed[..idx].Trim();
                        var val = trimmed[(idx + 1)..].Trim();
                        if (!string.IsNullOrEmpty(val)) loaded[key] = val;
                    }
                }
            }
            catch { }

            // 2. Primary store: Windows Credential Manager
            foreach (ApiKeyType type in Enum.GetValues(typeof(ApiKeyType)))
            {
                var keyName = TypeToKeyName(type);
                try
                {
                    var credVal = _vault.Retrieve(TargetName(keyName));
                    if (!string.IsNullOrWhiteSpace(credVal))
                        loaded[keyName] = credVal.Trim();
                }
                catch { }
            }

            // 3. Highest priority: Environment variables
            foreach (ApiKeyType type in Enum.GetValues(typeof(ApiKeyType)))
            {
                var keyName = TypeToKeyName(type);
                var env = _envReader(keyName)?.Trim();
                if (!string.IsNullOrEmpty(env))
                    loaded[keyName] = env;
            }

            _lock.EnterWriteLock();
            try
            {
                _keys.Clear();
                foreach (var kv in loaded) _keys[kv.Key] = kv.Value;
            }
            finally { _lock.ExitWriteLock(); }
        }

        public string? GetKey(ApiKeyType type)
        {
            var keyName = TypeToKeyName(type);
            _lock.EnterReadLock();
            try
            {
                return _keys.TryGetValue(keyName, out var v) && !string.IsNullOrWhiteSpace(v) ? v : null;
            }
            finally { _lock.ExitReadLock(); }
        }

        public bool SetKey(string key, ApiKeyType type)
        {
            var trimmed = (key ?? string.Empty).Trim();
            if (string.IsNullOrEmpty(trimmed)) return false;

            var keyName = TypeToKeyName(type);
            var savedToVault = false;
            try
            {
                savedToVault = _vault.Save(TargetName(keyName), trimmed);
            }
            catch { }

            _lock.EnterWriteLock();
            try
            {
                _keys[keyName] = trimmed;
            }
            finally { _lock.ExitWriteLock(); }

            return savedToVault || !OperatingSystem.IsWindows();
        }

        public bool HasKey(ApiKeyType type) => !string.IsNullOrWhiteSpace(GetKey(type));

        public bool DeleteKey(ApiKeyType type)
        {
            var keyName = TypeToKeyName(type);
            try { _vault.Delete(TargetName(keyName)); } catch { }

            _lock.EnterWriteLock();
            try
            {
                return _keys.Remove(keyName);
            }
            finally { _lock.ExitWriteLock(); }
        }

        public static string TypeToKeyName(ApiKeyType type) => type switch
        {
            ApiKeyType.Anthropic => "ANTHROPIC_API_KEY",
            ApiKeyType.Groq => "GROQ_API_KEY",
            ApiKeyType.Xai => "XAI_API_KEY",
            ApiKeyType.OpenAi => "OPENAI_API_KEY",
            _ => type.ToString().ToUpperInvariant()
        };

        public static string TargetName(string keyName) => $"InterviewMaster.{keyName}";
    }
}
