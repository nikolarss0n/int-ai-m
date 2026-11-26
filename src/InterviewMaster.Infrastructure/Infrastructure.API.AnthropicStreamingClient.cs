using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using InterviewMasterApp.Application;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Infrastructure.Storage;

namespace InterviewMasterApp.Infrastructure.API
{
    /// <summary>
    /// Unified SSE streaming LLM client supporting Anthropic Claude, xAI Grok, and OpenAI GPT-5.5.
    /// Implements combined classify-and-stream, spoken coding solutions, summarization, and session analysis.
    /// </summary>
    public class AnthropicStreamingClient : IAnthropicClient
    {
        private const string AnthropicApiVersion = "2023-06-01";

        private readonly string _apiKey;
        private readonly InterviewLlmProvider _provider;
        private readonly string _baseUrl;
        private readonly string _model;
        private readonly int _maxTokens;
        private readonly HttpClient _httpClient;

        private CancellationTokenSource? _currentRequestCts;
        private readonly object _ctsLock = new();
        private bool _isConnectionWarm;

        public InterviewLlmProvider Provider => _provider;
        public string Model => _model;

        public AnthropicStreamingClient(
            string apiKey,
            string? model = null,
            int maxTokens = AppConstants.MaxTokens.AnswerStream,
            InterviewLlmProvider provider = InterviewLlmProvider.Anthropic,
            HttpClient? httpClient = null)
        {
            _apiKey = apiKey ?? throw new ArgumentNullException(nameof(apiKey));
            _provider = provider;
            _maxTokens = maxTokens;
            _httpClient = httpClient ?? new HttpClient { Timeout = TimeSpan.FromMinutes(3) };

            switch (provider)
            {
                case InterviewLlmProvider.Xai:
                    _baseUrl = AppConstants.ApiUrls.XaiChat;
                    _model = string.IsNullOrWhiteSpace(model) ? AppConstants.Models.XaiGrok : model;
                    break;
                case InterviewLlmProvider.OpenAi:
                    _baseUrl = AppConstants.ApiUrls.OpenAiChat;
                    _model = string.IsNullOrWhiteSpace(model) ? AppSettings.Shared.OpenAiAnswerModel : model;
                    break;
                default:
                    _baseUrl = AppConstants.ApiUrls.AnthropicMessages;
                    _model = string.IsNullOrWhiteSpace(model) ? AppConstants.Models.AnthropicHaiku : model;
                    break;
            }
        }

        /// <summary>
        /// Creates a client matching <see cref="AppSettings.Shared.AnswerModel"/> and available API keys,
        /// with automatic fallback to whichever provider key is configured.
        /// </summary>
        public static AnthropicStreamingClient? CreateFromSettings(ApiKeyManager? keyManager = null)
        {
            var km = keyManager ?? ApiKeyManager.Shared;
            var preferred = AppSettings.Shared.AnswerModel;

            var order = preferred switch
            {
                AnswerModel.Gpt => new[] { InterviewLlmProvider.OpenAi, InterviewLlmProvider.Xai, InterviewLlmProvider.Anthropic },
                AnswerModel.Grok => new[] { InterviewLlmProvider.Xai, InterviewLlmProvider.Anthropic, InterviewLlmProvider.OpenAi },
                _ => new[] { InterviewLlmProvider.Anthropic, InterviewLlmProvider.Xai, InterviewLlmProvider.OpenAi }
            };

            foreach (var p in order)
            {
                var key = p switch
                {
                    InterviewLlmProvider.Anthropic => km.GetKey(ApiKeyType.Anthropic),
                    InterviewLlmProvider.Xai => km.GetKey(ApiKeyType.Xai),
                    InterviewLlmProvider.OpenAi => km.GetKey(ApiKeyType.OpenAi),
                    _ => null
                };
                if (!string.IsNullOrWhiteSpace(key))
                    return new AnthropicStreamingClient(key, provider: p);
            }
            return null;
        }

        public async Task WarmupConnectionAsync()
        {
            if (_isConnectionWarm) return;
            try
            {
                var host = _provider switch
                {
                    InterviewLlmProvider.Xai => "https://api.x.ai",
                    InterviewLlmProvider.OpenAi => "https://api.openai.com",
                    _ => "https://api.anthropic.com"
                };
                using var req = new HttpRequestMessage(HttpMethod.Head, host);
                using var _ = await _httpClient.SendAsync(req).ConfigureAwait(false);
                _isConnectionWarm = true;
            }
            catch { }
        }

