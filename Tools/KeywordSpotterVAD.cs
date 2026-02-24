using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using NAudio.Wave;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;

namespace InterviewMasterApp.Tools
{
    /// <summary>
    /// Keyword Spotter with Voice Activity Detection (VAD) - WPF Application
    /// Ported from Swift: keyword_spotter_vad.swift (2049 lines)
    ///
    /// Continuously listens and automatically detects speech segments using Silero VAD
    /// Features:
    /// - Voice Activity Detection with Silero VAD ONNX model
    /// - Voice profile for speaker identification (pitch, jitter, shimmer)
    /// - Groq Whisper transcription
    /// - Topic detection with LLM
    /// - Automatic interview answer generation
    /// - Scenario logging for analysis
    ///
    /// Usage: KeywordSpotterVAD.exe <GROQ_API_KEY>
    /// </summary>
    public partial class KeywordSpotterVADWindow : Window
    {
        private readonly GroqClient _groqClient;
        private readonly TopicMatcher _topicMatcher = new();
        private readonly VADRecorder _vadRecorder;
        private readonly ScenarioLogger _logger = new();
        private readonly VoiceProfile _voiceProfile;

        private bool _isListening;
        private string? _lastTopic;
        private List<string> _conversationContext = new();

        // UI Elements
        private TextBlock _statusLabel = null!;
        private TextBlock _resultLabel = null!;
        private Button _listenButton = null!;
        private TextBlock _latencyLabel = null!;
        private ProgressBar _levelIndicator = null!;
        private TextBlock _levelLabel = null!;
        private TextBlock _vadStatus = null!;
        private TextBlock _segmentCountLabel = null!;
        private TextBlock _profileLabel = null!;

        private int _segmentCount;

        public KeywordSpotterVADWindow(string apiKey)
        {
            _groqClient = new GroqClient(apiKey);
            _vadRecorder = new VADRecorder("Models/silero-vad-onnx/silero_vad.onnx");

            // Load or create voice profile
            _voiceProfile = VoiceProfile.Load() ?? new VoiceProfile();

            InitializeComponent();
            SetupCallbacks();

            _logger.StartScenario("keyword_spotter_vad_session");
        }

        private void InitializeComponent()
        {
            Title = "Keyword Spotter with VAD";
            Width = 700;
            Height = 640;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            Background = new SolidColorBrush(Color.FromRgb(40, 40, 45));

            var canvas = new Canvas();

            // Title
            var titleLabel = new TextBlock
            {
                Text = "🎤 Interview Assistant with Voice Detection",
                FontSize = 20,
                FontWeight = FontWeights.Bold,
                Foreground = Brushes.White,
                Margin = new Thickness(20, 20, 20, 10)
            };
            Canvas.SetTop(titleLabel, 20);
            Canvas.SetLeft(titleLabel, 20);
            canvas.Children.Add(titleLabel);

            // Instructions
            var instructions = new TextBlock
            {
                Text = "Click Start to begin continuous listening. Speak naturally - VAD will auto-detect speech.",
                FontSize = 12,
                Foreground = new SolidColorBrush(Color.FromRgb(153, 153, 153)),
                Margin = new Thickness(20, 55, 20, 10),
                TextWrapping = TextWrapping.Wrap
            };
            Canvas.SetTop(instructions, 55);
            Canvas.SetLeft(instructions, 20);
            canvas.Children.Add(instructions);

            // Listen button
            _listenButton = new Button
            {
                Content = "▶️ Start Listening",
                FontSize = 16,
                FontWeight = FontWeights.Medium,
                Width = 200,
                Height = 40,
                Background = new SolidColorBrush(Color.FromRgb(52, 199, 89)),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0)
            };
            _listenButton.Click += ToggleListening;
            Canvas.SetTop(_listenButton, 90);
            Canvas.SetLeft(_listenButton, 250);
            canvas.Children.Add(_listenButton);

