import Foundation

enum GameLanguage: String, CaseIterable {
    case english = "en"
    case chinese = "zh"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }
}

final class LanguageManager {
    static let shared = LanguageManager()

    private let key = "game_language"

    var current: GameLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: key),
               let lang = GameLanguage(rawValue: raw) {
                return lang
            }
            return .english
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    var isEnglish: Bool { current == .english }

    private init() {}
}

/// Convenience: pick EN or CN string based on current language.
nonisolated func L(_ en: String, _ zh: String) -> String {
    LanguageManager.shared.isEnglish ? en : zh
}
