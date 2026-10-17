import Foundation

public struct KeywordCommand: Sendable, Codable, Hashable, Identifiable {
    public var id: String { keyword }
    public var keyword: String
    public var name: String
    /// Website address. The persisted key also supports legacy `{query}` search templates.
    public var urlTemplate: String

    public init(keyword: String, name: String, urlTemplate: String) {
        self.keyword = keyword
        self.name = name
        self.urlTemplate = urlTemplate
    }

    public var supportsQuery: Bool {
        if urlTemplate.contains("{query}") { return true }
        guard let url = url(for: "") else { return false }
        return url.host?.lowercased() == "chatgpt.com" && ["", "/"].contains(url.path)
    }

    public func url(for query: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#/")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        let address = urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty, !address.contains(where: { $0.isWhitespace }) else { return nil }
        let normalized = address.contains(":") ? address : "https://" + address
        let s = normalized.replacingOccurrences(of: "{query}", with: encoded)
        guard let url = URL(string: s), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        if !query.isEmpty, !address.contains("{query}"), url.host?.lowercased() == "chatgpt.com",
           ["", "/"].contains(url.path), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            var items = components.queryItems ?? []
            items.removeAll { $0.name == "q" }
            items.append(URLQueryItem(name: "q", value: query))
            components.queryItems = items
            // A literal plus must not be interpreted as a space by query parsers.
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
            return components.url
        }
        return url
    }

    public static let websitePresets: [KeywordCommand] = [
        KeywordCommand(keyword: "chat", name: "ChatGPT", urlTemplate: "https://chatgpt.com"),
        KeywordCommand(keyword: "ds", name: "DeepSeek", urlTemplate: "https://chat.deepseek.com/?q={query}"),
    ]

    public static let builtIn: [KeywordCommand] = [
        KeywordCommand(keyword: "go", name: "Google 搜索", urlTemplate: "https://www.google.com/search?q={query}"),
    ] + websitePresets + [
        KeywordCommand(keyword: "yt", name: "YouTube 搜索", urlTemplate: "https://www.youtube.com/results?search_query={query}"),
        KeywordCommand(keyword: "dy", name: "抖音搜索", urlTemplate: "https://www.douyin.com/search/{query}"),
        KeywordCommand(keyword: "tb", name: "淘宝搜索", urlTemplate: "https://s.taobao.com/search?q={query}"),
        KeywordCommand(keyword: "jd", name: "京东搜索", urlTemplate: "https://search.jd.com/Search?keyword={query}"),
        KeywordCommand(keyword: "bl", name: "bilibili 搜索", urlTemplate: "https://search.bilibili.com/all?keyword={query}"),
        KeywordCommand(keyword: "gh", name: "GitHub 搜索", urlTemplate: "https://github.com/search?q={query}"),
        KeywordCommand(keyword: "bd", name: "百度搜索", urlTemplate: "https://www.baidu.com/s?wd={query}"),
        KeywordCommand(keyword: "hb", name: "花瓣搜索", urlTemplate: "https://huaban.com/search/?q={query}"),
        KeywordCommand(keyword: "zh", name: "知乎搜索", urlTemplate: "https://www.zhihu.com/search?type=content&q={query}"),
        KeywordCommand(keyword: "xhs", name: "小红书搜索", urlTemplate: "https://www.xiaohongshu.com/search_result?keyword={query}"),
        KeywordCommand(keyword: "wb", name: "微博搜索", urlTemplate: "https://s.weibo.com/weibo?q={query}"),
    ]
}

/// In-memory keyword set with CRUD; persistence is owned by the caller (settings store).
public struct KeywordRegistry: Sendable, Codable, Equatable {
    public private(set) var commands: [KeywordCommand]

    public init(commands: [KeywordCommand] = KeywordCommand.builtIn) { self.commands = commands }

    public enum RegistryError: Error, Equatable { case invalidKeyword, invalidTemplate, duplicate }

    public mutating func upsert(_ cmd: KeywordCommand, replacing old: String? = nil) throws {
        let kw = cmd.keyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty, !kw.contains(" "), kw != ">", kw.lowercased() != "bm" else { throw RegistryError.invalidKeyword }
        guard cmd.url(for: "x") != nil else { throw RegistryError.invalidTemplate }
        if old != kw, commands.contains(where: { $0.keyword == kw }) { throw RegistryError.duplicate }
        commands.removeAll { $0.keyword == (old ?? kw) }
        var saved = cmd
        saved.keyword = kw
        saved.urlTemplate = cmd.urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        commands.append(saved)
    }

    /// One-time settings upgrade; preserve existing keywords and app/shortcut aliases.
    public mutating func addMissingWebsitePresets(excluding aliases: Set<String> = []) {
        let occupied = Set(commands.map { $0.keyword.lowercased() }).union(aliases.map { $0.lowercased() })
        commands.append(contentsOf: KeywordCommand.websitePresets.filter { !occupied.contains($0.keyword.lowercased()) })
    }

    /// Remove retired defaults and shorten the original ChatGPT keyword without overwriting custom entries.
    public mutating func migrateQueryPresets(excluding aliases: Set<String> = []) {
        let retired = [
            KeywordCommand(keyword: "gemini", name: "Gemini", urlTemplate: "https://gemini.google.com"),
            KeywordCommand(keyword: "doubao", name: "豆包", urlTemplate: "https://www.doubao.com/chat/"),
        ]
        commands.removeAll { retired.contains($0) }
        let old = KeywordCommand(keyword: "chatgpt", name: "ChatGPT", urlTemplate: "https://chatgpt.com")
        if commands.contains(old) {
            let occupied = commands.contains { $0.keyword.caseInsensitiveCompare("chat") == .orderedSame }
                || aliases.contains { $0.caseInsensitiveCompare("chat") == .orderedSame }
            if !occupied {
                commands.removeAll { $0 == old }
                commands.append(KeywordCommand.websitePresets[0])
            }
        }
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
        guard let space = trimmed.firstIndex(where: { $0.isWhitespace }) else { return nil }
        let kw = String(trimmed[..<space])
        let q = String(trimmed[trimmed.index(after: space)...])
        guard let cmd = commands.first(where: { $0.keyword.caseInsensitiveCompare(kw) == .orderedSame }) else { return nil }
        return (cmd, q)
    }
}