            // VAD Status
            _vadStatus = new TextBlock
            {
                Text = "VAD: Not loaded",
                FontSize = 11,
                FontFamily = new FontFamily("Consolas"),
                Foreground = new SolidColorBrush(Color.FromRgb(255, 149, 0))
            };
            Canvas.SetTop(_vadStatus, 140);
            Canvas.SetLeft(_vadStatus, 20);
            canvas.Children.Add(_vadStatus);

            // Segment count
            _segmentCountLabel = new TextBlock
            {
                Text = "Segments: 0",
                FontSize = 11,
                FontFamily = new FontFamily("Consolas"),
                Foreground = new SolidColorBrush(Color.FromRgb(0, 122, 255))
            };
            Canvas.SetTop(_segmentCountLabel, 140);
            Canvas.SetLeft(_segmentCountLabel, 200);
            canvas.Children.Add(_segmentCountLabel);

            // Profile status
            _profileLabel = new TextBlock
            {
                Text = VoiceProfile.Exists ? "👤 Profile: Loaded" : "👤 Profile: Learning...",
                FontSize = 11,
                FontFamily = new FontFamily("Consolas"),
                Foreground = VoiceProfile.Exists
                    ? new SolidColorBrush(Color.FromRgb(52, 199, 89))
                    : new SolidColorBrush(Color.FromRgb(255, 149, 0))
            };
            Canvas.SetTop(_profileLabel, 140);
            Canvas.SetLeft(_profileLabel, 350);
            canvas.Children.Add(_profileLabel);

            // Level indicator
            _levelIndicator = new ProgressBar
            {
                Minimum = 0,
                Maximum = 100,
                Value = 0,
                Height = 20,
                Width = 560
            };
            Canvas.SetTop(_levelIndicator, 170);
            Canvas.SetLeft(_levelIndicator, 20);
            canvas.Children.Add(_levelIndicator);

            _levelLabel = new TextBlock
            {
                Text = "Level: 0.0 dB",
                FontSize = 11,
                FontFamily = new FontFamily("Consolas"),
                Foreground = new SolidColorBrush(Color.FromRgb(153, 153, 153))
            };
            Canvas.SetTop(_levelLabel, 195);
            Canvas.SetLeft(_levelLabel, 20);
            canvas.Children.Add(_levelLabel);

            // Status
            _statusLabel = new TextBlock
            {
                Text = "Ready - click Start to begin continuous listening",
                FontSize = 14,
                Foreground = Brushes.White,
                TextWrapping = TextWrapping.Wrap,
                Width = 660
            };
            Canvas.SetTop(_statusLabel, 220);
            Canvas.SetLeft(_statusLabel, 20);
            canvas.Children.Add(_statusLabel);

            // Latency
            _latencyLabel = new TextBlock
            {
                Text = "",
                FontSize = 12,
                FontFamily = new FontFamily("Consolas"),
                Foreground = new SolidColorBrush(Color.FromRgb(52, 199, 89)),
                TextWrapping = TextWrapping.Wrap,
                Width = 660
            };
            Canvas.SetTop(_latencyLabel, 250);
            Canvas.SetLeft(_latencyLabel, 20);
            canvas.Children.Add(_latencyLabel);

            // Result box
            var resultBorder = new Border
            {
                BorderBrush = new SolidColorBrush(Color.FromRgb(60, 60, 67)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(8),
                Background = new SolidColorBrush(Color.FromRgb(28, 28, 30)),
                Width = 660,
                Height = 330
            };
            Canvas.SetTop(resultBorder, 280);
            Canvas.SetLeft(resultBorder, 20);

            var scrollViewer = new ScrollViewer
            {
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                Padding = new Thickness(10)
            };

            _resultLabel = new TextBlock
            {
                Text = "Waiting for speech...",
                FontSize = 12,
                FontFamily = new FontFamily("Consolas"),
                Foreground = Brushes.White,
                TextWrapping = TextWrapping.Wrap
            };

            scrollViewer.Content = _resultLabel;
            resultBorder.Child = scrollViewer;
            canvas.Children.Add(resultBorder);

            Content = canvas;
        }

