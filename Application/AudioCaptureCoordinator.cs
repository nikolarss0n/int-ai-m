using System;
using System.Threading;
using System.Threading.Tasks;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Application
{
    /// <summary>
    /// Coordinates switching between System Audio (WASAPI loopback), Microphone, and Both,
    /// manages mute state, and serializes Start/Stop transitions to prevent races.
    /// </summary>
    public sealed class AudioCaptureCoordinator : IDisposable
    {
        private readonly Func<CaptureDevice, IAudioSourceCapture> _factory;
        private readonly SemaphoreSlim _lifecycleLock = new(1, 1);

        private IAudioSourceCapture? _activeCapture;
        private CaptureDevice _selectedDevice;
        private bool _isSessionActive;
        private bool _isSwitching;
        private bool _isMuted;
        private bool _isSpeaking;
        private bool _disposed;

        public CaptureDevice SelectedDevice => _selectedDevice;
        public CaptureDevice? ActiveDevice => _activeCapture?.Device;
        public bool IsSessionActive => _isSessionActive;
        public bool IsMuted => _isMuted;
        public bool IsSwitching => _isSwitching;

        public event Action<float, bool>? OnLevel;
        public event Action<byte[], AudioSource>? OnSpeechSegment;
        public event Action<string>? OnStatus;
        public event Action<CapturePresentation>? OnPresentationChanged;

        public AudioCaptureCoordinator(Func<CaptureDevice, IAudioSourceCapture> factory, CaptureDevice? initialDevice = null)
        {
            _factory = factory ?? throw new ArgumentNullException(nameof(factory));
            _selectedDevice = initialDevice ?? AppSettings.Shared.CaptureDevice;
        }

        public CapturePresentation CurrentPresentation =>
            CapturePresentation.Resolve(ActiveDevice, _isSessionActive, _isSwitching, _isMuted, _isSpeaking);

        public async Task StartAsync(CaptureDevice? device = null, CancellationToken ct = default)
        {
            await _lifecycleLock.WaitAsync(ct).ConfigureAwait(false);
            try
            {
                ThrowIfDisposed();
                if (device.HasValue) _selectedDevice = device.Value;
                _isSessionActive = true;
                _isSwitching = true;
                PublishPresentation();

                await StopActiveLockedAsync().ConfigureAwait(false);
                await StartDeviceLockedAsync(_selectedDevice, ct).ConfigureAwait(false);
            }
            finally
            {
                _isSwitching = false;
                PublishPresentation();
                _lifecycleLock.Release();
            }
        }

        public async Task SwitchDeviceAsync(CaptureDevice newDevice, CancellationToken ct = default)
        {
            await _lifecycleLock.WaitAsync(ct).ConfigureAwait(false);
            try
            {
                ThrowIfDisposed();
                _selectedDevice = newDevice;
                AppSettings.Shared.CaptureDevice = newDevice;

                if (!_isSessionActive)
                {
                    PublishPresentation();
                    return;
                }

                _isSwitching = true;
                PublishPresentation();
                await StopActiveLockedAsync().ConfigureAwait(false);
                await StartDeviceLockedAsync(newDevice, ct).ConfigureAwait(false);
            }
            finally
            {
                _isSwitching = false;
                PublishPresentation();
                _lifecycleLock.Release();
            }
        }

        public async Task StopAsync()
        {
            await _lifecycleLock.WaitAsync().ConfigureAwait(false);
            try
            {
                _isSessionActive = false;
                _isSwitching = false;
                _isSpeaking = false;
                await StopActiveLockedAsync().ConfigureAwait(false);
                PublishPresentation();
            }
            finally
            {
                _lifecycleLock.Release();
            }
        }

        public void SetMuted(bool muted)
        {
            _isMuted = muted;
            if (muted) _isSpeaking = false;
            _activeCapture?.SetMuted(muted);
            PublishPresentation();
        }

        public void ToggleMute() => SetMuted(!_isMuted);

        private async Task StartDeviceLockedAsync(CaptureDevice device, CancellationToken ct)
        {
            var capture = _factory(device);
            capture.SetMuted(_isMuted);
            capture.OnLevelUpdate = (db, speaking) =>
            {
                var changed = _isSpeaking != speaking;
                _isSpeaking = !_isMuted && speaking;
                OnLevel?.Invoke(_isMuted ? -100f : db, _isSpeaking);
                if (changed) PublishPresentation();
            };
            capture.OnSpeechSegment = (wav, source) =>
            {
                if (!_isMuted) OnSpeechSegment?.Invoke(wav, source);
            };
            capture.OnStatusChange = status => OnStatus?.Invoke(status);

            try
            {
                await capture.StartAsync(ct).ConfigureAwait(false);
                _activeCapture = capture;
            }
            catch
            {
                try { capture.Dispose(); } catch { }
                _activeCapture = null;
                throw;
            }
        }

        private async Task StopActiveLockedAsync()
        {
            var capture = _activeCapture;
            _activeCapture = null;
            if (capture == null) return;

            capture.OnLevelUpdate = null;
            capture.OnSpeechSegment = null;
            capture.OnStatusChange = null;
            try { await capture.StopAsync().ConfigureAwait(false); } catch { }
            try { capture.Dispose(); } catch { }
        }

        private void PublishPresentation() => OnPresentationChanged?.Invoke(CurrentPresentation);

        private void ThrowIfDisposed()
        {
            if (_disposed) throw new ObjectDisposedException(nameof(AudioCaptureCoordinator));
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            try { StopAsync().Wait(3000); } catch { }
            _lifecycleLock.Dispose();
        }
    }
}
