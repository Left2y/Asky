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
                    try? windows.map { $0.screen?.localizedName ?? "unknown" }.joined(separator: "\n")
                        .write(to: root.appendingPathComponent("screens"), atomically: true, encoding: .utf8)
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
                    if ToolService.launcherHasMultipleDisplays {
                        let fixtureIndex = Int(focused[1])!
                        func fixtureScreen() throws -> String {
                            try String(contentsOf: root.appendingPathComponent("screens"), encoding: .utf8)
                                .components(separatedBy: "\n")[fixtureIndex]
                        }
                        let originalScreen = try fixtureScreen()
                        try await ToolService.moveLauncherWindowDisplay(-1, for: target, in: snapshot)
                        try await Task.sleep(for: .milliseconds(400))
                        guard try fixtureScreen() != originalScreen else {
                            throw NSError(domain: "WindowDisplay-previous", code: 20)
                        }
                        try await ToolService.moveLauncherWindowDisplay(1, for: target, in: snapshot)
                        try await Task.sleep(for: .milliseconds(400))
                        guard try fixtureScreen() == originalScreen else {
                            throw NSError(domain: "WindowDisplay-next", code: 21)
                        }
                        print("PASS: real previous/next display moves independently confirmed by target window")
                    }
                    let app = try AppModel(root: root.appendingPathComponent("app"))
                    if ToolService.launcherHasMultipleDisplays {
                        for (action, code) in [(LocalShortcutAction.windowPreviousDisplay, UInt16(123)), (.windowNextDisplay, UInt16(124))] {
                            let mover = LauncherModel(app: app, searchProviders: [], chromeBookmarkAccessAllowed: false)
                            mover.inputText = "sw Asky SW Live Fixture"
                            for _ in 0..<60 {
                                if !mover.isSearching && mover.results.count == 2 { break }
                                try await Task.sleep(for: .milliseconds(100))
                            }
                            guard mover.results.count == 2 else { throw NSError(domain: "WindowDisplay-search", code: 23) }
                            let before = try String(contentsOf: root.appendingPathComponent("screens"), encoding: .utf8)
                            func arrow(_ flags: NSEvent.ModifierFlags) -> NSEvent {
                                NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                                    windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                                    isARepeat: false, keyCode: code)!
                            }
                            var hidden = false
                            mover.onHide = { hidden = true }
                            var flags: NSEvent.ModifierFlags = .shift
                            if action == .windowNextDisplay {
                                guard app.preferences.setShortcut(action, .init(code: UInt32(code), modifiers: 768, label: "⌘⇧ →")),
                                      !mover.handleActionKey(arrow(.shift)) else { throw NSError(domain: "WindowDisplay-custom", code: 24) }
                                flags.insert(.command)
                            }
                            guard mover.handleActionKey(arrow(flags)) else { throw NSError(domain: "WindowDisplay-key", code: 25) }
                            for _ in 0..<40 {
                                if hidden { break }
                                try await Task.sleep(for: .milliseconds(100))
                            }
                            try await Task.sleep(for: .milliseconds(300))
                            let after = try String(contentsOf: root.appendingPathComponent("screens"), encoding: .utf8)
                            guard hidden, before != after else { throw NSError(domain: "WindowDisplay-key-move", code: 26) }
                            mover.reset()
                        }
                        print("PASS: default Shift Left and custom Shift Command Right move real windows; old binding stops firing")
                    }
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
