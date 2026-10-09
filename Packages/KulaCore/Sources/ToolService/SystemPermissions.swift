import AppKit
import EventKit
@preconcurrency import Contacts
import UserNotifications
import Contracts

public enum SystemPermission: String, CaseIterable, Identifiable, Sendable {
    case calendar, reminders, contacts, screenRecording, accessibility, automation, notifications
    public var id: String { rawValue }
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
            guard current.canRequest else { return current }
            NSApp.activate()
            switch permission {
            case .calendar: _ = try await events.requestFullAccessToEvents()
            case .reminders: _ = try await events.requestFullAccessToReminders()
            case .contacts: _ = try await contacts.requestAccess(for: .contacts)
            case .notifications: _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
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
            catch { throw ToolError(.permissionDenied, "\(permission.title)授权请求失败：\(error.localizedDescription)。请打开 KulaHere 设置 › 系统权限。") }
        }
        guard current == .authorized else {
            throw ToolError(.permissionDenied, "\(permission.title)：\(current.rawValue)。请打开 KulaHere 设置 › 系统权限；授权后重新发送请求。")
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
}
