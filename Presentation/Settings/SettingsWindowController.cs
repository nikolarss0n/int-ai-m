using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using InterviewMasterApp;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Infrastructure.Storage;

namespace InterviewMasterApp.Presentation.Settings
{
    /// <summary>
    /// Port of SettingsWindowController.swift to WPF.
    /// Builds a settings Window in code and wires Save/Cancel logic to AppSettings and ApiKeyManager.
    /// </summary>
    public class SettingsWindowController
    {
        private Window? _window;

        // Controls
        private PasswordBox? _anthropicField;
        private PasswordBox? _groqField;
        private ComboBox? _roleDropdown;
        private ComboBox? _programmingLanguageDropdown;
        private ComboBox? _speakingLanguageDropdown;
        private TextBox? _frameworksField;

        public static Window Create()
        {
            var controller = new SettingsWindowController();
            controller.BuildWindow();
            return controller._window!;
        }

        private void BuildWindow()
        {
            _window = new Window
            {
                Title = "Settings",
                Width = 500,
                Height = 420,
                WindowStartupLocation = WindowStartupLocation.CenterScreen,
                ResizeMode = ResizeMode.NoResize
            };

            var root = new Grid { Margin = new Thickness(20) };
            _window.Content = root;

            // Define rows
            for (int i = 0; i < 12; i++) root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

            int row = 0;

            var interviewHeader = CreateSectionHeader("Interview Settings");
            Grid.SetRow(interviewHeader, row++);
            root.Children.Add(interviewHeader);

            // Role
            var rolePanel = CreateLabeledControl("Position/Role:", out _roleDropdown);
            PopulateEnumComboBox(_roleDropdown, typeof(InterviewRole), v => ((InterviewRole)v).GetDisplayName());
            SelectComboBoxItemByDisplay(_roleDropdown, AppSettings.Shared.Role.GetDisplayName());
            Grid.SetRow(rolePanel, row++);
            root.Children.Add(rolePanel);

            // Programming Language
            var progPanel = CreateLabeledControl("Programming Language:", out _programmingLanguageDropdown);
            PopulateEnumComboBox(_programmingLanguageDropdown, typeof(ProgrammingLanguage), v => ((ProgrammingLanguage)v).GetDisplayName());
            SelectComboBoxItemByDisplay(_programmingLanguageDropdown, AppSettings.Shared.ProgrammingLanguage.GetDisplayName());
            Grid.SetRow(progPanel, row++);
            root.Children.Add(progPanel);

            // Speaking Language
            var speakPanel = CreateLabeledControl("Response Language:", out _speakingLanguageDropdown);
            PopulateEnumComboBox(_speakingLanguageDropdown, typeof(SpeakingLanguage), v => ((SpeakingLanguage)v).GetDisplayName());
            SelectComboBoxItemByDisplay(_speakingLanguageDropdown, AppSettings.Shared.SpeakingLanguage.GetDisplayName());
            Grid.SetRow(speakPanel, row++);
            root.Children.Add(speakPanel);

            // Frameworks
            var frameworksPanel = CreateLabeledControl("Tech Stack:", out _frameworksField);
            _frameworksField.Text = AppSettings.Shared.Frameworks ?? string.Empty;
            _frameworksField.ToolTip = "Comma-separated list of frameworks and tools you use";
            Grid.SetRow(frameworksPanel, row++);
            root.Children.Add(frameworksPanel);

            // Divider (spacer)
            var divider = new Separator { Margin = new Thickness(0, 10, 0, 10) };
            Grid.SetRow(divider, row++);
            root.Children.Add(divider);

            // API Header
            var apiHeader = CreateSectionHeader("API Keys");
            Grid.SetRow(apiHeader, row++);
            root.Children.Add(apiHeader);

            // Anthropic Key
            var anthropicPanel = CreateLabeledPasswordBox("Anthropic API Key:", out _anthropicField);
            var anthKey = ApiKeyManager.Shared.GetKey(ApiKeyType.Anthropic);
            if (!string.IsNullOrEmpty(anthKey)) _anthropicField.Password = anthKey;
            Grid.SetRow(anthropicPanel, row++);
            root.Children.Add(anthropicPanel);

            // Groq Key
            var groqPanel = CreateLabeledPasswordBox("Groq API Key:", out _groqField);
            var groqKey = ApiKeyManager.Shared.GetKey(ApiKeyType.Groq);
            if (!string.IsNullOrEmpty(groqKey)) _groqField.Password = groqKey;
            Grid.SetRow(groqPanel, row++);
            root.Children.Add(groqPanel);

            // Help text
            var helpText = new TextBlock { Text = "API keys are stored securely in your user profile file.", FontSize = 11, Margin = new Thickness(0, 6, 0, 12) };
            Grid.SetRow(helpText, row++);
            root.Children.Add(helpText);

            // Buttons
            var buttonsPanel = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
            var saveButton = new Button { Content = "Save", Width = 80, Margin = new Thickness(8, 0, 0, 0), IsDefault = true };
            saveButton.Click += (_, _) => SaveSettings();
            var cancelButton = new Button { Content = "Cancel", Width = 80, Margin = new Thickness(8, 0, 0, 0), IsCancel = true };
            cancelButton.Click += (_, _) => CancelSettings();
            buttonsPanel.Children.Add(cancelButton);
            buttonsPanel.Children.Add(saveButton);
            Grid.SetRow(buttonsPanel, row++);
            root.Children.Add(buttonsPanel);
        }

