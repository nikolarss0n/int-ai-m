using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;

namespace InterviewMasterApp.Presentation.Windows
{
    public interface IPermissionsPanelDelegate
    {
        string DataConsentKey { get; }
    }

    /// <summary>
    /// Permissions panel controller sharing unified consent storage with <see cref="ScreenshotManager"/>.
    /// </summary>
    public class PermissionsPanelController
    {
        private readonly IPermissionsPanelDelegate _delegate;
        private Border? _panel;
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
                Width = 520,
                Background = new SolidColorBrush(Color.FromArgb(245, 25, 25, 30)),
                CornerRadius = new CornerRadius(18),
                BorderBrush = Brushes.Gold,
                BorderThickness = new Thickness(1.5),
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                Padding = new Thickness(20)
            };

            var stack = new StackPanel();
            stack.Children.Add(new TextBlock
            {
                Text = "Setup",
                Foreground = Brushes.White,
                FontSize = 20,
                FontWeight = FontWeights.SemiBold,
                HorizontalAlignment = HorizontalAlignment.Center
            });

            var row = new DockPanel { Margin = new Thickness(0, 14, 0, 8) };
            var btn = new Button { Content = "I Consent", Padding = new Thickness(12, 4, 12, 4) };
            btn.Click += (_, _) => { ScreenshotManager.SetDataConsent(true); UpdateStatus(); };
            DockPanel.SetDock(btn, Dock.Right);

            _dataConsentStatus = new TextBlock
            {
                Text = "Required",
                Foreground = Brushes.Orange,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 0, 10, 0)
            };
            DockPanel.SetDock(_dataConsentStatus, Dock.Right);

            row.Children.Add(btn);
            row.Children.Add(_dataConsentStatus);
            row.Children.Add(new TextBlock
            {
                Text = "AI Screenshot Analysis Consent",
                Foreground = Brushes.White,
                VerticalAlignment = VerticalAlignment.Center
            });

            stack.Children.Add(row);
            panel.Child = stack;
            parent.Children.Add(panel);
            _panel = panel;

            UpdateStatus();
            StartMonitoring();
        }

        public void UpdateStatus()
        {
            var consented = ScreenshotManager.GetDataConsent();
            if (_dataConsentStatus != null)
            {
                _dataConsentStatus.Text = consented ? "Enabled" : "Required";
                _dataConsentStatus.Foreground = consented ? Brushes.LightGreen : Brushes.Orange;
            }
            if (_panel != null)
                _panel.Visibility = consented ? Visibility.Collapsed : Visibility.Visible;
        }

        public void StartMonitoring()
        {
            _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
            _timer.Tick += (_, _) => UpdateStatus();
            _timer.Start();
        }

        public void StopMonitoring()
        {
            _timer?.Stop();
            _timer = null;
        }
    }
}
