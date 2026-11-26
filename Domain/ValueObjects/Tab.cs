namespace InterviewMasterApp.Domain.ValueObjects
{
    public enum Tab
    {
        Notes,
        Coding,
        Voice,
        Practice
    }

    public static class TabExtensions
    {
        public static string Title(this Tab tab) => tab switch
        {
            Tab.Notes => "Notes & CV",
            Tab.Coding => "Code Panel",
            Tab.Voice => "Live Interview",
            Tab.Practice => "Practice",
            _ => tab.ToString()
        };

        public static string KeyboardShortcut(this Tab tab) => tab switch
        {
            Tab.Voice => "Ctrl+Alt+1",
            Tab.Notes => "Ctrl+Alt+2",
            Tab.Coding => "Ctrl+Alt+3",
            Tab.Practice => "Ctrl+Alt+4",
            _ => string.Empty
        };
    }
}
