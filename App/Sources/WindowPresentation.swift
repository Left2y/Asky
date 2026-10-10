import AppKit

/// Foreground requests are one-shot. Ordinary windows never acquire a floating level.
@MainActor
final class WindowPresentation: NSObject {
    private weak var pendingWindow: NSWindow?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive),
                                               name: NSApplication.didBecomeActiveNotification, object: NSApp)
        NotificationCenter.default.addObserver(self, selector: #selector(cancelPending),
                                               name: NSApplication.didResignActiveNotification, object: NSApp)
        for name in [NSWindow.willCloseNotification, NSWindow.willMiniaturizeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(windowDismissed(_:)),
                                                   name: name, object: nil)
        }
    }

    func show(_ window: NSWindow) {
        window.level = .normal
        window.hidesOnDeactivate = false
        if window.isMiniaturized { window.deminiaturize(nil) }
        pendingWindow = window
        // Accessory-app activation is asynchronous. Order once within the normal
        // level so the window is visible, then finalize key focus on activation.
        window.orderFrontRegardless()
        NSApp.activate()
        if NSApp.isActive { didBecomeActive() }
    }

    func yieldToAuthentication() {
        // A late activation notification must not take key focus from the
        // system password dialog once credential interaction has begun.
        pendingWindow = nil
    }

    @objc private func didBecomeActive() {
        let window = pendingWindow
        pendingWindow = nil
        guard let window, window.isVisible, !window.isMiniaturized else { return }
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func cancelPending() { pendingWindow = nil }

    @objc private func windowDismissed(_ notification: Notification) {
        if notification.object as? NSWindow === pendingWindow { pendingWindow = nil }
    }
}

/// Handle settings before a non-activating panel forwards keys to its field editor.
enum SettingsShortcut {
    static func matches(_ event: NSEvent) -> Bool {
        event.type == .keyDown
            && event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command
            && event.charactersIgnoringModifiers == ","
    }
}
