using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using NAudio.Wave;

namespace InterviewMasterApp.Tools
{
    /// <summary>
    /// Keyword Spotter Test Harness - WPF Application
    /// Ported from Swift: keyword_spotter_test.swift
    /// Records audio, sends to Groq Whisper, matches interview keywords
    ///
    /// Usage: Set GROQ_API_KEY as command line argument or in app config
    /// Get your free API key at: https://console.groq.com
    /// </summary>
    public partial class KeywordSpotterWindow : Window
    {
        private readonly GroqWhisperClient _groqClient;
        private readonly KeywordMatcher _matcher = new();
        private readonly AudioRecorder _recorder = new();
        private bool _isRecording;

        // UI Elements
        private TextBlock _statusLabel = null!;
        private TextBlock _resultLabel = null!;
        private Button _recordButton = null!;
        private TextBlock _latencyLabel = null!;
        private ProgressBar _levelIndicator = null!;
        private TextBlock _levelLabel = null!;

        public KeywordSpotterWindow(string apiKey)
        {
            _groqClient = new GroqWhisperClient(apiKey);
            InitializeComponent();
            SetupAudioLevelCallback();
        }

        private void InitializeComponent()
        {
            Title = "Keyword Spotter Test";
            Width = 600;
            Height = 540;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            Background = new SolidColorBrush(Color.FromRgb(40, 40, 45));

            var mainPanel = new Grid();

            // Title
            var titleLabel = new TextBlock
            {
                Text = "🎤 Interview Keyword Spotter",
                FontSize = 24,
                FontWeight = FontWeights.Bold,
                Foreground = Brushes.White,
                Margin = new Thickness(20, 20, 20, 10),
                HorizontalAlignment = HorizontalAlignment.Center
            };

            // Instructions
            var instructions = new TextBlock
            {
                Text = "Press Record, say an interview topic (e.g., 'Tell me about closures'), then Stop",
                FontSize = 13,
                Foreground = new SolidColorBrush(Color.FromRgb(153, 153, 153)),
                Margin = new Thickness(20, 60, 20, 10),
                TextWrapping = TextWrapping.Wrap,
                HorizontalAlignment = HorizontalAlignment.Center
            };

            // Record button
            _recordButton = new Button
            {
                Content = "🔴 Start Recording",
                FontSize = 16,
                FontWeight = FontWeights.Medium,
                Width = 200,
                Height = 40,
                Margin = new Thickness(200, 100, 200, 10),
                Background = new SolidColorBrush(Color.FromRgb(0, 122, 255)),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0)
            };
            _recordButton.Click += ToggleRecording;

            // Level indicator
            _levelIndicator = new ProgressBar
            {
                Minimum = 0,
                Maximum = 100,
                Value = 0,
                Height = 20,
                Margin = new Thickness(100, 150, 150, 10)
            };

            _levelLabel = new TextBlock
            {
                Text = "Level: 0.0",
                FontSize = 11,
                FontFamily = new FontFamily("Consolas"),
                Foreground = new SolidColorBrush(Color.FromRgb(153, 153, 153)),
                Margin = new Thickness(460, 150, 20, 10),
                HorizontalAlignment = HorizontalAlignment.Right
            };

            // Status
            _statusLabel = new TextBlock
            {
                Text = "Ready - speak clearly into your microphone",
                FontSize = 14,
                Foreground = Brushes.White,
                Margin = new Thickness(20, 180, 20, 10),
                TextAlignment = TextAlignment.Center,
                HorizontalAlignment = HorizontalAlignment.Center
            };

            // Latency
            _latencyLabel = new TextBlock
            {
                Text = "",
                FontSize = 12,
                FontFamily = new FontFamily("Consolas"),
                Foreground = new SolidColorBrush(Color.FromRgb(52, 199, 89)),
                Margin = new Thickness(20, 210, 20, 10),
                TextAlignment = TextAlignment.Center,
                HorizontalAlignment = HorizontalAlignment.Center
            };

