import Testing
import Foundation
import Contracts
import ToolService
import Adapters

struct ChromeBookmarksTests {
    private var fixture: Data {
        Data(#"{"roots":{"bookmark_bar":{"type":"folder","children":[{"type":"folder","children":[{"type":"url","name":"Swift Guide","url":"https://example.com/swift"}]},{"type":"url","name":"Unsafe","url":"javascript:alert(1)"},{"type":"url","name":"","url":"https://other.example.com"}]}}}"#.utf8)
    }

    @Test func nestedBookmarksAreMatchedByTitleAndURL() async throws {
        let data = fixture
        let provider = ChromeBookmarksProvider(load: { ChromeBookmarkService.decode(data) })
        let title = await provider.search("swift", limit: 8)
        #expect(title.map(\.title) == ["Swift Guide"])
        #expect(title.first?.primaryAction == .openURL(URL(string: "https://example.com/swift")!))
        let url = await provider.search("OTHER.EXAMPLE", limit: 1)
        #expect(url.map(\.title) == ["https://other.example.com"])
        #expect(await provider.search("not-matching", limit: 8).isEmpty)
        #expect(await provider.search("swift", limit: 0).isEmpty)
        #expect(ChromeBookmarkService.decode(data).count == 2)
        #expect(ChromeBookmarkService.decode(Data("broken".utf8)).isEmpty)
    }

    @Test func profilesAreDeduplicatedAndMissingFilesDoNotFail() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["Default", "Profile 1", "Profile 2", "Guest Profile"] {
            let profile = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
            if name != "Profile 2" { try fixture.write(to: profile.appendingPathComponent("Bookmarks")) }
        }
        #expect(ChromeBookmarkService.load(root: root).count == 2)
        let account = Data(#"{"roots":{"bookmark_bar":{"type":"folder","children":[{"type":"url","name":"Kimi","url":"https://www.kimi.com/code"}]}}}"#.utf8)
        try account.write(to: root.appendingPathComponent("Profile 2/AccountBookmarks"))
        #expect(ChromeBookmarkService.load(root: root).map(\.title).contains("Kimi"))
        #expect(ChromeBookmarkService.load(root: root.appendingPathComponent("missing")).isEmpty)
    }
}
