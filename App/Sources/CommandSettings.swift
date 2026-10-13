import SwiftUI
import DirectActions
import ToolService

struct CommandSettings: View {
    @Bindable var app: AppModel
    @State private var terminals: [LauncherTerminalApplication] = []

    var body: some View {
        SettingsForm {
            Section(NSLocalizedString("内置指令", comment: "")) {
                ForEach(app.keywords.commands) { command in
                    LabeledContent {
                        Text(NSLocalizedString(command.name, comment: ""))
                    } label: {
                        HStack(spacing: 10) {
                            CommandIcon(keyword: command.keyword)
                                .accessibilityHidden(true)
                            Text(command.keyword).font(.system(.body, design: .monospaced))
                        }
                    }
                }
                LabeledContent {
                    Text(NSLocalizedString("终端命令", comment: ""))
                } label: {
                    HStack(spacing: 10) {
                        CommandIcon(terminalIcon: ToolService.launcherTerminalIcon(selectedTerminal))
                        .accessibilityHidden(true)
                        Text(">").font(.system(.body, design: .monospaced))
                    }
                }
                Text(NSLocalizedString("输入指令后按空格，再输入内容。内置指令固定，无需添加或修改。", comment: ""))
                    .foregroundStyle(.secondary)
            }
            Section(NSLocalizedString("终端", comment: "")) {
                LabeledContent(NSLocalizedString("执行命令的终端", comment: "")) {
                    SettingsChoice(selection: Binding(
                        get: { app.settings.terminalApplicationID ?? LauncherTerminalApplication.system.rawValue },
                        set: { app.settings.terminalApplicationID = $0 }),
                        options: terminalChoices.map { terminal in
                            (terminal.rawValue, terminal.name + (terminals.contains(terminal) ? "" : NSLocalizedString("（未安装）", comment: "")))
                        },
                        images: Dictionary(uniqueKeysWithValues: terminalChoices.compactMap { terminal in
                            ToolService.launcherTerminalIcon(terminal).map { (terminal.rawValue, $0) }
                        }))
                }
                SettingsTextField(NSLocalizedString("工作目录", comment: ""), text: $app.settings.terminalWorkingDirectory)
            }
        }
        .onAppear { terminals = ToolService.installedLauncherTerminals() }
    }

    private var selectedTerminal: LauncherTerminalApplication {
        app.settings.terminalApplicationID.flatMap(LauncherTerminalApplication.init(rawValue:)) ?? .system
    }

    private var terminalChoices: [LauncherTerminalApplication] {
        return terminals.contains(selectedTerminal) ? terminals : terminals + [selectedTerminal]
    }

}
