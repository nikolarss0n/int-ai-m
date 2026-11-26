using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using InterviewMasterApp.Application;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Infrastructure.API
{
    /// <summary>
    /// HTTP + real SSE streaming client for Anthropic Vision / Messages API.
    /// </summary>
    public class AnthropicApiClient : IAnthropicVisionClient
    {
        private readonly string _apiKey;
        private readonly string _baseUrl = AppConstants.ApiUrls.AnthropicMessages;
        private readonly string _apiVersion = "2023-06-01";
        private readonly HttpClient _http;

        public AnthropicApiClient(string apiKey, HttpClient? httpClient = null)
        {
            _apiKey = apiKey ?? throw new ArgumentNullException(nameof(apiKey));
            _http = httpClient ?? new HttpClient { Timeout = TimeSpan.FromMinutes(3) };
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

        public async Task<Result<string, ApiError>> SendMessageAsync(
            List<string> imagesBase64,
            string prompt,
            string model = AppConstants.Models.AnthropicHaiku,
            CancellationToken ct = default)
        {
            var payload = BuildPayload(imagesBase64, prompt, model, stream: false);
            using var req = CreateRequest(payload);

            try
            {
                using var response = await _http.SendAsync(req, ct).ConfigureAwait(false);
                var data = await response.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
                if (!response.IsSuccessStatusCode)
                    return Result<string, ApiError>.Fail(ApiError.HttpError, ExtractError(data, (int)response.StatusCode));

                var apiResponse = JsonSerializer.Deserialize<AnthropicResponse>(data);
                var text = string.Join("\n", apiResponse?.Content?.FindAll(c => !string.IsNullOrEmpty(c.Text)).ConvertAll(c => c.Text) ?? new List<string>());
                return Result<string, ApiError>.Ok(text);
            }
            catch (Exception ex)
            {
                return Result<string, ApiError>.Fail(ApiError.NetworkError, ex.Message);
            }
        }

        public async Task<Result<VoidResult, ApiError>> SendMessageStreamAsync(
            List<string> imagesBase64,
            string prompt,
            Action<string> onChunk,
            string model = AppConstants.Models.AnthropicHaiku,
            CancellationToken ct = default)
        {
            var (ok, _, error) = await ((IAnthropicVisionClient)this)
                .SendMessageStreamAsync(imagesBase64, prompt, onChunk, model, ct)
                .ConfigureAwait(false);

            return ok
                ? Result<VoidResult, ApiError>.Ok(VoidResult.Instance)
                : Result<VoidResult, ApiError>.Fail(ApiError.HttpError, error ?? "Streaming failed");
        }

        async Task<(bool IsSuccess, string Value, string? ErrorMessage)> IAnthropicVisionClient.SendMessageStreamAsync(
            List<string> imagesBase64,
            string prompt,
            Action<string> onChunk,
            string? model,
            CancellationToken ct)
        {
            var resolvedModel = string.IsNullOrWhiteSpace(model) ? AppConstants.Models.AnthropicHaiku : model;
            var payload = BuildPayload(imagesBase64, prompt, resolvedModel, stream: true);
            using var req = CreateRequest(payload);

            try
            {
                using var response = await _http.SendAsync(req, HttpCompletionOption.ResponseHeadersRead, ct).ConfigureAwait(false);
                if (!response.IsSuccessStatusCode)
                {
                    var errBody = await response.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
                    return (false, string.Empty, ExtractError(errBody, (int)response.StatusCode));
                }

                var sb = new StringBuilder();
                using var stream = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
                using var reader = new StreamReader(stream, Encoding.UTF8);

                string? currentEvent = null;
                while (!reader.EndOfStream)
                {
                    ct.ThrowIfCancellationRequested();
                    var line = await reader.ReadLineAsync(ct).ConfigureAwait(false);
                    if (line == null) break;
                    if (string.IsNullOrEmpty(line)) { currentEvent = null; continue; }

                    if (line.StartsWith("event: ", StringComparison.Ordinal))
                    {
                        currentEvent = line[7..].Trim();
                        if (currentEvent == "message_stop") break;
                        continue;
                    }

                    if (!line.StartsWith("data: ", StringComparison.Ordinal)) continue;
                    var data = line[6..];
                    if (currentEvent == "error")
                        return (false, sb.ToString(), ExtractError(data, 500));

                    if (currentEvent == "content_block_delta")
                    {
                        try
                        {
                            using var doc = JsonDocument.Parse(data);
                            if (doc.RootElement.TryGetProperty("delta", out var delta) &&
                                delta.TryGetProperty("text", out var textProp))
                            {
                                var chunk = textProp.GetString();
                                if (!string.IsNullOrEmpty(chunk))
                                {
                                    sb.Append(chunk);
                                    onChunk?.Invoke(chunk);
                                }
                            }
                        }
                        catch { }
                    }
                }

                return (true, sb.ToString(), null);
            }
            catch (Exception ex)
            {
                return (false, string.Empty, ex.Message);
            }
        }

        private static string BuildPayload(List<string> imagesBase64, string prompt, string model, bool stream)
        {
            var contentBlocks = new List<object>();
            foreach (var img in imagesBase64 ?? new List<string>())
            {
                contentBlocks.Add(new ImageContent
                {
                    Source = new ImageSource { Type = "base64", MediaType = "image/png", Data = img }
                });
            }
            contentBlocks.Add(new TextContent { Text = prompt });

            var body = new Dictionary<string, object>
            {
                ["model"] = model,
                ["max_tokens"] = AppConstants.MaxTokens.ImageAnalysis,
                ["stream"] = stream,
                ["messages"] = new List<AnthropicMessage>
                {
                    new() { Role = "user", Content = contentBlocks }
                }
            };
            return JsonSerializer.Serialize(body);
        }

        private HttpRequestMessage CreateRequest(string json)
        {
            var req = new HttpRequestMessage(HttpMethod.Post, _baseUrl);
            req.Headers.Add("x-api-key", _apiKey);
            req.Headers.Add("anthropic-version", _apiVersion);
            req.Content = new StringContent(json, Encoding.UTF8, "application/json");
            return req;
        }

        private static string ExtractError(string body, int statusCode)
        {
            try
            {
                var err = JsonSerializer.Deserialize<AnthropicErrorResponse>(body);
                if (!string.IsNullOrWhiteSpace(err?.Error?.Message))
                    return $"HTTP {statusCode}: {err.Error.Message}";
            }
            catch { }
            return string.IsNullOrWhiteSpace(body) ? $"HTTP {statusCode}" : $"HTTP {statusCode}: {body[..Math.Min(body.Length, 300)]}";
        }
    }

    public class Result<T, E>
    {
        public bool IsSuccess { get; private set; }
        public T? Value { get; private set; }
        public E? ErrorCode { get; private set; }
        public string? ErrorMessage { get; private set; }

        public static Result<T, E> Ok(T value) => new() { IsSuccess = true, Value = value };
        public static Result<T, E> Fail(E errorCode, string? message = null) => new() { IsSuccess = false, ErrorCode = errorCode, ErrorMessage = message };
    }

    public class VoidResult
    {
        private VoidResult() { }
        public static VoidResult Instance { get; } = new();
    }
}
