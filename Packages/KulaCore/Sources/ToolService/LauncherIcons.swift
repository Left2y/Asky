import AppKit
import Contracts
import UniformTypeIdentifiers

extension ToolService {
    @MainActor public static func pluginApplicationIcon(repository: String) -> NSImage? {
        let bundleID: String
        switch repository.lowercased() {
        case "https://github.com/niall-young/asky-plugin-orca": bundleID = "com.stablyai.orca"
        case "https://github.com/niall-young/asky-plugin-lark": bundleID = "com.bytedance.macos.feishu"
        default: return nil
        }
        guard let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return launcherIcon(filePath: application.path)
    }

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

    /// File metadata is read here, alongside the launcher's system icon lookup.
    @MainActor public static func launcherFileType(filePath: String) -> String? {
        let url = URL(fileURLWithPath: filePath)
        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey])
        let type = values?.contentType
        if values?.isDirectory == true {
            return (type ?? .folder).localizedDescription
        }
        let ext = url.pathExtension
        if !ext.isEmpty { return ext.uppercased() }
        return type?.localizedDescription
    }

    /// Renders a few icons off the main thread so the system icon services are loaded
    /// before the first result list draws (the first icon otherwise stalls ~80 ms).
    public static func prewarmLauncherIcons(filePaths: [String]) {
        Task.detached(priority: .utility) {
            let side = 64
            for path in filePaths {
                guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                      let context = NSGraphicsContext(bitmapImageRep: rep) else { continue }
                let icon = NSWorkspace.shared.icon(forFile: path)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                icon.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }

    /// Resolve the actual app artwork for each configurable data source.
    @MainActor public static func dataSourceApplicationIcon(_ source: DataSourceID) -> NSImage? {
        let bundleID: String
        switch source {
        case .calendar: bundleID = "com.apple.iCal"
        case .reminders: bundleID = "com.apple.reminders"
        case .notes: bundleID = "com.apple.Notes"
        case .contacts: bundleID = "com.apple.AddressBook"
        case .chrome: bundleID = "com.google.Chrome"
        case .shortcuts: bundleID = "com.apple.shortcuts"
        case .messages: bundleID = "com.apple.MobileSMS"
        case .maps: bundleID = "com.apple.Maps"
        case .terminal: bundleID = "com.apple.Terminal"
        case .clipboard, .plugins, .web: return nil
        case .memory: return nil // The App supplies its own bundled Asky logo.
        }
        guard let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return launcherIcon(filePath: application.path)
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
