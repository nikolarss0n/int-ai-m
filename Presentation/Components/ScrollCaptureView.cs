using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace InterviewMasterApp.Presentation.Components
{
    /// <summary>
    /// Port of ScrollCaptureView.swift — a WPF control that captures scroll events
    /// and forwards them to an inner ScrollViewer if present.
    /// </summary>
    public class ScrollCaptureView : ContentControl
    {
        public ScrollViewer? ScrollViewer { get; set; }

        protected override void OnMouseWheel(MouseWheelEventArgs e)
        {
            if (ScrollViewer != null)
            {
                var args = new MouseWheelEventArgs(e.MouseDevice, e.Timestamp, e.Delta)
                {
                    RoutedEvent = MouseWheelEvent,
                    Source = e.Source
                };
                ScrollViewer.RaiseEvent(args);
                e.Handled = true;
            }
            else
            {
                base.OnMouseWheel(e);
            }
        }

        protected override HitTestResult? HitTestCore(PointHitTestParameters hitTestParameters)
        {
            if (!IsVisible) return null;
            var pt = hitTestParameters.HitPoint;
            if (new Rect(new Point(0, 0), RenderSize).Contains(pt))
            {
                return new PointHitTestResult(this, pt);
            }
            return null;
        }
    }
}

