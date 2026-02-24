using System;
using System.Collections.Generic;

namespace InterviewMasterApp.Domain.Entities
{
    /// <summary>
    /// Domain Entity: Screenshot
    /// Represents a captured screenshot with metadata.
    /// Migrated from Swift: Screenshot.swift
    /// </summary>
    public class Screenshot
    {
        public Guid Id { get; }
        public byte[] ImageData { get; }  // PNG or JPEG bytes (Windows equivalent of NSImage)
        public DateTime CapturedAt { get; }

        /// <summary>
        /// Initialize a screenshot.
        /// </summary>
        public Screenshot(byte[] imageData, Guid? id = null, DateTime? capturedAt = null)
        {
            ImageData = imageData ?? throw new ArgumentNullException(nameof(imageData));
            Id = id ?? Guid.NewGuid();
            CapturedAt = capturedAt ?? DateTime.UtcNow;
        }

        /// <summary>
        /// Size of image data in KB.
        /// </summary>
        public double SizeInKb => ImageData.Length / 1024.0;

        /// <summary>
        /// Generate a thumbnail from the screenshot.
        /// </summary>
        /// <param name="maxWidth">Maximum width in pixels</param>
        /// <param name="maxHeight">Maximum height in pixels</param>
        /// <returns>Thumbnail image data</returns>
        public byte[] GenerateThumbnail(int maxWidth = 320, int maxHeight = 240)
        {
            // TODO: Implement image thumbnail generation using System.Drawing or Windows.Graphics
            // This requires image processing libraries:
            // Option 1: System.Drawing.Common (legacy)
            // Option 2: Windows.Graphics.Imaging (Windows-native)
            // For now, return placeholder
            return ImageData;
        }

        /// <summary>
        /// Convert image to base64 encoded string.
        /// </summary>
        public string ToBase64()
        {
            return Convert.ToBase64String(ImageData);
        }

        // MARK: - Equality

        /// <summary>
        /// Two screenshots are equal if they have the same ID.
        /// </summary>
        public override bool Equals(object? obj)
        {
            return obj is Screenshot other && Id == other.Id;
        }

        /// <summary>
        /// Hash based on ID.
        /// </summary>
        public override int GetHashCode()
        {
            return Id.GetHashCode();
        }

        /// <summary>
        /// Identifiable equivalent.
        /// </summary>
        public override string ToString()
        {
            return $"Screenshot(ID={Id}, Size={SizeInKb:F1}KB, CapturedAt={CapturedAt:g})";
        }
    }
}
