import AppKit
import SwiftUI
import Observation
import Theme
import ToolService

@MainActor @Observable
private final class PermissionAuthorizationModel {
    let permission: SystemPermission
    var regrant = false
    var message: String?

    init(permission: SystemPermission) { self.permission = permission }
}

@MainActor
struct PermissionAuthorizationSettingsHandle {
    let windowFrame: () -> CGRect?
    let dismiss: () -> Void
}

/// A standalone, nonmodal panel stays beside System Settings without activating Asky.
@MainActor
final class PermissionAuthorizationWindow: NSObject, NSWindowDelegate {
    static let shared = PermissionAuthorizationWindow()
    private var panel: NSPanel?
    private var settingsSession: PermissionAuthorizationSettingsHandle?
    private var observation: Task<Void, Never>?
    private var generation = UUID()
    private let readState: (SystemPermission) async -> PermissionState
    private let openPermissionSettings: (SystemPermission) throws -> PermissionAuthorizationSettingsHandle

    var window: NSPanel? { panel }

    init(readState: @escaping (SystemPermission) async -> PermissionState = { await SystemPermissions.state($0) },
         openSettings: @escaping (SystemPermission) throws -> PermissionAuthorizationSettingsHandle = {
             let session = try SystemPermissions.openAuthorizationSettings($0)
             return PermissionAuthorizationSettingsHandle(windowFrame: { session.windowFrame }, dismiss: { session.dismiss() })
         }) {
        self.readState = readState
        self.openPermissionSettings = openSettings
        super.init()
    }

    func show(_ permission: SystemPermission, colorScheme: ColorScheme) {
        guard permission.supportsAppDrag else { return }
        cancel()
        let generation = UUID()
        self.generation = generation
        let model = PermissionAuthorizationModel(permission: permission)
        let view = PermissionAuthorizationView(model: model, close: { [weak self] in self?.cancel() },
            reopenSettings: { [weak self] in self?.openSettings(for: model) })
            .environment(\.colorScheme, colorScheme)
        let host = NSHostingView(rootView: view)
        let panel = AuthorizationPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                       backing: .buffered, defer: false)
        panel.title = "\(permission.title) — Asky"
        panel.contentView = host
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .utilityWindow
        panel.delegate = self
        panel.setContentSize(host.fittingSize)
        self.panel = panel
        position(beside: nil)
        panel.makeKeyAndOrderFront(nil)

        observation = Task { [weak self] in
            guard let self else { return }
            let initial = await self.readState(permission)
            guard self.generation == generation, !Task.isCancelled else { return }
            model.regrant = initial == .authorized
            var progress = PermissionAuthorizationProgress(initialState: initial)
            // Adding the dragged app in System Settings is the grant request for this flow.
            // Do not block this independent panel on an additional native request dialog.
            self.openSettings(for: model)
            for _ in 0..<20 {
                guard self.generation == generation, !Task.isCancelled else { return }
                self.resizeToContent()
                if let frame = self.settingsSession?.windowFrame() {
                    self.position(beside: frame)
                    break
                }
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
            while self.generation == generation, !Task.isCancelled {
                let state = await self.readState(permission)
                guard self.generation == generation, !Task.isCancelled else { return }
                self.resizeToContent()
                if progress.observe(state) {
                    self.settingsSession?.dismiss()
                    self.cancel()
                    return
                }
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            }
        }
    }

    private func openSettings(for model: PermissionAuthorizationModel) {
        do {
            settingsSession = try openPermissionSettings(model.permission)
            model.message = nil
            if let frame = settingsSession?.windowFrame() { position(beside: frame) }
            panel?.makeKeyAndOrderFront(nil)
        } catch { model.message = error.localizedDescription }
    }

    func cancel() {
        generation = UUID()
        observation?.cancel()
        observation = nil
        settingsSession = nil
        let oldPanel = panel
        panel = nil
        oldPanel?.delegate = nil
        oldPanel?.close()
    }

    func windowWillClose(_ notification: Notification) { cancel() }

