import AppKit
import SwiftUI

@main @MainActor
enum SettingsRegression {
    static func main() {
        let application = NSApplication.shared
        let preview = CommandLine.arguments.contains("--preview")
        application.setActivationPolicy(preview ? .regular : .accessory)
        Task { @MainActor in
            do {
                let root = FileManager.default.temporaryDirectory.appending(path: "KulaHere-settings-\(UUID())")
                let model = try AppModel(root: root)
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
                if preview { application.activate(); return }
                for appearance in ["light", "dark"] {
                    model.preferences.appearance = appearance
                    for page in SettingsPage.allCases {
                        let tab = page.rawValue
                        model.settingsTab = tab
                        try await Task.sleep(for: .milliseconds(250))
                        window.contentView?.layoutSubtreeIfNeeded()
                        guard window.title == "\(page.title) — KulaHere 设置" else {
                            fatalError("settings title did not follow selection: \(tab)")
                        }
                        guard let view = window.contentView,
                              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("missing settings view") }
                        view.cacheDisplay(in: view.bounds, to: bitmap)
                        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("missing settings snapshot") }
                        try png.write(to: URL(filePath: "build/settings-\(appearance)-\(tab).png"))
                    }
                }
                model.openSettings(permissions: true)
                try await Task.sleep(for: .milliseconds(250))
                guard model.settingsTab == "permissions", window.title.hasPrefix("系统权限") else {
                    fatalError("permission recovery did not select its sidebar page")
                }
                window.setContentSize(SettingsWindow.minimumSize)
                window.contentView?.layoutSubtreeIfNeeded()
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
}
