using System;

namespace InterviewMasterApp.Domain.Entities
{
    /// <summary>
    /// Domain Entity: Screenshot.
    /// Keeps Domain free of UI/GDI+ dependencies by allowing Infrastructure/Presentation
    /// to register a real image resizer via <see cref="ThumbnailGenerator"/>.
    /// </summary>
    public class Screenshot
    {
        /// <summary>
        /// Platform hook registered by Infrastructure (e.g. GDI+/WPF resizer) to produce PNG thumbnails.
        /// </summary>
        public static Func<byte[], int, int, byte[]>? ThumbnailGenerator { get; set; }

        public Guid Id { get; }
        public byte[] ImageData { get; }
        public DateTime CapturedAt { get; }

        public Screenshot(byte[] imageData, Guid? id = null, DateTime? capturedAt = null)
        {
            ImageData = imageData ?? throw new ArgumentNullException(nameof(imageData));
            Id = id ?? Guid.NewGuid();
            CapturedAt = capturedAt ?? DateTime.UtcNow;
        }

        public double SizeInKb => ImageData.Length / 1024.0;

        public byte[] GenerateThumbnail(int maxWidth = 320, int maxHeight = 240)
        {
            if (ImageData.Length == 0) return ImageData;
            var generator = ThumbnailGenerator;
            if (generator != null)
            {
                try
                {
                    var resized = generator(ImageData, maxWidth, maxHeight);
                    if (resized != null && resized.Length > 0) return resized;
                }
                catch
                {
                    // Fall back to original image bytes
                }
            }
            return ImageData;
        }

        public string ToBase64() => Convert.ToBase64String(ImageData);

        public override bool Equals(object? obj) => obj is Screenshot other && Id == other.Id;
        public override int GetHashCode() => Id.GetHashCode();
        public override string ToString() => $"Screenshot(ID={Id}, Size={SizeInKb:F1}KB, CapturedAt={CapturedAt:g})";
    }
}
