using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;
using InterviewMasterApp.Application;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Infrastructure;

namespace InterviewMasterApp.Infrastructure.Speech
{
    /// <summary>
    /// Captures microphone audio via NAudio WaveInEvent at 16kHz mono (or resampled via a persistent
    /// WdlResamplingSampleProvider) with null-safe stop/dispose and real dB level metering.
    /// </summary>
    public class WindowsAudioCapture : IAudioSourceCapture
    {
        private WaveInEvent? _waveIn;
        private BufferedWaveProvider? _bufferedProvider;
        private readonly object _lock = new();
        private bool _isRunning;
        private volatile bool _isMuted;
        private IVadEngine? _vadEngine;
        private Task? _processingTask;
        private CancellationTokenSource? _cts;

        private const int ChunkSize = 512;
        private const int TargetSampleRate = 16000;

        public CaptureDevice Device => CaptureDevice.Microphone;
        public bool IsCapturing => _isRunning;

        public Action<float, bool>? OnLevelUpdate { get; set; }
        public Action<byte[], AudioSource>? OnSpeechSegment { get; set; }
        public Action<string>? OnStatusChange { get; set; }

        public event Action<string>? StatusChanged;
        public event Action<float, bool>? LevelUpdated;
        public event Action<byte[]>? SpeechSegmentReady;

        public WindowsAudioCapture(IVadEngine vadEngine)
        {
            _vadEngine = vadEngine ?? throw new ArgumentNullException(nameof(vadEngine));
            _vadEngine.OnStatusChange = s => { OnStatusChange?.Invoke(s); StatusChanged?.Invoke(s); };
            _vadEngine.OnSpeechSegment = bytes =>
            {
                if (_isMuted) return;
                OnSpeechSegment?.Invoke(bytes, AudioSource.Microphone);
                SpeechSegmentReady?.Invoke(bytes);
            };
        }

        public void SetMuted(bool muted)
        {
            _isMuted = muted;
            if (muted)
            {
                OnLevelUpdate?.Invoke(-100f, false);
                LevelUpdated?.Invoke(-100f, false);
            }
        }

        public Task StartAsync(CancellationToken ct = default)
        {
            if (_isRunning) return Task.CompletedTask;

            _cts = new CancellationTokenSource();
            _isRunning = true;

            var inputFormat = new WaveFormat(44100, 16, 1);
            _waveIn = new WaveInEvent
            {
                WaveFormat = inputFormat,
                BufferMilliseconds = 50
            };
            _waveIn.DataAvailable += WaveIn_DataAvailable;

            _bufferedProvider = new BufferedWaveProvider(inputFormat)
            {
                DiscardOnBufferOverflow = true,
                ReadFully = false,
                BufferLength = inputFormat.AverageBytesPerSecond * 2
            };

            // Persistent resampler across the entire capture lifetime
            ISampleProvider pipeline = new WdlResamplingSampleProvider(_bufferedProvider.ToSampleProvider(), TargetSampleRate);

            _waveIn.StartRecording();
            _processingTask = Task.Run(() => ProcessLoopAsync(pipeline, inputFormat, _cts.Token));

            OnStatusChange?.Invoke("Microphone capture started");
            StatusChanged?.Invoke("Microphone capture started");
            return Task.CompletedTask;
        }

        public async Task StopAsync()
        {
            if (!_isRunning) return;
            _isRunning = false;

            try { _cts?.Cancel(); } catch { }

            var waveIn = _waveIn;
            _waveIn = null;
            if (waveIn != null)
            {
                waveIn.DataAvailable -= WaveIn_DataAvailable;
                try { waveIn.StopRecording(); } catch { }
                try { waveIn.Dispose(); } catch { }
            }

            if (_processingTask != null)
                await Task.WhenAny(_processingTask, Task.Delay(2000)).ConfigureAwait(false);

            _bufferedProvider = null;
            _processingTask = null;

            OnStatusChange?.Invoke("Microphone capture stopped");
            StatusChanged?.Invoke("Microphone capture stopped");
        }

        private void WaveIn_DataAvailable(object? sender, WaveInEventArgs e)
        {
            if (e.BytesRecorded > 0 && !_isMuted)
                _bufferedProvider?.AddSamples(e.Buffer, 0, e.BytesRecorded);
        }

        private async Task ProcessLoopAsync(ISampleProvider pipeline, WaveFormat inputFormat, CancellationToken ct)
        {
            var pending = new List<float>(ChunkSize * 2);
            var readBuffer = new float[TargetSampleRate / 20];
            var minBytes = inputFormat.AverageBytesPerSecond / 50;
            var lastLevelReport = DateTime.MinValue;
            bool lastSpeaking = false;

            try
            {
                while (!ct.IsCancellationRequested)
                {
                    var provider = _bufferedProvider;
                    if (provider == null) break;

                    if (provider.BufferedBytes < minBytes)
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
                                if (_vadEngine != null)
                                {
                                    _vadEngine.OnLevelUpdate = (_, spk) => isSpeaking = spk;
                                    try { _vadEngine.ProcessChunk(chunk); }
                                    catch (Exception ex) { OnStatusChange?.Invoke("VAD error: " + ex.Message); }
                                }

                                var now = DateTime.UtcNow;
                                if (isSpeaking != lastSpeaking || (now - lastLevelReport).TotalMilliseconds >= 80)
                                {
                                    lastSpeaking = isSpeaking;
                                    lastLevelReport = now;
                                    OnLevelUpdate?.Invoke(db, isSpeaking);
                                    LevelUpdated?.Invoke(db, isSpeaking);
                                }
                            }
                        }
                    }
                }
            }
            catch (OperationCanceledException) { }
            catch (Exception ex)
            {
                OnStatusChange?.Invoke("Mic processing error: " + ex.Message);
            }
        }

        private static float ComputeDb(float[] samples)
        {
            double sum = 0;
            for (int i = 0; i < samples.Length; i++) sum += samples[i] * samples[i];
            var rms = (float)Math.Sqrt(sum / Math.Max(samples.Length, 1));
            return 20f * MathF.Log10(MathF.Max(rms, 0.0000001f));
        }

        public void Dispose()
        {
            try { StopAsync().Wait(2000); } catch { }
            _vadEngine?.Dispose();
            _vadEngine = null;
            try { _cts?.Dispose(); } catch { }
            _cts = null;
        }
    }
}
