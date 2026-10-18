import AppKit
import ApplicationServices

/// Observes only Escape and mouse release for the lifetime of one native drag.
/// AppKit consumes these events inside its tracking loop; ordinary NSEvent monitors miss them.
@MainActor
public final class ClipboardDragGesture {
    private let observer: Observer?

    public init() { observer = AXIsProcessTrusted() ? Observer.start() : nil }

    /// Returns the physical release point in AppKit coordinates; cancellation/unavailable observation returns nil.
    public func finish() -> CGPoint? {
        guard let observer else { return nil }
        observer.stop()
        let result = observer.state.result()
        guard !result.cancelled, let point = result.point, let screen = NSScreen.screens.first else { return nil }
        return CGPoint(x: point.x, y: screen.frame.maxY - point.y)
    }

    isolated deinit { observer?.stop() }

    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false
        private var point: CGPoint?

        func consume(_ type: CGEventType, event: CGEvent) {
            lock.lock()
            defer { lock.unlock() }
            if type == .keyDown, event.getIntegerValueField(.keyboardEventKeycode) == 53 { cancelled = true }
            if type == .leftMouseUp, point == nil { point = event.location }
        }

        func result() -> (cancelled: Bool, point: CGPoint?) {
            lock.lock()
            defer { lock.unlock() }
            return (cancelled, point)
        }
    }

    private final class Observer: @unchecked Sendable {
        let state: State
        private let port: CFMachPort
        private let source: CFRunLoopSource
        private let lock = NSLock()
        private var loop: CFRunLoop?
        private var stopped = false

        private init(state: State, port: CFMachPort, source: CFRunLoopSource) {
            self.state = state
            self.port = port
            self.source = source
        }

        static func start() -> Observer? {
            let state = State()
            let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.leftMouseUp.rawValue)
            guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, context in
                    if let context {
                        Unmanaged<State>.fromOpaque(context).takeUnretainedValue().consume(type, event: event)
                    }
                    return Unmanaged.passUnretained(event)
                }, userInfo: Unmanaged.passUnretained(state).toOpaque()),
                let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else { return nil }
            let observer = Observer(state: state, port: port, source: source)
            let thread = Thread { observer.run() }
            thread.name = "Asky clipboard drag release"
            thread.start()
            return observer
        }

        private func run() {
            let current = CFRunLoopGetCurrent()!
            lock.lock()
            if stopped { lock.unlock(); return }
            loop = current
            CFRunLoopAddSource(current, source, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
            lock.unlock()
            CFRunLoopRun()
            CFRunLoopRemoveSource(current, source, .commonModes)
        }

        func stop() {
            lock.lock()
            if stopped { lock.unlock(); return }
            stopped = true
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
            if let loop { CFRunLoopStop(loop); CFRunLoopWakeUp(loop) }
            lock.unlock()
        }
    }
}
