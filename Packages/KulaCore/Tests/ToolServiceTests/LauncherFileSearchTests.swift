import Foundation
import Testing
@testable import ToolService

@Suite struct LauncherFileSearchTests {
    @Test func excludedRecentCachesCannotStarveExactFolder() {
        let caches = (0..<100).map { "/Users/test/Library/Application Support/orca/orca-cache-\($0).json" }
        let paths = caches + ["/Users/test/work/2026-orca-cli.md", "/Users/test/orca"]
        let rows = LauncherFileRanking.results(paths: paths, query: "orca", excluded: [], limit: 8)
        #expect(rows.map(\.title) == ["orca", "2026-orca-cli.md"])
    }

    @Test func relevancePrecedesRecencyAndLimit() {
        let partials = (0..<100).map { "/Users/test/work/notes-orca-\($0).md" }
        let rows = LauncherFileRanking.results(paths: partials + ["/Users/test/orca-tools", "/Users/test/Orca"],
                                               query: "ORCA", excluded: [], limit: 2)
        #expect(rows.map(\.title) == ["Orca", "orca-tools"])
        #expect(rows.first?.score == 1)
    }

    @Test func exclusionsRespectNamesAndPathBoundaries() {
        let paths = ["/Users/test/node_modules/orca.js", "/Users/test/.git/orca", "/Users/test/.hidden/orca",
                     "/Users/test/private/orca", "/Users/test/private-copy/orca", "/Users/test/orca"]
        let rows = LauncherFileRanking.results(paths: paths, query: "orca",
                                               excluded: ["node_modules", "/Users/test/private"], limit: 8)
        #expect(rows.map(\.target.identifier) == ["/Users/test/private-copy/orca", "/Users/test/orca"])
    }

    @Test func equalMatchesKeepRecencyAndDeduplicate() {
        let paths = ["/new/orca.md", "/new/orca.md", "/old/orca.md"]
        #expect(LauncherFileRanking.results(paths: paths, query: "orca", excluded: [], limit: 8)
            .map(\.target.identifier) == ["/new/orca.md", "/old/orca.md"])
        #expect(LauncherFileRanking.results(paths: paths, query: "orca", excluded: [], limit: 0).isEmpty)
        #expect(LauncherFileRanking.results(paths: paths, query: "orca", excluded: ["/"], limit: 8).isEmpty)
    }

    @Test func disabledScopesAndCancelledSearchReturnNothing() async {
        #expect(await ToolService.searchLauncherFiles(query: "orca", scopes: [], excluded: []).isEmpty)
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            return await ToolService.searchLauncherFiles(query: "orca", scopes: [URL(fileURLWithPath: "/")], excluded: [])
        }
        task.cancel()
        #expect(await task.value.isEmpty)
    }
}
