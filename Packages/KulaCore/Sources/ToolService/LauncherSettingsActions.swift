import AppKit
import DirectActions

extension ToolService {
    @MainActor
    public static func chooseLauncherSearchFolder() async -> URL? {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("添加文件搜索范围", comment: "")
        panel.message = NSLocalizedString("选择要加入文件搜索范围的文件夹。", comment: "")
        panel.prompt = NSLocalizedString("添加", comment: "")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        let response: NSApplication.ModalResponse = await withCheckedContinuation { continuation in
            if let window = NSApp.keyWindow {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
        return response == .OK ? panel.url?.standardizedFileURL : nil
    }

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
