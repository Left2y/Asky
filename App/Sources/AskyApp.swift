import AppKit
import SwiftUI
import Resources
import Carbon.HIToolbox
import ToolService

@main
@MainActor
enum AskyMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        _ = delegate
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: AppModel!
    private var launcher: LauncherController!
    private var launcherModel: LauncherModel!
    private var agentWindow: AgentWindowController!
    private var clipboard: ClipboardMonitor!
    private var clipboardWindow: ClipboardController!
    private var clipboardHotKey: HotKey?
    private var reminders: ProactiveReminders!
    private var hotKey: HotKey?
    private var newAgentHotKey: HotKey?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var pressure: MemoryPressureMonitor?
    private let termination = ApplicationTermination()
    private let windowPresentation = WindowPresentation()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppInstallationPrompt.handleLaunchIfNeeded() else { return }
        do { model = try AppModel() } catch {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Asky 无法打开本地数据", comment: "")
            alert.informativeText = "\(error)"
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        model.onOpenSettings = { [weak self] in self?.openSettings() }
        EditMenu.install()
        launcherModel = LauncherModel(app: model)
        launcher = LauncherController(model: launcherModel)
        launcher.onOpenSettings = { [weak self] in self?.openSettings() }
        agentWindow = AgentWindowController(model: AgentModel(app: model), presentation: windowPresentation)
        model.onModelAuthenticationStarted = { [weak self] in
            self?.agentWindow.prepareForAuthentication()
        }
        model.onModelAuthenticationFinished = { [weak self] in
            self?.agentWindow.restoreAfterAuthentication()
        }
        launcherModel.onAskAI = { [weak self] prompt in
            self?.launcher.hide()
            self?.agentWindow.show(prompt: prompt)
        }

        NSApp.appearance = model.preferences.appearance == "system" ? nil : NSAppearance(named: model.preferences.appearance == "dark" ? .darkAqua : .aqua)
        model.onHotKeyChange = { [weak self] code, modifiers in self?.registerHotKey(code: code, modifiers: modifiers) ?? false }
        _ = registerHotKey(code: model.preferences.hotKeyCode, modifiers: model.preferences.hotKeyModifiers)

        clipboardWindow = ClipboardController(app: model)
        model.onClipboardHotKeyChange = { [weak self] code, modifiers in self?.registerClipboardHotKey(code: code, modifiers: modifiers) ?? false }
        _ = registerClipboardHotKey(code: model.preferences.clipboardHotKeyCode, modifiers: model.preferences.clipboardHotKeyModifiers)
        model.onAgentHotKeyChange = { [weak self] code, modifiers in self?.registerAgentHotKey(code: code, modifiers: modifiers) ?? false }
        _ = registerAgentHotKey(code: model.preferences.agentHotKeyCode, modifiers: model.preferences.agentHotKeyModifiers)
        installStatusItem()
        clipboard = ClipboardMonitor(app: model)
        clipboard.start()
        reminders = ProactiveReminders(app: model)
        model.onSettingsChange = { [weak self] in self?.reminders.schedule() }
        pressure = MemoryPressureMonitor { [weak self] _ in
            Task { @MainActor in self?.launcher.hide() }
        }
        #if DEBUG
        if CommandLine.arguments.contains("--test-clipboard") {
            clipboardWindow.pinned = true
            clipboardWindow.show()
            clipboardWindow.query = ProcessInfo.processInfo.environment["ASKY_CLIPBOARD_TEST_QUERY"] ?? ""
        }
        #endif
        Task {
            await model.start()
            reminders.start()
            #if DEBUG
            if CommandLine.arguments.contains("--test-notification") {
                do { try await NotificationPreview.send() }
                catch {
                    let alert = NSAlert()
                    alert.messageText = "测试通知未发送"
                    alert.informativeText = error.localizedDescription
                    NSApp.activate()
                    alert.runModal()
                }
            }
            #endif
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard model != nil else { return true }
        if let settingsWindow, settingsWindow.isVisible {
            windowPresentation.show(settingsWindow)
        } else {
            openLauncher()
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        return termination.request { [self] in
            clipboard?.stop()
            clipboardWindow?.hide()
            clipboardHotKey?.unregister()
            reminders?.stop()
            newAgentHotKey?.unregister()
            hotKey?.unregister()
            model.confirmations.rejectAll()
            // Pi and its process group must be gone before the app exits (no orphans).
            await model.shutdown()
        }
    }

    private func registerHotKey(code: UInt32, modifiers: UInt32) -> Bool {
        let previous = model.preferences
        hotKey?.unregister()
        do {
            hotKey = try HotKey(keyCode: code, modifiers: modifiers) { [weak self] in self?.launcher.toggle() }
            model.hotKeyStatus = NSLocalizedString("已注册", comment: "")
            return true
        } catch {
            model.hotKeyStatus = NSLocalizedString("组合键已被占用或无法注册，请选择其他快捷键。", comment: "")
            hotKey = try? HotKey(keyCode: previous.hotKeyCode, modifiers: previous.hotKeyModifiers) { [weak self] in self?.launcher.toggle() }
            return false
        }
    }

    private func registerClipboardHotKey(code: UInt32, modifiers: UInt32) -> Bool {
        let previous = model.preferences
        let action: () -> Void = { [weak self] in
            self?.launcher.hide()
            self?.clipboardWindow.toggle()
        }
        clipboardHotKey?.unregister()
        do {
            clipboardHotKey = try HotKey(keyCode: code, modifiers: modifiers, action: action)
            model.clipboardHotKeyStatus = NSLocalizedString("已注册", comment: "")
            return true
        } catch HotKey.Failure.alreadyInUse {
            model.clipboardHotKeyStatus = NSLocalizedString("组合键已被占用，请选择其他快捷键，或从菜单栏打开剪贴板。", comment: "")
        } catch {
            model.clipboardHotKeyStatus = String(format: NSLocalizedString("快捷键注册失败：%@。请选择其他快捷键，或从菜单栏打开剪贴板。", comment: ""), String(describing: error))
        }
        if code != previous.clipboardHotKeyCode || modifiers != previous.clipboardHotKeyModifiers {
            clipboardHotKey = try? HotKey(keyCode: previous.clipboardHotKeyCode, modifiers: previous.clipboardHotKeyModifiers, action: action)
        } else {
            clipboardHotKey = nil
        }
        return false
    }

    private func registerAgentHotKey(code: UInt32, modifiers: UInt32) -> Bool {
        let previous = model.preferences
        let action: () -> Void = { [weak self] in self?.openNewAgentConversation() }
        newAgentHotKey?.unregister()
        do {
            newAgentHotKey = try HotKey(keyCode: code, modifiers: modifiers, action: action)
            model.agentHotKeyStatus = NSLocalizedString("已注册", comment: "")
            return true
        } catch HotKey.Failure.alreadyInUse {
            model.agentHotKeyStatus = NSLocalizedString("组合键已被占用，请选择其他快捷键，或从菜单栏打开 AI 对话。", comment: "")
        } catch {
            model.agentHotKeyStatus = String(format: NSLocalizedString("快捷键注册失败：%@。请选择其他快捷键，或从菜单栏打开 AI 对话。", comment: ""), String(describing: error))
        }
        if code != previous.agentHotKeyCode || modifiers != previous.agentHotKeyModifiers {
            newAgentHotKey = try? HotKey(keyCode: previous.agentHotKeyCode, modifiers: previous.agentHotKeyModifiers, action: action)
        } else {
            newAgentHotKey = nil
        }
        return false
    }

    // MARK: Menu bar

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(named: "StatusIcon")
        icon?.size = NSSize(width: 14, height: 14)
        icon?.isTemplate = true
        icon?.accessibilityDescription = "Asky"
        item.button?.image = icon
        item.button?.setAccessibilityLabel("Asky")
        let menu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("打开启动器", comment: ""), action: #selector(openLauncher), keyEquivalent: "").target = self
        menu.addItem(withTitle: NSLocalizedString("剪贴板历史", comment: ""), action: #selector(openClipboard), keyEquivalent: "").target = self
        menu.addItem(withTitle: NSLocalizedString("AI 对话", comment: ""), action: #selector(openAgent), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: NSLocalizedString("设置…", comment: ""), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: NSLocalizedString("退出 Asky", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func openLauncher() { clipboardWindow.hide(); launcher.show() }
    @objc private func openClipboard() { launcher.hide(); clipboardWindow.show() }
    @objc private func openAgent() {
        launcher.hide()
        agentWindow.show()
    }

    private func openNewAgentConversation() {
        launcher.hide()
        clipboardWindow.hide()
        agentWindow.showNewConversation()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === settingsWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = SettingsWindow.make(app: model)
            w.level = .normal
            w.collectionBehavior = [.moveToActiveSpace, .primary]
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            settingsWindow = w
        }
        launcher.hide()
        clipboardWindow.hide()
        NSApp.setActivationPolicy(.regular)
        if let settingsWindow { windowPresentation.show(settingsWindow) }
    }
}
