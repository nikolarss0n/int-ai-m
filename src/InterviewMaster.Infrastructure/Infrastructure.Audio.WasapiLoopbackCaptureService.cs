using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;
using InterviewMasterApp.Application;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Infrastructure;
using InterviewMasterApp.Infrastructure.Speech;

namespace InterviewMasterApp.Infrastructure.Audio
{
    /// <summary>
    /// Captures system audio output using WASAPI loopback with a persistent resampler pipeline
    /// (preserving filter state across reads — no boundary clicks) and real dB level metering.
    /// </summary>
    public class WasapiLoopbackCaptureService : IAudioSourceCapture
    {
        private readonly IVadEngine _vadEngine;
        private readonly object _lock = new();

        private WasapiLoopbackCapture? _capture;
        private BufferedWaveProvider? _bufferedProvider;
        private CancellationTokenSource? _cts;
        private Task? _processingTask;
        private bool _isRunning;
        private volatile bool _isMuted;
        private bool _disposed;

        private const int ChunkSize = 512;
        private const int TargetSampleRate = 16000;

        public CaptureDevice Device => CaptureDevice.SystemAudio;
        public bool IsCapturing => _isRunning;

        public Action<float, bool>? OnLevelUpdate { get; set; }
        public Action<byte[], AudioSource>? OnSpeechSegment { get; set; }
        public Action<string>? OnStatusChange { get; set; }

        public WasapiLoopbackCaptureService(IVadEngine vadEngine)
        {
            _vadEngine = vadEngine ?? throw new ArgumentNullException(nameof(vadEngine));
            _vadEngine.OnLevelUpdate = (_, speaking) => { /* dB emitted directly from chunk RMS below */ };
            _vadEngine.OnSpeechSegment = wavBytes =>
            {
                if (!_isMuted) OnSpeechSegment?.Invoke(wavBytes, AudioSource.SystemAudio);
            };
            _vadEngine.OnStatusChange = status => OnStatusChange?.Invoke(status);
        }

        public void SetMuted(bool muted)
        {
            _isMuted = muted;
            if (muted) OnLevelUpdate?.Invoke(-100f, false);
        }

        public Task StartAsync(CancellationToken ct = default) => StartCapturingAsync();
        public Task StopAsync() => StopCapturingAsync();

        public Task StartCapturingAsync()
        {
            ThrowIfDisposed();
            if (_isRunning) return Task.CompletedTask;

            _cts = new CancellationTokenSource();
            DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio, "WASAPI: creating loopback capture device...");
            _capture = new WasapiLoopbackCapture();

            var captureFormat = _capture.WaveFormat;
            _bufferedProvider = new BufferedWaveProvider(captureFormat)
            {
                DiscardOnBufferOverflow = true,
                ReadFully = false,
                BufferLength = captureFormat.AverageBytesPerSecond * 2
            };

            // Build ONE persistent sample conversion + resampling pipeline over _bufferedProvider
            // so WdlResamplingSampleProvider preserves filter state seamlessly across chunks.
            ISampleProvider sampleSource = _bufferedProvider.ToSampleProvider();
            if (sampleSource.WaveFormat.Channels > 1)
            {
                sampleSource = new StereoToMonoSampleProvider(sampleSource)
                {
                    LeftVolume = 0.5f,
                    RightVolume = 0.5f
                };
            }
            if (sampleSource.WaveFormat.SampleRate != TargetSampleRate)
            {
                sampleSource = new WdlResamplingSampleProvider(sampleSource, TargetSampleRate);
            }

            _capture.DataAvailable += OnDataAvailable;
            _capture.RecordingStopped += OnRecordingStopped;

            _capture.StartRecording();
            _isRunning = true;

            _processingTask = Task.Run(() => ProcessingLoopAsync(sampleSource, _cts.Token));
            OnStatusChange?.Invoke("System audio capture started (WASAPI loopback)");
            return Task.CompletedTask;
        }

