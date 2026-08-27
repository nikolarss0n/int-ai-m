import Foundation

extension Notification.Name {
    static let apiKeysUpdated = Notification.Name("apiKeysUpdated")
}

enum ApiKeyType: String, CaseIterable {
    case anthropic = "ANTHROPIC_API_KEY"
    case groq = "GROQ_API_KEY"
    /// xAI Grok (console.x.ai) — preferred for interview classify/answer
    case xai = "XAI_API_KEY"
}

/// Centralized API key management - reads from ~/.interview-master-keys
class ApiKeyManager {
    static let shared = ApiKeyManager()

    private var keys: [String: String] = [:]
    private let filePath = NSString(string: "~/.interview-master-keys").expandingTildeInPath
    private let queue = DispatchQueue(label: "com.interviewmaster.apikeys", attributes: .concurrent)

    private init() {
        loadKeys()
    }

    private func loadKeys() {
        var loaded: [String: String] = [:]

        if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

                let parts = trimmed.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        loaded[key] = value
                    }
                }
            }
        } else {
            NSLog("⚠️ ApiKeyManager: Could not read \(filePath)")
        }

        // Environment overrides file (useful for XAI_API_KEY without editing the key file)
        for type in ApiKeyType.allCases {
            if let env = ProcessInfo.processInfo.environment[type.rawValue]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !env.isEmpty {
                loaded[type.rawValue] = env
            }
        }

        queue.async(flags: .barrier) {
            self.keys = loaded
            NSLog("✅ ApiKeyManager: Loaded \(loaded.count) keys from file/env")
        }
    }

    func getKey(_ type: ApiKeyType) -> String? {
        return queue.sync { keys[type.rawValue] }
    }

    func setKey(_ key: String, for type: ApiKeyType) -> Bool {
        queue.async(flags: .barrier) { self.keys[type.rawValue] = key }
        return true
    }

    func hasKey(_ type: ApiKeyType) -> Bool {
        return queue.sync {
            guard let key = keys[type.rawValue] else { return false }
            return !key.isEmpty
        }
    }

    func deleteKey(_ type: ApiKeyType) -> Bool {
        queue.async(flags: .barrier) { self.keys.removeValue(forKey: type.rawValue) }
        return true
    }
}
