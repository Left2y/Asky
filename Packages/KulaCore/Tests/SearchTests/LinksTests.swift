import Testing
import Foundation
import Contracts
import Search

struct LinksTests {
    @Test func recognizesWebAddressesOnly() async {
        let provider = LinksProvider()
        for input in ["example.com/docs?q=swift", "https://example.com/中文", "http://localhost:8080"] {
            let results = await provider.search(input, limit: 8)
            #expect(results.count == 1)
            #expect(results.first?.source == .link)
            #expect(results.first?.primaryAction == LauncherWebURL.parse(input).map { .openURL($0) })
        }
        for input in ["find example.com", "javascript:alert(1)", "file:///tmp/a", "https://", "https://user:password@example.com",
                      "中文", "a", "123", "-kimi", "foo_bar"] {
            #expect(await provider.search(input, limit: 8).isEmpty)
        }
        #expect(await provider.search("example.com", limit: 0).isEmpty)
    }

    @Test func bareWordCompletesOnlyKnownSites() async {
        let sites = ["https://www.happyoyster.com/world?x=1", "https://happy.example.org/a", "https://kimi.moonshot.cn/chat",
                     "https://www.kimi.com/"].compactMap(URL.init(string:))
        let provider = LinksProvider(knownSites: { sites })
        #expect(await provider.search(" Happy ", limit: 8).first?.primaryAction == .openURL(URL(string: "https://www.happyoyster.com")!))
        #expect(await provider.search("kimi", limit: 8).first?.primaryAction == .openURL(URL(string: "https://www.kimi.com")!))
        for input in ["kidfasl", "oyster", "foo_bar"] {
            #expect(await provider.search(input, limit: 8).isEmpty)
        }
        #expect(await LinksProvider().search("kimi", limit: 8).isEmpty)
    }
}
