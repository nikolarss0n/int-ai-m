using System;
using System.Threading.Tasks;

namespace InterviewMasterApp.Infrastructure.Speech
{
    /// <summary>
    /// Stub for SystemAudioCapture. Capturing system audio (loopback) requires native APIs or NAudio.
    /// This implementation is a placeholder and throws NotSupportedException when used.
    /// </summary>
    public class SystemAudioCapture
    {
        public Action<float, bool> OnLevelUpdate { get; set; }
        public Action<byte[]> OnSpeechSegment { get; set; }
        public Action<string> OnStatusChange { get; set; }

        public Task StartCapturingAsync()
        {
            throw new NotSupportedException("System audio capture is platform-specific and not implemented in this stub.");
        }

        public Task StopCapturingAsync()
        {
            OnStatusChange?.Invoke("System audio capture stopped");
            return Task.CompletedTask;
        }
    }

