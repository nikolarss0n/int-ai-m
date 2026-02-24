using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;
using InterviewMasterApp.Infrastructure;

namespace InterviewMasterApp.Infrastructure.Speech
{
    /// <summary>
    /// Captures audio from default input device using NAudio, resamples to 16kHz mono,
    /// buffers into fixed-size chunks and forwards to an IVadEngine implementation.
    /// Designed to be used from a UI thread (WinUI/WPF) via StartAsync/Stop.
    /// </summary>
    public class WindowsAudioCapture : IDisposable
    {
        private WaveInEvent _waveIn;
        private WaveFormat _targetFormat = new WaveFormat(16000, 16, 1);
        private BufferedWaveProvider _bufferedProvider;
        private readonly object _lock = new object();
        private bool _isRunning;
        private IVadEngine _vadEngine;

        // chunk size in samples for Silero-style VAD
        private const int ChunkSize = 512;

        private CancellationTokenSource _cts;

        // Events for UI integration
        public event Action<string> StatusChanged;
        public event Action<float, bool> LevelUpdated; // level, isSpeaking
        public event Action<byte[]> SpeechSegmentReady; // WAV bytes

        public WindowsAudioCapture(IVadEngine vadEngine)
        {
            _vadEngine = vadEngine ?? throw new ArgumentNullException(nameof(vadEngine));

            // Wire VAD engine callbacks to our events
            _vadEngine.OnStatusChange = s => StatusChanged?.Invoke(s);
            _vadEngine.OnLevelUpdate = (lvl, spk) => LevelUpdated?.Invoke(lvl, spk);
            _vadEngine.OnSpeechSegment = bytes => SpeechSegmentReady?.Invoke(bytes);
        }

        /// <summary>
        /// Start audio capture and processing. Safe to call from UI thread.
        /// </summary>
        public Task StartAsync()
        {
            if (_isRunning) return Task.CompletedTask;

            _cts = new CancellationTokenSource();
            _isRunning = true;

            DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio, "MIC: creating WaveInEvent for default input device...");

            // Use WaveInEvent for compatibility
            _waveIn = new WaveInEvent();
            _waveIn.WaveFormat = new WaveFormat(44100, 1); // common device format
            _waveIn.BufferMilliseconds = 50;
            _waveIn.DataAvailable += WaveIn_DataAvailable;

            DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio,
                $"MIC: device format: {_waveIn.WaveFormat.SampleRate}Hz, {_waveIn.WaveFormat.Channels}ch, {_waveIn.WaveFormat.BitsPerSample}bit");

            _bufferedProvider = new BufferedWaveProvider(_waveIn.WaveFormat) { DiscardOnBufferOverflow = true };

            _waveIn.StartRecording();
            DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio, "MIC: recording started");

            // Start background processing loop
            _ = Task.Run(() => ProcessLoopAsync(_cts.Token));
            _vadEngine.OnStatusChange?.Invoke("Audio capture started");
            StatusChanged?.Invoke("Audio capture started");
            return Task.CompletedTask;
        }

        /// <summary>
        /// Stop capture and processing.
        /// </summary>
        public Task StopAsync()
        {
            if (!_isRunning) return Task.CompletedTask;

            _cts?.Cancel();
            _isRunning = false;

            try { _waveIn?.StopRecording(); } catch { }
            try { _waveIn?.Dispose(); } catch { }
            _waveIn = null;

            _vadEngine.OnStatusChange?.Invoke("Audio capture stopped");
            StatusChanged?.Invoke("Audio capture stopped");
            return Task.CompletedTask;
        }

        private int _micDataCount;
        private DateTime _lastMicLog = DateTime.MinValue;

        private void WaveIn_DataAvailable(object sender, WaveInEventArgs e)
        {
            _bufferedProvider?.AddSamples(e.Buffer, 0, e.BytesRecorded);

            _micDataCount++;
            if ((DateTime.UtcNow - _lastMicLog).TotalSeconds >= 5.0)
            {
                DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio,
                    $"MIC: data callback #{_micDataCount}, {e.BytesRecorded} bytes, buffer={_bufferedProvider?.BufferedBytes ?? 0} bytes");
                _lastMicLog = DateTime.UtcNow;
            }
        }

        private async Task ProcessLoopAsync(CancellationToken ct)
        {
            // We'll read from _bufferedProvider and resample to 16kHz using WdlResamplingSampleProvider
            while (!ct.IsCancellationRequested)
            {
                if (_bufferedProvider == null || _bufferedProvider.BufferedBytes < _waveIn.WaveFormat.AverageBytesPerSecond / 10)
                {
                    await Task.Delay(10, ct).ContinueWith(_ => { });
                    continue;
                }

                try
                {
                    int bytesToRead = Math.Min(_bufferedProvider.BufferedBytes, _waveIn.WaveFormat.BlockAlign * 1024);
                    var buffer = new byte[bytesToRead];
                    int read = _bufferedProvider.Read(buffer, 0, bytesToRead);
                    if (read <= 0) { await Task.Delay(5, ct).ContinueWith(_ => { }); continue; }

                    // Convert bytes to float samples and resample
                    using var ms = new MemoryStream(buffer);
                    var sampleProvider = new RawSourceWaveStream(ms, _waveIn.WaveFormat).ToSampleProvider();
                    var resampler = new WdlResamplingSampleProvider(sampleProvider, _targetFormat.SampleRate);
                    var samplesBuffer = new float[resampler.WaveFormat.SampleRate / 10 * resampler.WaveFormat.Channels];
                    int samplesRead;
                    while ((samplesRead = resampler.Read(samplesBuffer, 0, samplesBuffer.Length)) > 0)
                    {
                        // Flatten to mono (already mono) and buffer into chunk-sized arrays
                        BufferSamples(samplesBuffer, samplesRead);
                    }
                }
                catch (OperationCanceledException) { break; }
                catch (Exception ex)
                {
                    _vadEngine.OnStatusChange?.Invoke("Capture processing error: " + ex.Message);
                    StatusChanged?.Invoke("Capture processing error: " + ex.Message);
                    await Task.Delay(50, ct).ContinueWith(_ => { });
                }
            }
        }

        private List<float> _pending = new List<float>();

        private void BufferSamples(float[] samples, int count)
        {
            lock (_lock)
            {
                for (int i = 0; i < count; i++)
                {
                    _pending.Add(samples[i]);
                    if (_pending.Count >= ChunkSize)
                    {
                        var chunk = _pending.Take(ChunkSize).ToArray();
                        _pending.RemoveRange(0, ChunkSize);
                        // Forward to VAD engine
                        try
                        {
                            _vadEngine.ProcessChunk(chunk);
                        }
                        catch (Exception ex)
                        {
                            _vadEngine.OnStatusChange?.Invoke("VAD processing error: " + ex.Message);
                            StatusChanged?.Invoke("VAD processing error: " + ex.Message);
                        }
                    }
                }
            }
        }

        public void Dispose()
        {
            try { StopAsync().Wait(2000); } catch { }
            _vadEngine?.Dispose();
            _vadEngine = null;
            try { _cts?.Dispose(); } catch { }
        }
    }
}
