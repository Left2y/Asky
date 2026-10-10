import Foundation
import Contracts
import Synchronization

/// A local search source. Must honour cancellation and return a bounded batch.
public protocol SearchProvider: Sendable {
    var source: SearchSource { get }
    func search(_ query: String, limit: Int) async -> [SearchResult]
}

/// Fans a query out to providers, tags batches with a monotonically increasing QueryID and
/// drops late batches from superseded queries. The previous query's tasks are cancelled on each keystroke.
public final class SearchCoordinator: Sendable {
    public typealias BatchHandler = @Sendable @MainActor (SearchBatch) -> Void

    private let providers: [any SearchProvider]
    private let perProviderLimit: Int
    private let state = LockedState()

    public init(providers: [any SearchProvider], perProviderLimit: Int = 8) {
        self.providers = providers
        self.perProviderLimit = perProviderLimit
    }

    /// Starts a new query; returns its ID. Batches for older IDs are never delivered.
    @discardableResult
    public func query(_ text: String, onBatch: @escaping BatchHandler) -> QueryID {
        let (id, old) = state.next()
        old.forEach { $0.cancel() }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return id }
        var tasks: [Task<Void, Never>] = []
        for p in providers {
            let limit = perProviderLimit
            tasks.append(Task.detached(priority: .userInitiated) { [state] in
                let results = await p.search(trimmed, limit: limit)
                guard !Task.isCancelled, state.isCurrent(id) else { return }
                let batch = SearchBatch(queryID: id, provider: p.source, results: Array(results.prefix(limit)))
                await MainActor.run {
                    guard state.isCurrent(id) else { return }
                    onBatch(batch)
                }
            })
        }
        state.setTasks(tasks, for: id)
        return id
    }

    public func cancel() {
        let (_, old) = state.next()
        old.forEach { $0.cancel() }
    }

    public func isCurrent(_ id: QueryID) -> Bool { state.isCurrent(id) }
}

final class LockedState: Sendable {
    private struct S {
        var current: UInt64 = 0
        var tasks: [Task<Void, Never>] = []
    }
    private let m = Mutex(S())

    func next() -> (QueryID, [Task<Void, Never>]) {
        m.withLock { s in
            s.current += 1
            defer { s.tasks = [] }
            return (QueryID(s.current), s.tasks)
        }
    }

    func setTasks(_ t: [Task<Void, Never>], for id: QueryID) {
        let stale = m.withLock { s -> Bool in
            guard id.value == s.current else { return true }
            s.tasks = t
            return false
        }
        if stale { t.forEach { $0.cancel() } }
    }

    func isCurrent(_ id: QueryID) -> Bool { m.withLock { id.value == $0.current } }
}

/// Merges batches for display: dedupes by result id and orders by score, then source priority.
public struct ResultMerger: Sendable {
    public static let sourceOrder: [SearchSource] = [
        .calculator, .conversion, .currency, .keyword, .terminal, .link, .app, .bookmark, .chromeTab, .shortcut, .file, .clipboard, .askAI,
    ]

    public static func merge(_ batches: [SearchBatch], limit: Int = 40) -> [SearchResult] {
        var seen = Set<String>()
        var all: [SearchResult] = []
        for b in batches { for r in b.results where seen.insert(r.id).inserted { all.append(r) } }
        let rank = Dictionary(uniqueKeysWithValues: sourceOrder.enumerated().map { ($1, $0) })
        return Array(all.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return (rank[$0.source] ?? 99) < (rank[$1.source] ?? 99)
        }.prefix(limit))
    }
}

/// Simple subsequence / prefix fuzzy scorer for app and tab titles (case and diacritic insensitive).
public enum FuzzyMatch {
    public static func score(_ query: String, in candidate: String) -> Double? {
        let q = normalize(query), c = normalize(candidate)
        guard !q.isEmpty else { return nil }
        if c == q { return 1.0 }
        if c.hasPrefix(q) { return 0.9 }
        let words = c.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" || $0 == "." })
        if words.contains(where: { $0.hasPrefix(q) }) { return 0.8 }
        let initials = String(words.compactMap(\.first))
        if initials.hasPrefix(q) { return 0.75 }
        if c.contains(q) { return 0.6 }
        var it = c.makeIterator()
        var matched = 0
        outer: for ch in q {
            while let x = it.next() {
                if x == ch { matched += 1; continue outer }
            }
            return nil
        }
        return matched == q.count ? 0.4 * Double(q.count) / Double(max(c.count, 1)) + 0.2 : nil
    }

    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
