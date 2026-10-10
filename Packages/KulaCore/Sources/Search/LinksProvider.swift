import Foundation
import Contracts

public struct LinksProvider: SearchProvider {
    public let source = SearchSource.link
    /// Sites the user already knows (bookmarks, open tabs). Bare words only complete against these.
    private let knownSites: @Sendable () -> [URL]

    public init(knownSites: @escaping @Sendable () -> [URL] = { [] }) {
        self.knownSites = knownSites
    }

    public func search(_ query: String, limit: Int) async -> [SearchResult] {
        guard limit > 0, !Task.isCancelled,
              let url = LauncherWebURL.parse(query) ?? Self.complete(query, from: knownSites()) else { return [] }
        return [SearchResult(source: .link, target: TargetRef(kind: "url", identifier: url.absoluteString),
                             title: "打开链接", subtitle: url.absoluteString,
                             actions: [.openURL(url), .copy(url.absoluteString)], score: 1)]
    }

    /// A single ASCII word such as `happy` completes to the root of a known site whose
    /// host starts with it (`https://www.happyoyster.com`). Unknown words produce no link.
    static func complete(_ query: String, from sites: [URL]) -> URL? {
        let word = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard word.count >= 2, word.count <= 63,
              word.allSatisfy({ ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "-" }),
              word.contains(where: \.isLetter) else { return nil }
        var best: (host: String, root: URL)?
        for site in sites {
            guard let host = site.host()?.lowercased(), let scheme = site.scheme else { continue }
            let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            guard bare.hasPrefix(word), best.map({ bare.count < $0.host.count }) ?? true,
                  let root = URL(string: "\(scheme)://\(host)") else { continue }
            best = (bare, root)
        }
        return best?.root
    }
}
