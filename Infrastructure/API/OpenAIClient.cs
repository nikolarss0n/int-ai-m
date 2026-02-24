using System;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;

namespace InterviewMasterApp.Infrastructure.API
{
    /// <summary>
    /// OpenAI Whisper client for speech-to-text. Ported from OpenAIClient.swift
    /// </summary>
    public class OpenAIClient
    {
        private readonly string _apiKey;
        private readonly string _baseUrl = "https://api.openai.com/v1/audio/transcriptions";
        private readonly string _model = "whisper-1";
        private readonly HttpClient _http;

        public OpenAIClient(string apiKey, HttpClient httpClient = null)
        {
            _apiKey = apiKey ?? throw new ArgumentNullException(nameof(apiKey));
            _http = httpClient ?? new HttpClient();
        }

        public async Task<Result<string, Exception>> TranscribeAsync(float[] audioData, double sampleRate)
        {
            var wavData = EncodeAudioToWavData(audioData, (int)sampleRate);
            if (wavData == null)
                return Result<string, Exception>.Fail(new Exception("Failed to encode audio"));

            var boundary = "Boundary-" + Guid.NewGuid().ToString();
            using var content = new MultipartFormDataContent(boundary);
            content.Headers.ContentType = new MediaTypeHeaderValue("multipart/form-data") { Parameters = { new NameValueHeaderValue("boundary", boundary) } };

            content.Add(new StringContent(_model), "model");
            content.Add(new StringContent("en"), "language");

            var audioContent = new ByteArrayContent(wavData);
            audioContent.Headers.ContentType = new MediaTypeHeaderValue("audio/wav");
            content.Add(audioContent, "file", "audio.wav");

            using var request = new HttpRequestMessage(HttpMethod.Post, _baseUrl);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
            request.Content = content;

            try
            {
                using var resp = await _http.SendAsync(request);
                var data = await resp.Content.ReadAsStringAsync();
                if (!resp.IsSuccessStatusCode)
                    return Result<string, Exception>.Fail(new Exception("Failed to transcribe"));

                // naive JSON parse to extract "text" field
                var idx = data.IndexOf("\"text\":");
                if (idx >= 0)
                {
                    var start = data.IndexOf('"', idx + 7) + 1;
                    var end = data.IndexOf('"', start);
                    if (start > 0 && end > start)
                    {
                        var text = data.Substring(start, end - start).ToLower().Trim();
                        return Result<string, Exception>.Ok(text);
                    }
                }

                return Result<string, Exception>.Fail(new Exception("Failed to parse transcription"));
            }
            catch (Exception ex)
            {
                return Result<string, Exception>.Fail(ex);
            }
        }

        private byte[] EncodeAudioToWavData(float[] audioData, int sampleRate)
        {
            try
            {
                // Convert float [-1,1] to Int16 PCM
                var int16 = new short[audioData.Length];
                for (int i = 0; i < audioData.Length; i++)
                {
                    var v = audioData[i];
                    var clamped = Math.Max(-1.0f, Math.Min(1.0f, v));
                    int16[i] = (short)(clamped * 32767);
                }

                using var ms = new MemoryStream();
                using var bw = new BinaryWriter(ms);

                // RIFF header
                bw.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));
                bw.Write((uint)(36 + int16.Length * 2));
                bw.Write(System.Text.Encoding.ASCII.GetBytes("WAVE"));

                // fmt chunk
                bw.Write(System.Text.Encoding.ASCII.GetBytes("fmt "));
                bw.Write((uint)16);
                bw.Write((ushort)1);
                bw.Write((ushort)1);
                bw.Write((uint)sampleRate);
                bw.Write((uint)(sampleRate * 2));
                bw.Write((ushort)2);
                bw.Write((ushort)16);

                // data chunk
                bw.Write(System.Text.Encoding.ASCII.GetBytes("data"));
                bw.Write((uint)(int16.Length * 2));
                foreach (var s in int16) bw.Write(s);

                return ms.ToArray();
            }
            catch
            {
                return null;
            }
        }
    }
}

