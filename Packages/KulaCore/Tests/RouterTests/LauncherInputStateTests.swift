import Testing
import DirectActions
@testable import Router

@Suite struct LauncherInputStateTests {
    let keywords = KeywordRegistry()

    @Test func terminalPrefixRequiresSpaceAndKeepsShellSyntax() {
        var state = LauncherInputState()
        state.edit(">", keywords: keywords)
        #expect(!state.hasScope && state.text == ">")
        state.edit("> ", keywords: keywords)
        #expect(state.terminal && state.hasScope && state.text.isEmpty)
        state.edit("echo 'go chat' > /tmp/output", keywords: keywords)
        #expect(state.rawQuery == "> echo 'go chat' > /tmp/output")
        #expect(IntentRouter().route(state.rawQuery) == .terminal(command: "echo 'go chat' > /tmp/output"))
        let ignored = state.backspaceOnEmptyText()
        #expect(!ignored)
        state.edit("", keywords: keywords)
        let handled = state.backspaceOnEmptyText()
        #expect(handled)
        #expect(!state.hasScope)
        state.edit("chat hello", keywords: keywords)
        #expect(state.command?.keyword == "chat")
    }

    @Test func customTerminalKeywordReplacesDefault() {
        var state = LauncherInputState()
        state.terminalKeyword = "sh"
        state.edit("> pwd", keywords: keywords)
        #expect(!state.terminal)
        state.replaceRawQuery("SH pwd", keywords: keywords)
        #expect(state.terminal && state.text == "pwd")
        #expect(state.rawQuery == "sh pwd")
        #expect(IntentRouter(terminalKeyword: "sh").route(state.rawQuery) == .terminal(command: "pwd"))
        #expect(!LauncherInputState.isValidTerminalKeyword("bm"))
        #expect(!LauncherInputState.isValidTerminalKeyword("a b"))
    }

    @Test func pastedTerminalCommandAndReplacementResetScope() {
        var state = LauncherInputState()
        state.replaceRawQuery("  >pwd", keywords: keywords)
        #expect(!state.hasScope && state.text == "  >pwd")
        state.replaceRawQuery("  > pwd", keywords: keywords)
        #expect(state.terminal && state.text == "pwd")
        state.replaceRawQuery("Safari", keywords: keywords)
        #expect(!state.hasScope && state.text == "Safari")
        state.edit("＞pwd", keywords: keywords)
        #expect(!state.hasScope)
    }

    @Test func terminalInputMethodSpaceConsumesToken() {
        var state = LauncherInputState()
        state.edit(">\u{3000}", keywords: keywords)
        #expect(state.terminal && state.text.isEmpty)
        state.edit("pwd", keywords: keywords)
        #expect(state.rawQuery == "> pwd")
    }

    @Test func firstSpaceConsumesKeywordAndNextCharacterIsQuery() {
        var state = LauncherInputState()
        state.edit("g", keywords: keywords)
        state.edit("go", keywords: keywords)
        #expect(state.command == nil)
        state.edit("go ", keywords: keywords)
        #expect(state.command?.keyword == "go")
        #expect(state.text == "")
        state.edit("Who ", keywords: keywords)
        state.edit("Who is fantuan?", keywords: keywords)
        #expect(state.text == "Who is fantuan?")
        #expect(state.rawQuery == "go Who is fantuan?")
    }

    @Test func inputMethodSpaceConsumesKeywordImmediately() {
        var state = LauncherInputState()
        state.edit("go\u{3000}", keywords: keywords)
        #expect(state.command?.keyword == "go")
        #expect(state.text.isEmpty)
        state.edit("kimi", keywords: keywords)
        #expect(state.rawQuery == "go kimi")
    }

    @Test func emptyBackspaceClearsCommandAndOrdinarySearchResumes() {
        var state = LauncherInputState()
        state.edit("go ", keywords: keywords)
        let handled = state.backspaceOnEmptyText()
        #expect(handled)
        #expect(state.command == nil)
        #expect(state.rawQuery == "")
        let ignored = state.backspaceOnEmptyText()
        #expect(!ignored)
        state.edit("Safari", keywords: keywords)
        #expect(state.command == nil)
        #expect(state.text == "Safari")
    }

    @Test func queryDeletionKeepsScopeUntilNextBackspace() {
        var state = LauncherInputState()
        state.edit("go cats", keywords: keywords)
        let ignored = state.backspaceOnEmptyText()
        #expect(!ignored)
        state.edit("", keywords: keywords)
        #expect(state.command?.keyword == "go")
        let handled = state.backspaceOnEmptyText()
        #expect(handled)
        #expect(state.rawQuery == "")
    }

    @Test func leavingCommandDoesNotConsumeQueryThatLooksLikeAnotherCommand() {
        var state = LauncherInputState()
        state.edit("go go query", keywords: keywords)
        state.leaveCommand()
        #expect(state.command == nil)
        #expect(state.text == "go query")
        state.replaceRawQuery("", keywords: keywords)
        #expect(state.command == nil)
        #expect(state.text == "")
    }

    @Test func bookmarkScopeIsEnteredByKeywordOrEntry() {
        var state = LauncherInputState()
        state.edit("bm kimi", keywords: keywords)
        #expect(state.bookmarks && state.command == nil)
        #expect(state.text == "kimi")
        #expect(state.rawQuery == "bm kimi")
        state.edit("", keywords: keywords)
        let left = state.backspaceOnEmptyText()
        #expect(left)
        #expect(!state.hasScope)
        state.edit("kimi", keywords: keywords)
        state.enterBookmarks("kimi")
        #expect(state.bookmarks && state.text == "kimi")
        state.replaceRawQuery("", keywords: keywords)
        #expect(!state.hasScope)
    }
    @Test func disabledBookmarksNeverConsumeTheScopeKeyword() {
        var state = LauncherInputState()
        let keywords = KeywordRegistry()
        state.edit("bm deepseek", keywords: keywords, bookmarksEnabled: false)
        #expect(!state.bookmarks && state.text == "bm deepseek")
        state.replaceRawQuery("bm deepseek", keywords: keywords, bookmarksEnabled: true)
        #expect(state.bookmarks && state.text == "deepseek")
        state.replaceRawQuery(state.rawQuery, keywords: keywords, bookmarksEnabled: false)
        #expect(!state.bookmarks && state.text == "bm deepseek")
    }

}
