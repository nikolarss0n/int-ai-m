using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using InterviewMasterApp.Application;

namespace InterviewMasterApp.Infrastructure.API
{
    /// <summary>
    /// Real Anthropic SSE streaming client that implements IAnthropicClient.
    /// Uses HttpCompletionOption.ResponseHeadersRead for true token-by-token streaming
    /// via Server-Sent Events (SSE).
    /// </summary>
    public class AnthropicStreamingClient : IAnthropicClient
    {
        private const string BaseUrl = "https://api.anthropic.com/v1/messages";
        private const string ApiVersion = "2023-06-01";

        private readonly string _apiKey;
        private readonly string _model;
        private readonly int _maxTokens;
        private readonly HttpClient _httpClient;

        private CancellationTokenSource _currentRequestCts;
        private readonly object _ctsLock = new object();
        private bool _isConnectionWarm;

        public AnthropicStreamingClient(string apiKey, string model = "claude-haiku-4-5-20251001", int maxTokens = 4096)
        {
            _apiKey = apiKey ?? throw new ArgumentNullException(nameof(apiKey));
            _model = model;
            _maxTokens = maxTokens;
            _httpClient = new HttpClient
            {
                Timeout = TimeSpan.FromMinutes(5) // Streaming responses can be long-lived
            };
        }

        /// <summary>
        /// Pre-warm the TCP connection to the Anthropic API to reduce first-request latency.
        /// </summary>
        public async Task WarmupConnectionAsync()
        {
            if (_isConnectionWarm) return;

            try
            {
                using var request = new HttpRequestMessage(HttpMethod.Head, "https://api.anthropic.com");
                using var response = await _httpClient.SendAsync(request).ConfigureAwait(false);
                _isConnectionWarm = true;
            }
            catch
            {
                // Non-critical; connection will be established on first real request.
            }
        }

        /// <summary>
        /// Cancel any in-flight streaming or non-streaming request.
        /// </summary>
        public void CancelCurrentRequest()
        {
            lock (_ctsLock)
            {
                if (_currentRequestCts != null && !_currentRequestCts.IsCancellationRequested)
                {
                    _currentRequestCts.Cancel();
                    Debug.WriteLine("[AnthropicStreamingClient] Current request cancelled.");
                }
            }
        }

        /// <summary>
        /// Stream an interview answer using real SSE streaming from the Anthropic Messages API.
        /// The messages list should contain dictionaries with "role" and "content" keys (the
        /// format produced by ConversationContext.MessagesToAPIFormat).
        /// </summary>
        public async Task StreamAnswerAsync(
            string question,
            List<object> messages,
            string userBackground,
            Action<string> onChunk,
            CancellationToken ct = default)
        {
            // Create a linked CancellationTokenSource so both external and internal cancellation work
            var internalCts = new CancellationTokenSource();
            lock (_ctsLock)
            {
                _currentRequestCts?.Dispose();
                _currentRequestCts = internalCts;
            }

            using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(ct, internalCts.Token);
            var token = linkedCts.Token;

            try
            {
                // Build the system prompt
                var systemPrompt = BuildSystemPrompt(userBackground);

                // Build the messages array for the API
                var apiMessages = BuildApiMessages(question, messages);

                // Build the request body
                var requestBody = new SseRequestBody
                {
                    Model = _model,
                    MaxTokens = _maxTokens,
                    System = systemPrompt,
                    Stream = true,
                    Messages = apiMessages
                };

                var jsonOptions = new JsonSerializerOptions
                {
                    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                };
                var json = JsonSerializer.Serialize(requestBody, jsonOptions);

                using var httpRequest = new HttpRequestMessage(HttpMethod.Post, BaseUrl);
                httpRequest.Headers.Add("x-api-key", _apiKey);
                httpRequest.Headers.Add("anthropic-version", ApiVersion);
                httpRequest.Content = new StringContent(json, Encoding.UTF8, "application/json");

                // Use ResponseHeadersRead to start processing as soon as headers arrive
                using var response = await _httpClient.SendAsync(
                    httpRequest,
                    HttpCompletionOption.ResponseHeadersRead,
                    token).ConfigureAwait(false);

                if (!response.IsSuccessStatusCode)
                {
                    var errorBody = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                    string errorMessage;

                    try
                    {
                        var errorResponse = JsonSerializer.Deserialize<AnthropicErrorResponse>(errorBody);
                        errorMessage = errorResponse?.Error?.Message ?? $"HTTP {(int)response.StatusCode}";
                    }
                    catch
                    {
                        errorMessage = $"HTTP {(int)response.StatusCode}: {errorBody}";
                    }

                    throw new HttpRequestException($"Anthropic API error: {errorMessage}");
                }

                // Read the SSE stream
                using var stream = await response.Content.ReadAsStreamAsync().ConfigureAwait(false);
                using var reader = new StreamReader(stream, Encoding.UTF8);

                await ParseSseStream(reader, onChunk, token).ConfigureAwait(false);
            }
            catch (OperationCanceledException) when (token.IsCancellationRequested)
            {
                Debug.WriteLine("[AnthropicStreamingClient] Stream cancelled.");
                // Swallow cancellation - caller requested it via CancelCurrentRequest or CancellationToken
            }
            finally
            {
                lock (_ctsLock)
                {
                    if (_currentRequestCts == internalCts)
                    {
                        _currentRequestCts = null;
                    }
                }
            }
        }

