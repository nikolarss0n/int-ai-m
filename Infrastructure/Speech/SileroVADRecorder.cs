using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using InterviewMasterApp.Infrastructure;

namespace InterviewMasterApp.Infrastructure.Speech
{
    /// <summary>
    /// IVadEngine implementation using Silero ONNX VAD with proper speech accumulation.
    /// Accumulates audio frames while speech is detected, adds pre-speech buffer and
    /// post-speech padding, enforces min/max duration, and emits WAV bytes.
    /// </summary>
    public class SileroVADRecorder : IVadEngine
    {
        private readonly SileroOnnxVAD _vad;

        // Configuration
        private const float SpeechThreshold = 0.5f;
        private const int PreSpeechBufferMs = 300;
        private const int PostSpeechPaddingMs = 500;
        private const double MinSpeechDurationSec = 0.5;
        private const double MaxSpeechDurationSec = 30.0;
        private const int SampleRate = 16000;
        private const int ChunkSize = 512;

        // Derived constants
        private readonly int _preSpeechChunkCount;
        private readonly int _postSpeechChunkCount;
        private readonly int _maxSpeechSamples;

        // State
        private bool _isSpeaking;
        private readonly List<float> _speechFrames = new();
        private readonly Queue<float[]> _preSpeechBuffer = new();
        private int _silenceChunks;

        // IVadEngine callbacks
        public Action<float, bool>? OnLevelUpdate { get; set; }
        public Action<byte[]>? OnSpeechSegment { get; set; }
        public Action<string>? OnStatusChange { get; set; }

        private int _chunkCount;
        private DateTime _lastLogTime = DateTime.MinValue;
        private string _label = "VAD";

