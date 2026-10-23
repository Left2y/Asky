import Contracts
import AppKit
import DirectActions

extension ToolService {
    @MainActor
    public static func chooseLauncherSearchFolder() async -> URL? {
        let panel = NSOpenPanel()
        panel.title = CoreLocalization.text("添加文件搜索范围")
        panel.message = CoreLocalization.text("选择要加入文件搜索范围的文件夹。")
        panel.prompt = CoreLocalization.text("添加")
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
        panel.title = CoreLocalization.text("授权 Chrome 书签")
        panel.message = CoreLocalization.text("选择 Chrome 文件夹以允许读取书签。Asky 只读取书签文件，不读取浏览历史。")
        panel.prompt = CoreLocalization.text("授权")
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
            alert.messageText = CoreLocalization.text("无法读取所选文件夹中的 Chrome 书签")
            alert.informativeText = CoreLocalization.text("请选择 Chrome 文件夹或它的 Default／Profile 个人资料文件夹，再重新授权。")
            alert.addButton(withTitle: CoreLocalization.text("好"))
            await AppDialog.present(alert)
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
    public static func openLauncherApplication(_ url: URL) async throws {
        guard url.isFileURL, url.pathExtension.lowercased() == "app" else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        // The synchronous open(URL) API can wait on Launch Services while the
        // target app starts. Its async counterpart keeps the launcher responsive.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.allowsRunningApplicationSubstitution = false
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
