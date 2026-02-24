using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Speech.Recognition;
using System.Threading.Tasks;

namespace InterviewMasterApp.Infrastructure.Audio
{
    public record VoiceAnalysisResult(double[] Pitch, double[] Jitter, double[] Shimmer, string Text);

    /// <summary>
    /// Voice analyzer: extracts pitch/jitter/shimmer from WAV audio and optionally runs speech recognition (Windows).
    /// This is a pragmatic port of the macOS VoiceAnalyzer that used SFSpeechRecognizer.
    /// </summary>
    public class VoiceAnalyzer
    {
        public VoiceAnalyzer() { }

        /// <summary>
        /// Request authorization - on Windows this is effectively a no-op; return true.
        /// </summary>
        public static Task<bool> RequestAuthorizationAsync()
        {
            return Task.FromResult(true);
        }

        /// <summary>
        /// Analyze audio file (WAV PCM16) and extract pitch/jitter/shimmer and recognized text (if available).
        /// </summary>
        public async Task<Result<VoiceAnalysisResult, Exception>> AnalyzeAudioAsync(string wavPath)
        {
            try
            {
                if (!File.Exists(wavPath)) return Result<VoiceAnalysisResult, Exception>.Fail(new FileNotFoundException("WAV not found", wavPath));

                using var fs = File.OpenRead(wavPath);
                var wav = WaveFileReader.ReadWav(fs);
                if (wav.FormatBitsPerSample != 16)
                    return Result<VoiceAnalysisResult, Exception>.Fail(new NotSupportedException("Only 16-bit PCM WAV supported"));

                // Convert to mono floats
                var samples = WaveFileReader.ReadSamples(wav);

                // Frame params
                int frameSize = Math.Min(2048, wav.SampleRate / 10 * 2); // ~200ms max
                int hop = frameSize / 2;

                var pitchList = new List<double>();
                var amplitudeList = new List<double>();

                for (int pos = 0; pos + frameSize <= samples.Length; pos += hop)
                {
                    var frame = new double[frameSize];
                    for (int i = 0; i < frameSize; i++) frame[i] = samples[pos + i];

                    // Windowing
                    var win = HammingWindow(frame);

                    // Autocorrelation pitch detection
                    var f0 = DetectFundamentalFrequency(win, wav.SampleRate, minHz: 50, maxHz: 800);
                    pitchList.Add(f0);

                    // RMS amplitude
                    var rms = Math.Sqrt(win.Select(x => x * x).Average());
                    amplitudeList.Add(rms);
                }

                // Jitter: normalized frame-to-frame pitch variation
                var validPitches = pitchList.Where(p => p > 0).ToArray();
                double[] jitterArr = new double[validPitches.Length];
                for (int i = 1; i < validPitches.Length; i++) jitterArr[i] = Math.Abs(validPitches[i] - validPitches[i - 1]);

                // Shimmer: amplitude variation
                double[] shimmerArr = new double[amplitudeList.Count];
                for (int i = 1; i < amplitudeList.Count; i++) shimmerArr[i] = Math.Abs(amplitudeList[i] - amplitudeList[i - 1]);

                // Try speech recognition (best-effort) using System.Speech (synchronous)
                string recognized = string.Empty;
                try
                {
                    recognized = RecognizeSpeechFromWav(wavPath);
                }
                catch
                {
                    recognized = string.Empty;
                }

                var result = new VoiceAnalysisResult(pitchList.ToArray(), jitterArr, shimmerArr, recognized);
                return Result<VoiceAnalysisResult, Exception>.Ok(result);
            }
            catch (Exception ex)
            {
                return Result<VoiceAnalysisResult, Exception>.Fail(ex);
            }
        }

        private static double[] HammingWindow(double[] input)
        {
            int n = input.Length;
            var outArr = new double[n];
            for (int i = 0; i < n; i++)
                outArr[i] = input[i] * (0.54 - 0.46 * Math.Cos(2 * Math.PI * i / (n - 1)));
            return outArr;
        }

