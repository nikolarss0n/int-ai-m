using System;
using WebRtcVad;

namespace InterviewMasterApp.Infrastructure.Speech
{
    /// <summary>
    /// Simple wrapper around WebRtcVad NuGet package.
    /// Accepts float[] samples (mono, 16kHz) and invokes the native VAD to decide speech/no-speech.
    /// </summary>
    public class WebRtcVadWrapper : IVadEngine
    {
        private Vad _vad;
        private const int FrameMs = 30; // frame length for WebRTC VAD (10/20/30 ms allowed)
        private int _sampleRate = 16000;
        private int _frameSamples;

        public Action<float, bool> OnLevelUpdate { get; set; }
        public Action<byte[]> OnSpeechSegment { get; set; }
        public Action<string> OnStatusChange { get; set; }

        private System.Collections.Generic.List<short> _recordingBuffer = new System.Collections.Generic.List<short>();

        public WebRtcVadWrapper(int aggressiveness = 2)
        {
            _vad = new Vad();
            _vad.Init();
            _vad.SetMode(aggressiveness); // 0..3
            _frameSamples = _sampleRate * FrameMs / 1000;
            OnStatusChange?.Invoke("WebRTC VAD initialized (mode=" + aggressiveness + ")");
        }

        public void ProcessChunk(float[] samples)
        {
            // Convert float samples to PCM16
            var pcm = new short[samples.Length];
            for (int i = 0; i < samples.Length; i++) pcm[i] = (short)Math.Max(short.MinValue, Math.Min(short.MaxValue, (int)(samples[i] * 32767)));

            // Push into buffer and process in frame-sized windows
            int idx = 0;
            while (idx + _frameSamples <= pcm.Length)
            {
                var frame = new short[_frameSamples];
                Array.Copy(pcm, idx, frame, 0, _frameSamples);
                idx += _frameSamples;

                bool isSpeech = _vad.Process(_sampleRate, frame, 0, frame.Length) == 1;
                // Call level update with simple indicator
                OnLevelUpdate?.Invoke(isSpeech ? 1.0f : 0.0f, isSpeech);

                if (isSpeech)
                {
                    // Append to recording buffer
                    foreach (var s in frame) _recordingBuffer.Add(s);
                }
                else
                {
                    if (_recordingBuffer.Count > 0)
                    {
                        // finalize recorded segment
                        var bytes = Pcm16ToWav(_recordingBuffer.ToArray(), _sampleRate);
                        OnSpeechSegment?.Invoke(bytes);
                        _recordingBuffer.Clear();
                    }
                }
            }

            // leftover samples are ignored for simplicity
        }

        private byte[] Pcm16ToWav(short[] pcm, int sampleRate)
        {
            using var ms = new System.IO.MemoryStream();
            using var bw = new System.IO.BinaryWriter(ms);
            int bytesPerSample = 2;
            int subChunk2Size = pcm.Length * bytesPerSample;
            int chunkSize = 36 + subChunk2Size;

            bw.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));
            bw.Write(chunkSize);
            bw.Write(System.Text.Encoding.ASCII.GetBytes("WAVE"));
            bw.Write(System.Text.Encoding.ASCII.GetBytes("fmt "));
            bw.Write(16);
            bw.Write((short)1);
            bw.Write((short)1);
            bw.Write(sampleRate);
            bw.Write(sampleRate * bytesPerSample);
            bw.Write((short)(bytesPerSample));
            bw.Write((short)(bytesPerSample * 8));
            bw.Write(System.Text.Encoding.ASCII.GetBytes("data"));
            bw.Write(subChunk2Size);

            foreach (var s in pcm) bw.Write(s);

            return ms.ToArray();
        }

        public void Dispose()
        {
            _vad?.Dispose();
            _vad = null;
        }
    }
}

