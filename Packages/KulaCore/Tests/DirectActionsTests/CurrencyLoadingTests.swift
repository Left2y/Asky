import Foundation
import Testing
@testable import DirectActions

@Suite struct CurrencyLoadingTests {
    private static let xml = Data("<Cube><Cube time=\"2026-10-12\"><Cube currency=\"USD\" rate=\"1.1\"/><Cube currency=\"CNY\" rate=\"7.7\"/></Cube></Cube>".utf8)

    @Test func staleCacheReturnsWhileRefreshIsBlocked() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("rates.json")
        let old = ExchangeRates(date: "2026-10-08", perEUR: ["USD": 1, "CNY": 6], fetchedAt: .distantPast)
        try JSONEncoder().encode(old).write(to: url)
        let gate = RateFetchGate()
        let service = ExchangeRateService(cacheURL: url, fetcher: { _ in await gate.fetch() })
        let result = await service.convert(CurrencyQuery(amount: 1, from: "USD", to: "CNY"))
        guard case .converted(let value, _, let date, let cached, _) = result else {
            Issue.record("Expected immediate cached conversion"); return
        }
        #expect(value == 6 && date == old.date && cached)
        await gate.waitUntilStarted()
        // Launch prefetch joins the refresh already triggered by the stale conversion.
        let warmup = Task { await service.prefetch() }
        await gate.finish(Self.xml)
        await warmup.value
        #expect(await gate.count == 1)
        #expect(await service.cachedRates()?.date == "2026-10-12")
    }

    @Test func coldPrefetchPersistsRatesForNextLaunch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("rates.json")
        let gate = RateFetchGate()
        let service = ExchangeRateService(cacheURL: url, fetcher: { _ in await gate.fetch() })
        let warmup = Task { await service.prefetch() }
        await gate.waitUntilStarted()
        let conversion = Task { await service.convert(CurrencyQuery(amount: 1, from: "USD", to: "CNY")) }
        await gate.finish(Self.xml)
        await warmup.value
        guard case .converted(let value, _, _, _, _) = await conversion.value else {
            Issue.record("Expected prefetched rates"); return
        }
        #expect(abs(value - 7) < 1e-9)
        #expect(await gate.count == 1)
        let offline = ExchangeRateService(cacheURL: url, fetcher: { _ in throw URLError(.notConnectedToInternet) })
        #expect(await offline.rates(allowNetwork: false)?.0.date == "2026-10-12")
    }
}

private actor RateFetchGate {
    private var continuation: CheckedContinuation<Data, Never>?
    private var started: [CheckedContinuation<Void, Never>] = []
    private(set) var count = 0

    func fetch() async -> Data {
        count += 1
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            started.forEach { $0.resume() }
            started.removeAll()
        }
    }

    func waitUntilStarted() async {
        if count > 0 { return }
        await withCheckedContinuation { started.append($0) }
    }

    func finish(_ data: Data) {
        continuation?.resume(returning: data)
        continuation = nil
    }
}
