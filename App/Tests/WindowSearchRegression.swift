import AppKit
import ApplicationServices
import ToolService

@main @MainActor
private enum WindowSearchRegression {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                try await check()
                print("PASS: sw entry, custom trigger, mode isolation, exit, cancellation")
                print("Live Accessibility access: \(AXIsProcessTrusted())")
                exit(0)
            } catch {
                fputs("FAIL: \(error)\n", stderr)
                exit(1)
            }
        }
        app.run()
    }

    static func require(_ value: Bool, _ message: String) throws {
        if !value { throw NSError(domain: "WindowSearch", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func check() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Asky-windows-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let model = LauncherModel(app: app, searchProviders: [], chromeBookmarkAccessAllowed: false)
        model.inputText = "sw"
        guard let command = model.results.first(where: { $0.target.kind == "search-command" && $0.target.identifier == "windows" }) else {
            throw NSError(domain: "WindowSearch", code: 2)
        }
        model.execute(command, action: command.primaryAction)
        try require(model.filter == .windows && model.inputText.isEmpty, "Return must enter empty window search")
        model.inputText = "link readme"
        try require(model.filter == .windows && !model.isLinkScope, "Window query must not switch modes")
        model.inputText = "README"
        model.leaveCommand()
        try require(model.filter == .all && model.inputText == "README", "Escape must retain query")
        model.reset()
        model.inputText = "sw "
        try require(model.filter == .windows && model.inputText.isEmpty, "Space must enter window mode")
        try require(model.backspaceOnEmptyInput() && model.filter == .all, "Backspace must exit")
        app.preferences.commandKeywords["windows"] = "win"
        model.inputText = "win README"
        try require(model.filter == .windows && model.inputText == "README", "Custom trigger must preserve query")
        model.reset()
        try await Task.sleep(for: .milliseconds(300))
        try require(model.filter == .all && model.results.isEmpty, "Cancelled search must not repopulate results")
        // The native permission branch runs without requesting or changing permissions.
        if !AXIsProcessTrusted() {
            model.inputText = "win "
            try await Task.sleep(for: .milliseconds(400))
            try require(!model.isSearching && model.status != nil && model.results.isEmpty,
                        "Missing permission must be visible without app-only fallback")
            model.reset()
            print("PASS: missing Accessibility permission feedback")
        }
    }
}
