import DirectActions

/// The displayed query and the consumed command token have separate lifetimes.
public struct LauncherInputState: Equatable {
    public private(set) var text = ""
    public private(set) var command: KeywordCommand?

    public init() {}

    public var rawQuery: String {
        command.map { $0.keyword + " " + text } ?? text
    }

    public mutating func edit(_ value: String, keywords: KeywordRegistry) {
        if command == nil, let (matched, query) = keywords.matchInput(value) {
            command = matched
            text = query
        } else {
            text = value
        }
    }

    public mutating func replaceRawQuery(_ value: String, keywords: KeywordRegistry) {
        command = nil
        edit(value, keywords: keywords)
    }

    public mutating func leaveCommand() {
        command = nil
    }

    /// Native text editing calls this even when the field has no characters to delete.
    public mutating func backspaceOnEmptyText() -> Bool {
        guard text.isEmpty, command != nil else { return false }
        leaveCommand()
        return true
    }
}
