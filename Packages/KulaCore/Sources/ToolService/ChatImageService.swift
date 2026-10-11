import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Markdown image reads belong to the native ToolService module, never the agent or UI.
public actor ChatImageService {
    public static let shared = ChatImageService()
    private let session: URLSession
    private var cache: [URL: Data] = [:]
    private var order: [URL] = []
    private var cacheBytes = 0
    private static let downloadLimit = 10 * 1024 * 1024
    private static let cacheLimit = 32 * 1024 * 1024

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    public static func supports(_ url: URL) -> Bool {
        ["https", "http"].contains(url.scheme?.lowercased() ?? "") && url.host != nil
            && url.user == nil && url.password == nil
    }

    public func imageData(from url: URL) async throws -> Data {
        guard Self.supports(url) else { throw URLError(.unsupportedURL) }
        if let data = cache[url] { return data }
        var request = URLRequest(url: url)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              response.url.map(Self.supports) == true else { throw URLError(.badServerResponse) }
        guard response.expectedContentLength <= Self.downloadLimit else { throw URLError(.dataLengthExceedsMaximum) }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < Self.downloadLimit else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        let thumbnail = try Self.thumbnail(data)
        // Another suspended request may have populated this URL in the meantime.
        if let existing = cache[url] { return existing }
        while cacheBytes + thumbnail.count > Self.cacheLimit, !order.isEmpty {
            let oldest = order.removeFirst()
            cacheBytes -= cache.removeValue(forKey: oldest)?.count ?? 0
        }
        if thumbnail.count <= Self.cacheLimit {
            cache[url] = thumbnail
            order.append(url)
            cacheBytes += thumbnail.count
        }
        return thumbnail
    }

    static func thumbnail(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileReadCorruptFile) }
        return output as Data
    }
}
