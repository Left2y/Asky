import AppKit
import SwiftUI
import Theme

/// One in-app reminder card. Unlike UserNotifications, Asky draws the whole surface itself.
struct ReminderBannerItem: Identifiable {
    struct Action {
        var title: String
        var prominent = false
        var handler: @MainActor () -> Void = {}
    }

    let id = UUID()
    var source: String
    var timeLabel: String
    var title: String
    var body: String
    var symbol = "calendar"
    var actions: [Action] = []
    /// Auto-dismiss delay; hovering pauses it. nil keeps the card until the user acts.
    var lifetime: TimeInterval? = 8
}

/// Floating cards in the top-right corner, stacked downward, never taking focus from the frontmost app.
@MainActor
final class ReminderBannerCenter {
    static let shared = ReminderBannerCenter()

    private static let width: CGFloat = 360
    private static let margin: CGFloat = 12
    private static let gap: CGFloat = 10
    /// Transparent canvas around the card so the panel does not clip its shadow.
    static let shadowInset: CGFloat = 24
    private static let maxVisible = 3

    private final class Entry {
        let item: ReminderBannerItem
        let panel: NSPanel
        var timer: Timer?
        var remaining: TimeInterval?
        var deadline: Date?
        init(item: ReminderBannerItem, panel: NSPanel) {
            self.item = item
            self.panel = panel
            remaining = item.lifetime
        }
    }

    private var entries: [Entry] = []
    private var waiting: [ReminderBannerItem] = []

    func show(_ item: ReminderBannerItem) {
        guard entries.count < Self.maxVisible else { waiting.append(item); return }
        let panel = ReminderBannerPanel()
        let entry = Entry(item: item, panel: panel)
        let view = ReminderBannerView(item: item,
                                      onDismiss: { [weak self] in self?.dismiss(item.id) },
                                      onHover: { [weak self] hovering in self?.setPaused(hovering, id: item.id) })
        let host = NSHostingView(rootView: view)
        let size = NSSize(width: Self.width + Self.shadowInset * 2,
                          height: host.fittingSize.height)
        // Measured once; the panel frame is then owned by the stack layout, not the hosting view.
        host.sizingOptions = []
        panel.setContentSize(size)
        panel.contentView = host
        entries.append(entry)

        guard let screen = (NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main)?.visibleFrame
        else { return }
        let target = origin(for: entries.count - 1, size: size, in: screen)
        panel.alphaValue = 0
        panel.setFrameOrigin(NSPoint(x: target.x + 40, y: target.y))
        panel.orderFrontRegardless()
        animate(duration: 0.35) {
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(target)
        }
        NSAccessibility.post(element: panel, notification: .announcementRequested,
                             userInfo: [.announcement: "\(item.title)，\(item.body)", .priority: NSAccessibilityPriorityLevel.high.rawValue])
        startTimer(entry)
    }

