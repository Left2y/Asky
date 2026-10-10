import AppKit
import SwiftUI
import Resources
import Carbon.HIToolbox

@main
@MainActor
enum KulaHereMain {
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
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var launcher: LauncherController!
    private var launcherModel: LauncherModel!
    private var agentWindow: AgentWindowController!
    private var clipboard: ClipboardMonitor!
    private var clipboardWindow: ClipboardController!
    private var clipboardHotKey: HotKey?
    private var reminders: ProactiveReminders!
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var pressure: MemoryPressureMonitor?
    private var terminating = false
    private let windowPresentation = WindowPresentation()

    func applicationDidFinishLaunching(_ notification: Notification) {
        do { model = try AppModel() } catch {
            let alert = NSAlert()
            alert.messageText = "KulaHere 无法打开本地数据"
            alert.informativeText = "\(error)"
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        model.onOpenSettings = { [weak self] in self?.openSettings() }
        launcherModel = LauncherModel(app: model)
        launcher = LauncherController(model: launcherModel)
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
        installStatusItem()
        clipboard = ClipboardMonitor(app: model)
        clipboard.start()
        reminders = ProactiveReminders(app: model)
        model.onSettingsChange = { [weak self] in self?.reminders.schedule() }
        pressure = MemoryPressureMonitor { [weak self] _ in
            Task { @MainActor in self?.launcher.hide() }
        }
        Task {
            await model.start()
            reminders.start()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        agentWindow?.show()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating, let model else { return .terminateNow }
        terminating = true
        clipboard?.stop()
        clipboardWindow?.hide()
        clipboardHotKey?.unregister()
        reminders?.stop()
        hotKey?.unregister()
        model.confirmations.rejectAll()
        // Pi and its process group must be gone before the app exits (no orphans).
        Task {
            await model.shutdown()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func registerHotKey(code: UInt32, modifiers: UInt32) -> Bool {
        let previous = model.preferences
        hotKey?.unregister()
        do {
            hotKey = try HotKey(keyCode: code, modifiers: modifiers) { [weak self] in self?.launcher.toggle() }
            model.hotKeyStatus = "已注册"
            return true
        } catch {
            model.hotKeyStatus = "组合键已被占用或无法注册，请选择其他快捷键。"
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
            model.clipboardHotKeyStatus = "已注册"
            return true
        } catch HotKey.Failure.alreadyInUse {
            model.clipboardHotKeyStatus = "组合键已被占用，请选择其他快捷键，或从菜单栏打开剪贴板。"
        } catch {
            model.clipboardHotKeyStatus = "快捷键注册失败：\(error)。请选择其他快捷键，或从菜单栏打开剪贴板。"
        }
        if code != previous.clipboardHotKeyCode || modifiers != previous.clipboardHotKeyModifiers {
            clipboardHotKey = try? HotKey(keyCode: previous.clipboardHotKeyCode, modifiers: previous.clipboardHotKeyModifiers, action: action)
        } else {
            clipboardHotKey = nil
        }
        return false
    }

    // MARK: Menu bar

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(named: "StatusIcon")
        icon?.size = NSSize(width: 18, height: 18)
        icon?.isTemplate = true
        icon?.accessibilityDescription = "KulaHere"
        item.button?.image = icon
        item.button?.setAccessibilityLabel("KulaHere")
        let menu = NSMenu()
        menu.addItem(withTitle: "打开启动器", action: #selector(openLauncher), keyEquivalent: "").target = self
        menu.addItem(withTitle: "剪贴板历史", action: #selector(openClipboard), keyEquivalent: "").target = self
        menu.addItem(withTitle: "AI 对话", action: #selector(openAgent), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 KulaHere", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func openLauncher() { clipboardWindow.hide(); launcher.show() }
    @objc private func openClipboard() { launcher.hide(); clipboardWindow.show() }
    @objc private func openAgent() {
        launcher.hide()
        agentWindow.show()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
            w.title = "KulaHere 设置"
            w.level = .normal
            w.collectionBehavior = [.moveToActiveSpace, .primary]
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(app: model))
            w.center()
            settingsWindow = w
        }
        launcher.hide()
        if let settingsWindow { windowPresentation.show(settingsWindow) }
    }
}
