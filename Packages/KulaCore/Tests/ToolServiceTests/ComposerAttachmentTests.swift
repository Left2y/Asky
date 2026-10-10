import AppKit
import Foundation
import Testing
import ToolService

struct ComposerAttachmentTests {
    @Test func importPreservesNameAndRemovalKeepsOriginal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let original = root.appendingPathComponent("任务.txt")
        try Data("附件正文".utf8).write(to: original)
        let directory = root.appendingPathComponent("attachments")
        let preview = try ComposerAttachmentService.importFile(original, into: directory)
        #expect(URL(filePath: preview.reference.path).lastPathComponent == "任务.txt")
        #expect(preview.reference.kind == .text)
        #expect(preview.reference.byteSize == Data("附件正文".utf8).count)
        #expect(try Data(contentsOf: URL(filePath: preview.reference.path)) == Data("附件正文".utf8))
        ComposerAttachmentService.removeDraft(preview.reference, from: directory)
        #expect(!FileManager.default.fileExists(atPath: preview.reference.path))
        #expect(FileManager.default.fileExists(atPath: original.path))
        var outside = preview.reference
        outside.path = original.path
        ComposerAttachmentService.removeDraft(outside, from: directory)
        #expect(FileManager.default.fileExists(atPath: original.path))
    }

    @Test func imageImportNormalizesTIFFAndProducesBoundedPreview() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 320, pixelsHigh: 160,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        let tiff = try #require(bitmap.representation(using: .tiff, properties: [:]))
        let preview = try ComposerAttachmentService.importImage(tiff, into: directory)
        #expect(preview.reference.mimeType == "image/png")
        #expect(preview.reference.kind == .image)
        let image = try #require(NSBitmapImageRep(data: Data(contentsOf: URL(filePath: preview.reference.path))))
        #expect(image.pixelsWide == 320)
        let thumbnailData = try #require(preview.thumbnail)
        let thumbnail = try #require(NSBitmapImageRep(data: thumbnailData))
        #expect(thumbnail.pixelsWide <= 200)
        #expect(thumbnail.pixelsHigh <= 200)
    }
}
