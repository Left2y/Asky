import Foundation
import Testing
@testable import ToolService

@Suite struct ApplicationLanguageTests {
    @Test @MainActor func nativeOverrideAndSystemResetPreserveOtherPreferences() throws {
        let suite = "app.asky.language-tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("keep", forKey: "unrelated")
        for language in [ApplicationLanguage.english, .simplifiedChinese] {
            ToolService.setApplicationLanguage(language, defaults: defaults)
            #expect(defaults.stringArray(forKey: "AppleLanguages") == [language.rawValue])
        }
        ToolService.setApplicationLanguage(.system, defaults: defaults)
        #expect(defaults.persistentDomain(forName: suite)?["AppleLanguages"] == nil)
        #expect(defaults.string(forKey: "unrelated") == "keep")
    }
}
