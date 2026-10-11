import AppKit
import EventKit
@preconcurrency import Contacts
import UserNotifications
import UniformTypeIdentifiers
import Contracts

public enum SystemPermission: String, CaseIterable, Identifiable, Sendable {
    case calendar, reminders, contacts, screenRecording, accessibility, automation, notifications
    public var id: String { rawValue }
    public var supportsAppDrag: Bool { self == .accessibility || self == .screenRecording }
    // These APIs report only a Boolean, so false cannot distinguish never requested from denied.
    public func canRequest(from state: PermissionState) -> Bool {
        state.canRequest || (supportsAppDrag && state == .denied)
    }
    public var title: String {
        switch self {
        case .calendar: "日历"
        case .reminders: "提醒事项"
        case .contacts: "通讯录"
        case .screenRecording: "屏幕录制"
        case .accessibility: "辅助功能（自动粘贴）"
        case .automation: "自动化（Chrome、备忘录）"
        case .notifications: "通知"
        }
    }
    var pane: String {
        switch self {
        case .calendar: "Privacy_Calendars"
        case .reminders: "Privacy_Reminders"
        case .contacts: "Privacy_Contacts"
        case .screenRecording: "Privacy_ScreenCapture"
        case .accessibility: "Privacy_Accessibility"
        case .automation: "Privacy_Automation"
        case .notifications: ""
        }
    }
    var tccService: String? {
        switch self {
        case .screenRecording: "ScreenCapture"
        case .accessibility: "Accessibility"
        default: nil
        }
    }
    /// Screen capture access is read once per process, so a new grant applies only after relaunch.
    public var requiresRelaunchAfterGrant: Bool { self == .screenRecording }
    public static func source(_ source: DataSourceID) -> Self? {
        switch source {
        case .calendar: .calendar
        case .reminders: .reminders
        case .contacts: .contacts
        default: nil
        }
    }
}

public enum PermissionState: String, Sendable {
    case notDetermined = "尚未请求"
    case authorized = "已授权"
    case denied = "未授权，请到系统设置开启"
    case restricted = "系统限制，无法请求"
    case writeOnly = "仅允许写入，需要完全访问"
    case perTarget = "按目标应用授权，首次使用时请求"
    public var canRequest: Bool { self == .notDetermined || self == .writeOnly }
}

/// Native permission operations live alongside ToolService, never in the model runtime.
@MainActor
public enum SystemPermissions {
    private static let events = EKEventStore()
    private static let contacts = CNContactStore()
    private static var pending: [SystemPermission: Task<PermissionState, Error>] = [:]

    public static func eventState(_ status: EKAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined: .notDetermined
        case .fullAccess, .authorized: .authorized
        case .writeOnly: .writeOnly
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }

