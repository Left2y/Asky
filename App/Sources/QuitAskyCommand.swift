import AppKit
import Contracts
import ToolService

/// A launcher-owned lifecycle command, independent of app indexing and AI.
@MainActor
enum QuitAskyCommand {
    static func matches(_ query: String) -> Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("asky") == .orderedSame
    }

    static func isResult(_ result: SearchResult) -> Bool {
        result.target.kind == "asky-command" && result.target.identifier == "quit-asky"
    }

    static var result: SearchResult {
        SearchResult(source: .keyword, target: TargetRef(kind: "asky-command", identifier: "quit-asky"),
                     title: NSLocalizedString("关闭 Asky", comment: "Quit launcher action"), actions: [.open])
    }

    static func makeAlert() -> NSAlert {
        let alert = AppDialog.make()
        alert.messageText = NSLocalizedString("关闭 Asky？", comment: "Quit confirmation title")
        alert.informativeText = NSLocalizedString("关闭后，Asky 将退出。你可以随时重新打开应用。", comment: "Quit confirmation message")
        alert.addButton(withTitle: NSLocalizedString("关闭 Asky", comment: "Quit confirmation action")).keyEquivalent = "\r"
        alert.addButton(withTitle: NSLocalizedString("取消", comment: "Cancel")).keyEquivalent = "\u{1b}"
        return alert
    }
}
