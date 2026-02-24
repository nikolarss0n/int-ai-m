using System.Windows;
using System.Windows.Controls;

namespace InterviewMasterApp.Presentation.Components
{
    /// <summary>
    /// Flipped view where Y=0 is at the top (like iOS). For WPF, set a panel with Top-to-Bottom layout.
    /// This class is a marker; actual layout behavior should be implemented in the container control.
    /// </summary>
    public class FlippedView : Panel
    {
        protected override Size MeasureOverride(Size availableSize)
        {
            foreach (UIElement child in InternalChildren)
            {
                child.Measure(availableSize);
            }
            return base.MeasureOverride(availableSize);
        }

        protected override Size ArrangeOverride(Size finalSize)
        {
            double y = 0;
            foreach (UIElement child in InternalChildren)
            {
                var desired = child.DesiredSize;
                child.Arrange(new Rect(0, y, finalSize.Width, desired.Height));
                y += desired.Height; // next child below
            }
            return finalSize;
        }
    }
}

