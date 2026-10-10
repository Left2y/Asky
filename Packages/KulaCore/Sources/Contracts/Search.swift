import Foundation

/// Contract version. Draft until M0 freezes it; bump on any breaking change.
public enum ContractVersion {
    public static let current = "0.1-draft"
}

public enum SearchSource: String, Sendable, Codable, CaseIterable {
    case app, file, link, bookmark, chromeTab, clipboard, keyword, calculator, conversion, currency, terminal, shortcut, askAI
}

/// Only web URLs may become launcher links; arbitrary schemes are never inferred.
public enum LauncherWebURL {
    public static func parse(_ text: String) -> URL? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !input.contains(where: { $0.isWhitespace }) else { return nil }
        let explicit = input.lowercased().hasPrefix("https://") || input.lowercased().hasPrefix("http://")
        guard let components = URLComponents(string: explicit ? input : "https://" + input),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.port.map({ (1...65535).contains($0) }) ?? true else { return nil }
        if !explicit {
            let labels = host.split(separator: ".", omittingEmptySubsequences: false)
            guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty && !$0.hasPrefix("-") && !$0.hasSuffix("-") &&
                $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } }),
                  let suffix = labels.last, suffix.count >= 2, suffix.allSatisfy(\.isLetter) else { return nil }
        }
        return components.url
    }
}

/// Stable reference to a concrete target; verified again before execution.
public struct TargetRef: Sendable, Hashable, Codable {
    public var kind: String
    public var identifier: String
    public init(kind: String, identifier: String) {
        self.kind = kind
        self.identifier = identifier
    }
}

public enum ResultAction: Sendable, Hashable, Codable {
    case open
    case revealInFinder
    case switchTo
    case copy(String)
    case openURL(URL)
    case runTerminal(command: String)
    case runShortcut(name: String)
    case askAI(prompt: String)
}

public struct SearchResult: Sendable, Hashable, Identifiable {
    public var id: String { "\(source.rawValue):\(target.identifier)" }
    public var source: SearchSource
    public var target: TargetRef
    public var title: String
    public var subtitle: String
    public var actions: [ResultAction]
    public var score: Double

    public init(source: SearchSource, target: TargetRef, title: String, subtitle: String = "",
                actions: [ResultAction], score: Double = 0) {
        self.source = source
        self.target = target
        self.title = title
        self.subtitle = subtitle
        self.actions = actions
        self.score = score
    }

    public var primaryAction: ResultAction? { actions.first }
}

/// Monotonic query identifier; results tagged with an older id are discarded.
public struct QueryID: Sendable, Hashable, Comparable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
    public static func < (l: QueryID, r: QueryID) -> Bool { l.value < r.value }
}

public struct SearchBatch: Sendable {
    public var queryID: QueryID
    public var provider: SearchSource
    public var results: [SearchResult]
    public init(queryID: QueryID, provider: SearchSource, results: [SearchResult]) {
        self.queryID = queryID
        self.provider = provider
        self.results = results
    }
}
