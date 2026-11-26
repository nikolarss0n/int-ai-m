using System;
using System.Threading;
using System.Threading.Tasks;
using InterviewMasterApp.Application;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Infrastructure.Audio;

namespace InterviewMasterApp.Infrastructure.Speech
{
    public static class AudioCaptureFactory
    {
        public static IAudioSourceCapture Create(CaptureDevice device) => device switch
        {
            CaptureDevice.SystemAudio => new WasapiLoopbackCaptureService(new SileroVADRecorder("SYS")),
            CaptureDevice.Microphone => new WindowsAudioCapture(new SileroVADRecorder("MIC")),
            CaptureDevice.Both => new CompositeAudioCapture(),
            _ => new WasapiLoopbackCaptureService(new SileroVADRecorder("SYS"))
        };
    }

    /// <summary>
    /// Captures both WASAPI system audio (interviewer) and microphone (candidate) concurrently.
    /// </summary>
    public sealed class CompositeAudioCapture : IAudioSourceCapture
    {
        private readonly WasapiLoopbackCaptureService _system;
        private readonly WindowsAudioCapture _mic;
        private bool _isCapturing;

        public CaptureDevice Device => CaptureDevice.Both;
        public bool IsCapturing => _isCapturing;

        public Action<float, bool>? OnLevelUpdate { get; set; }
        public Action<byte[], AudioSource>? OnSpeechSegment { get; set; }
        public Action<string>? OnStatusChange { get; set; }

        public CompositeAudioCapture()
        {
            _system = new WasapiLoopbackCaptureService(new SileroVADRecorder("SYS"));
            _mic = new WindowsAudioCapture(new SileroVADRecorder("MIC"));

            _system.OnLevelUpdate = (db, spk) => OnLevelUpdate?.Invoke(db, spk);
            _system.OnSpeechSegment = (wav, src) => OnSpeechSegment?.Invoke(wav, src);
            _system.OnStatusChange = s => OnStatusChange?.Invoke(s);

            _mic.OnSpeechSegment = (wav, src) => OnSpeechSegment?.Invoke(wav, src);
            _mic.OnStatusChange = s => OnStatusChange?.Invoke(s);
        }

        public async Task StartAsync(CancellationToken ct = default)
        {
            await _system.StartAsync(ct).ConfigureAwait(false);
            try
            {
                await _mic.StartAsync(ct).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                // System audio works even if no mic is connected
                OnStatusChange?.Invoke($"Mic unavailable (system audio active): {ex.Message}");
            }
            _isCapturing = true;
        }

        public async Task StopAsync()
        {
            _isCapturing = false;
            try { await _mic.StopAsync().ConfigureAwait(false); } catch { }
            try { await _system.StopAsync().ConfigureAwait(false); } catch { }
        }

        public void SetMuted(bool muted)
        {
            _system.SetMuted(muted);
            _mic.SetMuted(muted);
        }

        public void Dispose()
        {
            _mic.Dispose();
            _system.Dispose();
        }
    }
}
