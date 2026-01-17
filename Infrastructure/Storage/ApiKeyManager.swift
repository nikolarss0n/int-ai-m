import Foundation

extension Notification.Name {
    static let apiKeysUpdated = Notification.Name("apiKeysUpdated")
}

enum ApiKeyType: String, CaseIterable {
    case anthropic = "ANTHROPIC_API_KEY"
    case groq = "GROQ_API_KEY"
}

/// Centralized API key management - reads from ~/.interview-master-keys
class ApiKeyManager {
    static let shared = ApiKeyManager()

    private var keys: [String: String] = [:]
    private let filePath = NSString(string: "~/.interview-master-keys").expandingTildeInPath

    private init() {
        loadKeys()
    }

    private func loadKeys() {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            NSLog("⚠️ ApiKeyManager: Could not read \(filePath)")
            return
        }

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                keys[key] = value
            }
        }
        NSLog("✅ ApiKeyManager: Loaded \(keys.count) keys from file")
    }

    func getKey(_ type: ApiKeyType) -> String? {
        return keys[type.rawValue]
    }

    func setKey(_ key: String, for type: ApiKeyType) -> Bool {
        keys[type.rawValue] = key
        return true
    }

    func hasKey(_ type: ApiKeyType) -> Bool {
        guard let key = keys[type.rawValue] else { return false }
        return !key.isEmpty
    }

    func deleteKey(_ type: ApiKeyType) -> Bool {
        keys.removeValue(forKey: type.rawValue)
        return true
    }
}
