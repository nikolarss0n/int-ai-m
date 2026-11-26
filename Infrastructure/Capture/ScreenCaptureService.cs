using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
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
        public Screenshot? Screenshot { get; }
        public CaptureError Error { get; }
        public string? ErrorMessage { get; }

        private ScreenCaptureResult(Screenshot screenshot)
        {
            IsSuccess = true;
            Screenshot = screenshot;
            Error = CaptureError.None;
        }

        private ScreenCaptureResult(CaptureError error, string? message = null)
        {
            IsSuccess = false;
            Error = error;
            ErrorMessage = message;
        }

        public static ScreenCaptureResult Success(Screenshot s) => new(s);
        public static ScreenCaptureResult Failure(CaptureError error, string? msg = null) => new(error, msg);
    }

    /// <summary>
    /// DPI-aware Windows screen capture service supporting the active cursor monitor (multi-monitor aware)
    /// and registering high-quality PNG thumbnail generation on <see cref="Screenshot.ThumbnailGenerator"/>.
    /// </summary>
    public class ScreenCaptureService : IScreenCaptureService
    {
        static ScreenCaptureService()
        {
            Screenshot.ThumbnailGenerator = GeneratePngThumbnail;
        }

        public static byte[] GeneratePngThumbnail(byte[] pngBytes, int maxWidth, int maxHeight)
        {
            using var inputStream = new MemoryStream(pngBytes);
            using var original = Image.FromStream(inputStream);
            var ratioX = (double)maxWidth / original.Width;
            var ratioY = (double)maxHeight / original.Height;
            var ratio = Math.Min(1.0, Math.Min(ratioX, ratioY));
            var targetW = Math.Max(1, (int)Math.Round(original.Width * ratio));
            var targetH = Math.Max(1, (int)Math.Round(original.Height * ratio));

            using var thumb = new Bitmap(targetW, targetH, PixelFormat.Format32bppArgb);
            using var g = Graphics.FromImage(thumb);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.SmoothingMode = SmoothingMode.HighQuality;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.DrawImage(original, 0, 0, targetW, targetH);

            using var outStream = new MemoryStream();
            thumb.Save(outStream, ImageFormat.Png);
            return outStream.ToArray();
        }

        public Task<ScreenCaptureResult> CaptureScreenAsync()
        {
            return Task.Run(() =>
            {
                try
                {
                    // Capture the monitor currently under the cursor (falls back to PrimaryScreen).
                    // Because app.manifest sets PerMonitorV2 DPI awareness, Bounds are physical pixels.
                    var screen = Screen.FromPoint(Cursor.Position) ?? Screen.PrimaryScreen;
                    if (screen == null)
                        return ScreenCaptureResult.Failure(CaptureError.NoDisplayFound, "No display found");

                    var bounds = screen.Bounds;
                    using var bitmap = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format32bppArgb);
                    using var g = Graphics.FromImage(bitmap);
                    g.CopyFromScreen(bounds.X, bounds.Y, 0, 0, bounds.Size, CopyPixelOperation.SourceCopy);

                    using var ms = new MemoryStream();
                    bitmap.Save(ms, ImageFormat.Png);
                    var screenshot = new Screenshot(ms.ToArray());
                    return ScreenCaptureResult.Success(screenshot);
                }
                catch (Exception ex)
                {
                    return ScreenCaptureResult.Failure(CaptureError.CaptureFailed, ex.Message);
                }
            });
        }
    }
}