        public SileroVADRecorder(string label = "VAD")
        {
            _label = label;
            _vad = new SileroOnnxVAD();

            // Calculate chunk counts from time durations
            float chunksPerSecond = (float)SampleRate / ChunkSize;
            _preSpeechChunkCount = Math.Max(1, (int)(chunksPerSecond * PreSpeechBufferMs / 1000));
            _postSpeechChunkCount = Math.Max(1, (int)(chunksPerSecond * PostSpeechPaddingMs / 1000));
            _maxSpeechSamples = (int)(SampleRate * MaxSpeechDurationSec);

            if (_vad.IsLoaded)
            {
                DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio, "SileroVADRecorder: ONNX VAD ready");
                OnStatusChange?.Invoke("Silero ONNX VAD ready");
            }
            else
            {
                DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio, "SileroVADRecorder: ONNX model NOT loaded, using RMS fallback");
                OnStatusChange?.Invoke("Silero ONNX VAD model not found - using RMS fallback");
            }
        }

        /// <summary>
        /// Process a chunk of mono 16kHz float32 audio samples.
        /// </summary>
        public void ProcessChunk(float[] samples)
        {
            if (!_vad.IsLoaded)
            {
                ProcessChunkRmsFallback(samples);
                return;
            }

            var prob = _vad.Predict(samples);
            if (prob < 0) // error
            {
                _chunkCount++;
                if (_chunkCount <= 3)
                {
                    DebugLogger.Shared.Log(DebugLogger.LogCategory.Error,
                        $"VAD ONNX Predict returned {prob}, falling back to RMS (chunk #{_chunkCount})");
                }
                ProcessChunkRmsFallback(samples);
                return;
            }

            _chunkCount++;
            var isSpeech = prob > SpeechThreshold;
            OnLevelUpdate?.Invoke(prob, isSpeech);

            // Log periodically (every ~2 seconds) to avoid flooding
            if ((DateTime.UtcNow - _lastLogTime).TotalSeconds >= 2.0)
            {
                // Calculate RMS of input for diagnostics
                double rmsSum = 0;
                float maxAbs = 0;
                foreach (var s in samples)
                {
                    rmsSum += s * s;
                    var abs = Math.Abs(s);
                    if (abs > maxAbs) maxAbs = abs;
                }
                var rms = (float)Math.Sqrt(rmsSum / Math.Max(1, samples.Length));

                DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio,
                    $"[{_label}] chunk #{_chunkCount} prob={prob:F3} rms={rms:F6} max={maxAbs:F6} speech={isSpeech} speaking={_isSpeaking} frames={_speechFrames.Count} len={samples.Length}");
                _lastLogTime = DateTime.UtcNow;
            }

            if (isSpeech)
            {
                if (!_isSpeaking)
                {
                    // Speech just started - flush pre-speech buffer into speech frames
                    _isSpeaking = true;
                    _speechFrames.Clear();
                    DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio, $"VAD: speech START detected (prob={prob:F3})");

                    foreach (var buffered in _preSpeechBuffer)
                        _speechFrames.AddRange(buffered);

                    _silenceChunks = 0;
                }

                _speechFrames.AddRange(samples);
                _silenceChunks = 0;

                // Max duration check - emit what we have and continue
                if (_speechFrames.Count >= _maxSpeechSamples)
                {
                    EmitSpeechSegment();
                    _isSpeaking = false;
                    _vad.ResetState();
                }
            }
            else
            {
                if (_isSpeaking)
                {
                    // Include silence frames as post-speech padding
                    _speechFrames.AddRange(samples);
                    _silenceChunks++;

                    if (_silenceChunks >= _postSpeechChunkCount)
                    {
                        // Speech ended after sufficient silence
                        var durationSec = (double)_speechFrames.Count / SampleRate;

                        if (durationSec >= MinSpeechDurationSec)
                        {
                            DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio,
                                $"VAD: speech END, duration={durationSec:F2}s, emitting segment ({_speechFrames.Count} samples)");
                            EmitSpeechSegment();
                        }
                        else
                        {
                            DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio,
                                $"VAD: speech END, duration={durationSec:F2}s TOO SHORT (min={MinSpeechDurationSec}s), discarding");
                            _speechFrames.Clear();
                        }

                        _isSpeaking = false;
                    }
                }

                // Maintain rolling pre-speech buffer
                _preSpeechBuffer.Enqueue((float[])samples.Clone());
                while (_preSpeechBuffer.Count > _preSpeechChunkCount)
                    _preSpeechBuffer.Dequeue();
            }
        }

        /// <summary>
        /// Simple RMS-based fallback when ONNX model isn't available.
        /// </summary>
        private DateTime _lastRmsLog = DateTime.MinValue;

        private void ProcessChunkRmsFallback(float[] samples)
        {
            double sum = 0;
            foreach (var s in samples) sum += s * s;
            var rms = (float)Math.Sqrt(sum / Math.Max(1, samples.Length));

            var isSpeech = rms > 0.03f;
            OnLevelUpdate?.Invoke(rms, isSpeech);

            // Log periodically
            if ((DateTime.UtcNow - _lastRmsLog).TotalSeconds >= 3.0)
            {
                DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio,
                    $"VAD RMS fallback: rms={rms:F4} speech={isSpeech} speaking={_isSpeaking} frames={_speechFrames.Count}");
                _lastRmsLog = DateTime.UtcNow;
            }

            if (isSpeech)
            {
                if (!_isSpeaking)
                {
                    _isSpeaking = true;
                    _speechFrames.Clear();
                    _silenceChunks = 0;
                    DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio, $"VAD RMS: speech START (rms={rms:F4})");
                }

                _speechFrames.AddRange(samples);
                _silenceChunks = 0;
            }
            else
            {
                if (_isSpeaking)
                {
                    _speechFrames.AddRange(samples);
                    _silenceChunks++;

                    if (_silenceChunks >= _postSpeechChunkCount)
                    {
                        var durationSec = (double)_speechFrames.Count / SampleRate;
                        if (durationSec >= MinSpeechDurationSec)
                        {
                            DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio,
                                $"VAD RMS: speech END, duration={durationSec:F2}s, emitting segment");
                            EmitSpeechSegment();
                        }
                        else
                        {
                            DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio,
                                $"VAD RMS: speech END, duration={durationSec:F2}s TOO SHORT, discarding");
                            _speechFrames.Clear();
                        }
                        _isSpeaking = false;
                    }
                }
            }
        }

        private void EmitSpeechSegment()
        {
            if (_speechFrames.Count == 0) return;

            var wav = WavHelper.CreateWavFromFloat(_speechFrames.ToArray(), SampleRate);
            _speechFrames.Clear();
            OnSpeechSegment?.Invoke(wav);
        }

        public void Dispose()
        {
            _vad?.Dispose();
        }
    }

    /// <summary>
    /// Helper to create WAV byte arrays from float samples.
    /// </summary>
    internal static class WavHelper
    {
        public static byte[] CreateWavFromFloat(float[] samples, int sampleRate)
        {
            var int16 = new short[samples.Length];
            for (int i = 0; i < samples.Length; i++)
            {
                var v = Math.Max(-1.0f, Math.Min(1.0f, samples[i]));
                int16[i] = (short)(v * short.MaxValue);
            }

            using var ms = new MemoryStream();
            using var bw = new BinaryWriter(ms);
            int bytesPerSample = 2;
            int subChunk2Size = int16.Length * bytesPerSample;
            int chunkSize = 36 + subChunk2Size;

            bw.Write(Encoding.ASCII.GetBytes("RIFF"));
            bw.Write(chunkSize);
            bw.Write(Encoding.ASCII.GetBytes("WAVE"));
            bw.Write(Encoding.ASCII.GetBytes("fmt "));
            bw.Write(16);
            bw.Write((short)1);
            bw.Write((short)1);
            bw.Write(sampleRate);
            bw.Write(sampleRate * bytesPerSample);
            bw.Write((short)bytesPerSample);
            bw.Write((short)(bytesPerSample * 8));
            bw.Write(Encoding.ASCII.GetBytes("data"));
            bw.Write(subChunk2Size);

            foreach (var s in int16) bw.Write(s);

            return ms.ToArray();
        }
    }
}
