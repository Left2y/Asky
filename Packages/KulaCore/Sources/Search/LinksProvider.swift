import Foundation
import Contracts

public struct LinksProvider: SearchProvider {
    public let source = SearchSource.link
    public init() {}

    public func search(_ query: String, limit: Int) async -> [SearchResult] {
        guard limit > 0, !Task.isCancelled, let url = LauncherWebURL.parse(query) else { return [] }
        return [SearchResult(source: .link, target: TargetRef(kind: "url", identifier: url.absoluteString),
                             title: "打开链接", subtitle: url.absoluteString,
                             actions: [.openURL(url), .copy(url.absoluteString)], score: 1)]
    }
}
