import AppKit
import LocalStore

public struct CalculatorHistoryRecord: Codable, Sendable, Identifiable {
    public let id: String
    public let expression: String
    public let result: String
}

extension ToolService {
    private static let calculatorHistoryKey = "launcher.calculatorHistory"

    /// A bounded local history, newest first. Search preserves recency order.
    public static func calculatorHistory(in store: LocalStore, query: String = "") -> [CalculatorHistoryRecord] {
        let records = store.codableSetting(calculatorHistoryKey, as: [CalculatorHistoryRecord].self) ?? []
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return Array(records.prefix(200)).filter {
            text.isEmpty || $0.expression.localizedStandardContains(text) || $0.result.localizedStandardContains(text)
        }
    }

    public static func saveCalculatorHistory(expression: String, result: String, in store: LocalStore) {
        let expression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expression.isEmpty, !result.isEmpty else { return }
        var records = calculatorHistory(in: store)
        records.removeAll { $0.expression == expression && $0.result == result }
        records.insert(CalculatorHistoryRecord(id: UUID().uuidString, expression: expression, result: result), at: 0)
        store.setCodableSetting(calculatorHistoryKey, Array(records.prefix(200)))
    }

    public static func deleteCalculatorHistory(id: String, in store: LocalStore) {
        store.setCodableSetting(calculatorHistoryKey, calculatorHistory(in: store).filter { $0.id != id })
    }

    @MainActor
    public static func copyCalculatorResult(_ value: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(value, forType: .string)
    }
}
