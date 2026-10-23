import AppKit
import Contracts
import Search

private struct CategoryProvider: SearchProvider {
    let source: SearchSource
    let count: Int
    func search(_ query: String, limit: Int) async -> [SearchResult] {
        try? await Task.sleep(for: .milliseconds(source == .file ? 150 : 20))
        // Deliberately finishes cancelled requests too; the coordinator must discard them.
        return (0..<min(count, limit)).map {
            SearchResult(source: source, target: TargetRef(kind: "fixture", identifier: "\(source)-\($0)"),
                         title: "\(query) \(source) \($0)", actions: [], score: 1 - Double($0) / 1_000)
        }
    }
}

@main @MainActor
private enum LauncherFilterSearchRegression {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                    application.appearance = NSAppearance(named: appearance)
                    try await check(appearance)
                }
                print("Category search regression passed")
                exit(0)
            } catch {
                fputs("Category search failed: \(error)\n", stderr)
                exit(1)
            }
        }
        application.run()
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "CategorySearch", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    private static func settle(_ model: LauncherModel) async throws {
        for _ in 0..<60 {
            if !model.isSearching { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw NSError(domain: "CategorySearch", code: 2, userInfo: [NSLocalizedDescriptionKey: "Search did not settle"])
    }

    private static func editableField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        return view.subviews.compactMap { editableField(in: $0) }.first
    }

    private static func scrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.compactMap { scrollView(in: $0) }.first
    }

    private static func check(_ appearance: NSAppearance.Name) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "Asky-category-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let model = LauncherModel(app: app, searchProviders: [
            CategoryProvider(source: .app, count: 85), CategoryProvider(source: .file, count: 250),
            CategoryProvider(source: .shortcut, count: 65), CategoryProvider(source: .keyword, count: 250)
        ], chromeBookmarkAccessAllowed: false)
        let controller = LauncherController(model: model)
        controller.show()
        defer { controller.hide() }
        guard let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }) as? LauncherPanel else {
            throw NSError(domain: "CategorySearch", code: 3)
        }
        panel.onBlur = {}
        // This suite scripts keyboard navigation; the user's pointer must not select rows.
        panel.ignoresMouseEvents = true
        panel.resignKey()
        NSApp.deactivate()
        model.inputText = "report"
        try await settle(model)
        try require(model.results.filter { $0.source == .file }.count == 8, "All must keep 8 file hits")
        for (filter, source, expected) in [(LauncherFilter.files, SearchSource.file, 200),
                                           (.applications, .app, 85), (.shortcuts, .shortcut, 65),
                                           (.quickLinks, .keyword, 200)] {
            model.setFilter(filter)
            try require(model.inputText == "report", "category switch must preserve query")
            try await settle(model)
            try require(model.results.count == expected && model.results.allSatisfy { $0.source == source },
                        "\(filter): expected \(expected), got \(model.results.count)")
            if filter == .files {
                model.move(199)
                try await Task.sleep(for: .milliseconds(400))
                try require(model.selection == 199 && model.results[199].target.identifier == "file-199",
                            "keyboard must reach hit 200")
                guard let scroll = panel.contentView.flatMap({ scrollView(in: $0) }) else {
                    throw NSError(domain: "CategorySearch", code: 4)
                }
                try require(scroll.contentView.bounds.origin.y > 0, "last hit must scroll into view")
                guard let document = scroll.documentView else { throw NSError(domain: "CategorySearch", code: 4) }
                try require(abs(document.bounds.maxY - scroll.contentView.bounds.maxY) <= 2,
                            "lazy list must reveal the actual final row, including footer clearance")
                let capture = Process()
                capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-l", String(panel.windowNumber), "build/category-search-\(appearance.rawValue).png"]
                try capture.run()
                capture.waitUntilExit()
                try require(capture.terminationStatus == 0, "screenshot must succeed")
                model.move(-199)
                try await Task.sleep(for: .milliseconds(250))
                try require(model.selection == 0 && scroll.contentView.bounds.origin.y <= 1,
                            "keyboard must return to the first unrealized row: selection=\(model.selection), offset=\(scroll.contentView.bounds.origin.y), height=\(document.bounds.height)")
            }
        }
        // Sample the real main run loop while result rows and rapid query updates run.
        model.setFilter(.files)
        var gaps: [Double] = []
        let probe = Task { @MainActor in
            var last = ContinuousClock.now
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(5)) } catch { return }
                let now = ContinuousClock.now
                let duration = last.duration(to: now).components
                gaps.append(Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15)
                last = now
            }
        }
        for i in 0..<20 {
            model.inputText = "report\(i)"
            try await Task.sleep(for: .milliseconds(8))
        }
        try await settle(model)
        try await Task.sleep(for: .milliseconds(150))
        probe.cancel()
        try require(model.results.count == 200 && model.results.allSatisfy { $0.title.hasPrefix("report19 ") },
                    "rapid edits must publish only the newest query: query=\(model.query), searching=\(model.isSearching), count=\(model.results.count), first=\(model.results.first?.title ?? "nil")")
        let sorted = gaps.sorted()
        if !sorted.isEmpty {
            print("\(appearance.rawValue): main-loop probe p95=\(sorted[min(sorted.count - 1, sorted.count * 95 / 100)]) ms, max=\(sorted.last!) ms")
        }
        model.inputText = "report"
        try await settle(model)
        model.setFilter(.files)
        try await Task.sleep(for: .milliseconds(110))
        model.setFilter(.applications)
        try await settle(model)
        try await Task.sleep(for: .milliseconds(200))
        try require(model.results.count == 85 && model.results.allSatisfy { $0.source == .app },
                    "late file batch must not overwrite applications")
        model.setFilter(.all)
        try await settle(model)
        try require(model.results.filter { $0.source == .file }.count == 8 && model.inputText == "report",
                    "returning to All must restore compact results and preserve query")
        for (id, name, trigger) in LauncherFilter.commands {
            let category = LauncherFilter(commandID: id)!
            model.setFilter(.all, query: "")
            model.inputText = trigger.uppercased()
            try require(model.results.first?.target == TargetRef(kind: "search-command", identifier: id),
                        "exact trigger must put the category command first: \(trigger)")
            model.submit(.executeSelection)
            try require(model.filter == category && model.hasScope && model.inputText.isEmpty,
                        "Return must enter an empty category scope")
            try require(model.backspaceOnEmptyInput() && model.filter == .all && !model.hasScope,
                        "empty Backspace must leave category mode")
            model.inputText = trigger + " report"
            try await settle(model)
            try require(model.filter == category && model.inputText == "report", "Space must consume trigger")
            model.inputText = "go literal"
            try require(model.filter == category && model.commandInput == nil && model.inputText == "go literal",
                        "nested commands must remain literal")
            panel.onEscape()
            try require(controller.isVisible && model.filter == .all && model.inputText == "literal",
                        "Escape must return to the root, where normal commands are parsed")
            // Exit the normal `go` scope too, then find the category by its name.
            model.leaveCommand()
            model.query = name
            try require(model.results.first?.target == TargetRef(kind: "search-command", identifier: id),
                        "category name must discover its command")
            model.query = ""
            app.preferences.commandKeywords[id] = "custom" + trigger
            try require(app.commandKeywordProblem("custom" + trigger, id: "ai") != nil,
                        "custom category token must participate in conflict checks")
            model.query = "custom" + trigger + " report"
            try require(model.filter == category && model.inputText == "report", "custom trigger must enter category")
            model.setFilter(.all, query: "")
            model.inputText = trigger + " report"
            try require(model.filter == .all, "customized category must stop consuming its default token")
            app.preferences.commandKeywords.removeValue(forKey: id)
        }
        model.setFilter(.all, query: "")
        model.inputText = "file "
        try await Task.sleep(for: .milliseconds(150))
        guard let field = editableField(in: panel.contentView!),
              let editor = field.currentEditor() as? NSTextView else {
            throw NSError(domain: "CategorySearch", code: 5)
        }
        // Exercise the native text-change delegate, including immediate removal of the token.
        model.leaveCommand()
        try await Task.sleep(for: .milliseconds(100))
        field.stringValue = "file report"
        field.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: field))
        try require(model.filter == .files && model.inputText == "report" && editor.string == "report",
                    "native edit must consume the prefix and synchronize the field editor")
        model.inputText = ""
        try await Task.sleep(for: .milliseconds(100))
        // Dispatch a real key event: calling the delegate directly can see an unrelated
        // NSApp.currentEvent (for example a mouse event from the screenshot capture).
        let backspace = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                        windowNumber: panel.windowNumber, context: nil, characters: "\u{7F}",
                                        charactersIgnoringModifiers: "\u{7F}", isARepeat: false, keyCode: 51)!
        panel.sendEvent(backspace)
        try await Task.sleep(for: .milliseconds(100))
        try require(model.filter == .all && editor.string.isEmpty,
                    "native empty Backspace must leave category mode")
        print("\(appearance.rawValue): category limits, scrolling, stale queries, command discovery, custom tokens, Space/Return/Escape/Backspace and native editor passed")
    }
}
