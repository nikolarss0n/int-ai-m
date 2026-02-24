using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;

namespace InterviewMasterApp.Infrastructure.Storage
{
    public enum ApiKeyType
    {
        Anthropic, // ANTHROPIC_API_KEY
        Groq       // GROQ_API_KEY
    }

    /// <summary>
    /// Centralized API key management - reads from %USERPROFILE%/.interview-master-keys
    /// Ported from Swift: ApiKeyManager.swift
    /// </summary>
    public class ApiKeyManager
    {
        private static readonly Lazy<ApiKeyManager> _lazy = new(() => new ApiKeyManager());
        public static ApiKeyManager Shared => _lazy.Value;

        private readonly ReaderWriterLockSlim _lock = new();
        private readonly Dictionary<string, string> _keys = new(StringComparer.OrdinalIgnoreCase);
        private readonly string _filePath;

        private ApiKeyManager()
        {
            var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            _filePath = Path.Combine(userProfile, ".interview-master-keys");
            LoadKeys();
        }

        private void LoadKeys()
        {
            try
            {
                if (!File.Exists(_filePath)) return;
                var lines = File.ReadAllLines(_filePath);
                var loaded = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

                foreach (var line in lines)
                {
                    var trimmed = line?.Trim();
                    if (string.IsNullOrEmpty(trimmed) || trimmed.StartsWith("#")) continue;
                    var idx = trimmed.IndexOf('=');
                    if (idx <= 0) continue;
                    var key = trimmed.Substring(0, idx).Trim();
                    var value = trimmed.Substring(idx + 1).Trim();
                    loaded[key] = value;
                }

                _lock.EnterWriteLock();
                try
                {
                    _keys.Clear();
                    foreach (var kv in loaded) _keys[kv.Key] = kv.Value;
                }
                finally { _lock.ExitWriteLock(); }

                Console.WriteLine($"✅ ApiKeyManager: Loaded {loaded.Count} keys from file {_filePath}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"⚠️ ApiKeyManager: Could not read {_filePath}: {ex.Message}");
            }
        }

        public string GetKey(ApiKeyType type)
        {
            var keyName = TypeToKeyName(type);
            _lock.EnterReadLock();
            try
            {
                return _keys.TryGetValue(keyName, out var v) ? v : null;
            }
            finally { _lock.ExitReadLock(); }
        }

        public bool SetKey(string key, ApiKeyType type)
        {
            var keyName = TypeToKeyName(type);
            _lock.EnterWriteLock();
            try
            {
                _keys[keyName] = key;
            }
            finally { _lock.ExitWriteLock(); }

            // Async persist to file in background
            try
            {
                PersistKeys();
            }
            catch
            {
                // ignore persistence errors for now
            }

            return true;
        }

        public bool HasKey(ApiKeyType type)
        {
            var keyName = TypeToKeyName(type);
            _lock.EnterReadLock();
            try
            {
                return _keys.TryGetValue(keyName, out var v) && !string.IsNullOrWhiteSpace(v);
            }
            finally { _lock.ExitReadLock(); }
        }

        public bool DeleteKey(ApiKeyType type)
        {
            var keyName = TypeToKeyName(type);
            _lock.EnterWriteLock();
            try
            {
                if (_keys.Remove(keyName))
                {
                    PersistKeys();
                    return true;
                }
                return false;
            }
            finally { _lock.ExitWriteLock(); }
        }

        private void PersistKeys()
        {
            // Persist all keys to the plain-text file (same semantics as the Swift version).
            // Keep simple format: KEY=VALUE
            try
            {
                var dir = Path.GetDirectoryName(_filePath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir)) Directory.CreateDirectory(dir);

                var lines = _keys.Select(kv => $"{kv.Key}={kv.Value}").ToArray();
                File.WriteAllLines(_filePath, lines);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"⚠️ ApiKeyManager: Failed to persist keys: {ex.Message}");
            }
        }

        private static string TypeToKeyName(ApiKeyType type)
        {
            return type switch
            {
                ApiKeyType.Anthropic => "ANTHROPIC_API_KEY",
                ApiKeyType.Groq => "GROQ_API_KEY",
                _ => type.ToString().ToUpperInvariant()
            };
        }
    }
}

