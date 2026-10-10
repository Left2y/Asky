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
        for input in ["SwiftUI", "find example.com", "javascript:alert(1)", "file:///tmp/a", "https://", "https://user:password@example.com"] {
            #expect(await provider.search(input, limit: 8).isEmpty)
        }
        #expect(await provider.search("example.com", limit: 0).isEmpty)
    }
}
