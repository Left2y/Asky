import AppKit
import Contracts

extension ToolService {
    @MainActor public static func openLauncherURL(_ url: URL) -> Bool {
        return NSWorkspace.shared.open(url)
    }
    /// Presentation-only system reads stay in the native service boundary.
    @MainActor public static func launcherIcon(filePath: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: filePath)
    }

    @MainActor public static func launcherBrowserIcon(for url: URL) -> NSImage? {
        guard let application = NSWorkspace.shared.urlForApplication(toOpen: url) else { return nil }
        return NSWorkspace.shared.icon(forFile: application.path)
    }
}
