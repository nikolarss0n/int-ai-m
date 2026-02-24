using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace InterviewMasterApp.Application
{
    /// <summary>
    /// Interface for Anthropic API client used by the Application layer.
    /// </summary>
    public interface IAnthropicClient
    {
        Task WarmupConnectionAsync();
        void CancelCurrentRequest();

        Task StreamAnswerAsync(
            string question,
            List<object> messages,
            string userBackground,
            Action<string> onChunk,
            CancellationToken ct = default);

        Task<(string Text, double LatencyMs)> SendMessageAsync(string prompt, int maxTokens = 300);
    }
}
