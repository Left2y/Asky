import AppKit
import SwiftUI
import Resources
import Carbon.HIToolbox
import ToolService
import Contracts
import ServiceManagement

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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
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
        #if DEBUG
        if CommandLine.arguments.contains("--test-confirmations") {
            // Exercise the real shared UI without starting the model or executing tools.
            let confirmations = ConfirmationCenter()
            Task { @MainActor in
                let previews: [(String, CallerOrigin)] = [
                    ("plugin_lark__execute", .agent(sessionID: "preview")),
                    ("calendar_update_event", .agent(sessionID: "preview")),
                    ("messages_prepare_draft", .agent(sessionID: "preview")),
                    ("notes_append", .mcp(instanceID: "preview"))
                ]
                for (tool, origin) in previews {
                    let decision = await confirmations.present(ConfirmationRequest(
                        requestID: UUID().uuidString, tool: tool,
                        target: "样式预览：不会执行真实操作",
                        changes: tool == "plugin_lark__execute" ? ["标题：示例"] : ["内容：样式预览"],
                        argumentsDigest: "preview", origin: origin,
                        title: tool == "plugin_lark__execute" ? "通过飞书创建知识库内容？" : nil,
                        details: tool == "plugin_lark__execute" ? #"{"argv":["wiki","spaces","node-create","--data","{\"title\":\"示例\"}"]}"# : nil))
                    print("confirmation-preview \(tool): \(decision.rawValue)")
                }
                for title in ["安装可信插件", "安装新版本？", "图片下载失败"] {
                    let alert = AppDialog.make()
                    alert.messageText = NSLocalizedString(title, comment: "")
                    alert.informativeText = "样式预览：不会安装、更新或下载。"
                    alert.addButton(withTitle: NSLocalizedString("好", comment: ""))
                    NSApp.activate()
                    _ = alert.runModal()
                }
                NSApp.terminate(nil)
            }
            return
        }
        #endif
        guard !AppInstallationPrompt.handleLaunchIfNeeded() else { return }
        do { model = try AppModel() } catch {
            let alert = AppDialog.make()
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
        model.onMenuBarIconVisibilityChange = { [weak self] visible in
            self?.statusItem?.isVisible = visible
        }
        clipboard = ClipboardMonitor(app: model)
        clipboard.start()
        reminders = ProactiveReminders(app: model)
        model.onSettingsChange = { [weak self] in self?.reminders.schedule() }
        model.updater.isQuiet = { [weak self] in self?.isQuietForUpdate ?? false }
        ToolService.removeStaleAppUpdates()
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
                    let alert = AppDialog.make()
                    alert.messageText = "测试通知未发送"
                    alert.informativeText = error.localizedDescription
                    NSApp.activate()
                    alert.runModal()
                }
            }
            #endif
        }
    }

    /// Silent relaunch only when nothing is open, running or waiting for the user.
    private var isQuietForUpdate: Bool {
        !launcher.isVisible && !clipboardWindow.isVisible && !agentWindow.isVisible && !agentWindow.model.isRunning
            && settingsWindow?.isVisible != true && model.confirmations.queue.isEmpty
            && !model.terminal.isRunning && !model.isMCPBusy
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
        menu.delegate = self
        item.menu = menu
        item.isVisible = model.preferences.showMenuBarIcon
        statusItem = item
    }

    /// Rebuilt on every open so check marks always mirror the current settings.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusItem?.menu else { return }
        menu.removeAllItems()
        add(menu, "打开启动器", #selector(openLauncher))
        add(menu, "剪贴板历史", #selector(openClipboard))
        add(menu, "AI 对话", #selector(openAgent))
        menu.addItem(.separator())
        add(menu, "记录剪贴板历史", #selector(toggleClipboardRecording), on: model.settings.clipboardEnabled)
        add(menu, "允许 AI 搜索公开网页", #selector(toggleWebSearch), on: model.settings.webSearchEnabled != false)
        add(menu, "主动提醒", #selector(toggleProactiveReminders), on: model.settings.proactiveReminders)
        let approval = submenu(menu, "AI 审批模式")
        let mode = model.settings.approvalMode ?? .autoReview
        for (option, title) in [(ApprovalMode.autoReview, "自动审批"), (.fullAccess, "完全访问")] {
            add(approval, title, #selector(selectApprovalMode(_:)), on: mode == option).representedObject = option.rawValue
        }
        let appearance = submenu(menu, "外观")
        for (value, title) in [("system", "跟随系统"), ("light", "浅色"), ("dark", "深色")] {
            add(appearance, title, #selector(selectAppearance(_:)), on: model.preferences.appearance == value).representedObject = value
        }
        add(menu, "登录时启动", #selector(toggleLaunchAtLogin), on: SMAppService.mainApp.status == .enabled)
        menu.addItem(.separator())
        add(menu, "设置…", #selector(openSettings), key: ",")
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: NSLocalizedString("退出 Asky", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        hideAutomaticImage(quit)
    }

    /// macOS 27 auto-attaches SF Symbols to items whose (English) titles it recognizes, e.g. "Settings…".
    private func hideAutomaticImage(_ item: NSMenuItem) {
        if #available(macOS 27.0, *) { item.preferredImageVisibility = .hidden }
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "", on: Bool? = nil) -> NSMenuItem {
        let item = menu.addItem(withTitle: NSLocalizedString(title, comment: ""), action: action, keyEquivalent: key)
        item.target = self
        if let on { item.state = on ? .on : .off }
        hideAutomaticImage(item)
        return item
    }

    private func submenu(_ menu: NSMenu, _ title: String) -> NSMenu {
        let item = menu.addItem(withTitle: NSLocalizedString(title, comment: ""), action: nil, keyEquivalent: "")
        hideAutomaticImage(item)
        let sub = NSMenu()
        item.submenu = sub
        return sub
    }

    @objc private func toggleClipboardRecording() { model.settings.clipboardEnabled.toggle() }
    @objc private func toggleWebSearch() { model.settings.webSearchEnabled = model.settings.webSearchEnabled == false }
    @objc private func toggleProactiveReminders() { model.settings.proactiveReminders.toggle() }
    @objc private func selectApprovalMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = ApprovalMode(rawValue: raw) else { return }
        model.settings.approvalMode = mode
    }
    @objc private func selectAppearance(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        model.preferences.appearance = value
    }
    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let alert = AppDialog.make()
            alert.messageText = NSLocalizedString("无法更改登录时启动", comment: "")
            alert.informativeText = error.localizedDescription
            NSApp.activate()
            alert.runModal()
        }
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
