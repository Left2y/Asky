import DirectActions

/// The displayed query and the consumed command token have separate lifetimes.
public struct LauncherInputState: Equatable {
    /// Built-in scope keyword: `bm ` searches Chrome bookmarks only.
    public static let bookmarkKeyword = "bm"

    public private(set) var text = ""
    public private(set) var command: KeywordCommand?
    public private(set) var bookmarks = false

    public init() {}

    public var hasScope: Bool { command != nil || bookmarks }

    public var rawQuery: String {
        if bookmarks { return Self.bookmarkKeyword + " " + text }
        return command.map { $0.keyword + " " + text } ?? text
    }

    public mutating func edit(_ value: String, keywords: KeywordRegistry) {
        if !hasScope, let query = Self.matchBookmarks(value) {
            bookmarks = true
            text = query
        } else if !hasScope, let (matched, query) = keywords.matchInput(value) {
            command = matched
            text = query
        } else {
            text = value
        }
    }

    public mutating func replaceRawQuery(_ value: String, keywords: KeywordRegistry) {
        leaveCommand()
        edit(value, keywords: keywords)
    }

    /// Enters bookmark search with `query` already typed.
    public mutating func enterBookmarks(_ query: String) {
        command = nil
        bookmarks = true
        text = query
    }

    public mutating func leaveCommand() {
        command = nil
        bookmarks = false
    }

    /// Native text editing calls this even when the field has no characters to delete.
    public mutating func backspaceOnEmptyText() -> Bool {
        guard text.isEmpty, hasScope else { return false }
        leaveCommand()
        return true
    }

    private static func matchBookmarks(_ input: String) -> String? {
        let trimmed = input.drop(while: { $0.isWhitespace })
        guard let space = trimmed.firstIndex(where: { $0.isWhitespace }),
              trimmed[..<space].caseInsensitiveCompare(bookmarkKeyword) == .orderedSame else { return nil }
        return String(trimmed[trimmed.index(after: space)...])
    }
}
