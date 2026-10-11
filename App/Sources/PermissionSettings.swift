import SwiftUI
import Combine
import Theme
import ToolService

struct PermissionSettings: View {
    @State private var states: [SystemPermission: PermissionState] = [:]
    @State private var requesting: SystemPermission?
    @Environment(\.colorScheme) private var colorScheme
    @State private var message: String?
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
                            Text(NSLocalizedString(states[permission]?.rawValue ?? "正在检查…", comment: ""))
                                .textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        if permission.supportsAppDrag {
                            Button(NSLocalizedString(states[permission] == .authorized ? "重新授权" : "去授权", comment: "")) {
                                message = nil
                                PermissionAuthorizationWindow.shared.show(permission, colorScheme: colorScheme)
                            }
                        } else {
                            HStack(spacing: 8) {
                                if let state = states[permission], permission.canRequest(from: state) {
                                    Button(requesting == permission ? NSLocalizedString("正在请求…", comment: "") : NSLocalizedString("请求授权", comment: "")) {
                                        Task { await request(permission) }
                                    }.disabled(requesting != nil)
                                }
                                Button(NSLocalizedString("打开系统设置", comment: "")) { openSettings(permission) }
                            }.fixedSize()
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button(NSLocalizedString("刷新权限状态", comment: "")) { Task { await refresh() } }
                if let message { Text(message).textStyle(.secondary).textSelection(.enabled) }
            }
        }
        .formStyle(.grouped)
        .task { await refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refresh() }
        }
        .onReceive(refreshTimer) { _ in
            guard scenePhase == .active, requesting == nil else { return }
            Task { await refresh() }
        }
    }

    private func request(_ permission: SystemPermission) async {
        requesting = permission
        message = nil
        do { states[permission] = try await SystemPermissions.request(permission) }
        catch { message = error.localizedDescription }
        requesting = nil
    }

    private func openSettings(_ permission: SystemPermission) {
        do { try SystemPermissions.openSettings(permission) }
        catch { message = error.localizedDescription }
    }

    private func refresh() async {
        for permission in SystemPermission.allCases { states[permission] = await SystemPermissions.state(permission) }
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
