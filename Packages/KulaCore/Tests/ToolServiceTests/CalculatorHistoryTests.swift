import Testing
import Foundation
import LocalStore
@testable import ToolService

struct CalculatorHistoryTests {
    @Test func persistsSearchesDeduplicatesAndDeletes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LocalStore(root: root)
        ToolService.saveCalculatorHistory(expression: "2 + 3", result: "5", in: store)
        ToolService.saveCalculatorHistory(expression: "6 * 7", result: "42", in: store)
        ToolService.saveCalculatorHistory(expression: "2 + 3", result: "5", in: store)
        let reopened = try LocalStore(root: root)
        let records = ToolService.calculatorHistory(in: reopened)
        #expect(records.map(\.result) == ["5", "42"])
        #expect(ToolService.calculatorHistory(in: reopened, query: "6 *").count == 1)
        #expect(ToolService.calculatorHistory(in: reopened, query: "42").count == 1)
        ToolService.deleteCalculatorHistory(id: records[0].id, in: reopened)
        #expect(ToolService.calculatorHistory(in: store).map(\.result) == ["42"])
    }

    @Test func retainsOnlyNewest200() throws {
        let store = try LocalStore(inMemoryWithRoot: URL(filePath: "/tmp/calculator-history-tests"))
        for index in 0..<205 {
            ToolService.saveCalculatorHistory(expression: "\(index) + 1", result: "\(index + 1)", in: store)
        }
        let records = ToolService.calculatorHistory(in: store)
        #expect(records.count == 200)
        #expect(records.first?.result == "205")
        #expect(records.last?.result == "6")
    }
}
