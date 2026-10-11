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
            case .keywords: KeywordSettings(app: app)
            case .general: GeneralSettings(app: app)
            case .sources: SourceSettings(app: app)
            case .permissions: PermissionSettings()
            case .memory: MemorySettings(app: app)
            case .mcp: MCPSettings(app: app)
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
            Section("触发快捷键") {
                LabeledContent("唤起启动器") {
                    HotKeyRecorder(label: app.preferences.hotKeyLabel, apply: setLauncher).frame(width: 240, height: 34)
                }
                Text(app.hotKeyStatus).foregroundStyle(.secondary)
                Button("恢复默认 ⌥ Space") { setLauncher(UInt32(kVK_Space), UInt32(optionKey), "⌥ Space") }
            }
            Section("剪贴板") {
                LabeledContent("打开剪贴板历史") {
                    HotKeyRecorder(label: app.preferences.clipboardHotKeyLabel, apply: setClipboard).frame(width: 240, height: 34)
                }
                Text(app.clipboardHotKeyStatus).foregroundStyle(.secondary)
                let d = SettingsPreferences.defaultClipboardHotKey
                Button("恢复默认 \(d.label)") { setClipboard(d.code, d.modifiers, d.label) }
            }
        }.formStyle(.grouped)
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
        if !view.recording { view.title = label + " · 点击录制" }
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
            title = label + " · 点击录制"
        }
        required init?(coder: NSCoder) { fatalError() }
        @objc func begin() { recording = true; title = "按下组合键，Esc 取消"; window?.makeFirstResponder(self) }
        override func resignFirstResponder() -> Bool {
            recording = false
            title = label + " · 点击录制"
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
                title = "请包含 ⌘、⌥ 或 ⌃"; return
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
                title = "已被占用，换一个组合键"
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
    @State private var newScope = ""

    var body: some View {
        Form {
            Section("启动") {
                Toggle("登录时启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister(); loginError = nil }
                        catch { loginError = error.localizedDescription; launchAtLogin = !on }
                    }
                if let loginError { Text(loginError).foregroundStyle(ThemeColor.kTextNegative) }
            }
            Section("外观") {
                Picker("应用主题", selection: $app.preferences.appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                Text("应用于启动器、AI 对话与设置窗口。").foregroundStyle(.secondary)
            }
            Section("文件搜索范围") {
                ForEach(app.settings.fileScopes, id: \.self) { p in
                    HStack { Text(p).lineLimit(1); Spacer(); Button("移除") { app.settings.fileScopes.removeAll { $0 == p } } }
                }
                HStack {
                    TextField("添加目录路径", text: $newScope)
                    Button("添加") {
                        let p = (newScope as NSString).expandingTildeInPath
                        if FileManager.default.fileExists(atPath: p), !app.settings.fileScopes.contains(p) { app.settings.fileScopes.append(p) }
                        newScope = ""
                    }
                }
                TextField("排除的目录名（逗号分隔）", text: Binding(
                    get: { app.settings.excludedDirectories.joined(separator: ", ") },
                    set: { app.settings.excludedDirectories = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
            }
            Section("终端") {
                TextField("工作目录", text: $app.settings.terminalWorkingDirectory)
                Text("仅在输入以 > 开头并按 ↩ 时运行；交互式命令转到“终端”。").textStyle(.secondary)
            }
            Section("剪贴板") {
                Text("快捷键：\(app.preferences.clipboardHotKeyLabel)（在“触发快捷键”中修改）").textStyle(.secondary)
                Toggle("记录剪贴板历史", isOn: $app.settings.clipboardEnabled)
                Text("保留 30 天、上限 200 MiB，固定项不删除；密码管理器与标记为隐藏的内容不记录。").textStyle(.secondary)
                TextField("排除的应用 Bundle ID（逗号分隔）", text: Binding(
                    get: { app.settings.clipboardExcludedApps.joined(separator: ", ") },
                    set: { app.settings.clipboardExcludedApps = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
                Button("清空未固定的剪贴板历史", role: .destructive) {
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
    @State private var account = ""
    @State private var folder = ""

    static let labels: [(DataSourceID, String)] = [
        (.calendar, "日历"), (.reminders, "提醒事项"), (.notes, "备忘录"), (.contacts, "通讯录"), (.chrome, "Chrome 标签与书签"),
        (.shortcuts, "快捷指令"), (.messages, "信息（仅草稿交接）"), (.memory, "个人记忆"), (.maps, "路线时间（MapKit）"),
    ]

    var body: some View {
        Form {
            Section("AI 与工具可使用的来源") {
                ForEach(Self.labels, id: \.0) { id, label in
                    Toggle(label, isOn: Binding(
                        get: { app.settings.enabledSources.contains(id) },
                        set: { on in if on { app.settings.enabledSources.insert(id) } else { app.settings.enabledSources.remove(id) } }))
                }
            }
            Section("授权的备忘录文件夹") {
                ForEach(app.settings.notesFolders, id: \.self) { f in
                    HStack { Text("\(f.account) › \(f.folder)"); Spacer(); Button("移除") { app.settings.notesFolders.removeAll { $0 == f } } }
                }
                HStack {
                    TextField("账户（如 iCloud）", text: $account)
                    TextField("文件夹", text: $folder)
                    Button("添加") {
                        guard !account.isEmpty, !folder.isEmpty else { return }
                        app.settings.notesFolders.append(NotesFolder(account: account, folder: folder))
                        account = ""; folder = ""
                    }
                }
            }
            Section("系统权限") {
                Button("管理系统权限…") { app.openSettings(permissions: true) }
            }
            Section("情境提醒") {
                Toggle("主动提醒（冲突、出行准备、重要日期）", isOn: $app.settings.proactiveReminders)
                Toggle("后台 AI 判断（默认关闭）", isOn: $app.settings.backgroundAI)
            }
        }
        .formStyle(.grouped)
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

    var body: some View {
        Form {
            Section("供应商与模型") {
                Picker("供应商", selection: Binding(get: { provider }, set: { value in
                    provider = value
                    if value == "openai" { baseURL = "https://api.openai.com/v1"; model = "" }
                    if value == "deepseek" { baseURL = "https://api.deepseek.com"; model = "" }
                })) {
                    Text("自定义（OpenAI 兼容）").tag("custom")
                    Text("OpenAI").tag("openai")
                    Text("DeepSeek").tag("deepseek")
                }

                TextField("API 地址", text: $baseURL, prompt: Text("https://api.example.com/v1"))
                TextField("模型名", text: $model)
                SecureField("API Key（留空保留已保存的 Key）", text: $key)
            }
            Section {
                HStack {
                    Button("保存") { Task { await save() } }
                    Button("检查已保存配置") { Task { await check() } }.disabled(checking || app.modelConfiguration == nil)
                    if checking { ProgressView().controlSize(.small) }
                }
                if let message { Text(message).textStyle(.secondary) }
                if let c = capabilities ?? app.modelConfiguration?.capabilities {
                    LabeledContent("文本", value: capabilityLabel(c.text))
                    LabeledContent("工具调用", value: capabilityLabel(c.tools))
                    LabeledContent("图像输入", value: capabilityLabel(c.image))
                }
            }
        }
        .formStyle(.grouped)
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
        case .available: "可用"
        case .unavailable: "不可用"
        case .unknown: "未检查"
        }
    }

    private func save() async {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1"].contains(host)),
              !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = "请填写有效的 https 地址与模型名。"
            return
        }
        do {
            if let agent = app.agent, await agent.state == .busy {
                message = "请等待当前 AI 任务结束后保存模型设置。"; return
            }
            let account = app.modelConfiguration?.credentialRef ?? ModelSettings.keyAccount
            guard !key.isEmpty || app.keychain.contains(account: account) else {
                message = "请填写 API Key；留空只会保留已保存的 Key。"
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
            message = "已保存。"
        } catch {
            message = "钥匙串写入失败：\(error)"
        }
    }

    private func check() async {
        guard var cfg = app.modelConfiguration else { return }
        checking = true
        defer { checking = false }
        do {
            guard let key = try await app.readModelCredential(account: cfg.credentialRef) else {
                message = "请先保存 API Key。"; return
            }
            let caps = await ModelCapabilityCheck.run(baseURL: cfg.baseURL, model: cfg.modelName, apiKey: key)
            cfg.capabilities = caps
            app.modelConfiguration = cfg
            capabilities = caps
            message = "检查完成。"
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

// MARK: Keywords

struct KeywordSettings: View {
    @Bindable var app: AppModel
    @State private var keyword = ""
    @State private var name = ""
    @State private var website = ""
    @State private var error: String?

    var body: some View {
        Form {
            Section("网页关键词（输入关键词后 ↩ 打开）") {
                ForEach(app.keywords.commands, id: \.keyword) { c in
                    HStack {
                        Text(c.keyword).font(.system(.body, design: .monospaced)).frame(width: 60, alignment: .leading)
                        VStack(alignment: .leading) {
                            Text(c.name)
                            Text(c.url(for: "")?.absoluteString ?? c.urlTemplate).textStyle(.secondary).lineLimit(1)
                            Text(c.supportsQuery ? "支持：关键词 + 问题" : "仅打开网页，不传递问题").textStyle(.secondary)
                        }
                        Spacer()
                        Button("删除") { app.keywords.remove(c.keyword) }
                    }
                }
            }
            Section("添加") {
                TextField("关键词", text: $keyword)
                TextField("名称", text: $name)
                TextField("网址（如 chatgpt.com）", text: $website)
                Text("输入网址即可，省略 https:// 也可以。关键词后按回车打开网页。").textStyle(.secondary)
                Button("保存") {
                    do {
                        guard !app.preferences.aliases.contains(where: { $0.alias.caseInsensitiveCompare(keyword.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }) else {
                            error = "这个别名已被应用或快捷指令使用。"; return
                        }
                        try app.keywords.upsert(KeywordCommand(keyword: keyword, name: name.isEmpty ? keyword : name, urlTemplate: website))
                        keyword = ""; name = ""; website = ""; error = nil
                    } catch KeywordRegistry.RegistryError.invalidTemplate {
                        error = "请输入有效的网址，例如 chatgpt.com 或 https://example.com。"
                    } catch KeywordRegistry.RegistryError.invalidKeyword {
                        error = "关键词不能为空、不能包含空格，也不能使用 bm 或 >。"
                    } catch KeywordRegistry.RegistryError.duplicate {
                        error = "这个关键词已存在，请换一个。"
                    } catch { self.error = "保存失败，请重试。" }
                }
                if let error { Text(error).foregroundStyle(ThemeColor.kTextNegative) }
            }
        }
        .formStyle(.grouped)
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
                Toggle("开启记忆", isOn: Binding(
                    get: { !app.settings.memoryExtractionPaused },
                    set: { app.settings.memoryExtractionPaused = !$0 }
                ))
            }
            Section("记忆（\(records.count)）") {
                if records.isEmpty { Text("暂无记忆").textStyle(.secondary) }
                ForEach(records) { m in
                    VStack(alignment: .leading, spacing: 4) {
                        if editing == m.id {
                            TextField("内容", text: $draft)
                            HStack {
                                Button("保存为纠正") { _ = try? app.memories.correct(m.id, newContent: draft); editing = nil; reload() }
                                Button("取消") { editing = nil }
                            }
                        } else {
                            Text(m.content)
                            Text("\(m.kind.rawValue)\(m.confirmed ? " · 已确认" : "")\(m.pinned ? " · 已固定" : "") · 来源：\(m.sourceIDs.joined(separator: ", "))")
                                .textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle)
                            HStack {
                                Button("编辑") { editing = m.id; draft = m.content }
                                Button(m.pinned ? "取消固定" : "固定") { try? app.memories.setPinned(m.id, !m.pinned); reload() }
                                if !m.confirmed { Button("确认") { try? app.memories.confirm(m.id); reload() } }
                                Button("删除", role: .destructive) { try? app.memories.delete(m.id); reload() }
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
                Text("外部 MCP 客户端通过 kulahere-mcp 连接正在运行的 KulaHere。实例默认关闭、默认只读；写入始终在 KulaHere 中确认。记忆、剪贴板、Key、终端与发送不会对外暴露。")
                    .textStyle(.secondary)
                LabeledContent("本地连接", value: app.isMCPListening ? "监听中" : "未监听（无已启用实例）")
                if let e = app.mcpServerError { Text(e).foregroundStyle(ThemeColor.kTextNegative) }
            }
            if let issued {
                Section("新实例“\(issued.name)”的配置（凭据只显示这一次）") {
                    Text(Self.configSnippet(credential: issued.credential))
                        .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    Button("复制配置") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Self.configSnippet(credential: issued.credential), forType: .string)
                    }
                    Button("我已保存") { self.issued = nil }
                }
            }
            Section("实例") {
                ForEach($instances) { $inst in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(inst.name).textStyle(.button)
                            Spacer()
                            Button("撤销", role: .destructive) {
                                try? MCPInstanceStore(app.store).delete(inst.id)
                                reload()
                            }
                        }
                        Toggle("启用", isOn: $inst.enabled).onChange(of: inst.enabled) { save(inst) }
                        Toggle("只读", isOn: $inst.readOnly).onChange(of: inst.readOnly) { save(inst) }
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
                    TextField("实例名称（如 Claude Desktop）", text: $newName)
                    Button("创建") {
                        do {
                            let (inst, cred) = try app.gateway.register(name: newName.isEmpty ? "MCP 客户端" : newName)
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
            "kulahere": {
              "command": "\(AppModel.bridgeExecutablePath)",
              "env": { "KULAHERE_MCP_CREDENTIAL": "\(credential)" }
            }
          }
        }
        """
    }
}


private struct PermissionSettings: View {
    @State private var states: [SystemPermission: PermissionState] = [:]
    @State private var requesting: SystemPermission?
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Text("数据来源开关不等于系统授权。首次使用日历、提醒事项或通讯录时会请求权限；拒绝后请在系统设置中开启，再重新发送请求。")
                    .textStyle(.secondary)
            }
            Section("系统权限") {
                ForEach(SystemPermission.allCases) { permission in
                    HStack(spacing: 12) {
                        Image(systemName: symbol(for: permission))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(iconColor(for: permission), in: RoundedRectangle(cornerRadius: 7))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(permission.title)
                            Text(states[permission]?.rawValue ?? "正在检查…")
                                .textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        HStack(spacing: 8) {
                            if states[permission]?.canRequest == true {
                                Button(requesting == permission ? "正在请求…" : "请求授权") {
                                    requesting = permission
                                    message = nil
                                    Task {
                                        do {
                                            let state = try await SystemPermissions.request(permission)
                                            states[permission] = state
                                            message = "\(permission.title)：\(state.rawValue)"
                                        } catch { message = "\(permission.title)授权请求失败：\(error.localizedDescription)" }
                                        requesting = nil
                                    }
                                }.disabled(requesting != nil)
                            }
                            Button("打开系统设置") {
                                do { try SystemPermissions.openSettings(permission); message = nil }
                                catch { message = error.localizedDescription }
                            }
                        }
                        .fixedSize()
                    }
                    .padding(.vertical, 4)
                }
                Button("刷新权限状态") { Task { await refresh() } }
                if let message { Text(message).textStyle(.secondary).textSelection(.enabled) }
            }
            Section {
                Text("自动化权限按目标应用分别授予；Chrome 或备忘录首次使用会请求。备忘录还需要在“数据来源”中添加允许访问的账户和文件夹。屏幕录制授权后若仍失败，请重启 KulaHere。")
                    .textStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refresh() }
        }
    }

    private func refresh() async {
        for permission in SystemPermission.allCases { states[permission] = await SystemPermissions.state(permission) }
    }

    private func symbol(for permission: SystemPermission) -> String {
        switch permission {
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .contacts: "person.crop.rectangle"
        case .screenRecording: "record.circle"
        case .accessibility: "accessibility"
        case .automation: "gearshape.2"
        case .notifications: "bell.badge"
        }
    }

    private func iconColor(for permission: SystemPermission) -> Color {
        switch permission {
        case .calendar, .screenRecording: .red
        case .reminders: .orange
        case .contacts: .brown
        case .accessibility: .blue
        case .automation: .gray
        case .notifications: .purple
        }
    }
}
