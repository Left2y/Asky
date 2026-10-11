import SwiftUI
import DirectActions
import Contracts
import ToolService

struct AliasSettings: View {
    @Bindable var app: AppModel
    @State private var alias = ""
    @State private var kind = "app"
    @State private var target = ""
    @State private var shortcuts: [String] = []
    @State private var message: String?
    @State private var editing: UUID?

    var body: some View {
        Form {
            Section("应用与快捷指令别名") {
                if app.preferences.aliases.isEmpty { Text("暂无别名").foregroundStyle(.secondary) }
                ForEach(app.preferences.aliases) { item in
                    HStack {
                        Text(item.alias).font(.system(.body, design: .monospaced)).frame(width: 90, alignment: .leading)
                        targetIcon(kind: item.kind, target: item.target)
                        VStack(alignment: .leading) {
                            Text(item.kind == "app" ? URL(filePath: item.target).deletingPathExtension().lastPathComponent : item.target)
                            Text(item.kind == "app" ? "应用" : "快捷指令").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("编辑") { editing = item.id; alias = item.alias; kind = item.kind; target = item.target }
                        Button("删除", role: .destructive) { app.preferences.aliases.removeAll { $0.id == item.id } }
                    }
                }
            }
            Section(editing == nil ? "添加别名" : "编辑别名") {
                TextField("别名", text: $alias)
                Picker("类型", selection: $kind) {
                    Text("应用").tag("app")
                    Text("快捷指令").tag("shortcut")
                }.onChange(of: kind) { _, _ in target = "" }
                if kind == "app" {
                    LabeledContent("应用") {
                        if !target.isEmpty { targetIcon(kind: kind, target: target) }
                        Text(target.isEmpty ? "尚未选择" : URL(filePath: target).deletingPathExtension().lastPathComponent)
                        Button("选择…") {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.applicationBundle]
                            panel.directoryURL = URL(filePath: "/Applications")
                            panel.canChooseDirectories = false
                            if panel.runModal() == .OK, let url = panel.url { target = url.path }
                        }
                    }
                } else {
                    Picker("快捷指令", selection: $target) {
                        Text("请选择").tag("")
                        ForEach(Array(Set(shortcuts + (target.isEmpty ? [] : [target]))).sorted(), id: \.self) { name in
                            HStack {
                                targetIcon(kind: "shortcut", target: name)
                                Text(name)
                            }.tag(name)
                        }
                    }
                    Button("刷新快捷指令") { Task { shortcuts = await ToolService.listLauncherShortcuts() } }
                    if shortcuts.isEmpty { Text("暂无快捷指令").foregroundStyle(.secondary) }
                }
                HStack {
                    Button("保存别名") { save() }.disabled(target.isEmpty)
                    if editing != nil { Button("取消") { reset() } }
                }
                if let message { Text(message).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
         .task { shortcuts = await ToolService.listLauncherShortcuts() }
    }

    private func targetIcon(kind: String, target: String) -> some View {
        Image(nsImage: ToolService.launcherIcon(filePath: kind == "app" ? target : "/System/Applications/Shortcuts.app"))
        .resizable()
        .scaledToFit()
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }

    private func reset() { editing = nil; alias = ""; target = ""; message = nil }
    private func save() {
        let name = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains(where: \.isWhitespace), name != ">", name.lowercased() != "bm" else {
            message = "别名不能为空、包含空格，或使用保留命令 bm、>。"; return
        }
        guard !app.preferences.aliases.contains(where: { $0.id != editing && $0.alias.caseInsensitiveCompare(name) == .orderedSame }),
              !app.keywords.commands.contains(where: { $0.keyword.caseInsensitiveCompare(name) == .orderedSame }) else {
            message = "这个别名或关键词已存在。"; return
        }
        let item = LauncherAlias(id: editing ?? UUID(), alias: name, kind: kind, target: target)
        app.preferences.aliases.removeAll { $0.id == item.id }
        app.preferences.aliases.append(item)
        reset()
    }
}
