import Foundation
import Testing
@testable import ToolService

@Suite struct AppUpdateTests {
    @Test func parsesReleaseAndPrefersMacArchiveWithChecksum() throws {
        let json = """
        {"tag_name":"v0.0.3","name":"Asky 0.0.3","html_url":"https://github.com/Niall-Young/Asky/releases/tag/v0.0.3",
         "assets":[
          {"name":"Source.zip","browser_download_url":"https://example.com/Source.zip"},
          {"name":"Asky-0.0.3-macos-arm64.zip","browser_download_url":"https://example.com/Asky-0.0.3-macos-arm64.zip"},
          {"name":"Asky-0.0.3-macos-arm64.zip.sha256","browser_download_url":"https://example.com/Asky-0.0.3-macos-arm64.zip.sha256"}]}
        """
        let release = try AppUpdate.parseRelease(Data(json.utf8))
        #expect(release.version == "0.0.3")
        #expect(release.name == "Asky 0.0.3")
        #expect(release.archiveURL.lastPathComponent == "Asky-0.0.3-macos-arm64.zip")
        #expect(release.checksumURL?.lastPathComponent == "Asky-0.0.3-macos-arm64.zip.sha256")
    }

    @Test func releaseWithoutArchiveIsRejected() {
        let json = #"{"tag_name":"v1","html_url":"https://example.com","assets":[]}"#
        #expect(throws: AppUpdateError.missingArchive) { try AppUpdate.parseRelease(Data(json.utf8)) }
    }

    @Test func onlyHigherVersionsAreUpdates() {
        #expect(AppUpdate.isNewer("v0.0.3", than: "0.0.2"))
        #expect(AppUpdate.isNewer("0.0.10", than: "0.0.9"))
        #expect(AppUpdate.isNewer("1.0", than: "0.9.9"))
        #expect(!AppUpdate.isNewer("v0.0.2", than: "0.0.2"))
        #expect(!AppUpdate.isNewer("1.0", than: "1.0.0"))
        #expect(!AppUpdate.isNewer("0.0.2", than: "0.1.0"))
    }

    @Test func checksumParsingAndHashing() throws {
        let line = "623573c5f1258067bf39043c4ed68a00836f7a5a72b053947bb6710b723fe0d3  Asky-0.0.2-macos-arm64.zip\n"
        #expect(AppUpdate.parseChecksum(line) == "623573c5f1258067bf39043c4ed68a00836f7a5a72b053947bb6710b723fe0d3")
        #expect(AppUpdate.parseChecksum("Not Found") == nil)
        let file = FileManager.default.temporaryDirectory.appending(path: "asky-update-\(UUID()).txt")
        try Data("abc".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(try AppUpdate.sha256(of: file) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
