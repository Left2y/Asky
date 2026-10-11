import AppKit
import SwiftUI
import ToolService

@main @MainActor
enum ApplicationLanguageRegression {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                let english = Bundle.main.preferredLocalizations.first == "en"
                let legacy = Data(#"{"appearance":"dark","hotKeyLabel":"custom shortcut"}"#.utf8)
                let migrated = try JSONDecoder().decode(SettingsPreferences.self, from: legacy)
                guard migrated.language == .system, migrated.appearance == "dark",
                      migrated.hotKeyLabel == "custom shortcut" else { fatalError("legacy preferences lost") }
                let unknown = try JSONDecoder().decode(SettingsPreferences.self, from: Data(#"{"language":"unknown","appearance":"light"}"#.utf8))
                guard unknown.language == .system, unknown.appearance == "light" else { fatalError("unsupported language didn't fall back") }
                let root = FileManager.default.temporaryDirectory.appending(path: "Asky-language-\(UUID())")
                defer { try? FileManager.default.removeItem(at: root) }
                let model = try AppModel(root: root)
                model.preferences.language = .english
                let restored = try AppModel(root: root)
                guard restored.preferences.language == .english, model.launchLanguage == .system else {
                    fatalError("language didn't persist or changed the running language")
                }
                model.preferences.language = .system
                guard let identifier = Bundle.main.bundleIdentifier,
                      UserDefaults.standard.persistentDomain(forName: identifier)?["AppleLanguages"] == nil else {
                    fatalError("Follow System retained an app-specific override")
                }
                guard SettingsPage.general.title == (english ? "General" : "通用"),
                      NSLocalizedString("应用语言", comment: "") == (english ? "App language" : "应用语言"),
                      NSLocalizedString("退出 Asky", comment: "") == (english ? "Quit Asky" : "退出 Asky") else {
                    fatalError("native bundle localization mismatch")
                }
                EditMenu.install()
                guard NSApp.mainMenu?.items.last?.submenu?.title == (english ? "Edit" : "编辑") else {
                    fatalError("AppKit edit menu didn't localize")
                }
                let window = SettingsWindow.make(app: model)
                window.center()
                window.makeKeyAndOrderFront(nil)
                try await Task.sleep(for: .milliseconds(800))
                for page in SettingsPage.allCases {
                    model.settingsTab = page.rawValue
                    try await Task.sleep(for: .milliseconds(100))
                    let suffix = english ? "Asky Settings" : "Asky 设置"
                    guard window.title == "\(page.title) — \(suffix)" else { fatalError("window title didn't localize") }
                }
                model.settingsTab = SettingsPage.general.rawValue
                try await Task.sleep(for: .milliseconds(300))
                guard let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                    fatalError("missing native window snapshot")
                }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let png = try bitmap.representation(using: .png, properties: [:]).unwrap()
                try png.write(to: URL(filePath: "build/application-language-\(english ? "en" : "zh-Hans").png"))
                print("PASS: legacy migration, language persistence, system reset, native localization, all settings titles, native snapshot (\(Bundle.main.preferredLocalizations))")
                window.close()
                application.terminate(nil)
            } catch { fatalError("language regression: \(error)") }
        }
        application.run()
    }
}

private extension Optional {
    func unwrap() throws -> Wrapped {
        guard let value = self else { throw CocoaError(.fileWriteUnknown) }
        return value
    }
}
