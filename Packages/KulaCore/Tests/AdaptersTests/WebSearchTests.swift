import Foundation
import Testing
import Contracts
import LocalStore
import ToolService
@testable import Adapters

@Suite struct WebSearchTests {
    let url = URL(string: "https://www.bing.com/search?q=swift")!

    @Test func parsesSourcesAndRejectsUnsafeLinks() throws {
        let encoded = Data("https://swift.org/?a=1&b=2".utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let html = """
        <li class="b_algo"><h2><a href="https://www.bing.com/ck/a?u=a1\(encoded)&amp;ntb=1">Swift &amp; &#x4E2D;&#25991;</a></h2><p>Learn <strong>Swift</strong>.</p></li>
        <li class="b_algo"><h2><a href="javascript:alert(1)">Unsafe</a></h2></li>
        <li class="b_algo"><h2><a href="https://swift.org/?a=1&amp;b=2">Duplicate</a></h2></li>
        <li class="b_algo"><h2><a href="https://developer.apple.com/swift/">Apple</a></h2></li>
        """
        let output = try WebSearchTool.output(html: html, query: "swift", searchURL: url, count: 5)
        #expect(output["results"]?.arrayValue?.count == 2)
        #expect(output["results"]?.arrayValue?.first?["title"]?.stringValue == "Swift & 中文")
        #expect(output["results"]?.arrayValue?.first?["url"]?.stringValue == "https://swift.org/?a=1&b=2")
        #expect(try WebSearchTool.output(html: html, query: "swift", searchURL: url, count: 1)["results"]?.arrayValue?.count == 1)
        #expect(WebSearchTool.sourceURL("file:///etc/passwd") == nil)
        #expect(WebSearchTool.sourceURL("https://user:pass@example.com") == nil)
    }

    @Test func challengesAndChangedMarkupAreFailures() throws {
        for html in ["<html>unexpected layout</html>", "<div id='b_captcha'>verify</div>"] {
            #expect(throws: ToolError.self) { try WebSearchTool.output(html: html, query: "swift", searchURL: url, count: 5) }
        }
        #expect(try WebSearchTool.output(html: "<li class='b_no'>No results</li>", query: "swift", searchURL: url, count: 5)["results"]?.arrayValue?.isEmpty == true)
    }

    @Test func validatesBeforeNetwork() async {
        for args: JSONValue in [["query": " "], ["query": .string(String(repeating: "a", count: 501))],
                                ["query": "swift", "count": 1.5], ["query": "swift", "count": 11]] {
            do { _ = try await WebSearchTool().execute(args); Issue.record("Invalid arguments accepted") }
            catch let error as ToolError { #expect(error.code == .invalidArguments) }
            catch { Issue.record("Unexpected error: \(error)") }
        }
    }

    @Test func sourcePolicyAndMCPExposure() async throws {
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let disabled = ToolService(store: store, policy: { PolicySnapshot(enabledSources: []) }, presenter: { _ in .rejected })
        await disabled.register(WebSearchTool())
        #expect(await disabled.definitions(for: .agent(sessionID: "s")).isEmpty)
        #expect(await disabled.submit(ActionRequest(tool: "web_search", arguments: ["query": "swift"], origin: .agent(sessionID: "s"), intent: .explicitRequest)).error?.code == .sourceDisabled)
        let enabled = ToolService(store: store, policy: { PolicySnapshot(enabledSources: [.web]) }, presenter: { _ in .rejected })
        await enabled.register(WebSearchTool())
        #expect(await enabled.definitions(for: .agent(sessionID: "s")).contains { $0.name == "web_search" })
        #expect(await enabled.definitions(for: .mcp(instanceID: "s")).isEmpty)
    }

    @Test func liveSearchThroughToolService() async throws {
        guard ProcessInfo.processInfo.environment["ASKY_LIVE_WEB_SEARCH"] == "1" else { return }
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let service = ToolService(store: store, policy: { PolicySnapshot(enabledSources: [.web]) }, presenter: { _ in .rejected })
        await service.register(WebSearchTool())
        let result = await service.submit(ActionRequest(tool: "web_search", arguments: ["query": "Swift Apple documentation", "count": 5], origin: .agent(sessionID: "live"), intent: .explicitRequest))
        #expect(result.status == .completed, "\(String(describing: result.error))")
        #expect(result.output?["results"]?.arrayValue?.isEmpty == false)
        print("Live web search: \(String(describing: result.output))")
    }
}
