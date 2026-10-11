import AppKit
import SwiftUI
import DirectActions
import LocalStore
import Router

@main @MainActor
enum SettingsRegression {
    static func main() {
        let application = NSApplication.shared
        let preview = CommandLine.arguments.contains("--preview")
        application.setActivationPolicy(preview ? .regular : .accessory)
        Task { @MainActor in
            do {
                let root = FileManager.default.temporaryDirectory.appending(path: "Asky-settings-\(UUID())")
                let legacyStore = try LocalStore(root: root)
                legacyStore.setCodableSetting("keywords", KeywordRegistry(commands: [
                    KeywordCommand(keyword: "go", name: "Custom", urlTemplate: "https://example.com"),
                ]))
                let model = try AppModel(root: root)
                guard model.keywords.commands == KeywordCommand.builtIn,
                      model.keywords.match("go hello")?.0.urlTemplate.contains("google.com") == true,
                      model.keywords.match("chat hello")?.0.url(for: "hello")?.host == "chatgpt.com",
                      SettingsPage.allCases.contains(.keywords),
                      SettingsPage.resolve("keywords") == .keywords else {
                    fatalError("legacy settings changed fixed presets or command settings are missing")
                }
                var input = LauncherInputState()
                input.edit("> pwd", keywords: model.keywords)
                guard input.terminal, input.text == "pwd" else {
                    fatalError("terminal preset failed without user configuration")
                }
                let legacy = Data(#"{"appearance":"dark","hotKeyCode":49,"hotKeyModifiers":6144,"hotKeyLabel":"⌃⌥ Space","clipboardHotKeyLabel":"custom clipboard"}"#.utf8)
                let migrated = try JSONDecoder().decode(SettingsPreferences.self, from: legacy)
                guard migrated.appearance == "dark", migrated.hotKeyLabel == "⌃⌥ Space",
                      migrated.clipboardHotKeyLabel == "custom clipboard",
                      migrated.agentHotKeyCode == SettingsPreferences.defaultAgentHotKey.code,
                      migrated.agentHotKeyModifiers == SettingsPreferences.defaultAgentHotKey.modifiers,
                      migrated.agentHotKeyLabel == SettingsPreferences.defaultAgentHotKey.label else {
                    fatalError("AI hotkey migration lost existing preferences or default binding")
                }
                model.preferences.agentHotKeyCode = 17
                model.preferences.agentHotKeyModifiers = 6144
                model.preferences.agentHotKeyLabel = "⌃⌥ T"
                let reloaded = try AppModel(root: root)
                guard reloaded.preferences.agentHotKeyCode == 17,
                      reloaded.preferences.agentHotKeyModifiers == 6144,
                      reloaded.preferences.agentHotKeyLabel == "⌃⌥ T" else {
                    fatalError("custom AI hotkey did not survive preference reload")
                }
                let defaultAgent = SettingsPreferences.defaultAgentHotKey
                model.preferences.agentHotKeyCode = defaultAgent.code
                model.preferences.agentHotKeyModifiers = defaultAgent.modifiers
                model.preferences.agentHotKeyLabel = defaultAgent.label
                if CommandLine.arguments.contains("--dark") { model.preferences.appearance = "dark" }
                var hotKey: HotKey?
                model.onHotKeyChange = { code, modifiers in
                    do {
                        let candidate = try HotKey(keyCode: code, modifiers: modifiers) {}
                        hotKey?.unregister()
                        hotKey = candidate
                        model.hotKeyStatus = "已注册"
                        return true
                    } catch { model.hotKeyStatus = "组合键已被占用"; return false }
                }
                let window = SettingsWindow.make(app: model)
                guard let split = window.contentViewController as? NSSplitViewController,
                      split.splitViewItems.count == 2,
                      split.splitViewItems[0].behavior == .sidebar,
                      window.styleMask.contains(.resizable),
                      window.contentMinSize == SettingsWindow.minimumSize else {
                    fatalError("missing native settings sidebar or resize constraints")
                }
                window.center()
                window.makeKeyAndOrderFront(nil)
                if preview {
                    if CommandLine.arguments.contains("--commands") { model.settingsTab = "keywords" }
                    application.activate(); return
                }
                for appearance in ["light", "dark"] {
                    model.preferences.appearance = appearance
                    for page in SettingsPage.allCases {
                        let tab = page.rawValue
                        model.settingsTab = tab
                        try await Task.sleep(for: .milliseconds(250))
                        window.contentView?.layoutSubtreeIfNeeded()
                        assertDetailBelowToolbar(split, window: window)
                        guard window.title == "\(page.title) — Asky 设置" else {
                            fatalError("settings title did not follow selection: \(tab)")
                        }
                        guard let view = window.contentView,
                              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("missing settings view") }
                        view.cacheDisplay(in: view.bounds, to: bitmap)
                        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("missing settings snapshot") }
                        try png.write(to: URL(filePath: "build/settings-\(appearance)-\(tab).png"))
                        if page == .sources {
                            guard let scroll = findScrollView(in: split.splitViewItems[1].viewController.view),
                                  let document = scroll.documentView else {
                                fatalError("missing settings scroll view")
                            }
                            let bottom = max(0, document.bounds.height - scroll.contentView.bounds.height)
                            guard bottom > 0 else { fatalError("data sources no longer scrolls") }
                            scroll.contentView.scroll(to: NSPoint(x: 0, y: document.isFlipped ? bottom : 0))
                            scroll.reflectScrolledClipView(scroll.contentView)
                            try await Task.sleep(for: .milliseconds(250))
                            assertDetailBelowToolbar(split, window: window)
                            view.cacheDisplay(in: view.bounds, to: bitmap)
                            let scrolled = bitmap.representation(using: .png, properties: [:])!
                            try scrolled.write(to: URL(filePath: "build/settings-\(appearance)-sources-scrolled.png"))
                        }
                    }
                }
                model.openSettings(permissions: true)
                try await Task.sleep(for: .milliseconds(250))
                guard model.settingsTab == "permissions", window.title.hasPrefix("系统权限") else {
                    fatalError("permission recovery did not select its sidebar page")
                }
                window.setContentSize(SettingsWindow.minimumSize)
                window.contentView?.layoutSubtreeIfNeeded()
                assertDetailBelowToolbar(split, window: window)
                guard split.splitViewItems[0].isCollapsed == false,
                      split.splitViewItems[1].viewController.view.bounds.width >= 540 else {
                    fatalError("settings detail clipped at minimum window size")
                }
                try? FileManager.default.removeItem(at: root)
                print("Settings native light/dark snapshots passed")
                exit(0)
            } catch { fputs("Settings regression failed: \(error)\n", stderr); exit(1) }
        }
        application.run()
    }

    private static func assertDetailBelowToolbar(_ split: NSSplitViewController, window: NSWindow) {
        guard let hosting = split.splitViewItems[1].viewController.children.first else {
            fatalError("missing settings detail host")
        }
        let viewport = hosting.view.convert(hosting.view.bounds, to: nil)
        guard viewport.maxY <= window.contentLayoutRect.maxY + 0.5,
              viewport.height > 400 else {
            fatalError("settings scroll viewport overlaps toolbar: \(viewport), layout: \(window.contentLayoutRect)")
        }
    }

    private static func findScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { findScrollView(in: $0) }.first
    }
}
