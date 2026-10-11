import Foundation
import Contracts
import Search
import ToolService

public struct ChromeBookmarksProvider: SearchProvider {
    public let source = SearchSource.bookmark
    private let load: @Sendable () throws -> [ChromeBookmark]
    private let onFailure: @Sendable (String, ChromeBookmarkService.ReadFailure) -> Void

    public init(load: @escaping @Sendable () throws -> [ChromeBookmark] = { try ChromeBookmarkService.read() },
                onFailure: @escaping @Sendable (String, ChromeBookmarkService.ReadFailure) -> Void = { _, _ in }) {
        self.load = load
        self.onFailure = onFailure
    }

    public func search(_ query: String, limit: Int) async -> [SearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, limit > 0, !Task.isCancelled else { return [] }
        let bookmarks: [ChromeBookmark]
        do { bookmarks = try load() }
        catch {
            guard !Task.isCancelled else { return [] }
            onFailure(q, error as? ChromeBookmarkService.ReadFailure ?? .unreadable)
            return []
        }
        return bookmarks.compactMap { bookmark -> SearchResult? in
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
