import SwiftUI
import DirectActions

struct CommandSettings: View {
    @Bindable var app: AppModel

    var body: some View {
        SettingsForm {
            Section(NSLocalizedString("内置指令", comment: "")) {
                ForEach(KeywordCommand.builtIn) { command in
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
                Text(NSLocalizedString("输入指令后按空格，再输入内容。内置指令固定，无需添加或修改。", comment: ""))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
