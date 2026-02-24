using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;
using InterviewMasterApp.Infrastructure;
using InterviewMasterApp.Infrastructure.Speech;

namespace InterviewMasterApp.Infrastructure.Audio
{
    /// <summary>
    /// Captures system audio output (what speakers play) using WASAPI loopback,
    /// converts stereo float32 to mono, resamples to 16kHz, buffers into 512-sample
    /// chunks, and forwards them to an IVadEngine for voice activity detection.
    ///
    /// Pipeline: WasapiLoopbackCapture (48kHz stereo float32)
    ///        -> stereo-to-mono (average L+R)
    ///        -> WdlResamplingSampleProvider (16kHz)
    ///        -> 512-sample chunks
    ///        -> IVadEngine.ProcessChunk()
    ///        -> speech segments (WAV bytes)
    /// </summary>
    public class WasapiLoopbackCaptureService : IDisposable
    {
        private readonly IVadEngine _vadEngine;
        private readonly object _lock = new object();

        private WasapiLoopbackCapture? _capture;
        private BufferedWaveProvider? _bufferedProvider;
        private CancellationTokenSource? _cts;
        private Task? _processingTask;
        private bool _isRunning;
        private bool _disposed;

        /// <summary>Chunk size in samples for Silero VAD input.</summary>
        private const int ChunkSize = 512;

        /// <summary>Target sample rate for VAD processing.</summary>
        private const int TargetSampleRate = 16000;

        // --------------- Callbacks (same interface as SystemAudioCapture) ---------------

        /// <summary>
        /// Called with (level, isSpeaking) whenever audio level is computed.
        /// </summary>
        public Action<float, bool>? OnLevelUpdate { get; set; }

        /// <summary>
        /// Called with WAV bytes when a complete speech segment is detected.
        /// </summary>
        public Action<byte[]>? OnSpeechSegment { get; set; }

        /// <summary>
        /// Called with a status string on state changes or errors.
        /// </summary>
        public Action<string>? OnStatusChange { get; set; }

        // --------------- Constructor ---------------

        public WasapiLoopbackCaptureService(IVadEngine vadEngine)
        {
            _vadEngine = vadEngine ?? throw new ArgumentNullException(nameof(vadEngine));

            // Wire VAD engine callbacks through to our public callbacks.
            _vadEngine.OnLevelUpdate = (level, speaking) => OnLevelUpdate?.Invoke(level, speaking);
            _vadEngine.OnSpeechSegment = wavBytes => OnSpeechSegment?.Invoke(wavBytes);
            _vadEngine.OnStatusChange = status => OnStatusChange?.Invoke(status);
        }

        // --------------- Public API ---------------

        /// <summary>
        /// Start capturing system audio via WASAPI loopback.
        /// </summary>
        public Task StartCapturingAsync()
        {
            ThrowIfDisposed();

            if (_isRunning)
                return Task.CompletedTask;

            _cts = new CancellationTokenSource();

            // WasapiLoopbackCapture picks the default render device automatically.
            // Its WaveFormat is typically 48kHz stereo IEEE float (32-bit).
            DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio, "WASAPI: creating loopback capture device...");
            _capture = new WasapiLoopbackCapture();

            var captureFormat = _capture.WaveFormat;
            DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio,
                $"WASAPI: device format: {captureFormat.SampleRate}Hz, {captureFormat.Channels}ch, {captureFormat.BitsPerSample}bit, encoding={captureFormat.Encoding}");
            OnStatusChange?.Invoke(
                $"Loopback device format: {captureFormat.SampleRate}Hz, {captureFormat.Channels}ch, {captureFormat.BitsPerSample}bit");

            // BufferedWaveProvider sits between the capture callback and the processing thread
            // so we decouple the WASAPI callback from resampling/VAD work.
            _bufferedProvider = new BufferedWaveProvider(captureFormat)
            {
                DiscardOnBufferOverflow = true,
                BufferLength = captureFormat.AverageBytesPerSecond * 2 // 2 seconds of buffer
            };

            _capture.DataAvailable += OnDataAvailable;
            _capture.RecordingStopped += OnRecordingStopped;

            _capture.StartRecording();
            _isRunning = true;

            // Launch the background thread that reads from the buffer, resamples, and feeds VAD.
            _processingTask = Task.Run(() => ProcessingLoopAsync(_cts.Token));

