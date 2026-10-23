import AppKit
import Contracts
import LocalStore
import ToolService

@main @MainActor
private enum PluginLauncherRegression {
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "PluginLauncher", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func until(line: Int = #line, _ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw NSError(domain: "PluginLauncher", code: 2, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for plugin state at line \(line)"])
    }
    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        // This regression drives the model; discard physical events from concurrent UI regressions.
        let eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .mouseMoved]) { _ in nil }
        defer { if let eventMonitor { NSEvent.removeMonitor(eventMonitor) } }
        Task { @MainActor in
            do {
                for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                    NSApp.appearance = NSAppearance(named: appearance)
                    try await check(appearance)
                }
                print("Plugin launcher regression passed in light and dark appearances; no AI configured")
                exit(0)
            } catch {
                fputs("Plugin launcher regression failed: \(error)\n", stderr)
                exit(1)
            }
        }
        NSApp.run()
    }
    static func check(_ appearance: NSAppearance.Name) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "Asky-plugin-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LocalStore(root: root)
        let source = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appending(path: "examples/plugins/text-tools")
        let directory = root.appending(path: "plugins/text_tools")
        try FileManager.default.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: directory)
        var manifest = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: directory.appending(path: "asky-plugin.json")))
        var object = manifest.objectValue!
        var tools = object["tools"]!.arrayValue!
        tools.append(["name": "write", "description": "Confirm action", "agentVisible": false,
                      "effect": "write", "confirmation": "always", "inputSchema": ["type": "object", "properties": [:]]])
        var commands = object["commands"]!.arrayValue!
        commands.append(["name": "write", "title": "Confirm Action", "mode": "action", "tool": "write"])
        object["tools"] = .array(tools)
        object["commands"] = .array(commands)
        manifest = .object(object)
        let record: JSONValue = ["manifest": manifest, "repository": "https://github.com/example/text-tools", "commit": "fixture", "enabled": true, "configuration": [:]]
        let plugin = try JSONDecoder().decode(InstalledPlugin.self, from: record.canonicalData())
        store.setCodableSetting("plugins.installed", [plugin])
        let entry = directory.appending(path: "index.mjs")
        var code = try String(contentsOf: entry, encoding: .utf8)
        code = code.replacingOccurrences(of: "if (!text)", with: "if (text === 'slow') await new Promise(r => setTimeout(r, 800));\n        if (!text)")
        try code.write(to: entry, atomically: true, encoding: .utf8)
        let app = try AppModel(root: root)
        let model = LauncherModel(app: app, searchProviders: [])
        var askedAI = false
        model.onAskAI = { _ in askedAI = true }
        model.query = "Tools"
        try await until { model.results.contains { $0.target.kind == "plugin-command" } }
        model.selection = model.results.firstIndex { $0.target.identifier == "text_tools/text" }!
        model.submit(.executeSelection)
        try require(model.pluginScope?.id == "text_tools/text", "selection must enter plugin scope")
        model.inputText = "你好 world"
        try await until { !model.isSearching && model.results.count == 2 }
        try require(model.results[0].title == "%E4%BD%A0%E5%A5%BD%20world", "query must execute via worker without a model")
        try require(model.inputText == "你好 world" && model.hasScope, "plugin input must stay in its scope")
        let controller = LauncherController(model: model)
        controller.show()
        defer { controller.hide() }
        guard let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }) as? LauncherPanel else {
            throw NSError(domain: "PluginLauncher", code: 3)
        }
        let blur = panel.onBlur
        panel.onBlur = {}
        var copiedText: String?
        var copyCount = 0
        model.onHide = {
            copiedText = NSPasteboard.general.string(forType: .string)
            copyCount += 1
        }
        try await until { !model.isSearching && model.results.count == 2 }
        try await Task.sleep(for: .milliseconds(400))
        let capture = Process()
        capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-l", String(panel.windowNumber), "build/plugin-launcher-\(appearance.rawValue).png"]
        try capture.run()
        capture.waitUntilExit()
        try require(capture.terminationStatus == 0, "native capture must succeed")
        model.selection = 0
        model.submit(.executeSelection)
        try await until { copiedText == "%E4%BD%A0%E5%A5%BD%20world" }
        model.inputText = "slow"
        try await Task.sleep(for: .milliseconds(220))
        model.inputText = "new"
        try await until { !model.isSearching && model.results.first?.title == "new" }
        try await Task.sleep(for: .milliseconds(900))
        try require(model.results.first?.title == "new", "stale query must not overwrite newer results")
        model.inputText = ""
        try require(model.backspaceOnEmptyInput() && model.pluginScope == nil, "empty backspace must exit scope")
        model.query = "text hello"
        try require(model.pluginScope?.id == "text_tools/text" && model.inputText == "hello", "keyword prefix must enter plugin scope")
        model.leaveCommand()
        model.query = "Generate UUID"
        try require(model.results.first?.target.identifier == "text_tools/uuid", "command titles must be searchable")
        model.submit(.executeSelection)
        try await until { !model.isSearching && model.results.first?.target.kind == "plugin-result" }
        try require(UUID(uuidString: model.results.first?.title ?? "") != nil, "action command must run immediately")
        model.leaveCommand()
        model.query = "Confirm Action"
        model.submit(.executeSelection)
        try await until { !app.confirmations.queue.isEmpty }
        try require(model.isConfirmingPluginCommand, "launcher must retain pending confirmation state")
        blur()
        try require(controller.isVisible && model.pluginScope?.id == "text_tools/write", "confirmation focus change must not hide or cancel launcher")
        app.confirmations.rejectAll()
        try await until { !model.isSearching }
        try require(model.status != nil, "rejected write must report a result")
        model.leaveCommand()
        model.query = "Generate UUID"
        model.submit(.executeSelection)
        try await until { !model.isSearching && model.results.first?.target.kind == "plugin-result" }
        await app.tools.plugins.setEnabled("text_tools", false)
        let before = copyCount
        model.submit(.executeSelection)
        try await Task.sleep(for: .milliseconds(100))
        try require(copyCount == before, "disabled plugin results must not act")
        model.reset()
        try require(model.results.isEmpty && model.pluginScope == nil, "reset must clear plugin state")
        model.query = "Tools"
        model.rebuildProviders()
        try await Task.sleep(for: .milliseconds(150))
        try require(!model.results.contains { $0.target.kind == "plugin-command" }, "disabled commands must disappear after refresh")
        try require(!askedAI, "functional plugin must never invoke AI")
    }
}
