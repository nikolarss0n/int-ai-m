using System;

namespace InterviewMasterApp
{
    /// <summary>
    /// App-wide notification events (single canonical definition).
    /// Other parts of the app subscribe to these static events.
    /// </summary>
    public static class AppNotifications
    {
        public static event Action? ApiKeysUpdated;
        public static event Action? InterviewSettingsUpdated;

        public static void RaiseApiKeysUpdated() => ApiKeysUpdated?.Invoke();
        public static void RaiseInterviewSettingsUpdated() => InterviewSettingsUpdated?.Invoke();
    }
}
