import AppKit
import Contracts
import Search

private struct WindowSearchProvider: SearchProvider {
    let source: SearchSource
    let delay: Duration
    let count: Int

    func search(_ query: String, limit: Int) async -> [SearchResult] {
        try? await Task.sleep(for: delay)
        guard !Task.isCancelled, query != "empty" else { return [] }
        // Every successive prefix has the same result geometry.
        return (0..<min(count, limit)).map {
            SearchResult(source: source, target: TargetRef(kind: "test", identifier: "\(source)-\($0)"),
                         title: "Safari \($0)", actions: [], score: 1)
        }
    }
}

/// Runs the real launcher tree/panel with delayed sources and an isolated store.
@main
@MainActor
enum LauncherWindowRegression {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                    application.appearance = NSAppearance(named: appearance)
                    try await checkWindow()
                    print("appearance=\(appearance.rawValue) passed")
                }
                print("LauncherWindow native regression checks passed")
                exit(0)
            } catch {
                fputs("LauncherWindow regression failed: \(error)\n", stderr)
                exit(1)
            }
        }
        application.run()
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "LauncherWindowRegression", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    private static func searchField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.delegate is LauncherSearchField.Coordinator { return field }
        return view.subviews.lazy.compactMap { searchField(in: $0) }.first
    }

    private static func checkWindow() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "KulaHere-window-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let model = LauncherModel(app: app, searchProviders: [
            WindowSearchProvider(source: .app, delay: .milliseconds(10), count: 8),
            WindowSearchProvider(source: .file, delay: .milliseconds(300), count: 4),
        ])
        let controller = LauncherController(model: model)
        model.inputText = "s"
        controller.show()
        defer { controller.hide() }
        guard let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }) as? LauncherPanel else {
            throw NSError(domain: "LauncherWindowRegression", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "launcher panel not available"])
        }
        // This standalone accessory process is not the user's foreground app.
        // A desktop focus change must not dismiss the geometry test halfway through.
        panel.onBlur = {}
        try await Task.sleep(for: .milliseconds(50))
        guard let content = panel.contentView, let field = searchField(in: content) else {
            throw NSError(domain: "LauncherWindowRegression", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "launcher field not available"])
        }
        panel.makeFirstResponder(field)
        guard let editor = field.currentEditor() as? NSTextView else {
            throw NSError(domain: "LauncherWindowRegression", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "launcher editor not available"])
        }
        let initialTop = panel.convertToScreen(field.convert(field.bounds, to: nil)).maxY
        var initialInputDrift: CGFloat = 0
        for _ in 0..<70 {
            try await Task.sleep(for: .milliseconds(5))
            let top = panel.convertToScreen(field.convert(field.bounds, to: nil)).maxY
            initialInputDrift = max(initialInputDrift, abs(top - initialTop))
        }
        print("initialDeliverySamples=70 inputDrift=\(initialInputDrift)")
        try require(initialInputDrift <= 1, "first asynchronous results must preserve input position")
        try require(model.results.contains { $0.source == .app }, "initial search must finish")
        let baseline = panel.frame
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let visibleFrame = screen?.visibleFrame {
            let availableHeight = floor(visibleFrame.height * 0.88 - 24)
            // 64 pt field + 1 pt divider + 400 pt list + 264 pt shadow canvas.
            let expectedHeight = min(465, availableHeight) + 264
            try require(abs(baseline.height - expectedHeight) <= 1,
                        "long results must use the increased 400 pt list budget within screen bounds")
        }
        let inputTop = panel.convertToScreen(field.convert(field.bounds, to: nil)).maxY
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        var minHeight = baseline.height
        var maxInputDrift: CGFloat = 0
        let initialAppCount = model.results.filter { $0.source == .app }.count
        var minAppCount = initialAppCount
        var snapshots = 0
        for character in "afari" {
            editor.insertText(String(character), replacementRange: editor.selectedRange())
            // AppKit may defer its delegate notification for programmatic insertText.
            (field.delegate as? LauncherSearchField.Coordinator)?.controlTextDidChange(
                Notification(name: NSControl.textDidChangeNotification, object: field))
            for _ in 0..<10 {
                try await Task.sleep(for: .milliseconds(5))
                minHeight = min(minHeight, panel.frame.height)
                let top = panel.convertToScreen(field.convert(field.bounds, to: nil)).maxY
                maxInputDrift = max(maxInputDrift, abs(top - inputTop))
                snapshots += 1
                minAppCount = min(minAppCount, model.results.filter { $0.source == .app }.count)
            }
        }
        for _ in 0..<80 {
            try await Task.sleep(for: .milliseconds(5))
            minHeight = min(minHeight, panel.frame.height)
            let top = panel.convertToScreen(field.convert(field.bounds, to: nil)).maxY
            maxInputDrift = max(maxInputDrift, abs(top - inputTop))
            snapshots += 1
        }
        print("samples=\(snapshots) baselineHeight=\(baseline.height) minHeight=\(minHeight) inputDrift=\(maxInputDrift) model=\(model.inputText) editor=\(editor.string)")
        try require(model.inputText == "safari" && editor.string == "safari", "native typing must preserve text")
        try require(abs(minHeight - baseline.height) <= 1, "results must not collapse while the replacement search is pending")
        try require(maxInputDrift <= 1, "input screen position must stay fixed during result delivery")
        try require(minAppCount == initialAppCount, "still-matching rows must remain visible between search batches")
        try require(field.currentEditor() === editor, "result delivery must preserve the editor")

        model.inputText = "empty"
        try await Task.sleep(for: .milliseconds(250))
        try require(model.isSearching, "slow source must still be pending")
        try require(abs(panel.frame.height - baseline.height) <= 1, "slow pending search must retain the result footprint")
        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(5))
            let top = panel.convertToScreen(field.convert(field.bounds, to: nil)).maxY
            maxInputDrift = max(maxInputDrift, abs(top - inputTop))
        }
        try require(panel.frame.height < baseline.height, "settled smaller results must release reserved height")
        try require(!model.results.contains { $0.source == .app || $0.source == .file }, "empty provider batches must remove old results")
        model.inputText = ""
        for _ in 0..<60 {
            try await Task.sleep(for: .milliseconds(5))
            let top = panel.convertToScreen(field.convert(field.bounds, to: nil)).maxY
            maxInputDrift = max(maxInputDrift, abs(top - inputTop))
        }
        try require(abs(panel.frame.height - 328) <= 1, "clearing input must restore the 64 pt field plus shadow canvas")
        print("settledChangeSamples=160 inputDrift=\(maxInputDrift)")
        try require(maxInputDrift <= 1, "shrinking/clearing results must preserve input position")

        model.inputText = "go "
        try await Task.sleep(for: .milliseconds(200))
        try require(model.commandInput != nil && editor.string.isEmpty, "keyword entry must consume its token")
        editor.insertText("safari", replacementRange: editor.selectedRange())
        (field.delegate as? LauncherSearchField.Coordinator)?.controlTextDidChange(
            Notification(name: NSControl.textDidChangeNotification, object: field))
        try await Task.sleep(for: .milliseconds(200))
        try require(model.commandInput?.text == "safari", "keyword query must remain editable")
    }
}
