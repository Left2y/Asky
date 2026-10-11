import SwiftUI
import DirectActions
import ToolService

struct CommandSettings: View {
    @Bindable var app: AppModel
    @State private var terminals: [LauncherTerminalApplication] = []

    var body: some View {
        Form {
            Section(NSLocalizedString("内置指令", comment: "")) {
                ForEach(app.keywords.commands) { command in
                    LabeledContent {
                        Text(NSLocalizedString(command.name, comment: ""))
                    } label: {
                        HStack(spacing: 10) {
                            Image("Command" + logoName(for: command.keyword))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .accessibilityHidden(true)
                            Text(command.keyword).font(.system(.body, design: .monospaced))
                        }
                    }
                }
                LabeledContent {
                    Text(NSLocalizedString("终端命令", comment: ""))
                } label: {
                    HStack(spacing: 10) {
                        Group {
                            if let icon = ToolService.launcherTerminalIcon(selectedTerminal) {
                                Image(nsImage: icon).resizable().scaledToFit()
                            } else {
                                Image(systemName: "terminal").resizable().scaledToFit()
                            }
                        }
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                        Text(">").font(.system(.body, design: .monospaced))
                    }
                }
                Text(NSLocalizedString("输入指令后按空格，再输入内容。内置指令固定，无需添加或修改。", comment: ""))
                    .foregroundStyle(.secondary)
            }
            Section(NSLocalizedString("终端", comment: "")) {
                Picker(NSLocalizedString("执行命令的终端", comment: ""), selection: Binding(
                    get: { app.settings.terminalApplicationID ?? LauncherTerminalApplication.system.rawValue },
                    set: { app.settings.terminalApplicationID = $0 })) {
                    ForEach(terminalChoices) { terminal in
                        HStack {
                            if let icon = ToolService.launcherTerminalIcon(terminal) {
                                Image(nsImage: icon).resizable().scaledToFit().frame(width: 20, height: 20)
                            }
                            Text(terminal.name + (terminals.contains(terminal) ? "" : NSLocalizedString("（未安装）", comment: "")))
                        }.tag(terminal.rawValue)
                    }
                }
                Text(NSLocalizedString("支持系统终端、iTerm2 与 Ghostty 1.3+，列表显示已安装的终端。", comment: ""))
                    .foregroundStyle(.secondary)
                TextField(NSLocalizedString("工作目录", comment: ""), text: $app.settings.terminalWorkingDirectory)
            }
        }
        .formStyle(.grouped)
        .onAppear { terminals = ToolService.installedLauncherTerminals() }
    }

    private var selectedTerminal: LauncherTerminalApplication {
        app.settings.terminalApplicationID.flatMap(LauncherTerminalApplication.init(rawValue:)) ?? .system
    }

    private var terminalChoices: [LauncherTerminalApplication] {
        return terminals.contains(selectedTerminal) ? terminals : terminals + [selectedTerminal]
    }

    private func logoName(for keyword: String) -> String {
        switch keyword {
        case "go": "Google"
        case "chat": "ChatGPT"
        case "yt": "YouTube"
        case "dy": "Douyin"
        case "tb": "Taobao"
        case "jd": "JD"
        case "bl": "Bilibili"
        case "gh": "GitHub"
        default: "Google"
        }
    }
}
