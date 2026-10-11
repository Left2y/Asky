import AppKit

@main
@MainActor
enum ApplicationTerminationRegression {
    final class Delegate: NSObject, NSApplicationDelegate {
        let termination = ApplicationTermination()
        var cleanups = 0
        var cleanedUp = false
        var requests = 0
        let legacy = CommandLine.arguments.contains("--legacy")

        func applicationDidFinishLaunching(_ notification: Notification) {
            // This is how AboutSettings.install calls terminate after awaiting staging.
            Task { @MainActor in NSApp.terminate(nil) }
        }

        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
            requests += 1
            if legacy {
                Task { @MainActor in
                    cleanedUp = true
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
                return .terminateLater
            }
            return termination.request { [self] in
                cleanups += 1
                // A second Quit while cleanup is suspended must not exit prematurely.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(20))
                    NSApp.terminate(nil)
                }
                try? await Task.sleep(for: .milliseconds(100))
                cleanedUp = true
            }
        }

        func applicationWillTerminate(_ notification: Notification) {
            precondition(cleanedUp && cleanups == 1 && requests == 3,
                         "Quit bypassed cleanup, duplicated cleanup, or failed to retry")
            print("Application termination native regression passed")
            fflush(stdout)
        }
    }

    static func main() {
        let app = NSApplication.shared
        let delegate = Delegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
