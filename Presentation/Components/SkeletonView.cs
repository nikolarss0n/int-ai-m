using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using InterviewMasterApp.Presentation.Styling;

namespace InterviewMasterApp.Presentation.Components
{
    /// <summary>
    /// Skeleton loading placeholder shaped like upcoming answer bullets or code lines.
    /// Respects Windows reduced-motion setting (<see cref="SystemParameters.ClientAreaAnimation"/>).
    /// </summary>
    public sealed class SkeletonView : StackPanel
    {
        private readonly List<UIElement> _bars = new();

        public SkeletonView(bool codeShape = false)
        {
            Orientation = Orientation.Vertical;
            Margin = new Thickness(0, 6, 0, 6);

            if (codeShape)
            {
                AddBar(150, 12, 0, 10);
                AddBar(260, 9, 0, 12);
                AddBar(340, 10, 14, 7);
                AddBar(290, 10, 14, 7);
                AddBar(210, 10, 14, 0);
            }
            else
            {
                AddBulletRow(420);
                AddBulletRow(370);
                AddBulletRow(400);
                AddBulletRow(290);
            }
        }

        private void AddBulletRow(double width)
        {
            var row = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 12) };
            var dot = new Ellipse
            {
                Width = 6,
                Height = 6,
                Fill = DesignTokens.Brush(DesignTokens.Colors.BgSkeleton),
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 0, 10, 0)
            };
            var bar = new Border
            {
                Width = width,
                Height = 12,
                CornerRadius = new CornerRadius(6),
                Background = DesignTokens.Brush(DesignTokens.Colors.BgSkeleton),
                HorizontalAlignment = HorizontalAlignment.Left
            };
            row.Children.Add(dot);
            row.Children.Add(bar);
            Children.Add(row);
            _bars.Add(bar);
        }

        private void AddBar(double width, double height, double leftMargin, double bottomMargin)
        {
            var bar = new Border
            {
                Width = width,
                Height = height,
                CornerRadius = new CornerRadius(height / 2.0),
                Background = DesignTokens.Brush(DesignTokens.Colors.BgSkeleton),
                HorizontalAlignment = HorizontalAlignment.Left,
                Margin = new Thickness(leftMargin, 0, 0, bottomMargin)
            };
            Children.Add(bar);
            _bars.Add(bar);
        }

        public void StartShimmer()
        {
            if (!SystemParameters.ClientAreaAnimation) return;
            for (int i = 0; i < _bars.Count; i++)
            {
                var anim = new DoubleAnimation(0.45, 1.0, TimeSpan.FromMilliseconds(800))
                {
                    AutoReverse = true,
                    RepeatBehavior = RepeatBehavior.Forever,
                    BeginTime = TimeSpan.FromMilliseconds(i * 120)
                };
                _bars[i].BeginAnimation(OpacityProperty, anim);
            }
        }

        public void StopShimmer()
        {
            foreach (var bar in _bars)
            {
                bar.BeginAnimation(OpacityProperty, null);
                bar.Opacity = 1.0;
            }
        }
    }
}
