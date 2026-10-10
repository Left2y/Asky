import AppKit
import Contracts
import ImageIO
import UniformTypeIdentifiers

/// Explicit composer imports stay local until the user submits the task.
public enum ComposerAttachmentService {
    public struct Preview: Sendable {
        public let reference: AttachmentRef
        public let thumbnail: Data?
    }

    public static func importFile(_ source: URL, into directory: URL) throws -> Preview {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw CocoaError(.fileReadUnsupportedScheme) }
        let type = UTType(filenameExtension: source.pathExtension)
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(source.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            let kind: AttachmentKind = type?.conforms(to: .image) == true ? .image
                : type?.conforms(to: .text) == true ? .text : .file
            return preview(AttachmentRef(kind: kind, path: destination.path,
                mimeType: type?.preferredMIMEType ?? "application/octet-stream",
                byteSize: values.fileSize ?? 0, temporary: false))
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    public static func importImage(_ data: Data, into directory: URL) throws -> Preview {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("粘贴图片.png")
        guard let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(output, image, nil)
        guard CGImageDestinationFinalize(output) else { throw CocoaError(.fileWriteUnknown) }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        return preview(AttachmentRef(kind: .image, path: url.path, mimeType: "image/png", byteSize: size, temporary: false))
    }

    public static func preview(_ reference: AttachmentRef) -> Preview {
        var thumbnail: Data?
        if reference.kind == .image,
           let source = CGImageSourceCreateWithURL(URL(filePath: reference.path) as CFURL, nil),
           let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 200
           ] as CFDictionary) {
            let data = NSMutableData()
            if let output = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(output, image, nil)
                if CGImageDestinationFinalize(output) { thumbnail = data as Data }
            }
        }
        return Preview(reference: reference, thumbnail: thumbnail)
    }

    public static func removeDraft(_ reference: AttachmentRef, from directory: URL) {
        let url = URL(filePath: reference.path).standardizedFileURL
        let root = directory.standardizedFileURL
        guard url.path.hasPrefix(root.path + "/") else { return }
        try? FileManager.default.removeItem(at: url)
        let folder = url.deletingLastPathComponent()
        if folder != root, (try? FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty) == true {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    @MainActor public static func pastedFiles() -> [URL] {
        (NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }

    @MainActor public static func pastedImage() -> Data? {
        NSPasteboard.general.data(forType: .png) ?? NSPasteboard.general.data(forType: .tiff)
    }
}
