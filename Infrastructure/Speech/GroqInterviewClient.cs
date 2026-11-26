using System;
using System.Diagnostics;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using InterviewMasterApp.Application;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Infrastructure.Speech
{
    /// <summary>
    /// Groq API client for Whisper STT (with language + vocabulary prompt + retry) and fast LLM classification/answering.
    /// </summary>
    public class GroqInterviewClient : IGroqInterviewClient
    {
        private readonly string _apiKey;
        private readonly string _whisperUrl = AppConstants.ApiUrls.GroqTranscriptions;
        private readonly string _chatUrl = AppConstants.ApiUrls.GroqChat;
        private readonly HttpClient _http;
        private CancellationTokenSource? _currentCts;
        private readonly object _ctsLock = new();
        private bool _isWarm;

        public GroqInterviewClient(string apiKey, HttpClient? httpClient = null)
        {
            _apiKey = apiKey ?? throw new ArgumentNullException(nameof(apiKey));
            _http = httpClient ?? new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        }

        public async Task WarmupConnectionAsync()
        {
            if (_isWarm) return;
            try
            {
                using var req = new HttpRequestMessage(HttpMethod.Head, "https://api.groq.com");
                using var _ = await _http.SendAsync(req).ConfigureAwait(false);
                _isWarm = true;
            }
            catch { }
        }

        public void CancelCurrentRequest()
        {
            lock (_ctsLock)
            {
                if (_currentCts != null && !_currentCts.IsCancellationRequested)
                    _currentCts.Cancel();
            }
        }

        private CancellationTokenSource BeginRequestToken(CancellationToken ct)
        {
            var linked = CancellationTokenSource.CreateLinkedTokenSource(ct);
            lock (_ctsLock)
            {
                _currentCts = linked;
            }
            return linked;
        }

        private void EndRequestToken(CancellationTokenSource linked)
        {
            lock (_ctsLock)
            {
                if (ReferenceEquals(_currentCts, linked))
                    _currentCts = null;
            }
            linked.Dispose();
        }

        public async Task<(string Text, double LatencyMs)> TranscribeAsync(
            byte[] audioData,
            string filename = "audio.wav",
            CancellationToken ct = default)
        {
            var sw = Stopwatch.StartNew();
            const int maxAttempts = 3;
            double[] backoffs = { 0.5, 1.0, 1.5 };
            Exception? lastEx = null;

            var (uploadName, mimeType) = GroqRequestTuning.TranscriptionUpload(audioData);
            if (!string.IsNullOrWhiteSpace(filename) && filename != "audio.wav") uploadName = filename;

            var settings = AppSettings.Shared;
            var langCode = settings.LanguageCode;
            var vocabPrompt = settings.WhisperVocabulary;

            var linkedCts = BeginRequestToken(ct);
            try
            {
                var token = linkedCts.Token;
                for (int attempt = 0; attempt < maxAttempts; attempt++)
                {
                    try
                    {
                        using var content = new MultipartFormDataContent(Guid.NewGuid().ToString());
                        content.Add(new StringContent(AppConstants.Models.GroqWhisper), "model");
                        if (!string.IsNullOrWhiteSpace(langCode))
                            content.Add(new StringContent(langCode), "language");
                        if (!string.IsNullOrWhiteSpace(vocabPrompt))
                            content.Add(new StringContent(vocabPrompt), "prompt");

                        var audioContent = new ByteArrayContent(audioData);
                        audioContent.Headers.ContentType = new MediaTypeHeaderValue(mimeType);
                        content.Add(audioContent, "file", uploadName);

                        using var req = new HttpRequestMessage(HttpMethod.Post, _whisperUrl);
                        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
                        req.Content = content;

                        using var resp = await _http.SendAsync(req, token).ConfigureAwait(false);
                        var data = await resp.Content.ReadAsStringAsync(token).ConfigureAwait(false);

                        if ((int)resp.StatusCode is >= 400 and < 500)
                            throw new HttpRequestException($"HTTP {(int)resp.StatusCode}: Transcription failed: {data}");
                        if (!resp.IsSuccessStatusCode)
                            throw new HttpRequestException($"HTTP {(int)resp.StatusCode}: {data}");

                        var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                        var doc = JsonSerializer.Deserialize<GroqTranscriptionResponse>(data, options);
                        sw.Stop();
                        return (doc?.Text ?? string.Empty, sw.Elapsed.TotalMilliseconds);
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
                            await Task.Delay(TimeSpan.FromSeconds(backoffs[attempt]), token).ConfigureAwait(false);
                    }
                }

                throw lastEx ?? new Exception("Groq transcription failed after retries.");
            }
            finally
            {
                EndRequestToken(linkedCts);
            }
        }

        public async Task<(string Answer, double LatencyMs)> GenerateAnswerAsync(
            string topic,
            string transcription,
            string? userBackground = null,
            CancellationToken ct = default)
        {
            var sw = Stopwatch.StartNew();
            var settings = AppSettings.Shared;
            var bg = !string.IsNullOrWhiteSpace(userBackground)
                ? $"\n=== USER'S BACKGROUND ===\n{userBackground}\n=== END BACKGROUND ===\n"
                : string.Empty;

            var prompt =
$@"Technical Interview Coach. Speakable cue-card bullets.
{settings.InterviewContext}
{bg}
Q: ""{transcription}""
Topic: {topic}

{settings.AnswerStyleInstruction}
{settings.LanguageInstruction}";

            var body = new
            {
                model = AppConstants.Models.GroqLlama,
                messages = new[] { new { role = "user", content = prompt } },
                max_tokens = AppConstants.MaxTokens.GroqAnswer
            };

            var json = JsonSerializer.Serialize(body);
            using var req = new HttpRequestMessage(HttpMethod.Post, _chatUrl);
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
            req.Content = new StringContent(json, Encoding.UTF8, "application/json");

            using var resp = await _http.SendAsync(req, ct).ConfigureAwait(false);
            var data = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            sw.Stop();
            if (!resp.IsSuccessStatusCode)
                return ($"API error: {resp.StatusCode}", sw.Elapsed.TotalMilliseconds);

            try
            {
                var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var decoded = JsonSerializer.Deserialize<GroqChatResponse>(data, opts);
                return (decoded?.Choices?[0]?.Message?.Content?.Trim() ?? string.Empty, sw.Elapsed.TotalMilliseconds);
            }
            catch
            {
                return ("Failed to decode response", sw.Elapsed.TotalMilliseconds);
            }
        }

        public async Task<(UtteranceClassification Classification, double LatencyMs)> ClassifyUtteranceAsync(
            string text,
            string buffer,
            string? lastTopic,
            CancellationToken ct = default)
        {
            var sw = Stopwatch.StartNew();
            var combined = string.IsNullOrWhiteSpace(buffer) ? text : $"{buffer} {text}";
            var lastTopicNote = !string.IsNullOrWhiteSpace(lastTopic) ? $"Last topic: {lastTopic}" : string.Empty;

            var prompt =
$@"Classify this utterance. Return ONLY: STATUS,TOPIC

Text: ""{combined}""
{lastTopicNote}

IMPORTANT: This is speech-to-text from a technical interview. Words may be misheard.
Use context to interpret what makes sense technically (e.g., ""Ray vs ArrayList"" -> Array vs ArrayList).

STATUS (pick one):
- question = asking about something OR mentioning a topic (wants info)
- incomplete = cut off mid-sentence (""What is the"", ""Can you"")
- answer = user responding/explaining (any length). Includes: ""Yes, sure"", ""Thank you"", ""Okay, I understand"", any explanation
- filler = ONLY single meaningless sounds: ""um"", ""uh"", ""hmm"", ""ah"". NOT ""okay"", ""yes"", ""thank you""

Short topic mentions like ""polymorphism"", ""singleton pattern"" = question

TOPICS:
array, arrayList, linkedList, hashMap, hashSet, treeMap, queue, collections, threads, process, synchronized, volatile, deadlock, locks, jvm, jdk, jre, garbageCollection, heap, stack, oop, inheritance, polymorphism, encapsulation, abstraction, abstractClass, interface, lambda, streamApi, optional, exceptions, closure, hoisting, eventLoop, promises, asyncAwait, reactHooks, typescript, bigO, sorting, binarySearch, recursion, dynamicProgramming, bfs, dfs, systemDesign, caching, redis, loadBalancing, database, sql, nosql, microservices, rest, singleton, factory, builder, observer, strategy, dependencyInjection, solid, testing, unitTest, playwright, docker, kubernetes, cicd, git, aws, linux, rag, llm, agents, evals, ml, background, experience, followUp, unknown";

            var body = new
            {
                model = AppConstants.Models.GroqLlama,
                messages = new[] { new { role = "user", content = prompt } },
                max_tokens = 20,
                temperature = 0
            };

            var json = JsonSerializer.Serialize(body);
            using var req = new HttpRequestMessage(HttpMethod.Post, _chatUrl);
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
            req.Content = new StringContent(json, Encoding.UTF8, "application/json");

            using var resp = await _http.SendAsync(req, ct).ConfigureAwait(false);
            var data = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            sw.Stop();

            try
            {
                var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var decoded = JsonSerializer.Deserialize<GroqChatResponse>(data, opts);
                var raw = decoded?.Choices?[0]?.Message?.Content?.Trim().ToLowerInvariant() ?? "question,unknown";
                var cleaned = raw.Replace(":", ",").Replace(" ", "");
                var parts = cleaned.Split(',');
                var status = parts.Length > 0 ? parts[0] : "question";
                var topic = parts.Length > 1 ? parts[1] : "unknown";
                return (new UtteranceClassification { Status = status, Topic = topic }, sw.Elapsed.TotalMilliseconds);
            }
            catch
            {
                return (new UtteranceClassification { Status = "question", Topic = "unknown" }, sw.Elapsed.TotalMilliseconds);
            }
        }

        private class GroqTranscriptionResponse { public string? Text { get; set; } }
        private class GroqChatResponse { public GroqChoice[]? Choices { get; set; } }
        private class GroqChoice { public GroqMessage? Message { get; set; } }
        private class GroqMessage { public string? Content { get; set; } }
    }
}