        private static double DetectFundamentalFrequency(double[] frame, int sampleRate, int minHz = 50, int maxHz = 800)
        {
            int minLag = sampleRate / maxHz;
            int maxLag = sampleRate / minHz;
            int n = frame.Length;

            double bestCorr = 0;
            int bestLag = 0;

            for (int lag = minLag; lag <= maxLag && lag < n - 1; lag++)
            {
                double sum = 0;
                for (int i = 0; i < n - lag; i++) sum += frame[i] * frame[i + lag];
                if (sum > bestCorr)
                {
                    bestCorr = sum;
                    bestLag = lag;
                }
            }

            if (bestLag == 0) return 0;
            return (double)sampleRate / bestLag;
        }

        private static string RecognizeSpeechFromWav(string wavPath)
        {
            try
            {
                using var recognizer = new SpeechRecognitionEngine(new CultureInfo("en-US"));
                recognizer.LoadGrammar(new DictationGrammar());
                recognizer.SetInputToWaveFile(wavPath);
                var result = recognizer.Recognize();
                return result?.Text ?? string.Empty;
            }
            catch
            {
                return string.Empty;
            }
        }
    }

    // Small WAV reader utility (supports PCM16)
    internal class WaveFileReader
    {
        public int SampleRate { get; private set; }
        public int Channels { get; private set; }
        public int FormatBitsPerSample { get; private set; }
        public long DataStart { get; private set; }
        public long DataLength { get; private set; }

        private WaveFileReader() { }

        public static WaveFileReader ReadWav(Stream s)
        {
            using var br = new BinaryReader(s, System.Text.Encoding.UTF8, leaveOpen: true);
            var riff = new string(br.ReadChars(4));
            if (riff != "RIFF") throw new InvalidDataException("Not a WAV file");
            _ = br.ReadInt32(); // size
            var wave = new string(br.ReadChars(4));
            if (wave != "WAVE") throw new InvalidDataException("Not a WAV file");

            var reader = new WaveFileReader();
            while (s.Position < s.Length)
            {
                var chunkId = new string(br.ReadChars(4));
                var chunkSize = br.ReadInt32();
                if (chunkId == "fmt ")
                {
                    var audioFormat = br.ReadInt16();
                    reader.Channels = br.ReadInt16();
                    reader.SampleRate = br.ReadInt32();
                    _ = br.ReadInt32(); // byte rate
                    _ = br.ReadInt16(); // block align
                    reader.FormatBitsPerSample = br.ReadInt16();
                    // Skip any extra fmt data
                    var fmtExtra = chunkSize - 16;
                    if (fmtExtra > 0) br.ReadBytes(fmtExtra);
                }
                else if (chunkId == "data")
                {
                    reader.DataStart = s.Position;
                    reader.DataLength = chunkSize;
                    break;
                }
                else
                {
                    // skip other chunks
                    br.ReadBytes(chunkSize);
                }
            }

            return reader;
        }

        public static double[] ReadSamples(WaveFileReader reader, Stream s)
        {
            s.Position = reader.DataStart;
            using var br = new BinaryReader(s, System.Text.Encoding.UTF8, leaveOpen: true);
            int sampleCount = (int)(reader.DataLength / (reader.FormatBitsPerSample / 8));
            var samples = new List<double>(sampleCount / reader.Channels);

            for (int i = 0; i < sampleCount; i += reader.Channels)
            {
                // Read first channel
                short val = br.ReadInt16();
                // Skip other channels
                for (int ch = 1; ch < reader.Channels; ch++) _ = br.ReadInt16();
                samples.Add(val / 32767.0);
            }

            return samples.ToArray();
        }

        public static double[] ReadSamples(Stream s)
        {
            var reader = ReadWav(s);
            return ReadSamples(reader, s);
        }
    }
}

