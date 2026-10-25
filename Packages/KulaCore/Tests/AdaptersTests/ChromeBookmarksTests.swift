import Testing
import os
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
        let access = try root.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        #expect(try ChromeBookmarkService.read(accessBookmark: access).map(\.title).contains("Kimi"))
        #expect(ChromeBookmarkService.accessState(accessBookmark: access) == .authorized)
        #expect(ChromeBookmarkService.load(root: root.appendingPathComponent("missing")).isEmpty)
    }
    @Test func readFailuresReachProviderWithoutBecomingMissingMatches() async throws {
        let failures = OSAllocatedUnfairLock<[ChromeBookmarkService.ReadFailure]>(initialState: [])
        let provider = ChromeBookmarksProvider(load: { throw ChromeBookmarkService.ReadFailure.permissionDenied },
                                               onFailure: { _, failure in failures.withLock { $0.append(failure) } })
        #expect(await provider.search("deepseek", limit: 8).isEmpty)
        #expect(failures.withLock { $0 } == [.permissionDenied])
        #expect(ChromeBookmarkService.accessState(accessBookmark: Data("invalid".utf8)) == .denied)
        #expect(ChromeBookmarkService.accessState(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)) == .missing)
        #expect(throws: ChromeBookmarkService.ReadFailure.permissionDenied) {
            try ChromeBookmarkService.read(accessBookmark: Data("invalid".utf8))
        }
        #expect(try ChromeBookmarkService.read(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)).isEmpty)
    }

    @Test func pickerParentAndProfileResolveTheSameBookmarks() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let chrome = parent.appendingPathComponent("Chrome")
        let profile = chrome.appendingPathComponent("Default")
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        try fixture.write(to: profile.appendingPathComponent("AccountBookmarks"))
        for folder in [parent, chrome, profile] {
            let access = try folder.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            #expect(try ChromeBookmarkService.read(accessBookmark: access).count == 2)
            #expect(ChromeBookmarkService.accessState(accessBookmark: access) == .authorized)
        }
        let unrelated = parent.appendingPathComponent("Unrelated")
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)
        #expect(ChromeBookmarkService.accessState(root: unrelated) == .invalidFolder)
        #expect(throws: ChromeBookmarkService.ReadFailure.invalidFolder) { try ChromeBookmarkService.read(root: unrelated) }
    }

}
