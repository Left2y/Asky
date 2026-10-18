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
                let capture = Process()
                capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-l", String(panel.windowNumber), "build/category-search-\(appearance.rawValue).png"]
                try capture.run()
                capture.waitUntilExit()
                try require(capture.terminationStatus == 0, "screenshot must succeed")
            }
        }
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
        print("\(appearance.rawValue): files 8 -> 200 -> 8; apps 85, shortcuts 65, quick links 200; scroll and stale queries passed")
    }
}
