using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Input;
using System.Windows;
using System.Windows.Media.Animation;

namespace InterviewMasterApp.Presentation.Components
{
    /// <summary>
    /// Port of HoverButton.swift — WPF/WinUI-idiomatic hoverable button.
    /// This simple implementation exposes hover/press brushes and basic animations.
    /// For WinUI, consider adapting VisualStateManager instead.
    /// </summary>
    public class HoverButton : Button
    {
        public Brush NormalBackground { get; set; } = Brushes.Transparent;
        public Brush HoverBackground { get; set; } = Brushes.Transparent;
        public Brush PressBackground { get; set; } = Brushes.Transparent;
        public Brush NormalBorder { get; set; } = Brushes.Transparent;
        public Brush HoverBorder { get; set; } = Brushes.Transparent;

        private bool _isHovered = false;

        protected override void OnMouseEnter(MouseEventArgs e)
        {
            base.OnMouseEnter(e);
            _isHovered = true;
            AnimateToHoverState();
        }

        protected override void OnMouseLeave(MouseEventArgs e)
        {
            base.OnMouseLeave(e);
            _isHovered = false;
            AnimateToNormalState();
        }

        protected override void OnPreviewMouseLeftButtonDown(MouseButtonEventArgs e)
        {
            base.OnPreviewMouseLeftButtonDown(e);
            AnimateToPressState();
        }

        protected override void OnPreviewMouseLeftButtonUp(MouseButtonEventArgs e)
        {
            base.OnPreviewMouseLeftButtonUp(e);
            if (_isHovered) AnimateToHoverState(); else AnimateToNormalState();
        }

        private void AnimateToHoverState()
        {
            Background = HoverBackground;
            BorderBrush = HoverBorder;
            var scale = new ScaleTransform(1.02, 1.02);
            RenderTransform = scale;
        }

        private void AnimateToNormalState()
        {
            Background = NormalBackground;
            BorderBrush = NormalBorder;
            RenderTransform = Transform.Identity;
        }

        private void AnimateToPressState()
        {
            Background = PressBackground;
            var scale = new ScaleTransform(0.97, 0.97);
            RenderTransform = scale;
        }

        public void ConfigureHoverColors(Color accent)
        {
            // Simple mapping to brushes
            NormalBackground = new SolidColorBrush(Color.FromArgb(38, accent.R, accent.G, accent.B));
            HoverBackground = new SolidColorBrush(Color.FromArgb(64, accent.R, accent.G, accent.B));
            PressBackground = new SolidColorBrush(Color.FromArgb(90, accent.R, accent.G, accent.B));
            NormalBorder = new SolidColorBrush(Color.FromArgb(77, accent.R, accent.G, accent.B));
            HoverBorder = new SolidColorBrush(Color.FromArgb(128, accent.R, accent.G, accent.B));

            Background = NormalBackground;
            BorderBrush = NormalBorder;
        }
    }
}

