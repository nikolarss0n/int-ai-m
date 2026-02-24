keyword_spotter_vad.swiftusing System;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace InterviewMasterApp.Infrastructure.Audio
{
    /// <summary>
    /// Stores voice characteristics extracted from analytics.
    /// Migrated from Swift: VoiceProfile
    /// </summary>
    public class VoiceProfile
    {
        public double AvgPitch { get; set; }
        public double PitchStdDev { get; set; }
        public double AvgJitter { get; set; }
        public double AvgShimmer { get; set; }
        public int SampleCount { get; set; }

        private static string ProfilePath
        {
            get
            {
                var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                return Path.Combine(home, ".interview_master_voice_profile.json");
            }
        }

        public static bool Exists => File.Exists(ProfilePath);

        public static VoiceProfile Load()
        {
            try
            {
                var data = File.ReadAllText(ProfilePath);
                return JsonSerializer.Deserialize<VoiceProfile>(data);
            }
            catch
            {
                return null;
            }
        }

        public void Save()
        {
            var options = new JsonSerializerOptions { WriteIndented = true };
            var json = JsonSerializer.Serialize(this, options);
            File.WriteAllText(ProfilePath, json);
        }

        public static void Delete()
        {
            try { if (File.Exists(ProfilePath)) File.Delete(ProfilePath); } catch { }
        }

        public void AddSample(double[] pitch, double[] jitter, double[] shimmer)
        {
            if (pitch == null || pitch.Length == 0) return;

            var pitchAvg = pitch.Average();
            var pitchVariance = pitch.Select(p => (p - pitchAvg) * (p - pitchAvg)).Average();
            var pitchStd = Math.Sqrt(pitchVariance);

            var jitterAvg = (jitter == null || jitter.Length == 0) ? 0.0 : jitter.Average();
            var shimmerAvg = (shimmer == null || shimmer.Length == 0) ? 0.0 : shimmer.Average();

            var n = (double)SampleCount;
            AvgPitch = (AvgPitch * n + pitchAvg) / (n + 1);
            PitchStdDev = (PitchStdDev * n + pitchStd) / (n + 1);
            AvgJitter = (AvgJitter * n + jitterAvg) / (n + 1);
            AvgShimmer = (AvgShimmer * n + shimmerAvg) / (n + 1);
            SampleCount += 1;
        }

        /// <summary>
        /// Compare incoming voice against this profile, returning 0.0..1.0
        /// </summary>
        public double Similarity(double[] pitch, double[] jitter, double[] shimmer)
        {
            if (SampleCount == 0 || pitch == null || pitch.Length == 0) return 0.5; // unknown

            var incomingPitchAvg = pitch.Average();
            var incomingJitterAvg = (jitter == null || jitter.Length == 0) ? AvgJitter : jitter.Average();
            var incomingShimmerAvg = (shimmer == null || shimmer.Length == 0) ? AvgShimmer : shimmer.Average();

            var pitchTolerance = Math.Max(PitchStdDev * 2, 20.0);
            var pitchDiff = Math.Abs(incomingPitchAvg - AvgPitch);
            var pitchScore = Math.Max(0.0, 1.0 - (pitchDiff / pitchTolerance));

            var jitterTolerance = Math.Max(AvgJitter * 0.5, 0.01);
            var jitterDiff = Math.Abs(incomingJitterAvg - AvgJitter);
            var jitterScore = Math.Max(0.0, 1.0 - (jitterDiff / jitterTolerance));

            var shimmerTolerance = Math.Max(AvgShimmer * 0.5, 0.01);
            var shimmerDiff = Math.Abs(incomingShimmerAvg - AvgShimmer);
            var shimmerScore = Math.Max(0.0, 1.0 - (shimmerDiff / shimmerTolerance));

            return pitchScore * 0.6 + jitterScore * 0.2 + shimmerScore * 0.2;
        }

        public override string ToString()
        {
            return $"VoiceProfile(pitch: {AvgPitch:F1}Hz ±{PitchStdDev:F1}, jitter: {AvgJitter:F4}, shimmer: {AvgShimmer:F4}, samples: {SampleCount})";
        }
    }
}

