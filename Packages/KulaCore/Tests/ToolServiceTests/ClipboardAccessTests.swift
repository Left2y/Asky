import AppKit
import Testing
import LocalStore
@testable import ToolService

@Suite @MainActor
struct ClipboardAccessTests {
    @Test func chatImageFlavorsSurviveFilenameTextAndTemporaryFileRemoval() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let jpeg = try #require(bitmap.representation(using: .jpeg, properties: [:]))
        let pb = NSPasteboard.withUniqueName()
        defer { pb.releaseGlobally() }
        for (type, data) in [(NSPasteboard.PasteboardType.png, png), (.tiff, try #require(bitmap.tiffRepresentation)),
                             (NSPasteboard.PasteboardType("public.jpeg"), jpeg)] {
            pb.clearContents()
            pb.setString("img_v3_02167_827d327e.jpg", forType: .string)
            pb.setData(data, forType: type)
            let snapshot = ClipboardAccess.snapshot(from: pb)
            let image = try #require(snapshot.image)
            #expect(NSBitmapImageRep(data: image)?.pixelsWide == 64)
            #expect(snapshot.fileURLs.isEmpty)
        }
        let file = root.appending(path: "img_v3_02167.jpg")
        try jpeg.write(to: file)
        pb.clearContents()
        pb.writeObjects([file as NSURL])
        pb.setString(file.lastPathComponent, forType: .string)
        let snapshot = ClipboardAccess.snapshot(from: pb)
        #expect(snapshot.fileURLs.isEmpty)
        try FileManager.default.removeItem(at: file)
        let captured = try #require(snapshot.image)
        #expect(NSBitmapImageRep(data: captured)?.pixelsHigh == 36)
        // Multiple files must remain a file selection, even when a preview image is advertised.
        pb.clearContents()
        pb.writeObjects([file as NSURL, root.appending(path: "second.jpg") as NSURL])
        pb.setData(png, forType: .png)
        #expect(ClipboardAccess.snapshot(from: pb).fileURLs.count == 2)
        #expect(ClipboardAccess.snapshot(from: pb).image == nil)
        pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        #expect(ClipboardAccess.snapshot(from: pb).image == nil)
        #expect(ClipboardAccess.snapshot(from: pb).text == nil)
    }

    @Test func fileSelectionRoundTripsWithoutDeletingOriginals() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let urls = [root.appending(path: "中文 file.txt"), root.appending(path: "Folder")]
        try Data("actual contents".utf8).write(to: urls[0])
        try FileManager.default.createDirectory(at: urls[1], withIntermediateDirectories: true)
        let pb = NSPasteboard.withUniqueName()
        defer { pb.releaseGlobally() }
        pb.writeObjects(urls.map { $0 as NSURL })
        pb.setString("中文 file.txt\nFolder", forType: .string)
        let snapshot = ClipboardAccess.snapshot(from: pb)
        #expect(snapshot.fileURLs == urls)
        let store = ClipboardStore(try LocalStore(root: root.appending(path: "history")))
        let item = ClipboardItem(kind: .file, text: snapshot.text, filePath: urls[0].path,
            filePaths: snapshot.fileURLs.map(\.path), byteSize: 100, contentHash: "files")
        try store.insert(item)
        let restored = try #require(store.recent(limit: 1).first)
        #expect(ClipboardAccess.copy(restored, to: pb))
        #expect(ClipboardAccess.snapshot(from: pb).fileURLs == urls)
        #expect(pb.string(forType: .string) == nil)
        let writers = try #require(ClipboardAccess.dragItems(for: restored))
        #expect(writers.allSatisfy { $0 is NSURL })
        let dragPB = NSPasteboard.withUniqueName()
        defer { dragPB.releaseGlobally() }
        #expect(dragPB.writeObjects(writers))
        #expect(ClipboardAccess.snapshot(from: dragPB).fileURLs == urls)
        #expect(ClipboardAccess.snapshot(from: pb).restoredFromHistory)
        #expect(try store.delete(ids: [restored.id]).isEmpty)
        #expect(FileManager.default.fileExists(atPath: urls[0].path))
        #expect(FileManager.default.fileExists(atPath: urls[1].path))
        try FileManager.default.removeItem(at: urls[0])
        pb.clearContents()
        pb.setString("keep", forType: .string)
        #expect(!ClipboardAccess.copy(restored, to: pb))
        #expect(ClipboardAccess.dragItems(for: restored) == nil)
        #expect(pb.string(forType: .string) == "keep")
    }

    @Test func legacyAndConcealedFilePasteboards() {
        let pb = NSPasteboard.withUniqueName()
        defer { pb.releaseGlobally() }
        pb.setPropertyList(["/tmp/a", "/tmp/b"], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        #expect(ClipboardAccess.snapshot(from: pb).fileURLs.map(\.path) == ["/tmp/a", "/tmp/b"])
        pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        #expect(ClipboardAccess.snapshot(from: pb).fileURLs.isEmpty)
    }

    @Test func textCopyAndDragPreserveFullContents() {
        let text = "完整文字\nsecond line 🐈"
        let item = ClipboardItem(kind: .text, text: text, byteSize: text.utf8.count, contentHash: "text")
        let pb = NSPasteboard.withUniqueName()
        defer { pb.releaseGlobally() }
        #expect(ClipboardAccess.copy(item, to: pb))
        #expect(pb.string(forType: .string) == text)
        #expect(ClipboardAccess.snapshot(from: pb).restoredFromHistory)
        pb.clearContents()
        pb.setString("file:///tmp/example.txt", forType: .string)
        #expect(!ClipboardAccess.snapshot(from: pb).restoredFromHistory)
        #expect(ClipboardAccess.snapshot(from: pb).fileURLs.isEmpty)
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
