import Foundation

public struct KeywordCommand: Sendable, Hashable, Identifiable {
    public var id: String { keyword }
    public let keyword: String
    public let name: String
    /// Built-in website address or search template.
    public let urlTemplate: String

    fileprivate init(keyword: String, name: String, urlTemplate: String) {
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

/// Active built-in website commands with configurable trigger tokens.
public struct KeywordRegistry: Sendable, Equatable {
    public let commands: [KeywordCommand]

    public init(disabledCommands: Set<String> = [], triggerKeywords: [String: String] = [:]) {
        commands = KeywordCommand.builtIn.filter {
            !disabledCommands.contains($0.keyword)
        }.map { preset in
            KeywordCommand(keyword: triggerKeywords[preset.keyword] ?? preset.keyword,
                           name: preset.name, urlTemplate: preset.urlTemplate)
        }
    }

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