            OnStatusChange?.Invoke("System audio capture started (WASAPI loopback)");
            return Task.CompletedTask;
        }

        /// <summary>
        /// Stop capturing and wait for the processing pipeline to drain.
        /// </summary>
        public async Task StopCapturingAsync()
        {
            if (!_isRunning)
                return;

            _isRunning = false;

            // Signal the processing loop to exit.
            try { _cts?.Cancel(); } catch { /* already disposed */ }

            // Stop the WASAPI capture device.
            try { _capture?.StopRecording(); } catch { /* best effort */ }

            // Wait for the processing task to finish (with a timeout).
            if (_processingTask != null)
            {
                await Task.WhenAny(_processingTask, Task.Delay(3000)).ConfigureAwait(false);
            }

            Cleanup();

            OnStatusChange?.Invoke("System audio capture stopped");
        }

        // --------------- WASAPI Callbacks ---------------

        private int _dataCallbackCount;
        private DateTime _lastDataLog = DateTime.MinValue;

        private void OnDataAvailable(object? sender, WaveInEventArgs e)
        {
            // Push raw bytes into the buffered provider; the processing thread will consume them.
            if (e.BytesRecorded > 0)
            {
                _dataCallbackCount++;
                _bufferedProvider?.AddSamples(e.Buffer, 0, e.BytesRecorded);

                // Log every ~5 seconds
                if ((DateTime.UtcNow - _lastDataLog).TotalSeconds >= 5.0)
                {
                    DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio,
                        $"WASAPI: data callback #{_dataCallbackCount}, {e.BytesRecorded} bytes, buffer={_bufferedProvider?.BufferedBytes ?? 0} bytes");
                    _lastDataLog = DateTime.UtcNow;
                }
            }
        }

        private void OnRecordingStopped(object? sender, StoppedEventArgs e)
        {
            if (e.Exception != null)
            {
                OnStatusChange?.Invoke($"Recording stopped with error: {e.Exception.Message}");
            }
        }

        // --------------- Processing Loop ---------------

        private async Task ProcessingLoopAsync(CancellationToken ct)
        {
            // Pending mono 16kHz samples waiting to fill up to ChunkSize.
            var pending = new List<float>();

            try
            {
                while (!ct.IsCancellationRequested)
                {
                    var provider = _bufferedProvider;
                    if (provider == null)
                        break;

                    int buffered = provider.BufferedBytes;

                    // Wait until we have at least ~10ms worth of data.
                    if (buffered < provider.WaveFormat.AverageBytesPerSecond / 100)
                    {
                        await Task.Delay(10, ct).ConfigureAwait(false);
                        continue;
                    }

                    int bytesToRead = Math.Min(buffered, provider.WaveFormat.BlockAlign * 2048);
                    var rawBuffer = new byte[bytesToRead];
                    int bytesRead = provider.Read(rawBuffer, 0, bytesToRead);
                    if (bytesRead <= 0)
                    {
                        await Task.Delay(5, ct).ConfigureAwait(false);
                        continue;
                    }

                    // Build a mini pipeline:
                    //   raw bytes -> ISampleProvider (float32, device format)
                    //             -> mono (if stereo)
                    //             -> resample to 16kHz
                    var rawStream = new MemoryStream(rawBuffer, 0, bytesRead);
                    var rawSource = new RawSourceWaveStream(rawStream, provider.WaveFormat);
                    ISampleProvider sampleSource = rawSource.ToSampleProvider();

                    // Stereo -> mono: average L+R.
                    if (sampleSource.WaveFormat.Channels > 1)
                    {
                        sampleSource = new StereoToMonoSampleProvider(sampleSource)
                        {
                            LeftVolume = 0.5f,
                            RightVolume = 0.5f
                        };
                    }

                    // Resample to 16kHz if the device rate differs.
                    if (sampleSource.WaveFormat.SampleRate != TargetSampleRate)
                    {
                        sampleSource = new WdlResamplingSampleProvider(sampleSource, TargetSampleRate);
                    }

                    // Read all resampled mono samples.
                    var resampledBuffer = new float[TargetSampleRate / 10]; // ~100ms worth
                    int samplesRead;
                    while ((samplesRead = sampleSource.Read(resampledBuffer, 0, resampledBuffer.Length)) > 0)
                    {
                        FeedVadChunks(resampledBuffer, samplesRead, pending);
                    }

                    // Dispose the temporary stream.
                    rawStream.Dispose();
                    rawSource.Dispose();
                }
            }
            catch (OperationCanceledException)
            {
                // Normal shutdown.
            }
            catch (Exception ex)
            {
                OnStatusChange?.Invoke($"Processing loop error: {ex.Message}");
            }
        }

        /// <summary>
        /// Buffers resampled mono samples into 512-sample chunks and forwards each
        /// complete chunk to the VAD engine.
        /// </summary>
        private void FeedVadChunks(float[] samples, int count, List<float> pending)
        {
            lock (_lock)
            {
                for (int i = 0; i < count; i++)
                {
                    pending.Add(samples[i]);

                    if (pending.Count >= ChunkSize)
                    {
                        var chunk = new float[ChunkSize];
                        pending.CopyTo(0, chunk, 0, ChunkSize);
                        pending.RemoveRange(0, ChunkSize);

                        try
                        {
                            _vadEngine.ProcessChunk(chunk);
                        }
                        catch (Exception ex)
                        {
                            OnStatusChange?.Invoke($"VAD processing error: {ex.Message}");
                        }
                    }
                }
            }
        }

        // --------------- Cleanup / Dispose ---------------

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
            if (_disposed)
                throw new ObjectDisposedException(nameof(WasapiLoopbackCaptureService));
        }

        public void Dispose()
        {
            if (_disposed)
                return;
            _disposed = true;

            try { StopCapturingAsync().Wait(3000); } catch { }

            try { _vadEngine.Dispose(); } catch { }

            GC.SuppressFinalize(this);
        }
    }
}
