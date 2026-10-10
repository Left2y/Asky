import Foundation

public struct KeywordCommand: Sendable, Codable, Hashable, Identifiable {
    public var id: String { keyword }
    public var keyword: String
    public var name: String
    /// URL template; `{query}` is replaced with the percent-encoded query.
    public var urlTemplate: String

    public init(keyword: String, name: String, urlTemplate: String) {
        self.keyword = keyword
        self.name = name
        self.urlTemplate = urlTemplate
    }

    public func url(for query: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#/")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        let s = urlTemplate.replacingOccurrences(of: "{query}", with: encoded)
        guard let url = URL(string: s), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return nil }
        return url
    }

    public static let builtIn: [KeywordCommand] = [
        KeywordCommand(keyword: "go", name: "Google 搜索", urlTemplate: "https://www.google.com/search?q={query}"),
    ]
}

/// In-memory keyword set with CRUD; persistence is owned by the caller (settings store).
public struct KeywordRegistry: Sendable, Codable, Equatable {
    public private(set) var commands: [KeywordCommand]

    public init(commands: [KeywordCommand] = KeywordCommand.builtIn) { self.commands = commands }

    public enum RegistryError: Error, Equatable { case invalidKeyword, invalidTemplate, duplicate }

    public mutating func upsert(_ cmd: KeywordCommand, replacing old: String? = nil) throws {
        let kw = cmd.keyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty, !kw.contains(" "), kw != ">" else { throw RegistryError.invalidKeyword }
        guard cmd.urlTemplate.contains("{query}"), cmd.url(for: "x") != nil else { throw RegistryError.invalidTemplate }
        if old != kw, commands.contains(where: { $0.keyword == kw }) { throw RegistryError.duplicate }
        commands.removeAll { $0.keyword == (old ?? kw) }
        commands.append(cmd)
    }

    public mutating func remove(_ keyword: String) { commands.removeAll { $0.keyword == keyword } }

    /// Matches "go SwiftUI" → (go, "SwiftUI").
    public func match(_ input: String) -> (KeywordCommand, String)? {
        guard let (cmd, text) = matchInput(input) else { return nil }
        let query = text.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? nil : (cmd, query)
    }

    /// A completed keyword followed by a space enters command input, even before a query is typed.
    public func matchInput(_ input: String) -> (KeywordCommand, String)? {
        let trimmed = String(input.drop(while: { $0.isWhitespace }))
        guard let space = trimmed.firstIndex(of: " ") else { return nil }
        let kw = String(trimmed[..<space])
        let q = String(trimmed[trimmed.index(after: space)...])
        guard let cmd = commands.first(where: { $0.keyword.caseInsensitiveCompare(kw) == .orderedSame }) else { return nil }
        return (cmd, q)
    }
}
