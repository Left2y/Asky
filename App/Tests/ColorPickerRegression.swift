import AppKit
import Contracts
import LocalStore
import ToolService

@main @MainActor
private enum ColorPickerRegression {
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "ColorPicker", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func main() throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let root = FileManager.default.temporaryDirectory.appending(path: "Asky-color-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let model = LauncherModel(app: app, searchProviders: [])
        for query in ["color", "COLOR", "取色", "屏幕取色"] {
            model.query = query
            try require(model.results.first?.target.identifier == "colorPicker", "query must prioritize color picker: \(query)")
            try require(model.primaryLauncherAction?.title == "屏幕取色", "primary action must describe color picking")
        }
        app.preferences.commandKeywords["colorPicker"] = "pick"
        model.query = "pick"
        try require(model.results.first?.target.identifier == "colorPicker", "custom keyword must keep the stable command identity")
        model.setFilter(.files, query: "pick")
        try require(!model.results.contains { $0.target.identifier == "colorPicker" }, "file scope must not expose global tools")
        let hex = ToolService.screenColorHex(NSColor(srgbRed: 1, green: 147.0 / 255, blue: 23.0 / 255, alpha: 1))!
        let item = ClipboardItem(kind: .text, text: hex, byteSize: hex.utf8.count, contentHash: "test")
        try require(ClipboardColor(item: item)?.hex == "#FF9317", "sampled text must be recognized by the existing clipboard preview")
        print("Color picker routing, custom keyword, scope and clipboard preview regression passed")
    }
}
