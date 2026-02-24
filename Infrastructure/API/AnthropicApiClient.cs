using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;

namespace InterviewMasterApp.Infrastructure.API
{
    /// <summary>
    /// HTTP client for Anthropic Messages API. Minimal port of AnthropicApiClient.swift
    /// </summary>
    public class AnthropicApiClient
    {
        private readonly string _apiKey;
        private readonly string _baseUrl = "https://api.anthropic.com/v1/messages";
        private readonly string _apiVersion = "2023-06-01";
        private readonly HttpClient _http;

        public AnthropicApiClient(string apiKey, HttpClient httpClient = null)
        {
            _apiKey = apiKey ?? throw new ArgumentNullException(nameof(apiKey));
            _http = httpClient ?? new HttpClient();
        }

        public enum ApiError
        {
            InvalidRequest,
            NetworkError,
            InvalidResponse,
            HttpError,
            DecodingError,
            InvalidApiKey
        }

        /// <summary>
        /// Send message and return aggregated text response (non-streaming)
        /// </summary>
        public async Task<Result<string, ApiError>> SendMessageAsync(List<string> imagesBase64, string prompt, string model = "claude-haiku-4.5-20250514")
        {
            var contentBlocks = new List<object>();

            foreach (var img in imagesBase64 ?? new List<string>())
            {
                var imageContent = new ImageContent
                {
                    Source = new ImageSource { Type = "base64", MediaType = "image/png", Data = img }
                };
                contentBlocks.Add(imageContent);
            }

            contentBlocks.Add(new TextContent { Text = prompt });

            var request = new AnthropicRequest
            {
                Model = model,
                MaxTokens = 4096,
                Messages = new List<AnthropicMessage>
                {
                    new AnthropicMessage { Role = "user", Content = contentBlocks }
                }
            };

            using var httpRequest = new HttpRequestMessage(HttpMethod.Post, _baseUrl);
            httpRequest.Headers.Add("x-api-key", _apiKey);
            httpRequest.Headers.Add("anthropic-version", _apiVersion);
            httpRequest.Content = JsonContent.Create(request, options: new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase });

            try
            {
                using var response = await _http.SendAsync(httpRequest);
                var data = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    try
                    {
                        var error = JsonSerializer.Deserialize<AnthropicErrorResponse>(data);
                        return Result<string, ApiError>.Fail(ApiError.HttpError, error?.Error?.Message ?? "HTTP error");
                    }
                    catch
                    {
                        return Result<string, ApiError>.Fail(ApiError.HttpError, "HTTP error");
                    }
                }

                try
                {
                    var apiResponse = JsonSerializer.Deserialize<AnthropicResponse>(data);
                    var responseText = string.Join("\n", apiResponse?.Content?.FindAll(c => !string.IsNullOrEmpty(c.Text)).ConvertAll(c => c.Text) ?? new List<string>());
                    return Result<string, ApiError>.Ok(responseText);
                }
                catch
                {
                    return Result<string, ApiError>.Fail(ApiError.DecodingError, "Failed to decode response");
                }
            }
            catch
            {
                return Result<string, ApiError>.Fail(ApiError.NetworkError, "Network error");
            }
        }

        // Note: Streaming support (SSE) would require a specialized parser. Provide a simple streaming stub API that
        // accepts an Action<string> called for each chunk; implementation can be expanded later.

        public async Task<Result<VoidResult, ApiError>> SendMessageStreamAsync(List<string> imagesBase64, string prompt, Action<string> onChunk, string model = "claude-haiku-4.5-20250514")
        {
            // For now, implement as non-streaming call and call onChunk once with full text.
            var result = await SendMessageAsync(imagesBase64, prompt, model);
            if (result.IsSuccess)
            {
                onChunk?.Invoke(result.Value);
                return Result<VoidResult, ApiError>.Ok(VoidResult.Instance);
            }
            return Result<VoidResult, ApiError>.Fail(ApiError.HttpError, "Stream not implemented");
        }
    }

    // Small Result type to mirror Swift Result<T,Error>
    public class Result<T, E>
    {
        public bool IsSuccess { get; private set; }
        public T Value { get; private set; }
        public E ErrorCode { get; private set; }
        public string ErrorMessage { get; private set; }

        public static Result<T, E> Ok(T value) => new Result<T, E> { IsSuccess = true, Value = value };
        public static Result<T, E> Fail(E errorCode, string message = null) => new Result<T, E> { IsSuccess = false, ErrorCode = errorCode, ErrorMessage = message };
    }

    public class VoidResult
    {
        private VoidResult() { }
        public static VoidResult Instance { get; } = new VoidResult();
    }
}

