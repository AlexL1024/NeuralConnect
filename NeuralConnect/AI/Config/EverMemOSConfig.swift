import Foundation
import EverMemOSKit

enum EverMemOSConfig {
    private static let modeKey = "evermemos_deployment_mode"
    private static let baseURLKeyPrefix = "evermemos_base_url"
    private static let tokenKey = "evermemos_token"

    // MARK: - Deployment Mode

    static var deploymentMode: DeploymentProfile {
        get {
            if let raw = UserDefaults.standard.string(forKey: modeKey),
               let mode = DeploymentProfile(rawValue: raw) {
                return mode
            }
            return .cloud
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
        }
    }

    // MARK: - Cloud Config

    static var cloudBaseURL: URL {
        let str = UserDefaults.standard.string(forKey: "\(baseURLKeyPrefix).cloud")
            ?? DeploymentProfile.cloud.defaultBaseURL.absoluteString
        return URL(string: str) ?? DeploymentProfile.cloud.defaultBaseURL
    }

    static var cloudToken: String {
        // Try Keychain first, fallback to UserDefaults for migration
        if let token = KeychainHelper.load(forKey: tokenKey) {
            return token
        }
        if let legacy = UserDefaults.standard.string(forKey: tokenKey), !legacy.isEmpty {
            KeychainHelper.save(legacy, forKey: tokenKey)
            UserDefaults.standard.removeObject(forKey: tokenKey)
            return legacy
        }
        return ""
    }

    // MARK: - Local Config

    static var localBaseURL: URL {
        let str = UserDefaults.standard.string(forKey: "\(baseURLKeyPrefix).local")
            ?? DeploymentProfile.local.defaultBaseURL.absoluteString
        return URL(string: str) ?? DeploymentProfile.local.defaultBaseURL
    }

    // MARK: - Current Mode Accessors

    static var baseURL: URL {
        deploymentMode == .cloud ? cloudBaseURL : localBaseURL
    }

    static var token: String { cloudToken }

    static var isConfigured: Bool {
        switch deploymentMode {
        case .cloud: return !cloudToken.isEmpty
        case .local: return true
        }
    }

    // MARK: - Save

    static func save(mode: DeploymentProfile, baseURL: String, token: String) {
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
        switch mode {
        case .cloud:
            UserDefaults.standard.set(baseURL, forKey: "\(baseURLKeyPrefix).cloud")
            KeychainHelper.save(token, forKey: tokenKey)
        case .local:
            UserDefaults.standard.set(baseURL, forKey: "\(baseURLKeyPrefix).local")
        }
    }

    // MARK: - Migration

    static func migrateIfNeeded() {
        let oldKey = "evermemos_base_url"
        if let stored = UserDefaults.standard.string(forKey: oldKey) {
            // Migrate old single base URL to cloud-specific key
            if !stored.contains("evermemos.com") {
                UserDefaults.standard.set(stored, forKey: "\(baseURLKeyPrefix).cloud")
            }
            UserDefaults.standard.removeObject(forKey: oldKey)
        }
    }

    // MARK: - Per-Device Tenant

    private static let deviceIdKey = "evermemos_device_id"

    static var deviceTenantId: String {
        if let existing = KeychainHelper.load(forKey: deviceIdKey) {
            return "neuralconnect_\(existing)"
        }
        let newId = UUID().uuidString.prefix(8).lowercased()
        KeychainHelper.save(String(newId), forKey: deviceIdKey)
        return "neuralconnect_\(newId)"
    }

    // MARK: - Build Service

    static func buildService() -> MemosService? {
        guard isConfigured else { return nil }
        switch deploymentMode {
        case .cloud:
            return MemosService(profile: .cloud, baseURL: cloudBaseURL, token: cloudToken, tenantId: deviceTenantId)
        case .local:
            return MemosService(profile: .local, baseURL: localBaseURL, tenantId: deviceTenantId)
        }
    }
}
