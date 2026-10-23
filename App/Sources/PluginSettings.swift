import SwiftUI
import Contracts
import ToolService

enum PluginSettingsCategory: String, CaseIterable, Identifiable {
    case ai, function
    var id: String { rawValue }
    var title: String {
        NSLocalizedString(self == .ai ? "AI 插件" : "功能插件", tableName: "Plugins", comment: "")
    }
    var emptyTitle: String {
        NSLocalizedString(self == .ai ? "尚未安装 AI 插件" : "尚未安装功能插件", tableName: "Plugins", comment: "")
    }
    func includes(_ manifest: PluginManifest) -> Bool {
        let hasCommands = !(manifest.commands ?? []).isEmpty
        switch self {
        case .ai:
            return manifest.tools.contains { $0.agentVisible != false } || manifest.instructions != nil || !hasCommands
        case .function:
            return hasCommands
        }
    }
    static func matches(_ plugin: InstalledPlugin, query: String) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        let m = plugin.manifest
        let fields = [m.name, m.id, plugin.repository]
            + m.tools.flatMap { [$0.name, $0.description] }
            + (m.commands ?? []).flatMap { [$0.name, $0.title, $0.keyword ?? "", $0.subtitle ?? ""] }
        return fields.contains { $0.localizedStandardContains(term) }
    }
}

