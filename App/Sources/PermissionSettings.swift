import SwiftUI
import Combine
import Theme
import ToolService

struct PermissionSettings: View {
    @State private var states: [SystemPermission: PermissionState] = [:]
    @State private var requesting: SystemPermission?
    @State private var authorizing: SystemPermission?
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
                                authorizing = permission
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
        .sheet(item: $authorizing, onDismiss: { Task { await refresh() } }) { permission in
            PermissionAuthorizationSheet(permission: permission,
                state: states[permission], requesting: requesting == permission, message: message) {
                Task {
                    if let state = states[permission], permission.canRequest(from: state) {
                        await request(permission)
                    }
                    openSettings(permission)
                }
            }
            .presentationBackground(.clear)
        }
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

private struct PermissionAuthorizationSheet: View {
    let permission: SystemPermission
    let state: PermissionState?
    let requesting: Bool
    let message: String?
    let openSettings: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString(permission.title, comment: ""))
                        .font(.system(size: 20, weight: .semibold))
                    Label(NSLocalizedString(state == .authorized ? "已开启" : "需要授权", comment: ""),
                          systemImage: state == .authorized ? "checkmark.circle.fill" : "lock.shield")
                        .font(.system(size: 13))
                        .foregroundStyle(state == .authorized ? ThemeColor.kTextPositive : ThemeColor.kTextSubtle)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ThemeColor.kTextSubtle)
                .accessibilityLabel(NSLocalizedString("关闭", comment: ""))
                .keyboardShortcut(.cancelAction)
            }

            let canDrag = SystemPermissions.canDragApp(at: SystemPermissions.appURL)
            if canDrag {
                appTile.onDrag {
                    SystemPermissions.appDragProvider() ?? NSItemProvider()
                } preview: {
                    Image(nsImage: SystemPermissions.appIcon).resizable().frame(width: 64, height: 64)
                }
                .help(NSLocalizedString("将 Asky 拖到对应系统设置页的应用列表", comment: ""))
            } else {
                appTile.opacity(0.5)
            }

            Text(NSLocalizedString(canDrag
                ? (state == .authorized
                    ? "在系统设置中选中 Asky，点击“−”删除旧条目，再拖入上方应用卡片并开启开关。"
                    : "打开系统设置，将上方应用卡片拖入列表并开启开关。若已有 Asky 条目，先点击“−”删除，再拖入。")
                : "请先将 Asky.app 移到“应用程序”文件夹并重新打开，再拖拽授权。", comment: ""))
                .font(.system(size: 14))
                .foregroundStyle(ThemeColor.kTextSubtle)
                .fixedSize(horizontal: false, vertical: true)
            if let message {
                Text(message).font(.system(size: 13)).foregroundStyle(ThemeColor.kTextNegative)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button(NSLocalizedString("在 Finder 中显示", comment: "")) { SystemPermissions.revealApp() }
                    .buttonStyle(.plain).foregroundStyle(ThemeColor.kTextSubtle)
                Spacer()
                Button(requesting ? NSLocalizedString("正在请求…", comment: "") : NSLocalizedString("打开系统设置", comment: ""), action: openSettings)
                    .buttonStyle(.glass).disabled(requesting)
            }
        }
        .padding(24)
        .frame(width: 460)
        .foregroundStyle(ThemeColor.kText)
        .background {
            let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
            if reduceTransparency {
                shape.fill(ThemeColor.kBackground.color(for: colorScheme, opaque: true))
            } else {
                shape.fill(.clear).glassEffect(.regular, in: shape)
            }
        }
    }

    private var appTile: some View {
        HStack(spacing: 14) {
            Image(nsImage: SystemPermissions.appIcon).resizable().frame(width: 56, height: 56)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Asky.app").font(.system(size: 17, weight: .medium))
                Text(NSLocalizedString("拖到系统设置的应用列表", comment: ""))
                    .font(.system(size: 13)).foregroundStyle(ThemeColor.kTextSubtle)
            }
            Spacer()
            Image(systemName: "hand.draw").font(.system(size: 19)).foregroundStyle(ThemeColor.kIconSubtle)
        }
        .padding(20)
        .background(ThemeColor.kBackgroundNeutral, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(ThemeColor.kBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("Asky 应用授权卡片，拖到系统设置的应用列表", comment: ""))
    }
}
