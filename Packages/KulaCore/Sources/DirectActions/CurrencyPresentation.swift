import Foundation

/// Currency order and regional flags shared by the launcher and its tests.
public enum CurrencyPresentation {
    private static let regions: [String: String] = [
        "CNY": "CN", "USD": "US", "EUR": "EU", "JPY": "JP", "GBP": "GB",
        "HKD": "HK", "KRW": "KR", "SGD": "SG", "AUD": "AU", "CAD": "CA",
        "CHF": "CH", "NZD": "NZ", "THB": "TH", "INR": "IN", "MYR": "MY",
        "CZK": "CZ", "DKK": "DK", "HUF": "HU", "PLN": "PL", "RON": "RO",
        "SEK": "SE", "ISK": "IS", "NOK": "NO", "TRY": "TR", "BRL": "BR",
        "IDR": "ID", "ILS": "IL", "MXN": "MX", "PHP": "PH", "ZAR": "ZA",
    ]

    public static func targetCodes(from: String) -> [String] {
        let preferred = ["CNY", "USD", "EUR", "JPY", "GBP", "HKD", "KRW", "SGD", "AUD", "CAD", "CHF", "NZD"]
        return (preferred + CurrencyQuery.known.subtracting(preferred).sorted()).filter { $0 != from }
    }

    public static func flag(for code: String) -> String? {
        guard let region = regions[code] else { return nil }
        return String(String.UnicodeScalarView(region.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }))
    }

    public static func name(for code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }
}
