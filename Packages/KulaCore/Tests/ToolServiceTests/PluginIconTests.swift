import Foundation
import Testing
import Contracts
import LocalStore
@testable import ToolService

@Suite struct PluginIconTests {
    @Test func legacyManifestAndConfinedArtwork() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appending(path: "plugins/example")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = Data(#"{"id":"example","name":"Example","version":"1","apiVersion":1,"entry":"index.mjs","tools":[]}"#.utf8)
        var manifest = try JSONDecoder().decode(PluginManifest.self, from: json)
        #expect(manifest.icon == nil)
        let store = try LocalStore(root: root)
        func manager(icon: String?) -> PluginManager {
            manifest.icon = icon
            let plugin = InstalledPlugin(manifest: manifest, repository: "https://github.com/example/plugin", commit: "1", enabled: true, configuration: [:])
            store.setCodableSetting("plugins.installed", [plugin])
            return PluginManager(store: store)
        }
        let image = Data([1, 2, 3])
        try image.write(to: directory.appending(path: "icon.png"))
        #expect(await manager(icon: nil).iconData(for: "example") == nil)
        #expect(await manager(icon: "icon.png").iconData(for: "example") == image)
        #expect(await manager(icon: "missing.png").iconData(for: "example") == nil)
        try image.write(to: root.appending(path: "outside.png"))
        #expect(await manager(icon: "../../outside.png").iconData(for: "example") == nil)
        #expect(await manager(icon: root.appending(path: "outside.png").path).iconData(for: "example") == nil)
        try FileManager.default.createSymbolicLink(at: directory.appending(path: "escape.png"), withDestinationURL: root.appending(path: "outside.png"))
        #expect(await manager(icon: "escape.png").iconData(for: "example") == nil)
        try Data(repeating: 0, count: 2 * 1024 * 1024 + 1).write(to: directory.appending(path: "large.png"))
        #expect(await manager(icon: "large.png").iconData(for: "example") == nil)
        #expect(await manager(icon: "icon.png").iconData(for: "unknown") == nil)
    }
}