        private void SetupCallbacks()
        {
            // VAD status callback
            _vadRecorder.OnVADStatus = (status) =>
            {
                Dispatcher.Invoke(() =>
                {
                    _vadStatus.Text = $"VAD: {status}";
                    _vadStatus.Foreground = status == "Ready"
                        ? new SolidColorBrush(Color.FromRgb(52, 199, 89))
                        : new SolidColorBrush(Color.FromRgb(255, 149, 0));
                });
            };

            // Level update callback
            _vadRecorder.OnLevelUpdate = (db, isSpeech) =>
            {
                Dispatcher.Invoke(() =>
                {
                    var normalized = Math.Max(0, Math.Min(100, (db + 50) * 2));
                    _levelIndicator.Value = normalized;
                    _levelLabel.Text = $"Level: {db:F1} dB";
                    _levelIndicator.Foreground = isSpeech
                        ? new SolidColorBrush(Color.FromRgb(255, 59, 48))
                        : new SolidColorBrush(Color.FromRgb(52, 199, 89));
                });
            };

            // Speech segment callback
            _vadRecorder.OnSpeechSegment = async (audioData, durationMs) =>
            {
                _segmentCount++;
                await Dispatcher.InvokeAsync(() =>
                {
                    _segmentCountLabel.Text = $"Segments: {_segmentCount}";
                    _statusLabel.Text = $"🎙️ Processing segment #{_segmentCount} ({durationMs}ms)...";
                });

                _logger.Log("speech_start", new Dictionary<string, object>
                {
                    {"segment_id", _segmentCount},
                    {"duration_ms", durationMs}
                });

                await ProcessSpeechSegment(audioData, _segmentCount);
            };
        }

        private void ToggleListening(object sender, RoutedEventArgs e)
        {
            if (_isListening)
            {
                StopListening();
            }
            else
            {
                StartListening();
            }
        }

        private void StartListening()
        {
            try
            {
                _vadRecorder.StartListening();
                _isListening = true;
                _segmentCount = 0;

                _listenButton.Content = "⏸️ Stop Listening";
                _listenButton.Background = new SolidColorBrush(Color.FromRgb(255, 59, 48));
                _statusLabel.Text = "🎧 Listening... Speak naturally into your microphone";
                _statusLabel.Foreground = new SolidColorBrush(Color.FromRgb(52, 199, 89));
                _resultLabel.Text = "Listening for speech...";

                _logger.Log("listening_start");
            }
            catch (Exception ex)
            {
                _statusLabel.Text = $"Error: {ex.Message}";
                _statusLabel.Foreground = new SolidColorBrush(Color.FromRgb(255, 59, 48));
            }
        }

        private void StopListening()
        {
            _vadRecorder.StopListening();
            _isListening = false;

            _listenButton.Content = "▶️ Start Listening";
            _listenButton.Background = new SolidColorBrush(Color.FromRgb(52, 199, 89));
            _statusLabel.Text = "Stopped - click Start to resume";
            _statusLabel.Foreground = Brushes.White;

            _logger.Log("listening_stop");
            var logFile = _logger.Save();
            if (logFile != null)
            {
                _statusLabel.Text += $" (Log saved: {Path.GetFileName(logFile)})";
            }
        }

