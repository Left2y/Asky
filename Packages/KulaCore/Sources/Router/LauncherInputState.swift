import DirectActions

/// The displayed query and the consumed command token have separate lifetimes.
public struct LauncherInputState: Equatable {
    /// Default scope keyword: `bm ` searches Chrome bookmarks only.
    public static let bookmarkKeyword = "bm"
    /// Default token that enters terminal mode; users may customise it.
    public static let defaultTerminalKeyword = ">"

    public private(set) var text = ""
    public private(set) var command: KeywordCommand?
    public private(set) var tabs = false
    public var tabToken = "st"
    public private(set) var bookmarks = false
    public private(set) var terminal = false
    public private(set) var links = false
    public private(set) var ai = false
    public var bookmarkToken = Self.bookmarkKeyword
    public var linkToken = "link"
    public var aiToken = "ai"
    public var terminalKeyword = Self.defaultTerminalKeyword

    public init() {}

    public var hasScope: Bool { command != nil || tabs || bookmarks || terminal || links || ai }

    public var rawQuery: String {
        if terminal { return terminalKeyword + " " + text }
        if tabs { return tabToken + " " + text }
        if bookmarks { return bookmarkToken + " " + text }
        if links { return linkToken + " " + text }
        if ai { return aiToken + " " + text }
        return command.map { $0.keyword + " " + text } ?? text
    }

    public mutating func edit(_ value: String, keywords: KeywordRegistry, bookmarksEnabled: Bool = true) {
        if !hasScope, let query = Self.matchTerminal(value, keyword: terminalKeyword) {
            terminal = true
            text = query
        } else if !hasScope, let query = Self.matchTerminal(value, keyword: tabToken) {
            tabs = true
            text = query
        } else if bookmarksEnabled, !hasScope, let query = Self.matchTerminal(value, keyword: bookmarkToken) {
            bookmarks = true
            text = query
        } else if !hasScope, let query = Self.matchTerminal(value, keyword: linkToken) {
            links = true
            text = query
        } else if !hasScope, let query = Self.matchTerminal(value, keyword: aiToken) {
            ai = true
            text = query
        } else if !hasScope, let (matched, query) = keywords.matchInput(value) {
            command = matched
            text = query
        } else {
            text = value
        }
    }

    public mutating func replaceRawQuery(_ value: String, keywords: KeywordRegistry, bookmarksEnabled: Bool = true) {
        leaveCommand()
        edit(value, keywords: keywords, bookmarksEnabled: bookmarksEnabled)
    }

    /// Enters bookmark search with `query` already typed.
    public mutating func enterBookmarks(_ query: String) {
        leaveCommand()
        bookmarks = true
        text = query
    }

    public mutating func enterTabs(_ query: String) {
        leaveCommand()
        tabs = true
        text = query
    }

    public mutating func leaveCommand() {
        tabs = false
        command = nil
        bookmarks = false
        terminal = false
        links = false
        ai = false
    }

    /// Native text editing calls this even when the field has no characters to delete.
    public mutating func backspaceOnEmptyText() -> Bool {
        guard text.isEmpty, hasScope else { return false }
        leaveCommand()
        return true
    }

    /// Like keyword commands, the terminal token is committed only by a following space.
    static func matchTerminal(_ input: String, keyword: String = defaultTerminalKeyword) -> String? {
        guard !keyword.isEmpty else { return nil }
        let trimmed = input.drop(while: { $0.isWhitespace })
        guard let space = trimmed.firstIndex(where: { $0.isWhitespace }),
              trimmed[..<space].caseInsensitiveCompare(keyword) == .orderedSame else { return nil }
        return String(trimmed[space...].drop(while: { $0.isWhitespace }))
    }

    /// A terminal keyword is a single non-empty token that does not collide with the bookmark scope.
    public static func isValidTerminalKeyword(_ keyword: String) -> Bool {
        !keyword.isEmpty && !keyword.contains(where: \.isWhitespace)
            && keyword.caseInsensitiveCompare(bookmarkKeyword) != .orderedSame
    }

}
