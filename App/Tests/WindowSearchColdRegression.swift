import AppKit
import CoreGraphics
import ToolService

extension ToolService {
    @MainActor fileprivate static func coldFixtureVisibility(_ ids: [Int]) -> [Bool] {
        let rows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        return ids.map { id in
            rows.first { ($0[kCGWindowNumber as String] as? Int) == id }?[kCGWindowIsOnscreen as String] as? Bool ?? false
        }
    }
}

@MainActor private final class ColdFixtureControl: NSObject {
    let root: URL
    init(root: URL) { self.root = root }
    @objc func clicked(_ sender: Any?) {
        try? "clicked".write(to: root.appendingPathComponent("clicked"), atomically: true, encoding: .utf8)
    }
}

/// The scanner process never sees the fixture before two windows have entered fullscreen.
@main @MainActor
private enum WindowSearchColdRegression {
    static var windows: [NSWindow] = []
    static var observers: [NSObjectProtocol] = []
    static var controls: [ColdFixtureControl] = []
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: message, code: 1) }
    }
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let fixture = CommandLine.arguments.contains("--fixture")
        let root = fixture ? URL(fileURLWithPath: CommandLine.arguments[1])
            : FileManager.default.temporaryDirectory.appendingPathComponent("Asky-cold-windows-\(UUID())")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if fixture {
            for index in 0..<3 {
                let window = NSWindow(contentRect: NSRect(x: 150 + 30 * index, y: 120, width: 400, height: 260),
                                      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                window.title = "Asky Cold Spaces Fixture"
                window.collectionBehavior = [.fullScreenPrimary]
                window.isReleasedWhenClosed = false
                windows.append(window)
                let control = ColdFixtureControl(root: root)
                controls.append(control)
                let button = NSButton(title: "Test control", target: control, action: #selector(ColdFixtureControl.clicked(_:)))
                button.frame = window.contentView!.bounds
                button.autoresizingMask = [.width, .height]
                window.contentView!.addSubview(button)
                window.makeKeyAndOrderFront(nil)
                observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: window, queue: .main) { _ in
                    MainActor.assumeIsolated {
                        if index == 1 {
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(1))
                                windows[2].toggleFullScreen(nil)
                            }
                        } else if index == 2 {
                            let ids = windows.map { String($0.windowNumber) }.joined(separator: ",")
                            try? ids.write(to: root.appendingPathComponent("ready"), atomically: true, encoding: .utf8)
                        }
                    }
                })
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                windows[1].toggleFullScreen(nil)
            }
        } else {
            let anchor = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 300, height: 160),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            anchor.title = "Asky Cold Scanner"
            anchor.makeKeyAndOrderFront(nil)
            windows.append(anchor)
            Task { @MainActor in
                let child = Process()
                child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
                child.arguments = [root.path, "--fixture"]
                defer {
                    if child.isRunning { child.terminate(); child.waitUntilExit() }
                    try? FileManager.default.removeItem(at: root)
                }
                do {
                    try child.run()
                    for _ in 0..<150 {
                        if FileManager.default.fileExists(atPath: root.appendingPathComponent("ready").path) { break }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    let ids = try String(contentsOf: root.appendingPathComponent("ready"), encoding: .utf8)
                        .split(separator: ",").compactMap { Int($0) }
                    try require(ids.count == 3, "fixture-must-have-three-windows")
                    NSApp.activate(ignoringOtherApps: true)
                    anchor.makeKeyAndOrderFront(nil)
                    try await Task.sleep(for: .seconds(2))
                    try require(ToolService.coldFixtureVisibility(Array(ids.dropFirst())) == [false, false],
                                "both-fullscreen-windows-must-be-offscreen-before-first-search")
                    let start = ContinuousClock.now
                    // First ever catalog request in this scanner process: no warm-up or retained references.
                    let snapshot = try await ToolService.launcherWindows()
                    let rows = LauncherWindowSnapshot.results(from: snapshot.entries, query: "Asky Cold Spaces Fixture")
                    try require(rows.count == 3, "cold-search-must-find-both-inactive-fullscreen-windows-count-\(rows.count)")
                    try require(ToolService.coldFixtureVisibility(Array(ids.dropFirst())) == [false, false],
                                "discovery-must-not-switch-spaces")
                    print("PASS: cold catalog found", rows.count)
                    let states = try rows.map { try ToolService.launcherWindowFullScreenState($0.target.identifier, in: snapshot) }
                    try require(states.filter { $0 }.count == 2, "two-fullscreen-and-one-windowed")
                    print("PASS: first search discovers three same-title windows, including two already fullscreen on inactive Spaces (\(start.duration(to: .now)))")
                    let target = rows[states.lastIndex(of: true)!].target.identifier
                    try await ToolService.activateLauncherWindow(target, in: snapshot)
                    try await Task.sleep(for: .seconds(2))
                    try require(!FileManager.default.fileExists(atPath: root.appendingPathComponent("clicked").path),
                                "key-focus-must-not-click-window-controls")
                    try require(ToolService.coldFixtureVisibility(Array(ids.dropFirst())).filter { $0 }.count == 1,
                                "activate-must-reveal-one-exact-fullscreen-window")
                    try await ToolService.setLauncherWindowFullScreen(false, for: target, in: snapshot)
                    try await Task.sleep(for: .seconds(2))
                    try require(try !ToolService.launcherWindowFullScreenState(target, in: snapshot), "cold-target-exits-fullscreen")
                    try ToolService.closeLauncherWindow(target, in: snapshot)
                    try await Task.sleep(for: .milliseconds(600))
                    let refreshed = try await ToolService.launcherWindows()
                    try require(LauncherWindowSnapshot.results(from: refreshed.entries, query: "Asky Cold Spaces Fixture").count == 2,
                                "cold-target-close-must-not-resurrect")
                    print("PASS: recovered fullscreen target activates, exits fullscreen and closes; sibling stays intact")
                } catch {
                    fputs("FAIL cold windows: \(error)\n", stderr)
                    if child.isRunning { child.terminate(); child.waitUntilExit() }
                    exit(1)
                }
                if child.isRunning { child.terminate(); child.waitUntilExit() }
                try? FileManager.default.removeItem(at: root)
                exit(0)
            }
        }
        app.run()
    }
}
