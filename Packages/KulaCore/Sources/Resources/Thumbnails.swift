import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Image I/O thumbnailing straight from the source file at display size (no full decode first),
/// with an accounted LRU cache and at most `Budgets.decodeConcurrency` concurrent decodes.
public final class ThumbnailService: Sendable {
    public struct Thumbnail: @unchecked Sendable {
        public let image: CGImage
        public var cost: Int { image.bytesPerRow * image.height }
    }

    public let cache: CostLRUCache<String, Thumbnail>
    private let limiter: ConcurrencyLimiter

    public init(budget: Int = Budgets.imageCacheBytes, concurrency: Int = Budgets.decodeConcurrency) {
        cache = CostLRUCache(name: "thumbnails", costLimit: budget)
        limiter = ConcurrencyLimiter(limit: concurrency)
    }

    public func thumbnail(for url: URL, maxPixelSize: Int) async -> CGImage? {
        let key = "\(url.path)#\(maxPixelSize)"
        if let hit = cache.value(for: key) { return hit.image }
        let image: CGImage? = await limiter.withPermit {
            if Task.isCancelled { return nil }
            return Self.decode(url: url, maxPixelSize: maxPixelSize)
        }
        guard let image, !Task.isCancelled else { return nil }
        let t = Thumbnail(image: image)
        cache.insert(t, for: key, cost: t.cost)
        return image
    }

    public static func decode(url: URL, maxPixelSize: Int) -> CGImage? {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, srcOpts) else { return nil }
        let opts = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts)
    }

    /// Writes a PNG thumbnail file (used for clipboard history rows).
    public static func writeThumbnail(from source: URL, to dest: URL, maxPixelSize: Int) -> Bool {
        guard let img = decode(url: source, maxPixelSize: maxPixelSize),
              let d = CGImageDestinationCreateWithURL(dest as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(d, img, nil)
        return CGImageDestinationFinalize(d)
    }
}

/// Dispatches memory-pressure events; observers trim rebuildable caches and lower concurrency.
public final class MemoryPressureMonitor: Sendable {
    private let source: DispatchSourceMemoryPressure

    public init(handler: @escaping @Sendable (_ critical: Bool) -> Void) {
        source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))
        let s = source
        source.setEventHandler { handler(s.data.contains(.critical)) }
        source.activate()
    }

    deinit { source.cancel() }
}
