import AppKit
import Contracts
import ToolService

@main @MainActor
enum LauncherTerminalRegression {
    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                try await check()
                print("Launcher terminal native regression passed")
                exit(0)
            } catch {
                print("FAILED: \(error)")
                exit(1)
            }
        }
        NSApplication.shared.run()
    }

    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TerminalRegression", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func check() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Asky-terminal-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let model = LauncherModel(app: app, searchProviders: [])
        let controller = LauncherController(model: model)
        controller.show()
        defer { controller.hide() }
        try await Task.sleep(for: .milliseconds(250))
        guard let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }),
              let field = findField(panel.contentView!) else { throw NSError(domain: "TerminalRegression", code: 2) }
        (panel as? LauncherPanel)?.onBlur = {}
        model.inputText = ">"
        try await Task.sleep(for: .milliseconds(200))
        try require(model.isTerminalScope && model.inputText.isEmpty && model.results.isEmpty, "bare prefix enters idle terminal mode")
        try require(field.stringValue.isEmpty, "prefix consumed in native field")
        model.inputText = "printf '%s' 'go chat' > result.txt"
        try await Task.sleep(for: .milliseconds(200))
        try require(field.stringValue == model.inputText, "native field displays only command")
        try require(model.results.count == 1 && model.results.first?.primaryAction == .runTerminal(command: model.inputText), "only terminal action is offered")
        if let view = panel.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to: URL(filePath: "build/launcher-terminal.png"))
        }
        model.inputText = ""
        try require(model.backspaceOnEmptyInput(), "Backspace exits terminal mode")
        try require(!model.hasScope, "ordinary search resumes")
        model.query = ">pwd"
        try require(model.isTerminalScope && model.inputText == "pwd", "pasted prefix without space")
        model.query = "go cats"
        try require(!model.isTerminalScope && model.commandInput?.command.keyword == "go", "web keywords still work")
        print("Native field: prefix, shell redirection, empty state, Backspace and keyword replacement passed")
        if CommandLine.arguments.contains("--handoff") {
            let marker = root.appendingPathComponent("handoff.txt")
            app.settings.terminalWorkingDirectory = root.path
            var didHide = false
            model.onHide = { didHide = true; controller.hide() }
            model.query = "> printf terminal-ok > handoff.txt"
            model.submit(.executeSelection)
            for _ in 0..<50 {
                if FileManager.default.fileExists(atPath: marker.path), didHide { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            try require((try? String(contentsOf: marker, encoding: .utf8)) == "terminal-ok", "Terminal executed in configured directory")
            try require(didHide && model.terminal == nil, "successful handoff hides launcher without embedded shell")
            print("Return handed off to Terminal; marker read back and launcher hidden")
        }
    }

    static func findField(_ view: NSView) -> CompletionTextField? {
        if let field = view as? CompletionTextField { return field }
        return view.subviews.compactMap(findField).first
    }
}
