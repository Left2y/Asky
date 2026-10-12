import Foundation
import Testing
import Contracts
import DirectActions
@testable import Router

@Suite struct RouterTests {
    let router = IntentRouter()

    @Test func emptyInput() {
        #expect(router.route("   ") == .empty)
        #expect(router.askAIResult(for: " ") == nil)
    }

    @Test func terminalOnlyWithExplicitPrefix() {
        #expect(router.route("> ls -la") == .terminal(command: "ls -la"))
        #expect(router.route("ls -la") == .search(query: "ls -la"))
        #expect(router.route(">") == .search(query: ">"))
        #expect(router.route(">pwd") == .search(query: ">pwd"))
        #expect(router.route("> ") == .search(query: ">"))
        #expect(router.route(">\u{3000}pwd") == .terminal(command: "pwd"))
    }

    @Test func calculationBeatsSearch() {
        #expect(router.route("1+2*3") == .calculation(expression: "1+2*3", value: 7))
        #expect(!router.includesSearch(router.route("1+2")))
    }

    @Test(arguments: ["(12-1)*3", "(12–1)*3", "(12−1)×3", "（１２－１）＊３"])
    func parenthesizedCalculationKeepsOriginalExpression(_ expression: String) throws {
        let route = router.route(expression)
        #expect(route == .calculation(expression: expression, value: 33))
        #expect(!router.includesSearch(route))
        let result = try #require(router.directResults(for: route).first)
        #expect(result.source == .calculator)
        #expect(result.subtitle == expression)
        #expect(result.primaryAction == .copy("33"))
    }

    @Test func conversionAndCurrency() {
        if case .conversion(let c) = router.route("10 km mi") {
            #expect(abs(c.value - 6.21371) < 0.001)
        } else { Issue.record("expected conversion") }
        if case .currency(let q) = router.route("100 usd to cny") {
            #expect(q.from == "USD" && q.to == "CNY" && q.amount == 100)
        } else { Issue.record("expected currency") }
    }

    @Test func keywordRoute() {
        guard case .keyword(let cmd, let q) = router.route("go swift testing") else {
            Issue.record("expected keyword"); return
        }
        #expect(cmd.keyword == "go" && q == "swift testing")
        let rows = router.directResults(for: .keyword(cmd, query: q))
        #expect(rows.first?.target.identifier.contains("swift%20testing") == true)
    }

    @Test(arguments: ["yt", "dy", "tb", "jd", "bl", "gh"])
    func builtInSiteSearchCarriesEncodedQuery(_ keyword: String) throws {
        let query = "中文 & + # / ?"
        var state = LauncherInputState()
        state.edit("\(keyword.uppercased()) ", keywords: KeywordRegistry())
        #expect(state.command?.keyword == keyword)
        #expect(state.text.isEmpty)
        state.edit(query, keywords: KeywordRegistry())
        guard case .keyword(let command, let routedQuery) = router.route(state.rawQuery) else {
            Issue.record("expected site search command"); return
        }
        #expect(routedQuery == query)
        let row = try #require(router.directResults(for: .keyword(command, query: routedQuery)).first)
        let url = try #require(URL(string: row.target.identifier))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let destinations: [String: (String, String)] = [
            "yt": ("www.youtube.com", "search_query"), "tb": ("s.taobao.com", "q"),
            "jd": ("search.jd.com", "keyword"), "bl": ("search.bilibili.com", "keyword"),
            "gh": ("github.com", "q"),
        ]
        if keyword == "dy" {
            #expect(url.host == "www.douyin.com")
            #expect(components.percentEncodedPath.removingPercentEncoding == "/search/" + query)
            #expect(components.percentEncodedPath.contains("%2F"))
            #expect(components.query == nil)
        } else {
            let destination = try #require(destinations[keyword])
            #expect(url.host == destination.0)
            #expect(components.queryItems == [URLQueryItem(name: destination.1, value: query)])
        }
        #expect(components.fragment == nil)
        #expect(row.actions == [.openURL(url)])
    }

    @Test func commandInputRequiresCompletedTokenAndPreservesEmptyScope() {
        let registry = KeywordRegistry()
        #expect(registry.matchInput("go") == nil)
        #expect(registry.matchInput("google query") == nil)
        #expect(registry.matchInput("GO ")?.0.keyword == "go")
        #expect(registry.matchInput("go ")?.1 == "")
        #expect(registry.match("go ") == nil)
        #expect(registry.matchInput("go Who ")?.1 == "Who ")
        #expect(registry.match("go Who ")?.1 == "Who")
        #expect(registry.matchInput(" go Who is fantuan?")?.1 == "Who is fantuan?")
        let custom = KeywordRegistry(commands: [KeywordCommand(keyword: "saf", name: "Safari", urlTemplate: "https://www.google.com/search?q={query}")])
        #expect(custom.matchInput("saf Who is fantuan?")?.0.name == "Safari")
        #expect(custom.matchInput("saf Who is fantuan?")?.1 == "Who is fantuan?")
    }

    @Test func plainTextIsSearchWithAskAIAction() {
        #expect(router.route("Safari") == .search(query: "Safari"))
        let ai = router.askAIResult(for: "Safari")
        #expect(ai?.source == .askAI)
        #expect(ai?.actions == [.askAI(prompt: "Safari")])
        #expect(ai?.subtitle == "")
    }

    @Test(arguments: ["帮我梳理一下日程", "帮我安排明天下午的工作", "请问明天有什么安排", "怎么安排今天的工作", "今天有会议吗？", "help me plan my day", "How can I organize my calendar?"])
    func conversationalRequestsPrepareAIAction(_ prompt: String) {
        let route = router.route(prompt)
        #expect(route == .conversation(prompt: prompt))
        #expect(!router.includesSearch(route))
        let rows = router.directResults(for: route)
        #expect(rows.count == 1)
        #expect(rows.first?.source == .askAI)
        #expect(rows.first?.primaryAction == .askAI(prompt: prompt))
    }

    @Test(arguments: ["日程", "日程安排.pdf", "Calendar", "kimi", "Safari", "https://example.com/help", "ls -la"])
    func namesAndFragmentsStayLocal(_ query: String) {
        #expect(router.route(query) == .search(query: query))
    }

    @Test func explicitCommandsTakePriorityOverConversation() {
        guard case .keyword(_, let query) = router.route("go 帮我梳理一下日程") else {
            Issue.record("explicit keyword must win"); return
        }
        #expect(query == "帮我梳理一下日程")
        #expect(router.route("> explain command") == .terminal(command: "explain command"))
        let custom = IntentRouter(keywords: KeywordRegistry(commands: [
            KeywordCommand(keyword: "please", name: "Search", urlTemplate: "https://example.com/?q={query}")
        ]))
        guard case .keyword = custom.route("please help me plan") else {
            Issue.record("custom keyword must win"); return
        }
    }
}
