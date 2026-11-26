using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Infrastructure.Storage;
using InterviewMasterApp.Presentation.Styling;

namespace InterviewMasterApp.Presentation.Settings
{
    /// <summary>
    /// Dark-themed WPF Settings window covering Interview Profile, Answer Model, Audio Source,
    /// Transparency, Resume/CV import, and Windows Credential Manager API keys.
    /// </summary>
    public class SettingsWindowController
    {
        private Window? _window;

        private ComboBox? _roleDropdown;
        private ComboBox? _programmingLanguageDropdown;
        private ComboBox? _listeningLanguageDropdown;
        private ComboBox? _responseLanguageDropdown;
        private ComboBox? _answerModelDropdown;
        private ComboBox? _captureDeviceDropdown;
        private TextBox? _frameworksField;
        private TextBox? _openAiModelField;
        private Slider? _transparencySlider;
        private TextBlock? _resumeStatusLabel;

        private PasswordBox? _anthropicField;
        private PasswordBox? _groqField;
        private PasswordBox? _xaiField;
        private PasswordBox? _openAiField;

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
                Title = "Interview Master — Settings",
                Width = 580,
                Height = 680,
                Background = DesignTokens.BgCardBrush,
                Foreground = DesignTokens.TextPrimaryBrush,
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                ResizeMode = ResizeMode.NoResize
            };

            var scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
            var root = new StackPanel { Margin = new Thickness(22) };
            scroll.Content = root;
            _window.Content = scroll;

            root.Children.Add(SectionHeader("Interview Profile"));

            root.Children.Add(LabeledCombo("Position / Role:", out _roleDropdown));
            foreach (var r in EnumExtensions.SelectableRoles)
                _roleDropdown.Items.Add(new ComboBoxItem { Content = r.GetDisplayName(), Tag = r });
            SelectByTag(_roleDropdown, AppSettings.Shared.Role);

            root.Children.Add(LabeledCombo("Programming Language:", out _programmingLanguageDropdown));
            PopulateEnum<ProgrammingLanguage>(_programmingLanguageDropdown, v => v.GetDisplayName());
            SelectByTag(_programmingLanguageDropdown, AppSettings.Shared.ProgrammingLanguage);

            root.Children.Add(LabeledCombo("Listening Language:", out _listeningLanguageDropdown));
            PopulateEnum<SpeakingLanguage>(_listeningLanguageDropdown, v => v.GetDisplayName());
            SelectByTag(_listeningLanguageDropdown, AppSettings.Shared.ListeningLanguage);

            root.Children.Add(LabeledCombo("Response Language:", out _responseLanguageDropdown));
            PopulateEnum<SpeakingLanguage>(_responseLanguageDropdown, v => v.GetDisplayName());
            SelectByTag(_responseLanguageDropdown, AppSettings.Shared.ResponseLanguage);

            root.Children.Add(LabeledText("Tech Stack:", out _frameworksField, AppSettings.Shared.Frameworks));

            root.Children.Add(Divider());
            root.Children.Add(SectionHeader("Model, Audio & Appearance"));

            root.Children.Add(LabeledCombo("Answer Model:", out _answerModelDropdown));
            PopulateEnum<AnswerModel>(_answerModelDropdown, v => v.GetDisplayName());
            SelectByTag(_answerModelDropdown, AppSettings.Shared.AnswerModel);

            root.Children.Add(LabeledText("OpenAI Model ID:", out _openAiModelField, AppSettings.Shared.OpenAiAnswerModel));

            root.Children.Add(LabeledCombo("Audio Source:", out _captureDeviceDropdown));
            PopulateEnum<CaptureDevice>(_captureDeviceDropdown, v => v.GetDisplayName());
            SelectByTag(_captureDeviceDropdown, AppSettings.Shared.CaptureDevice);

