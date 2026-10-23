import AppKit
import Testing
@testable import ToolService

@Suite struct LauncherRowPresentationTests {
    @Test @MainActor func coldFileArtworkIsDecodedAndWarmLookupReusesIt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("report.pdf")
        try Data().write(to: file)
        let request = LauncherArtworkRequest.file(path: file.path, includeType: true)
        #expect(ToolService.cachedLauncherPresentation(for: request) == nil)
        let loaded = try #require(await ToolService.loadLauncherPresentation(for: request))
        #expect(loaded.fileType == "PDF")
        let bitmap = try #require(loaded.icon?.representations.first as? NSBitmapImageRep)
        #expect(bitmap.pixelsWide == 96 && bitmap.pixelsHigh == 96)
        #expect(ToolService.cachedLauncherPresentation(for: request)?.icon === loaded.icon)
    }

    @Test func directoryExtensionDoesNotBecomeItsType() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).assets")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let loaded = await ToolService.loadLauncherPresentation(for: .file(path: folder.path, includeType: true))
        #expect(loaded?.fileType != nil)
        #expect(loaded?.fileType != "ASSETS")
    }

    @Test func cancelledRowsDoNotStartColdLookups() async {
        let request = LauncherArtworkRequest.file(path: "/tmp/\(UUID())")
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            return await ToolService.loadLauncherPresentation(for: request)
        }
        task.cancel()
        #expect(await task.value == nil)
        #expect(ToolService.cachedLauncherPresentation(for: request) == nil)
    }
}
