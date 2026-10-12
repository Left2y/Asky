import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import Contracts
import LocalStore
import DirectActions
import Memory
import MCPGateway
import Adapters
import Theme
import ToolService

struct SettingsView: View {
    @Bindable var app: AppModel
    var body: some View {
        Group {
            switch SettingsPage.resolve(app.settingsTab) {
            case .model: ModelSettingsView(app: app)
            case .hotkey: HotKeySettings(app: app)
            case .aliases: AliasSettings(app: app)
            case .keywords: CommandSettings(app: app)
            case .general: GeneralSettings(app: app)
            case .sources: SourceSettings(app: app)
            case .permissions: PermissionSettings(app: app)
            case .memory: MemorySettings(app: app)
            case .mcp: MCPSettings(app: app)
            case .plugins: PluginSettings(app: app)
            case .about: AboutSettings()
            case .author: AuthorSettings()
            }
        }
        .toggleStyle(.switch)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HotKeySettings: View {
    @Bindable var app: AppModel
    var body: some View {
        Form {
            Section(NSLocalizedString("触发快捷键", comment: "")) {
                LabeledContent(NSLocalizedString("唤起启动器", comment: "")) {
                    HotKeyRecorder(label: app.preferences.hotKeyLabel, apply: setLauncher).frame(width: 240, height: 34)
                }
                if !app.hotKeyStatus.isEmpty, app.hotKeyStatus != NSLocalizedString("已注册", comment: "") {
                    Text(app.hotKeyStatus).foregroundStyle(.secondary)
                }
                Button(NSLocalizedString("恢复默认", comment: "")) { setLauncher(UInt32(kVK_Space), UInt32(optionKey), "⌥ Space") }
            }
            Section(NSLocalizedString("剪贴板", comment: "")) {
                LabeledContent(NSLocalizedString("打开剪贴板历史", comment: "")) {
                    HotKeyRecorder(label: app.preferences.clipboardHotKeyLabel, apply: setClipboard).frame(width: 240, height: 34)
                }
                if !app.clipboardHotKeyStatus.isEmpty, app.clipboardHotKeyStatus != NSLocalizedString("已注册", comment: "") {
                    Text(app.clipboardHotKeyStatus).foregroundStyle(.secondary)
                }
                let d = SettingsPreferences.defaultClipboardHotKey
                Button(NSLocalizedString("恢复默认", comment: "")) { setClipboard(d.code, d.modifiers, d.label) }
            }
            Section(NSLocalizedString("AI 对话", comment: "")) {
                LabeledContent(NSLocalizedString("打开 AI 对话", comment: "")) {
                    HotKeyRecorder(label: app.preferences.agentHotKeyLabel, apply: setAgent).frame(width: 240, height: 34)
                }
                if !app.agentHotKeyStatus.isEmpty, app.agentHotKeyStatus != NSLocalizedString("已注册", comment: "") {
                    Text(app.agentHotKeyStatus).foregroundStyle(.secondary)
                }
                let d = SettingsPreferences.defaultAgentHotKey
                Button(NSLocalizedString("恢复默认", comment: "")) { setAgent(d.code, d.modifiers, d.label) }
            }
        }.formStyle(.grouped)
    }

    @discardableResult private func setAgent(_ code: UInt32, _ modifiers: UInt32, _ label: String) -> Bool {
        guard app.onAgentHotKeyChange?(code, modifiers) == true else { return false }
        app.preferences.agentHotKeyCode = code
        app.preferences.agentHotKeyModifiers = modifiers
        app.preferences.agentHotKeyLabel = label
        return true
    }

    @discardableResult private func setLauncher(_ code: UInt32, _ modifiers: UInt32, _ label: String) -> Bool {
        guard app.onHotKeyChange?(code, modifiers) == true else { return false }
        app.preferences.hotKeyCode = code
        app.preferences.hotKeyModifiers = modifiers
        app.preferences.hotKeyLabel = label
        return true
    }

    @discardableResult private func setClipboard(_ code: UInt32, _ modifiers: UInt32, _ label: String) -> Bool {
        guard app.onClipboardHotKeyChange?(code, modifiers) == true else { return false }
        app.preferences.clipboardHotKeyCode = code
        app.preferences.clipboardHotKeyModifiers = modifiers
        app.preferences.clipboardHotKeyLabel = label
        return true
    }
}

private struct HotKeyRecorder: NSViewRepresentable {
    let label: String
    let apply: (UInt32, UInt32, String) -> Bool
    func makeNSView(context: Context) -> Recorder { Recorder(label: label, apply: apply) }
    func updateNSView(_ view: Recorder, context: Context) {
        view.label = label
        view.apply = apply
        if !view.recording { view.title = label }
        view.setAccessibilityLabel(String(format: NSLocalizedString("快捷键 %@，点击录制", comment: ""), label))
    }
    final class Recorder: NSButton {
        var label: String
        var apply: (UInt32, UInt32, String) -> Bool
        var recording = false
        override var acceptsFirstResponder: Bool { true }
        init(label: String, apply: @escaping (UInt32, UInt32, String) -> Bool) {
            self.label = label
            self.apply = apply
            super.init(frame: .zero)
            bezelStyle = .rounded
            target = self
            action = #selector(begin)
            title = label
            toolTip = NSLocalizedString("录制快捷键", comment: "")
            setAccessibilityLabel(String(format: NSLocalizedString("快捷键 %@，点击录制", comment: ""), label))
        }
        required init?(coder: NSCoder) { fatalError() }
        @objc func begin() { recording = true; title = NSLocalizedString("按下组合键，Esc 取消", comment: ""); window?.makeFirstResponder(self) }
        override func resignFirstResponder() -> Bool {
            recording = false
            title = label
            return super.resignFirstResponder()
        }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard recording else { return super.performKeyEquivalent(with: event) }
            keyDown(with: event)
            return true
        }
        override func keyDown(with event: NSEvent) {
            guard recording else { return }
            if event.keyCode == 53 { window?.makeFirstResponder(nil); return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.intersection([.command, .option, .control]).isEmpty else {
                title = NSLocalizedString("请包含 ⌘、⌥ 或 ⌃", comment: ""); return
            }
            var modifiers: UInt32 = 0
            var label = ""
            for (flag, carbon, symbol) in [(NSEvent.ModifierFlags.control, controlKey, "⌃"), (.option, optionKey, "⌥"), (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")] {
                if flags.contains(flag) { modifiers |= UInt32(carbon); label += symbol }
            }
            label += " " + Self.keyName(event)
            if apply(UInt32(event.keyCode), modifiers, label) {
                window?.makeFirstResponder(nil)
            } else {
                title = NSLocalizedString("已被占用，换一个组合键", comment: "")
            }
        }
        // charactersIgnoringModifiers is mangled by ⌥ (e.g. ⌥V → √), so use the layout-independent key name where possible.
        static func keyName(_ event: NSEvent) -> String {
            let special: [Int: String] = [kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab", kVK_Delete: "Delete",
                                          kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
                                          kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
                                          kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"]
            if let name = special[Int(event.keyCode)] { return name }
            let chars = event.characters(byApplyingModifiers: []) ?? event.charactersIgnoringModifiers ?? ""
            return chars.isEmpty ? "Key \(event.keyCode)" : chars.uppercased()
        }
    }
}

// MARK: General

private struct GeneralSettings: View {
    @Bindable var app: AppModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var choosingScope = false

    var body: some View {
        Form {
            Section(NSLocalizedString("启动", comment: "")) {
                Toggle(NSLocalizedString("登录时启动", comment: ""), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister(); loginError = nil }
                        catch { loginError = error.localizedDescription; launchAtLogin = !on }
                    }
                if let loginError { Text(loginError).foregroundStyle(ThemeColor.kTextNegative) }
            }
            Section(NSLocalizedString("外观", comment: "")) {
                Picker(NSLocalizedString("应用主题", comment: ""), selection: $app.preferences.appearance) {
                    Text(NSLocalizedString("跟随系统", comment: "")).tag("system")
                    Text(NSLocalizedString("浅色", comment: "")).tag("light")
                    Text(NSLocalizedString("深色", comment: "")).tag("dark")
                }
            }
            Section(NSLocalizedString("语言", comment: "")) {
                Picker(NSLocalizedString("应用语言", comment: ""), selection: $app.preferences.language) {
                    Text(NSLocalizedString("跟随系统", comment: "")).tag(ApplicationLanguage.system)
                    Text(verbatim: "简体中文").tag(ApplicationLanguage.simplifiedChinese)
                    Text(verbatim: "English").tag(ApplicationLanguage.english)
                }
                Text(NSLocalizedString("语言更改将在下次启动应用时生效。跟随系统会使用 macOS 的首选语言。", comment: ""))
                    .foregroundStyle(.secondary)
                if app.preferences.language != app.launchLanguage {
                    Text(NSLocalizedString("已保存，下次启动生效。", comment: ""))
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                if app.settings.fileScopes.isEmpty {
                    Text(NSLocalizedString("尚未添加搜索目录", comment: ""))
                        .foregroundStyle(.secondary)
                }
                ForEach(app.settings.fileScopes, id: \.self) { p in
                    HStack {
                        Label(p, systemImage: "folder")
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(p)
                        Spacer()
                        Button(NSLocalizedString("移除", comment: "")) { app.settings.fileScopes.removeAll { $0 == p } }
                    }
                }
                TextField(NSLocalizedString("排除的目录名（逗号分隔）", comment: ""), text: Binding(
                    get: { app.settings.excludedDirectories.joined(separator: ", ") },
                    set: { app.settings.excludedDirectories = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
            } header: {
                HStack {
                    Text(NSLocalizedString("文件搜索范围", comment: ""))
                    Spacer()
                    Button(NSLocalizedString("添加文件夹…", comment: ""), systemImage: "folder.badge.plus") {
                        choosingScope = true
                        Task { @MainActor in
                            defer { choosingScope = false }
                            guard let folder = await ToolService.chooseLauncherSearchFolder() else { return }
                            let path = folder.path
                            if !app.settings.fileScopes.contains(path) { app.settings.fileScopes.append(path) }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.body)
                    .disabled(choosingScope)
                }
            }
            Section(NSLocalizedString("剪贴板", comment: "")) {
                Toggle(NSLocalizedString("记录剪贴板历史", comment: ""), isOn: $app.settings.clipboardEnabled)
                TextField(NSLocalizedString("排除的应用 Bundle ID（逗号分隔）", comment: ""), text: Binding(
                    get: { app.settings.clipboardExcludedApps.joined(separator: ", ") },
                    set: { app.settings.clipboardExcludedApps = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
                Button(NSLocalizedString("清空未固定的剪贴板历史", comment: ""), role: .destructive) {
                    let store = ClipboardStore(app.store)
                    let ids = store.recent(limit: 100_000).filter { !$0.pinned }.map(\.id)
                    ClipboardMonitor.removeFiles((try? store.delete(ids: ids)) ?? [])
                }
            }
        }
        .formStyle(.grouped)
    }


}

// MARK: Sources

private struct SourceSettings: View {
    @Bindable var app: AppModel
    @State private var availableFolders: [NotesFolder] = []
    @State private var loadingFolders = false
    @State private var foldersLoaded = false
    @State private var folderError: String?

    private var displayedFolders: [NotesFolder] {
        availableFolders + app.settings.notesFolders.filter { !availableFolders.contains($0) }
    }

    private func connectNotes() async {
        guard !loadingFolders else { return }
        loadingFolders = true
        folderError = nil
        defer { loadingFolders = false }
        app.settings.enabledSources.insert(.notes)
        let result = await app.tools.submit(ActionRequest(tool: "notes_list_folders", arguments: .object([:]),
                                                         origin: .launcher, intent: .explicitRequest))
        guard result.status == .completed, let output = result.output else {
            folderError = result.error?.message ?? NSLocalizedString("无法读取备忘录文件夹，请重试。", comment: "")
            return
        }
        do {
            availableFolders = try JSONDecoder().decode([NotesFolder].self, from: output.canonicalData())
            foldersLoaded = true
            // Refresh identifiers for existing selections without expanding their access scope.
            app.settings.notesFolders = app.settings.notesFolders.map { saved in
                availableFolders.first(where: { $0.matchesLocation(saved) }) ?? saved
            }
        } catch {
            folderError = NSLocalizedString("无法读取备忘录文件夹，请重试。", comment: "")
        }
    }

    static let labels: [(DataSourceID, String)] = [
        (.calendar, NSLocalizedString("日历", comment: "")), (.reminders, NSLocalizedString("提醒事项", comment: "")), (.notes, NSLocalizedString("备忘录", comment: "")), (.contacts, NSLocalizedString("通讯录", comment: "")), (.chrome, NSLocalizedString("Chrome 标签与书签", comment: "")),
        (.shortcuts, NSLocalizedString("快捷指令", comment: "")), (.messages, NSLocalizedString("信息（仅草稿交接）", comment: "")), (.memory, NSLocalizedString("个人记忆", comment: "")), (.maps, NSLocalizedString("路线时间（MapKit）", comment: "")),
    ]

    var body: some View {
        Form {
            Section(NSLocalizedString("AI 与工具可使用的来源", comment: "")) {
                ForEach(Self.labels, id: \.0) { id, label in
                    Toggle(isOn: Binding(
                        get: { app.settings.enabledSources.contains(id) },
                        set: { on in if on { app.settings.enabledSources.insert(id) } else { app.settings.enabledSources.remove(id) } })) {
                        HStack(spacing: 8) {
                            sourceIcon(id)
                                .frame(width: 24, height: 24)
                                .accessibilityHidden(true)
                            Text(label)
                        }
                    }
                }
            }
            Section(NSLocalizedString("授权的备忘录文件夹", comment: "")) {
                HStack {
                    Button(NSLocalizedString(foldersLoaded ? "刷新文件夹" : "连接备忘录", comment: "")) {
                        Task { await connectNotes() }
                    }
                    .disabled(loadingFolders)
                    if loadingFolders { ProgressView().controlSize(.small) }
                }
                Text(NSLocalizedString("连接后自动读取账户和文件夹。勾选允许 Asky 访问的文件夹，选择会自动保存；不会读取未勾选文件夹中的备忘录内容。", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(Set(displayedFolders.map(\.account))).sorted(), id: \.self) { account in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(account).font(.headline)
                        ForEach(displayedFolders.filter { $0.account == account }, id: \.self) { folder in
                            Toggle(isOn: Binding(
                                get: { app.settings.notesFolders.contains(folder) },
                                set: { selected in
                                    app.settings.notesFolders.removeAll { $0 == folder }
                                    if selected { app.settings.notesFolders.append(folder) }
                                })) {
                                HStack {
                                    Label(folder.folder, systemImage: "folder")
                                    if foldersLoaded && !availableFolders.contains(folder) {
                                        Text(NSLocalizedString("未找到，请取消选择或刷新", comment: "")).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }
                if foldersLoaded && availableFolders.isEmpty {
                    Text(NSLocalizedString("未找到文件夹，请先在 Apple 备忘录中添加账户或创建文件夹，再刷新。", comment: ""))
                        .foregroundStyle(.secondary)
                }
                if let folderError {
                    Text(folderError).foregroundStyle(.red)
                    Button(NSLocalizedString("打开自动化权限设置…", comment: "")) {
                        do { try SystemPermissions.openSettings(.automation) }
                        catch { self.folderError = error.localizedDescription }
                    }
                }
            }

            Section(NSLocalizedString("系统权限", comment: "")) {
                Button(NSLocalizedString("管理系统权限…", comment: "")) { app.openSettings(permissions: true) }
            }
            Section(NSLocalizedString("情境提醒", comment: "")) {
                Toggle(NSLocalizedString("主动提醒（冲突、出行准备、重要日期）", comment: ""), isOn: $app.settings.proactiveReminders)
                Toggle(NSLocalizedString("后台 AI 判断（默认关闭）", comment: ""), isOn: $app.settings.backgroundAI)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private func sourceIcon(_ source: DataSourceID) -> some View {
        DataSourceIcon(source: source)
    }
}

// MARK: Model

private struct ModelSettingsView: View {
    let app: AppModel
    @State private var provider = "custom"
    @State private var baseURL = ""
    @State private var model = ""
    @State private var key = ""
    @State private var message: String?
    @State private var capabilities: ModelCapabilities?
    @State private var checking = false
    @State private var saving = false
    @State private var saved = false
    @State private var checked = false

    var body: some View {
        Form {
            Section(NSLocalizedString("供应商与模型", comment: "")) {
                Picker(NSLocalizedString("供应商", comment: ""), selection: Binding(get: { provider }, set: { value in
                    provider = value
                    if value == "openai" { baseURL = "https://api.openai.com/v1"; model = "" }
                    if value == "deepseek" { baseURL = "https://api.deepseek.com"; model = "" }
                })) {
                    Text(NSLocalizedString("自定义（OpenAI 兼容）", comment: "")).tag("custom")
                    Text("OpenAI").tag("openai")
                    Text("DeepSeek").tag("deepseek")
                }

                TextField(NSLocalizedString("API 地址", comment: ""), text: $baseURL, prompt: Text("https://api.example.com/v1"))
                TextField(NSLocalizedString("模型名", comment: ""), text: $model)
                SecureField(NSLocalizedString("API Key（留空保留已保存的 Key）", comment: ""), text: $key)
            }
            Section {
                HStack {
                    Button { Task { await save() } } label: {
                        Text(NSLocalizedString("保存", comment: ""))
                            .opacity(saved || saving ? 0 : 1)
                            .overlay {
                                if saved { Image(systemName: "checkmark") }
                                else if saving { ProgressView().controlSize(.small) }
                            }
                    }
                    .disabled(saving || saved || checking)
                    .accessibilityLabel(saved ? NSLocalizedString("已保存", comment: "") : NSLocalizedString("保存", comment: ""))
                    Button { Task { await check() } } label: {
                        Text(NSLocalizedString("检查已保存配置", comment: ""))
                            .opacity(checked || checking ? 0 : 1)
                            .overlay {
                                if checked { Image(systemName: "checkmark") }
                                else if checking { Text(NSLocalizedString("检查中…", comment: "")) }
                            }
                    }
                    .disabled(checking || checked || saving || app.modelConfiguration == nil)
                    .accessibilityLabel(checked ? NSLocalizedString("检查完成", comment: "") : checking ? NSLocalizedString("检查中", comment: "") : NSLocalizedString("检查已保存配置", comment: ""))
                }
                if let message { Text(message).foregroundStyle(ThemeColor.kTextNegative) }
                if let c = capabilities ?? app.modelConfiguration?.capabilities {
                    LabeledContent(NSLocalizedString("文本", comment: ""), value: capabilityLabel(c.text))
                    LabeledContent(NSLocalizedString("工具调用", comment: ""), value: capabilityLabel(c.tools))
                    LabeledContent(NSLocalizedString("图像输入", comment: ""), value: capabilityLabel(c.image))
                }
            }
        }
        .formStyle(.grouped)
        .task(id: saved) {
            guard saved else { return }
            do { try await Task.sleep(for: .milliseconds(1500)); saved = false }
            catch { }
        }
        .task(id: checked) {
            guard checked else { return }
            do { try await Task.sleep(for: .milliseconds(1500)); checked = false }
            catch { }
        }
        .onAppear {
            provider = app.preferences.provider
            if let c = app.modelConfiguration {
                baseURL = c.baseURL.absoluteString
                model = c.modelName
            }
        }
    }

    private func capabilityLabel(_ value: CapabilityStatus) -> String {
        switch value {
        case .available: NSLocalizedString("可用", comment: "")
        case .unavailable: NSLocalizedString("不可用", comment: "")
        case .unknown: NSLocalizedString("未检查", comment: "")
        }
    }

    private func save() async {
        message = nil
        saving = true
        defer { saving = false }
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1"].contains(host)),
              !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = NSLocalizedString("请填写有效的 https 地址与模型名。", comment: "")
            return
        }
        do {
            if let agent = app.agent, await agent.state == .busy {
                message = NSLocalizedString("请等待当前 AI 任务结束后保存模型设置。", comment: ""); return
            }
            let account = app.modelConfiguration?.credentialRef ?? ModelSettings.keyAccount
            guard !key.isEmpty || app.keychain.contains(account: account) else {
                message = NSLocalizedString("请填写 API Key；留空只会保留已保存的 Key。", comment: "")
                return
            }
            if !key.isEmpty {
                try app.keychain.set(key, account: account)
                await app.credentialSession.remember(key, account: account)
            }
            app.preferences.provider = provider
            app.modelConfiguration = ModelConfiguration(baseURL: url, modelName: model.trimmingCharacters(in: .whitespacesAndNewlines), credentialRef: account)
            key = ""
            await app.agent?.shutdown()
            capabilities = nil
            saved = true
        } catch {
            message = String(format: NSLocalizedString("钥匙串写入失败：%@", comment: ""), String(describing: error))
        }
    }

    private func check() async {
        guard var cfg = app.modelConfiguration else { return }
        message = nil
        checking = true
        defer { checking = false }
        do {
            guard let key = try await app.readModelCredential(account: cfg.credentialRef) else {
                message = NSLocalizedString("请先保存 API Key。", comment: ""); return
            }
            let caps = await ModelCapabilityCheck.run(baseURL: cfg.baseURL, model: cfg.modelName, apiKey: key)
            cfg.capabilities = caps
            app.modelConfiguration = cfg
            capabilities = caps
            checked = true
        } catch { message = error.localizedDescription }
    }

}

/// Three minimal chat-completions probes. A failing probe marks only that capability unavailable.
enum ModelCapabilityCheck {
    static func run(baseURL: URL, model: String, apiKey: String) async -> ModelCapabilities {
        let text = await probe(baseURL, apiKey, ["model": model, "max_tokens": 4,
                                                 "messages": [["role": "user", "content": "ping"]]])
        let tools = await probe(baseURL, apiKey, [
            "model": model, "max_tokens": 16,
            "messages": [["role": "user", "content": "call noop"]],
            "tools": [["type": "function", "function": ["name": "noop", "description": "no-op",
                                                         "parameters": ["type": "object", "properties": [String: String]()]]]],
        ])
        let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        let image = await probe(baseURL, apiKey, [
            "model": model, "max_tokens": 4,
            "messages": [["role": "user", "content": [
                ["type": "text", "text": "color?"],
                ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(png)"]],
            ]]],
        ])
        return ModelCapabilities(text: text ? .available : .unavailable, image: image ? .available : .unavailable,
                                 tools: tools ? .available : .unavailable, checkedAt: Date())
    }

    private static func probe(_ base: URL, _ key: String, _ body: [String: Any]) async -> Bool {
        var req = URLRequest(url: base.appending(path: "chat/completions"), timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        return (resp as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
    }
}

// MARK: Memory

private struct MemorySettings: View {
    @Bindable var app: AppModel
    @State private var records: [MemoryRecord] = []
    @State private var editing: String?
    @State private var draft = ""

    var body: some View {
        Form {
            Section {
                Toggle(NSLocalizedString("开启记忆", comment: ""), isOn: Binding(
                    get: { !app.settings.memoryExtractionPaused },
                    set: { app.settings.memoryExtractionPaused = !$0 }
                ))
            }
            Section(String(format: NSLocalizedString("记忆（%@）", comment: ""), String(records.count))) {
                if records.isEmpty { Text(NSLocalizedString("暂无记忆", comment: "")).textStyle(.secondary) }
                ForEach(records) { m in
                    VStack(alignment: .leading, spacing: 4) {
                        if editing == m.id {
                            TextField(NSLocalizedString("内容", comment: ""), text: $draft)
                            HStack {
                                Button(NSLocalizedString("保存为纠正", comment: "")) { _ = try? app.memories.correct(m.id, newContent: draft); editing = nil; reload() }
                                Button(NSLocalizedString("取消", comment: "")) { editing = nil }
                            }
                        } else {
                            Text(m.content)
                            Text("\(m.kind.rawValue)\(m.confirmed ? NSLocalizedString(" · 已确认", comment: "") : "")\(m.pinned ? NSLocalizedString(" · 已固定", comment: "") : "") · \(NSLocalizedString("来源", comment: "")): \(m.sourceIDs.joined(separator: ", "))")
                                .textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle)
                            HStack {
                                Button(NSLocalizedString("编辑", comment: "")) { editing = m.id; draft = m.content }
                                Button(m.pinned ? NSLocalizedString("取消固定", comment: "") : NSLocalizedString("固定", comment: "")) { try? app.memories.setPinned(m.id, !m.pinned); reload() }
                                if !m.confirmed { Button(NSLocalizedString("确认", comment: "")) { try? app.memories.confirm(m.id); reload() } }
                                Button(NSLocalizedString("删除", comment: ""), role: .destructive) { try? app.memories.delete(m.id); reload() }
                            }
                            .buttonStyle(.link)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: reload)
    }

    private func reload() { records = app.memories.list(limit: 200) }
}

// MARK: External MCP

private struct MCPSettings: View {
    @Bindable var app: AppModel
    @State private var instances: [MCPInstance] = []
    @State private var newName = ""
    @State private var issued: (name: String, credential: String)?
    @State private var error: String?

    /// Never exposed externally regardless of instance settings.
    static let exposable: [DataSourceID] = [.calendar, .reminders, .notes, .contacts, .chrome, .shortcuts, .messages]

    var body: some View {
        Form {
            Section {
                LabeledContent(NSLocalizedString("本地连接", comment: ""), value: app.isMCPListening ? NSLocalizedString("监听中", comment: "") : NSLocalizedString("未监听（无已启用实例）", comment: ""))
                if let e = app.mcpServerError { Text(e).foregroundStyle(ThemeColor.kTextNegative) }
            }
            if let issued {
                Section(String(format: NSLocalizedString("新实例“%@”的配置（凭据只显示这一次）", comment: ""), issued.name)) {
                    Text(Self.configSnippet(credential: issued.credential))
                        .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    Button(NSLocalizedString("复制配置", comment: "")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Self.configSnippet(credential: issued.credential), forType: .string)
                    }
                    Button(NSLocalizedString("我已保存", comment: "")) { self.issued = nil }
                }
            }
            Section(NSLocalizedString("实例", comment: "")) {
                ForEach($instances) { $inst in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(inst.name).textStyle(.button)
                            Spacer()
                            Button(NSLocalizedString("撤销", comment: ""), role: .destructive) {
                                try? MCPInstanceStore(app.store).delete(inst.id)
                                reload()
                            }
                        }
                        Toggle(NSLocalizedString("启用", comment: ""), isOn: $inst.enabled).onChange(of: inst.enabled) { save(inst) }
                        Toggle(NSLocalizedString("只读", comment: ""), isOn: $inst.readOnly).onChange(of: inst.readOnly) { save(inst) }
                        HStack {
                            ForEach(Self.exposable, id: \.self) { s in
                                Toggle(s.rawValue, isOn: Binding(
                                    get: { inst.sources.contains(s) },
                                    set: { on in
                                        if on { inst.sources.append(s) } else { inst.sources.removeAll { $0 == s } }
                                        save(inst)
                                    }))
                                .toggleStyle(.checkbox)
                            }
                        }
                        .textStyle(.secondary)
                    }
                }
                HStack {
                    TextField(NSLocalizedString("实例名称（如 Claude Desktop）", comment: ""), text: $newName)
                    Button(NSLocalizedString("创建", comment: "")) {
                        do {
                            let (inst, cred) = try app.gateway.register(name: newName.isEmpty ? NSLocalizedString("MCP 客户端", comment: "") : newName)
                            issued = (inst.name, cred)
                            newName = ""
                            reload()
                        } catch { self.error = "\(error)" }
                    }
                }
                if let error { Text(error).foregroundStyle(ThemeColor.kTextNegative) }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: reload)
    }

    private func save(_ inst: MCPInstance) {
        try? MCPInstanceStore(app.store).update(inst)
        app.refreshMCPServer()
    }

    private func reload() {
        instances = MCPInstanceStore(app.store).all()
        app.refreshMCPServer()
    }

    static func configSnippet(credential: String) -> String {
        """
        {
          "mcpServers": {
            "asky": {
              "command": "\(AppModel.bridgeExecutablePath)",
              "env": { "ASKY_MCP_CREDENTIAL": "\(credential)" }
            }
          }
        }
        """
    }
}
