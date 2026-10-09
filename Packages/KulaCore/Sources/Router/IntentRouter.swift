import Foundation
import Contracts
import DirectActions

/// Result of local routing. Ordinary input never calls a model; the terminal only runs via explicit `>`.
public enum Route: Sendable, Equatable {
    case empty
    case calculation(expression: String, value: Double)
    case conversion(ConversionResult)
    case currency(CurrencyQuery)
    case keyword(KeywordCommand, query: String)
    case terminal(command: String)
    case search(query: String)
}

public enum SubmitKind: Sendable, Equatable {
    /// Return: execute the selected result.
    case executeSelection
    /// ⌘Return: explicitly hand the raw input to the AI.
    case submitToAI
}

public struct IntentRouter: Sendable {
    public var keywords: KeywordRegistry

    public init(keywords: KeywordRegistry = KeywordRegistry()) { self.keywords = keywords }

    /// Priority: explicit terminal → calculation → unit / currency → keyword → search.
    public func route(_ raw: String) -> Route {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty { return .empty }
        if input.hasPrefix(">") {
            let cmd = input.dropFirst().trimmingCharacters(in: .whitespaces)
            return cmd.isEmpty ? .search(query: input) : .terminal(command: cmd)
        }
        if let v = Calculator.evaluate(input) { return .calculation(expression: input, value: v) }
        if let c = UnitConverter.convert(input) { return .conversion(c) }
        if let q = CurrencyQuery.parse(input) { return .currency(q) }
        if let (cmd, q) = keywords.match(input) { return .keyword(cmd, query: q) }
        return .search(query: input)
    }

    /// Whether the route should also run search providers alongside its direct result.
    public func includesSearch(_ route: Route) -> Bool {
        switch route {
        case .search: true
        case .empty, .terminal, .calculation, .conversion, .currency, .keyword: false
        }
    }

    /// The "Ask AI" result always appended for non-empty input. It is an action, not an automatic call.
    public func askAIResult(for raw: String) -> SearchResult? {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }
        return SearchResult(source: .askAI, target: TargetRef(kind: "ai", identifier: "ask"),
                            title: "询问 AI：\(input)", subtitle: "⌘↩ 提交给 AI", actions: [.askAI(prompt: input)], score: -1)
    }

    /// Builds direct-result rows for a non-search route (currency is resolved asynchronously by the caller).
    public func directResults(for route: Route) -> [SearchResult] {
        switch route {
        case .calculation(let expr, let v):
            let s = Calculator.format(v)
            return [SearchResult(source: .calculator, target: TargetRef(kind: "calc", identifier: expr),
                                 title: s, subtitle: "\(expr) · ↩ 复制", actions: [.copy(s)], score: 100)]
        case .conversion(let c):
            let v = Calculator.format((c.value * 1e6).rounded() / 1e6)
            return [SearchResult(source: .conversion, target: TargetRef(kind: "unit", identifier: c.display),
                                 title: "\(v) \(c.toSymbol)", subtitle: "\(c.display) · ↩ 复制", actions: [.copy(v)], score: 100)]
        case .keyword(let cmd, let q):
            guard let url = cmd.url(for: q) else { return [] }
            return [SearchResult(source: .keyword, target: TargetRef(kind: "url", identifier: url.absoluteString),
                                 title: "\(cmd.name)：\(q)", subtitle: url.absoluteString, actions: [.openURL(url)], score: 100)]
        case .terminal(let cmd):
            return [SearchResult(source: .terminal, target: TargetRef(kind: "terminal", identifier: cmd),
                                 title: "运行：\(cmd)", subtitle: "显式终端命令 · ↩ 执行", actions: [.runTerminal(command: cmd)], score: 100)]
        case .currency, .search, .empty:
            return []
        }
    }
}
