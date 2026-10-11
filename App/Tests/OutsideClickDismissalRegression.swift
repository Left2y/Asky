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
            dismissal.show(below: popup, contains: { popup.frame.contains($0) }, dismiss: {
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
        try require(counter.clicks == 1, "Closing click or release activated background button")
        try await click(point)
        try require(counter.clicks == 2, "Next click blocked by a leftover shield")
        show()
        try await Task.sleep(for: .milliseconds(200))
        try await click(point, button: .right)
        try require(!popup.isVisible && dismissals == 2, "Right click did not dismiss")
        show()
        dismissal.hide() // Fixed/pinned mode removes outside interception.
        try await click(point)
        try require(popup.isVisible && counter.clicks == 3, "Pinned popup blocked background")
        dismissal.hide()
    }
}