        public void CancelCurrentRequest()
        {
            lock (_ctsLock)
            {
                if (_currentRequestCts != null && !_currentRequestCts.IsCancellationRequested)
                    _currentRequestCts.Cancel();
            }
        }

        public async Task StreamAnswerAsync(
            string question,
            List<object> messages,
            string userBackground,
            Action<string> onChunk,
            CancellationToken ct = default)
        {
            var systemPrompt = BuildAnswerSystemPrompt(userBackground, resumeText: null, questionText: question, topic: "unknown", recentContext: string.Empty, memoryContext: null, pinnedSolution: null);
            var apiMessages = BuildApiMessages(question, messages);
            await StreamRawAsync(systemPrompt, apiMessages, AppConstants.MaxTokens.AnswerStream, onChunk, ct).ConfigureAwait(false);
        }

        public async Task<ClassifyAndStreamResult> ClassifyAndStreamAnswerAsync(
            string utterance,
            string recentContext,
            string userBackground,
            string? resumeText,
            string? memoryContext,
            string? pinnedSolution,
            string? lastTopic,
            Action<UtteranceClassification> onClassification,
            Action<string> onAnswerChunk,
            CancellationToken ct = default)
        {
            var settings = AppSettings.Shared;
            var systemPrompt = BuildClassifyAndAnswerSystemPrompt(settings, userBackground, resumeText, utterance, lastTopic ?? "unknown", recentContext, memoryContext, pinnedSolution);

            var userPrompt = new StringBuilder();
            if (!string.IsNullOrWhiteSpace(lastTopic))
                userPrompt.AppendLine($"Previous topic: {lastTopic}");
            if (!string.IsNullOrWhiteSpace(recentContext) && recentContext != "No previous conversation.")
                userPrompt.AppendLine($"Recent conversation:\n{recentContext}\n");
            userPrompt.AppendLine($"Interviewer just said:\n\"{utterance}\"");

            var messages = new List<ChatMessage> { new("user", userPrompt.ToString()) };

            var rawAccum = new StringBuilder();
            bool classificationEmitted = false;
            var emittedAnswerLen = 0;
            var classification = new UtteranceClassification { Status = "question", Topic = lastTopic ?? "unknown" };

            await StreamRawAsync(systemPrompt, messages, AppConstants.MaxTokens.AnswerStream + 80, chunk =>
            {
                rawAccum.Append(chunk);
                var parsed = ClassifierStreamParser.Parse(rawAccum.ToString(), headerless: false, streamEnded: false);

                if (!classificationEmitted && (parsed.StatusLine != null || parsed.FormatDrift))
                {
                    classification = parsed.StatusLine != null
                        ? ParseStatusLine(parsed.StatusLine, lastTopic)
                        : new UtteranceClassification { Status = "question", Topic = lastTopic ?? "unknown" };
                    classificationEmitted = true;
                    onClassification?.Invoke(classification);
                }

                if (parsed.Answer.Length > emittedAnswerLen)
                {
                    var delta = parsed.Answer[emittedAnswerLen..];
                    emittedAnswerLen = parsed.Answer.Length;
                    onAnswerChunk?.Invoke(delta);
                }
            }, ct).ConfigureAwait(false);

            var finalParsed = ClassifierStreamParser.Parse(rawAccum.ToString(), headerless: false, streamEnded: true);
            if (!classificationEmitted)
            {
                classification = finalParsed.StatusLine != null
                    ? ParseStatusLine(finalParsed.StatusLine, lastTopic)
                    : new UtteranceClassification { Status = "question", Topic = lastTopic ?? "unknown" };
                onClassification?.Invoke(classification);
            }

            if (finalParsed.Answer.Length > emittedAnswerLen)
            {
                var delta = finalParsed.Answer[emittedAnswerLen..];
                onAnswerChunk?.Invoke(delta);
            }

            return new ClassifyAndStreamResult(classification, finalParsed.Answer, finalParsed.FormatDrift);
        }

