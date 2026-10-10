import Testing
import DirectActions
@testable import Router

@Suite struct LauncherInputStateTests {
    let keywords = KeywordRegistry()

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
}
