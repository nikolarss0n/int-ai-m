using System;
using System.Collections.Generic;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using InterviewMasterApp.Domain.Entities;

namespace InterviewMasterApp.Presentation.Windows
{
    /// <summary>
    /// Screenshot alert window (WPF). Ported from ScreenshotAlertWindow.swift.
    /// </summary>
    public class ScreenshotAlertWindow
    {
        private const double AlertWidth = 400;
        private const double AlertHeight = 120;

        private Window? _window;
        private StackPanel? _thumbnailsContainer;

        public (Window window, Panel container)? CreateWindow()
        {
            var screen = SystemParameters.WorkArea;
            var x = screen.Right - AlertWidth - 20;
            var y = screen.Top + 20;

            var win = new StealthWindow
            {
                Width = AlertWidth,
                Height = AlertHeight,
                Left = x,
                Top = y,
                WindowStyle = WindowStyle.None,
                AllowsTransparency = true,
                Background = Brushes.Transparent,
                Topmost = true,
                ShowInTaskbar = false
            };

            var root = new Border
            {
                CornerRadius = new CornerRadius(16),
                Background = new SolidColorBrush(Color.FromArgb(240, 20, 20, 25)),
                BorderBrush = Brushes.MediumPurple,
                BorderThickness = new Thickness(2),
                Padding = new Thickness(10)
            };

            var grid = new Grid();
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

            var title = new TextBlock
            {
                Text = "Screenshot Captured",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 16,
                HorizontalAlignment = HorizontalAlignment.Center
            };
            Grid.SetRow(title, 0);
            grid.Children.Add(title);

            var shortcuts = new TextBlock
            {
                Text = "Show App / Analyze / Clear",
                Foreground = Brushes.LightGray,
                FontSize = 11,
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 2, 0, 6)
            };
            Grid.SetRow(shortcuts, 1);
            grid.Children.Add(shortcuts);

            var scroll = new ScrollViewer
            {
                HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
                VerticalScrollBarVisibility = ScrollBarVisibility.Disabled
            };

            _thumbnailsContainer = new StackPanel { Orientation = Orientation.Horizontal };
            scroll.Content = _thumbnailsContainer;

            Grid.SetRow(scroll, 2);
            grid.Children.Add(scroll);

            root.Child = grid;
            win.Content = root;

            _window = win;
            return (win, _thumbnailsContainer);
        }

        public bool IsVisible => _window?.IsVisible ?? false;

        public void Hide()
        {
            if (_window != null) Hide(_window);
        }

        public void Show(Window window)
        {
            if (window == null) return;
            window.Opacity = 0;
            window.Show();
            var anim = new DoubleAnimation(1.0, new Duration(TimeSpan.FromMilliseconds(250)));
            window.BeginAnimation(Window.OpacityProperty, anim);
        }

        public void Hide(Window window)
        {
            if (window == null) return;
            var anim = new DoubleAnimation(0.0, new Duration(TimeSpan.FromMilliseconds(200)));
            anim.Completed += (_, _) => window.Hide();
            window.BeginAnimation(Window.OpacityProperty, anim);
        }

        public void CreateThumbnails(IReadOnlyList<Screenshot> screenshots)
        {
            if (_thumbnailsContainer == null || screenshots == null) return;
            _thumbnailsContainer.Children.Clear();

            foreach (var shot in screenshots)
            {
                var img = new Image
                {
                    Width = 70,
                    Height = 40,
                    Margin = new Thickness(4, 0, 4, 0),
                    Stretch = Stretch.UniformToFill,
                    Source = ToBitmapImage(shot.ImageData)
                };
                _thumbnailsContainer.Children.Add(img);
            }
        }

        private static BitmapImage ToBitmapImage(byte[] data)
        {
            var image = new BitmapImage();
            using var mem = new MemoryStream(data);
            image.BeginInit();
            image.CacheOption = BitmapCacheOption.OnLoad;
            image.StreamSource = mem;
            image.EndInit();
            image.Freeze();
            return image;
        }
    }
}

