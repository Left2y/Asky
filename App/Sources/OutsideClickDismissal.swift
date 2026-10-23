import AppKit

/// Observes outside presses without placing windows over the user's other apps.
/// Local events are forwarded unchanged; global observation never consumes input.
@MainActor
final class OutsideClickDismissal {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var dismiss: () -> Void = {}
    private var contains: (NSPoint) -> Bool = { _ in false }

    func show(contains: @escaping (NSPoint) -> Bool,
              dismiss: @escaping () -> Void) {
        hide()
        self.contains = contains
        self.dismiss = dismiss
        let presses: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: presses) { [weak self] event in
            MainActor.assumeIsolated { self?.observe(event) }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: presses) { [weak self] event in
            MainActor.assumeIsolated { self?.observe(event) }
        }
    }

    func hide() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        dismiss = {}
        contains = { _ in false }
    }

    private func observe(_ event: NSEvent) {
        let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
        guard !contains(point) else { return }
        dismiss()
    }
}
