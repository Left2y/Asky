import AppKit
import SwiftUI
import Resources

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
    private var reminders: ProactiveReminders!
    private var hotKey: HotKey?
    private var hotKeyStatus = ""
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var pressure: MemoryPressureMonitor?
    private var terminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        do { model = try AppModel() } catch {
            let alert = NSAlert()
            alert.messageText = "KulaHere 无法打开本地数据"
            alert.informativeText = "\(error)"
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        launcherModel = LauncherModel(app: model)
        launcher = LauncherController(model: launcherModel)
        agentWindow = AgentWindowController(model: AgentModel(app: model))
        model.onModelAuthenticationFinished = { [weak self] in
            self?.agentWindow.restoreAfterAuthentication()
        }
        launcherModel.onAskAI = { [weak self] prompt in
            self?.launcher.hide()
            self?.agentWindow.show(prompt: prompt)
        }

        do {
            hotKey = try HotKey { [weak self] in self?.launcher.toggle() }
            hotKeyStatus = "已注册。"
        } catch HotKey.Failure.alreadyInUse {
            hotKeyStatus = "⌥Space 已被其他应用占用；请从菜单栏图标打开启动器。"
        } catch {
            hotKeyStatus = "快捷键注册失败：\(error)"
        }

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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating, let model else { return .terminateNow }
        terminating = true
        clipboard?.stop()
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

    // MARK: Menu bar

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: "KulaHere")
        let menu = NSMenu()
        menu.addItem(withTitle: "打开启动器", action: #selector(openLauncher), keyEquivalent: "").target = self
        menu.addItem(withTitle: "AI 对话", action: #selector(openAgent), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 KulaHere", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func openLauncher() { launcher.show() }
    @objc private func openAgent() { agentWindow.show() }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
            w.title = "KulaHere 设置"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(app: model, hotKeyStatus: hotKeyStatus))
            w.center()
            settingsWindow = w
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
