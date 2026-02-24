using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using InterviewMasterApp.Application;

namespace InterviewMasterApp.Infrastructure.Speech
{
    /// <summary>
    /// Groq API client for interview assistance (STT + LLM) - C# port.
    /// Implements IGroqInterviewClient for use by the Application layer.
    /// </summary>
    public class GroqInterviewClient : IGroqInterviewClient
    {
        private readonly string _apiKey;
        private readonly string _whisperUrl = "https://api.groq.com/openai/v1/audio/transcriptions"; // AppConstants.APIURLs.groqTranscriptions
        private readonly string _chatUrl = "https://api.groq.com/openai/v1/chat/completions"; // AppConstants.APIURLs.groqChat
        private readonly HttpClient _http;

        public GroqInterviewClient(string apiKey, HttpClient httpClient = null)
        {
            _apiKey = apiKey ?? throw new ArgumentNullException(nameof(apiKey));
            _http = httpClient ?? new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        }

        public void CancelCurrentRequest()
        {
            // HttpClient cancellation should be handled via CancellationToken by caller
        }

        public async Task<(string Text, double LatencyMs)> TranscribeAsync(byte[] audioData, string filename = "audio.wav")
        {
            var start = DateTime.UtcNow;
            var boundary = Guid.NewGuid().ToString();
            using var content = new MultipartFormDataContent(boundary);
            content.Add(new StringContent("whisper-large-v3-turbo"), "model");
            // language and prompt could be added from AppSettings later
            var audioContent = new ByteArrayContent(audioData);
            audioContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("audio/wav");
            content.Add(audioContent, "file", filename);

            using var req = new HttpRequestMessage(HttpMethod.Post, _whisperUrl);
            req.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _apiKey);
            req.Content = content;

            using var resp = await _http.SendAsync(req);
            var data = await resp.Content.ReadAsStringAsync();

            if (!resp.IsSuccessStatusCode)
            {
                throw new HttpRequestException($"Transcription failed: {resp.StatusCode}\n{data}");
            }

            // Expecting { "text": "..." }
            try
            {
                var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var doc = JsonSerializer.Deserialize<GroqTranscriptionResponse>(data, options);
                var latency = (DateTime.UtcNow - start).TotalMilliseconds;
                System.Diagnostics.Debug.WriteLine($"[GroqSTT] raw response ({data.Length} chars): {data.Substring(0, Math.Min(200, data.Length))}");
                return (doc?.Text ?? string.Empty, latency);
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to parse transcription response: {data}", ex);
            }
        }

        public async Task<(string Answer, double LatencyMs)> GenerateAnswerAsync(string topic, string transcription, string userBackground = null)
        {
            var start = DateTime.UtcNow;
            var prompt = $"Technical Interview Coach.\nQ: \"{transcription}\"\nTopic: {topic}\n";

            var body = new
            {
                model = "llama-3.3-70b-versatile",
                messages = new[] { new { role = "user", content = prompt } },
                max_tokens = 200
            };

            var json = JsonSerializer.Serialize(body);
            using var req = new HttpRequestMessage(HttpMethod.Post, _chatUrl);
            req.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _apiKey);
            req.Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

            using var resp = await _http.SendAsync(req);
            var data = await resp.Content.ReadAsStringAsync();
            if (!resp.IsSuccessStatusCode)
                return ($"API error: {resp.StatusCode}", (DateTime.UtcNow - start).TotalMilliseconds);

            try
            {
                var jsonOpts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var decoded = JsonSerializer.Deserialize<GroqChatResponse>(data, jsonOpts);
                var answer = decoded?.Choices?[0]?.Message?.Content?.Trim() ?? "";
                return (answer, (DateTime.UtcNow - start).TotalMilliseconds);
            }
            catch
            {
                return ("Failed to decode response", (DateTime.UtcNow - start).TotalMilliseconds);
            }
        }

        public async Task<(UtteranceClassification Classification, double LatencyMs)> ClassifyUtteranceAsync(string text, string buffer, string lastTopic)
        {
            // Build prompt similar to Swift implementation
            var combined = string.IsNullOrWhiteSpace(buffer) ? text : buffer + " " + text;
            var prompt = $"Classify this utterance. Return: STATUS,TOPIC\nText: \"{combined}\"\n";

            var body = new
            {
                model = "llama-3.3-70b-versatile",
                messages = new[] { new { role = "user", content = prompt } },
                max_tokens = 20,
                temperature = 0
            };

            var json = JsonSerializer.Serialize(body);
            using var req = new HttpRequestMessage(HttpMethod.Post, _chatUrl);
            req.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _apiKey);
            req.Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

            using var resp = await _http.SendAsync(req);
            var data = await resp.Content.ReadAsStringAsync();
            var latency = (DateTime.UtcNow - DateTime.UtcNow).TotalMilliseconds; // placeholder

            try
            {
                var jsonOpts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var decoded = JsonSerializer.Deserialize<GroqChatResponse>(data, jsonOpts);
                var raw = decoded?.Choices?[0]?.Message?.Content?.Trim().ToLower() ?? "question,unknown";
                var cleaned = raw.Replace(":", ",").Replace(" ", "");
                var parts = cleaned.Split(',');
                var status = parts.Length > 0 ? parts[0] : "question";
                var topic = parts.Length > 1 ? parts[1] : "unknown";
                return (new UtteranceClassification { Status = status, Topic = topic }, latency);
            }
            catch
            {
                return (new UtteranceClassification { Status = "question", Topic = "unknown" }, latency);
            }
        }

        // UtteranceClassification is defined in InterviewMasterApp.Application

        // Response DTOs
        private class GroqTranscriptionResponse { public string Text { get; set; } }
        private class GroqChatResponse { public GroqChoice[] Choices { get; set; } public GroqError Error { get; set; } }
        private class GroqChoice { public GroqMessage Message { get; set; } }
        private class GroqMessage { public string Content { get; set; } }
        private class GroqError { public string Message { get; set; } }
    }
}
