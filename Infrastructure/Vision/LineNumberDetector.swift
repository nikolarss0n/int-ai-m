import Cocoa
import Vision
import CoreGraphics
import ScreenCaptureKit

/// Detects all code lines in editor windows using Vision OCR
/// Returns exact screen coordinates and right edge for each detected line
@available(macOS 13.0, *)
class LineNumberDetector {

    struct DetectedCodeLine {
        let index: Int            // Line index (0-based from top of visible area)
        let lineNumber: Int?      // Actual line number from gutter (if detected)
        let screenY: CGFloat      // Y coordinate in screen space (NS coordinates)
        let rightEdgeX: CGFloat   // X position where this line's code ends
        let text: String          // The actual text content of this line
    }

    struct DetectionResult {
        let lines: [DetectedCodeLine]
        let estimatedLineHeight: CGFloat
        let windowBounds: CGRect
    }

    /// Simple OCR result for screenshot analysis (no screen coordinates needed)
    struct OCRLine {
        let lineNumber: Int       // 1-based line number
        let text: String          // The text content
    }

    /// Detect code lines from an NSImage (for screenshot analysis)
    /// Returns lines with line numbers for use as Claude context
    func detectLinesFromImage(_ image: NSImage) async -> [OCRLine] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            debugLog("❌ LineDetector: Failed to get CGImage from NSImage")
            return []
        }

        return await detectLinesFromCGImage(cgImage)
    }

    /// Core OCR detection from CGImage
    private func detectLinesFromCGImage(_ image: CGImage) async -> [OCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        // Use Revision 3 (latest stable revision)
        request.revision = VNRecognizeTextRequestRevision3
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            debugLog("❌ LineDetector: Vision request failed: \(error)")
            return []
        }

        guard let observations = request.results else {
            return []
        }

        // Group text by Y position to form lines
        struct TextBlock {
            let midY: CGFloat
            let minX: CGFloat
            let text: String
        }

        var gutterNumbers: [(lineNum: Int, midY: CGFloat)] = []
        var codeBlocks: [TextBlock] = []
        let lineNumberPattern = try! NSRegularExpression(pattern: "^\\d{1,5}$")

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespaces)
            let bbox = observation.boundingBox

            // Vision coords: midY=1.0 is TOP, midY=0.0 is BOTTOM
            // Skip top 15% (tab bar, title) and bottom 5% (status bar)
            guard bbox.midY < 0.85 && bbox.midY > 0.05 else { continue }

            // Check for line number in gutter (wider detection area)
            if bbox.minX < 0.08 && bbox.maxX < 0.12 {
                let range = NSRange(text.startIndex..., in: text)
                if lineNumberPattern.firstMatch(in: text, range: range) != nil,
                   let num = Int(text) {
                    gutterNumbers.append((num, bbox.midY))
                }
            }
            // Code content - filter out UI elements
            else if bbox.minX > 0.05 && bbox.minX < 0.75 && bbox.width > 0.03 {
                let isLikelyCode = text.count > 3 &&
                    !text.hasSuffix(".ts") && !text.hasSuffix(".js") &&
                    !text.hasSuffix(".swift") && !text.hasSuffix(".py")
                if isLikelyCode {
                    codeBlocks.append(TextBlock(midY: bbox.midY, minX: bbox.minX, text: text))
                }
            }
        }

        // Cluster into lines
        let yTolerance: CGFloat = 0.02
        var linesClusters: [[TextBlock]] = []

        for block in codeBlocks {
            var foundLine = false
            for i in 0..<linesClusters.count {
                if let first = linesClusters[i].first, abs(first.midY - block.midY) < yTolerance {
                    linesClusters[i].append(block)
                    foundLine = true
                    break
                }
            }
            if !foundLine {
                linesClusters.append([block])
            }
        }

        // Build OCR lines sorted by Y (top to bottom)
        var ocrLines: [(y: CGFloat, text: String, lineNum: Int?)] = []

        for cluster in linesClusters {
            guard !cluster.isEmpty else { continue }

            let avgY = cluster.map { $0.midY }.reduce(0, +) / CGFloat(cluster.count)
            let sorted = cluster.sorted { $0.minX < $1.minX }
            let lineText = sorted.map { $0.text }.joined(separator: " ")

            // Match to gutter line number
            var matchedLineNum: Int? = nil
            for gutter in gutterNumbers {
                if abs(gutter.midY - avgY) < yTolerance {
                    matchedLineNum = gutter.lineNum
                    break
                }
            }

            ocrLines.append((avgY, lineText, matchedLineNum))
        }

        // Sort by Y (higher Y = top of image)
        ocrLines.sort { $0.y > $1.y }

        // Assign sequential line numbers if not detected from gutter
        var result: [OCRLine] = []
        for (index, line) in ocrLines.enumerated() {
            let lineNum = line.lineNum ?? (index + 1)
            if !line.text.trimmingCharacters(in: .whitespaces).isEmpty {
                result.append(OCRLine(lineNumber: lineNum, text: line.text))
            }
        }

        debugLog("✅ LineDetector: OCR found \(result.count) lines from image")
        return result
    }

    /// Detect all code lines in a specific window
    func detectCodeLines(windowID: CGWindowID, windowBounds: CGRect) async -> DetectionResult? {
        guard let windowImage = await captureWindow(windowID: windowID) else {
            debugLog("❌ LineDetector: Failed to capture window")
            return nil
        }

        debugLog("📸 LineDetector: Captured \(windowImage.width)x\(windowImage.height) image")

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate  // Best quality OCR for code
        request.usesLanguageCorrection = false  // Don't autocorrect code
        request.recognitionLanguages = ["en-US"]

        // Use Revision 3 (latest stable revision for text recognition)
        request.revision = VNRecognizeTextRequestRevision3
        request.automaticallyDetectsLanguage = true  // Better accuracy

        let handler = VNImageRequestHandler(cgImage: windowImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            debugLog("❌ LineDetector: Vision request failed: \(error)")
            return nil
        }

        guard let observations = request.results else {
            debugLog("❌ LineDetector: No results from Vision")
            return nil
        }

        debugLog("🔍 LineDetector: Found \(observations.count) text observations")

        // Log first 10 raw observations for debugging
        for (i, obs) in observations.prefix(10).enumerated() {
            if let candidate = obs.topCandidates(1).first {
                let bbox = obs.boundingBox
                debugLog("   Raw[\(i)]: '\(candidate.string.prefix(30))' bbox=(x:\(String(format:"%.2f", bbox.minX))-\(String(format:"%.2f", bbox.maxX)), y:\(String(format:"%.2f", bbox.minY))-\(String(format:"%.2f", bbox.maxY)))")
            }
        }
        if observations.count > 10 {
            debugLog("   ... and \(observations.count - 10) more observations")
        }

        // Separate line numbers (gutter) from code content
        struct TextBlock {
            let midY: CGFloat
            let maxX: CGFloat
            let minX: CGFloat
            let text: String
        }

        var gutterNumbers: [(lineNum: Int, midY: CGFloat)] = []
        var codeBlocks: [TextBlock] = []
        let lineNumberPattern = try! NSRegularExpression(pattern: "^\\d{1,5}$")

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespaces)
            let bbox = observation.boundingBox

            // Vision coords: midY=1.0 is TOP, midY=0.0 is BOTTOM
            // Skip top 15% (tab bar, title) and bottom 5% (status bar)
            guard bbox.midY < 0.85 && bbox.midY > 0.05 else { continue }

            // Check if this is a line number in the gutter (far left, digits only)
            if bbox.minX < 0.08 && bbox.maxX < 0.12 {
                let range = NSRange(text.startIndex..., in: text)
                if lineNumberPattern.firstMatch(in: text, range: range) != nil,
                   let num = Int(text) {
                    gutterNumbers.append((num, bbox.midY))
                }
            }
            // Code content: must be in code area, have reasonable length
            else if bbox.minX > 0.05 && bbox.minX < 0.75 && bbox.width > 0.03 {
                // Skip UI-like text (too short, file extensions, etc.)
                let isLikelyCode = text.count > 3 &&
                    !text.hasSuffix(".ts") && !text.hasSuffix(".js") &&
                    !text.hasSuffix(".swift") && !text.hasSuffix(".py") &&
                    !text.hasPrefix("File") && !text.hasPrefix("Edit") &&
                    !text.hasPrefix("View") && !text.hasPrefix("Go") &&
                    !text.hasPrefix("Run") && !text.hasPrefix("Terminal")

                if isLikelyCode {
                    codeBlocks.append(TextBlock(midY: bbox.midY, maxX: bbox.maxX, minX: bbox.minX, text: text))
                }
            }
        }

        debugLog("  📊 Found \(gutterNumbers.count) line numbers, \(codeBlocks.count) code blocks")

        // Cluster code blocks into lines
        let yTolerance: CGFloat = 0.02
        var linesClusters: [[TextBlock]] = []

        for block in codeBlocks {
            var foundLine = false
            for i in 0..<linesClusters.count {
                if let first = linesClusters[i].first, abs(first.midY - block.midY) < yTolerance {
                    linesClusters[i].append(block)
                    foundLine = true
                    break
                }
            }
            if !foundLine {
                linesClusters.append([block])
            }
        }

        // Build detected lines with line numbers matched by Y position
        var detectedLines: [DetectedCodeLine] = []

        for cluster in linesClusters {
            guard !cluster.isEmpty else { continue }

            let avgY = cluster.map { $0.midY }.reduce(0, +) / CGFloat(cluster.count)
            let maxX = cluster.map { $0.maxX }.max() ?? 0.5

            // Combine text from all blocks on this line
            let lineText = cluster.map { $0.text }.joined(separator: " ")

            // Find matching line number from gutter
            var matchedLineNum: Int? = nil
            for gutter in gutterNumbers {
                if abs(gutter.midY - avgY) < yTolerance {
                    matchedLineNum = gutter.lineNum
                    break
                }
            }

            let screenY = windowBounds.minY + (avgY * windowBounds.height)
            let rightEdgeX = windowBounds.minX + (maxX * windowBounds.width) + 30

            detectedLines.append(DetectedCodeLine(
                index: 0,
                lineNumber: matchedLineNum,
                screenY: screenY,
                rightEdgeX: rightEdgeX,
                text: lineText
            ))
        }

        // Sort by Y (top to bottom = higher Y first in NS coords)
        detectedLines.sort { $0.screenY > $1.screenY }

        // Assign indices
        detectedLines = detectedLines.enumerated().map { idx, line in
            DetectedCodeLine(index: idx, lineNumber: line.lineNumber, screenY: line.screenY, rightEdgeX: line.rightEdgeX, text: line.text)
        }

        // Estimate line height
        var lineHeight: CGFloat = 20
        if detectedLines.count >= 2 {
            var heights: [CGFloat] = []
            for i in 1..<detectedLines.count {
                let h = abs(detectedLines[i-1].screenY - detectedLines[i].screenY)
                if h > 5 && h < 50 { heights.append(h) }
            }
            if !heights.isEmpty {
                lineHeight = heights.reduce(0, +) / CGFloat(heights.count)
            }
        }

        debugLog("✅ LineDetector: \(detectedLines.count) lines, \(gutterNumbers.count) with line numbers")

        return DetectionResult(lines: detectedLines, estimatedLineHeight: lineHeight, windowBounds: windowBounds)
    }

    private func captureWindow(windowID: CGWindowID) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let targetWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                debugLog("❌ LineDetector: Window \(windowID) not found")
                return nil
            }

            let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
            let config = SCStreamConfiguration()
            // Capture at 2x resolution for better OCR accuracy
            let scale: CGFloat = 2.0
            config.width = Int(targetWindow.frame.width * scale)
            config.height = Int(targetWindow.frame.height * scale)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            debugLog("❌ LineDetector: ScreenCaptureKit failed: \(error)")
            return nil
        }
    }

    func findTargetWindow() -> (windowID: CGWindowID, bounds: CGRect, appName: String)? {
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let targetApps = ["Code", "Visual Studio Code", "Google Chrome", "Safari", "Firefox", "Brave Browser", "Arc", "Cursor", "WezTerm", "iTerm", "Terminal"]

        debugLog("🪟 LineDetector: Searching \(windowList.count) windows for target apps: \(targetApps.joined(separator: ", "))")

        // Log first 10 windows for debugging
        var windowsLogged = 0
        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = window[kCGWindowLayer as String] as? Int else { continue }

            let x = bounds["X"] ?? 0, y = bounds["Y"] ?? 0
            let w = bounds["Width"] ?? 0, h = bounds["Height"] ?? 0

            if windowsLogged < 10 {
                debugLog("   Window: '\(ownerName)' layer=\(layer) size=\(Int(w))x\(Int(h))")
                windowsLogged += 1
            }

            guard layer == 0 else { continue }
            guard w > 400 && h > 300 else { continue }
            guard targetApps.contains(where: { ownerName.localizedCaseInsensitiveContains($0) }) else { continue }

            guard let screen = NSScreen.main else { continue }
            let nsY = screen.frame.height - y - h

            debugLog("✅ LineDetector: Found target window '\(ownerName)' ID=\(windowID)")
            return (windowID, CGRect(x: x, y: nsY, width: w, height: h), ownerName)
        }
        debugLog("❌ LineDetector: No matching target window found")
        return nil
    }
}
