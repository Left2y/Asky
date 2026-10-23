import AppKit
import QuartzCore

/// Opt-in Debug tracing only; never writes user queries or window titles.
@MainActor
enum LauncherPresentationTrace {
    static var isEnabled: Bool {
        #if DEBUG
        CommandLine.arguments.contains("--diagnose-launcher")
        #else
        false
        #endif
    }

    #if DEBUG
    private static var observer: LauncherPresentationObserver?
    #endif

    static func start() {
        #if DEBUG
        guard isEnabled, observer == nil else { return }
        let observer = LauncherPresentationObserver()
        self.observer = observer
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didExposeNotification, NSWindow.willCloseNotification] {
            NotificationCenter.default.addObserver(observer,
                selector: #selector(LauncherPresentationObserver.windowChanged(_:)), name: name, object: nil)
        }
        #endif
    }

    static func record(_ event: String, panel: NSWindow? = nil) {
        #if DEBUG
        guard isEnabled else { return }
        let frame = panel.map { NSStringFromRect($0.frame) } ?? "none"
        NSLog("launcher-presentation t=%.6f event=%@ window=%d visible=%d key=%d frame=%@ windows=%@",
              CACurrentMediaTime(), event, panel?.windowNumber ?? -1,
              panel?.isVisible == true ? 1 : 0, panel?.isKeyWindow == true ? 1 : 0, frame,
              NSApp.windows.map { "\(type(of: $0)):\($0.windowNumber):\($0.isVisible):\(NSStringFromRect($0.frame))" }.joined(separator: ","))
        #endif
    }
}

#if DEBUG
@MainActor
private final class LauncherPresentationObserver: NSObject {
    @objc func windowChanged(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        LauncherPresentationTrace.record("notification-\(notification.name.rawValue)", panel: window)
    }
}
#endif
