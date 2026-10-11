import Foundation

/// Languages with bundled interface translations. macOS selects the localization at launch.
public enum ApplicationLanguage: String, CaseIterable, Codable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"
}

extension ToolService {
    /// Change only this application's native language override, never the global language list.
    @MainActor
    public static func setApplicationLanguage(_ language: ApplicationLanguage, defaults: UserDefaults = .standard) {
        if language == .system {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([language.rawValue], forKey: "AppleLanguages")
        }
    }
}
