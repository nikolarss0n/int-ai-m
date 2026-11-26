using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using InterviewMasterApp.Domain.Entities;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Domain.ValueObjects;

namespace InterviewMasterApp.Application.UseCases
{
    public sealed class AnalyzeCodingTaskUseCase
    {
        private readonly IAnthropicVisionClient _visionClient;

        public AnalyzeCodingTaskUseCase(IAnthropicVisionClient visionClient)
        {
            _visionClient = visionClient ?? throw new ArgumentNullException(nameof(visionClient));
        }

        public async Task<(bool IsSuccess, Analysis? Analysis, string? ErrorMessage)> ExecuteAsync(
            CodingSession session,
            AnalysisMode mode,
            Action<string>? onChunk = null,
            CancellationToken ct = default)
        {
            if (session == null || !session.IsReadyForAnalysis)
                return (false, null, "No screenshots to analyze.");

            var prompt = mode.Prompt();
            var images = session.ScreenshotsAsBase64;
            var result = await _visionClient.SendMessageStreamAsync(images, prompt, chunk => onChunk?.Invoke(chunk), ct: ct)
                .ConfigureAwait(false);

            if (!result.IsSuccess)
                return (false, null, result.ErrorMessage ?? "Analysis failed.");

            var analysis = new Analysis(result.Value);
            session.SetAnalysis(analysis);
            return (true, analysis, null);
        }
    }

    public sealed class ClearSessionUseCase
    {
        public void Execute(CodingSession session, bool clearScreenshots = true)
        {
            if (session == null) return;
            if (clearScreenshots) session.Clear();
            else session.ClearAnalysis();
        }
    }

    public sealed class ConfigureApiKeyUseCase
    {
        private readonly Func<string, bool> _saveKey;
        private readonly Func<string?> _loadKey;
        private readonly Func<bool> _deleteKey;

        public ConfigureApiKeyUseCase(Func<string, bool> saveKey, Func<string?> loadKey, Func<bool> deleteKey)
        {
            _saveKey = saveKey ?? throw new ArgumentNullException(nameof(saveKey));
            _loadKey = loadKey ?? throw new ArgumentNullException(nameof(loadKey));
            _deleteKey = deleteKey ?? throw new ArgumentNullException(nameof(deleteKey));
        }

        public bool Save(string rawKey)
        {
            var trimmed = (rawKey ?? string.Empty).Trim();
            if (trimmed.Length < 10) return false;
            var ok = _saveKey(trimmed);
            if (ok) AppNotifications.RaiseApiKeysUpdated();
            return ok;
        }

        public string? Load() => _loadKey();

        public bool Delete()
        {
            var ok = _deleteKey();
            if (ok) AppNotifications.RaiseApiKeysUpdated();
            return ok;
        }
    }
}