        /// <summary>
        /// Send a non-streaming message to the Anthropic API with retry logic and backoff.
        /// Returns the response text and the total latency in milliseconds.
        /// </summary>
        public async Task<(string Text, double LatencyMs)> SendMessageAsync(string prompt, int maxTokens = 300)
        {
            var stopwatch = Stopwatch.StartNew();
            const int maxAttempts = 3;
            var backoffSeconds = new[] { 0.5, 1.0, 2.0 };

            var requestBody = new SseRequestBody
            {
                Model = _model,
                MaxTokens = maxTokens,
                Stream = false,
                Messages = new List<SseMessage>
                {
                    new SseMessage { Role = "user", Content = prompt }
                }
            };

            var jsonOptions = new JsonSerializerOptions
            {
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
            var json = JsonSerializer.Serialize(requestBody, jsonOptions);

            Exception lastException = null;

            for (int attempt = 0; attempt < maxAttempts; attempt++)
            {
                try
                {
                    using var httpRequest = new HttpRequestMessage(HttpMethod.Post, BaseUrl);
                    httpRequest.Headers.Add("x-api-key", _apiKey);
                    httpRequest.Headers.Add("anthropic-version", ApiVersion);
                    httpRequest.Content = new StringContent(json, Encoding.UTF8, "application/json");

                    using var response = await _httpClient.SendAsync(httpRequest).ConfigureAwait(false);
                    var responseBody = await response.Content.ReadAsStringAsync().ConfigureAwait(false);

                    // 4xx errors are not retryable
                    if ((int)response.StatusCode >= 400 && (int)response.StatusCode < 500)
                    {
                        string errorMessage;
                        try
                        {
                            var errorResponse = JsonSerializer.Deserialize<AnthropicErrorResponse>(responseBody);
                            errorMessage = errorResponse?.Error?.Message ?? $"HTTP {(int)response.StatusCode}";
                        }
                        catch
                        {
                            errorMessage = $"HTTP {(int)response.StatusCode}";
                        }

                        throw new HttpRequestException($"Anthropic API client error: {errorMessage}");
                    }

                    // 5xx errors are retryable
                    if (!response.IsSuccessStatusCode)
                    {
                        throw new HttpRequestException($"HTTP {(int)response.StatusCode}: {responseBody}");
                    }

                    var decoded = JsonSerializer.Deserialize<AnthropicResponse>(responseBody);
                    var text = string.Empty;
                    if (decoded?.Content != null && decoded.Content.Count > 0)
                    {
                        text = decoded.Content[0].Text?.Trim() ?? string.Empty;
                    }

                    stopwatch.Stop();
                    return (text, stopwatch.Elapsed.TotalMilliseconds);
                }
                catch (HttpRequestException ex) when (
                    ex.Message.Contains("client error") ||
                    ((int?)GetStatusCodeFromMessage(ex.Message) >= 400 &&
                     (int?)GetStatusCodeFromMessage(ex.Message) < 500))
                {
                    // 4xx errors should not be retried
                    throw;
                }
                catch (Exception ex)
                {
                    lastException = ex;
                    Debug.WriteLine($"[AnthropicStreamingClient] SendMessageAsync attempt {attempt + 1}/{maxAttempts} failed: {ex.Message}");

                    if (attempt < maxAttempts - 1)
                    {
                        await Task.Delay(TimeSpan.FromSeconds(backoffSeconds[attempt])).ConfigureAwait(false);
                    }
                }
            }

            throw lastException ?? new Exception("SendMessageAsync failed after all retry attempts.");
        }

        #region SSE Parsing

        /// <summary>
        /// Parse an SSE stream from the Anthropic Messages API, extracting text deltas
        /// and invoking onChunk for each piece of content.
        /// </summary>
        private static async Task ParseSseStream(StreamReader reader, Action<string> onChunk, CancellationToken ct)
        {
            string currentEvent = null;

            while (!reader.EndOfStream)
            {
                ct.ThrowIfCancellationRequested();

                var line = await reader.ReadLineAsync().ConfigureAwait(false);

                if (line == null)
                    break;

                // Empty line signals end of an event block
                if (string.IsNullOrEmpty(line))
                {
                    currentEvent = null;
                    continue;
                }

                // Parse "event: <type>" lines
                if (line.StartsWith("event: ", StringComparison.Ordinal))
                {
                    currentEvent = line.Substring("event: ".Length).Trim();

                    if (currentEvent == "message_stop")
                    {
                        // Stream is complete
                        return;
                    }

                    if (currentEvent == "error")
                    {
                        // Next data line will contain error details; we'll handle it below
                    }

                    continue;
                }

                // Parse "data: <json>" lines
                if (line.StartsWith("data: ", StringComparison.Ordinal))
                {
                    var data = line.Substring("data: ".Length);

                    if (currentEvent == "error")
                    {
                        // Attempt to parse error details
                        string errorMessage = "Unknown streaming error";
                        try
                        {
                            var errorEvent = JsonSerializer.Deserialize<SseErrorEvent>(data);
                            errorMessage = errorEvent?.Error?.Message ?? errorMessage;
                        }
                        catch
                        {
                            errorMessage = data;
                        }

                        throw new InvalidOperationException($"Anthropic streaming error: {errorMessage}");
                    }

                    if (currentEvent == "content_block_delta")
                    {
                        try
                        {
                            var deltaEvent = JsonSerializer.Deserialize<SseContentBlockDeltaEvent>(data);
                            var text = deltaEvent?.Delta?.Text;
                            if (!string.IsNullOrEmpty(text))
                            {
                                onChunk?.Invoke(text);
                            }
                        }
                        catch (JsonException ex)
                        {
                            Debug.WriteLine($"[AnthropicStreamingClient] Failed to parse content_block_delta: {ex.Message}");
                        }
                    }

                    // Other events (message_start, content_block_start, content_block_stop, message_delta, ping)
                    // are acknowledged but not acted upon for text streaming purposes.

                    continue;
                }

                // Lines starting with ":" are SSE comments (keep-alive); ignore them.
            }
        }

        #endregion

        #region Message Building

        private static string BuildSystemPrompt(string userBackground)
        {
            var sb = new StringBuilder();
            sb.Append("You are an expert interview assistant helping a candidate during a live technical or behavioral interview. ");
            sb.Append("Provide concise, well-structured answers that the candidate can use to respond to the interviewer. ");
            sb.Append("Focus on clarity and correctness. Use bullet points or short paragraphs. ");
            sb.Append("If the question involves code, provide clean, working examples with brief explanations.");

            if (!string.IsNullOrWhiteSpace(userBackground))
            {
                sb.Append("\n\nCandidate background:\n");
                sb.Append(userBackground);
            }

            return sb.ToString();
        }

        /// <summary>
        /// Build the messages array for the Anthropic API from the incoming question and
        /// conversation history. The messages list contains Dictionary&lt;string, string&gt;
        /// objects with "role" and "content" keys.
        /// </summary>
        private static List<SseMessage> BuildApiMessages(string question, List<object> messages)
        {
            var apiMessages = new List<SseMessage>();

            // Add conversation history from the messages list
            if (messages != null)
            {
                foreach (var msg in messages)
                {
                    string role = null;
                    string content = null;

                    if (msg is Dictionary<string, string> dictStr)
                    {
                        dictStr.TryGetValue("role", out role);
                        dictStr.TryGetValue("content", out content);
                    }
                    else if (msg is Dictionary<string, object> dictObj)
                    {
                        role = dictObj.TryGetValue("role", out var r) ? r?.ToString() : null;
                        content = dictObj.TryGetValue("content", out var c) ? c?.ToString() : null;
                    }
                    else
                    {
                        // Try JSON round-trip as fallback for unknown types
                        try
                        {
                            var jsonElement = JsonSerializer.SerializeToElement(msg);
                            if (jsonElement.ValueKind == JsonValueKind.Object)
                            {
                                role = jsonElement.TryGetProperty("role", out var rProp) ? rProp.GetString() : null;
                                content = jsonElement.TryGetProperty("content", out var cProp) ? cProp.GetString() : null;
                            }
                        }
                        catch
                        {
                            continue;
                        }
                    }

                    if (!string.IsNullOrEmpty(role) && !string.IsNullOrEmpty(content))
                    {
                        apiMessages.Add(new SseMessage { Role = role, Content = content });
                    }
                }
            }

            // If the conversation history already ends with the current question as the last
            // user message, we don't need to add it again. Otherwise, append it.
            bool lastMessageIsQuestion = apiMessages.Count > 0
                && apiMessages[apiMessages.Count - 1].Role == "user"
                && apiMessages[apiMessages.Count - 1].Content == question;

            if (!lastMessageIsQuestion && !string.IsNullOrWhiteSpace(question))
            {
                apiMessages.Add(new SseMessage { Role = "user", Content = question });
            }

            // Anthropic requires the first message to be from the user
            if (apiMessages.Count > 0 && apiMessages[0].Role != "user")
            {
                apiMessages.Insert(0, new SseMessage { Role = "user", Content = "(Interview in progress)" });
            }

            // Ensure we have at least one message
            if (apiMessages.Count == 0)
            {
                apiMessages.Add(new SseMessage { Role = "user", Content = question ?? "Hello" });
            }

            return apiMessages;
        }

        #endregion

        #region Helpers

        /// <summary>
        /// Attempt to extract an HTTP status code from an exception message.
        /// Returns null if parsing fails.
        /// </summary>
        private static int? GetStatusCodeFromMessage(string message)
        {
            if (string.IsNullOrEmpty(message)) return null;

            // Look for patterns like "HTTP 429" or "HTTP 500"
            var httpIdx = message.IndexOf("HTTP ", StringComparison.OrdinalIgnoreCase);
            if (httpIdx >= 0)
            {
                var numStart = httpIdx + 5;
                var numStr = "";
                for (int i = numStart; i < message.Length && char.IsDigit(message[i]); i++)
                {
                    numStr += message[i];
                }
                if (int.TryParse(numStr, out var code))
                    return code;
            }

            return null;
        }

        #endregion

        #region SSE Event DTOs

        /// <summary>
        /// Request body for the Anthropic Messages API (supports both streaming and non-streaming).
        /// </summary>
        internal class SseRequestBody
        {
            [JsonPropertyName("model")]
            public string Model { get; set; }

            [JsonPropertyName("max_tokens")]
            public int MaxTokens { get; set; }

            [JsonPropertyName("system")]
            public string System { get; set; }

            [JsonPropertyName("stream")]
            public bool? Stream { get; set; }

            [JsonPropertyName("messages")]
            public List<SseMessage> Messages { get; set; }
        }

        /// <summary>
        /// A single message in the Anthropic Messages API request.
        /// </summary>
        internal class SseMessage
        {
            [JsonPropertyName("role")]
            public string Role { get; set; }

            [JsonPropertyName("content")]
            public string Content { get; set; }
        }

        /// <summary>
        /// SSE event: content_block_delta
        /// Carries incremental text output from the model.
        /// </summary>
        internal class SseContentBlockDeltaEvent
        {
            [JsonPropertyName("type")]
            public string Type { get; set; }

            [JsonPropertyName("index")]
            public int Index { get; set; }

            [JsonPropertyName("delta")]
            public SseDelta Delta { get; set; }
        }

        /// <summary>
        /// Delta payload within a content_block_delta event.
        /// </summary>
        internal class SseDelta
        {
            [JsonPropertyName("type")]
            public string Type { get; set; }

            [JsonPropertyName("text")]
            public string Text { get; set; }
        }

        /// <summary>
        /// SSE event: message_start
        /// Contains the initial message metadata.
        /// </summary>
        internal class SseMessageStartEvent
        {
            [JsonPropertyName("type")]
            public string Type { get; set; }

            [JsonPropertyName("message")]
            public SseMessageInfo Message { get; set; }
        }

        /// <summary>
        /// Message metadata within a message_start event.
        /// </summary>
        internal class SseMessageInfo
        {
            [JsonPropertyName("id")]
            public string Id { get; set; }

            [JsonPropertyName("type")]
            public string Type { get; set; }

            [JsonPropertyName("role")]
            public string Role { get; set; }

            [JsonPropertyName("model")]
            public string Model { get; set; }

            [JsonPropertyName("usage")]
            public SseUsage Usage { get; set; }
        }

        /// <summary>
        /// SSE event: message_delta
        /// Carries end-of-message metadata such as stop_reason.
        /// </summary>
        internal class SseMessageDeltaEvent
        {
            [JsonPropertyName("type")]
            public string Type { get; set; }

            [JsonPropertyName("delta")]
            public SseMessageDelta Delta { get; set; }

            [JsonPropertyName("usage")]
            public SseUsage Usage { get; set; }
        }

        /// <summary>
        /// Delta payload within a message_delta event.
        /// </summary>
        internal class SseMessageDelta
        {
            [JsonPropertyName("stop_reason")]
            public string StopReason { get; set; }

            [JsonPropertyName("stop_sequence")]
            public string StopSequence { get; set; }
        }

        /// <summary>
        /// Token usage information.
        /// </summary>
        internal class SseUsage
        {
            [JsonPropertyName("input_tokens")]
            public int InputTokens { get; set; }

            [JsonPropertyName("output_tokens")]
            public int OutputTokens { get; set; }
        }

        /// <summary>
        /// SSE event: error
        /// </summary>
        internal class SseErrorEvent
        {
            [JsonPropertyName("type")]
            public string Type { get; set; }

            [JsonPropertyName("error")]
            public SseErrorDetail Error { get; set; }
        }

        /// <summary>
        /// Error detail within an SSE error event.
        /// </summary>
        internal class SseErrorDetail
        {
            [JsonPropertyName("type")]
            public string Type { get; set; }

            [JsonPropertyName("message")]
            public string Message { get; set; }
        }

        #endregion
    }
}
