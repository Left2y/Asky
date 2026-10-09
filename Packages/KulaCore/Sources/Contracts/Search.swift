import Foundation

/// Contract version. Draft until M0 freezes it; bump on any breaking change.
public enum ContractVersion {
    public static let current = "0.1-draft"
}

public enum SearchSource: String, Sendable, Codable, CaseIterable {
    case app, file, chromeTab, clipboard, keyword, calculator, conversion, currency, terminal, shortcut, askAI
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
