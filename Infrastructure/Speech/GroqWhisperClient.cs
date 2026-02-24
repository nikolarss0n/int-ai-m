using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.Tasks;

namespace InterviewMasterApp.Infrastructure.Speech
{
    public class TranscriptionResult
    {
        public string Text { get; set; }
        public double LatencyMs { get; set; }
    }

    public enum GroqError
    {
        InvalidResponse,
        ApiError
    }

    public class GroqWhisperClient
    {
        private readonly string _apiKey;
        private readonly string _baseUrl = "https://api.groq.com/openai/v1/audio/transcriptions";
        private readonly HttpClient _http;

        public GroqWhisperClient(string apiKey, HttpClient httpClient = null)
        {
            _apiKey = apiKey ?? throw new ArgumentNullException(nameof(apiKey));
            _http = httpClient ?? new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        }

        public async Task<TranscriptionResult> TranscribeAsync(byte[] audioData, string filename = "audio.wav")
        {
            var start = DateTime.UtcNow;
            var boundary = Guid.NewGuid().ToString();
            using var content = new MultipartFormDataContent(boundary);
            content.Add(new StringContent("whisper-large-v3-turbo"), "model");
            content.Add(new StringContent("en"), "language");

            var audioContent = new ByteArrayContent(audioData);
            audioContent.Headers.ContentType = new MediaTypeHeaderValue("audio/wav");
            content.Add(audioContent, "file", filename);

            using var req = new HttpRequestMessage(HttpMethod.Post, _baseUrl);
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
            req.Content = content;

            using var resp = await _http.SendAsync(req);
            var data = await resp.Content.ReadAsStringAsync();

            if (!resp.IsSuccessStatusCode)
                throw new HttpRequestException($"Groq transcription failed: {resp.StatusCode}\n{data}");

            try
            {
                var decoded = JsonSerializer.Deserialize<GroqTranscriptionResponse>(data);
                return new TranscriptionResult { Text = decoded?.Text ?? string.Empty, LatencyMs = (DateTime.UtcNow - start).TotalMilliseconds };
            }
            catch (Exception ex)
            {
                throw new Exception("Failed to decode Groq transcription response", ex);
            }
        }

        private class GroqTranscriptionResponse { public string Text { get; set; } }
    }
}
