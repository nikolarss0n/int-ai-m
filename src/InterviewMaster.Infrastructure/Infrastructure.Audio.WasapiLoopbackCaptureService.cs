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
            // Use a generic N-channel downmixer (StereoToMonoSampleProvider throws on 5.1/7.1 headsets).
            ISampleProvider sampleSource = _bufferedProvider.ToSampleProvider();
            if (sampleSource.WaveFormat.Channels > 1)
            {
                sampleSource = new MultiChannelToMonoSampleProvider(sampleSource);
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
            var silentChunk = new float[ChunkSize];
            var lastLevelReport = DateTime.MinValue;
            var lastAudioPacketUtc = DateTime.UtcNow;
            var lastSilenceFeedUtc = DateTime.MinValue;
            bool lastSpeaking = false;

            try
            {
                while (!ct.IsCancellationRequested)
                {
                    var provider = _bufferedProvider;
                    if (provider == null) break;

                    if (provider.BufferedBytes < provider.WaveFormat.AverageBytesPerSecond / 50)
                    {
                        // WASAPI loopback stops firing DataAvailable completely when no app is playing audio.
                        // Feed zero-chunks at 32ms cadence (512 samples @ 16kHz) so SileroVADRecorder counts
                        // its post-speech silence padding and flushes the completed utterance instead of hanging.
                        var now = DateTime.UtcNow;
                        if (!_isMuted &&
                            (now - lastAudioPacketUtc).TotalMilliseconds >= 40 &&
                            (now - lastSilenceFeedUtc).TotalMilliseconds >= 32)
                        {
                            lastSilenceFeedUtc = now;
                            bool isSpeaking = false;
                            lock (_lock)
                            {
                                _vadEngine.OnLevelUpdate = (_, spk) => isSpeaking = spk;
                                try { _vadEngine.ProcessChunk(silentChunk); }
                                catch { }
                            }
                            if (lastSpeaking || (now - lastLevelReport).TotalMilliseconds >= 120)
                            {
                                lastSpeaking = isSpeaking;
                                lastLevelReport = now;
                                OnLevelUpdate?.Invoke(-100f, isSpeaking);
                            }
                        }

                        await Task.Delay(10, ct).ConfigureAwait(false);
                        continue;
                    }

                    int samplesRead = pipeline.Read(readBuffer, 0, readBuffer.Length);
                    if (samplesRead <= 0)
                    {
                        await Task.Delay(10, ct).ConfigureAwait(false);
                        continue;
                    }

                    lastAudioPacketUtc = DateTime.UtcNow;
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

        /// <summary>
        /// Averages any N-channel input (stereo, 5.1, 7.1 headsets, spatial audio) into mono.
        /// </summary>
        private sealed class MultiChannelToMonoSampleProvider : ISampleProvider
        {
            private readonly ISampleProvider _source;
            private readonly int _channels;
            private float[] _sourceBuffer = Array.Empty<float>();

            public WaveFormat WaveFormat { get; }

            public MultiChannelToMonoSampleProvider(ISampleProvider source)
            {
                _source = source ?? throw new ArgumentNullException(nameof(source));
                _channels = Math.Max(1, source.WaveFormat.Channels);
                WaveFormat = WaveFormat.CreateIeeeFloatWaveFormat(source.WaveFormat.SampleRate, 1);
            }

            public int Read(float[] buffer, int offset, int count)
            {
                int needed = count * _channels;
                if (_sourceBuffer.Length < needed) _sourceBuffer = new float[needed];
                int read = _source.Read(_sourceBuffer, 0, needed);
                int frames = read / _channels;
                float scale = 1f / _channels;
                for (int f = 0; f < frames; f++)
                {
                    float sum = 0f;
                    int baseIdx = f * _channels;
                    for (int ch = 0; ch < _channels; ch++) sum += _sourceBuffer[baseIdx + ch];
                    buffer[offset + f] = sum * scale;
                }
                return frames;
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
