import AppKit
import ToolService

@main @MainActor enum WindowSearchLiveRegression {
    static var windows: [NSWindow] = []
    static var observers: [NSObjectProtocol] = []
    static func main() {
        let application = NSApplication.shared
        let fixture = CommandLine.arguments.contains("--fixture")
        let root = fixture ? URL(fileURLWithPath: CommandLine.arguments[1])
            : FileManager.default.temporaryDirectory.appendingPathComponent("Asky-live-windows-\(UUID())")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if fixture {
            application.setActivationPolicy(.regular)
            for index in 0..<2 {
                let window = NSWindow(contentRect: NSRect(x: 160 + index * 60, y: 160, width: 320, height: 180),
                                      styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
                window.title = "Asky SW Live Fixture"
                window.isReleasedWhenClosed = false
                windows.append(window)
                observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { _ in
                    try? String(index).write(to: root.appendingPathComponent("focused"), atomically: true, encoding: .utf8)
                })
                window.makeKeyAndOrderFront(nil)
            }
            windows[1].miniaturize(nil)
            _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                MainActor.assumeIsolated {
                    let command = root.appendingPathComponent("close")
                    if let text = try? String(contentsOf: command, encoding: .utf8), let index = Int(text) {
                        windows[index].close()
                        try? FileManager.default.removeItem(at: command)
                    }
                }
            }
        } else {
            application.setActivationPolicy(.accessory)
            Task { @MainActor in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
                process.arguments = [root.path, "--fixture"]
                func cleanUp() {
                    if process.isRunning { process.terminate(); process.waitUntilExit() }
                    try? FileManager.default.removeItem(at: root)
                }
                do {
                    try process.run()
                    try await Task.sleep(for: .seconds(2))
                    let snapshot = try await ToolService.launcherWindows()
                    let rows = LauncherWindowSnapshot.results(from: snapshot.entries, query: "Asky SW Live Fixture")
                    guard rows.count == 2 else { throw NSError(domain: "WindowSearchLiveRegression-count-\(rows.count)", code: 1) }
                    var focused: [String] = []
                    for row in rows {
                        try await ToolService.activateLauncherWindow(row.target.identifier, in: snapshot)
                        try await Task.sleep(for: .milliseconds(500))
                        focused.append(try String(contentsOf: root.appendingPathComponent("focused"), encoding: .utf8))
                    }
                    guard Set(focused).count == 2 else { throw NSError(domain: "WindowSearchLiveRegression-wrong-focus", code: 2) }
                    try focused[0].write(to: root.appendingPathComponent("close"), atomically: true, encoding: .utf8)
                    try await Task.sleep(for: .milliseconds(400))
                    do {
                        try await ToolService.activateLauncherWindow(rows[0].target.identifier, in: snapshot)
                        throw NSError(domain: "WindowSearchLiveRegression-stale-target-accepted", code: 3)
                    } catch WindowSearchError.unavailable {}
                    print("PASS: live same-title windows stay distinct, exact focus switches between both, minimized restoration, closed target rejected")
                    cleanUp()
                    exit(0)
                } catch {
                    fputs("FAIL live windows: \(error)\n", stderr)
                    cleanUp()
                    exit(1)
                }
            }
        }
        application.run()
    }
}