    public static func state(_ permission: SystemPermission) async -> PermissionState {
        switch permission {
        case .calendar: return eventState(EKEventStore.authorizationStatus(for: .event))
        case .reminders: return eventState(EKEventStore.authorizationStatus(for: .reminder))
        case .contacts:
            switch CNContactStore.authorizationStatus(for: .contacts) {
            case .notDetermined: return .notDetermined
            case .authorized: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .restricted
            }
        case .screenRecording: return CGPreflightScreenCaptureAccess() ? .authorized : .denied
        case .accessibility: return AXIsProcessTrusted() ? .authorized : .denied
        case .automation: return .perTarget
        case .notifications:
            switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
            case .notDetermined: return .notDetermined
            case .authorized, .provisional: return .authorized
            case .denied: return .denied
            @unknown default: return .restricted
            }
        }
    }

    public static func request(_ permission: SystemPermission) async throws -> PermissionState {
        if let task = pending[permission] { return try await task.value }
        let task = Task { @MainActor in
            let current = await state(permission)
            guard permission.canRequest(from: current) else { return current }
            NSApp.activate()
            switch permission {
            case .calendar: _ = try await events.requestFullAccessToEvents()
            case .reminders: _ = try await events.requestFullAccessToReminders()
            case .contacts: _ = try await contacts.requestAccess(for: .contacts)
            case .notifications: _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
            case .screenRecording: _ = CGRequestScreenCaptureAccess()
            case .accessibility: _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            default: break
            }
            return await state(permission)
        }
        pending[permission] = task
        defer { pending[permission] = nil }
        return try await task.value
    }

    public static func require(_ source: DataSourceID, origin: CallerOrigin) async throws {
        guard let permission = SystemPermission.source(source) else { return }
        var current = await state(permission)
        // External clients cannot cause system prompts. Grant access in the native app first.
        if case .mcp = origin {} else if current.canRequest {
            do { current = try await request(permission) }
            catch { throw ToolError(.permissionDenied, "\(permission.title)授权请求失败：\(error.localizedDescription)。请打开 Asky 设置 › 系统权限。") }
        }
        guard current == .authorized else {
            throw ToolError(.permissionDenied, "\(permission.title)：\(current.rawValue)。请打开 Asky 设置 › 系统权限；授权后重新发送请求。")
        }
    }

    public static func openSettings(_ permission: SystemPermission) throws {
        let link = permission == .notifications
            ? "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
            : "x-apple.systempreferences:com.apple.preference.security?\(permission.pane)"
        guard let url = URL(string: link), NSWorkspace.shared.open(url) else {
            throw ToolError(.adapterFailure, "无法打开系统设置。请手动进入系统设置 › 隐私与安全性 › \(permission.title)。")
        }
    }

    /// Drag the running bundle, never another build found by bundle identifier.
    public static var appURL: URL { Bundle.main.bundleURL }
    public static var appIcon: NSImage { NSWorkspace.shared.icon(forFile: appURL.path) }

    public static func canDragApp(at url: URL) -> Bool {
        url.isFileURL && url.pathExtension == "app" && !url.pathComponents.contains("AppTranslocation")
    }

    public static func appDragProvider() -> NSItemProvider? {
        appDragProvider(for: appURL)
    }

    static func appDragProvider(for url: URL) -> NSItemProvider? {
        guard canDragApp(at: url) else { return nil }
        let provider = NSItemProvider()
        provider.suggestedName = url.lastPathComponent
        let data = Data(url.absoluteString.utf8)
        provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    public static func revealApp() {
        NSWorkspace.shared.activateFileViewerSelecting([appURL])
    }

    /// Ad-hoc builds are recorded by cdhash, so an entry left by an older build stays switched on
    /// without applying, and System Settings ignores a drop while that entry exists.
    /// Clearing only this bundle's entry lets the drop record the running build.
    public static func resetAuthorization(_ permission: SystemPermission) async {
        guard let service = permission.tccService, let bundleID = Bundle.main.bundleIdentifier else { return }
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/tccutil")
            process.arguments = ["reset", service, bundleID]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return }
            process.waitUntilExit()
        }.value
    }

    /// Lets the running process add itself to the list, so the entry carries its real signature.
    /// Both calls return at once; the toggle is then switched on in System Settings.
    public static func registerForAuthorization(_ permission: SystemPermission) {
        switch permission {
        case .screenRecording: _ = CGRequestScreenCaptureAccess()
        case .accessibility: _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        default: break
        }
    }

    public static func relaunchApp() throws {
        try ToolService.reopenInstalledAppAfterExit(at: appURL)
        NSApp.terminate(nil)
    }

    public static func openAuthorizationSettings(_ permission: SystemPermission) throws -> PermissionSettingsSession {
        let session = PermissionSettingsSession(permission: permission)
        try openSettings(permission)
        return session
    }
}

/// Track only the settings application and permission pane opened by this flow.
@MainActor
public final class PermissionSettingsSession {
    private let permission: SystemPermission
    private var application: NSRunningApplication?

    fileprivate init(permission: SystemPermission) { self.permission = permission }

    private func resolveApplication() -> NSRunningApplication? {
        if let application { return application.isTerminated ? nil : application }
        application = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").first
        return application
    }

    private var paneTitles: Set<String> {
        switch permission {
        case .screenRecording:
            ["录屏与系统录音", "屏幕录制", "屏幕与系统音频录制", "Screen Recording", "Screen & System Audio Recording"]
        case .accessibility:
            ["辅助功能", "设备控制和数据访问", "Accessibility", "Device Control and Data Access"]
        default: []
        }
    }

    private var visibleWindows: [[String: Any]] {
        guard let application = resolveApplication(),
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return windows.filter {
            ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == application.processIdentifier &&
            ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
        }
    }

    /// Convert Quartz screen coordinates to AppKit coordinates for side-by-side placement.
    public var windowFrame: CGRect? {
        guard let window = visibleWindows.first,
              let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
              let primary = NSScreen.screens.first else { return nil }
        return CGRect(x: rect.minX, y: primary.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Close a matching pane when Accessibility permits it. Otherwise hide that pane's app.
    /// Never quit System Settings or dismiss a different pane the user has navigated to.
    public func dismiss() {
        guard let application = resolveApplication() else { return }
        if AXIsProcessTrusted() {
            let element = AXUIElementCreateApplication(application.processIdentifier)
            var windows: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windows) == .success,
                  let windows = windows as? [AXUIElement] else { return }
            for window in windows {
                var title: CFTypeRef?
                guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title) == .success,
                      let title = title as? String, paneTitles.contains(title) else { continue }
                var closeButton: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeButton) == .success,
                   let closeButton,
                   AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString) == .success { return }
                _ = application.hide()
                return
            }
        } else if visibleWindows.contains(where: { paneTitles.contains($0[kCGWindowName as String] as? String ?? "") }) {
            _ = application.hide()
        }
    }
}

/// A fresh grant completes immediately; regranting must first observe the old grant disappear.
public struct PermissionAuthorizationProgress: Sendable {
    private var observedUnauthorized: Bool
    public private(set) var completed = false

    public init(initialState: PermissionState) { observedUnauthorized = initialState != .authorized }

    public mutating func observe(_ state: PermissionState) -> Bool {
        guard !completed else { return false }
        if state != .authorized { observedUnauthorized = true; return false }
        guard observedUnauthorized else { return false }
        completed = true
        return true
    }
}
