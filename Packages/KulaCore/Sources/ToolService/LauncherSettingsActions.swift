import AppKit
import DirectActions

extension ToolService {
    public static func listLauncherShortcuts() async -> [String] {
        await ShortcutsService.list()
    }

    public static func runLauncherShortcut(name: String) -> AsyncStream<ShortcutRunState> {
        ShortcutsService.run(name: name)
    }

    @MainActor
    public static func openLauncherApplication(_ url: URL) -> Bool {
        guard url.isFileURL, url.pathExtension.lowercased() == "app", FileManager.default.fileExists(atPath: url.path) else { return false }
        return NSWorkspace.shared.open(url)
    }
}
