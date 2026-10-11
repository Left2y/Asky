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
        let legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(app.settings)) as! [String: Any]
        var oldSettings = legacy
        oldSettings.removeValue(forKey: "terminalApplicationID")
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: oldSettings))
        try require(decoded.terminalApplicationID == nil && decoded.fileScopes == app.settings.fileScopes, "old settings preserve values and default to system terminal")
        let model = LauncherModel(app: app, searchProviders: [])
        try require(model.terminalApplication == .system && model.terminalIcon != nil, "system app icon is available")
        app.settings.terminalApplicationID = LauncherTerminalApplication.iTerm.rawValue
        try require(model.terminalApplication == .iTerm, "selection changes launcher terminal")
        try require(SettingsReader(store: app.store).load().terminalApplicationID == LauncherTerminalApplication.iTerm.rawValue, "terminal selection persists")
        app.settings.terminalApplicationID = nil
        let controller = LauncherController(model: model)
        controller.show()
        defer { controller.hide() }
        try await Task.sleep(for: .milliseconds(250))
        guard let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }),
              let field = findField(panel.contentView!) else { throw NSError(domain: "TerminalRegression", code: 2) }
        (panel as? LauncherPanel)?.onBlur = {}
        panel.makeFirstResponder(field)
        guard let editor = field.currentEditor() as? NSTextView else {
            throw NSError(domain: "TerminalRegression", code: 3)
        }
        editor.insertText(">", replacementRange: editor.selectedRange())
        field.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: field))
        try await Task.sleep(for: .milliseconds(200))
        try require(!model.hasScope && model.inputText == ">" && editor.string == ">", "bare prefix stays visible in ordinary search")
        try require(!model.results.contains { $0.source == .terminal }, "bare prefix offers no terminal action")
        editor.insertText(" ", replacementRange: editor.selectedRange())
        field.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: field))
        try require(model.isTerminalScope && model.inputText.isEmpty && model.results.isEmpty, "space enters idle terminal mode")
        try require(field.stringValue.isEmpty && editor.string.isEmpty && editor.selectedRange().location == 0, "space consumes prefix and resets native caret immediately")
        model.inputText = "printf '%s' 'go chat' > result.txt"
        try await Task.sleep(for: .milliseconds(200))
        try require(findField(panel.contentView!)?.stringValue == model.inputText, "native field displays only command")
        try require(model.results.count == 1 && model.results.first?.primaryAction == .runTerminal(command: model.inputText), "only terminal action is offered")
        if let view = panel.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to: URL(filePath: "build/launcher-terminal.png"))
        }
        model.inputText = ""
        try require(model.backspaceOnEmptyInput(), "Backspace exits terminal mode")
        try require(!model.hasScope, "ordinary search resumes")
        model.query = ">pwd"
        try require(!model.hasScope && model.inputText == ">pwd", "pasted prefix without space remains search")
        try require(!model.results.contains { $0.source == .terminal }, "undelimited pasted command offers no terminal action")
        model.query = "> pwd"
        try require(model.isTerminalScope && model.inputText == "pwd", "pasted prefix with space enters terminal mode")
        model.query = "go cats"
        try require(!model.isTerminalScope && model.commandInput?.command.keyword == "go", "web keywords still work")
        let settings = SettingsWindow.make(app: app)
        settings.center()
        settings.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(250))
        if let view = settings.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to: URL(filePath: "build/terminal-settings.png"))
        }
        settings.orderOut(nil)
        print("Terminal settings: legacy decoding, selected app, icon and persistence passed")
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

    static func findField(_ view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        return view.subviews.compactMap(findField).first
    }
}