            // Transparency slider
            var sliderGrid = new Grid { Margin = new Thickness(0, 4, 0, 4) };
            sliderGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(175) });
            sliderGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            var sliderLabel = new TextBlock { Text = "Background Transparency:", Foreground = DesignTokens.TextBodyBrush, VerticalAlignment = VerticalAlignment.Center };
            _transparencySlider = new Slider { Minimum = 0, Maximum = 0.85, Value = AppSettings.Shared.BackgroundTransparency, VerticalAlignment = VerticalAlignment.Center };
            Grid.SetColumn(sliderLabel, 0);
            Grid.SetColumn(_transparencySlider, 1);
            sliderGrid.Children.Add(sliderLabel);
            sliderGrid.Children.Add(_transparencySlider);
            root.Children.Add(sliderGrid);

            root.Children.Add(Divider());
            root.Children.Add(SectionHeader("Resume / CV (Live Grounding)"));

            var resumeRow = new DockPanel { Margin = new Thickness(0, 4, 0, 8) };
            var loadCvBtn = ActionButton("Load CV (.md / .txt)", OnLoadResumeClicked);
            var clearCvBtn = ActionButton("Clear", OnClearResumeClicked);
            clearCvBtn.Margin = new Thickness(8, 0, 0, 0);
            DockPanel.SetDock(clearCvBtn, Dock.Right);
            DockPanel.SetDock(loadCvBtn, Dock.Right);
            _resumeStatusLabel = new TextBlock
            {
                Text = ResumeStore.Shared.HasResume ? $"Loaded: {ResumeStore.Shared.FileName}" : "No CV loaded",
                Foreground = DesignTokens.TextMutedBrush,
                VerticalAlignment = VerticalAlignment.Center
            };
            resumeRow.Children.Add(clearCvBtn);
            resumeRow.Children.Add(loadCvBtn);
            resumeRow.Children.Add(_resumeStatusLabel);
            root.Children.Add(resumeRow);

            root.Children.Add(Divider());
            root.Children.Add(SectionHeader("API Keys (Windows Credential Manager)"));

            root.Children.Add(LabeledPassword("Anthropic API Key:", out _anthropicField, ApiKeyManager.Shared.GetKey(ApiKeyType.Anthropic)));
            root.Children.Add(LabeledPassword("Groq API Key (STT):", out _groqField, ApiKeyManager.Shared.GetKey(ApiKeyType.Groq)));
            root.Children.Add(LabeledPassword("xAI Grok API Key:", out _xaiField, ApiKeyManager.Shared.GetKey(ApiKeyType.Xai)));
            root.Children.Add(LabeledPassword("OpenAI API Key:", out _openAiField, ApiKeyManager.Shared.GetKey(ApiKeyType.OpenAi)));

            root.Children.Add(new TextBlock
            {
                Text = "Keys are saved to Windows Credential Manager (fallback read: %USERPROFILE%\\.interview-master-keys).",
                Foreground = DesignTokens.TextMutedBrush,
                FontSize = 11,
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 6, 0, 14)
            });

            var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
            var cancelBtn = ActionButton("Cancel", () => _window?.Close());
            cancelBtn.IsCancel = true;
            var saveBtn = ActionButton("Save", SaveSettings);
            saveBtn.Background = DesignTokens.AccentWashBrush;
            saveBtn.Foreground = DesignTokens.AccentTextBrush;
            saveBtn.Margin = new Thickness(8, 0, 0, 0);
            saveBtn.IsDefault = true;
            buttons.Children.Add(cancelBtn);
            buttons.Children.Add(saveBtn);
            root.Children.Add(buttons);
        }

        private void OnLoadResumeClicked()
        {
            var dlg = new OpenFileDialog
            {
                Title = "Select Resume / CV",
                Filter = "Markdown / Text (*.md;*.txt)|*.md;*.txt|All files (*.*)|*.*"
            };
            if (dlg.ShowDialog(_window) == true)
            {
                try
                {
                    ResumeStore.Shared.AttachFile(dlg.FileName);
                    if (_resumeStatusLabel != null)
                        _resumeStatusLabel.Text = $"Loaded: {ResumeStore.Shared.FileName}";
                }
                catch (Exception ex)
                {
                    MessageBox.Show(_window, ex.Message, "Could not load CV", MessageBoxButton.OK, MessageBoxImage.Warning);
                }
            }
        }

        private void OnClearResumeClicked()
        {
            ResumeStore.Shared.Clear();
            if (_resumeStatusLabel != null) _resumeStatusLabel.Text = "No CV loaded";
        }

        private void SaveSettings()
        {
            if (_roleDropdown?.SelectedItem is ComboBoxItem ri && ri.Tag is InterviewRole role)
                AppSettings.Shared.Role = role;
            if (_programmingLanguageDropdown?.SelectedItem is ComboBoxItem pi && pi.Tag is ProgrammingLanguage pl)
                AppSettings.Shared.ProgrammingLanguage = pl;
            if (_listeningLanguageDropdown?.SelectedItem is ComboBoxItem li && li.Tag is SpeakingLanguage ll)
                AppSettings.Shared.ListeningLanguage = ll;
            if (_responseLanguageDropdown?.SelectedItem is ComboBoxItem rli && rli.Tag is SpeakingLanguage rl)
                AppSettings.Shared.ResponseLanguage = rl;
            if (_answerModelDropdown?.SelectedItem is ComboBoxItem mi && mi.Tag is AnswerModel am)
                AppSettings.Shared.AnswerModel = am;
            if (_captureDeviceDropdown?.SelectedItem is ComboBoxItem ci && ci.Tag is CaptureDevice cd)
                AppSettings.Shared.CaptureDevice = cd;

            AppSettings.Shared.Frameworks = _frameworksField?.Text?.Trim() ?? string.Empty;
            AppSettings.Shared.OpenAiAnswerModel = _openAiModelField?.Text?.Trim() ?? AppConstants.Models.OpenAiDefault;
            if (_transparencySlider != null)
                AppSettings.Shared.BackgroundTransparency = _transparencySlider.Value;

            SaveKeyIfPresent(_anthropicField, ApiKeyType.Anthropic);
            SaveKeyIfPresent(_groqField, ApiKeyType.Groq);
            SaveKeyIfPresent(_xaiField, ApiKeyType.Xai);
            SaveKeyIfPresent(_openAiField, ApiKeyType.OpenAi);

            AppNotifications.RaiseApiKeysUpdated();
            AppNotifications.RaiseInterviewSettingsUpdated();
            _window?.Close();
        }

        private static void SaveKeyIfPresent(PasswordBox? box, ApiKeyType type)
        {
            var val = box?.Password?.Trim() ?? string.Empty;
            if (!string.IsNullOrEmpty(val))
                ApiKeyManager.Shared.SetKey(val, type);
        }

        private static TextBlock SectionHeader(string title) => new()
        {
            Text = title.ToUpperInvariant(),
            Foreground = DesignTokens.AccentTextBrush,
            FontWeight = FontWeights.SemiBold,
            FontSize = 11,
            Margin = new Thickness(0, 6, 0, 8)
        };

        private static Separator Divider() => new()
        {
            Background = DesignTokens.BorderSubtleBrush,
            Margin = new Thickness(0, 10, 0, 8)
        };

        private static FrameworkElement LabeledCombo(string label, out ComboBox combo)
        {
            combo = new ComboBox { Margin = new Thickness(0, 3, 0, 3), Height = 28 };
            return Row(label, combo);
        }

        private static FrameworkElement LabeledText(string label, out TextBox box, string value)
        {
            box = new TextBox
            {
                Text = value ?? string.Empty,
                Margin = new Thickness(0, 3, 0, 3),
                Height = 28,
                VerticalContentAlignment = VerticalAlignment.Center,
                Background = DesignTokens.BgWidgetBrush,
                Foreground = DesignTokens.TextPrimaryBrush,
                CaretBrush = DesignTokens.TextPrimaryBrush,
                BorderBrush = DesignTokens.BorderSubtleBrush,
                Padding = new Thickness(6, 0, 6, 0)
            };
            return Row(label, box);
        }

        private static FrameworkElement LabeledPassword(string label, out PasswordBox box, string? value)
        {
            box = new PasswordBox
            {
                Margin = new Thickness(0, 3, 0, 3),
                Height = 28,
                VerticalContentAlignment = VerticalAlignment.Center,
                Background = DesignTokens.BgWidgetBrush,
                Foreground = DesignTokens.TextPrimaryBrush,
                CaretBrush = DesignTokens.TextPrimaryBrush,
                BorderBrush = DesignTokens.BorderSubtleBrush,
                Padding = new Thickness(6, 0, 6, 0)
            };
            if (!string.IsNullOrEmpty(value)) box.Password = value;
            return Row(label, box);
        }

        private static Grid Row(string labelText, UIElement control)
        {
            var g = new Grid();
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(175) });
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            var lbl = new TextBlock { Text = labelText, Foreground = DesignTokens.TextBodyBrush, VerticalAlignment = VerticalAlignment.Center };
            Grid.SetColumn(lbl, 0);
            Grid.SetColumn(control, 1);
            g.Children.Add(lbl);
            g.Children.Add(control);
            return g;
        }

        private static Button ActionButton(string text, Action onClick)
        {
            var btn = new Button
            {
                Content = text,
                Padding = new Thickness(14, 6, 14, 6),
                Background = DesignTokens.BgWidgetBrush,
                Foreground = DesignTokens.TextPrimaryBrush,
                BorderThickness = new Thickness(0),
                Cursor = System.Windows.Input.Cursors.Hand
            };
            btn.Click += (_, _) => onClick();
            return btn;
        }

        private static void PopulateEnum<TEnum>(ComboBox cb, Func<TEnum, string> display) where TEnum : struct, Enum
        {
            foreach (var v in Enum.GetValues<TEnum>())
                cb.Items.Add(new ComboBoxItem { Content = display(v), Tag = v });
        }

        private static void SelectByTag(ComboBox cb, object value)
        {
            foreach (ComboBoxItem item in cb.Items)
            {
                if (Equals(item.Tag, value)) { cb.SelectedItem = item; return; }
            }
            if (cb.Items.Count > 0) cb.SelectedIndex = 0;
        }
    }
}
