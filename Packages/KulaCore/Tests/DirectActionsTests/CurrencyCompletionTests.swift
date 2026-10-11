import Foundation
import Testing
@testable import DirectActions

@Suite struct CurrencyCompletionTests {
    @Test(arguments: ["1美元", "1 美金", "1 usd", "1USD"])
    func singleCurrency(_ text: String) throws {
        let query = try #require(CurrencyQuery.parse(text))
        #expect(query.amount == 1 && query.from == "USD" && query.showsAllCurrencies)
        #expect(CurrencyPresentation.targetCodes(from: query.from).first == "CNY")
    }

    @Test func explicitPairAndYuan() throws {
        let pair = try #require(CurrencyQuery.parse("100美元换成人民币"))
        #expect(pair.to == "CNY" && !pair.showsAllCurrencies)
        let yuan = try #require(CurrencyQuery.parse("100人民币"))
        #expect(yuan.from == "CNY" && yuan.showsAllCurrencies)
        #expect(!CurrencyPresentation.targetCodes(from: "CNY").contains("CNY"))
        #expect(CurrencyPresentation.flag(for: "CNY") == "🇨🇳")
        #expect(CurrencyQuery.known.allSatisfy { CurrencyPresentation.flag(for: $0) != nil })
    }

    @Test(arguments: ["美元", "1美元abc", "1USD to", "1USD USD", "1foo", "1/0", "1e999 USD", "1美元 人民币 多余"])
    func incompleteQueriesStaySearch(_ text: String) {
        #expect(CurrencyQuery.parse(text) == nil)
    }

    @Test func batchOfflineSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = root.appendingPathComponent("rates.json")
        let snapshot = ExchangeRates(date: "2026-10-08", perEUR: ["USD": 1.1, "CNY": 7.7, "JPY": 165], fetchedAt: .distantPast)
        try JSONEncoder().encode(snapshot).write(to: cache)
        let service = ExchangeRateService(cacheURL: cache, fetcher: { _ in throw URLError(.notConnectedToInternet) })
        let results = await service.conversions(try #require(CurrencyQuery.parse("1美元")))
        #expect(results.count == 3)
        guard case .converted(let value, let rate, let date, let cached, let query) = results[0] else {
            Issue.record("Expected CNY first"); return
        }
        #expect(abs(value - 7) < 1e-9 && abs(rate - 7) < 1e-9)
        #expect(date == snapshot.date && cached && query.to == "CNY")
        let unavailable = await service.conversions(CurrencyQuery(amount: 1, from: "GBP", to: "CNY", showsAllCurrencies: true))
        #expect(unavailable.count == 1)
        guard case .unavailable = unavailable[0] else { Issue.record("Missing source must not fabricate values"); return }
    }
}
