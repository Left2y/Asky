import AppKit
import UniformTypeIdentifiers

public enum SettingsExclusionSelection: Sendable {
    case directory
    case application
}

extension ToolService {
    /// Selection only records the existing exclusion key; it grants no search or clipboard access.
    @MainActor
    public static func chooseSettingsExclusion(_ selection: SettingsExclusionSelection) async -> String? {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString(selection == .directory ? "排除的目录名" : "排除的应用 Bundle ID", comment: "")
        panel.prompt = NSLocalizedString("确定", comment: "")
        panel.canChooseFiles = selection == .application
        panel.canChooseDirectories = selection == .directory
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.treatsFilePackagesAsDirectories = false
        if selection == .application {
            panel.allowedContentTypes = [.applicationBundle]
            panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        }
        NSApp.activate()
        let response: NSApplication.ModalResponse = await withCheckedContinuation { continuation in
            if let window = NSApp.keyWindow {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
        guard response == .OK, let url = panel.url else { return nil }
        switch selection {
        case .directory:
            return url.lastPathComponent
        case .application:
            guard let identifier = Bundle(url: url)?.bundleIdentifier, !identifier.isEmpty else {
                let alert = AppDialog.make()
                alert.messageText = NSLocalizedString("所选应用没有 Bundle ID，无法添加排除项。", comment: "")
                alert.addButton(withTitle: NSLocalizedString("好", comment: ""))
                alert.runModal()
                return nil
            }
            return identifier
        }
    }
}
