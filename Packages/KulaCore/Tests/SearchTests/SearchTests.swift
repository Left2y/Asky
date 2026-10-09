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
}
