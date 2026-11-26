using System;

namespace InterviewMasterApp.Domain.Model
{
    public enum AudioReservationOwner
    {
        Interview,
        Practice
    }

    public sealed record MicrophoneLease(Guid Id, AudioReservationOwner Owner);

    public sealed class MicrophoneReservations
    {
        private readonly object _lock = new();
        public MicrophoneLease? Current { get; private set; }

        public MicrophoneLease? Acquire(AudioReservationOwner owner)
        {
            lock (_lock)
            {
                if (Current != null) return null;
                Current = new MicrophoneLease(Guid.NewGuid(), owner);
                return Current;
            }
        }

        public bool Owns(MicrophoneLease lease)
        {
            lock (_lock) return Current == lease;
        }

        public void Release(MicrophoneLease lease)
        {
            lock (_lock)
            {
                if (Current == lease) Current = null;
            }
        }
    }

    public sealed class PushToTalkState
    {
        public bool Latched { get; private set; }
        public double? PressedAt { get; private set; }
        private bool _clearsLatch;
        public Guid? PressId { get; private set; }

        public bool IsMuted => Latched || (PressedAt.HasValue && !_clearsLatch);

        public Guid? KeyDown(double timeSeconds, bool isRepeat)
        {
            if (isRepeat || PressedAt.HasValue) return null;
            _clearsLatch = Latched;
            if (_clearsLatch) Latched = false;
            PressedAt = timeSeconds;
            PressId = Guid.NewGuid();
            return PressId;
        }

        public bool KeyUp(double timeSeconds)
        {
            if (!PressedAt.HasValue) return false;
            if (!_clearsLatch) Latched = (timeSeconds - PressedAt.Value) < 0.4;
            PressedAt = null;
            PressId = null;
            _clearsLatch = false;
            return true;
        }

        public void ToggleLatch()
        {
            var next = !IsMuted;
            Latched = next;
            PressedAt = null;
            PressId = null;
            _clearsLatch = false;
        }

        public bool Expire(Guid id)
        {
            if (PressId != id) return false;
            Latched = false;
            PressedAt = null;
            PressId = null;
            _clearsLatch = false;
            return true;
        }
    }

    public enum CapturePresentationKind
    {
        Idle,
        Switching,
        Unavailable,
        Listening,
        Speaking,
        Muted
    }

    public sealed record CapturePresentation(CapturePresentationKind Kind, CaptureDevice? Device = null)
    {
        public string Label => Kind switch
        {
            CapturePresentationKind.Idle => "Audio starts with the interview",
            CapturePresentationKind.Switching => "Switching audio source",
            CapturePresentationKind.Unavailable => "Audio unavailable. Select a source to try again.",
            CapturePresentationKind.Listening => $"Listening to {(Device ?? CaptureDevice.SystemAudio).GetDisplayName()}. Click or press Ctrl+Shift+M to mute.",
            CapturePresentationKind.Speaking => $"Speech detected on {(Device ?? CaptureDevice.SystemAudio).GetDisplayName()}. Click or press Ctrl+Shift+M to mute.",
            CapturePresentationKind.Muted => "Muted. Click or press Ctrl+Shift+M to unmute.",
            _ => string.Empty
        };

        public static CapturePresentation Resolve(CaptureDevice? active, bool sessionActive, bool switching, bool muted, bool speaking)
        {
            if (!sessionActive) return new CapturePresentation(CapturePresentationKind.Idle);
            if (muted) return new CapturePresentation(CapturePresentationKind.Muted);
            if (active.HasValue) return new CapturePresentation(speaking ? CapturePresentationKind.Speaking : CapturePresentationKind.Listening, active.Value);
            return new CapturePresentation(switching ? CapturePresentationKind.Switching : CapturePresentationKind.Unavailable);
        }

        public static CaptureDevice ResolveStartupCaptureDevice(CaptureDevice preferred, bool microphoneAllowed) =>
            preferred == CaptureDevice.Microphone && !microphoneAllowed ? CaptureDevice.SystemAudio : preferred;
    }
}
