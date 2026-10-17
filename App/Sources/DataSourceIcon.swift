import SwiftUI
import Contracts
import ToolService

/// Application identities share native artwork across search, settings and tool records.
struct DataSourceIcon: View {
    let source: DataSourceID

    @ViewBuilder var body: some View {
        if source == .memory {
            Image("AskyLogo").resizable().scaledToFit()
        } else if let icon = ToolService.dataSourceApplicationIcon(source) {
            Image(nsImage: icon).renderingMode(.original).resizable().scaledToFit()
        } else {
            Image(mingCute: fallbackSymbol).resizable().scaledToFit()
        }
    }

    private var fallbackSymbol: String {
        switch source {
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .notes: "note.text"
        case .contacts: "person.crop.circle"
        case .chrome: "globe"
        case .shortcuts: "square.stack.3d.up"
        case .messages: "message"
        case .terminal: "terminal"
        case .maps: "map"
        case .web: "globe"
        case .clipboard: "doc.on.clipboard"
        case .plugins: "puzzlepiece.extension"
        case .memory: "brain"
        }
    }
}
