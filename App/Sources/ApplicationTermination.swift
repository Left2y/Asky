import AppKit

/// Keeps asynchronous cleanup outside AppKit's terminateLater nested event loop.
@MainActor
final class ApplicationTermination {
    private enum State { case running, cleaningUp, ready }
    private var state = State.running

    func request(shutdown: @escaping @MainActor () async -> Void) -> NSApplication.TerminateReply {
        switch state {
        case .ready: return .terminateNow
        case .cleaningUp: return .terminateCancel
        case .running:
            state = .cleaningUp
            Task { @MainActor in
                await shutdown()
                state = .ready
                NSApp.terminate(nil)
            }
            // Returning lets the calling Swift task finish and the main executor run cleanup.
            // A repeated Quit must not bypass that cleanup.
            return .terminateCancel
        }
    }
}