    private func resizeToContent() {
        guard let panel, let content = panel.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        if size.width > 0, size.height > 0, size != panel.frame.size { panel.setContentSize(size) }
    }

    private func position(beside settingsFrame: CGRect?) {
        guard let panel else { return }
        let screen = settingsFrame.flatMap { frame in
            NSScreen.screens.first { $0.frame.contains(NSPoint(x: frame.midX, y: frame.midY)) }
        } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame.insetBy(dx: 12, dy: 12)
        let size = panel.frame.size
        var x = visible.minX
        var y = visible.midY - size.height / 2
        if let frame = settingsFrame {
            let right = frame.maxX + 12
            let left = frame.minX - size.width - 12
            x = right + size.width <= visible.maxX ? right : max(visible.minX, left)
            y = frame.maxY - size.height - 36
        }
        x = max(visible.minX, min(x, visible.maxX - size.width))
        y = max(visible.minY, min(y, visible.maxY - size.height))
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private final class AuthorizationPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { close() }
}

private struct PermissionAuthorizationView: View {
    let model: PermissionAuthorizationModel
    let close: () -> Void
    let reopenSettings: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(NSLocalizedString(model.permission.title, comment: ""))
                    .font(.system(size: 16, weight: .regular))
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28).contentShape(.circle)
                }
                .buttonStyle(.plain).foregroundStyle(ThemeColor.kTextSubtle)
                .accessibilityLabel(NSLocalizedString("关闭", comment: ""))
            }
            let canDrag = SystemPermissions.canDragApp(at: SystemPermissions.appURL)
            if canDrag {
                appTile.onDrag { SystemPermissions.appDragProvider() ?? NSItemProvider() } preview: {
                    appTile.frame(width: 320).environment(\.colorScheme, colorScheme)
                }
            } else {
                appTile.opacity(0.5)
            }
            Text(NSLocalizedString(canDrag
                ? (model.regrant
                    ? "先删除旧条目，再拖入卡片并开启。"
                    : "将卡片拖入系统设置，开启 Asky 开关。")
                : "请先将 Asky.app 移到“应用程序”文件夹并重新打开，再拖拽授权。", comment: ""))
                .font(.system(size: 14)).foregroundStyle(ThemeColor.kTextSubtle)
                .fixedSize(horizontal: false, vertical: true)
            if let message = model.message {
                Text(message).font(.system(size: 13)).foregroundStyle(ThemeColor.kTextNegative)
                    .fixedSize(horizontal: false, vertical: true)
                Button(NSLocalizedString("打开系统设置", comment: ""), action: reopenSettings)
                    .buttonStyle(.glass)
            }
        }
        .padding(20)
        .frame(width: 360)
        .foregroundStyle(ThemeColor.kText)
        .background {
            let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
            shape.fill(ThemeColor.kBackground.color(for: colorScheme, opaque: reduceTransparency))
                .glassEffect(reduceTransparency ? .identity : .regular, in: shape)
                .shadow(color: .black.opacity(0.16), radius: 14, y: 5)
        }
        .padding(20)
    }

    private var appTile: some View {
        HStack(spacing: 12) {
            Image(nsImage: SystemPermissions.appIcon).resizable().frame(width: 48, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("Asky.app").font(.system(size: 16, weight: .regular))
                Text(NSLocalizedString("拖拽授权", comment: ""))
                    .font(.system(size: 13)).foregroundStyle(ThemeColor.kTextSubtle)
            }
            Spacer(minLength: 0)
            Image(systemName: "hand.draw").foregroundStyle(ThemeColor.kIconSubtle)
        }
        .padding(16)
        .background {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            shape.fill(ThemeColor.kBackground.color(for: colorScheme, opaque: reduceTransparency))
                .glassEffect(reduceTransparency ? .identity : .regular, in: shape)
        }
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(ThemeColor.kBorder, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("Asky 应用授权卡片，拖到系统设置的应用列表", comment: ""))
    }
}
