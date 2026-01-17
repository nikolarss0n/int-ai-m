import Foundation

/// Simple file logger for debugging main functionality
/// Log file is cleared on each app start
class DebugLogger {
    static let shared = DebugLogger()

    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "com.interviewmaster.logger", qos: .utility)

    private init() {
        // Log file in project directory (use current working directory)
        let cwd = FileManager.default.currentDirectoryPath
        logFileURL = URL(fileURLWithPath: cwd).appendingPathComponent("interview_debug.log")

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }

    /// Clear the log file (call on app start)
    func clear() {
        queue.sync {
            try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
        }
        log("=== Interview Master Started ===")
    }

    /// Log a message with timestamp
    func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        let entry = "[\(timestamp)] [\(fileName):\(line)] \(message)\n"

        queue.async { [weak self] in
            guard let self = self else { return }
            if let handle = try? FileHandle(forWritingTo: self.logFileURL) {
                handle.seekToEndOfFile()
                if let data = entry.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            } else {
                // File doesn't exist, create it
                try? entry.write(to: self.logFileURL, atomically: true, encoding: .utf8)
            }
        }

        // Also print to console for immediate feedback
        NSLog("📝 %@", message)
    }

    /// Log with category prefix
    func log(_ category: LogCategory, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("\(category.rawValue) \(message)", file: file, function: function, line: line)
    }

    enum LogCategory: String {
        case audio = "🎤 AUDIO:"
        case transcription = "📝 TRANSCRIBE:"
        case classification = "🏷️ CLASSIFY:"
        case answer = "💬 ANSWER:"
        case stream = "📡 STREAM:"
        case error = "❌ ERROR:"
        case delegate = "📤 DELEGATE:"
    }
}

// Convenience global function
func debugLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.shared.log(message, file: file, function: function, line: line)
}

func debugLog(_ category: DebugLogger.LogCategory, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.shared.log(category, message, file: file, function: function, line: line)
}
