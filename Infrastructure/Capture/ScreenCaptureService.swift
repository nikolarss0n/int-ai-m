import Foundation
import Cocoa
import ScreenCaptureKit

/// Infrastructure: Screen Capture Service
/// Handles screenshot capture using ScreenCaptureKit
class ScreenCaptureService {

    enum CaptureError: Error {
        case noDisplayFound
        case captureFailed(Error)
    }

    /// Capture a screenshot of the main display, excluding our own app windows
    func captureScreen() async -> Result<Screenshot, CaptureError> {
        StealthLogger.shared.log("🖥️ captureScreen() - requesting SCShareableContent...")
        do {
            // Use ScreenCaptureKit
            let content = try await SCShareableContent.current
            StealthLogger.shared.log("🖥️ Got shareable content - displays=\(content.displays.count), windows=\(content.windows.count)")

            guard let display = content.displays.first else {
                StealthLogger.shared.log("🖥️ ERROR: No display found")
                return .failure(.noDisplayFound)
            }
            StealthLogger.shared.log("🖥️ Display: \(display.width)x\(display.height)")

            // Exclude our own app's windows so the overlay doesn't appear in screenshots
            let myPID = ProcessInfo.processInfo.processIdentifier
            let ownWindows = content.windows.filter { $0.owningApplication?.processID == myPID }
            StealthLogger.shared.log("🖥️ Excluding \(ownWindows.count) own windows (PID=\(myPID))")

            // Configure capture
            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.scalesToFit = false

            // Capture screenshot
            StealthLogger.shared.log("🖥️ Calling SCScreenshotManager.captureImage()...")
            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            StealthLogger.shared.log("🖥️ captureImage() returned - \(cgImage.width)x\(cgImage.height)")

            // Convert to NSImage
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

            // Create Screenshot entity
            let screenshot = Screenshot(image: nsImage)
            StealthLogger.shared.log("🖥️ Screenshot created successfully - id=\(screenshot.id)")

            return .success(screenshot)

        } catch {
            StealthLogger.shared.log("🖥️ captureScreen() EXCEPTION: \(error)")
            return .failure(.captureFailed(error))
        }
    }
}
