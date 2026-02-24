namespace InterviewMasterApp.Infrastructure.Storage
{
    /// <summary>
    /// Interface for secure API key storage.
    /// </summary>
    public interface IApiKeyStore
    {
        string? GetKey(string service);
        void SetKey(string service, string key);
    }
}
