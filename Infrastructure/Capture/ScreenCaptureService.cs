using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;
using InterviewMasterApp.Domain.Entities;

namespace InterviewMasterApp.Infrastructure.Capture
{
    public enum CaptureError
    {
        None,
        NoDisplayFound,
        CaptureFailed
    }

    public class ScreenCaptureResult
    {
        public bool IsSuccess { get; }
        public Screenshot Screenshot { get; }
        public CaptureError Error { get; }
        public string ErrorMessage { get; }

        private ScreenCaptureResult(Screenshot screenshot)
        {
            IsSuccess = true;
            Screenshot = screenshot;
            Error = CaptureError.None;
        }

        private ScreenCaptureResult(CaptureError error, string message = null)
        {
            IsSuccess = false;
            Error = error;
            ErrorMessage = message;
        }

        public static ScreenCaptureResult Success(Screenshot s) => new ScreenCaptureResult(s);
        public static ScreenCaptureResult Failure(CaptureError error, string msg = null) => new ScreenCaptureResult(error, msg);
    }

    /// <summary>
    /// Windows implementation that captures the primary screen using GDI+ (System.Drawing)
    /// Note: excludes app windows behavior is not implemented (requires window enumeration & composition APIs).
    /// </summary>
    public class ScreenCaptureService : IScreenCaptureService
    {
        public async Task<ScreenCaptureResult> CaptureScreenAsync()
        {
            try
            {
                var primary = Screen.PrimaryScreen;
                if (primary == null)
                    return ScreenCaptureResult.Failure(CaptureError.NoDisplayFound, "No primary display found");

                var bounds = primary.Bounds;
                using var bitmap = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format32bppArgb);
                using var g = Graphics.FromImage(bitmap);
                g.CopyFromScreen(bounds.X, bounds.Y, 0, 0, bounds.Size, CopyPixelOperation.SourceCopy);

                // Convert to PNG byte array
                using var ms = new MemoryStream();
                bitmap.Save(ms, ImageFormat.Png);
                var bytes = ms.ToArray();

                var screenshot = new InterviewMasterApp.Domain.Entities.Screenshot(bytes);
                return ScreenCaptureResult.Success(screenshot);
            }
            catch (Exception ex)
            {
                return ScreenCaptureResult.Failure(CaptureError.CaptureFailed, ex.Message);
            }
        }
    }
}

