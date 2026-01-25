import Cocoa
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Line detector using Tesseract 5 OCR with hOCR output for precise bounding boxes
/// Better accuracy than Apple Vision for detecting gutter line numbers
@available(macOS 13.0, *)
class TesseractLineDetector {

    struct DetectedCodeLine {
        let index: Int
        let lineNumber: Int?      // Actual line number from gutter
        let screenY: CGFloat      // Y coordinate in screen space
        let rightEdgeX: CGFloat   // X position where line ends
        let text: String
    }

    struct DetectionResult {
        let lines: [DetectedCodeLine]
        let estimatedLineHeight: CGFloat
        let windowBounds: CGRect
    }

    private let tesseractPath = "/opt/homebrew/bin/tesseract"

    /// Detect code lines using Tesseract OCR
    func detectCodeLines(windowID: CGWindowID, windowBounds: CGRect) async -> DetectionResult? {
        // Capture window to temp file and get dimensions
        guard let captureResult = await captureWindowToFile(windowID: windowID) else {
            debugLog("❌ Tesseract: Failed to capture window")
            return nil
        }
        let imagePath = captureResult.path
        let imageWidth = CGFloat(captureResult.width)
        let imageHeight = CGFloat(captureResult.height)
        defer { try? FileManager.default.removeItem(atPath: imagePath) }

        debugLog("📸 Tesseract: Captured \(Int(imageWidth))x\(Int(imageHeight)) image")

        // Run tesseract with TSV output (gives bounding boxes)
        guard let tsvOutput = runTesseract(imagePath: imagePath) else {
            debugLog("❌ Tesseract: OCR failed")
            return nil
        }

        // Parse TSV output
        let detectedWords = parseTSV(tsvOutput)
        debugLog("📊 Tesseract: Detected \(detectedWords.count) words")

        // Separate gutter numbers from code
        var gutterNumbers: [(lineNum: Int, y: CGFloat, height: CGFloat)] = []
        var codeWords: [(text: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] = []

        let lineNumberPattern = try! NSRegularExpression(pattern: "^\\d{1,5}$")

        for word in detectedWords {
            let normX = word.x / imageWidth
            let normY = word.y / imageHeight
            let normWidth = word.width / imageWidth

            // Skip top 5% (window chrome only) and bottom 3%
            guard normY > 0.05 && normY < 0.97 else { continue }

            // Gutter: leftmost 10% of screen, digits only
            if normX < 0.10 && normWidth < 0.05 {
                let range = NSRange(word.text.startIndex..., in: word.text)
                if lineNumberPattern.firstMatch(in: word.text, range: range) != nil,
                   let num = Int(word.text) {
                    gutterNumbers.append((num, word.y, word.height))
                    debugLog("  Gutter: \(num) at y=\(Int(word.y))")
                }
            }
            // Code content: after gutter area (allow single chars too for code like 'x', 'i', etc.)
            else if normX > 0.05 && normX < 0.90 && !word.text.isEmpty {
                codeWords.append((word.text, word.x, word.y, word.width, word.height))
            }
        }

        debugLog("  📊 Found \(gutterNumbers.count) gutter numbers, \(codeWords.count) code words")

        // Cluster words into lines by Y position
        let yTolerance: CGFloat = 10  // pixels
        var linesClusters: [[(text: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)]] = []

        for word in codeWords {
            var foundLine = false
            for i in 0..<linesClusters.count {
                if let first = linesClusters[i].first, abs(first.y - word.y) < yTolerance {
                    linesClusters[i].append(word)
                    foundLine = true
                    break
                }
            }
            if !foundLine {
                linesClusters.append([word])
            }
        }

        // Build detected lines
        var detectedLines: [DetectedCodeLine] = []

        for cluster in linesClusters {
            guard !cluster.isEmpty else { continue }

            let avgY = cluster.map { $0.y }.reduce(0, +) / CGFloat(cluster.count)
            let maxX = cluster.map { $0.x + $0.width }.max() ?? 0
            let sortedWords = cluster.sorted { $0.x < $1.x }
            let lineText = sortedWords.map { $0.text }.joined(separator: " ")

            // Match to gutter line number by Y position
            var matchedLineNum: Int? = nil
            for gutter in gutterNumbers {
                if abs(gutter.y - avgY) < yTolerance * 1.5 {
                    matchedLineNum = gutter.lineNum
                    break
                }
            }

            // Convert to screen coordinates
            // Tesseract Y is from top, NSScreen Y is from bottom
            guard NSScreen.main != nil else { continue }
            let screenY = windowBounds.maxY - (avgY / imageHeight * windowBounds.height)
            let rightEdgeX = windowBounds.minX + (maxX / imageWidth * windowBounds.width) + 30

            detectedLines.append(DetectedCodeLine(
                index: 0,
                lineNumber: matchedLineNum,
                screenY: screenY,
                rightEdgeX: rightEdgeX,
                text: lineText
            ))
        }

        // Sort by Y (top to bottom in screen coords = higher Y first)
        detectedLines.sort { $0.screenY > $1.screenY }

        // Assign indices
        detectedLines = detectedLines.enumerated().map { idx, line in
            DetectedCodeLine(index: idx, lineNumber: line.lineNumber, screenY: line.screenY, rightEdgeX: line.rightEdgeX, text: line.text)
        }

        // Log what we found
        for (i, line) in detectedLines.prefix(8).enumerated() {
            debugLog("  Line \(i): L\(line.lineNumber ?? -1) y=\(Int(line.screenY)) '\(line.text.prefix(40))'")
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

        debugLog("✅ Tesseract: \(detectedLines.count) lines, \(gutterNumbers.count) with line numbers, height=\(Int(lineHeight))")

        return DetectionResult(lines: detectedLines, estimatedLineHeight: lineHeight, windowBounds: windowBounds)
    }

    // MARK: - Private

    private struct CaptureResult {
        let path: String
        let width: Int
        let height: Int
    }

    private func captureWindowToFile(windowID: CGWindowID) async -> CaptureResult? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let targetWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                debugLog("❌ Tesseract: Window not found")
                return nil
            }

            let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
            let config = SCStreamConfiguration()
            config.width = Int(targetWindow.frame.width * 2)  // 2x for better OCR
            config.height = Int(targetWindow.frame.height * 2)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

            // Save to temp file (use home dir - Tesseract has issues with /tmp)
            let tempPath = FileManager.default.homeDirectoryForCurrentUser.path + "/.tesseract_input.png"
            let url = URL(fileURLWithPath: tempPath)
            let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(dest, cgImage, nil)
            CGImageDestinationFinalize(dest)

            return CaptureResult(path: tempPath, width: cgImage.width, height: cgImage.height)
        } catch {
            debugLog("❌ Tesseract: Capture failed: \(error)")
            return nil
        }
    }

    private func runTesseract(imagePath: String) -> String? {
        debugLog("🔧 Tesseract: Running on \(imagePath)")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: imagePath) else {
            debugLog("❌ Tesseract: Image file not found at \(imagePath)")
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tesseractPath)
        // PSM 6 = uniform block of text (better for code)
        // --dpi 300 = specify resolution for accurate sizing
        process.arguments = [imagePath, "stdout", "-l", "eng", "--psm", "6", "--dpi", "300", "tsv"]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()

            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            if let stderrStr = String(data: stderrData, encoding: .utf8), !stderrStr.isEmpty {
                debugLog("⚠️ Tesseract stderr: \(stderrStr.prefix(200))")
            }

            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)

            // Log first few lines with text content
            if let output = output {
                let lines = output.components(separatedBy: "\n")
                let textLines = lines.filter { line in
                    let cols = line.components(separatedBy: "\t")
                    return cols.count >= 12 && !cols[11].trimmingCharacters(in: .whitespaces).isEmpty
                }
                debugLog("🔧 Tesseract: \(lines.count) total rows, \(textLines.count) with text")
                for (i, line) in textLines.prefix(5).enumerated() {
                    let cols = line.components(separatedBy: "\t")
                    if cols.count >= 12 {
                        debugLog("  Row \(i): conf=\(cols[10]) text='\(cols[11].prefix(30))'")
                    }
                }
            }
            return output
        } catch {
            debugLog("❌ Tesseract: Process failed: \(error)")
            return nil
        }
    }

    private struct Word {
        let text: String
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let conf: Double
    }

    private func parseTSV(_ tsv: String) -> [Word] {
        var words: [Word] = []
        let lines = tsv.components(separatedBy: "\n")

        for line in lines.dropFirst() {  // Skip header
            let cols = line.components(separatedBy: "\t")
            guard cols.count >= 12 else { continue }

            // Confidence is a float like "78.942932"
            let confStr = cols[10]
            let conf = Double(confStr) ?? 0
            let text = cols[11].trimmingCharacters(in: .whitespaces)

            // Accept any confidence > 0 (code fonts may have lower OCR confidence)
            guard conf > 0 && !text.isEmpty else { continue }

            guard let x = Double(cols[6]),
                  let y = Double(cols[7]),
                  let w = Double(cols[8]),
                  let h = Double(cols[9]) else { continue }

            words.append(Word(text: text, x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h), conf: conf))
        }

        return words
    }

    func findTargetWindow() -> (windowID: CGWindowID, bounds: CGRect, appName: String)? {
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let targetApps = ["Code", "Visual Studio Code", "Cursor", "WezTerm", "iTerm", "Terminal"]

        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = window[kCGWindowLayer as String] as? Int else { continue }

            let x = bounds["X"] ?? 0, y = bounds["Y"] ?? 0
            let w = bounds["Width"] ?? 0, h = bounds["Height"] ?? 0

            guard layer == 0 && w > 400 && h > 300 else { continue }
            guard targetApps.contains(where: { ownerName.localizedCaseInsensitiveContains($0) }) else { continue }

            guard let screen = NSScreen.main else { continue }
            let nsY = screen.frame.height - y - h

            return (windowID, CGRect(x: x, y: nsY, width: w, height: h), ownerName)
        }
        return nil
    }
}
