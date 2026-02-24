using System;

namespace InterviewMasterApp.Infrastructure.Speech
{
    public interface IVadEngine : IDisposable
    {
        /// <summary>
        /// Process a chunk of float samples (mono, 16kHz recommended)
        /// </summary>
        void ProcessChunk(float[] samples);

        Action<float, bool> OnLevelUpdate { get; set; }
        Action<byte[]> OnSpeechSegment { get; set; }
        Action<string> OnStatusChange { get; set; }
    }
}

