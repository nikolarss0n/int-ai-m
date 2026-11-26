using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Domain.Speech
{
    /// <summary>
    /// Capture-independent adaptive-baseline speech turn detector with speculative preview support.
    /// </summary>
    public sealed class SpeechTurnDetector
    {
        public sealed record Labels(string Idle, string Speaking, string Processing, string Muted)
        {
            public static readonly Labels SystemAudio = new(
                "Listening to system audio...", "Interviewer speaking...", "Processing...", "Capture muted");
            public static readonly Labels Microphone = new(
                "Listening to microphone...", "Interviewer speaking...", "Processing...", "Capture muted");
        }

        public sealed record Tuning(
            float SpeechMargin,
            float SilenceMargin,
            float AbsoluteMinSpeechDb,
            double MinSpeechDuration,
            double SilenceTimeout,
            double SpeculativeSilenceTimeout,
            int BaselineWindowSize,
            int BaselineUpdateInterval,
            double LevelCallbackInterval)
        {
            public static readonly Tuning SystemAudio = new(
                18f, 10f, -35f,
                AppConstants.Thresholds.MinSpeechDuration,
                AppConstants.Thresholds.SilenceTimeout,
                AppConstants.Thresholds.SpeculativeSilenceTimeout,
                40, 5, 0.08);

            public static readonly Tuning MicrophoneExperimental = SystemAudio;
        }

        private readonly object _lock = new();
        private readonly Labels _labels;
        private readonly Tuning _tuning;
        private readonly Func<DateTime> _now;

        private Action<SpeechTurnEmit, byte[]?>? _turnSink;
        private Action<float, bool>? _levelSink;
        private Action<string>? _statusSink;

        private readonly List<float> _baselineBuffer = new();
        private float _currentBaseline = -60f;
        private int _baselineUpdateCount;
        private bool _isSpeaking;
        private bool _isMuted;
        private bool _isShutdown;
        private DateTime? _speechStartTime;
        private DateTime? _lastSpeechTime;
        private float _peakLevel = -100f;
        private readonly List<float> _recordedSamples = new();
        private double _sampleRate = 16_000;
        private bool _didPreviewCurrentUtterance;
        private DateTime _lastLevelCallbackTime = DateTime.MinValue;
        private bool _lastLevelCallbackSpeaking;

        public SpeechTurnDetector(
            Labels labels,
            Tuning tuning,
            Action<SpeechTurnEmit, byte[]?> emitTurn,
            Action<float, bool> emitLevel,
            Action<string> emitStatus,
            Func<DateTime>? now = null)
        {
            _labels = labels;
            _tuning = tuning;
            _now = now ?? (() => DateTime.UtcNow);
            _turnSink = emitTurn;
            _levelSink = emitLevel;
            _statusSink = emitStatus;
        }

        public void SetSampleRate(double rate)
        {
            lock (_lock)
            {
                if (double.IsFinite(rate) && rate > 0 && rate <= uint.MaxValue / 2.0)
                    _sampleRate = rate;
            }
        }

        public void SetMuted(bool muted)
        {
            List<Action> emissions;
            lock (_lock)
            {
                if (_isShutdown || _isMuted == muted) return;
                _isMuted = muted;
                emissions = new List<Action>();
                var turn = _turnSink;
                var level = _levelSink;
                var status = _statusSink;

                if (muted)
                {
                    if (_didPreviewCurrentUtterance)
                        emissions.Add(() => turn?.Invoke(SpeechTurnEmit.SpeechResumedAfterPreview, null));
                    AbandonCurrentUtterance();
                    _lastLevelCallbackSpeaking = false;
                    emissions.Add(() => level?.Invoke(-100f, false));
                }
                var msg = muted ? _labels.Muted : _labels.Idle;
                emissions.Add(() => status?.Invoke(msg));
            }
            foreach (var e in emissions) e();
        }

        public void Reset()
        {
            Action? emission = null;
            lock (_lock)
            {
                var cancelledPreview = _didPreviewCurrentUtterance;
                AbandonCurrentUtterance();
                _baselineBuffer.Clear();
                _currentBaseline = -60f;
                _baselineUpdateCount = 0;
                _lastLevelCallbackTime = DateTime.MinValue;
                _lastLevelCallbackSpeaking = false;
                if (cancelledPreview)
                {
                    var turn = _turnSink;
                    emission = () => turn?.Invoke(SpeechTurnEmit.SpeechResumedAfterPreview, null);
                }
            }
            emission?.Invoke();
        }

        public void Shutdown()
        {
            lock (_lock)
            {
                _isShutdown = true;
                AbandonCurrentUtterance();
                _turnSink = null;
                _levelSink = null;
                _statusSink = null;
            }
        }

        public void Ingest(ReadOnlySpan<float> samples)
        {
            List<Action> emissions;
            lock (_lock)
            {
                if (_isShutdown || _isMuted || samples.Length == 0) return;

                double sum = 0;
                for (int i = 0; i < samples.Length; i++) sum += samples[i] * samples[i];
                var rms = (float)Math.Sqrt(sum / Math.Max(samples.Length, 1));
                var db = 20f * MathF.Log10(MathF.Max(rms, 0.0000001f));

                if (_isSpeaking)
                {
                    for (int i = 0; i < samples.Length; i++) _recordedSamples.Add(samples[i]);
                }

                emissions = ProcessVad(db);
            }
            foreach (var e in emissions) e();
        }

        private void UpdateBaseline(float db)
        {
            if (_isSpeaking || db <= -90f || db >= -20f) return;
            _baselineUpdateCount++;
            if (_baselineUpdateCount < _tuning.BaselineUpdateInterval) return;
            _baselineUpdateCount = 0;

            _baselineBuffer.Add(db);
            if (_baselineBuffer.Count > _tuning.BaselineWindowSize) _baselineBuffer.RemoveAt(0);
            if (_baselineBuffer.Count >= 10)
            {
                var sorted = _baselineBuffer.OrderBy(x => x).Take(_baselineBuffer.Count / 2).ToList();
                var newBaseline = sorted.Average();
                _currentBaseline = _currentBaseline * 0.7f + newBaseline * 0.3f;
            }
        }

        private List<Action> ProcessVad(float db)
        {
            var time = _now();
            var emissions = new List<Action>();
            var turn = _turnSink;
            var level = _levelSink;
            var status = _statusSink;

            UpdateBaseline(db);

            if (db > _currentBaseline + _tuning.SpeechMargin && db > _tuning.AbsoluteMinSpeechDb)
            {
                _lastSpeechTime = time;
                _peakLevel = MathF.Max(_peakLevel, db);
                if (!_isSpeaking)
                {
                    _isSpeaking = true;
                    _speechStartTime = time;
                    _peakLevel = db;
                    _recordedSamples.Clear();
                    _didPreviewCurrentUtterance = false;
                    emissions.Add(() => status?.Invoke(_labels.Speaking));
                }
                else if (_didPreviewCurrentUtterance)
                {
                    _didPreviewCurrentUtterance = false;
                    emissions.Add(() => turn?.Invoke(SpeechTurnEmit.SpeechResumedAfterPreview, null));
                }
            }
            else if (_isSpeaking)
            {
                var nearBaseline = db < _currentBaseline + _tuning.SilenceMargin;
                var silence = _lastSpeechTime.HasValue ? (time - _lastSpeechTime.Value).TotalSeconds : 0;

                if (nearBaseline && silence > _tuning.SpeculativeSilenceTimeout && !_didPreviewCurrentUtterance)
                {
                    var previewAudio = EligibleUtteranceWav(time);
                    if (previewAudio != null)
                    {
                        _didPreviewCurrentUtterance = true;
                        emissions.Add(() => turn?.Invoke(SpeechTurnEmit.SpeculativePreview, previewAudio));
                    }
                }

                if (nearBaseline && silence > _tuning.SilenceTimeout)
                {
                    var finalAudio = EligibleUtteranceWav(time);
                    if (finalAudio != null)
                    {
                        emissions.Add(() => status?.Invoke(_labels.Processing));
                        emissions.Add(() => turn?.Invoke(SpeechTurnEmit.FinalSilence, finalAudio));
                    }
                    else if (_didPreviewCurrentUtterance)
                    {
                        emissions.Add(() => turn?.Invoke(SpeechTurnEmit.SpeechResumedAfterPreview, null));
                    }
                    AbandonCurrentUtterance();
                    emissions.Add(() => status?.Invoke(_labels.Idle));
                }
            }

            var stateChanged = _isSpeaking != _lastLevelCallbackSpeaking;
            if (stateChanged || (time - _lastLevelCallbackTime).TotalSeconds >= _tuning.LevelCallbackInterval)
            {
                _lastLevelCallbackTime = time;
                _lastLevelCallbackSpeaking = _isSpeaking;
                var spk = _isSpeaking;
                emissions.Add(() => level?.Invoke(db, spk));
            }

            return emissions;
        }

        private void AbandonCurrentUtterance()
        {
            _isSpeaking = false;
            _speechStartTime = null;
            _lastSpeechTime = null;
            _peakLevel = -100f;
            _recordedSamples.Clear();
            _didPreviewCurrentUtterance = false;
        }

        private byte[]? EligibleUtteranceWav(DateTime now)
        {
            var duration = _speechStartTime.HasValue ? (now - _speechStartTime.Value).TotalSeconds : 0;
            if (duration <= _tuning.MinSpeechDuration ||
                _peakLevel - _currentBaseline < _tuning.SpeechMargin * 0.5f ||
                _recordedSamples.Count == 0)
                return null;

            uint dataSize = (uint)(_recordedSamples.Count * 2);
            uint sr = (uint)_sampleRate;
            using var ms = new MemoryStream();
            using var bw = new BinaryWriter(ms, Encoding.ASCII);
            bw.Write(Encoding.ASCII.GetBytes("RIFF"));
            bw.Write(dataSize + 36);
            bw.Write(Encoding.ASCII.GetBytes("WAVE"));
            bw.Write(Encoding.ASCII.GetBytes("fmt "));
            bw.Write(16u);
            bw.Write((ushort)1);
            bw.Write((ushort)1);
            bw.Write(sr);
            bw.Write(sr * 2);
            bw.Write((ushort)2);
            bw.Write((ushort)16);
            bw.Write(Encoding.ASCII.GetBytes("data"));
            bw.Write(dataSize);
            for (int i = 0; i < _recordedSamples.Count; i++)
            {
                var clamped = Math.Clamp(_recordedSamples[i], -1f, 1f);
                bw.Write((short)(clamped * short.MaxValue));
            }
            return ms.ToArray();
        }
    }
}
