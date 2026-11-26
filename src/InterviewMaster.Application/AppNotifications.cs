using System;

namespace InterviewMasterApp
{
    public static class AppNotifications
    {
        public static event Action? ApiKeysUpdated;
        public static event Action? InterviewSettingsUpdated;
        public static event Action? ResumeChanged;

        public static void RaiseApiKeysUpdated() => ApiKeysUpdated?.Invoke();
        public static void RaiseInterviewSettingsUpdated() => InterviewSettingsUpdated?.Invoke();
        public static void RaiseResumeChanged() => ResumeChanged?.Invoke();
    }
}