        private async Task ProcessSpeechSegment(byte[] audioData, int segmentId)
        {
            var totalStart = DateTime.Now;

            try
            {
                // Step 1: Transcribe with Groq Whisper
                _logger.Log("stt_start", new Dictionary<string, object> { {"segment_id", segmentId} });

                var (rawText, sttLatency) = await _groqClient.TranscribeAsync(audioData, "segment.wav");

                _logger.Log("stt_end", new Dictionary<string, object>
                {
                    {"segment_id", segmentId},
                    {"text", rawText},
                    {"latency_ms", sttLatency}
                });

                if (string.IsNullOrWhiteSpace(rawText))
                {
                    await Dispatcher.InvokeAsync(() =>
                    {
                        _statusLabel.Text = "⚠️ Empty transcription";
                    });
                    return;
                }

                // Step 2: Detect topic
                _logger.Log("topic_start", new Dictionary<string, object>
                {
                    {"segment_id", segmentId},
                    {"transcription", rawText}
                });

                var context = string.Join("\n", _conversationContext.TakeLast(3));
                var (topic, topicLatency) = await _groqClient.DetectTopicAsync(rawText, context, _lastTopic);

                _logger.Log("topic_end", new Dictionary<string, object>
                {
                    {"segment_id", segmentId},
                    {"topic", topic},
                    {"latency_ms", topicLatency}
                });

                // Step 3: Generate answer if it's a question
                string? answer = null;
                double answerLatency = 0;

                if (topic != "answer" && topic != "unknown" && topic != "followUp")
                {
                    _logger.Log("answer_start", new Dictionary<string, object>
                    {
                        {"segment_id", segmentId},
                        {"topic", topic}
                    });

                    (answer, answerLatency) = await _groqClient.GenerateAnswerAsync(topic, rawText);

                    _logger.Log("answer_end", new Dictionary<string, object>
                    {
                        {"segment_id", segmentId},
                        {"answer_length", answer?.Length ?? 0},
                        {"latency_ms", answerLatency}
                    });

                    _lastTopic = topic;
                }

                var totalLatency = (DateTime.Now - totalStart).TotalMilliseconds;

                // Update conversation context
                _conversationContext.Add($"{segmentId}. {rawText}");
                if (_conversationContext.Count > 10)
                {
                    _conversationContext.RemoveAt(0);
                }

                // Update UI
                await Dispatcher.InvokeAsync(() =>
                {
                    _latencyLabel.Text = $"⚡ STT: {sttLatency:F0}ms | Topic: {topicLatency:F0}ms | Answer: {answerLatency:F0}ms | Total: {totalLatency:F0}ms";

                    var topicDisplay = topic == "followUp" ? "Follow-up" :
                                      topic == "answer" ? "User answering" :
                                      topic == "unknown" ? "Unknown" : topic;

                    _statusLabel.Text = $"✅ Segment #{segmentId}: {topicDisplay}";
                    _statusLabel.Foreground = topic == "unknown"
                        ? new SolidColorBrush(Color.FromRgb(255, 204, 0))
                        : new SolidColorBrush(Color.FromRgb(52, 199, 89));

                    var result = $"Segment #{segmentId}:\n";
                    result += $"Transcription: \"{rawText}\"\n";
                    result += $"Topic: {topicDisplay}\n";

                    if (answer != null)
                    {
                        result += $"\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
                        result += $"ANSWER:\n{answer}\n";
                    }

                    result += $"\n{'═',80}\n\n";

                    _resultLabel.Text = result + _resultLabel.Text;
                });
            }
            catch (Exception ex)
            {
                _logger.Log("error", new Dictionary<string, object>
                {
                    {"segment_id", segmentId},
                    {"message", ex.Message}
                });

                await Dispatcher.InvokeAsync(() =>
                {
                    _statusLabel.Text = $"❌ Error in segment #{segmentId}";
                    _statusLabel.Foreground = new SolidColorBrush(Color.FromRgb(255, 59, 48));
                    _resultLabel.Text = $"Error: {ex.Message}\n\n" + _resultLabel.Text;
                });
            }
        }

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            if (_isListening)
            {
                StopListening();
            }

            _vadRecorder.Dispose();
            _logger.Save();

