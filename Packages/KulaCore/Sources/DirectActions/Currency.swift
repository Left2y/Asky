import Foundation

/// ECB daily reference rates, EUR-based. Daily reference conversion, not trading quotes.
public struct ExchangeRates: Sendable, Codable, Equatable {
    public var date: String // yyyy-MM-dd as published by ECB
    public var perEUR: [String: Double]
    public var fetchedAt: Date

    public init(date: String, perEUR: [String: Double], fetchedAt: Date) {
        self.date = date
        var r = perEUR
        r["EUR"] = 1
        self.perEUR = r
        self.fetchedAt = fetchedAt
    }

    public func convert(_ amount: Double, from: String, to: String) -> (value: Double, rate: Double)? {
        func rate(_ c: String) -> Double? { c.uppercased() == "EUR" ? 1 : perEUR[c.uppercased()] }
        guard let f = rate(from), let t = rate(to), f > 0 else { return nil }
        let rate = t / f
        return (amount * rate, rate)
    }

    /// Parses https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml
    public static func parseECB(_ data: Data, fetchedAt: Date = Date()) -> ExchangeRates? {
        let delegate = ECBParser()
        let p = XMLParser(data: data)
        p.delegate = delegate
        guard p.parse(), let date = delegate.date, !delegate.rates.isEmpty else { return nil }
        return ExchangeRates(date: date, perEUR: delegate.rates, fetchedAt: fetchedAt)
    }

    private final class ECBParser: NSObject, XMLParserDelegate {
        var date: String?
        var rates: [String: Double] = [:]
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes: [String: String] = [:]) {
            guard elementName == "Cube" else { return }
            if let t = attributes["time"] { date = t }
            if let c = attributes["currency"], let r = attributes["rate"], let v = Double(r) { rates[c] = v }
        }
    }
}

public struct CurrencyQuery: Sendable, Equatable {
    public var amount: Double
    public var from: String
    public var to: String
    public var showsAllCurrencies: Bool = false

    public init(amount: Double, from: String, to: String, showsAllCurrencies: Bool = false) {
        self.amount = amount
        self.from = from
        self.to = to
        self.showsAllCurrencies = showsAllCurrencies
    }

    static let aliases: [String: String] = [
        "人民币": "CNY", "rmb": "CNY", "元": "CNY", "美元": "USD", "美金": "USD", "欧元": "EUR",
        "澳元": "AUD", "加元": "CAD", "新加坡元": "SGD", "新币": "SGD", "瑞士法郎": "CHF", "新西兰元": "NZD", "泰铢": "THB", "印度卢比": "INR", "日元": "JPY", "英镑": "GBP", "港币": "HKD", "港元": "HKD", "韩元": "KRW", "$": "USD", "¥": "CNY", "€": "EUR", "£": "GBP",
    ]

    static let known: Set<String> = [
        "EUR", "USD", "JPY", "CZK", "DKK", "GBP", "HUF", "PLN", "RON", "SEK", "CHF", "ISK", "NOK", "TRY", "AUD",
        "BRL", "CAD", "CNY", "HKD", "IDR", "ILS", "INR", "KRW", "MXN", "MYR", "NZD", "PHP", "SGD", "THB", "ZAR",
    ]

    static func code(_ token: String) -> String? {
        if let a = aliases[token.lowercased()] ?? aliases[token] { return a }
        let u = token.uppercased()
        return known.contains(u) ? u : nil
    }

    /// "100 USD CNY", "100 usd to cny", "100美元 人民币".
    public static func parse(_ input: String) -> CurrencyQuery? {
        if let (amount, a, b) = QuantityParser.parse(input), amount.isFinite,
           let f = code(a), let t = code(b), f != t {
            return CurrencyQuery(amount: amount, from: f, to: t)
        }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Full-string match keeps partial pairs and ordinary searches out of currency mode.
        let pattern = #"^([+-]?(?:[0-9]+(?:,[0-9]{3})*)(?:\.[0-9]+)?|[+-]?\.[0-9]+)\s*([^\s0-9]+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numberRange = Range(match.range(at: 1), in: text),
              let currencyRange = Range(match.range(at: 2), in: text),
              let amount = Double(text[numberRange].replacingOccurrences(of: ",", with: "")), amount.isFinite,
              let from = code(String(text[currencyRange])) else { return nil }
        return CurrencyQuery(amount: amount, from: from, to: from == "CNY" ? "USD" : "CNY", showsAllCurrencies: true)
    }
}

