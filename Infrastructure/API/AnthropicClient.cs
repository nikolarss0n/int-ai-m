using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;

namespace InterviewMasterApp.Infrastructure.API
{
    /// <summary>
    /// Higher-level Anthropic client that mirrors behavior of AnthropicClient.swift
    /// Implements retry/backoff and streaming stub.
    /// </summary>
    public class AnthropicClient
    {
        private readonly string _apiKey;
        private readonly string _baseUrl = "https://api.anthropic.com/v1/messages";
        private readonly string _model;
        private readonly int _maxTokens;
        private readonly HttpClient _http;

        private bool _isConnectionWarm;

        public AnthropicClient(string apiKey, string model = null, int maxTokens = 4096, HttpClient httpClient = null)
        {
            _apiKey = apiKey ?? throw new ArgumentNullException(nameof(apiKey));
            _model = model ?? "claude-haiku-4-5-20251001";
            _maxTokens = maxTokens;
            _http = httpClient ?? new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        }

        public void CancelCurrentRequest()
        {
            // HttpClient doesn't support per-request cancel without CancellationToken; caller should provide tokens.
        }

        public async Task WarmupConnectionAsync()
        {
            if (_isConnectionWarm) return;
            try
            {
                var req = new HttpRequestMessage(HttpMethod.Head, "https://api.anthropic.com");
                using var resp = await _http.SendAsync(req);
                _isConnectionWarm = true;
            }
            catch
            {
                // Non-critical
            }
        }

        public async Task<(string Text, double LatencyMs)> SendMessageAsync(string prompt, int maxTokens = 300)
        {
            var start = DateTime.UtcNow;
            var maxAttempts = 3;
            var backoffs = new[] { 0.5, 1.0, 1.5 };

            var requestBody = new Dictionary<string, object>
            {
                ["model"] = _model,
                ["max_tokens"] = maxTokens,
                ["messages"] = new[] { new Dictionary<string, object> { ["role"] = "user", ["content"] = prompt } }
            };

            var json = JsonSerializer.Serialize(requestBody);
            var request = new HttpRequestMessage(HttpMethod.Post, _baseUrl);
            request.Headers.Add("x-api-key", _apiKey);
            request.Headers.Add("anthropic-version", "2023-06-01");
            request.Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

            Exception lastEx = null;
            for (int attempt = 0; attempt < maxAttempts; attempt++)
            {
                try
                {
                    using var resp = await _http.SendAsync(request);
                    var data = await resp.Content.ReadAsStringAsync();

                    if ((int)resp.StatusCode >= 400 && (int)resp.StatusCode < 500)
                    {
                        throw new HttpRequestException($"HTTP {(int)resp.StatusCode}");
                    }

                    var decoded = JsonSerializer.Deserialize<AnthropicResponse>(data);
                    var text = string.Empty;
                    if (decoded?.Content != null && decoded.Content.Count > 0)
                        text = decoded.Content[0].Text?.Trim() ?? string.Empty;

                    var latency = (DateTime.UtcNow - start).TotalMilliseconds;
                    return (text, latency);
                }
                catch (Exception ex)
                {
                    lastEx = ex;
                    if (attempt < maxAttempts - 1)
                        await Task.Delay(TimeSpan.FromSeconds(backoffs[attempt]));
                }
            }

            throw lastEx ?? new Exception("Request failed");
        }

        public async Task<Result<VoidResult, Exception>> StreamTextMessageAsync(string prompt, int maxTokens, Action<string> onChunk)
        {
            // Reuse SendMessageAsync for now and call onChunk with final text
            var (text, _) = await SendMessageAsync(prompt, maxTokens);
            onChunk?.Invoke(text);
            return Result<VoidResult, Exception>.Ok(VoidResult.Instance);
        }

        // Classification helpers can be ported as needed - omitted for brevity
    }
}

