import AppKit
import Foundation
import Testing
@testable import ToolService

struct ChatImageTests {
    @Test func onlyRemoteImageURLsAreAccepted() {
        #expect(ChatImageService.supports(URL(string: "https://example.com/image.png")!))
        #expect(ChatImageService.supports(URL(string: "http://localhost/image.png")!))
        for value in ["file:///etc/passwd", "data:image/png;base64,AAAA", "https://user:password@example.com/a"] {
            #expect(!ChatImageService.supports(URL(string: value)!))
        }
    }

    @Test func rejectsInvalidImageData() {
        #expect(throws: (any Error).self) { try ChatImageService.thumbnail(Data("not an image".utf8)) }
    }

    @Test func downsamplesLargeImagesPreservingAspectRatio() throws {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 3200, pixelsHigh: 1600,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        let input = try #require(bitmap.representation(using: .png, properties: [:]))
        let output = try ChatImageService.thumbnail(input)
        let image = try #require(NSBitmapImageRep(data: output))
        #expect(image.pixelsWide == 1600)
        #expect(image.pixelsHigh == 800)
    }
    @Test func downloadsPreserveOriginalPixelsAndNeverOverwrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 3200, pixelsHigh: 1600,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let source = URL(string: "https://example.com/photo.jpg?token=test")!
        let first = try ChatImageService.saveImage(data, source: source, directory: directory)
        let second = try ChatImageService.saveImage(data, source: source, directory: directory)
        #expect(first.lastPathComponent == "photo.png")
        #expect(second.lastPathComponent == "photo (1).png")
        #expect(try Data(contentsOf: first) == data)
        #expect(try Data(contentsOf: second) == data)
        #expect(try #require(NSBitmapImageRep(data: Data(contentsOf: first))).pixelsWide == 3200)
    }

}
