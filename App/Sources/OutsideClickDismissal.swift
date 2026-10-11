import AppKit

/// Owns the closing click instead of observing a click already delivered to another app.
/// Non-activating windows keep the foreground application and keyboard switching intact.
@MainActor
final class OutsideClickDismissal {
    private var shields: [DismissalShield] = []
    private var monitor: Any?
    private var pressedButtons: Set<Int> = []
    private var dismiss: () -> Void = {}
    private var contains: (NSPoint) -> Bool = { _ in false }

    func show(below panel: NSWindow, contains: @escaping (NSPoint) -> Bool,
              dismiss: @escaping () -> Void) {
        hide()
        self.contains = contains
        self.dismiss = dismiss
        for screen in NSScreen.screens {
            let shield = DismissalShield(contentRect: screen.frame,
                                        styleMask: [.borderless, .nonactivatingPanel],
                                        backing: .buffered, defer: false)
            shield.isOpaque = false
            // A nonzero alpha makes the transparent surface receive WindowServer hits.
            shield.backgroundColor = NSColor.black.withAlphaComponent(0.001)
            shield.hasShadow = false
            shield.hidesOnDeactivate = false
            shield.isReleasedWhenClosed = false
            shield.level = panel.level
            shield.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            shield.order(.below, relativeTo: panel.windowNumber)
            shields.append(shield)
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .leftMouseUp, .rightMouseUp, .otherMouseUp,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]) { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.filter(event) == nil && self != nil }
            return consumed ? nil : event
        }
    }

    func hide() {
        // Keep receiving the release/drag belonging to the closing press.
        guard pressedButtons.isEmpty else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        shields.forEach { $0.orderOut(nil) }
        shields.removeAll()
        dismiss = {}
        contains = { _ in false }
    }

    private func filter(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
            guard !shields.isEmpty, !contains(point) else { return event }
            pressedButtons.insert(event.buttonNumber)
            dismiss()
            return nil
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            guard pressedButtons.remove(event.buttonNumber) != nil else { return event }
            hide()
            return nil
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            return pressedButtons.contains(event.buttonNumber) ? nil : event
        default:
            return event
        }
    }
}

private final class DismissalShield: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