struct PluginSettings: View {
    @Bindable var app: AppModel
    @State private var selectedCategory = PluginSettingsCategory.ai
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var plugins: [InstalledPlugin] = []
    @State private var repository = ""
    @State private var pendingRepository = ""
    @State private var confirmInstall = false
    @State private var busy = false
    @State private var status = ""
    @State private var editing: InstalledPlugin?
    @State private var icons: [String: NSImage] = [:]
    private var manager: PluginManager { app.tools.plugins }
    private func label(_ key: String) -> String { NSLocalizedString(key, comment: "") }
    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var categories: [PluginSettingsCategory] { isSearching ? PluginSettingsCategory.allCases : [selectedCategory] }
    private func installed(in category: PluginSettingsCategory) -> [InstalledPlugin] {
        plugins.filter { category.includes($0.manifest) && PluginSettingsCategory.matches($0, query: query) }
    }
    private func official(in category: PluginSettingsCategory) -> [String] {
        PluginManager.officialRepositories.filter { source in
            if let plugin = plugins.first(where: { $0.repository == source }) {
                return category.includes(plugin.manifest) && PluginSettingsCategory.matches(plugin, query: query)
            }
            guard category == .ai else { return false }
            let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
            return term.isEmpty || [officialName(source), officialDescription(source), source].contains { $0.localizedStandardContains(term) }
        }
    }
    private func officialName(_ source: String) -> String { source.hasSuffix("asky-plugin-lark") ? label("飞书") : "Orca" }
    private func officialDescription(_ source: String) -> String {
        label(source.hasSuffix("asky-plugin-lark") ? "通过飞书 CLI 管理文档、日程、任务和消息" : "添加项目，启动指定 Agent 并提交任务")
    }
    private func sectionTitle(_ key: String, category: PluginSettingsCategory) -> String {
        isSearching ? category.title + " · " + label(key) : label(key)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                SettingsSearchField(query: $query, focus: $searchFocused,
                                    placeholder: "搜索插件或命令", identifier: "plugin-search")
                    .frame(height: 28)
                Picker(label("插件"), selection: $selectedCategory) {
                    ForEach(PluginSettingsCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.large)
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: 28)
                .accessibilityIdentifier("plugin-tabs")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)
            SettingsForm {
                Section(label("安装插件")) {
                    HStack(alignment: .settingsInput) {
                        SettingsTextField(label("GitHub 仓库链接"), text: $repository)
                            .accessibilityIdentifier("plugin-repository")
                        SettingsButton(label("安装")) { requestInstall(repository) }.accessibilityLabel(label("安装")).disabled(busy || repository.isEmpty)
                    }
                }
                ForEach(categories) { category in
                    let sources = official(in: category)
                    let installed = installed(in: category)
                    if !sources.isEmpty {
                        Section(sectionTitle("官方插件", category: category)) {
                            ForEach(sources, id: \.self) { source in
                                officialRow(source)
                            }
                        }
                    }
                    if !installed.isEmpty || !isSearching {
                        Section(sectionTitle("已安装插件", category: category)) {
                            if installed.isEmpty { Text(category.emptyTitle).foregroundStyle(.secondary) }
                            ForEach(installed) { plugin in
                                installedRow(plugin, category: category)
                            }
                        }
                    }
                }
                if isSearching && categories.allSatisfy({ installed(in: $0).isEmpty && official(in: $0).isEmpty }) {
                    Section {
                        Text(NSLocalizedString("未找到匹配的插件", tableName: "Plugins", comment: ""))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("plugin-no-results")
                    }
                }
                if busy || !status.isEmpty {
                    Section {
                        if busy { ProgressView(label("正在处理插件…")) }
                        Text(status).font(.system(size: 12)).textSelection(.enabled)
                    }
                }
            }
        }
        .task { await reload() }
        .appDialog(label("安装可信插件"), isPresented: $confirmInstall,
                   message: label("此仓库的插件将能够在本机执行代码。安装表示你信任该来源") + "\n\n" + pendingRepository,
                   buttons: [label("安装"), label("取消")]) { response in
            if response == 0 {
                let source = pendingRepository
                perform("安装插件", selectInstalledRepository: source) { try await manager.install(repository: source) }
            }
        }
        .sheet(item: $editing) { plugin in
            PluginConfigurationEditor(plugin: plugin, manager: manager) { Task { await reload() } }
        }
    }
    private func officialRow(_ source: String) -> some View {
        HStack(spacing: 12) {
            pluginIcon(repository: source)
            VStack(alignment: .leading, spacing: 3) {
                Text(officialName(source))
                Text(officialDescription(source)).foregroundStyle(.secondary)
            }
            Spacer()
            if plugins.contains(where: { $0.repository == source }) {
                Text(label("已安装")).foregroundStyle(.secondary)
            } else {
                SettingsButton(label("安装")) { requestInstall(source) }.accessibilityLabel(label("安装")).disabled(busy)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plugin-official-" + source.split(separator: "/").last.map(String.init)!)
    }
    private func installedRow(_ plugin: InstalledPlugin, category: PluginSettingsCategory) -> some View {
        HStack(spacing: 12) {
            pluginIcon(repository: plugin.repository)
            VStack(alignment: .leading, spacing: 3) {
                Text(plugin.manifest.name)
                pluginSubtitle(plugin)
            }
            Spacer(minLength: 12)
            Toggle(label("启用"), isOn: Binding(get: { plugin.enabled }, set: { value in
                Task { await manager.setEnabled(plugin.id, value); await reload() }
            }))
            .labelsHidden().toggleStyle(.switch).controlSize(.small).fixedSize()
            .accessibilityLabel(label("启用"))
            .accessibilityIdentifier("plugin-enabled-" + category.rawValue + "-" + plugin.id)
            .help(label("启用")).disabled(busy)
            pluginMenu(plugin)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plugin-installed-" + category.rawValue + "-" + plugin.id)
    }
    private func requestInstall(_ url: String) {
        do { pendingRepository = try PluginManager.repositoryURL(url); confirmInstall = true }
        catch { status = error.localizedDescription }
    }
    private func pluginSubtitle(_ plugin: InstalledPlugin) -> some View {
        HStack(spacing: 6) {
            Text(plugin.isOfficial ? "v\(plugin.manifest.version)" : "\(label("自行安装")) · v\(plugin.manifest.version)")
                .foregroundStyle(.secondary)
            if let commands = plugin.manifest.commands, !commands.isEmpty {
                Text(String(format: NSLocalizedString("%d 个命令", tableName: "Plugins", comment: ""), commands.count))
                    .foregroundStyle(.secondary)
            }
            if plugin.needsConfiguration { Text(label("需要配置")).foregroundStyle(.orange) }
        }
        .help(plugin.isOfficial ? "" : plugin.repository)
    }
    private func pluginMenu(_ plugin: InstalledPlugin) -> some View {
        SettingsMoreMenu {
            if !(plugin.manifest.configuration ?? []).isEmpty {
                Button(label("配置")) { editing = plugin }
            }
            Button(label("更新")) { perform("更新插件") { try await manager.install(repository: plugin.repository) } }
            Button(label("回退")) { perform("回退插件") { try await manager.rollback(plugin.id) } }
                .disabled(plugin.previousCommit == nil)
            if let url = URL(string: plugin.repository) {
                Button(label("在 GitHub 查看项目")) { NSWorkspace.shared.open(url) }
            }
            Divider()
            Button(label("卸载"), role: .destructive) { perform("卸载插件") { try await manager.uninstall(plugin.id) } }
        }
        .accessibilityLabel(label("更多操作")).help(label("更多操作")).disabled(busy)
    }
    private func pluginIcon(repository: String) -> some View {
        Group {
            if let icon = icons[repository] {
                Image(nsImage: icon).resizable().scaledToFit()
            } else {
                Image("Plugin").resizable().scaledToFit()
            }
        }
        .frame(width: 36, height: 36)
        .accessibilityHidden(true)
    }
    private func reload() async {
        let installed = await manager.installed()
        var artwork: [String: NSImage] = [:]
        for source in PluginManager.officialRepositories {
            artwork[source] = ToolService.pluginApplicationIcon(repository: source)
        }
        for plugin in installed {
            if let data = await manager.iconData(for: plugin.id), let image = NSImage(data: data), image.isValid {
                artwork[plugin.repository] = image
            } else {
                artwork[plugin.repository] = ToolService.pluginApplicationIcon(repository: plugin.repository)
            }
        }
        icons = artwork
        plugins = installed
    }
    private func perform(_ title: String, selectInstalledRepository: String? = nil, operation: @escaping () async throws -> Void) {
        busy = true; status = label(title)
        Task {
            var succeeded = false
            do { try await operation(); status = label("操作完成"); succeeded = true }
            catch { status = error.localizedDescription }
            busy = false
            await reload()
            if succeeded, let source = selectInstalledRepository, let plugin = plugins.first(where: { $0.repository == source }) {
                selectedCategory = PluginSettingsCategory.function.includes(plugin.manifest) ? .function : .ai
                query = ""
            }
        }
    }
}
private struct PluginConfigurationEditor: View {
    let plugin: InstalledPlugin
    let manager: PluginManager
    let saved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: JSONValue]
    @State private var error = ""
    init(plugin: InstalledPlugin, manager: PluginManager, saved: @escaping () -> Void) {
        self.plugin = plugin; self.manager = manager; self.saved = saved
        _values = State(initialValue: plugin.configuration)
    }
    var body: some View {
        VStack(alignment: .leading) {
            Text(plugin.manifest.name).font(.headline)
            SettingsForm {
                ForEach(plugin.manifest.configuration ?? []) { field in
                    if field.type == "boolean" {
                        Toggle(field.label, isOn: Binding(get: { values[field.key]?.boolValue ?? false }, set: { values[field.key] = .bool($0) }))
                    } else if field.type == "enum" {
                        LabeledContent(field.label) {
                            SettingsChoice(selection: text(field.key), options: (field.options ?? []).map { ($0, $0) })
                        }
                    } else {
                        SettingsTextField(field.label, text: text(field.key))
                    }
                }
            }.formStyle(.grouped)
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                SettingsButton(NSLocalizedString("取消", comment: "")) { dismiss() }.accessibilityLabel(NSLocalizedString("取消", comment: ""))
                SettingsButton(NSLocalizedString("保存", comment: "")) {
                    Task {
                        do { try await manager.configure(plugin.id, values: values); saved(); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                }.accessibilityLabel(NSLocalizedString("保存", comment: "")).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 520, height: 360)
    }
    private func text(_ key: String) -> Binding<String> {
        Binding(get: { values[key]?.stringValue ?? "" }, set: { values[key] = .string($0) })
    }
}
