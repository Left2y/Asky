import SwiftUI
import DirectActions
import Contracts
import ToolService

struct AliasSettings: View {
    @Bindable var app: AppModel
    @State private var editor: AliasDraft?

    var body: some View {
        SettingsForm {
            Section {
                if app.preferences.aliases.isEmpty {
                    Text(label("暂无别名")).foregroundStyle(.secondary)
                }
                ForEach(app.preferences.aliases) { item in
                    HStack(spacing: 12) {
                        AliasTargetIcon(kind: item.kind, target: item.target, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AliasDraft.displayName(kind: item.kind, target: item.target)).lineLimit(1)
                            Text(label(item.kind == "app" ? "应用" : "快捷指令"))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 12)
                        AliasChip(text: item.alias)
                        aliasMenu(item)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { editor = AliasDraft(item) }
                }
                HStack {
                    Spacer()
                    SettingsButton(label("添加别名"), systemImage: "plus") { editor = AliasDraft() }
                }
            } header: {
                Text(label("应用与快捷指令别名"))
            } footer: {
                Text(label("在输入框中输入别名并回车，即可直接打开对应的应用或运行快捷指令。"))
            }
        }
        .sheet(item: $editor) { draft in
            AliasEditor(app: app, draft: draft)
        }
    }

    private func aliasMenu(_ item: LauncherAlias) -> some View {
        Menu {
            Button(label("编辑")) { editor = AliasDraft(item) }
            Divider()
            Button(label("删除"), role: .destructive) { app.preferences.aliases.removeAll { $0.id == item.id } }
        } label: {
            Image(systemName: "ellipsis.circle").font(.system(size: 15)).foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .accessibilityLabel(label("更多操作") + " " + item.alias).help(label("更多操作"))
    }
}

private func label(_ key: String) -> String { NSLocalizedString(key, comment: "") }

private struct AliasDraft: Identifiable {
    let id: UUID
    let isNew: Bool
    var alias = ""
    var kind = "app"
    var target = ""

    init() { id = UUID(); isNew = true }
    init(_ item: LauncherAlias) {
        id = item.id; isNew = false; alias = item.alias; kind = item.kind; target = item.target
    }

    static func displayName(kind: String, target: String) -> String {
        kind == "app" ? URL(filePath: target).deletingPathExtension().lastPathComponent : target
    }
}

private struct AliasTargetIcon: View {
    let kind: String
    let target: String
    let size: CGFloat
    var body: some View {
        Image(nsImage: ToolService.launcherIcon(filePath: kind == "app" ? target : "/System/Applications/Shortcuts.app"))
            .resizable().scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct AliasChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            .help(label("别名"))
    }
}

private struct AliasEditor: View {
    @Bindable var app: AppModel
    @State var draft: AliasDraft
    @State private var shortcuts: [String] = []
    @State private var loadingShortcuts = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label(draft.isNew ? "添加别名" : "编辑别名"))
                .font(.headline).padding(.horizontal, 20).padding(.top, 20)
            SettingsForm {
                Section {
                    LabeledContent(label("类型")) {
                        Picker(label("类型"), selection: $draft.kind) {
                            Text(label("应用")).tag("app")
                            Text(label("快捷指令")).tag("shortcut")
                        }
                        .pickerStyle(.segmented).labelsHidden().fixedSize()
                    }
                    .onChange(of: draft.kind) { _, _ in draft.target = "" }
                    if draft.kind == "app" { appPicker } else { shortcutPicker }
                }
                Section {
                    SettingsTextField(label("别名"), text: $draft.alias, prompt: Text(verbatim: "fig"))
                } footer: {
                    if let error = validationError {
                        Text(error).foregroundStyle(.red)
                    } else {
                        Text(label("不能包含空格，不区分大小写。"))
                    }
                }
            }
            HStack {
                Spacer()
                SettingsButton(label("取消")) { dismiss() }.keyboardShortcut(.cancelAction)
                SettingsButton(label("保存")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 480, height: 340)
        .task { await refreshShortcuts() }
    }

    private var appPicker: some View {
        LabeledContent(label("应用")) {
            HStack(spacing: 8) {
                if !draft.target.isEmpty {
                    AliasTargetIcon(kind: "app", target: draft.target, size: 22)
                    Text(AliasDraft.displayName(kind: "app", target: draft.target)).lineLimit(1)
                }
                SettingsButton(label(draft.target.isEmpty ? "选择应用…" : "更换…")) { chooseApp() }
            }
        }
    }

    private var shortcutPicker: some View {
        LabeledContent(label("快捷指令")) {
            HStack(spacing: 8) {
                if shortcutChoices.isEmpty && !loadingShortcuts {
                    Text(label("暂无快捷指令")).foregroundStyle(.secondary)
                } else {
                    SettingsChoice(selection: $draft.target, options:
                        [("", label("请选择"))] + shortcutChoices.map { ($0, $0) },
                        images: Dictionary(uniqueKeysWithValues: shortcutChoices.map {
                            ($0, ToolService.launcherIcon(filePath: "/System/Applications/Shortcuts.app"))
                        }))
                }
                SettingsButton("", systemImage: "arrow.clockwise", isLoading: loadingShortcuts) {
                    Task { await refreshShortcuts() }
                }
                .help(label("刷新快捷指令")).accessibilityLabel(label("刷新快捷指令"))
            }
        }
    }

    private var shortcutChoices: [String] {
        Array(Set(shortcuts + (draft.kind == "shortcut" && !draft.target.isEmpty ? [draft.target] : []))).sorted()
    }

    private var trimmedAlias: String { draft.alias.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var validationError: String? {
        let name = trimmedAlias
        guard !name.isEmpty else { return nil }
        let terminalKeyword = app.settings.terminalCommandKeyword
        if name.contains(where: \.isWhitespace) || name.caseInsensitiveCompare(terminalKeyword) == .orderedSame
            || name.lowercased() == "bm" {
            return String(format: label("别名不能为空、包含空格，或使用保留命令 bm、%@。"), terminalKeyword)
        }
        if app.preferences.aliases.contains(where: { $0.id != draft.id && $0.alias.caseInsensitiveCompare(name) == .orderedSame })
            || app.keywords.commands.contains(where: { $0.keyword.caseInsensitiveCompare(name) == .orderedSame }) {
            return label("这个别名或关键词已存在。")
        }
        return nil
    }

    private var canSave: Bool { !trimmedAlias.isEmpty && !draft.target.isEmpty && validationError == nil }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(filePath: "/Applications")
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        draft.target = url.path
        // Suggest a short alias from the app name so the common case needs no typing.
        if trimmedAlias.isEmpty {
            draft.alias = AliasDraft.displayName(kind: "app", target: url.path)
                .split(whereSeparator: \.isWhitespace).first.map { $0.lowercased() } ?? ""
        }
    }

    private func refreshShortcuts() async {
        loadingShortcuts = true
        shortcuts = await ToolService.listLauncherShortcuts()
        loadingShortcuts = false
    }

    private func save() {
        guard canSave else { return }
        let item = LauncherAlias(id: draft.id, alias: trimmedAlias, kind: draft.kind, target: draft.target)
        if let index = app.preferences.aliases.firstIndex(where: { $0.id == item.id }) {
            app.preferences.aliases[index] = item
        } else {
            app.preferences.aliases.append(item)
        }
        dismiss()
    }
}
