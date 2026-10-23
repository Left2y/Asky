import AppKit

@main
@MainActor
enum OutsideClickDismissalRegression {
    final class Counter: NSObject {
        var clicks = 0
        @objc func click(_ sender: Any?) { clicks += 1 }
    }

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--background" {
            runBackground(log: URL(fileURLWithPath: CommandLine.arguments[2]))
            app.run()
            return
        }
        Task { @MainActor in
            do {
                try await check()
                print("Outside-click dismissal native regression passed")
                exit(0)
            } catch {
                fputs("Outside-click dismissal failed: \(error)\n", stderr)
                exit(1)
            }
        }
        app.run()
    }

    /// A separate process proves the global monitor path, without sharing AppKit dispatch.
    static func runBackground(log: URL) {
        let window = NSWindow(contentRect: NSRect(x: 150, y: 200, width: 480, height: 240),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Asky background input regression"
        window.isReleasedWhenClosed = false
        var events: [String] = []
        _ = NSEvent.addLocalMonitorForEvents(matching: [
            .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .rightMouseUp, .scrollWheel
        ]) { event in
            MainActor.assumeIsolated {
                events.append(String(event.type.rawValue))
                try? events.joined(separator: "\n").write(to: log, atomically: true, encoding: .utf8)
            }
            return event
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "OutsideClickDismissal", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func click(_ point: NSPoint, button: CGMouseButton = .left, drag: Bool = false) async throws {
        guard let screen = NSScreen.screens.first else { throw NSError(domain: "NoScreen", code: 1) }
        let location = CGPoint(x: point.x, y: screen.frame.maxY - point.y)
        let down: CGEventType = button == .right ? .rightMouseDown : .leftMouseDown
        let up: CGEventType = button == .right ? .rightMouseUp : .leftMouseUp
        CGEvent(mouseEventSource: nil, mouseType: down, mouseCursorPosition: location, mouseButton: button)?.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(150))
        if drag {
            CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: location, mouseButton: button)?.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(100))
        }
        CGEvent(mouseEventSource: nil, mouseType: up, mouseCursorPosition: location, mouseButton: button)?.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(200))
    }

    static func check() async throws {
        let counter = Counter()
        let background = NSWindow(contentRect: NSRect(x: 150, y: 200, width: 480, height: 240),
                                  styleMask: [.titled], backing: .buffered, defer: false)
        background.title = "Asky outside click regression"
        let button = NSButton(title: "Background action", target: counter, action: #selector(Counter.click(_:)))
        button.frame = NSRect(x: 24, y: 80, width: 170, height: 48)
        background.contentView?.addSubview(button)
        background.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let point = background.convertPoint(toScreen: NSPoint(x: 100, y: 104))
        let popup = NSPanel(contentRect: NSRect(x: 400, y: 380, width: 280, height: 120),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        popup.level = .floating
        popup.backgroundColor = .windowBackgroundColor
        let dismissal = OutsideClickDismissal()
        var dismissals = 0
        defer { dismissal.hide(); popup.orderOut(nil); background.orderOut(nil) }
        func show() {
            popup.orderFrontRegardless()
            dismissal.show(contains: { popup.frame.contains($0) }, dismiss: {
                dismissals += 1
                dismissal.hide()
                popup.orderOut(nil)
            })
        }
        try await Task.sleep(for: .milliseconds(300))
        // First prove system input reaches the underlying real AppKit button.
        try await click(point)
        try require(counter.clicks == 1, "Input permission/baseline button click failed")
        show()
        try await Task.sleep(for: .milliseconds(200))
        try await click(NSPoint(x: popup.frame.midX, y: popup.frame.midY))
        try require(popup.isVisible && dismissals == 0, "Internal click dismissed popup")
        try await click(point, drag: true)
        try require(!popup.isVisible && dismissals == 1, "Outside press did not dismiss")
        try require(counter.clicks == 2, "Outside click/drag did not reach background button")
        try await click(point)
        try require(counter.clicks == 3, "Next click was blocked")
        show()
        try await Task.sleep(for: .milliseconds(200))
        try await click(point, button: .right)
        try require(!popup.isVisible && dismissals == 2, "Right click did not dismiss")
        show()
        dismissal.hide() // Fixed/pinned mode stops dismissal observation.
        try await click(point)
        try require(popup.isVisible && counter.clicks == 4, "Pinned popup blocked background")
        dismissal.hide()
        popup.orderOut(nil)
        background.orderOut(nil)

        let log = FileManager.default.temporaryDirectory.appendingPathComponent("asky-input-\(UUID().uuidString).txt")
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        helper.arguments = ["--background", log.path]
        try helper.run()
        defer {
            helper.terminate()
            helper.waitUntilExit()
            try? FileManager.default.removeItem(at: log)
        }
        try await Task.sleep(for: .milliseconds(700))
        func received(_ type: NSEvent.EventType) -> Bool {
            let contents = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
            return contents.split(separator: "\n").contains(Substring(String(type.rawValue)))
        }
        show()
        try await Task.sleep(for: .milliseconds(200))
        // Scrolling the background remains possible and does not dismiss a panel.
        let screen = NSScreen.screens[0]
        CGWarpMouseCursorPosition(CGPoint(x: point.x, y: screen.frame.maxY - point.y))
        CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                wheel1: 30, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(200))
        try require(received(.scrollWheel) && popup.isVisible, "Background scroll blocked or dismissed popup")
        try await click(point, drag: true)
        try require(!popup.isVisible && dismissals == 3, "Cross-app click did not dismiss")
        try require(received(.leftMouseDown) && received(.leftMouseDragged) && received(.leftMouseUp),
                    "Cross-app press/drag/release did not reach background")
        show()
        try await Task.sleep(for: .milliseconds(200))
        try await click(point, button: .right)
        try require(!popup.isVisible && dismissals == 4, "Cross-app right click did not dismiss")
        try require(received(.rightMouseDown) && received(.rightMouseUp), "Cross-app right click was swallowed")
        show()
        dismissal.hide()
        try await click(point)
        try require(popup.isVisible && dismissals == 4, "Removed global observer still dismissed popup")
    }
}
