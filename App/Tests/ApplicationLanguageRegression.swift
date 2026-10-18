import AppKit
import SwiftUI
import ToolService
import Contracts
import Search
import DirectActions

private struct LanguageBrowserProvider: SearchProvider {
    let source: SearchSource
    func search(_ query: String, limit: Int) async -> [SearchResult] { [] }
}

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
                let launcher = LauncherModel(app: model, searchProviders: [LanguageBrowserProvider(source: .chromeTab), LanguageBrowserProvider(source: .bookmark)], chromeBookmarkAccessAllowed: true)
                for (trigger, expected) in [("st", "Search Open Tabs"), ("bm", "Search bookmarks"), ("link", "Search links"), ("ai", "AI search")] {
                    launcher.query = trigger
                    try await Task.sleep(for: .milliseconds(200))
                    guard let row = launcher.results.first, let action = launcher.primaryLauncherAction,
                          row.target.kind == "search-command",
                          row.title == (english ? expected : AppModel.searchCommands.first { $0.2 == trigger }!.1),
                          NSLocalizedString(action.title, tableName: "Launcher", comment: "") == row.title else {
                        fatalError("search entry/action localization mismatch: \(trigger)")
                    }
                }
                for command in KeywordCommand.builtIn {
                    let name = NSLocalizedString(command.name, comment: "")
                    launcher.query = command.keyword
                    try await Task.sleep(for: .milliseconds(200))
                    guard launcher.results.contains(where: { $0.target.kind == "keyword-match" && $0.title == name }),
                          !english || !name.contains(where: { $0.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) } }) else {
                        fatalError("website suggestion localization mismatch: \(command.keyword)")
                    }
                    launcher.query = command.keyword + " 原样 query"
                    let title = command.supportsQuery
                        ? (english ? "\(name): 原样 query" : "\(name)：原样 query")
                        : (english ? "Open \(name)" : "打开 \(name)")
                    guard launcher.results.first?.title == title else { fatalError("website result localization mismatch") }
                }
                let controller = LauncherController(model: launcher)
                controller.show()
                guard let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }) as? LauncherPanel else {
                    fatalError("missing launcher language panel")
                }
                panel.onBlur = {}
                launcher.query = "yt"
                try await Task.sleep(for: .milliseconds(350))
                guard let index = launcher.results.firstIndex(where: { $0.target.kind == "tab-search" }) else {
                    fatalError("missing tab search fallback")
                }
                launcher.selection = index
                guard let action = launcher.primaryLauncherAction,
                      NSLocalizedString(action.title, tableName: "Launcher", comment: "") == (english ? "Search Open Tabs" : "搜索开启的标签页") else {
                    fatalError("tab search footer localization mismatch")
                }
                try await Task.sleep(for: .milliseconds(200))
                guard let view = panel.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                    fatalError("missing launcher snapshot")
                }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try bitmap.representation(using: .png, properties: [:])!.write(to: URL(filePath: "build/launcher-language-\(english ? "en" : "zh-Hans").png"))
                controller.hide()
                print("PASS: all search entry actions, website suggestions and query results, tab footer, launcher snapshot")
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