            base.OnClosing(e);
        }
    }

    // MARK: - Voice Profile (Speaker Identification)

    public class VoiceProfile
    {
        public double AvgPitch { get; set; }
        public double PitchStdDev { get; set; }
        public double AvgJitter { get; set; }
        public double AvgShimmer { get; set; }
        public int SampleCount { get; set; }

        private static readonly string ProfilePath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".interview_master_voice_profile.json");

        public static bool Exists => File.Exists(ProfilePath);

        public static VoiceProfile? Load()
        {
            if (!File.Exists(ProfilePath)) return null;
            var json = File.ReadAllText(ProfilePath);
            return JsonSerializer.Deserialize<VoiceProfile>(json);
        }

        public void Save()
        {
            var json = JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(ProfilePath, json);
        }

        public static void Delete()
        {
            if (File.Exists(ProfilePath))
                File.Delete(ProfilePath);
        }
    }

    // MARK: - Scenario Logger

    public class ScenarioLogger
    {
        private List<Dictionary<string, object>> _events = new();
        private DateTime _startTime = DateTime.Now;
        private string? _scenarioName;
        private readonly string _outputDir;

        public ScenarioLogger()
        {
            _outputDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                "interview_scenarios");
            Directory.CreateDirectory(_outputDir);
        }

        public void StartScenario(string name)
        {
            _scenarioName = name;
            _events.Clear();
            _startTime = DateTime.Now;
            Log("scenario_start", new Dictionary<string, object> { {"name", name} });
        }

        public void Log(string type, Dictionary<string, object>? data = null)
        {
            var ev = new Dictionary<string, object>
            {
                {"t_ms", (int)(DateTime.Now - _startTime).TotalMilliseconds},
                {"type", type}
            };

            if (data != null)
            {
                foreach (var kv in data)
                {
                    ev[kv.Key] = kv.Value;
                }
            }

            _events.Add(ev);
        }

        public string? Save()
        {
            if (_events.Count == 0) return null;

            var timestamp = DateTime.Now.ToString("yyyy-MM-ddTHH-mm-ss");
            var filename = $"{_scenarioName}_{timestamp}.json";
            var filepath = Path.Combine(_outputDir, filename);

            var output = new Dictionary<string, object>
            {
                {"scenario", _scenarioName ?? "unnamed"},
                {"recorded_at", timestamp},
                {"events", _events}
            };

            var json = JsonSerializer.Serialize(output, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(filepath, json);

            return filepath;
        }
    }

    // MARK: - VAD Recorder

    public class VADRecorder : IDisposable
    {
        private WaveInEvent? _waveIn;
        private InferenceSession? _vadSession;
        private readonly List<float> _audioBuffer = new();
        private bool _isSpeaking;
        private DateTime? _speechStartTime;
        private readonly List<byte> _speechBuffer = new();

        private const int SampleRate = 16000;
        private const int VADWindowSize = 512; // 32ms at 16kHz
        private const float SpeechThreshold = 0.5f;
        private const int MinSpeechDuration = 500; // ms
        private const int SilenceTimeout = 800; // ms

        public Action<string>? OnVADStatus { get; set; }
        public Action<float, bool>? OnLevelUpdate { get; set; }
        public Action<byte[], int>? OnSpeechSegment { get; set; }

        public VADRecorder(string modelPath)
        {
            try
            {
                _vadSession = new InferenceSession(modelPath);
                OnVADStatus?.Invoke("Ready");
            }
            catch (Exception ex)
            {
                OnVADStatus?.Invoke($"Failed: {ex.Message}");
            }
        }

        public void StartListening()
        {
            _waveIn = new WaveInEvent
            {
                WaveFormat = new WaveFormat(SampleRate, 1)
            };

            _waveIn.DataAvailable += OnDataAvailable;
            _waveIn.StartRecording();
        }

        public void StopListening()
        {
            _waveIn?.StopRecording();
            _waveIn?.Dispose();
            _waveIn = null;
        }

        private void OnDataAvailable(object? sender, WaveInEventArgs e)
        {
            // Convert bytes to floats
            for (int i = 0; i < e.BytesRecorded; i += 2)
            {
                short sample = BitConverter.ToInt16(e.Buffer, i);
                _audioBuffer.Add(sample / 32768f);
            }

            // Calculate dB level
            float max = 0;
            for (int i = 0; i < e.BytesRecorded; i += 2)
            {
                short sample = BitConverter.ToInt16(e.Buffer, i);
                max = Math.Max(max, Math.Abs(sample / 32768f));
            }
            var db = 20 * Math.Log10(max + 0.0001);

            // Process with VAD when we have enough samples
            while (_audioBuffer.Count >= VADWindowSize)
            {
                var chunk = _audioBuffer.Take(VADWindowSize).ToArray();
                _audioBuffer.RemoveRange(0, VADWindowSize);

                var isSpeech = RunVAD(chunk);
                OnLevelUpdate?.Invoke((float)db, isSpeech);

                if (isSpeech && !_isSpeaking)
                {
                    // Speech started
                    _isSpeaking = true;
                    _speechStartTime = DateTime.Now;
                    _speechBuffer.Clear();
                }

                if (_isSpeaking)
                {
                    // Collect speech audio
                    foreach (var sample in chunk)
                    {
                        short s = (short)(sample * 32768);
                        _speechBuffer.Add((byte)(s & 0xFF));
                        _speechBuffer.Add((byte)((s >> 8) & 0xFF));
                    }

                    // Check for silence timeout
                    if (!isSpeech && _speechStartTime != null)
                    {
                        var duration = (DateTime.Now - _speechStartTime.Value).TotalMilliseconds;
                        if (duration > MinSpeechDuration + SilenceTimeout)
                        {
                            // Speech ended
                            _isSpeaking = false;
                            var audioData = _speechBuffer.ToArray();
                            var durationMs = (int)(DateTime.Now - _speechStartTime.Value).TotalMilliseconds;

                            Task.Run(() => OnSpeechSegment?.Invoke(audioData, durationMs));
                        }
                    }
                }
            }
        }

        private bool RunVAD(float[] audioChunk)
        {
            if (_vadSession == null) return false;

            try
            {
                // Create input tensor [1, 512]
                var inputTensor = new DenseTensor<float>(new[] { 1, VADWindowSize });
                for (int i = 0; i < VADWindowSize; i++)
                {
                    inputTensor[0, i] = audioChunk[i];
                }

                var inputs = new List<NamedOnnxValue>
                {
                    NamedOnnxValue.CreateFromTensor("input", inputTensor)
                };

                using var results = _vadSession.Run(inputs);
                var output = results.First().AsTensor<float>();
                var probability = output[0];

                return probability > SpeechThreshold;
            }
            catch
            {
                return false;
            }
        }

        public void Dispose()
        {
            StopListening();
            _vadSession?.Dispose();
        }
    }

    // MARK: - Groq Client

    public class GroqClient
    {
        private readonly string _apiKey;
        private readonly HttpClient _httpClient = new();
        private const string WhisperUrl = "https://api.groq.com/openai/v1/audio/transcriptions";
        private const string ChatUrl = "https://api.groq.com/openai/v1/chat/completions";

        public GroqClient(string apiKey)
        {
            _apiKey = apiKey;
        }

        public async Task<(string Text, double LatencyMs)> TranscribeAsync(byte[] audioData, string filename)
        {
            var startTime = DateTime.Now;

            var boundary = Guid.NewGuid().ToString();
            var content = new MultipartFormDataContent(boundary);
            content.Add(new StringContent("whisper-large-v3"), "model");
            content.Add(new StringContent("en"), "language");
            content.Add(new ByteArrayContent(audioData), "file", filename);

            var request = new HttpRequestMessage(HttpMethod.Post, WhisperUrl);
            request.Headers.Add("Authorization", $"Bearer {_apiKey}");
            request.Content = content;

            var response = await _httpClient.SendAsync(request);
            response.EnsureSuccessStatusCode();

            var responseJson = await response.Content.ReadAsStringAsync();
            var whisperResponse = JsonSerializer.Deserialize<WhisperResponse>(responseJson);

            var latency = (DateTime.Now - startTime).TotalMilliseconds;
            return (whisperResponse?.Text ?? "", latency);
        }

        public async Task<(string Answer, double LatencyMs)> GenerateAnswerAsync(string topic, string transcription)
        {
            var startTime = DateTime.Now;

            var prompt = $@"You are a senior software engineer helping someone in a technical interview.

Question asked: ""{transcription}""
Topic: {topic}

Give a concise but complete interview answer. Include:
1. One-line definition
2. Key points (3-4 bullets)
3. Quick code example if relevant (short!)
4. One common interview follow-up or edge case

Keep it SHORT - this needs to fit on screen and be read quickly. No fluff.
Use plain text, no markdown headers.";

            var requestBody = new
            {
                model = "llama-3.1-8b-instant",
                messages = new[] { new { role = "user", content = prompt } },
                max_tokens = 400,
                temperature = 0.3
            };

            var request = new HttpRequestMessage(HttpMethod.Post, ChatUrl);
            request.Headers.Add("Authorization", $"Bearer {_apiKey}");
            request.Content = new StringContent(
                JsonSerializer.Serialize(requestBody),
                Encoding.UTF8,
                "application/json");

            var response = await _httpClient.SendAsync(request);
            response.EnsureSuccessStatusCode();

            var responseJson = await response.Content.ReadAsStringAsync();
            var chatResponse = JsonSerializer.Deserialize<ChatResponse>(responseJson);

            var answer = chatResponse?.Choices?.FirstOrDefault()?.Message?.Content?.Trim() ?? "No answer generated";
            var latency = (DateTime.Now - startTime).TotalMilliseconds;

            return (answer, latency);
        }

        public async Task<(string Topic, double LatencyMs)> DetectTopicAsync(string text, string context, string? lastTopic)
        {
            var startTime = DateTime.Now;

            var lastTopicHint = lastTopic != null ? $"Last discussed topic: {lastTopic}" : "No previous topic";

            var prompt = $@"You are an interview topic detector. Analyze the transcription and conversation context.

{lastTopicHint}

Recent conversation:
{context}

Current utterance: ""{text}""

Return ONLY ONE WORD - the topic name or ""followUp"" or ""answer"" or ""unknown"".";

            var requestBody = new
            {
                model = "llama-3.1-8b-instant",
                messages = new[] { new { role = "user", content = prompt } },
                max_tokens = 20,
                temperature = 0
            };

            var request = new HttpRequestMessage(HttpMethod.Post, ChatUrl);
            request.Headers.Add("Authorization", $"Bearer {_apiKey}");
            request.Content = new StringContent(
                JsonSerializer.Serialize(requestBody),
                Encoding.UTF8,
                "application/json");

            var response = await _httpClient.SendAsync(request);
            response.EnsureSuccessStatusCode();

            var responseJson = await response.Content.ReadAsStringAsync();
            var chatResponse = JsonSerializer.Deserialize<ChatResponse>(responseJson);

            var topic = chatResponse?.Choices?.FirstOrDefault()?.Message?.Content?.Trim().ToLowerInvariant() ?? "unknown";
            var latency = (DateTime.Now - startTime).TotalMilliseconds;

            return (topic, latency);
        }

        private class WhisperResponse
        {
            public string? Text { get; set; }
        }

        private class ChatResponse
        {
            public Choice[]? Choices { get; set; }
            public class Choice
            {
                public Message? Message { get; set; }
            }
            public class Message
            {
                public string? Content { get; set; }
            }
        }
    }

    // MARK: - Topic Matcher

    public class TopicMatcher
    {
        // Placeholder for topic matching logic
        public string? FindTopic(string text)
        {
            return null; // LLM-based topic detection is used instead
        }
    }

    // MARK: - Entry Point

    public class KeywordSpotterVADApp
    {
        [STAThread]
        public static void Main(string[] args)
        {
            if (args.Length == 0)
            {
                MessageBox.Show(
                    "Usage: KeywordSpotterVAD.exe <GROQ_API_KEY>\n\n" +
                    "Get your free API key at: https://console.groq.com\n\n" +
                    "Example:\n" +
                    "  KeywordSpotterVAD.exe gsk_xxxxxxxxxxxxx\n\n" +
                    "Note: Requires Silero VAD ONNX model at Models/silero-vad-onnx/silero_vad.onnx",
                    "Keyword Spotter VAD",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
                return;
            }

            var apiKey = args[0];
            var app = new Application();
            var window = new KeywordSpotterVADWindow(apiKey);
            app.Run(window);
        }
    }
}

