import Testing
import Foundation
import Contracts
@testable import Search

struct StubProvider: SearchProvider {
    let source: SearchSource
    let delay: Duration
    let title: String
    func search(_ query: String, limit: Int) async -> [SearchResult] {
        try? await Task.sleep(for: delay)
        if Task.isCancelled { return [] }
        return [SearchResult(source: source, target: TargetRef(kind: "x", identifier: "\(title)-\(query)"),
                             title: "\(title) \(query)", actions: [.open], score: 0.5)]
    }
}

@MainActor
final class BatchSink {
    var batches: [SearchBatch] = []
}

@Suite struct SearchTests {
    @Test @MainActor func lateBatchesFromSupersededQueriesAreDropped() async throws {
        let coord = SearchCoordinator(providers: [StubProvider(source: .file, delay: .milliseconds(150), title: "slow"),
                                                  StubProvider(source: .app, delay: .milliseconds(1), title: "fast")])
        let sink = BatchSink()
        let first = coord.query("a") { b in sink.batches.append(b) }
        let second = coord.query("ab") { b in sink.batches.append(b) }
        #expect(second > first)
        try await Task.sleep(for: .milliseconds(400))
        #expect(!sink.batches.isEmpty)
        #expect(sink.batches.allSatisfy { $0.queryID == second })
        #expect(sink.batches.count == 2)
    }

    @Test @MainActor func emptyQueryDeliversNothing() async throws {
        let coord = SearchCoordinator(providers: [StubProvider(source: .app, delay: .zero, title: "x")])
        let sink = BatchSink()
        coord.query("   ") { b in sink.batches.append(b) }
        try await Task.sleep(for: .milliseconds(50))
        #expect(sink.batches.isEmpty)
    }

    @Test func fuzzyRanking() throws {
        let exact = try #require(FuzzyMatch.score("safari", in: "Safari"))
        let prefix = try #require(FuzzyMatch.score("saf", in: "Safari"))
        let initials = try #require(FuzzyMatch.score("vsc", in: "Visual Studio Code"))
        let sub = try #require(FuzzyMatch.score("sfr", in: "Safari"))
        #expect(exact > prefix && prefix > initials && initials > sub)
        #expect(FuzzyMatch.score("xyz", in: "Safari") == nil)
    }

    @Test func mergerDedupesAndOrders() {
        let a = SearchResult(source: .app, target: TargetRef(kind: "app", identifier: "/A.app"), title: "A", actions: [.open], score: 0.5)
        let calc = SearchResult(source: .calculator, target: TargetRef(kind: "calc", identifier: "1"), title: "1", actions: [.open], score: 0.5)
        let merged = ResultMerger.merge([SearchBatch(queryID: QueryID(1), provider: .app, results: [a, a]),
                                         SearchBatch(queryID: QueryID(1), provider: .calculator, results: [calc])])
        #expect(merged.map(\.source) == [.calculator, .app])
    }

    @Test func appsProviderScansGivenRoots() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for n in ["Kula Notes.app", "Other.app", "readme.txt"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(n), withIntermediateDirectories: true)
        }
        let p = AppsProvider(roots: [root])
        let r = await p.search("kula", limit: 5)
        #expect(r.map(\.title) == ["Kula Notes"])
    }

    @Test func appsProviderMatchesLocalizedAndEnglishNames() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for (english, chinese, localization) in [("WeChat", "微信", "zh-Hans"), ("DingTalk", "钉钉", "zh_CN")] {
            let contents = root.appendingPathComponent("\(english).app/Contents")
            let resources = contents.appendingPathComponent("Resources/\(localization).lproj")
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
            let info: [String: String] = ["CFBundleName": english, "CFBundleIdentifier": "test.\(english)",
                                         "CFBundleDevelopmentRegion": "en", "CFBundlePackageType": "APPL"]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
                .write(to: contents.appendingPathComponent("Info.plist"))
            if english == "DingTalk" {
                try "\"CFBundleDisplayName\" = \"\(chinese)\";".data(using: .utf16)!
                    .write(to: resources.appendingPathComponent("InfoPlist.strings"))
            } else {
                try PropertyListSerialization.data(fromPropertyList: ["CFBundleDisplayName": chinese], format: .xml, options: 0)
                    .write(to: resources.appendingPathComponent("InfoPlist.strings"))
            }
        }
        let provider = AppsProvider(roots: [root, root])
        for (english, chinese) in [("WeChat", "微信"), ("DingTalk", "钉钉")] {
            for query in [english, chinese] {
                let results = await provider.search(query, limit: 5)
                #expect(results.count == 1)
                #expect(results.first.map { URL(fileURLWithPath: $0.target.identifier).lastPathComponent } == "\(english).app")
            }
        }
        #expect(await provider.search("不存在的应用", limit: 5).isEmpty)
    }

    @Test func appsProviderMatchesSystemLoctableNames() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for (app, format) in [("Phone", PropertyListSerialization.PropertyListFormat.binary),
                              ("Notes", PropertyListSerialization.PropertyListFormat.xml)] {
            let contents = root.appendingPathComponent("\(app).app/Contents")
            let resources = contents.appendingPathComponent("Resources")
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
            try PropertyListSerialization.data(fromPropertyList: ["CFBundleName": app], format: .xml, options: 0)
                .write(to: contents.appendingPathComponent("Info.plist"))
            let table: [String: Any] = [
                "en": ["CFBundleDisplayName": app],
                "zh_CN": ["CFBundleDisplayName": app == "Phone" ? "电话" : "备忘录"],
                "zh_TW": ["CFBundleName": app == "Phone" ? "電話" : "備忘錄"],
                "fr": ["CFBundleDisplayName": ""],
                "meta": "ignored", "invalid": ["CFBundleName": 42],
                "copyright": ["NSHumanReadableCopyright": "DoNotIndexThis"]
            ]
            try PropertyListSerialization.data(fromPropertyList: table, format: format, options: 0)
                .write(to: resources.appendingPathComponent("InfoPlist.loctable"))
        }
        let provider = AppsProvider(roots: [root])
        for (query, app) in [("电话", "Phone"), ("電話", "Phone"), ("Phone", "Phone"),
                             ("备忘录", "Notes"), ("備忘錄", "Notes"), ("Notes", "Notes")] {
            let results = await provider.search(query, limit: 5)
            #expect(results.count == 1)
            #expect(results.first.map { URL(fileURLWithPath: $0.target.identifier).lastPathComponent } == "\(app).app")
        }
        #expect(await provider.search("DoNotIndexThis", limit: 5).isEmpty)
    }

    @Test func appsProviderIncludesFinderHiddenAppsButSkipsDotEntries() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var app = root.appendingPathComponent("VisibleSearch.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isHidden = true
        try app.setResourceValues(values)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".Internal.app"), withIntermediateDirectories: true)
        let provider = AppsProvider(roots: [root])
        #expect(await provider.search("VisibleSearch", limit: 5).count == 1)
        #expect(await provider.search("Internal", limit: 5).isEmpty)
    }

}
