import AppKit
import Testing
import LocalStore
@testable import ToolService

@Suite @MainActor struct ClipboardSearchTests {
    @Test func sourceAndTypeCanBeCombinedWithoutSearchingDimensions() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ClipboardStore(try LocalStore(inMemoryWithRoot: root))
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let path = root.appending(path: "fixture.tiff")
        try #require(bitmap.tiffRepresentation).write(to: path)
        let image = ClipboardItem(kind: .image, filePath: path.path, byteSize: 1,
            sourceApp: "微信", contentHash: "picture", createdAt: Date().addingTimeInterval(-200))
        try store.insert(image)
        for i in 0..<105 {
            try store.insert(ClipboardItem(kind: .text, text: "unrelated \(i)", byteSize: 1,
                                          contentHash: "text-\(i)"))
        }
        for query in ["图片", "微信", "TIFF", "tiff", "微信 TIFF", "图片 微信", "微信 TIFF 图片"] {
            #expect(ClipboardAccess.search(in: store, query: query).map(\.id) == [image.id])
        }
        #expect(ClipboardAccess.search(in: store, query: "64 × 36").isEmpty)
        #expect(ClipboardAccess.search(in: store, query: "Safari TIFF").isEmpty)
        #expect(ClipboardAccess.search(in: store, query: "微信", limit: 0).isEmpty)
        let text = ClipboardItem(kind: .text, text: "微信 TIFF notes", byteSize: 1, contentHash: "literal")
        try store.insert(text)
        #expect(ClipboardAccess.search(in: store, query: "微信 TIFF").map(\.id) == [text.id, image.id])
        #expect(ClipboardAccess.search(in: store, query: "微信 TIFF", limit: 1).map(\.id) == [text.id])
    }
}
