using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;

namespace InterviewMasterApp.Presentation.Windows
{
    /// <summary>
    /// Delegate for permissions panel callbacks.
    /// </summary>
    public interface IPermissionsPanelDelegate
    {
        string DataConsentKey { get; }
    }

    /// <summary>
    /// Permissions panel controller (WPF). Ported from PermissionsPanelController.swift.
    /// </summary>
    public class PermissionsPanelController
    {
        private readonly IPermissionsPanelDelegate _delegate;
        private Border? _panel;
        private TextBlock? _accessibilityStatus;
        private TextBlock? _screenRecordingStatus;
        private TextBlock? _dataConsentStatus;
        private DispatcherTimer? _timer;

        public PermissionsPanelController(IPermissionsPanelDelegate @delegate)
        {
            _delegate = @delegate;
        }

        public void Setup(Panel parent)
        {
            var panel = new Border
            {
                Width = 560,
                Height = 440,
                Background = new SolidColorBrush(Color.FromArgb(245, 25, 25, 30)),
                CornerRadius = new CornerRadius(20),
                BorderBrush = Brushes.Gold,
                BorderThickness = new Thickness(2),
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                Padding = new Thickness(20)
            };

            var stack = new StackPanel { Orientation = Orientation.Vertical, VerticalAlignment = VerticalAlignment.Center };
            panel.Child = stack;

            var title = new TextBlock { Text = "Setup Required", Foreground = Brushes.White, FontSize = 24, FontWeight = FontWeights.Bold, HorizontalAlignment = HorizontalAlignment.Center };
            var subtitle = new TextBlock { Text = "Complete the following steps to use Interview Master", Foreground = Brushes.LightGray, FontSize = 12, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 4, 0, 12) };
            stack.Children.Add(title);
            stack.Children.Add(subtitle);

            CreateRow(stack, "Accessibility", "Global hotkeys from any app", "Open Settings", out _accessibilityStatus, OpenAccessibilitySettings);
            CreateRow(stack, "Screen Recording", "Capture coding problems", "Open Settings", out _screenRecordingStatus, OpenScreenRecordingSettings);
            CreateRow(stack, "AI Data Sharing", "Send screenshots for analysis", "I Consent", out _dataConsentStatus, GrantDataConsent);

            var hint = new TextBlock { Text = "Shortcuts work from any app", Foreground = Brushes.Gray, FontSize = 11, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 12, 0, 0) };
            stack.Children.Add(hint);

            parent.Children.Add(panel);
            _panel = panel;

            UpdateStatus();
            StartMonitoring();
        }

        private void CreateRow(Panel parent, string title, string description, string buttonTitle, out TextBlock statusLabel, Action clickHandler)
        {
            var row = new Grid { Margin = new Thickness(0, 8, 0, 8) };
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(120) });

            var stack = new StackPanel { Orientation = Orientation.Vertical };
            stack.Children.Add(new TextBlock { Text = title, Foreground = Brushes.White, FontSize = 14, FontWeight = FontWeights.SemiBold });
            stack.Children.Add(new TextBlock { Text = description, Foreground = Brushes.LightGray, FontSize = 11 });

            statusLabel = new TextBlock { Text = "Required", Foreground = Brushes.Orange, FontSize = 11, HorizontalAlignment = HorizontalAlignment.Right };

            var button = new Button { Content = buttonTitle, Width = 110, Margin = new Thickness(0, 4, 0, 0) };
            button.Click += (_, _) => clickHandler();

            Grid.SetColumn(stack, 0);
            Grid.SetColumn(statusLabel, 1);
            Grid.SetColumn(button, 1);

            row.Children.Add(stack);
            row.Children.Add(statusLabel);
            row.Children.Add(button);
            parent.Children.Add(row);
        }

        private void OpenAccessibilitySettings()
        {
            // Best-effort: open Windows privacy settings
            try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("ms-settings:privacy-accessibility") { UseShellExecute = true }); } catch { }
        }

        private void OpenScreenRecordingSettings()
        {
            try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("ms-settings:privacy-screenrecording") { UseShellExecute = true }); } catch { }
        }

        private void GrantDataConsent()
        {
            var key = _delegate.DataConsentKey;
            LocalSettings.SetBool(key, true);
            UpdateStatus();
        }

        public void UpdateStatus()
        {
            var hasAccessibility = CheckAccessibility();
            var hasScreenRecording = CheckScreenRecording();
            var hasDataConsent = LocalSettings.GetBool(_delegate.DataConsentKey);

            SetStatus(_accessibilityStatus, hasAccessibility);
            SetStatus(_screenRecordingStatus, hasScreenRecording);
            SetStatus(_dataConsentStatus, hasDataConsent);

            if (_panel != null)
            {
                _panel.Visibility = (hasAccessibility && hasScreenRecording && hasDataConsent) ? Visibility.Collapsed : Visibility.Visible;
            }
        }

        public void StartMonitoring()
        {
            _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _timer.Tick += (_, _) => UpdateStatus();
            _timer.Start();
        }

        public void StopMonitoring()
        {
            _timer?.Stop();
            _timer = null;
        }

        private static void SetStatus(TextBlock? label, bool enabled)
        {
            if (label == null) return;
            label.Text = enabled ? "Enabled" : "Required";
            label.Foreground = enabled ? Brushes.LightGreen : Brushes.Orange;
        }

        // Windows does not have direct equivalents for these macOS permissions.
        private static bool CheckAccessibility() => true;
        private static bool CheckScreenRecording() => true;
    }

    internal static class LocalSettings
    {
        private static readonly string FilePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".interview-master-settings.json");

        public static bool GetBool(string key)
        {
            var data = ReadAll();
            return data.TryGetValue(key, out var val) && val;
        }

        public static void SetBool(string key, bool value)
        {
            var data = ReadAll();
            data[key] = value;
            WriteAll(data);
        }

        private static Dictionary<string, bool> ReadAll()
        {
            try
            {
                if (!File.Exists(FilePath)) return new Dictionary<string, bool>();
                var json = File.ReadAllText(FilePath);
                return JsonSerializer.Deserialize<Dictionary<string, bool>>(json) ?? new Dictionary<string, bool>();
            }
            catch
            {
                return new Dictionary<string, bool>();
            }
        }

        private static void WriteAll(Dictionary<string, bool> data)
        {
            try
            {
                var json = JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(FilePath, json);
            }
            catch
            {
                // ignore persistence errors
            }
        }
    }
}

