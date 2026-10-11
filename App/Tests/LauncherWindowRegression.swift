import AppKit
import Contracts
import Search
import LocalStore

private struct WindowSearchProvider: SearchProvider {
    let source: SearchSource
    let delay: Duration
    let count: Int
    var matchingQueries: Set<String>? = nil

    func search(_ query: String, limit: Int) async -> [SearchResult] {
        try? await Task.sleep(for: delay)
        guard !Task.isCancelled, query != "empty",
              matchingQueries.map({ $0.contains(query) }) ?? true else { return [] }
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
        if CommandLine.arguments.contains("--scroll-background") {
            runScrollBackground()
            return
        }
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                    application.appearance = NSAppearance(named: appearance)
                    if CommandLine.arguments.contains("--system-app-names") {
                        try await checkSystemAppNames()
                    } else if CommandLine.arguments.contains("--alias-routing") {
                        try await checkAliasRouting()
                    } else if CommandLine.arguments.contains("--ai-routing") {
                        try await checkAIRouting()
                    } else {
                        try await checkWindow()
                    }
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

    private static func checkSystemAppNames() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "Asky-system-names-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let model = LauncherModel(app: app, searchProviders: [AppsProvider()])
        let controller = LauncherController(model: model)
        controller.show()
        let panel = NSApp.windows.first { $0 is LauncherPanel && $0.isVisible }
        (panel as? LauncherPanel)?.onBlur = {}
        defer { controller.hide() }
        for (query, file) in [("电话", "Phone.app"), ("备忘录", "Notes.app"),
                              ("计算器", "Calculator.app"), ("系统设置", "System Settings.app"),
                              ("音频MIDI设置", "Audio MIDI Setup.app"), ("活动监视器", "Activity Monitor.app"),
                              ("终端", "Terminal.app"), ("日历", "Calendar.app")] {
            model.query = query
            for _ in 0..<60 {
                if !model.isSearching { break }
                try await Task.sleep(for: .milliseconds(50))
            }
            try require(!model.isSearching, "system app search must finish")
            try require(model.results.contains { $0.source == .app &&
                URL(fileURLWithPath: $0.target.identifier).lastPathComponent == file },
                "missing system app for \(query)")
            let result = model.results.first { URL(fileURLWithPath: $0.target.identifier).lastPathComponent == file }
            try require(result?.title == query, "expected Chinese title \(query), got \(result?.title ?? "nil")")
            print("\(query) => \(file), title=\(result!.title) passed")
            if query == "系统设置", let view = panel?.contentView,
               let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: bitmap)
                if let png = bitmap.representation(using: .png, properties: [:]) {
                    try png.write(to: URL(filePath: "build/launcher-system-names-" +
                        (NSApp.appearance?.name.rawValue ?? "default") + ".png"))
                }
            }
        }
    }

    private static func checkAliasRouting() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "Asky-alias-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let model = LauncherModel(app: app, searchProviders: [
            WindowSearchProvider(source: .app, delay: .milliseconds(10), count: 2),
            WindowSearchProvider(source: .shortcut, delay: .milliseconds(250), count: 1),
        ])
        let controller = LauncherController(model: model)
        controller.show()
        let panel = NSApp.windows.first { $0 is LauncherPanel && $0.isVisible }
        (panel as? LauncherPanel)?.onBlur = {}
        defer { controller.hide() }
        model.query = "GO"
        try require(model.results.first?.target.kind == "keyword-match" && model.selection == 0,
                    "exact case-insensitive keyword must be selected before provider batches")
        try require(model.keyword(for: model.results[0]) == "go", "exact match must retain its badge")
        try require(model.results[0].target.identifier == "https://www.google.com/search?q=",
                    "bare keyword must open its command without searching for the alias itself")
        for _ in 0..<60 {
            if !model.isSearching { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        try require(!model.isSearching, "search providers must finish within three seconds")
        try require(model.results.prefix(2).map(\.source) == [.keyword, .shortcut] && model.selection == 0,
                    "late app and shortcut batches must leave the alias first and selected")
        if let view = panel?.contentView,
           let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            if let png = bitmap.representation(using: .png, properties: [:]) {
                let file = "build/launcher-alias-" + (NSApp.appearance?.name.rawValue ?? "default") + ".png"
                try png.write(to: URL(filePath: file))
            }
        }
        model.query = "Safari"
        for _ in 0..<60 {
            if !model.isSearching { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        try require(!model.isSearching, "search providers must finish within three seconds")
        try require(model.results.first?.source == .shortcut && model.selection == 0,
                    "shortcut results must precede apps")
        model.query = "go SwiftUI"
        try require(model.commandInput != nil && model.results.count == 1 &&
                    model.results[0].target.identifier.contains("q=SwiftUI"),
                    "space must still enter the explicit keyword query mode")
        model.query = "gopher"
        for _ in 0..<60 {
            if !model.isSearching { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        try require(!model.isSearching, "search providers must finish within three seconds")
        try require(!model.results.contains { $0.target.kind == "keyword-match" },
                    "partial keywords must not count as exact aliases")
        app.preferences.aliases = [LauncherAlias(alias: "sc", kind: "shortcut", target: "Daily")]
        model.query = "SC"
        try await Task.sleep(for: .milliseconds(500))
        try require(model.results.first?.target.kind == "launcher-alias" &&
                    model.results.first?.primaryAction == .runShortcut(name: "Daily"),
                    "configured shortcut aliases must survive late search batches and remain selected")
        let restored = try AppModel(root: root)
        try require(restored.preferences.aliases == app.preferences.aliases,
                    "aliases must survive app reload")
        app.preferences.appearance = "dark"
        app.preferences.hotKeyLabel = "⌃⌥ Space"
        let reloaded = try AppModel(root: root)
        try require(reloaded.preferences.appearance == "dark" && reloaded.preferences.hotKeyLabel == "⌃⌥ Space",
                    "appearance and hotkey preferences must survive reload")
        NSApp.appearance = NSAppearance(named: .aqua)
        let credentials = ModelCredentialSession()
        let fakeKeychain = Keychain(service: "app.asky.nonexistent-regression")
        await credentials.remember("synthetic", account: "model")
        for _ in 0..<2 {
            let value = try await credentials.read(account: "model", keychain: fakeKeychain,
                started: { fatalError("cached credentials must not request authorization") }, finished: {})
            try require(value == "synthetic", "capability checks and runtime must share session credentials")
        }
        await credentials.remember("replacement", account: "model")
        let replacement = try await credentials.read(account: "model", keychain: fakeKeychain,
            started: { fatalError("a freshly saved key must not request authorization") }, finished: {})
        try require(replacement == "replacement", "saving a new key must update the session credential")
        print("Exact alias, case folding, late batches, shortcut priority and spaced command passed")
    }

    private static func checkAIRouting() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "Asky-routing-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let model = LauncherModel(app: app, searchProviders: [
            WindowSearchProvider(source: .app, delay: .milliseconds(300), count: 8,
                                 matchingQueries: ["Safari", "kimi"]),
            WindowSearchProvider(source: .bookmark, delay: .milliseconds(10), count: 4),
        ])
        var submitted: [String] = []
        model.onAskAI = { submitted.append($0) }
        let controller = LauncherController(model: model)
        controller.show()
        if let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }) as? LauncherPanel {
            panel.onBlur = {}
            // Keep the routing test independent of typing in the user's app.
            panel.orderOut(nil)
        }
        defer { controller.hide() }
        let prompt = "帮我梳理一下日程"
        model.query = "Safari"
        try await Task.sleep(for: .milliseconds(150))
        model.query = prompt
        try require(submitted.isEmpty, "typing must not submit AI")
        try require(model.results.count == 1 && model.results[0].source == .askAI,
                    "conversation must show only the AI action, with no bookmark fallback")
        try require(model.selection == 0 && !model.isSearching, "AI must be the default selection")
        try require(model.results[0].subtitle.isEmpty, "AI row must have no shortcut subtitle")
        try await Task.sleep(for: .milliseconds(450))
        try require(model.results.count == 1, "cancelled local batches must not replace the AI selection")
        if let panel = NSApp.windows.first(where: { $0 is LauncherPanel }) as? LauncherPanel {
            try require(abs(panel.frame.height - 391) <= 1,
                        "single AI category must omit the 52 pt header from native window height")
        }
        model.submit(.executeSelection)
        try require(submitted == [prompt], "ordinary Return must hand the prompt to AI once")
        for text in ["你是谁啊", "你好", "随便聊聊", "我今天有点累", "明天有什么安排"] {
            model.query = text
            try require(model.results.count == 1 && model.results.first?.source == .askAI,
                        "unmatched plain text must immediately default to AI without phrase rules")
            try await Task.sleep(for: .milliseconds(450))
            try require(model.results.count == 1 && model.results.first?.source == .askAI && model.selection == 0,
                        "empty local batches must leave only AI, not generic bookmark or Google actions")
            try require(submitted.last != text, "typing plain text must not send")
            model.submit(.executeSelection)
            try require(submitted.last == text, "Return must submit unmatched plain text: expected \(text), got \(submitted.last ?? "nil")")
        }
        model.query = "kimi"
        try await Task.sleep(for: .milliseconds(450))
        try require(model.results.first?.source == .app, "bare names must keep local search first")
        try require(model.results.filter { $0.source == .askAI }.count == 1, "local search retains one AI action")
        model.query = "go " + prompt
        try require(model.commandInput != nil && model.results.first?.source == .keyword,
                    "explicit keyword must keep its command result")
        print("AI default selection, Return handoff, no subtitle, cancelled batches and explicit scopes passed")
    }

    private static func searchField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.delegate is LauncherSearchField.Coordinator { return field }
        return view.subviews.lazy.compactMap { searchField(in: $0) }.first
    }

    private static func scrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
    }

    private static func checkScrolling(panel: LauncherPanel, content: NSView,
                                       model: LauncherModel, editor: NSTextView) async throws {
        guard let scroll = scrollView(in: content) else {
            throw NSError(domain: "LauncherWindowRegression", code: 3)
        }
        let listRect = scroll.convert(scroll.bounds, to: nil)
        let inputPoint = NSPoint(x: listRect.midX, y: listRect.maxY + 32)
        let rowPoint = NSPoint(x: listRect.midX, y: listRect.midY)
        let selection = model.selection
        let text = editor.string
        for units in [CGScrollEventUnit.line, .pixel] {
            for point in [rowPoint, inputPoint] {
                let before = scroll.contentView.bounds.origin.y
                let cg = CGEvent(scrollWheelEvent2Source: nil, units: units, wheelCount: 1,
                                 wheel1: units == .line ? -4 : -80, wheel2: 0, wheel3: 0)!
                let event = NSEvent(cgEvent: cg)!
                try require(panel.routeScrollWheel(event, at: point), "shell must route wheel events")
                try await Task.sleep(for: .milliseconds(200))
                let after = scroll.contentView.bounds.origin.y
                try require(after > before, "mouse/precise scrolling must move actual results")
                let reverse = CGEvent(scrollWheelEvent2Source: nil, units: units, wheelCount: 1,
                                      wheel1: units == .line ? 4 : 80, wheel2: 0, wheel3: 0)!
                panel.routeScrollWheel(NSEvent(cgEvent: reverse)!, at: point)
                try await Task.sleep(for: .milliseconds(200))
                try require(scroll.contentView.bounds.origin.y < after, "reverse scrolling must work")
            }
        }
        let event = NSEvent(cgEvent: CGEvent(scrollWheelEvent2Source: nil, units: .line,
                                           wheelCount: 1, wheel1: -4, wheel2: 0, wheel3: 0)!)!
        try require(!panel.routeScrollWheel(event, at: .zero), "shadow must not intercept scrolling")
        try require(model.selection == selection && editor.string == text && panel.firstResponder === editor,
                    "scrolling must preserve selection, text and input focus")
        let target = model.results.lastIndex { $0.source == .file }!
        let steps = target - selection
        let field = searchField(in: content)!
        for _ in 0..<steps {
            _ = (field.delegate as? LauncherSearchField.Coordinator)?.control(
                field, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:)))
        }
        try await Task.sleep(for: .milliseconds(200))
        try require(model.selection == target, "keyboard navigation must remain available")
        try require(scroll.contentView.bounds.origin.y > 0, "keyboard must reveal an offscreen selection")
        let coordinator = field.delegate as! LauncherSearchField.Coordinator
        for _ in 0..<(model.results.count + 3) {
            _ = coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:)))
        }
        try await Task.sleep(for: .milliseconds(200))
        try require(model.selection == model.results.count - 1, "repeated Down must stop at the last result")
        let bottom = scroll.contentView.bounds.origin.y
        _ = coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:)))
        try await Task.sleep(for: .milliseconds(200))
        try require(scroll.contentView.bounds.origin.y == bottom, "Down at the last result must not scroll back to the top")
        _ = coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveUp(_:)))
        try require(model.selection == model.results.count - 2, "Up must move away from the last result")
        for _ in 0..<(model.results.count + 3) {
            _ = coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveUp(_:)))
        }
        try await Task.sleep(for: .milliseconds(200))
        try require(model.selection == 0, "repeated Up must stop at the first result")
        let top = scroll.contentView.bounds.origin.y
        _ = coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveUp(_:)))
        try await Task.sleep(for: .milliseconds(200))
        try require(scroll.contentView.bounds.origin.y == top, "Up at the first result must not scroll back to the bottom")
        _ = coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:)))
        try require(model.selection == 1 && panel.firstResponder === editor,
                    "Down must move away from the first result while preserving input focus")
        model.selection = selection
        try await Task.sleep(for: .milliseconds(200))
        print("wheel/precise forward/reverse over rows/input, focus and bounded keyboard navigation checks passed")
    }

    private static func runScrollBackground() {
        let args = CommandLine.arguments
        let report = URL(fileURLWithPath: args[2])
        let frame = NSRect(x: Double(args[3])!, y: Double(args[4])!,
                           width: Double(args[5])!, height: Double(args[6])!)
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: NSRect(origin: .zero, size: frame.size))
        let document = NSTextView(frame: NSRect(x: 0, y: 0, width: frame.width, height: 5000))
        document.string = String(repeating: "Synthetic background scroll target\n", count: 200)
        scroll.documentView = document
        window.contentView = scroll
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 200))
        scroll.reflectScrolledClipView(scroll.contentView)
        let timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            MainActor.assumeIsolated {
                try? String(describing: scroll.contentView.bounds.origin.y).write(to: report, atomically: true, encoding: .utf8)
            }
        }
        withExtendedLifetime((window, timer)) { NSApp.run() }
    }

    private static func checkSystemDelivery(controller: LauncherController, panel: LauncherPanel, content: NSView) async throws {
        try require(CGPreflightPostEventAccess(), "system scroll test requires existing event-post access")
        let report = FileManager.default.temporaryDirectory.appending(path: "Asky-scroll-\(UUID())")
        let background = Process()
        background.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        background.arguments = ["--scroll-background", report.path, String(describing: panel.frame.minX),
                                String(describing: panel.frame.minY), String(describing: panel.frame.width), String(describing: panel.frame.height)]
        background.terminationHandler = { _ in try? FileManager.default.removeItem(at: report) }
        try background.run()
        defer { background.terminate() }
        for _ in 0..<100 {
            if FileManager.default.fileExists(atPath: report.path) { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        try await Task.sleep(for: .milliseconds(200))
        controller.show()
        let foreground = scrollView(in: content)!
        foreground.contentView.scroll(to: NSPoint(x: 0, y: 200))
        foreground.reflectScrolledClipView(foreground.contentView)
        let oldPointer = CGEvent(source: nil)!.location
        defer { CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: oldPointer,
                        mouseButton: .left)?.post(tap: .cghidEventTap) }
        let rect = panel.convertToScreen(foreground.convert(foreground.bounds, to: nil))
        let points = [NSPoint(x: rect.midX, y: rect.midY),
                      NSPoint(x: rect.midX, y: rect.maxY + 32),
                      NSPoint(x: rect.minX + 3, y: rect.midY)]
        for units in [CGScrollEventUnit.line, .pixel] {
            for location in points {
                foreground.contentView.scroll(to: NSPoint(x: 0, y: 200))
                foreground.reflectScrolledClipView(foreground.contentView)
                let point = CGPoint(x: location.x, y: NSScreen.screens[0].frame.maxY - location.y)
                CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point,
                        mouseButton: .left)?.post(tap: .cghidEventTap)
                try await Task.sleep(for: .milliseconds(200))
                print("hit point=\(location) panelFrame=\(panel.frame) key=\(panel.isKeyWindow) active=\(NSApp.isActive)")
                let backBefore = try String(contentsOf: report, encoding: .utf8)
                let frontBefore = foreground.contentView.bounds.origin.y
                let event = CGEvent(scrollWheelEvent2Source: nil, units: units, wheelCount: 1,
                                    wheel1: units == .line ? -5 : -80, wheel2: 0, wheel3: 0)!
                event.location = point
                event.post(tap: .cghidEventTap)
                try await Task.sleep(for: .milliseconds(700))
                let backAfter = try String(contentsOf: report, encoding: .utf8)
                print("system delivery front=\(frontBefore)->\(foreground.contentView.bounds.origin.y) background=\(backBefore)->\(backAfter)")
                try require(foreground.contentView.bounds.origin.y != frontBefore, "system wheel must reach launcher")
                try require(backAfter == backBefore, "background app must not scroll under launcher")
            }
        }
    }

    private static func checkWindow() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "Asky-window-\(UUID())")
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
        try await checkSystemDelivery(controller: controller, panel: panel, content: content)
        try await checkScrolling(panel: panel, content: content, model: model, editor: editor)
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
