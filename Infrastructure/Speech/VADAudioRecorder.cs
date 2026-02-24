using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace InterviewMasterApp.Infrastructure.Speech
{
    /// <summary>
    /// Port of VADAudioRecorder - simplified implementation using AVAudioRecorder equivalents are not available.
    /// This class provides the same public callbacks and uses a temporary file approach simulated by caller.
    /// For real audio capture use NAudio (Windows) or WASAPI loopback.
    /// </summary>
    public class VADAudioRecorder
    {
        public Action<float, bool> OnLevelUpdate { get; set; }
        public Action<byte[]> OnSpeechSegment { get; set; }
        public Action<string> OnStatusChange { get; set; }

        private bool _isListening;
        private string _tempFilePath;

        public void StartListening()
        {
            _isListening = true;
            _tempFilePath = Path.Combine(Path.GetTempPath(), $"vad_{Guid.NewGuid()}.m4a");
            OnStatusChange?.Invoke("VAD: Listening (simulated)");
        }

        public void StopListening()
        {
            _isListening = false;
            if (File.Exists(_tempFilePath)) try { File.Delete(_tempFilePath); } catch { }
            OnStatusChange?.Invoke("VAD: Stopped");
        }

        /// <summary>
        /// Simulate feeding audio samples (wav/m4a bytes) into the recorder for detection.
        /// In a real implementation this would be audio frames and internal RMS calculation.
        /// </summary>
        public void FeedAudioData(byte[] audioBytes)
        {
            if (!_isListening) return;

            // Naive trigger: whenever audioBytes length > 0, treat as a speech segment
            if (audioBytes != null && audioBytes.Length > 0)
            {
                OnLevelUpdate?.Invoke(0.5f, true);
                OnSpeechSegment?.Invoke(audioBytes);
            }
        }
    }
}
