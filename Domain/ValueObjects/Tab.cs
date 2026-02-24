using System;

namespace InterviewMasterApp.Domain.ValueObjects
{
    /// <summary>
    /// Value Object: Tab
    /// Represents the different tabs/views in the application.
    /// Migrated from Swift: Tab.swift
    /// </summary>
    public enum Tab
    {
        Notes,
        Coding,
        Voice
    }

    public static class TabExtensions
    {
        public static string Title(this Tab tab)
        {
            return tab switch
            {
                Tab.Notes => "📝 Interview Notes",
                Tab.Coding => "💻 Coding Task",
                Tab.Voice => "🎤 Voice Assistant",
                _ => string.Empty
            };
        }

        public static string KeyboardShortcut(this Tab tab)
        {
            return tab switch
            {
                Tab.Notes => "Ctrl+1",
                Tab.Coding => "Ctrl+2",
                Tab.Voice => "Ctrl+3",
                _ => string.Empty
            };
        }
    }
}
