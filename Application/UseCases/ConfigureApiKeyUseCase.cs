using System;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using InterviewMasterApp.Infrastructure.Storage;

namespace InterviewMasterApp.Application.UseCases
{
    /// <summary>
    /// Use case for configuring the Anthropic API key.
    /// Migrated from Swift: ConfigureApiKeyUseCase.swift
    /// Windows uses Credential Manager or DPAPI for secure storage.
    /// </summary>
    public class ConfigureApiKeyUseCase
    {
        private readonly IApiKeyStore _keyStore;

        public ConfigureApiKeyUseCase(IApiKeyStore keyStore)
        {
            _keyStore = keyStore ?? throw new ArgumentNullException(nameof(keyStore));
        }

        /// <summary>
        /// Save API key with validation.
        /// </summary>
        /// <param name="apiKeyString">Raw API key string</param>
        /// <returns>Validated ApiKey or error</returns>
        public async Task<Result<ApiKey>> SaveAsync(string apiKeyString)
        {
            // Validate API key format
            if (!IsValidApiKey(apiKeyString))
            {
                return Result<ApiKey>.Failure(
                    new ConfigException("Invalid API key format. Must start with 'sk-ant-'")
                );
            }

            // Save to secure storage (Windows Credential Manager or DPAPI)
            var saveResult = await _keyStore.SaveAsync(apiKeyString);

            if (saveResult.IsSuccess)
            {
                return Result<ApiKey>.Success(new ApiKey(apiKeyString));
            }

            return Result<ApiKey>.Failure(saveResult.Error);
        }

        /// <summary>
        /// Retrieve saved API key.
        /// </summary>
        /// <returns>ApiKey or error</returns>
        public async Task<Result<ApiKey>> RetrieveAsync()
        {
            var retrieveResult = await _keyStore.RetrieveAsync();

            if (!retrieveResult.IsSuccess)
            {
                return Result<ApiKey>.Failure(
                    new ConfigException($"Failed to retrieve API key: {retrieveResult.Error.Message}")
                );
            }

            var apiKeyString = retrieveResult.Value;

            if (!IsValidApiKey(apiKeyString))
            {
                return Result<ApiKey>.Failure(
                    new ConfigException("Invalid API key format. Must start with 'sk-ant-'")
                );
            }

            return Result<ApiKey>.Success(new ApiKey(apiKeyString));
        }

        /// <summary>
        /// Check if API key exists in storage.
        /// </summary>
        /// <returns>true if exists, false otherwise</returns>
        public async Task<bool> ExistsAsync()
        {
            return await _keyStore.ExistsAsync();
        }

        /// <summary>
        /// Delete saved API key.
        /// </summary>
        /// <returns>Success or error</returns>
        public async Task<Result<Unit>> DeleteAsync()
        {
            var deleteResult = await _keyStore.DeleteAsync();

            if (deleteResult.IsSuccess)
            {
                return Result<Unit>.Success(Unit.Value);
            }

            return Result<Unit>.Failure(
                new ConfigException($"Failed to delete API key: {deleteResult.Error.Message}")
            );
        }

        /// <summary>
        /// Validate API key format.
        /// </summary>
        private static bool IsValidApiKey(string apiKey)
        {
            return !string.IsNullOrWhiteSpace(apiKey) && apiKey.StartsWith("sk-ant-");
        }
    }

    /// <summary>
    /// Represents a validated API key (value object).
    /// </summary>
    public class ApiKey
    {
        public string Value { get; }

        public ApiKey(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
                throw new ArgumentException("API key cannot be empty", nameof(value));

            if (!value.StartsWith("sk-ant-"))
                throw new ArgumentException("Invalid API key format", nameof(value));

            Value = value;
        }
    }

    /// <summary>
    /// Custom exception for API key configuration errors.
    /// </summary>
    public class ConfigException : Exception
    {
        public ConfigException(string message) : base(message) { }
        public ConfigException(string message, Exception innerException)
            : base(message, innerException) { }
    }

    /// <summary>
    /// Represents a unit value (used when no return value is needed).
    /// </summary>
    public class Unit
    {
        public static Unit Value { get; } = new();
    }
}

