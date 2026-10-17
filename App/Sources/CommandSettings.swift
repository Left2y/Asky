import SwiftUI
import DirectActions

struct CommandSettings: View {
    @Bindable var app: AppModel
    @State private var query = ""

    private var filteredCommands: [KeywordCommand] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return KeywordCommand.builtIn.filter {
            term.isEmpty || $0.keyword.localizedStandardContains(term)
                || $0.name.localizedStandardContains(term)
                || NSLocalizedString($0.name, comment: "").localizedStandardContains(term)
        }
    }

    var body: some View {
        SettingsForm {
            Section {
                if filteredCommands.isEmpty {
                    Text(NSLocalizedString("未找到匹配的指令", comment: ""))
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredCommands) { command in
                    LabeledContent {
                        Text(NSLocalizedString(command.name, comment: ""))
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
                            Text(command.keyword).font(.system(.body, design: .monospaced))
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