        public async Task StopCapturingAsync()
        {
            if (!_isRunning) return;
            _isRunning = false;

            try { _cts?.Cancel(); } catch { }
            try { _capture?.StopRecording(); } catch { }

            if (_processingTask != null)
                await Task.WhenAny(_processingTask, Task.Delay(3000)).ConfigureAwait(false);

            Cleanup();
            OnStatusChange?.Invoke("System audio capture stopped");
        }

        private void OnDataAvailable(object? sender, WaveInEventArgs e)
        {
            if (e.BytesRecorded > 0 && !_isMuted)
                _bufferedProvider?.AddSamples(e.Buffer, 0, e.BytesRecorded);
        }

        private void OnRecordingStopped(object? sender, StoppedEventArgs e)
        {
            if (e.Exception != null)
                OnStatusChange?.Invoke($"Recording stopped with error: {e.Exception.Message}");
        }

        private async Task ProcessingLoopAsync(ISampleProvider pipeline, CancellationToken ct)
        {
            var pending = new List<float>(ChunkSize * 2);
            var readBuffer = new float[TargetSampleRate / 20]; // 50ms chunks at 16kHz
            var lastLevelReport = DateTime.MinValue;
            bool lastSpeaking = false;

            try
            {
                while (!ct.IsCancellationRequested)
                {
                    var provider = _bufferedProvider;
                    if (provider == null) break;

                    if (provider.BufferedBytes < provider.WaveFormat.AverageBytesPerSecond / 50)
                    {
                        await Task.Delay(10, ct).ConfigureAwait(false);
                        continue;
                    }

                    int samplesRead = pipeline.Read(readBuffer, 0, readBuffer.Length);
                    if (samplesRead <= 0)
                    {
                        await Task.Delay(10, ct).ConfigureAwait(false);
                        continue;
                    }

                    if (_isMuted) continue;

                    lock (_lock)
                    {
                        for (int i = 0; i < samplesRead; i++)
                        {
                            pending.Add(readBuffer[i]);
                            if (pending.Count >= ChunkSize)
                            {
                                var chunk = new float[ChunkSize];
                                pending.CopyTo(0, chunk, 0, ChunkSize);
                                pending.RemoveRange(0, ChunkSize);

                                var db = ComputeDb(chunk);
                                bool isSpeaking = false;
                                _vadEngine.OnLevelUpdate = (_, spk) => isSpeaking = spk;
                                try
                                {
                                    _vadEngine.ProcessChunk(chunk);
                                }
                                catch (Exception ex)
                                {
                                    OnStatusChange?.Invoke($"VAD processing error: {ex.Message}");
                                }

                                var now = DateTime.UtcNow;
                                if (isSpeaking != lastSpeaking || (now - lastLevelReport).TotalMilliseconds >= 80)
                                {
                                    lastSpeaking = isSpeaking;
                                    lastLevelReport = now;
                                    OnLevelUpdate?.Invoke(db, isSpeaking);
                                }
                            }
                        }
                    }
                }
            }
            catch (OperationCanceledException) { }
            catch (Exception ex)
            {
                OnStatusChange?.Invoke($"Processing loop error: {ex.Message}");
            }
        }

        private static float ComputeDb(float[] samples)
        {
            double sum = 0;
            for (int i = 0; i < samples.Length; i++) sum += samples[i] * samples[i];
            var rms = (float)Math.Sqrt(sum / Math.Max(samples.Length, 1));
            return 20f * MathF.Log10(MathF.Max(rms, 0.0000001f));
        }

        private void Cleanup()
        {
            if (_capture != null)
            {
                _capture.DataAvailable -= OnDataAvailable;
                _capture.RecordingStopped -= OnRecordingStopped;
                try { _capture.Dispose(); } catch { }
                _capture = null;
            }
            _bufferedProvider = null;
            try { _cts?.Dispose(); } catch { }
            _cts = null;
            _processingTask = null;
        }

        private void ThrowIfDisposed()
        {
            if (_disposed) throw new ObjectDisposedException(nameof(WasapiLoopbackCaptureService));
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            try { StopCapturingAsync().Wait(3000); } catch { }
            try { _vadEngine.Dispose(); } catch { }
            GC.SuppressFinalize(this);
        }
    }
}