            // Result box
            var resultBorder = new Border
            {
                BorderBrush = new SolidColorBrush(Color.FromRgb(60, 60, 67)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(8),
                Margin = new Thickness(20, 240, 20, 20),
                Background = new SolidColorBrush(Color.FromRgb(28, 28, 30))
            };

            var scrollViewer = new ScrollViewer
            {
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                Padding = new Thickness(10)
            };

            _resultLabel = new TextBlock
            {
                Text = "Waiting for audio...",
                FontSize = 12,
                FontFamily = new FontFamily("Consolas"),
                Foreground = Brushes.White,
                TextWrapping = TextWrapping.Wrap
            };

            scrollViewer.Content = _resultLabel;
            resultBorder.Child = scrollViewer;

            // Add all to canvas with absolute positioning
            var canvas = new Canvas();
            Canvas.SetTop(titleLabel, 20);
            Canvas.SetLeft(titleLabel, 20);
            canvas.Children.Add(titleLabel);

            Canvas.SetTop(instructions, 60);
            Canvas.SetLeft(instructions, 20);
            canvas.Children.Add(instructions);

            Canvas.SetTop(_recordButton, 100);
            Canvas.SetLeft(_recordButton, 200);
            canvas.Children.Add(_recordButton);

            Canvas.SetTop(_levelIndicator, 150);
            Canvas.SetLeft(_levelIndicator, 100);
            canvas.Children.Add(_levelIndicator);

            Canvas.SetTop(_levelLabel, 150);
            Canvas.SetLeft(_levelLabel, 460);
            canvas.Children.Add(_levelLabel);

            Canvas.SetTop(_statusLabel, 180);
            Canvas.SetLeft(_statusLabel, 20);
            canvas.Children.Add(_statusLabel);

            Canvas.SetTop(_latencyLabel, 210);
            Canvas.SetLeft(_latencyLabel, 20);
            canvas.Children.Add(_latencyLabel);

            Canvas.SetTop(resultBorder, 240);
            Canvas.SetLeft(resultBorder, 20);
            resultBorder.Width = 560;
            resultBorder.Height = 270;
            canvas.Children.Add(resultBorder);

            Content = canvas;
        }

        private void SetupAudioLevelCallback()
        {
            _recorder.OnLevelUpdate = level =>
            {
                Dispatcher.Invoke(() =>
                {
                    _levelIndicator.Value = Math.Min(level * 5, 100);
                    _levelLabel.Text = $"Level: {level:F1}";
                });
            };
        }

        private void ToggleRecording(object sender, RoutedEventArgs e)
        {
            if (_isRecording)
            {
                StopRecording();
            }
            else
            {
                StartRecording();
            }
        }

        private void StartRecording()
        {
            try
            {
                _recorder.StartRecording();
                _isRecording = true;
                _recordButton.Content = "⏹ Stop Recording";
                _statusLabel.Text = "🎙 Recording... Speak now!";
                _statusLabel.Foreground = new SolidColorBrush(Color.FromRgb(255, 59, 48));
                _resultLabel.Text = "Listening...";
                _latencyLabel.Text = "";
            }
            catch (Exception ex)
            {
                _statusLabel.Text = $"Error: {ex.Message}";
                _statusLabel.Foreground = new SolidColorBrush(Color.FromRgb(255, 59, 48));
            }
        }

        private void StopRecording()
        {
            var audioData = _recorder.StopRecording();
            _isRecording = false;
            _recordButton.Content = "🔴 Start Recording";
            _statusLabel.Text = "Processing with Groq Whisper...";
            _statusLabel.Foreground = new SolidColorBrush(Color.FromRgb(255, 149, 0));

            Task.Run(async () => await ProcessAudio(audioData));
        }

