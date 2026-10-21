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
        for query in ["图片", "微信", "TIFF", "tiff", "微信 TIFF", "图片 微信", "微信 TIFF 图片", image.imageTitle, String(image.imageTitle.prefix(4)), "\(image.imageTitle) 微信 TIFF"] {
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
    @Test func unavailableOriginalsAreHiddenBeforeLimitingAndRecoverWithoutDeletion() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ClipboardStore(try LocalStore(inMemoryWithRoot: root))
        let file = root.appending(path: "recover.txt")
        let valid = ClipboardItem(kind: .text, text: "fixture valid", byteSize: 1,
                                  contentHash: "valid", createdAt: Date().addingTimeInterval(-200))
        try store.insert(valid)
        for i in 0..<260 {
            try store.insert(ClipboardItem(kind: .file, text: "fixture missing", filePaths: [file.path],
                byteSize: 1, sourceApp: "Finder", contentHash: "missing-\(i)"))
        }
        for query in ["", "fixture", "Finder", "文件"] {
            let results = ClipboardAccess.search(in: store, query: query, limit: 1)
            #expect(results.map(\.id) == (query.isEmpty || query == "fixture" ? [valid.id] : []))
        }
        #expect(ClipboardAccess.search(in: store, query: "", limit: 0).isEmpty)
        #expect(store.recent(limit: 300).count == 261)
        try Data("recovered".utf8).write(to: file)
        #expect(ClipboardAccess.search(in: store, query: "Finder", limit: 1).count == 1)
        let group = ClipboardItem(kind: .file, filePaths: [file.path, root.appending(path: "missing").path],
                                  byteSize: 1, contentHash: "group")
        #expect(!ClipboardAccess.isAvailable(group))
        #expect(!ClipboardAccess.isAvailable(ClipboardItem(kind: .text, text: "  ", byteSize: 1, contentHash: "empty")))
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let original = root.appending(path: "original.img")
        let thumb = root.appending(path: "thumb.png")
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: original)
        try png.write(to: thumb)
        let image = ClipboardItem(kind: .image, filePath: original.path, thumbPath: thumb.path,
                                  byteSize: png.count, contentHash: "image")
        try store.insert(image)
        #expect(ClipboardAccess.isAvailable(image))
        try Data("corrupt".utf8).write(to: original)
        #expect(!ClipboardAccess.isAvailable(image))
        #expect(ClipboardAccess.search(in: store, query: "图片").isEmpty)
        try FileManager.default.removeItem(at: original)
        #expect(!ClipboardAccess.isAvailable(image))
        #expect(FileManager.default.fileExists(atPath: thumb.path))
    }

}