        public async Task<string> StreamCodingSolutionAsync(
            string task,
            string language,
            bool spoken,
            string? currentCode,
            string? changeRequest,
            Action<string> onChunk,
            CancellationToken ct = default)
        {
            var prompt = CodingInterviewStepsHelper.BuildPrompt(language, task, spoken, currentCode, changeRequest);
            var sb = new StringBuilder();
            await StreamRawAsync(
                systemPrompt: null,
                messages: new List<ChatMessage> { new("user", prompt) },
                maxTokens: AppConstants.MaxTokens.CodingSteps,
                onChunk: c => { sb.Append(c); onChunk?.Invoke(c); },
                ct: ct).ConfigureAwait(false);
            return sb.ToString();
        }

        public async Task<string> SummarizeConversationAsync(string conversationText, CancellationToken ct = default)
        {
            var prompt = $"Summarize this technical interview conversation so far in 3 concise bullet points (topics covered, candidate's key points, open threads):\n\n{conversationText}";
            var (text, _) = await SendMessageAsync(prompt, AppConstants.MaxTokens.Summarization, ct).ConfigureAwait(false);
            return text;
        }

        public async Task<SessionAnalysisResult> AnalyzeSessionAsync(string transcript, CancellationToken ct = default)
        {
            var prompt =
@"Analyze this technical interview transcript and return ONLY valid JSON with this shape:
{""topics"":[""...""],""insights"":[""...""],""strengths"":[""...""],""weaknesses"":[""...""]}

Transcript:
" + transcript;
            var (text, _) = await SendMessageAsync(prompt, AppConstants.MaxTokens.SessionAnalysis, ct).ConfigureAwait(false);
            try
            {
                var start = text.IndexOf('{');
                var end = text.LastIndexOf('}');
                var json = start >= 0 && end > start ? text[start..(end + 1)] : text;
                var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                return JsonSerializer.Deserialize<SessionAnalysisResult>(json, opts) ?? new SessionAnalysisResult();
            }
            catch
            {
                return new SessionAnalysisResult();
            }
        }

        public async Task<(string Text, double LatencyMs)> SendMessageAsync(string prompt, int maxTokens = 300, CancellationToken ct = default)
        {
            var sw = Stopwatch.StartNew();
            const int maxAttempts = 3;
            double[] backoffs = { 0.5, 1.0, 2.0 };
            Exception? lastEx = null;

            for (int attempt = 0; attempt < maxAttempts; attempt++)
            {
                try
                {
                    var body = BuildRequestPayload(null, new List<ChatMessage> { new("user", prompt) }, maxTokens, stream: false);
                    using var req = CreateHttpRequest(body);
                    using var resp = await _httpClient.SendAsync(req, ct).ConfigureAwait(false);
                    var data = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);

                    if ((int)resp.StatusCode is >= 400 and < 500)
                        throw new HttpRequestException($"HTTP {(int)resp.StatusCode}: {ExtractError(data, (int)resp.StatusCode)}");
                    if (!resp.IsSuccessStatusCode)
                        throw new HttpRequestException($"HTTP {(int)resp.StatusCode}: {data}");

                    var text = ExtractNonStreamingText(data);
                    sw.Stop();
                    return (text, sw.Elapsed.TotalMilliseconds);
                }
                catch (HttpRequestException ex) when (ex.Message.StartsWith("HTTP 4", StringComparison.Ordinal))
                {
                    throw;
                }
                catch (OperationCanceledException)
                {
                    throw;
                }
                catch (Exception ex)
                {
                    lastEx = ex;
                    if (attempt < maxAttempts - 1)
                        await Task.Delay(TimeSpan.FromSeconds(backoffs[attempt]), ct).ConfigureAwait(false);
                }
            }
            throw lastEx ?? new Exception("Request failed after retries.");
        }

