using System;

namespace InterviewMasterApp.Domain.ValueObjects
{
    /// <summary>
    /// Value object representing a validated Anthropic API key.
    /// Migrated from Swift: ApiKey.swift
    /// </summary>
    public class ApiKey
    {
        private readonly string _value;

        /// <summary>
        /// Initialize with validation.
        /// </summary>
        /// <param name="value">Raw API key string</param>
        /// <exception cref="ArgumentException">Thrown if API key format is invalid</exception>
        public ApiKey(string value)
        {
            var trimmed = (value ?? "").Trim();

            // Validate Anthropic API key format (sk-ant-XXXXXXX...)
            if (!trimmed.StartsWith("sk-ant-") || trimmed.Length <= 20)
            {
                throw new ArgumentException(
                    "Invalid API key format. Must start with 'sk-ant-' and be longer than 20 characters.",
                    nameof(value)
                );
            }

            _value = trimmed;
        }

        /// <summary>
        /// Try to create an API key with validation.
        /// </summary>
        public static bool TryCreate(string value, out ApiKey? apiKey)
        {
            apiKey = null;
            try
            {
                apiKey = new ApiKey(value);
                return true;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Get the raw API key value (use carefully!).
        /// </summary>
        public string RawValue => _value;

        /// <summary>
        /// Masked version for display (e.g., "sk-ant-***XYZ").
        /// </summary>
        public string Masked
        {
            get
            {
                if (_value.Length <= 10)
                    return "sk-ant-***";

                var prefix = _value.Substring(0, 7);  // "sk-ant-"
                var suffix = _value.Substring(_value.Length - 3);  // Last 3 chars
                return $"{prefix}***{suffix}";
            }
        }

        public override bool Equals(object? obj)
        {
            return obj is ApiKey other && _value == other._value;
        }

        public override int GetHashCode()
        {
            return _value.GetHashCode();
        }

        public override string ToString()
        {
            return Masked;
        }

        public static bool operator ==(ApiKey? left, ApiKey? right)
        {
            if (ReferenceEquals(left, right))
                return true;
            if (ReferenceEquals(left, null) || ReferenceEquals(right, null))
                return false;
            return left._value == right._value;
        }

        public static bool operator !=(ApiKey? left, ApiKey? right)
        {
            return !(left == right);
        }
    }
}
