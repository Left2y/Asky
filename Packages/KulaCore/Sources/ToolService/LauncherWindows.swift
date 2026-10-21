import AppKit
import ApplicationServices
import Contracts

/// A panel-scoped snapshot retains exact AX references, including identically titled windows.
public final class LauncherWindowSnapshot: @unchecked Sendable {
    public struct Entry: Sendable {
        public let id: String
        public let title: String
        public let application: String
        public let applicationPath: String

        public init(id: String, title: String, application: String, applicationPath: String) {
            self.id = id
            self.title = title
            self.application = application
            self.applicationPath = applicationPath
        }
    }
    public let entries: [Entry]
    private let targets: [String: (pid_t, AXUIElement)]

    private init(entries: [Entry], targets: [String: (pid_t, AXUIElement)]) {
        self.entries = entries
        self.targets = targets
    }

    public static func results(from entries: [Entry], query: String) -> [SearchResult] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return entries.filter { entry in
            terms.allSatisfy { entry.title.localizedStandardContains($0) || entry.application.localizedStandardContains($0) }
        }.map { entry in
            SearchResult(source: .app, target: TargetRef(kind: "application-window", identifier: entry.id),
                         title: entry.title.isEmpty ? entry.application : entry.title,
                         subtitle: entry.application, actions: [.switchTo], score: 100)
        }
    }

    fileprivate static func capture() throws -> LauncherWindowSnapshot {
        guard AXIsProcessTrusted() else { throw WindowSearchError.accessibility }
        var entries: [Entry] = []
        var targets: [String: (pid_t, AXUIElement)] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != getpid() {
            if Task.isCancelled { throw CancellationError() }
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.2)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement] else { continue }
            for window in windows {
                AXUIElementSetMessagingTimeout(window, 0.2)
                var role: CFTypeRef?
                guard AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &role) == .success,
                      role as? String == kAXWindowRole else { continue }
                var title: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
                let id = UUID().uuidString
                entries.append(Entry(id: id, title: title as? String ?? "", application: app.localizedName ?? "",
                                     applicationPath: app.bundleURL?.path ?? ""))
                targets[id] = (app.processIdentifier, window)
            }
        }
        return LauncherWindowSnapshot(entries: entries, targets: targets)
    }

    @MainActor fileprivate func activate(_ id: String) async throws {
        guard AXIsProcessTrusted() else { throw WindowSearchError.accessibility }
        guard let (pid, window) = targets[id], let app = NSRunningApplication(processIdentifier: pid) else {
            throw WindowSearchError.unavailable
        }
        // Revalidate by AX identity; never fall back to another window in the same app.
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement], windows.contains(where: { CFEqual($0, window) }) else {
            throw WindowSearchError.unavailable
        }
        var minimized: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
           minimized as? Bool == true {
            guard AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success else {
                throw WindowSearchError.unavailable
            }
        }
        app.unhide()
        guard app.activate(options: []) else { throw WindowSearchError.unavailable }
        // Restoring a minimized window is animated; AXRaise can temporarily fail until it finishes.
        var raised = false
        for _ in 0..<10 {
            try Task.checkCancellation()
            if AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success {
                raised = true
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard raised else { throw WindowSearchError.unavailable }
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, window)
    }
}

public enum WindowSearchError: Error { case accessibility, unavailable }

extension ToolService {
    public static func launcherWindows() async throws -> LauncherWindowSnapshot {
        let task = Task.detached(priority: .userInitiated) { try LauncherWindowSnapshot.capture() }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    @MainActor public static func activateLauncherWindow(_ id: String, in snapshot: LauncherWindowSnapshot) async throws {
        try await snapshot.activate(id)
    }
}