    func dismiss(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.item.id == id }) else { return }
        let entry = entries.remove(at: index)
        entry.timer?.invalidate()
        let panel = entry.panel
        animate(duration: 0.2, {
            panel.animator().alphaValue = 0
            panel.animator().setFrameOrigin(NSPoint(x: panel.frame.minX + 24, y: panel.frame.minY))
        }, completion: { panel.orderOut(nil) })
        relayout()
        if !waiting.isEmpty { show(waiting.removeFirst()) }
    }

    func dismissAll() {
        waiting.removeAll()
        entries.map(\.item.id).forEach(dismiss)
    }

    private func relayout() {
        guard let screen = (entries.first?.panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        var top = screen.maxY - Self.margin + Self.shadowInset
        for entry in entries {
            let size = entry.panel.frame.size
            let target = NSPoint(x: screen.maxX - Self.margin - size.width + Self.shadowInset, y: top - size.height)
            animate(duration: 0.25) { entry.panel.animator().setFrameOrigin(target) }
            top -= size.height - Self.shadowInset * 2 + Self.gap
        }
    }

    private func origin(for index: Int, size: NSSize, in screen: NSRect) -> NSPoint {
        var top = screen.maxY - Self.margin + Self.shadowInset
        for entry in entries.prefix(index) { top -= entry.panel.frame.height - Self.shadowInset * 2 + Self.gap }
        return NSPoint(x: screen.maxX - Self.margin - size.width + Self.shadowInset, y: top - size.height)
    }

    private func setPaused(_ paused: Bool, id: UUID) {
        guard let entry = entries.first(where: { $0.item.id == id }) else { return }
        if paused {
            entry.timer?.invalidate()
            entry.timer = nil
            if let deadline = entry.deadline { entry.remaining = max(1.5, deadline.timeIntervalSinceNow) }
        } else {
            startTimer(entry)
        }
    }

    private func startTimer(_ entry: Entry) {
        guard let remaining = entry.remaining else { return }
        entry.deadline = Date().addingTimeInterval(remaining)
        let id = entry.item.id
        entry.timer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss(id) }
        }
    }

    private func animate(duration: TimeInterval, _ changes: () -> Void, completion: (@MainActor () -> Void)? = nil) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = reduceMotion ? 0 : duration
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            changes()
        }, completionHandler: completion.map { done in { MainActor.assumeIsolated { done() } } })
    }

    #if DEBUG
    /// Developer preview: two sample cards, no calendar or scheduler records.
    func showPreview() {
        show(ReminderBannerItem(source: "Asky · 情境提醒", timeLabel: "15 分钟后",
                                title: "产品讨论会", body: "14:30 – 15:30 · 3 号会议室\n上次会议约定要带上新版原型，记得提前准备。",
                                symbol: "calendar",
                                actions: [.init(title: "稍后提醒"), .init(title: "查看依据", prominent: true)],
                                lifetime: nil))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.show(ReminderBannerItem(source: "Asky · 出行提醒", timeLabel: "现在",
                                          title: "该出发了", body: "去往望京 SOHO 预计 28 分钟，路况较平时拥堵。",
                                          symbol: "car.fill",
                                          actions: [.init(title: "已处理")]))
        }
    }
    #endif
}

private final class ReminderBannerPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct ReminderBannerView: View {
    let item: ReminderBannerItem
    let onDismiss: () -> Void
    let onHover: (Bool) -> Void
    @State private var hovering = false
    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                Text(item.source)
                    .textStyle(.secondary)
                    .foregroundStyle(ThemeColor.kTextSubtle)
                Spacer(minLength: 8)
                Text(item.timeLabel)
                    .textStyle(.secondary)
                    .foregroundStyle(ThemeColor.kTextSubtle)
                    .opacity(hovering ? 0 : 1)
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ThemeColor.kText)
                    Text(item.body)
                        .textStyle(.resultPrimary)
                        .foregroundStyle(ThemeColor.kTextSubtle)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }
                Spacer(minLength: 0)
            }

            if !item.actions.isEmpty {
                HStack(spacing: 8) {
                    Spacer()
                    ForEach(Array(item.actions.enumerated()), id: \.offset) { _, action in
                        Button {
                            action.handler()
                            onDismiss()
                        } label: {
                            Text(action.title).frame(minWidth: 56)
                        }
                        .buttonStyle(BannerButtonStyle(prominent: action.prominent))
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 360, alignment: .leading)
        .nativeGlassBackground(in: shape)
        .background {
            // Shadow only outside the card, so it never darkens the translucent glass.
            shape.fill(.black)
                .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 6)
                .mask {
                    Rectangle().padding(-ReminderBannerCenter.shadowInset)
                        .overlay { shape.fill(.black).blendMode(.destinationOut) }
                        .compositingGroup()
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(ThemeColor.kTextSubtle)
                .background(ThemeColor.kBackgroundNeutral, in: Circle())
                .padding(10)
                .accessibilityLabel(Text("关闭"))
                .transition(.opacity)
            }
        }
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.15)) { hovering = inside }
            onHover(inside)
        }
        .accessibilityElement(children: .contain)
        .padding(ReminderBannerCenter.shadowInset)
    }
}

/// System bordered buttons dim in non-key windows; the banner never becomes key, so it draws its own.
private struct BannerButtonStyle: ButtonStyle {
    var prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(ThemeColor.kText))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(prominent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(ThemeColor.kBackgroundNeutral),
                        in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}
