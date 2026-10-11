import SwiftUI
import Combine
import Observation
import Theme
import ToolService

/// Keep older asynchronous reads from overwriting the result of a user request.
@MainActor @Observable
final class PermissionSettingsModel {
    var states: [SystemPermission: PermissionState] = [:]
    var requesting: SystemPermission?
    var message: String?
    private var revision = 0
    private let readState: (SystemPermission) async -> PermissionState
    private let requestAccess: (SystemPermission) async throws -> PermissionState

    init(readState: @escaping (SystemPermission) async -> PermissionState = { await SystemPermissions.state($0) },
         requestAccess: @escaping (SystemPermission) async throws -> PermissionState = { try await SystemPermissions.request($0) }) {
        self.readState = readState
        self.requestAccess = requestAccess
    }

    func request(_ permission: SystemPermission) async {
        guard requesting == nil else { return }
        revision += 1
        requesting = permission
        message = nil
        defer { requesting = nil }
        do { states[permission] = try await requestAccess(permission) }
        catch { message = error.localizedDescription }
    }

    func refresh() async {
        guard requesting == nil else { return }
        revision += 1
        let currentRevision = revision
        for permission in SystemPermission.allCases {
            let state = await readState(permission)
            guard revision == currentRevision, requesting == nil, !Task.isCancelled else { return }
            states[permission] = state
        }
    }
}

struct PermissionSettings: View {
    @State private var model = PermissionSettingsModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section(NSLocalizedString("系统权限", comment: "")) {
                ForEach(SystemPermission.allCases) { permission in
                    HStack(spacing: 12) {
                        Image(systemName: symbol(for: permission))
                            .font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(iconColor(for: permission), in: RoundedRectangle(cornerRadius: 7))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString(permission.title, comment: ""))
                            Text(NSLocalizedString(model.states[permission]?.rawValue ?? "正在检查…", comment: ""))
                                .textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        if permission.supportsAppDrag {
                            Button(NSLocalizedString(model.states[permission] == .authorized ? "重新授权" : "去授权", comment: "")) {
                                model.message = nil
                                PermissionAuthorizationWindow.shared.show(permission, colorScheme: colorScheme)
                            }
                        } else {
                            HStack(spacing: 8) {
                                if let state = model.states[permission], permission.canRequest(from: state) {
                                    Button(model.requesting == permission ? NSLocalizedString("正在请求…", comment: "") : NSLocalizedString("请求授权", comment: "")) {
                                        Task { await model.request(permission) }
                                    }.disabled(model.requesting != nil)
                                }
                                Button(NSLocalizedString("打开系统设置", comment: "")) { openSettings(permission) }
                            }.fixedSize()
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button(NSLocalizedString("刷新权限状态", comment: "")) { Task { await model.refresh() } }
                if let message = model.message { Text(message).textStyle(.secondary).textSelection(.enabled) }
            }
        }
        .formStyle(.grouped)
        .task { await model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.refresh() }
        }
        .onReceive(refreshTimer) { _ in
            guard scenePhase == .active, model.requesting == nil else { return }
            Task { await model.refresh() }
        }
    }

    private func openSettings(_ permission: SystemPermission) {
        do { try SystemPermissions.openSettings(permission) }
        catch { model.message = error.localizedDescription }
    }

    private func symbol(for permission: SystemPermission) -> String {
        switch permission {
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .contacts: "person.crop.rectangle"
        case .screenRecording: "record.circle"
        case .accessibility: "accessibility"
        case .automation: "gearshape.2"
        case .notifications: "bell.badge"
        }
    }

    private func iconColor(for permission: SystemPermission) -> Color {
        switch permission {
        case .calendar, .screenRecording: .red
        case .reminders: .orange
        case .contacts: .brown
        case .automation: .gray
        case .accessibility: .blue
        case .notifications: .purple
        }
    }
}
