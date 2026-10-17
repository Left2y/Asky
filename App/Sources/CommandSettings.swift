import SwiftUI
import DirectActions

struct CommandSettings: View {
    @Bindable var app: AppModel
    @State private var query = ""

    private var filteredCommands: [KeywordCommand] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return KeywordCommand.builtIn.filter {
            term.isEmpty || app.commandKeyword($0.keyword).localizedStandardContains(term) || $0.keyword.localizedStandardContains(term)
                || $0.name.localizedStandardContains(term)
                || NSLocalizedString($0.name, comment: "").localizedStandardContains(term)
        }
    }

    var body: some View {
        SettingsForm {
            Section {
                ForEach(AppModel.searchCommands.filter { item in
                    query.isEmpty || app.commandKeyword(item.0).localizedStandardContains(query)
                        || NSLocalizedString(item.1, comment: "").localizedStandardContains(query)
                }, id: \.0) { item in
                    HStack(spacing: 10) {
                        LauncherFunctionIcon(asset: item.0 == "bookmark" ? "Bookmark" : item.0 == "link" ? "Link" : "Agent")
                        Text(NSLocalizedString(item.1, comment: ""))
                        Spacer()
                        CommandKeywordEditor(app: app, id: item.0)
                    }
                }
            } header: {
                Text(NSLocalizedString("搜索指令", comment: ""))
            } footer: {
                Text(NSLocalizedString("输入指令后按空格进入对应模式，回车执行。", comment: ""))
            }
            Section {
                if filteredCommands.isEmpty {
                    Text(NSLocalizedString("未找到匹配的指令", comment: ""))
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredCommands) { command in
                    LabeledContent {
                        CommandKeywordEditor(app: app, id: command.keyword)
                    } label: {
                        HStack(spacing: 10) {
                            Toggle(NSLocalizedString(command.name, comment: ""), isOn: Binding(
                                get: { !app.preferences.disabledBuiltInCommands.contains(command.keyword) },
                                set: { enabled in
                                    if enabled { app.preferences.disabledBuiltInCommands.remove(command.keyword) }
                                    else { app.preferences.disabledBuiltInCommands.insert(command.keyword) }
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .accessibilityIdentifier("command-enabled-" + command.keyword)
                            CommandIcon(keyword: command.keyword)
                                .accessibilityHidden(true)
                            Text(NSLocalizedString(command.name, comment: ""))
                        }
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("内置指令", comment: ""))
                    HStack(spacing: 8) {
                        Image(mingCute: "magnifyingglass").foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        TextField(NSLocalizedString("搜索指令或名称", comment: ""), text: $query)
                            .textFieldStyle(.plain)
                            .accessibilityIdentifier("command-search")
                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(mingCute: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(NSLocalizedString("清除搜索", comment: ""))
                        }
                    }
                    .font(.system(size: 14))
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct CommandKeywordEditor: View {
    @Bindable var app: AppModel
    let id: String
    @State private var draft = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                TextField(NSLocalizedString("触发指令", comment: ""), text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 90)
                    .accessibilityIdentifier("command-keyword-" + id)
                    .onSubmit(save)
                SettingsButton(NSLocalizedString("保存", comment: ""), action: save)
                    .disabled(draft == app.commandKeyword(id))
                SettingsButton(NSLocalizedString("恢复默认", comment: "")) {
                    let value = AppModel.searchCommands.first { $0.0 == id }?.2 ?? id
                    if let problem = app.commandKeywordProblem(value, id: id) { error = problem; return }
                    app.preferences.commandKeywords.removeValue(forKey: id)
                    draft = value
                    error = nil
                }
                .disabled(app.preferences.commandKeywords[id] == nil)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .onAppear { draft = app.commandKeyword(id) }
        .onChange(of: draft) { _, _ in error = nil }
    }

    private func save() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let problem = app.commandKeywordProblem(value, id: id) { error = problem; return }
        app.preferences.commandKeywords[id] = value
        draft = value
        error = nil
    }
}
