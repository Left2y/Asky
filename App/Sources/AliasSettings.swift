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
        SettingsForm {
            Section(NSLocalizedString("应用与快捷指令别名", comment: "")) {
                if app.preferences.aliases.isEmpty { Text(NSLocalizedString("暂无别名", comment: "")).foregroundStyle(.secondary) }
                ForEach(app.preferences.aliases) { item in
                    HStack {
                        Text(item.alias).font(.system(.body, design: .monospaced)).frame(width: 90, alignment: .leading)
                        targetIcon(kind: item.kind, target: item.target)
                        VStack(alignment: .leading) {
                            Text(item.kind == "app" ? URL(filePath: item.target).deletingPathExtension().lastPathComponent : item.target)
                            Text(item.kind == "app" ? NSLocalizedString("应用", comment: "") : NSLocalizedString("快捷指令", comment: "")).foregroundStyle(.secondary)
                        }
                        Spacer()
                        SettingsButton(NSLocalizedString("编辑", comment: "")) { editing = item.id; alias = item.alias; kind = item.kind; target = item.target }
                        SettingsButton(NSLocalizedString("删除", comment: ""), role: .destructive) { app.preferences.aliases.removeAll { $0.id == item.id } }
                    }
                }
            }
            Section(editing == nil ? NSLocalizedString("添加别名", comment: "") : NSLocalizedString("编辑别名", comment: "")) {
                SettingsTextField(NSLocalizedString("别名", comment: ""), text: $alias)
                Picker(NSLocalizedString("类型", comment: ""), selection: $kind) {
                    Text(NSLocalizedString("应用", comment: "")).tag("app")
                    Text(NSLocalizedString("快捷指令", comment: "")).tag("shortcut")
                }.onChange(of: kind) { _, _ in target = "" }
                if kind == "app" {
                    LabeledContent(NSLocalizedString("应用", comment: "")) {
                        if !target.isEmpty { targetIcon(kind: kind, target: target) }
                        Text(target.isEmpty ? NSLocalizedString("尚未选择", comment: "") : URL(filePath: target).deletingPathExtension().lastPathComponent)
                        SettingsButton(NSLocalizedString("选择…", comment: "")) {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.applicationBundle]
                            panel.directoryURL = URL(filePath: "/Applications")
                            panel.canChooseDirectories = false
                            if panel.runModal() == .OK, let url = panel.url { target = url.path }
                        }
                    }
                } else {
                    Picker(NSLocalizedString("快捷指令", comment: ""), selection: $target) {
                        Text(NSLocalizedString("请选择", comment: "")).tag("")
                        ForEach(Array(Set(shortcuts + (target.isEmpty ? [] : [target]))).sorted(), id: \.self) { name in
                            HStack {
                                targetIcon(kind: "shortcut", target: name)
                                Text(name)
                            }.tag(name)
                        }
                    }
                    SettingsButton(NSLocalizedString("刷新快捷指令", comment: "")) { Task { shortcuts = await ToolService.listLauncherShortcuts() } }
                    if shortcuts.isEmpty { Text(NSLocalizedString("暂无快捷指令", comment: "")).foregroundStyle(.secondary) }
                }
                HStack {
                    SettingsButton(NSLocalizedString("保存别名", comment: "")) { save() }.disabled(target.isEmpty)
                    if editing != nil { SettingsButton(NSLocalizedString("取消", comment: "")) { reset() } }
                }
                if let message { Text(message).foregroundStyle(.secondary) }
            }
        }
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
            message = NSLocalizedString("别名不能为空、包含空格，或使用保留命令 bm、>。", comment: ""); return
        }
        guard !app.preferences.aliases.contains(where: { $0.id != editing && $0.alias.caseInsensitiveCompare(name) == .orderedSame }),
              !app.keywords.commands.contains(where: { $0.keyword.caseInsensitiveCompare(name) == .orderedSame }) else {
            message = NSLocalizedString("这个别名或关键词已存在。", comment: ""); return
        }
        let item = LauncherAlias(id: editing ?? UUID(), alias: name, kind: kind, target: target)
        app.preferences.aliases.removeAll { $0.id == item.id }
        app.preferences.aliases.append(item)
        reset()
    }
}
