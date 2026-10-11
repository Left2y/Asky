import AppKit
import Testing
import LocalStore
@testable import ToolService

@Suite @MainActor
struct ClipboardAccessTests {
    @Test func textCopyAndDragPreserveFullContents() {
        let text = "完整文字\nsecond line 🐈"
        let item = ClipboardItem(kind: .text, text: text, byteSize: text.utf8.count, contentHash: "text")
        let pb = NSPasteboard.withUniqueName()
        defer { pb.releaseGlobally() }
        #expect(ClipboardAccess.copy(item, to: pb))
        #expect(pb.string(forType: .string) == text)
        #expect(ClipboardAccess.dragItem(for: item)?.string(forType: .string) == text)
    }

    @Test func missingImageDoesNotClearExistingClipboard() {
        let pb = NSPasteboard.withUniqueName()
        defer { pb.releaseGlobally() }
        pb.setString("keep", forType: .string)
        let item = ClipboardItem(kind: .image, filePath: "/missing/clipboard-image", byteSize: 12, contentHash: "missing")
        #expect(!ClipboardAccess.copy(item, to: pb))
        #expect(pb.string(forType: .string) == "keep")
        #expect(ClipboardAccess.dragItem(for: item) == nil)
    }

    @Test func imageCopyAndDragRetainOriginalDimensions() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 640, pixelsHigh: 360,
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let path = root.appending(path: "original.png")
        try data.write(to: path)
        let item = ClipboardItem(kind: .image, filePath: path.path, byteSize: data.count, contentHash: "image")
        let pb = NSPasteboard.withUniqueName()
        defer { pb.releaseGlobally() }
        #expect(ClipboardAccess.copy(item, to: pb))
        let restored = try #require(pb.data(forType: .tiff).flatMap { NSBitmapImageRep(data: $0) })
        #expect(restored.pixelsWide == 640)
        #expect(restored.pixelsHigh == 360)
        // Stored originals have no extension; the drag exports a real .png file URL plus PNG data.
        let typeless = root.appending(path: "original.img")
        try FileManager.default.moveItem(at: path, to: typeless)
        let stored = ClipboardItem(kind: .image, filePath: typeless.path, byteSize: data.count, contentHash: "image")
        let dragged = try #require(ClipboardAccess.dragItem(for: stored, exportDirectory: root.appending(path: "drag")))
        let url = try #require(dragged.string(forType: .fileURL).flatMap(URL.init(string:)))
        #expect(url.pathExtension == "png")
        #expect(NSBitmapImageRep(data: try Data(contentsOf: url))?.pixelsWide == 640)
        #expect(dragged.data(forType: .png) != nil)
    }
}
