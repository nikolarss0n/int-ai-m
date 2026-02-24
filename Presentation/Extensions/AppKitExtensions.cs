using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Input;

namespace InterviewMasterApp.Presentation.Extensions
{
    /// <summary>
    /// Windows-friendly equivalents for a few small AppKit extensions used by the macOS code.
    /// - Color constants (Apple HIG and Claude brand colors)
    /// - UI helpers: AddDropShadow, AddGlassEffect
    /// - Button hover helper
    /// - Small PathGeometry helper to create simple paths from points
    ///
    /// Note: These are pragmatic ports for WPF/WinUI usage. If you target WinUI 3, some types
    /// (DropShadowEffect / BlurEffect) will differ; tell me and I will produce a WinUI variant.
    /// </summary>
    public static class AppColors
    {
        // Apple HIG Colors
        public static Color AppleGreen => Color.FromRgb(52, 199, 89);
        public static SolidColorBrush AppleGreenBrush => new SolidColorBrush(AppleGreen);

        public static Color AppleRed => Color.FromRgb(255, 59, 48);
        public static SolidColorBrush AppleRedBrush => new SolidColorBrush(AppleRed);

        public static Color ApplePurple => Color.FromRgb(175, 82, 222);
        public static SolidColorBrush ApplePurpleBrush => new SolidColorBrush(ApplePurple);

        public static Color AppleGold => Color.FromRgb(255, 214, 0);
        public static SolidColorBrush AppleGoldBrush => new SolidColorBrush(AppleGold);

        // Claude brand colors (approx)
        public static Color ClaudeCoral => Color.FromRgb(0xD9, 0x77, 0x57);
        public static SolidColorBrush ClaudeCoralBrush => new SolidColorBrush(ClaudeCoral);

        public static Color ClaudeOrange => Color.FromRgb(0xE9, 0x8B, 0x65);
        public static SolidColorBrush ClaudeOrangeBrush => new SolidColorBrush(ClaudeOrange);

        public static Color ClaudePeach => Color.FromRgb(0xF4, 0xA4, 0x86);
        public static SolidColorBrush ClaudePeachBrush => new SolidColorBrush(ClaudePeach);

        public static Color ClaudeSand => Color.FromRgb(0xE0, 0xB2, 0x90);
        public static SolidColorBrush ClaudeSandBrush => new SolidColorBrush(ClaudeSand);
    }

    public static class UIElementExtensions
    {
        /// <summary>
        /// Add a subtle drop shadow to a FrameworkElement (WPF). For WinUI use an Acrylic/DropShadowBrush.
        /// </summary>
        public static void AddDropShadow(this FrameworkElement element, double opacity = 0.3, double radius = 8, double offsetY = -2)
        {
            if (element == null) return;

            var ds = new DropShadowEffect
            {
                Color = Colors.Black,
                Opacity = Math.Max(0, Math.Min(1, opacity)),
                BlurRadius = radius,
                ShadowDepth = Math.Abs(offsetY),
                Direction = offsetY < 0 ? 270 : 90
            };

            // If there is already an effect, wrap or replace - here we replace
            element.Effect = ds;
        }

        /// <summary>
        /// Add a simple glass-like blur effect. On WPF this uses a semi-transparent background + BlurEffect.
        /// For a better native look on newer Windows versions use WinUI Acrylic or Windows Composition APIs.
        /// </summary>
        public static void AddGlassEffect(this Control control)
        {
            if (control == null) return;

            // Semi-transparent background
            control.Background = new SolidColorBrush(Color.FromArgb(180, 255, 255, 255));

            try
            {
                // Apply a subtle blur. Note: BlurEffect may be expensive.
                control.Effect = new BlurEffect { Radius = 6 };
            }
            catch
            {
                // Ignore if BlurEffect not available in the target framework
            }
        }
    }

    public static class ButtonExtensions
    {
        /// <summary>
        /// Add a simple hover effect to a Button: stores original background and border brush and
        /// swaps brushes on mouse enter/leave. Call once at initialization time.
        /// </summary>
        public static void AddHoverEffect(this Button button)
        {
            if (button == null) return;

            var originalBackground = button.Background;
            var originalBorder = button.BorderBrush;

            // Use light opacity changes if specific brushes aren't set
            button.MouseEnter += (s, e) =>
            {
                try
                {
                    if (button.Background is SolidColorBrush bg)
                    {
                        var c = bg.Color;
                        button.Background = new SolidColorBrush(Color.FromArgb(255, (byte)Math.Min(255, c.R + 10), (byte)Math.Min(255, c.G + 10), (byte)Math.Min(255, c.B + 10)));
                    }
                    else
                    {
                        button.Opacity = 0.95;
                    }
                }
                catch { }
            };

            button.MouseLeave += (s, e) =>
            {
                try
                {
                    button.Background = originalBackground;
                    button.BorderBrush = originalBorder;
                    button.Opacity = 1.0;
                }
                catch { }
            };
        }
    }

    public static class PathHelpers
    {
        /// <summary>
        /// Create a PathGeometry from a sequence of points. Simple helper similar in spirit to converting
        /// an NSBezierPath to a CGPath on macOS. This supports straight lines; for curves provide segments explicitly.
        /// </summary>
        public static PathGeometry CreatePathGeometryFromPoints(IEnumerable<Point> points, bool closed = false)
        {
            var pts = points?.ToList() ?? new List<Point>();
            var geometry = new PathGeometry();
            if (!pts.Any()) return geometry;

            var figure = new PathFigure { StartPoint = pts[0], IsClosed = closed, IsFilled = false };
            if (pts.Count > 1)
            {
                var segments = new PolyLineSegment();
                for (int i = 1; i < pts.Count; i++) segments.Points.Add(pts[i]);
                figure.Segments.Add(segments);
            }

            geometry.Figures.Add(figure);
            return geometry;
        }
    }
}

