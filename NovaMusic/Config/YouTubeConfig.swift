import Foundation

/// Resolves the YouTube Data API v3 key.
/// Order: Settings (UserDefaults) → Secrets.plist → Info.plist.
enum YouTubeConfig {
    static let userDefaultsKey = "nova.youtubeDataAPIKey"
    static let infoPlistKey = "YOUTUBE_DATA_API_KEY"

    static var apiKey: String? {
        if let override = UserDefaults.standard.string(forKey: userDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty,
           override != "PASTE_YOUR_YOUTUBE_DATA_API_KEY_HERE" {
            return override
        }
        if let fromSecrets = string(fromPlistNamed: "Secrets", key: infoPlistKey) {
            return fromSecrets
        }
        if let fromInfo = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String {
            let trimmed = fromInfo.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty,
               !trimmed.hasPrefix("$("),
               trimmed != "PASTE_YOUR_YOUTUBE_DATA_API_KEY_HERE" {
                return trimmed
            }
        }
        return nil
    }

    static var isConfigured: Bool { apiKey != nil }

    static func saveUserAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: userDefaultsKey)
        }
    }

    static func clearUserAPIKey() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    private static func string(fromPlistNamed name: String, key: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let value = dict[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "PASTE_YOUR_YOUTUBE_DATA_API_KEY_HERE" else { return nil }
        return trimmed
    }
}