        private UIElement CreateSectionHeader(string title)
        {
            return new TextBlock { Text = title, FontWeight = FontWeights.Bold, FontSize = 13, Margin = new Thickness(0, 4, 0, 6) };
        }

        private FrameworkElement CreateLabeledControl(string labelText, out ComboBox comboBox)
        {
            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(160) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var label = new TextBlock { Text = labelText, VerticalAlignment = VerticalAlignment.Center };
            Grid.SetColumn(label, 0);
            grid.Children.Add(label);

            comboBox = new ComboBox { Margin = new Thickness(6, 2, 0, 2) };
            Grid.SetColumn(comboBox, 1);
            grid.Children.Add(comboBox);

            return grid;
        }

        private FrameworkElement CreateLabeledControl(string labelText, out TextBox textBox)
        {
            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(160) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var label = new TextBlock { Text = labelText, VerticalAlignment = VerticalAlignment.Center };
            Grid.SetColumn(label, 0);
            grid.Children.Add(label);

            textBox = new TextBox { Margin = new Thickness(6, 2, 0, 2) };
            Grid.SetColumn(textBox, 1);
            grid.Children.Add(textBox);

            return grid;
        }

        private FrameworkElement CreateLabeledPasswordBox(string labelText, out PasswordBox passwordBox)
        {
            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(160) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var label = new TextBlock { Text = labelText, VerticalAlignment = VerticalAlignment.Center };
            Grid.SetColumn(label, 0);
            grid.Children.Add(label);

            passwordBox = new PasswordBox { Margin = new Thickness(6, 2, 0, 2) };
            Grid.SetColumn(passwordBox, 1);
            grid.Children.Add(passwordBox);

            return grid;
        }

        private void PopulateEnumComboBox(ComboBox cb, Type enumType, Func<object, string> display)
        {
            cb.Items.Clear();
            foreach (var val in Enum.GetValues(enumType))
            {
                cb.Items.Add(new ComboBoxItem { Content = display(val), Tag = val });
            }
        }

        private void SelectComboBoxItemByDisplay(ComboBox cb, string display)
        {
            foreach (ComboBoxItem item in cb.Items)
            {
                if ((item.Content as string) == display)
                {
                    cb.SelectedItem = item;
                    return;
                }
            }
            if (cb.Items.Count > 0) cb.SelectedIndex = 0;
        }

        private void SaveSettings()
        {
            // Interview Settings
            if (_roleDropdown?.SelectedItem is ComboBoxItem roleItem && roleItem.Tag is InterviewRole role)
            {
                AppSettings.Shared.Role = role;
            }

            if (_programmingLanguageDropdown?.SelectedItem is ComboBoxItem langItem && langItem.Tag is ProgrammingLanguage pl)
            {
                AppSettings.Shared.ProgrammingLanguage = pl;
            }

            if (_speakingLanguageDropdown?.SelectedItem is ComboBoxItem spItem && spItem.Tag is SpeakingLanguage sl)
            {
                AppSettings.Shared.SpeakingLanguage = sl;
            }

            AppSettings.Shared.Frameworks = _frameworksField?.Text?.Trim() ?? string.Empty;

            // API Keys
            var anthropicKey = _anthropicField?.Password?.Trim() ?? string.Empty;
            var groqKey = _groqField?.Password?.Trim() ?? string.Empty;

            if (!string.IsNullOrEmpty(anthropicKey)) ApiKeyManager.Shared.SetKey(anthropicKey, ApiKeyType.Anthropic);
            if (!string.IsNullOrEmpty(groqKey)) ApiKeyManager.Shared.SetKey(groqKey, ApiKeyType.Groq);

            // Fire notifications (simple static events)
            AppNotifications.RaiseApiKeysUpdated();
            AppNotifications.RaiseInterviewSettingsUpdated();

            _window?.Close();
        }

        private void CancelSettings()
        {
            _window?.Close();
        }
    }

}