public enum CurrencyResult: Sendable, Equatable {
    case converted(value: Double, rate: Double, rateDate: String, fromCache: Bool, query: CurrencyQuery)
    case unavailable(reason: String)
}

/// Fetches ECB rates with an on-disk cache. Network failure falls back to the dated cache;
/// with no cache it reports unavailable rather than inventing a rate.
public actor ExchangeRateService {
    public static let ecbURL = URL(string: "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")!
    private let cacheURL: URL
    private let fetcher: @Sendable (URL) async throws -> Data
    private var cached: ExchangeRates?
    private var refreshTask: Task<ExchangeRates?, Never>?
    private let maxAge: TimeInterval

    public init(cacheURL: URL, maxAge: TimeInterval = 6 * 3600,
                fetcher: @escaping @Sendable (URL) async throws -> Data = { url in
                    var req = URLRequest(url: url)
                    req.timeoutInterval = 5
                    let (data, _) = try await URLSession.shared.data(for: req)
                    return data
                }) {
        self.cacheURL = cacheURL
        self.fetcher = fetcher
        self.maxAge = maxAge
    }

    public func cachedRates() -> ExchangeRates? {
        if let cached { return cached }
        if let d = try? Data(contentsOf: cacheURL), let r = try? JSONDecoder().decode(ExchangeRates.self, from: d) {
            cached = r
        }
        return cached
    }

    /// Preload once at launch without holding up app startup.
    public func prefetch() async {
        if let existing = cachedRates(), Date().timeIntervalSince(existing.fetchedAt) < maxAge { return }
        _ = await refresh().value
    }

    /// All callers share the same refresh, including typing while launch prefetch is in flight.
    private func refresh() -> Task<ExchangeRates?, Never> {
        if let refreshTask { return refreshTask }
        let fetcher = fetcher
        let task = Task { () -> ExchangeRates? in
            let fresh: ExchangeRates?
            if let data = try? await fetcher(Self.ecbURL) {
                fresh = ExchangeRates.parseECB(data)
            } else {
                fresh = nil
            }
            if let fresh {
                cached = fresh
                try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? JSONEncoder().encode(fresh).write(to: cacheURL, options: .atomic)
            }
            refreshTask = nil
            return fresh
        }
        refreshTask = task
        return task
    }

    public func rates(allowNetwork: Bool = true) async -> (ExchangeRates, fromCache: Bool)? {
        if let existing = cachedRates() {
            if allowNetwork, Date().timeIntervalSince(existing.fetchedAt) >= maxAge {
                _ = refresh()
            }
            return (existing, true)
        }
        guard allowNetwork, let fresh = await refresh().value else { return nil }
        return (fresh, false)
    }

    public func conversions(_ q: CurrencyQuery, allowNetwork: Bool = true) async -> [CurrencyResult] {
        guard let (snapshot, fromCache) = await rates(allowNetwork: allowNetwork) else {
            return [.unavailable(reason: "无可用汇率缓存，且无法连接 ECB")]
        }
        let targets = q.showsAllCurrencies ? CurrencyPresentation.targetCodes(from: q.from) : [q.to]
        let results: [CurrencyResult] = targets.compactMap { target in
            guard let (value, rate) = snapshot.convert(q.amount, from: q.from, to: target),
                  value.isFinite, rate.isFinite else { return nil }
            let query = CurrencyQuery(amount: q.amount, from: q.from, to: target)
            return .converted(value: value, rate: rate, rateDate: snapshot.date, fromCache: fromCache, query: query)
        }
        return results.isEmpty ? [.unavailable(reason: "ECB 参考汇率不含该币种")] : results
    }

    public func convert(_ q: CurrencyQuery, allowNetwork: Bool = true) async -> CurrencyResult {
        guard let (rates, fromCache) = await rates(allowNetwork: allowNetwork) else {
            return .unavailable(reason: "无可用汇率缓存，且无法连接 ECB")
        }
        guard let (v, r) = rates.convert(q.amount, from: q.from, to: q.to) else {
            return .unavailable(reason: "ECB 参考汇率不含 \(q.from) 或 \(q.to)")
        }
        return .converted(value: v, rate: r, rateDate: rates.date, fromCache: fromCache, query: q)
    }
}
