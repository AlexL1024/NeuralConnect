import Foundation

enum SetupMode: String {
    case auto
    case manual

    private static let key = "setup_mode"

    static var current: SetupMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: key),
               let mode = SetupMode(rawValue: raw) {
                return mode
            }
            return .manual
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    static var isAuto: Bool { current == .auto }
}
