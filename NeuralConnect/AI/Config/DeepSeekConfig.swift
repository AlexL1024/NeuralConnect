import Foundation

enum DeepSeekConfig {
    private static let apiKeyKey = "deepseek_api_key"
    private static let enabledKey = "deepseek_enabled"
    // Legacy UserDefaults key for migration
    private static let legacyApiKeyKey = "deepseek_api_key"

    static var apiKey: String {
        // Try Keychain first, fallback to UserDefaults for migration
        if let key = KeychainHelper.load(forKey: apiKeyKey) {
            return key
        }
        if let legacy = UserDefaults.standard.string(forKey: legacyApiKeyKey), !legacy.isEmpty {
            // Migrate to Keychain
            KeychainHelper.save(legacy, forKey: apiKeyKey)
            UserDefaults.standard.removeObject(forKey: legacyApiKeyKey)
            return legacy
        }
        return ""
    }

    static var isEnabled: Bool {
        // Default to true if user has never toggled the setting
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var isConfigured: Bool {
        isEnabled && !apiKey.isEmpty
    }

    static func save(apiKey: String, enabled: Bool) {
        KeychainHelper.save(apiKey, forKey: apiKeyKey)
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }
}
