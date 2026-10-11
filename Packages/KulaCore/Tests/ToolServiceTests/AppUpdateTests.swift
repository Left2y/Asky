import Foundation
import Testing
@testable import ToolService

@Suite struct AppUpdateTests {
    private static let page = URL(string: "https://github.com/Niall-Young/Asky/releases/tag/v0.0.9")!
    private static let assets = Data("""
    <a href="/Niall-Young/Asky/archive/refs/tags/v0.0.9.zip">Source</a>
    <a href="https://example.com/Niall-Young/Asky/releases/download/v0.0.9/Fake.zip">Other host</a>
    <a href="/Niall-Young/Asky/releases/download/v0.0.8/Old.zip">Old</a>
    <a href="/Niall-Young/Asky/releases/download/v0.0.9/Asky-0.0.9-macos-arm64.zip">ZIP</a>
    <a href="/Niall-Young/Asky/releases/download/v0.0.9/Asky-0.0.9-macos-arm64.zip.sha256">SHA</a>
    """.utf8)

    @Test func webFallbackExcludesSourceArchivesAndUnrelatedDownloads() throws {
        let release = try AppUpdate.parseWebRelease(pageURL: Self.page, assetsHTML: Self.assets)
        #expect(release.version == "0.0.9")
        #expect(release.archiveURL.lastPathComponent == "Asky-0.0.9-macos-arm64.zip")
        #expect(release.checksumURL?.lastPathComponent == "Asky-0.0.9-macos-arm64.zip.sha256")
        #expect(throws: AppUpdateError.missingArchive) {
            try AppUpdate.parseWebRelease(pageURL: Self.page, assetsHTML: Data(#"<a href="/Niall-Young/Asky/archive/refs/tags/v0.0.9.zip">Source</a>"#.utf8))
        }
        #expect(throws: AppUpdateError.noRelease) {
            try AppUpdate.parseWebRelease(pageURL: AppUpdate.latestPageURL, assetsHTML: Self.assets)
        }
    }

    private actor Server {
        var apiCalls = 0
        let status: Int
        init(status: Int) { self.status = status }
        func fetch(_ request: URLRequest) throws -> (Data, URLResponse) {
            let url = try #require(request.url)
            if url == AppUpdate.latestReleaseURL {
                apiCalls += 1
                return (Data(), HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                    headerFields: ["x-ratelimit-reset": String(Date().addingTimeInterval(3600).timeIntervalSince1970)])!)
            }
            #expect(request.value(forHTTPHeaderField: "Accept") == nil)
            if url == AppUpdate.latestPageURL {
                return (Data(), HTTPURLResponse(url: AppUpdateTests.page, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            #expect(url.absoluteString == "https://github.com/Niall-Young/Asky/releases/expanded_assets/v0.0.9")
            return (AppUpdateTests.assets, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }

    @Test(arguments: [403, 429]) func limitedAPIFallsBackAndHonorsCooldown(status: Int) async throws {
        let server = Server(status: status)
        let lookup = AppReleaseLookup()
        for _ in 0..<2 {
            let release = try await lookup.latest(fetch: { try await server.fetch($0) })
            #expect(release.version == "0.0.9")
            #expect(release.checksumURL != nil)
        }
        #expect(await server.apiCalls == 1)
    }

    @Test func missingReleaseRemainsAnError() async {
        let server = Server(status: 404)
        await #expect(throws: AppUpdateError.noRelease) {
            try await AppReleaseLookup().latest(fetch: { try await server.fetch($0) })
        }
    }

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
