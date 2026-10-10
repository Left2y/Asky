import AppKit
import SwiftUI

@main @MainActor
enum SettingsRegression {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                let root = FileManager.default.temporaryDirectory.appending(path: "KulaHere-settings-\(UUID())")
                let model = try AppModel(root: root)
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
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 590),
                                      styleMask: [.titled, .closable], backing: .buffered, defer: false)
                window.title = "KulaHere 设置验证"
                window.contentView = NSHostingView(rootView: SettingsView(app: model))
                window.center()
                window.makeKeyAndOrderFront(nil)
                if CommandLine.arguments.contains("--preview") { return }
                for appearance in ["light", "dark"] {
                    model.preferences.appearance = appearance
                    for tab in ["appearance", "model", "hotkey", "keywords", "permissions"] {
                        model.settingsTab = tab
                        try await Task.sleep(for: .milliseconds(250))
                        window.contentView?.layoutSubtreeIfNeeded()
                        guard let view = window.contentView,
                              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("missing settings view") }
                        view.cacheDisplay(in: view.bounds, to: bitmap)
                        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("missing settings snapshot") }
                        try png.write(to: URL(filePath: "build/settings-\(appearance)-\(tab).png"))
                    }
                }
                try? FileManager.default.removeItem(at: root)
                print("Settings native light/dark snapshots passed")
                exit(0)
            } catch { fputs("Settings regression failed: \(error)\n", stderr); exit(1) }
        }
        application.run()
    }
}
