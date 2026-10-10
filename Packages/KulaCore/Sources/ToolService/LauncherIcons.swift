import AppKit
import Contracts

extension ToolService {
    @MainActor private static let launcherIcons: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 128
        return cache
    }()

    @MainActor private static var browserApplication: URL?
    @MainActor private static var browserScheme: String?
    @MainActor private static var browserCheckedAt = Date.distantPast
    @MainActor public static func openLauncherURL(_ url: URL) -> Bool {
        return NSWorkspace.shared.open(url)
    }
    /// Presentation-only system reads stay in the native service boundary.
    @MainActor public static func launcherIcon(filePath: String) -> NSImage {
        if let cached = launcherIcons.object(forKey: filePath as NSString) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: filePath)
        launcherIcons.setObject(icon, forKey: filePath as NSString)
        return icon
    }

    @MainActor public static func launcherBrowserIcon(for url: URL) -> NSImage? {
        // Launcher commands use web URLs. Reuse the handler during rapid result updates.
        if browserScheme != url.scheme || Date().timeIntervalSince(browserCheckedAt) > 5 {
            browserScheme = url.scheme
            browserApplication = NSWorkspace.shared.urlForApplication(toOpen: url)
            browserCheckedAt = Date()
        }
        guard let application = browserApplication else { return nil }
        return launcherIcon(filePath: application.path)
    }
}
