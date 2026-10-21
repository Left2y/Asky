import AppKit
import SwiftUI
import LocalStore

@main @MainActor
enum LocalShortcutsRegression {
    static func event(_ code: UInt16, _ flags: NSEvent.ModifierFlags = [], window: NSWindow? = nil) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                         windowNumber: window?.windowNumber ?? 0, context: nil, characters: "j",
                         charactersIgnoringModifiers: "j", isARepeat: false, keyCode: code)!
    }

    static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                let root = FileManager.default.temporaryDirectory.appending(path: "Asky-shortcuts-\(UUID())")
                defer { try? FileManager.default.removeItem(at: root) }
                let app = try AppModel(root: root)
                let legacy = try JSONDecoder().decode(SettingsPreferences.self, from: Data("{}".utf8))
                for action in LocalShortcutAction.allCases {
                    precondition(legacy.shortcut(action) == action.defaultShortcut)
                }
                // Reject conflicts only where actions can run in the same window.
                precondition(!app.preferences.setShortcut(.execute, app.preferences.shortcut(.askAI)))
                precondition(!app.preferences.setShortcut(.clipboardCopy, app.preferences.shortcut(.settings)))
                precondition(app.preferences.setShortcut(.newChat, app.preferences.shortcut(.launcherMore)))
                app.preferences = SettingsPreferences()
                // Every action round-trips; two legacy fields retain their existing storage.
                for (index, action) in LocalShortcutAction.allCases.enumerated() {
                    let value = LauncherActionShortcut(code: UInt32(index), modifiers: 6912, label: "⌃⌥⇧⌘ \(index)")
                    precondition(app.preferences.setShortcut(action, value), "failed to edit \(action)")
                }
                let reloaded = try AppModel(root: root)
                precondition(reloaded.preferences == app.preferences)
                app.preferences = SettingsPreferences()
                app.settingsTab = "hotkey"
                let window = SettingsWindow.make(app: app)
                window.setContentSize(NSSize(width: 1000, height: 1100))
                window.makeKeyAndOrderFront(nil)
                try await Task.sleep(for: .milliseconds(350))
                @MainActor func views(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(views) }
                guard let content = window.contentView,
                      let recorder = views(content).compactMap({ $0 as? NSButton }).first(where: { $0.title == "⌘ C" }) else {
                    fatalError("Copy file must have a native editable recorder")
                }
                recorder.performClick(nil)
                precondition(window.firstResponder === recorder)
                recorder.keyDown(with: event(38, [.command, .shift], window: window))
                try await Task.sleep(for: .milliseconds(100))
                precondition(app.preferences.shortcut(.copyFile).code == 38)
                precondition(app.preferences.shortcut(.copyFile).modifiers == 768)
                let afterRecording = try AppModel(root: root)
                precondition(afterRecording.preferences.shortcut(.copyFile).code == 38)
                // Same native recorder accepts unmodified navigation keys and rejects occupied ones.
                recorder.performClick(nil)
                recorder.keyDown(with: event(36, window: window))
                precondition(app.preferences.shortcut(.copyFile).code == 38, "occupied Return must be rejected")
                window.makeFirstResponder(nil)
                for appearance in ["light", "dark"] {
                    app.preferences.appearance = appearance
                    try await Task.sleep(for: .milliseconds(200))
                    content.layoutSubtreeIfNeeded()
                    let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
                    content.cacheDisplay(in: content.bounds, to: bitmap)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(filePath: "build/shortcut-edit-\(appearance).png"))
                }
                let launcher = LauncherModel(app: app, searchProviders: [])
                var prompts: [String] = []
                launcher.onAskAI = { prompts.append($0) }
                launcher.query = "hello shortcut"
                precondition(app.preferences.setShortcut(.askAI, .init(code: 38, modifiers: 4096, label: "⌃ J")))
                precondition(launcher.handleActionKey(event(38, .control)))
                precondition(prompts == ["hello shortcut"])
                precondition(!launcher.handleActionKey(event(36, .command)), "old AI shortcut must stop firing")
                let clipboard = ClipboardController(app: app)
                precondition(app.preferences.setShortcut(.clipboardCopy, .init(code: 38, modifiers: 4096, label: "⌃ J")))
                precondition(clipboard.handleActionKey(event(38, .control)))
                precondition(!clipboard.handleActionKey(event(36, .command)), "old clipboard shortcut must stop firing")
                precondition(app.preferences.setShortcut(.copyFile, LocalShortcutAction.copyFile.defaultShortcut))
                precondition(app.preferences.shortcut(.copyFile) == LocalShortcutAction.copyFile.defaultShortcut)
                var draft = "message"
                var sends = 0
                var agentPreferences = SettingsPreferences()
                precondition(agentPreferences.setShortcut(.send, .init(code: 38, modifiers: 4096, label: "⌃ J")))
                precondition(agentPreferences.setShortcut(.newline, .init(code: 40, modifiers: 4096, label: "⌃ K")))
                let composer = ComposerTextEditor(text: Binding(get: { draft }, set: { draft = $0 }),
                    height: .constant(44), isFocused: .constant(false), pasteAttachment: { false },
                    submit: { sends += 1 }, shortcuts: agentPreferences)
                let host = NSHostingView(rootView: composer)
                host.frame = NSRect(x: 0, y: 0, width: 400, height: 100)
                let composerWindow = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
                composerWindow.contentView = host
                composerWindow.makeKeyAndOrderFront(nil)
                try await Task.sleep(for: .milliseconds(200))
                host.layoutSubtreeIfNeeded()
                let editor = views(host).compactMap { $0 as? NSTextView }.first!
                precondition(editor.performKeyEquivalent(with: event(38, .control, window: composerWindow)))
                precondition(sends == 1)
                precondition(editor.performKeyEquivalent(with: event(40, .control, window: composerWindow)))
                precondition(editor.string.contains("\n") && sends == 1)
                editor.keyDown(with: event(36, window: composerWindow))
                precondition(sends == 1, "old Return must stop sending after remapping")
                print("All 29 local actions: migration, conflict scopes, persistence, native recording, reset, launcher, clipboard and AI composer dispatch passed")
                exit(0)
            } catch { fatalError("\(error)") }
        }
        NSApp.run()
    }
}