        private async Task StreamRawAsync(
            string? systemPrompt,
            List<ChatMessage> messages,
            int maxTokens,
            Action<string> onChunk,
            CancellationToken ct)
        {
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
                var body = BuildRequestPayload(systemPrompt, messages, maxTokens, stream: true);
                using var req = CreateHttpRequest(body);
                using var response = await _httpClient.SendAsync(req, HttpCompletionOption.ResponseHeadersRead, token).ConfigureAwait(false);

                if (!response.IsSuccessStatusCode)
                {
                    var errBody = await response.Content.ReadAsStringAsync(token).ConfigureAwait(false);
                    throw new HttpRequestException($"HTTP {(int)response.StatusCode}: {ExtractError(errBody, (int)response.StatusCode)}");
                }

                using var stream = await response.Content.ReadAsStreamAsync(token).ConfigureAwait(false);
                using var reader = new StreamReader(stream, Encoding.UTF8);

                string? currentEvent = null;
                while (!reader.EndOfStream)
                {
                    token.ThrowIfCancellationRequested();
                    var line = await reader.ReadLineAsync(token).ConfigureAwait(false);
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
                    if (data == "[DONE]") break;

                    if (_provider == InterviewLlmProvider.Anthropic)
                    {
                        if (currentEvent == "error")
                            throw new InvalidOperationException($"Anthropic streaming error: {ExtractError(data, 500)}");
                        if (currentEvent == "content_block_delta")
                        {
                            var delta = ExtractAnthropicDelta(data);
                            if (!string.IsNullOrEmpty(delta)) onChunk?.Invoke(delta);
                        }
                    }
                    else
                    {
                        var delta = ExtractOpenAiDelta(data);
                        if (!string.IsNullOrEmpty(delta)) onChunk?.Invoke(delta);
                    }
                }
            }
            catch (OperationCanceledException) when (token.IsCancellationRequested)
            {
                // Cancelled intentionally
            }
            finally
            {
                lock (_ctsLock)
                {
                    if (_currentRequestCts == internalCts) _currentRequestCts = null;
                }
            }
        }

        private string BuildRequestPayload(string? systemPrompt, List<ChatMessage> messages, int maxTokens, bool stream)
        {
            if (_provider == InterviewLlmProvider.Anthropic)
            {
                var body = new Dictionary<string, object>
                {
                    ["model"] = _model,
                    ["max_tokens"] = maxTokens,
                    ["stream"] = stream,
                    ["messages"] = messages.Select(m => new Dictionary<string, string> { ["role"] = m.Role, ["content"] = m.Content }).ToList()
                };
                if (!string.IsNullOrWhiteSpace(systemPrompt))
                    body["system"] = systemPrompt;
                return JsonSerializer.Serialize(body);
            }

            // OpenAI / xAI wire format
            var allMsgs = new List<Dictionary<string, string>>();
            if (!string.IsNullOrWhiteSpace(systemPrompt))
                allMsgs.Add(new Dictionary<string, string> { ["role"] = "system", ["content"] = systemPrompt });
            foreach (var m in messages)
                allMsgs.Add(new Dictionary<string, string> { ["role"] = m.Role, ["content"] = m.Content });

            var payload = new Dictionary<string, object>
            {
                ["model"] = _model,
                ["stream"] = stream,
                ["messages"] = allMsgs
            };

            if (_provider == InterviewLlmProvider.OpenAi)
            {
                payload["max_completion_tokens"] = maxTokens + AppConstants.MaxTokens.OpenAiReasoningAllowance;
                payload["reasoning_effort"] = AppSettings.Shared.OpenAiReasoningEffort;
                if (AppSettings.Shared.OpenAiPriority) payload["service_tier"] = "priority";
            }
            else
            {
                payload["max_tokens"] = maxTokens;
            }

            return JsonSerializer.Serialize(payload);
        }

        private HttpRequestMessage CreateHttpRequest(string json)
        {
            var req = new HttpRequestMessage(HttpMethod.Post, _baseUrl);
            if (_provider == InterviewLlmProvider.Anthropic)
            {
                req.Headers.Add("x-api-key", _apiKey);
                req.Headers.Add("anthropic-version", AnthropicApiVersion);
            }
            else
            {
                req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
            }
            req.Content = new StringContent(json, Encoding.UTF8, "application/json");
            return req;
        }

        private string ExtractNonStreamingText(string data)
        {
            using var doc = JsonDocument.Parse(data);
            if (_provider == InterviewLlmProvider.Anthropic)
            {
                if (doc.RootElement.TryGetProperty("content", out var content) && content.GetArrayLength() > 0 &&
                    content[0].TryGetProperty("text", out var textProp))
                    return textProp.GetString()?.Trim() ?? string.Empty;
            }
            else
            {
                if (doc.RootElement.TryGetProperty("choices", out var choices) && choices.GetArrayLength() > 0 &&
                    choices[0].TryGetProperty("message", out var msg) &&
                    msg.TryGetProperty("content", out var contentProp))
                    return contentProp.GetString()?.Trim() ?? string.Empty;
            }
            return string.Empty;
        }

        private static string? ExtractAnthropicDelta(string data)
        {
            try
            {
                using var doc = JsonDocument.Parse(data);
                if (doc.RootElement.TryGetProperty("delta", out var delta) &&
                    delta.TryGetProperty("text", out var t))
                    return t.GetString();
            }
            catch { }
            return null;
        }

        private static string? ExtractOpenAiDelta(string data)
        {
            try
            {
                using var doc = JsonDocument.Parse(data);
                if (doc.RootElement.TryGetProperty("choices", out var choices) && choices.GetArrayLength() > 0 &&
                    choices[0].TryGetProperty("delta", out var delta) &&
                    delta.TryGetProperty("content", out var content))
                    return content.GetString();
            }
            catch { }
            return null;
        }

        private static string ExtractError(string body, int statusCode)
        {
            try
            {
                using var doc = JsonDocument.Parse(body);
                if (doc.RootElement.TryGetProperty("error", out var err))
                {
                    if (err.ValueKind == JsonValueKind.Object && err.TryGetProperty("message", out var msg))
                        return msg.GetString() ?? $"HTTP {statusCode}";
                    if (err.ValueKind == JsonValueKind.String)
                        return err.GetString() ?? $"HTTP {statusCode}";
                }
            }
            catch { }
            return string.IsNullOrWhiteSpace(body) ? $"HTTP {statusCode}" : body[..Math.Min(body.Length, 300)];
        }

        private static UtteranceClassification ParseStatusLine(string statusLine, string? fallbackTopic)
        {
            string status = "question";
            string topic = fallbackTopic ?? "unknown";
            foreach (var part in statusLine.Split('|', StringSplitOptions.RemoveEmptyEntries))
            {
                var trimmed = part.Trim();
                if (trimmed.StartsWith("STATUS:", StringComparison.OrdinalIgnoreCase))
                    status = trimmed[7..].Trim().ToLowerInvariant();
                else if (trimmed.StartsWith("TOPIC:", StringComparison.OrdinalIgnoreCase))
                    topic = trimmed[6..].Trim();
            }
            return new UtteranceClassification { Status = status, Topic = string.IsNullOrWhiteSpace(topic) ? "unknown" : topic };
        }

        private static string BuildClassifyAndAnswerSystemPrompt(
            AppSettings settings,
            string userBackground,
            string? resumeText,
            string utterance,
            string topic,
            string recentContext,
            string? memoryContext,
            string? pinnedSolution)
        {
            var sb = new StringBuilder();
            sb.AppendLine("You are a live technical interview co-pilot. Classify the interviewer utterance, then give a concise answer the candidate can say naturally.");
            sb.AppendLine();
            sb.AppendLine("=== OUTPUT FORMAT ===");
            sb.AppendLine("Line 1: STATUS:xxx|TOPIC:yyy");
            sb.AppendLine("Line 2: ---");
            sb.AppendLine("Line 3+: Answer (only if STATUS is question)");
            sb.AppendLine();
            sb.AppendLine("STATUS options:");
            sb.AppendLine("- question = Interviewer asking a technical/behavioral question, check-in, or implicit request (\"tell me about\", \"walk me through\").");
            sb.AppendLine("- incomplete = genuinely cut off mid-word/mid-phrase.");
            sb.AppendLine("- statement = pure confirmation/acknowledgment with NO information request (\"Great answer\", \"I see\", \"Got it\").");
            sb.AppendLine("- filler = standalone noise words (\"um\", \"hmm\", \"uh\").");
            sb.AppendLine();
            sb.AppendLine("=== INTERVIEW PROFILE ===");
            sb.AppendLine(settings.InterviewContext);
            sb.AppendLine();
            sb.AppendLine(settings.AnswerStyleInstruction);
            sb.AppendLine();
            sb.AppendLine(settings.LanguageInstruction);

            var grounding = InterviewBriefingHelper.ResumeGroundingInstruction(
                !string.IsNullOrWhiteSpace(resumeText) ? resumeText : userBackground,
                utterance,
                topic,
                recentContext);
            if (!string.IsNullOrWhiteSpace(grounding))
            {
                sb.AppendLine();
                sb.AppendLine(grounding);
            }
            else if (!string.IsNullOrWhiteSpace(userBackground))
            {
                sb.AppendLine();
                sb.AppendLine("CANDIDATE NOTES / BACKGROUND:");
                sb.AppendLine(userBackground.Length > 2000 ? userBackground[..2000] : userBackground);
            }

            if (!string.IsNullOrWhiteSpace(memoryContext))
            {
                sb.AppendLine();
                sb.AppendLine(memoryContext);
            }

            var pinnedBlock = AnswerPromptBlocks.PinnedCode(pinnedSolution);
            if (!string.IsNullOrWhiteSpace(pinnedBlock))
                sb.AppendLine(pinnedBlock);

            return sb.ToString();
        }

        private static string BuildAnswerSystemPrompt(
            string userBackground,
            string? resumeText,
            string questionText,
            string topic,
            string recentContext,
            string? memoryContext,
            string? pinnedSolution)
        {
            var settings = AppSettings.Shared;
            var sb = new StringBuilder();
            sb.AppendLine("You are a live technical interview co-pilot.");
            sb.AppendLine(settings.InterviewContext);
            sb.AppendLine();
            sb.AppendLine(settings.AnswerStyleInstruction);
            sb.AppendLine();
            sb.AppendLine(settings.LanguageInstruction);

            var grounding = InterviewBriefingHelper.ResumeGroundingInstruction(
                !string.IsNullOrWhiteSpace(resumeText) ? resumeText : userBackground,
                questionText,
                topic,
                recentContext);
            if (!string.IsNullOrWhiteSpace(grounding))
            {
                sb.AppendLine();
                sb.AppendLine(grounding);
            }
            else if (!string.IsNullOrWhiteSpace(userBackground))
            {
                sb.AppendLine();
                sb.AppendLine("CANDIDATE BACKGROUND:");
                sb.AppendLine(userBackground.Length > 2000 ? userBackground[..2000] : userBackground);
            }

            if (!string.IsNullOrWhiteSpace(memoryContext))
            {
                sb.AppendLine();
                sb.AppendLine(memoryContext);
            }

            var pinnedBlock = AnswerPromptBlocks.PinnedCode(pinnedSolution);
            if (!string.IsNullOrWhiteSpace(pinnedBlock))
                sb.AppendLine(pinnedBlock);

            return sb.ToString();
        }

        private static List<ChatMessage> BuildApiMessages(string question, List<object>? messages)
        {
            var list = new List<ChatMessage>();
            if (messages != null)
            {
                foreach (var msg in messages)
                {
                    if (msg is Dictionary<string, string> d &&
                        d.TryGetValue("role", out var r) && d.TryGetValue("content", out var c) &&
                        !string.IsNullOrEmpty(r) && !string.IsNullOrEmpty(c))
                    {
                        list.Add(new ChatMessage(r, c));
                    }
                    else if (msg is Dictionary<string, object> o &&
                             o.TryGetValue("role", out var ro) && o.TryGetValue("content", out var co))
                    {
                        var rs = ro?.ToString();
                        var cs = co?.ToString();
                        if (!string.IsNullOrEmpty(rs) && !string.IsNullOrEmpty(cs))
                            list.Add(new ChatMessage(rs, cs));
                    }
                }
            }

            if ((list.Count == 0 || list[^1].Role != "user" || list[^1].Content != question) && !string.IsNullOrWhiteSpace(question))
                list.Add(new ChatMessage("user", question));
            if (list.Count > 0 && list[0].Role != "user")
                list.Insert(0, new ChatMessage("user", "(Interview in progress)"));
            if (list.Count == 0)
                list.Add(new ChatMessage("user", question ?? "Hello"));
            return list;
        }

        private sealed record ChatMessage(string Role, string Content);
    }
}
