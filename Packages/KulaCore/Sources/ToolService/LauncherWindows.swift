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

    /// Chrome also exposes untitled AXUnknown helper surfaces as AXWindow objects.
    /// Keep real untitled windows and dialogs, but do not offer inert helper surfaces.
    static func isSearchableWindow(subrole: String?, title: String, hasCloseButton: Bool) -> Bool {
        subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole
            || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasCloseButton
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
                var subrole: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole)
                var closeButton: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeButton)
                guard isSearchableWindow(subrole: subrole as? String, title: title as? String ?? "",
                                         hasCloseButton: closeButton.map { CFGetTypeID($0) == AXUIElementGetTypeID() } ?? false)
                else { continue }
                let id = UUID().uuidString
                entries.append(Entry(id: id, title: title as? String ?? "", application: app.localizedName ?? "",
                                     applicationPath: app.bundleURL?.path ?? ""))
                targets[id] = (app.processIdentifier, window)
            }
        }
        return LauncherWindowSnapshot(entries: entries, targets: targets)
    }

    @MainActor fileprivate func validatedTarget(_ id: String) throws -> (NSRunningApplication, AXUIElement) {
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
        return (app, window)
    }

    @MainActor fileprivate func close(_ id: String) throws {
        let (_, window) = try validatedTarget(id)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID(),
              AXUIElementPerformAction(value as! AXUIElement, kAXPressAction as CFString) == .success else {
            throw WindowSearchError.unavailable
        }
    }

    @MainActor fileprivate func fullScreenState(_ id: String) throws -> Bool {
        let (_, window) = try validatedTarget(id)
        var value: CFTypeRef?
        var settable = DarwinBoolean(false)
        let read = AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value)
        let writable = AXUIElementIsAttributeSettable(window, "AXFullScreen" as CFString, &settable)
        guard read == .success, let state = value as? Bool,
              writable == .success, settable.boolValue else { throw WindowSearchError.unavailable }
        return state
    }

    @MainActor fileprivate func setFullScreen(_ enabled: Bool, for id: String) async throws {
        // Revalidate and read current state at execution, preserving the menu's explicit intent.
        _ = try fullScreenState(id)
        try await activate(id)
        let (_, window) = try validatedTarget(id)
        if try fullScreenState(id) == enabled { return }
        let result = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString,
                                                 enabled ? kCFBooleanTrue : kCFBooleanFalse)
        guard result == .success else {
            throw WindowSearchError.unavailable
        }
        // Native full-screen transitions are asynchronous; confirm the resulting state.
        for _ in 0..<40 {
            try await Task.sleep(for: .milliseconds(100))
            if let state = try? fullScreenState(id), state == enabled { return }
        }
        throw WindowSearchError.unavailable
    }

    @MainActor fileprivate func moveDisplay(_ direction: Int, for id: String) async throws {
        guard direction == -1 || direction == 1, NSScreen.screens.count > 1 else { throw WindowSearchError.unavailable }
        let (_, initialWindow) = try validatedTarget(id)
        var fullScreen: CFTypeRef?
        AXUIElementCopyAttributeValue(initialWindow, "AXFullScreen" as CFString, &fullScreen)
        guard fullScreen as? Bool != true else { throw WindowSearchError.fullScreenDisplayMove }
        try await activate(id)
        let (_, window) = try validatedTarget(id)
        func readFrame() throws -> CGRect {
            var positionValue: CFTypeRef?, sizeValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
                  AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
                  let positionValue, let sizeValue,
                  CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID()
            else { throw WindowSearchError.unavailable }
            var position = CGPoint.zero, size = CGSize.zero
            guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
                  AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { throw WindowSearchError.unavailable }
            return CGRect(origin: position, size: size)
        }
        let original = try readFrame()
        let screens = NSScreen.screens
        guard let primary = screens.first else { throw WindowSearchError.unavailable }
        func axRect(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX, y: primary.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
        }
        let displays = screens.map { axRect($0.frame) }
        guard let source = LauncherWindowDisplayLayout.source(for: original, displays: displays),
              let target = LauncherWindowDisplayLayout.target(for: original, displays: displays, direction: direction)
        else { throw WindowSearchError.unavailable }
        let destination = axRect(screens[target].visibleFrame)
        let desired = LauncherWindowDisplayLayout.frame(for: original, source: axRect(screens[source].visibleFrame), destination: destination)
        var position = desired.origin, size = desired.size
        var positionSettable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &positionSettable) == .success,
              positionSettable.boolValue else { throw WindowSearchError.unavailable }
        if size != original.size {
            guard let value = AXValueCreate(.cgSize, &size),
                  AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value) == .success
            else { throw WindowSearchError.unavailable }
        }
        guard let value = AXValueCreate(.cgPoint, &position),
              AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success
        else { throw WindowSearchError.unavailable }
        // An AX write may succeed before the application has applied the frame.
        for _ in 0..<10 {
            try await Task.sleep(for: .milliseconds(100))
            _ = try validatedTarget(id)
            let actual = try readFrame()
            if LauncherWindowDisplayLayout.source(for: actual, displays: displays) == target,
               abs(actual.minX - desired.minX) < 3, abs(actual.minY - desired.minY) < 3 { return }
        }
        throw WindowSearchError.unavailable
    }

    @MainActor fileprivate func activate(_ id: String) async throws {
        let (app, window) = try validatedTarget(id)
        let pid = app.processIdentifier
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

public enum WindowSearchError: Error { case accessibility, unavailable, fullScreenDisplayMove }

extension ToolService {
    @MainActor public static var launcherHasMultipleDisplays: Bool { NSScreen.screens.count > 1 }

    @MainActor public static func moveLauncherWindowDisplay(_ direction: Int, for id: String,
                                                           in snapshot: LauncherWindowSnapshot) async throws {
        try await snapshot.moveDisplay(direction, for: id)
    }

    public static func launcherWindows() async throws -> LauncherWindowSnapshot {
        let task = Task.detached(priority: .userInitiated) { try LauncherWindowSnapshot.capture() }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    @MainActor public static func activateLauncherWindow(_ id: String, in snapshot: LauncherWindowSnapshot) async throws {
        try await snapshot.activate(id)
    }
}

extension ToolService {
    @MainActor public static func closeLauncherWindow(_ id: String, in snapshot: LauncherWindowSnapshot) throws {
        try snapshot.close(id)
    }

    @MainActor public static func launcherWindowFullScreenState(_ id: String, in snapshot: LauncherWindowSnapshot) throws -> Bool {
        try snapshot.fullScreenState(id)
    }

    @MainActor public static func setLauncherWindowFullScreen(_ enabled: Bool, for id: String,
                                                             in snapshot: LauncherWindowSnapshot) async throws {
        try await snapshot.setFullScreen(enabled, for: id)
    }
}
