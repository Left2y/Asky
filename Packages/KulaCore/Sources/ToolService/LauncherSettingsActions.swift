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

    @MainActor
    public static func chooseChromeBookmarkFolder() async -> Data? {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("授权 Chrome 书签", comment: "")
        panel.message = NSLocalizedString("选择 Chrome 文件夹以允许读取书签。Asky 只读取书签文件，不读取浏览历史。", comment: "")
        panel.prompt = NSLocalizedString("授权", comment: "")
        panel.directoryURL = ChromeBookmarkService.defaultRoot
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        NSApp.activate()
        let response: NSApplication.ModalResponse = await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0) }
        }
        guard response == .OK, let folder = panel.url else { return nil }
        do {
            _ = try await Task.detached(priority: .userInitiated) {
                try ChromeBookmarkService.read(root: folder)
            }.value
            return try folder.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                           includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            let alert = AppDialog.make()
            alert.messageText = NSLocalizedString("无法读取所选文件夹中的 Chrome 书签", comment: "")
            alert.informativeText = NSLocalizedString("请选择 Chrome 文件夹或它的 Default／Profile 个人资料文件夹，再重新授权。", comment: "")
            alert.addButton(withTitle: NSLocalizedString("好", comment: ""))
            alert.runModal()
            return nil
        }
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
