import SwiftUI
import ServiceManagement
import Contracts
import LocalStore
import DirectActions
import Memory
import MCPGateway
import Adapters
import Theme

struct SettingsView: View {
    let app: AppModel
    let hotKeyStatus: String

    var body: some View {
        TabView {
            Tab("通用", systemImage: "gearshape") { GeneralSettings(app: app, hotKeyStatus: hotKeyStatus) }
            Tab("数据来源", systemImage: "square.stack") { SourceSettings(app: app) }
            Tab("模型", systemImage: "sparkles") { ModelSettingsView(app: app) }
            Tab("关键词", systemImage: "link") { KeywordSettings(app: app) }
            Tab("记忆", systemImage: "brain") { MemorySettings(app: app) }
            Tab("外部 MCP", systemImage: "point.3.connected.trianglepath.dotted") { MCPSettings(app: app) }
        }
        .frame(width: 640, height: 500)
    }
}

// MARK: General

private struct GeneralSettings: View {
    @Bindable var app: AppModel
    let hotKeyStatus: String
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var newScope = ""

    var body: some View {
        Form {
            Section("快捷键") {
                LabeledContent("唤起启动器", value: "⌥ Space")
                Text(hotKeyStatus).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle)
            }
            Section {
                Toggle("登录时启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister(); loginError = nil }
                        catch { loginError = error.localizedDescription; launchAtLogin = !on }
                    }
                if let loginError { Text(loginError).foregroundStyle(ThemeColor.kTextNegative) }
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
        (.calendar, "日历"), (.reminders, "提醒事项"), (.notes, "备忘录"), (.contacts, "通讯录"), (.chrome, "Chrome 标签"),
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
                Button("请求日历与提醒事项权限") { Task { _ = await app.native.eventKit.requestCalendar(); _ = await app.native.eventKit.requestReminders() } }
                Button("请求通讯录权限") { Task { _ = await app.native.contacts.request() } }
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
    @State private var baseURL = ""
    @State private var model = ""
    @State private var key = ""
    @State private var message: String?
    @State private var capabilities: ModelCapabilities?
    @State private var checking = false

    var body: some View {
        Form {
            Section("OpenAI 兼容接口") {
                TextField("API 地址", text: $baseURL, prompt: Text("https://api.example.com/v1"))
                TextField("模型名", text: $model)
                SecureField("API Key（保存在钥匙串）", text: $key)
            }
            Section {
                HStack {
                    Button("保存") { save() }
                    Button("检查能力") { Task { await check() } }.disabled(checking || app.modelConfiguration == nil)
                    if checking { ProgressView().controlSize(.small) }
                }
                if let message { Text(message).textStyle(.secondary) }
                if let c = capabilities ?? app.modelConfiguration?.capabilities {
                    LabeledContent("文本", value: c.text.rawValue)
                    LabeledContent("工具调用", value: c.tools.rawValue)
                    LabeledContent("图像输入", value: c.image.rawValue)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if let c = app.modelConfiguration {
                baseURL = c.baseURL.absoluteString
                model = c.modelName
                key = app.keychain.get(account: c.credentialRef) ?? ""
            }
        }
    }

    private func save() {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces)), url.scheme == "https" || url.host == "localhost" || url.host == "127.0.0.1",
              !model.trimmingCharacters(in: .whitespaces).isEmpty else {
            message = "请填写有效的 https 地址与模型名。"
            return
        }
        do {
            if key.isEmpty { app.keychain.delete(account: ModelSettings.keyAccount) }
            else { try app.keychain.set(key, account: ModelSettings.keyAccount) }
            app.modelConfiguration = ModelConfiguration(baseURL: url, modelName: model, credentialRef: ModelSettings.keyAccount)
            capabilities = nil
            message = "已保存。"
        } catch {
            message = "钥匙串写入失败：\(error)"
        }
    }

    private func check() async {
        guard var cfg = app.modelConfiguration, let key = app.keychain.get(account: cfg.credentialRef) else { return }
        checking = true
        defer { checking = false }
        let caps = await ModelCapabilityCheck.run(baseURL: cfg.baseURL, model: cfg.modelName, apiKey: key)
        cfg.capabilities = caps
        app.modelConfiguration = cfg
        capabilities = caps
        message = "检查完成（\(caps.checkedAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? "")）。"
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

private struct KeywordSettings: View {
    @Bindable var app: AppModel
    @State private var keyword = ""
    @State private var name = ""
    @State private var template = ""
    @State private var error: String?

    var body: some View {
        Form {
            Section("关键词（输入“关键词 内容”后 ↩ 打开）") {
                ForEach(app.keywords.commands, id: \.keyword) { c in
                    HStack {
                        Text(c.keyword).font(.system(.body, design: .monospaced)).frame(width: 60, alignment: .leading)
                        VStack(alignment: .leading) { Text(c.name); Text(c.urlTemplate).textStyle(.secondary).lineLimit(1) }
                        Spacer()
                        Button("删除") { app.keywords.remove(c.keyword) }
                    }
                }
            }
            Section("添加") {
                TextField("关键词", text: $keyword)
                TextField("名称", text: $name)
                TextField("URL 模板（包含 {query}）", text: $template)
                Button("保存") {
                    do {
                        try app.keywords.upsert(KeywordCommand(keyword: keyword, name: name.isEmpty ? keyword : name, urlTemplate: template))
                        keyword = ""; name = ""; template = ""; error = nil
                    } catch { self.error = "\(error)" }
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
                Toggle("暂停记忆提炼", isOn: $app.settings.memoryExtractionPaused)
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
