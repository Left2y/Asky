import Foundation
import Contracts
import Search
import ToolService

public struct ChromeBookmarksProvider: SearchProvider {
    public let source = SearchSource.bookmark
    private let load: @Sendable () -> [ChromeBookmark]

    public init(load: @escaping @Sendable () -> [ChromeBookmark] = { ChromeBookmarkService.load() }) {
        self.load = load
    }

    public func search(_ query: String, limit: Int) async -> [SearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, limit > 0, !Task.isCancelled else { return [] }
        return load().compactMap { bookmark -> SearchResult? in
            guard !Task.isCancelled else { return nil }
            let titleScore = FuzzyMatch.score(q, in: bookmark.title)
            let urlScore = bookmark.url.absoluteString.localizedCaseInsensitiveContains(q) ? 0.5 : 0.0
            let score = max(titleScore ?? 0, urlScore)
            guard score > 0 else { return nil }
            return SearchResult(source: .bookmark, target: TargetRef(kind: "url", identifier: bookmark.url.absoluteString),
                                title: bookmark.title, subtitle: bookmark.url.absoluteString,
                                actions: [.openURL(bookmark.url), .copy(bookmark.url.absoluteString)], score: score)
        }.sorted { $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score }.prefix(limit).map { $0 }
    }
}
