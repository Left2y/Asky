import SwiftUI
import DirectActions

struct CommandSettings: View {
    @Bindable var app: AppModel

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
            }
        }
    }
}
