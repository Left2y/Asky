import AppKit
import SwiftUI
import DirectActions
import LocalStore
import Router
import ToolService

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
                try await assertPermissionRefreshRace()
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
                try await assertStandaloneAuthorizationFlow(parent: window)
                try await assertNativeCardDrag(parent: window)
                try? FileManager.default.removeItem(at: root)
                print("Settings native snapshots, authorization lifecycle and card drag restoration passed")
                exit(0)
            } catch { fputs("Settings regression failed: \(error)\n", stderr); exit(1) }
        }
        application.run()
    }

    private static func assertNativeCardDrag(parent: NSWindow) async throws {
        var started = 0
        var accepted: [Bool] = []
        let card = PermissionCardHostingView(rootView: PermissionAppCard(colorScheme: .light, reduceTransparency: false),
            onStarted: { started += 1 }, onEnded: { accepted.append($0) })
        card.frame = NSRect(x: 12, y: 12, width: 320, height: 80)
        guard card.acceptsFirstMouse(for: nil), !card.mouseDownCanMoveWindow else {
            fatalError("dragging the inactive panel's card must not require a second click or move the window")
        }
        parent.contentView?.addSubview(card)
        defer { card.removeFromSuperview() }
        try await Task.sleep(for: .milliseconds(150))
        guard let snapshot = card.cardSnapshot(), snapshot.size == NSSize(width: 320, height: 80),
              let tiff = snapshot.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("drag preview is missing the full card")
        }
        try png.write(to: URL(filePath: "build/permission-drag-card.png"))
        card.beginCardDrag()
        guard card.alphaValue == 0, started == 1 else { fatalError("source card remained visible when dragging began") }
        card.finishCardDrag(operation: [])
        guard card.alphaValue == 1, accepted == [false] else { fatalError("cancelled drag did not restore the source card") }
        card.beginCardDrag()
        card.finishCardDrag(operation: .copy)
        guard card.alphaValue == 0, accepted == [false, true] else { fatalError("accepted drag incorrectly restored the source card") }
    }

    private static func assertPermissionRefreshRace() async throws {
        var pendingRead: CheckedContinuation<PermissionState, Never>?
        let model = PermissionSettingsModel(readState: { _ in
            await withCheckedContinuation { pendingRead = $0 }
        }, requestAccess: { _ in .authorized })
        let refresh = Task { await model.refresh() }
        while pendingRead == nil { await Task.yield() }
        await model.request(.calendar)
        guard model.states[.calendar] == .authorized, model.requesting == nil else {
            fatalError("successful request did not immediately update permission status")
        }
        pendingRead?.resume(returning: .notDetermined)
        await refresh.value
        guard model.states[.calendar] == .authorized else {
            fatalError("stale background read overwrote the completed request")
        }
    }

    /// Simulate permission changes without granting real TCC access or opening System Settings.
    private static func assertStandaloneAuthorizationFlow(parent: NSWindow) async throws {
        for regrant in [false, true] {
            var reads = 0
            var opened = 0
            var dismissed = 0
            var resets = 0
            let controller = PermissionAuthorizationWindow(readState: { _ in
                reads += 1
                if regrant {
                    return reads == 3 ? .denied : .authorized
                }
                return reads < 3 ? .denied : .authorized
            }, openSettings: { _ in
                opened += 1
                return PermissionAuthorizationSettingsHandle(windowFrame: { parent.frame }, dismiss: { dismissed += 1 })
            }, resetAuthorization: { _ in resets += 1 })
            controller.show(.accessibility, colorScheme: .light)
            try await Task.sleep(for: .milliseconds(150))
            guard let panel = controller.window, panel.isVisible,
                  panel.sheetParent == nil, parent.attachedSheet == nil,
                  panel.styleMask.contains(.nonactivatingPanel),
                  panel.level == .floating, !panel.hidesOnDeactivate,
                  opened == 1, dismissed == 0,
                  resets == (regrant ? 0 : 1) else {
                fatalError("authorization is modal or dismissed before a fresh grant")
            }
            for _ in 0..<30 where controller.window != nil {
                try await Task.sleep(for: .milliseconds(100))
            }
            guard controller.window == nil, dismissed == 1 else {
                fatalError("authorization completion failed to close the panel and its settings session")
            }
        }
        var pendingReset: CheckedContinuation<Void, Never>?
        var openedWhilePreparing = false
        let preparing = PermissionAuthorizationWindow(readState: { _ in .denied },
            openSettings: { _ in
                openedWhilePreparing = true
                return PermissionAuthorizationSettingsHandle(windowFrame: { parent.frame }, dismiss: {})
            }, resetAuthorization: { _ in
                await withCheckedContinuation { pendingReset = $0 }
            })
        preparing.show(.screenRecording, colorScheme: .light)
        while pendingReset == nil { await Task.yield() }
        guard !openedWhilePreparing else { fatalError("settings opened before stale entry reset completed") }
        // Closing while the reset is pending must not reopen settings when it returns.
        preparing.cancel()
        pendingReset?.resume()
        try await Task.sleep(for: .milliseconds(150))
        guard preparing.window == nil, !openedWhilePreparing else {
            fatalError("cancelled reset reopened the authorization flow")
        }
        var dismissed = false
        let cancelled = PermissionAuthorizationWindow(readState: { _ in .denied },
            openSettings: { _ in
                PermissionAuthorizationSettingsHandle(windowFrame: { parent.frame }, dismiss: { dismissed = true })
            }, resetAuthorization: { _ in })
        cancelled.show(.screenRecording, colorScheme: .dark)
        try await Task.sleep(for: .milliseconds(150))
        cancelled.window?.close()
        try await Task.sleep(for: .milliseconds(600))
        guard cancelled.window == nil, !dismissed else {
            fatalError("cancelling authorization should stop observation without dismissing System Settings")
        }
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
