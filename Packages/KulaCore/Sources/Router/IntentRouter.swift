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
    /// An explicit conversational request; typing only prepares the AI action.
    case conversation(prompt: String)
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
    public var terminalKeyword: String

    public init(keywords: KeywordRegistry = KeywordRegistry(),
                terminalKeyword: String = LauncherInputState.defaultTerminalKeyword) {
        self.keywords = keywords
        self.terminalKeyword = terminalKeyword
    }

    /// Priority: explicit terminal → calculation → unit / currency → keyword → conversation → search.
    public func route(_ raw: String) -> Route {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty { return .empty }
        if let command = LauncherInputState.matchTerminal(raw, keyword: terminalKeyword) {
            let cmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
            return cmd.isEmpty ? .search(query: input) : .terminal(command: cmd)
        }
        if let v = Calculator.evaluate(input) { return .calculation(expression: input, value: v) }
        if let c = UnitConverter.convert(input) { return .conversion(c) }
        if let q = CurrencyQuery.parse(input) { return .currency(q) }
        if let (cmd, q) = keywords.match(input) { return .keyword(cmd, query: q) }
        if Self.isConversation(input) { return .conversation(prompt: input) }
        return .search(query: input)
    }

    /// Conservative local cues: names and fragments remain search queries.
    /// Explicit commands are resolved first and never overridden by these cues.
    private static func isConversation(_ input: String) -> Bool {
        let text = input.lowercased()
        let requests = ["帮我", "帮忙", "请帮", "请问", "请解释", "请总结", "请分析", "请整理", "请安排", "请翻译",
                        "如何", "怎么", "为什么", "能否", "能不能", "可不可以"]
        if requests.contains(where: { text.hasPrefix($0) && text.count > $0.count }) { return true }
        let english = ["help me ", "please ", "how do ", "how can ", "how to ", "why does ", "why is ",
                       "what is ", "what are ", "can you ", "could you ", "summarize ", "explain ", "translate "]
        if english.contains(where: { text.hasPrefix($0) && text.count > $0.count }) { return true }
        return text.count > 3 && (text.hasSuffix("吗") || text.hasSuffix("吗？") || text.hasSuffix("吗?"))
    }

    /// Whether the route should also run search providers alongside its direct result.
    public func includesSearch(_ route: Route) -> Bool {
        switch route {
        case .search: true
        case .empty, .terminal, .calculation, .conversion, .currency, .keyword, .conversation: false
        }
    }

    /// Builds an AI action for non-empty input, without making a model call.
    public func askAIResult(for raw: String) -> SearchResult? {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }
        return SearchResult(source: .askAI, target: TargetRef(kind: "ai", identifier: "ask"),
                            title: "询问 AI：\(input)", actions: [.askAI(prompt: input)], score: -1)
    }

    /// Builds direct-result rows for a non-search route (currency is resolved asynchronously by the caller).
    public func directResults(for route: Route) -> [SearchResult] {
        switch route {
        case .conversation(let prompt):
            guard let result = askAIResult(for: prompt) else { return [] }
            return [result]
        case .calculation(let expr, let v):
            let s = Calculator.format(v)
            return [SearchResult(source: .calculator, target: TargetRef(kind: "calc", identifier: expr),
                                 title: s, subtitle: expr, actions: [.copy(s)], score: 100)]
        case .conversion(let c):
            let v = Calculator.format((c.value * 1e6).rounded() / 1e6)
            return [SearchResult(source: .conversion, target: TargetRef(kind: "unit", identifier: c.display),
                                 title: "\(v) \(c.toSymbol)", subtitle: "\(c.display) · ↩ 复制", actions: [.copy(v)], score: 100)]
        case .keyword(let cmd, let q):
            guard let url = cmd.url(for: q) else { return [] }
            return [SearchResult(source: .keyword, target: TargetRef(kind: "url", identifier: url.absoluteString),
                                 title: cmd.supportsQuery ? "\(cmd.name)：\(q)" : "打开 \(cmd.name)",
                                 subtitle: cmd.supportsQuery ? url.absoluteString : "仅打开网页，问题不会传递到网站", actions: [.openURL(url)], score: 100)]
        case .terminal(let cmd):
            return [SearchResult(source: .terminal, target: TargetRef(kind: "terminal", identifier: cmd),
                                 title: "运行：\(cmd)", subtitle: "↩ 在终端中运行", actions: [.runTerminal(command: cmd)], score: 100)]
        case .currency, .search, .empty:
            return []
        }
    }
}
