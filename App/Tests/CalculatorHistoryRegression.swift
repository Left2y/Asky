import AppKit
import Contracts
import ToolService

@main @MainActor
private enum CalculatorHistoryRegression {
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "CalculatorHistory", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                    NSApp.appearance = NSAppearance(named: appearance)
                    try await check(appearance)
                }
                print("Calculator history regression passed in light and dark appearances")
                exit(0)
            } catch {
                fputs("Calculator history regression failed: \(error)\n", stderr)
                exit(1)
            }
        }
        NSApp.run()
    }

    static func check(_ appearance: NSAppearance.Name) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "Asky-calculator-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let model = LauncherModel(app: app, searchProviders: [])
        model.query = "128 * 0.85"
        try require(ToolService.calculatorHistory(in: app.store).isEmpty, "typing must not save intermediate expressions")
        model.submit(.executeSelection)
        try require(ToolService.calculatorHistory(in: app.store).first?.result == "108.8", "confirming copy must save the calculation")
        model.query = "2 + 3"
        model.submit(.executeSelection)
        model.query = "calc"
        try require(model.results.first?.target.identifier == "calculatorHistory", "calc must expose entry")
        model.submit(.executeSelection)
        try require(model.filter == .calculatorHistory && model.results.count == 2, "entry must show recent history")
        try require(model.results.first?.title == "2 + 3 = 5", "history must show expression and result newest first")
        try require(model.secondaryActions.count == 2 && model.secondaryActions.last?.isNegative == true, "delete must use negative action styling")
        model.submit(.executeSelection)
        try require(NSPasteboard.general.string(forType: .string) == "5", "primary action must copy result")
        try require(ToolService.calculatorHistory(in: app.store).count == 2, "copying history must not add records")
        model.performLauncherAction(model.secondaryActions[0])
        try require(model.filter == .all && model.inputText == "5", "continue must return result to root input")
        model.inputText += " * 2"
        try require(model.calculation?.result == "10", "continued value must support arithmetic")
        model.query = "calc "
        model.inputText = "108.8"
        try require(model.results.count == 1, "history must be searchable")
        model.inputText = ""
        let controller = LauncherController(model: model)
        controller.show()
        defer { controller.hide() }
        guard let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }) as? LauncherPanel else {
            throw NSError(domain: "CalculatorHistory", code: 2)
        }
        panel.onBlur = {}
        try await Task.sleep(for: .milliseconds(300))
        _ = model.toggleActionsMenu()
        try await Task.sleep(for: .milliseconds(300))
        let capture = Process()
        capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-l", String(panel.windowNumber), "build/calculator-history-\(appearance.rawValue).png"]
        try capture.run()
        capture.waitUntilExit()
        try require(capture.terminationStatus == 0, "native screenshot must succeed")
        model.performLauncherAction(model.secondaryActions[1])
        try require(model.results.count == 1 && !model.isActionsMenuPresented, "delete must refresh and close menu")
        model.performLauncherAction(model.secondaryActions[1])
        try require(model.results.isEmpty && model.status != nil, "last deletion must display empty state")
        try require(model.backspaceOnEmptyInput() && !model.hasScope, "empty backspace must leave history")
        app.preferences.commandKeywords["calculatorHistory"] = "history"
        model.query = "history "
        try require(model.filter == .calculatorHistory, "custom trigger must work")
        model.reset()
        try require(!model.hasScope && model.results.isEmpty, "hide/reset must clear history scope")
    }
}
