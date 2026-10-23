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
                                      styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
                window.collectionBehavior = [.fullScreenPrimary]
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
                    let fullScreen = windows.indices.filter { windows[$0].styleMask.contains(.fullScreen) }
                    try? fullScreen.map(String.init).joined(separator: ",").write(to: root.appendingPathComponent("full-screen"), atomically: true, encoding: .utf8)
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
                    print("PASS: exact focus and minimized restoration")
                    let target = rows[1].target.identifier
                    guard try !ToolService.launcherWindowFullScreenState(target, in: snapshot) else {
                        throw NSError(domain: "WindowSearchLiveRegression-initial-fullscreen", code: 6)
                    }
                    print("PASS: read initial full-screen state")
                    try await ToolService.setLauncherWindowFullScreen(true, for: target, in: snapshot)
                    try await Task.sleep(for: .seconds(2))
                    guard try ToolService.launcherWindowFullScreenState(target, in: snapshot),
                          try String(contentsOf: root.appendingPathComponent("full-screen"), encoding: .utf8) == focused[1] else {
                        throw NSError(domain: "WindowSearchLiveRegression-enter-fullscreen", code: 7)
                    }
                    print("PASS: entered full screen on exact target")
                    try await ToolService.setLauncherWindowFullScreen(false, for: target, in: snapshot)
                    try await Task.sleep(for: .seconds(2))
                    guard try !ToolService.launcherWindowFullScreenState(target, in: snapshot) else {
                        throw NSError(domain: "WindowSearchLiveRegression-exit-fullscreen", code: 8)
                    }
                    print("PASS: exited full screen")
                    let app = try AppModel(root: root.appendingPathComponent("app"))
                    let launcher = LauncherModel(app: app, searchProviders: [], chromeBookmarkAccessAllowed: false)
                    launcher.inputText = "sw Asky SW Live Fixture"
                    for _ in 0..<60 {
                        if !launcher.isSearching && launcher.results.count == 2 { break }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    guard launcher.results.count == 2, launcher.toggleActionsMenu(),
                          launcher.secondaryActions.first?.title == "进入全屏",
                          launcher.secondaryActions.first?.shortcut == "⌃⌘ F" else {
                        throw NSError(domain: "WindowSearchLiveRegression-launcher-menu", code: 10)
                    }
                    func key(_ flags: NSEvent.ModifierFlags) -> NSEvent {
                        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                                         windowNumber: 0, context: nil, characters: "f", charactersIgnoringModifiers: "f",
                                         isARepeat: false, keyCode: 3)!
                    }
                    guard launcher.handleActionKey(key([.control, .command])) else {
                        throw NSError(domain: "WindowSearchLiveRegression-default-key", code: 11)
                    }
                    try await Task.sleep(for: .seconds(3))
                    guard try !String(contentsOf: root.appendingPathComponent("full-screen"), encoding: .utf8).isEmpty else {
                        throw NSError(domain: "WindowSearchLiveRegression-key-enter", code: 12)
                    }
                    launcher.inputText = "Asky SW Live Fixture"
                    try await Task.sleep(for: .seconds(1))
                    var foundFullScreen = false
                    for index in launcher.results.indices {
                        launcher.selection = index
                        launcher.toggleActionsMenu()
                        foundFullScreen = launcher.secondaryActions.first?.title == "退出全屏"
                        launcher.closeActionsMenu()
                        if foundFullScreen { break }
                    }
                    guard foundFullScreen,
                          app.preferences.setShortcut(.windowFullScreen, .init(code: 3, modifiers: 6400, label: "⌃⌥⌘ F")),
                          !launcher.handleActionKey(key([.control, .command])),
                          launcher.handleActionKey(key([.control, .option, .command])) else {
                        throw NSError(domain: "WindowSearchLiveRegression-custom-key", code: 13)
                    }
                    try await Task.sleep(for: .seconds(3))
                    guard try String(contentsOf: root.appendingPathComponent("full-screen"), encoding: .utf8).isEmpty else {
                        throw NSError(domain: "WindowSearchLiveRegression-key-exit", code: 14)
                    }
                    launcher.reset()
                    print("PASS: default/custom launcher full-screen shortcuts, menu labels, old binding stops firing")
                    try ToolService.closeLauncherWindow(rows[0].target.identifier, in: snapshot)
                    try await Task.sleep(for: .milliseconds(400))
                    do {
                        try await ToolService.activateLauncherWindow(rows[0].target.identifier, in: snapshot)
                        throw NSError(domain: "WindowSearchLiveRegression-stale-target-accepted", code: 3)
                    } catch WindowSearchError.unavailable {}
                    do {
                        try ToolService.closeLauncherWindow(rows[0].target.identifier, in: snapshot)
                        throw NSError(domain: "WindowSearchLiveRegression-stale-close-accepted", code: 4)
                    } catch WindowSearchError.unavailable {}
                    do {
                        try await ToolService.setLauncherWindowFullScreen(true, for: rows[0].target.identifier, in: snapshot)
                        throw NSError(domain: "WindowSearchLiveRegression-stale-fullscreen-accepted", code: 9)
                    } catch WindowSearchError.unavailable {}
                    print("PASS: exact close, stale close/full-screen rejected, enter/exit full screen on exact same-title window")
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
