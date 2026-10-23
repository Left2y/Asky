import AppKit
import UniformTypeIdentifiers

/// Only display resources are cached here, never search hits or file availability.
public enum LauncherArtworkRequest: Hashable, Sendable {
    case file(path: String, includeType: Bool = false)
    case application(bundleID: String)
    case browser(URL)

    fileprivate var cacheKey: NSString {
        switch self {
        case .file(let path, let includeType): "file:\(includeType):\(path)" as NSString
        case .application(let bundleID): "app:\(bundleID)" as NSString
        case .browser(let url): "browser:\(url.scheme ?? "")" as NSString
        }
    }
}

/// The bitmap is fully drawn on the worker and never mutated after publication.
public struct LauncherRowPresentation: @unchecked Sendable {
    public let icon: NSImage?
    public let fileType: String?
}

private final class PresentationEntry {
    let value: LauncherRowPresentation
    let created = ContinuousClock.now
    init(_ value: LauncherRowPresentation) { self.value = value }
}

/// NSCache supports concurrent access; entries and their rasterized images are immutable.
private final class PresentationCache: @unchecked Sendable {
    static let shared = PresentationCache()
    let entries: NSCache<NSString, PresentationEntry> = {
        let cache = NSCache<NSString, PresentationEntry>()
        cache.countLimit = 128
        cache.totalCostLimit = 8 * 1024 * 1024
        return cache
    }()

    func value(for request: LauncherArtworkRequest) -> LauncherRowPresentation? {
        guard let entry = entries.object(forKey: request.cacheKey),
              entry.created.duration(to: .now) < .seconds(5) else { return nil }
        return entry.value
    }
}

/// Serialize cold system lookups rather than starting one blocking operation per row.
private actor LauncherArtworkWorker {
    static let shared = LauncherArtworkWorker()

    func load(_ request: LauncherArtworkRequest) -> LauncherRowPresentation? {
        guard !Task.isCancelled else { return nil }
        if let warm = PresentationCache.shared.value(for: request) { return warm }
        let value = autoreleasepool {
            let path: String?
            var type: String?
            switch request {
            case .file(let filePath, let includeType):
                path = filePath
                if includeType {
                    let url = URL(fileURLWithPath: filePath)
                    let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey])
                    type = values?.isDirectory == true
                        ? (values?.contentType ?? .folder).localizedDescription
                        : (!url.pathExtension.isEmpty ? url.pathExtension.uppercased() : values?.contentType?.localizedDescription)
                }
            case .application(let bundleID):
                path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path
            case .browser(let url):
                path = NSWorkspace.shared.urlForApplication(toOpen: url)?.path
            }
            return LauncherRowPresentation(icon: path.flatMap(Self.bitmap), fileType: type)
        }
        guard !Task.isCancelled else { return nil }
        PresentationCache.shared.entries.setObject(PresentationEntry(value), forKey: request.cacheKey,
                                                   cost: value.icon == nil ? 1 : 96 * 96 * 4)
        return value
    }

    private static func bitmap(for path: String) -> NSImage? {
        let side = 96
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        let source = NSWorkspace.shared.icon(forFile: path)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        source.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: NSSize(width: side, height: side))
        image.addRepresentation(rep)
        return image
    }
}

extension ToolService {
    /// Cache-only: safe to call while SwiftUI constructs a row, with no system reads.
    public static func cachedLauncherPresentation(for request: LauncherArtworkRequest) -> LauncherRowPresentation? {
        PresentationCache.shared.value(for: request)
    }

    public static func loadLauncherPresentation(for request: LauncherArtworkRequest) async -> LauncherRowPresentation? {
        await LauncherArtworkWorker.shared.load(request)
    }
}
