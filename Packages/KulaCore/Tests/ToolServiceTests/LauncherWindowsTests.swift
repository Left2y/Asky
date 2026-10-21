import Testing
import Contracts
@testable import ToolService

struct LauncherWindowsTests {
    private let entries: [LauncherWindowSnapshot.Entry] = [
        .init(id: "editor-1", title: "README.md", application: "Editor", applicationPath: "/Applications/Editor.app"),
        .init(id: "editor-2", title: "README.md", application: "Editor", applicationPath: "/Applications/Editor.app"),
        .init(id: "browser-1", title: "文档", application: "Browser", applicationPath: "/Applications/Browser.app"),
        .init(id: "untitled", title: "", application: "Editor", applicationPath: "/Applications/Editor.app")
    ]

    @Test func listsDistinctWindowsEvenWhenTitlesMatch() {
        let rows = LauncherWindowSnapshot.results(from: entries, query: "")
        #expect(rows.count == 4)
        #expect(Set(rows.map(\.id)).count == 4)
        #expect(rows[0].target.identifier != rows[1].target.identifier)
        #expect(rows.allSatisfy { $0.primaryAction == .switchTo })
        #expect(rows.last?.title == "Editor")
    }

    @Test func matchesApplicationAndWindowTitleTogether() {
        #expect(LauncherWindowSnapshot.results(from: entries, query: "EDITOR readme").count == 2)
        #expect(LauncherWindowSnapshot.results(from: entries, query: "文档").map(\.target.identifier) == ["browser-1"])
        #expect(LauncherWindowSnapshot.results(from: entries, query: "missing").isEmpty)
    }
}