        private async Task ProcessAudio(byte[] audioData)
        {
            var totalStart = DateTime.Now;

            try
            {
                // Step 1: Transcribe with Groq Whisper
                var (rawText, transcriptionLatency) = await _groqClient.TranscribeAsync(audioData, "audio.wav");

                // Step 2: Try direct keyword match first
                var match = _matcher.FindMatch(rawText);
                double llmLatency = 0;
                string? fixedTopic = null;

                // Step 3: If no match, use LLM to interpret
                if (match == null && !string.IsNullOrWhiteSpace(rawText))
                {
                    var (fixed, llmTime) = await _groqClient.FixTranscriptionAsync(rawText);
                    llmLatency = llmTime;
                    fixedTopic = fixed;

                    // Try matching the LLM's interpretation
                    if (fixed != "unknown")
                    {
                        match = _matcher.FindMatch(fixed);
                    }
                }

                var totalLatency = (DateTime.Now - totalStart).TotalMilliseconds;

                await Dispatcher.InvokeAsync(() =>
                {
                    if (llmLatency > 0)
                    {
                        _latencyLabel.Text = $"⚡ Whisper: {transcriptionLatency:F0}ms | LLM: {llmLatency:F0}ms | Total: {totalLatency:F0}ms";
                    }
                    else
                    {
                        _latencyLabel.Text = $"⚡ Whisper: {transcriptionLatency:F0}ms | Total: {totalLatency:F0}ms";
                    }

                    if (match != null)
                    {
                        _statusLabel.Text = $"✅ Detected: {match.Value.Topic.DisplayName}";
                        _statusLabel.Foreground = new SolidColorBrush(Color.FromRgb(52, 199, 89));

                        var details = $"Raw transcription: \"{rawText}\"\n";
                        if (fixedTopic != null && fixedTopic != "unknown")
                        {
                            details += $"LLM interpreted as: \"{fixedTopic}\"\n";
                        }
                        details += $"Matched keyword: \"{match.Value.Keyword}\"\n";
                        details += $"Confidence: {match.Value.Confidence * 100:F0}%";

                        _resultLabel.Text = $"{details}\n\n" +
                                          "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n" +
                                          $"{match.Value.Topic.QuickAnswer}";
                    }
                    else
                    {
                        _statusLabel.Text = "❓ No topic matched";
                        _statusLabel.Foreground = new SolidColorBrush(Color.FromRgb(255, 204, 0));

                        var details = $"Raw transcription: \"{rawText}\"\n";
                        if (fixedTopic != null)
                        {
                            details += $"LLM interpretation: \"{fixedTopic}\"\n";
                        }

                        _resultLabel.Text = $"{details}\n\n" +
                                          "No interview topic detected.\n\n" +
                                          "Try saying things like:\n" +
                                          "• \"Tell me about closures\"\n" +
                                          "• \"Explain the event loop\"\n" +
                                          "• \"What is hoisting\"\n" +
                                          "• \"How do promises work\"";
                    }
                });
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() =>
                {
                    _statusLabel.Text = "❌ Error";
                    _statusLabel.Foreground = new SolidColorBrush(Color.FromRgb(255, 59, 48));
                    _resultLabel.Text = $"Error: {ex.Message}";
                    _latencyLabel.Text = "";
                });
            }
        }
    }

    // MARK: - Groq Whisper Client

    public class GroqWhisperClient
    {
        private readonly string _apiKey;
        private readonly HttpClient _httpClient = new();
        private const string WhisperUrl = "https://api.groq.com/openai/v1/audio/transcriptions";
        private const string ChatUrl = "https://api.groq.com/openai/v1/chat/completions";

        public GroqWhisperClient(string apiKey)
        {
            _apiKey = apiKey;
        }

        public async Task<(string Fixed, double LatencyMs)> FixTranscriptionAsync(string text)
        {
            var startTime = DateTime.Now;

            var prompt = $@"You are an interview topic detector. The user said something during a technical interview, but speech recognition may have errors.

Common interview topics: closures, hoisting, event loop, promises, async/await, prototypes, React hooks, useState, useEffect, virtual DOM, TypeScript, generics, linked list, hash map, trees, graphs, Big O, sorting, recursion, dynamic programming, system design, caching, load balancing, microservices, SOLID, design patterns, testing.

Transcription: ""{text}""

If this sounds like they're asking about an interview topic, respond with ONLY the topic name (e.g., ""closure"" or ""event loop"").
If you can't determine the topic, respond with ""unknown"".

Response (single word or short phrase only):";

            var request = new
            {
                model = "llama-3.1-8b-instant",
                messages = new[]
                {
                    new { role = "user", content = prompt }
                },
                max_tokens = 20,
                temperature = 0
            };

            var requestMessage = new HttpRequestMessage(HttpMethod.Post, ChatUrl);
            requestMessage.Headers.Add("Authorization", $"Bearer {_apiKey}");
            requestMessage.Content = new StringContent(
                JsonSerializer.Serialize(request),
                Encoding.UTF8,
                "application/json");

            var response = await _httpClient.SendAsync(requestMessage);
            response.EnsureSuccessStatusCode();

            var responseJson = await response.Content.ReadAsStringAsync();
            var chatResponse = JsonSerializer.Deserialize<ChatResponse>(responseJson);

            var fixed = chatResponse?.Choices?.FirstOrDefault()?.Message?.Content?.Trim().ToLowerInvariant() ?? "unknown";
            var latency = (DateTime.Now - startTime).TotalMilliseconds;

            return (fixed, latency);
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

        private class WhisperResponse
        {
            public string? Text { get; set; }
        }
    }

    // MARK: - Interview Topics

    public enum InterviewTopic
    {
        Closure, Hoisting, EventLoop, Promises, AsyncAwait, Prototypes,
        ReactHooks, UseState, UseEffect, VirtualDOM,
        TypeScript, Generics,
        LinkedList, HashMap, Trees, Graphs, BigO,
        Sorting, Recursion, DynamicProgramming,
        SystemDesign, Caching, LoadBalancing, Microservices,
        SOLID, DesignPatterns, Testing
    }

    public static class InterviewTopicExtensions
    {
        public static string[] GetKeywords(this InterviewTopic topic)
        {
            return topic switch
            {
                InterviewTopic.Closure => new[] { "closure", "closures", "lexical scope" },
                InterviewTopic.Hoisting => new[] { "hoisting", "hoist", "variable hoisting" },
                InterviewTopic.EventLoop => new[] { "event loop", "call stack", "callback queue", "microtask" },
                InterviewTopic.Promises => new[] { "promise", "promises", "then catch" },
                InterviewTopic.AsyncAwait => new[] { "async await", "async/await", "asynchronous" },
                InterviewTopic.Prototypes => new[] { "prototype", "prototypes", "prototype chain" },
                InterviewTopic.ReactHooks => new[] { "react hooks", "hooks", "custom hook" },
                InterviewTopic.UseState => new[] { "usestate", "use state" },
                InterviewTopic.UseEffect => new[] { "useeffect", "use effect" },
                InterviewTopic.VirtualDOM => new[] { "virtual dom", "reconciliation" },
                InterviewTopic.TypeScript => new[] { "typescript", "type script" },
                InterviewTopic.Generics => new[] { "generics", "generic types" },
                InterviewTopic.LinkedList => new[] { "linked list", "linkedlist" },
                InterviewTopic.HashMap => new[] { "hash map", "hashmap", "hash table" },
                InterviewTopic.Trees => new[] { "tree", "binary tree", "bst" },
                InterviewTopic.Graphs => new[] { "graph", "graphs", "dfs", "bfs" },
                InterviewTopic.BigO => new[] { "big o", "time complexity", "space complexity" },
                InterviewTopic.Sorting => new[] { "sorting", "quicksort", "mergesort" },
                InterviewTopic.Recursion => new[] { "recursion", "recursive" },
                InterviewTopic.DynamicProgramming => new[] { "dynamic programming", "dp", "memoization" },
                InterviewTopic.SystemDesign => new[] { "system design", "architecture" },
                InterviewTopic.Caching => new[] { "caching", "cache", "redis" },
                InterviewTopic.LoadBalancing => new[] { "load balancing", "load balancer" },
                InterviewTopic.Microservices => new[] { "microservices", "micro services" },
                InterviewTopic.SOLID => new[] { "solid", "solid principles" },
                InterviewTopic.DesignPatterns => new[] { "design patterns", "singleton", "factory" },
                InterviewTopic.Testing => new[] { "testing", "unit test", "tdd" },
                _ => Array.Empty<string>()
            };
        }

        public static string DisplayName(this InterviewTopic topic)
        {
            return topic switch
            {
                InterviewTopic.Closure => "Closures",
                InterviewTopic.Hoisting => "Hoisting",
                InterviewTopic.EventLoop => "Event Loop",
                InterviewTopic.Promises => "Promises",
                InterviewTopic.AsyncAwait => "Async/Await",
                InterviewTopic.Prototypes => "Prototypes",
                InterviewTopic.ReactHooks => "React Hooks",
                InterviewTopic.UseState => "useState",
                InterviewTopic.UseEffect => "useEffect",
                InterviewTopic.VirtualDOM => "Virtual DOM",
                InterviewTopic.TypeScript => "TypeScript",
                InterviewTopic.Generics => "Generics",
                InterviewTopic.LinkedList => "Linked Lists",
                InterviewTopic.HashMap => "Hash Maps",
                InterviewTopic.Trees => "Trees",
                InterviewTopic.Graphs => "Graphs",
                InterviewTopic.BigO => "Big O",
                InterviewTopic.Sorting => "Sorting",
                InterviewTopic.Recursion => "Recursion",
                InterviewTopic.DynamicProgramming => "Dynamic Programming",
                InterviewTopic.SystemDesign => "System Design",
                InterviewTopic.Caching => "Caching",
                InterviewTopic.LoadBalancing => "Load Balancing",
                InterviewTopic.Microservices => "Microservices",
                InterviewTopic.SOLID => "SOLID",
                InterviewTopic.DesignPatterns => "Design Patterns",
                InterviewTopic.Testing => "Testing",
                _ => topic.ToString()
            };
        }

        public static string QuickAnswer(this InterviewTopic topic)
        {
            return topic switch
            {
                InterviewTopic.Closure => @"CLOSURE: A function that retains access to its lexical scope even when executed outside that scope.

function outer() {
  let x = 10;
  return function inner() { return x; }
}
const fn = outer();
fn(); // 10 - still has access to x!

Key points:
• Created every time a function is created
• Used for data privacy, callbacks, partial application",

                InterviewTopic.Hoisting => @"HOISTING: JS moves declarations to top of scope during compilation.

• var: hoisted + initialized to undefined
• let/const: hoisted but NOT initialized (TDZ)
• functions: fully hoisted (can call before declaration)

console.log(x); // undefined
console.log(y); // ReferenceError!
var x = 1;
let y = 2;",

                InterviewTopic.EventLoop => @"EVENT LOOP: How JS handles async operations

1. Call Stack - runs sync code (LIFO)
2. Web APIs - handles async (setTimeout, fetch)
3. Microtask Queue - Promises, queueMicrotask
4. Macrotask Queue - setTimeout, setInterval

Order: Sync → All Microtasks → One Macrotask → Repeat",

                InterviewTopic.Promises => @"PROMISE: Object representing eventual completion/failure of async operation

States: pending → fulfilled OR rejected

const p = new Promise((resolve, reject) => {
  // async work
  resolve(value); // or reject(error)
});
p.then(v => {}).catch(e => {}).finally(() => {});

Promise.all([]) - all must succeed
Promise.race([]) - first to settle
Promise.allSettled([]) - wait for all",

                InterviewTopic.AsyncAwait => @"ASYNC/AWAIT: Syntactic sugar over Promises

async function getData() {
  try {
    const res = await fetch(url);
    return await res.json();
  } catch (e) {
    console.error(e);
  }
}

• async function always returns Promise
• await pauses until Promise resolves
• Use try/catch for error handling",

                _ => $"Topic: {topic.DisplayName()} - Add content for this topic"
            };
        }
    }

    // MARK: - Keyword Matcher

    public class KeywordMatcher
    {
        public (InterviewTopic Topic, string Keyword, double Confidence)? FindMatch(string text)
        {
            var normalized = text.ToLowerInvariant();

            foreach (InterviewTopic topic in Enum.GetValues(typeof(InterviewTopic)))
            {
                foreach (var keyword in topic.GetKeywords())
                {
                    if (normalized.Contains(keyword.ToLowerInvariant()))
                    {
                        return (topic, keyword, 1.0);
                    }
                }
            }

            return null;
        }
    }

    // MARK: - Audio Recorder

    public class AudioRecorder
    {
        private WaveInEvent? _waveIn;
        private MemoryStream? _recordingStream;
        private WaveFileWriter? _waveWriter;
        private System.Windows.Threading.DispatcherTimer? _levelTimer;

        public Action<float>? OnLevelUpdate { get; set; }

        public void StartRecording()
        {
            _recordingStream = new MemoryStream();

            _waveIn = new WaveInEvent
            {
                WaveFormat = new WaveFormat(16000, 1) // 16kHz mono
            };

            _waveWriter = new WaveFileWriter(_recordingStream, _waveIn.WaveFormat);

            _waveIn.DataAvailable += (s, e) =>
            {
                _waveWriter?.Write(e.Buffer, 0, e.BytesRead);

                // Calculate level (simplified)
                if (e.BytesRead > 0)
                {
                    float max = 0;
                    for (int i = 0; i < e.BytesRead; i += 2)
                    {
                        short sample = BitConverter.ToInt16(e.Buffer, i);
                        float sampleValue = sample / 32768f;
                        max = Math.Max(max, Math.Abs(sampleValue));
                    }
                    var db = 20 * Math.Log10(max + 0.0001);
                    var normalized = Math.Max(0, (float)((db + 50) * 2)); // -50dB to 0dB -> 0 to 100
                    OnLevelUpdate?.Invoke(normalized);
                }
            };

            _waveIn.StartRecording();
        }

        public byte[] StopRecording()
        {
            _waveIn?.StopRecording();
            _waveWriter?.Flush();
            _waveWriter?.Dispose();
            _waveIn?.Dispose();

            var audioData = _recordingStream?.ToArray() ?? Array.Empty<byte>();

            _recordingStream?.Dispose();
            _waveIn = null;
            _waveWriter = null;
            _recordingStream = null;

            return audioData;
        }
    }

    // MARK: - Entry Point

    public class KeywordSpotterApp
    {
        [STAThread]
        public static void Main(string[] args)
        {
            if (args.Length == 0)
            {
                MessageBox.Show(
                    "Usage: KeywordSpotterTest.exe <GROQ_API_KEY>\n\n" +
                    "Get your free API key at: https://console.groq.com\n\n" +
                    "Example:\n" +
                    "  KeywordSpotterTest.exe gsk_xxxxxxxxxxxxx",
                    "Keyword Spotter Test",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
                return;
            }

            var apiKey = args[0];
            var app = new Application();
            var window = new KeywordSpotterWindow(apiKey);
            app.Run(window);
        }
    }
}

