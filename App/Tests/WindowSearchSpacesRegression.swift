import AppKit
import ToolService

@main @MainActor
private enum WindowSearchSpacesRegression {
    static var windows: [NSWindow] = []
    static var observers: [NSObjectProtocol] = []

    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: message, code: 1) }
    }

    static func main() {
        let application = NSApplication.shared
        let fixture = CommandLine.arguments.contains("--fixture")
        let root = fixture ? URL(fileURLWithPath: CommandLine.arguments[1])
            : FileManager.default.temporaryDirectory.appendingPathComponent("Asky-spaces-\(UUID())")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if fixture {
            application.setActivationPolicy(.regular)
            for index in 0..<2 {
                let window = NSWindow(contentRect: NSRect(x: 160 + index * 60, y: 160, width: 400, height: 240),
                                      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                window.title = "Asky Spaces Fixture"
                window.collectionBehavior = [.fullScreenPrimary]
                window.isReleasedWhenClosed = false
                windows.append(window)
                observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { _ in
                    try? String(index).write(to: root.appendingPathComponent("focused"), atomically: true, encoding: .utf8)
                })
                window.makeKeyAndOrderFront(nil)
            }
        } else {
            application.setActivationPolicy(.accessory)
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
                    try await Task.sleep(for: .seconds(2))
                    let initial = try await ToolService.launcherWindows()
                    let rows = LauncherWindowSnapshot.results(from: initial.entries, query: "Asky Spaces Fixture")
                    try require(rows.count == 2, "initial-two-windows")
                    var focused: [String] = []
                    for row in rows {
                        try await ToolService.activateLauncherWindow(row.target.identifier, in: initial)
                        try await Task.sleep(for: .milliseconds(500))
                        focused.append(try String(contentsOf: root.appendingPathComponent("focused"), encoding: .utf8))
                    }
                    try require(Set(focused).count == 2, "distinct-window-identities")
                    try await ToolService.setLauncherWindowFullScreen(true, for: rows[1].target.identifier, in: initial)
                    try await Task.sleep(for: .seconds(2))
                    for _ in 0..<3 {
                        let refreshed = try await ToolService.launcherWindows()
                        let visible = LauncherWindowSnapshot.results(from: refreshed.entries, query: "Asky Spaces Fixture")
                        try require(visible.count == 2, "fullscreen-refresh-must-keep-other-space-window")
                        let states = try visible.map { try ToolService.launcherWindowFullScreenState($0.target.identifier, in: refreshed) }
                        try require(states.filter { $0 }.count == 1, "one-fullscreen-one-windowed")
                    }
                    try await ToolService.activateLauncherWindow(rows[0].target.identifier, in: initial)
                    try await Task.sleep(for: .seconds(1))
                    try require(try String(contentsOf: root.appendingPathComponent("focused"), encoding: .utf8) == focused[0],
                                "activate-exact-other-space-window")
                    try await ToolService.activateLauncherWindow(rows[1].target.identifier, in: initial)
                    try await Task.sleep(for: .seconds(1))
                    try ToolService.closeLauncherWindow(rows[0].target.identifier, in: initial)
                    try await Task.sleep(for: .milliseconds(600))
                    let afterClose = try await ToolService.launcherWindows()
                    try require(LauncherWindowSnapshot.results(from: afterClose.entries, query: "Asky Spaces Fixture").count == 1,
                                "closed-remembered-window-must-disappear")
                    do {
                        try await ToolService.activateLauncherWindow(rows[0].target.identifier, in: initial)
                        throw NSError(domain: "closed-reference-activated", code: 2)
                    } catch WindowSearchError.unavailable {}
                    do {
                        try ToolService.closeLauncherWindow(rows[0].target.identifier, in: initial)
                        throw NSError(domain: "closed-reference-closed", code: 3)
                    } catch WindowSearchError.unavailable {}
                    try await ToolService.setLauncherWindowFullScreen(false, for: rows[1].target.identifier, in: initial)
                    try await Task.sleep(for: .seconds(2))
                    try ToolService.closeLauncherWindow(rows[1].target.identifier, in: initial)
                    try await Task.sleep(for: .milliseconds(600))
                    let empty = try await ToolService.launcherWindows()
                    try require(LauncherWindowSnapshot.results(from: empty.entries, query: "Asky Spaces Fixture").isEmpty,
                                "all-closed-must-clear-catalog")
                    child.terminate(); child.waitUntilExit()
                    let terminated = try await ToolService.launcherWindows()
                    try require(LauncherWindowSnapshot.results(from: terminated.entries, query: "Asky Spaces Fixture").isEmpty,
                                "terminated-app-must-clear-catalog")
                    print("PASS: full-screen refresh retains both same-title windows across Spaces; exact switching and close work")
                    print("PASS: closed references rejected, catalog prunes closed windows and terminated apps")
                } catch {
                    fputs("FAIL Spaces: \(error)\n", stderr)
                    if child.isRunning { child.terminate(); child.waitUntilExit() }
                    exit(1)
                }
                exit(0)
            }
        }
        application.run()
    }
}
