using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using InterviewMasterApp.Presentation.Styling;

namespace InterviewMasterApp.Presentation.Components
{
    public enum ActivityCapsuleMode
    {
        Hidden,
        Listening,
        Transcribing,
        Connecting,
        Muted,
        NoAudio
    }

    /// <summary>
    /// Header activity capsule with a 5-bar real-time dB audio level meter while listening.
    /// Keeps a constant width whether silent or speaking.
    /// </summary>
    public sealed class AIActivityCapsuleView : Border
    {
        private readonly List<Rectangle> _bars = new();
        private readonly TextBlock _label;
        private ActivityCapsuleMode _mode = ActivityCapsuleMode.Hidden;
        private static readonly double[] Multipliers = { 0.5, 0.85, 1.0, 0.85, 0.5 };

        public AIActivityCapsuleView()
        {
            Height = 28;
            CornerRadius = new CornerRadius(14);
            Padding = new Thickness(10, 0, 12, 0);
            VerticalAlignment = VerticalAlignment.Center;
            Visibility = Visibility.Collapsed;

            var row = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };

            var meterPanel = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 0, 8, 0),
                Height = 14
            };

            for (int i = 0; i < 5; i++)
            {
                var bar = new Rectangle
                {
                    Width = 2.5,
                    Height = 3,
                    RadiusX = 1.25,
                    RadiusY = 1.25,
                    Fill = DesignTokens.SuccessTextBrush,
                    VerticalAlignment = VerticalAlignment.Center,
                    Margin = new Thickness(1, 0, 1, 0)
                };
                _bars.Add(bar);
                meterPanel.Children.Add(bar);
            }

            _label = new TextBlock
            {
                FontSize = DesignTokens.FontSizes.Caption,
                FontWeight = FontWeights.Medium,
                VerticalAlignment = VerticalAlignment.Center
            };

            row.Children.Add(meterPanel);
            row.Children.Add(_label);
            Child = row;
        }

        public void SetMode(ActivityCapsuleMode mode)
        {
            if (_mode == mode) return;
            _mode = mode;

            if (mode == ActivityCapsuleMode.Hidden)
            {
                Visibility = Visibility.Collapsed;
                return;
            }

            Visibility = Visibility.Visible;
            (SolidColorBrush bg, SolidColorBrush fg, string text) = mode switch
            {
                ActivityCapsuleMode.Listening => (DesignTokens.SuccessWashBrush, DesignTokens.SuccessTextBrush, "Listening"),
                ActivityCapsuleMode.Transcribing => (DesignTokens.AccentWashBrush, DesignTokens.AccentTextBrush, "Transcribing…"),
                ActivityCapsuleMode.Connecting => (DesignTokens.WarningWashBrush, DesignTokens.WarningTextBrush, "Connecting audio…"),
                ActivityCapsuleMode.Muted => (DesignTokens.WarningWashBrush, DesignTokens.WarningTextBrush, "Muted"),
                ActivityCapsuleMode.NoAudio => (DesignTokens.DangerWashBrush, DesignTokens.DangerTextBrush, "No audio"),
                _ => (DesignTokens.BgWidgetBrush, DesignTokens.TextMutedBrush, string.Empty)
            };

            Background = bg;
            _label.Text = text;
            _label.Foreground = fg;
            ToolTip = text;
            foreach (var bar in _bars)
            {
                bar.Fill = fg;
                bar.Height = 3;
            }
        }

        public void SetLevel(float db, bool isSpeaking)
        {
            if (_mode != ActivityCapsuleMode.Listening) return;
            ToolTip = isSpeaking ? "Hearing speech" : "Listening";

            if (!SystemParameters.ClientAreaAnimation)
            {
                foreach (var bar in _bars) bar.Height = isSpeaking ? 9 : 3;
                return;
            }

            // Map -60dB..-10dB to 0..1
            var normalized = Math.Clamp((db + 60f) / 50f, 0f, 1f);
            for (int i = 0; i < _bars.Count; i++)
            {
                var h = 3.0 + normalized * 11.0 * Multipliers[i];
                _bars[i].Height = Math.Clamp(h, 3.0, 14.0);
            }
        }
    }
}
