import AppKit
import Contracts
import Search
import ToolService

private struct FolderFixtureProvider: SearchProvider {
    let source = SearchSource.file
    let folder: URL
    func search(_ query: String, limit: Int) async -> [SearchResult] {
        [SearchResult(source: .file, target: TargetRef(kind: "file", identifier: folder.path),
                      title: folder.lastPathComponent, actions: [.open, .revealInFinder])]
    }
}

@main @MainActor
private enum LauncherFolderRegression {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                    application.appearance = NSAppearance(named: appearance)
                    try await check(appearance)
                }
                print("Launcher folder regression passed")
                exit(0)
            } catch {
                fputs("Folder regression failed: \(error)\n", stderr)
                exit(1)
            }
        }
        application.run()
    }

    private static func require(_ value: Bool, _ message: String) throws {
        if !value { throw NSError(domain: "FolderRegression", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    private static func check(_ appearance: NSAppearance.Name) async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "Asky-folder-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appending(path: "Design Assets")
        let nested = folder.appending(path: "Icons")
        let excluded = folder.appending(path: "Excluded")
        for url in [nested, excluded, folder.appending(path: "Example.app")] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        for name in ["Brief.md", "bm literal.txt", ".hidden"] {
            try Data(name.utf8).write(to: folder.appending(path: name))
        }
        try Data().write(to: nested.appending(path: "Logo.svg"))
        try require(ToolService.launcherFolder(at: folder.path) != nil, "directory must be enterable")
        try require(ToolService.launcherFolder(at: folder.appending(path: "Example.app").path) == nil, "app packages cannot be entered")
        let indexed = try await ToolService.searchLauncherFolder(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "App"), query: "LauncherModel.swift", excluded: [])
        try require(indexed.contains { $0.title == "LauncherModel.swift" }, "Spotlight must find an indexed nested file")
        let rows = try await ToolService.searchLauncherFolder(folder, query: "", excluded: [excluded.path])
        try require(!rows.contains { ["Excluded", ".hidden", "Logo.svg"].contains($0.title) }, "listing must respect exclusions, hidden files and depth")
        let app = try AppModel(root: root.appending(path: "store"))
        let model = LauncherModel(app: app, searchProviders: [FolderFixtureProvider(folder: folder)])
        let controller = LauncherController(model: model)
        controller.show()
        defer { controller.hide() }
        guard let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }) as? LauncherPanel else {
            throw NSError(domain: "FolderRegression", code: 2)
        }
        panel.onBlur = {}
        model.query = "Design"
        for _ in 0..<30 {
            if model.results.contains(where: { $0.source == .file }) { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        guard let folderIndex = model.results.firstIndex(where: { $0.source == .file }) else {
            throw NSError(domain: "FolderRegression", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing fixture row: \(model.results.map(\.title)) query=\(model.inputText)"])
        }
        model.selection = folderIndex
        try require(model.canEnterSelectedFolder, "folder selection must expose Tab action: \(model.results[folderIndex].target.identifier)")
        guard let editor = panel.firstResponder as? NSTextView else { throw NSError(domain: "FolderRegression", code: 3) }
        panel.sendEvent(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil, characters: "\t", charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48)!)
        try await Task.sleep(for: .milliseconds(400))
        try require(model.folderScope?.path == folder.path && model.inputText.isEmpty && editor.string.isEmpty,
                    "Tab scope=\(String(describing: model.folderScope)) expected=\(folder) query=\(model.inputText) editor=\(editor.string)")
        try require(model.results.contains { $0.title == "Brief.md" } && model.results.allSatisfy { $0.source == .file },
                    "empty folder search must show only contained files")
        try require(panel.firstResponder === editor, "Tab must preserve field editor focus")
        let capture = Process()
        capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-l", String(panel.windowNumber), "build/folder-\(appearance.rawValue).png"]
        try capture.run()
        capture.waitUntilExit()
        try require(capture.terminationStatus == 0, "folder screenshot must succeed")
        model.inputText = "b"
        try await Task.sleep(for: .milliseconds(750))
        try require(model.results.contains { $0.title == "Brief.md" }, "one-character queries must match")
        model.inputText = "bm literal"
        try await Task.sleep(for: .milliseconds(750))
        try require(model.folderScope?.path == folder.path && !model.isBookmarkScope && model.results.count == 1,
                    "command-like text must stay a literal filename search")
        try require(!model.enterSelectedFolder(), "ordinary file Tab must fall through")
        model.inputText = ""
        try await Task.sleep(for: .milliseconds(150))
        model.selection = model.results.firstIndex { $0.title == "Icons" }!
        panel.sendEvent(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil, characters: "\t", charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48)!)
        try await Task.sleep(for: .milliseconds(250))
        try require(model.folderScope?.path == nested.path && model.results.map(\.title) == ["Logo.svg"], "nested Tab must browse selected subfolder")
        panel.onEscape()
        try await Task.sleep(for: .milliseconds(200))
        try require(model.folderScope?.path == folder.path && panel.isVisible, "Escape must return one folder level")
        model.inputText = "absent-unique-name"
        try await Task.sleep(for: .milliseconds(750))
        try require(model.results.isEmpty && !model.isSearching && model.status != nil, "empty search must finish with explicit state")
        model.inputText = "Brief"
        panel.onEscape()
        try await Task.sleep(for: .milliseconds(750))
        try require(model.folderScope == nil && model.inputText == "Design" && model.results.first?.title == "Design Assets",
                    "leaving during a query must restore original search and discard stale results")
        try require(model.toggleActionsMenu(), "folder actions menu must open")
        guard let folderAction = model.secondaryActions.firstIndex(where: { if case .enterFolder = $0.kind { return true }; return false }) else {
            throw NSError(domain: "FolderRegression", code: 5)
        }
        model.actionSelection = folderAction
        try await Task.sleep(for: .milliseconds(300))
        if let menu = NSApp.windows.first(where: { $0.isVisible && $0.frame.width == LauncherLayout.actionsMenuWidth }) {
            let capture = Process()
            capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-l", String(menu.windowNumber), "build/folder-more-\(appearance.rawValue).png"]
            try capture.run()
            capture.waitUntilExit()
            try require(capture.terminationStatus == 0, "folder menu screenshot must succeed")
        }
        model.performHighlightedAction()
        try await Task.sleep(for: .milliseconds(250))
        try require(model.folderScope?.path == folder.path && !model.isActionsMenuPresented,
                    "Search Folder in More must close the menu and enter the folder")
        panel.sendEvent(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil, characters: "\u{7f}", charactersIgnoringModifiers: "\u{7f}", isARepeat: false, keyCode: 51)!)
        try await Task.sleep(for: .milliseconds(250))
        try require(model.folderScope == nil && model.inputText == "Design", "empty input Backspace must leave scope")
        try FileManager.default.removeItem(at: folder)
        try require(!model.enterSelectedFolder(), "deleted folder cannot be entered")
        model.reset()
        try require(model.folderScope == nil && model.inputText.isEmpty, "panel reset clears folder state")
        print("\(appearance.rawValue): Tab, literal names, nesting, Escape, Backspace, stale results, packages, exclusions passed")
    }
}
