using System.Threading.Tasks;

namespace InterviewMasterApp.Application
{
    /// <summary>
    /// Interface for Groq API client used by the Application layer.
    /// </summary>
    public interface IGroqInterviewClient
    {
        Task<(string Text, double LatencyMs)> TranscribeAsync(byte[] audioData, string filename = "audio.wav");

        Task<(UtteranceClassification Classification, double LatencyMs)> ClassifyUtteranceAsync(
            string text, string buffer, string lastTopic);
    }

    /// <summary>
    /// Classification result from Groq LLM.
    /// </summary>
    public class UtteranceClassification
    {
        public string Status { get; set; } = "question";
        public string Topic { get; set; } = "unknown";
    }
}
