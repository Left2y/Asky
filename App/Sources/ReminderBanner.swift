import AppKit
import SwiftUI
import Theme
import ToolService

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
    /// Why Asky raised this reminder; shown from the ⓘ beside the source line, not as a button.
    var reasons: [String] = []
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

    @MainActor private final class Entry {
        let item: ReminderBannerItem
        let panel: NSPanel
        let motion = ReminderBannerMotion()
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
        let view = ReminderBannerView(item: item, motion: entry.motion,
                                      onDismiss: { [weak self] in self?.dismiss(item.id) },
                                      onHover: { [weak self] hovering in self?.setPaused(hovering, id: item.id) })
        let host = NSHostingView(rootView: view)
        let size = NSSize(width: Self.width + Self.shadowInset * 2,
                          height: host.fittingSize.height)
        // Measured once; the panel frame is then owned by the stack layout, not the hosting view.
        host.sizingOptions = []
        entries.append(entry)

        guard let screen = (NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main)?.visibleFrame
        else { return }
        // Final size and place before the content attaches, so the first layout is already the resting one and
        // the only thing that animates is the horizontal slide inside the window (clipped at the screen edge).
        panel.setFrame(NSRect(origin: origin(for: entries.count - 1, size: size, in: screen), size: size), display: false)
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host
        host.layoutSubtreeIfNeeded()
        panel.orderFrontRegardless()
        DispatchQueue.main.async { entry.motion.present() }
        NSAccessibility.post(element: panel, notification: .announcementRequested,
                             userInfo: [.announcement: "\(item.title)，\(item.body)", .priority: NSAccessibilityPriorityLevel.high.rawValue])
        startTimer(entry)
    }

    func dismiss(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.item.id == id }) else { return }
        let entry = entries.remove(at: index)
        entry.timer?.invalidate()
        entry.motion.dismiss()
        let panel = entry.panel
        DispatchQueue.main.asyncAfter(deadline: .now() + (Self.reduceMotion ? 0 : 0.3)) { panel.orderOut(nil) }
        relayout()
        if !waiting.isEmpty { show(waiting.removeFirst()) }
    }

    func dismissAll() {
        waiting.removeAll()
        entries.map(\.item.id).forEach(dismiss)
    }

    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private func relayout() {
        guard let screen = (entries.first?.panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        for (index, entry) in entries.enumerated() {
            let size = entry.panel.frame.size
            let frame = NSRect(origin: origin(for: index, size: size, in: screen), size: size)
            guard frame != entry.panel.frame else { continue }
            // NSWindow animates `frame` (setFrame:display:), not setFrameOrigin.
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = Self.reduceMotion ? 0 : 0.25
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
                entry.panel.animator().setFrame(frame, display: true)
            }
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

    #if DEBUG
    /// Developer preview: two sample cards, no calendar or scheduler records.
    func showPreview() {
        show(ReminderBannerItem(source: "Asky · 情境提醒", timeLabel: "15 分钟后",
                                title: "产品讨论会", body: "14:30 – 15:30 · 3 号会议室\n上次会议约定要带上新版原型，记得提前准备。",
                                symbol: "calendar",
                                reasons: ["日程：产品讨论会 14:30", "记忆：上次会议约定带新版原型"],
                                actions: [.init(title: "稍后提醒"),
                                          .init(title: "打开日程", prominent: true) { Self.openApp("com.apple.iCal") }],
                                lifetime: nil))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.show(ReminderBannerItem(source: "Asky · 出行提醒", timeLabel: "现在",
                                          title: "该出发了", body: "去往望京 SOHO 预计 28 分钟，路况较平时拥堵。",
                                          symbol: "car.fill",
                                          reasons: ["日程：望京 SOHO 拜访 10:30", "路况：较平时拥堵"],
                                          actions: [.init(title: "已处理"),
                                                    .init(title: "查看路线", prominent: true) { Self.openApp("com.apple.Maps") }]))
        }
    }

    private static func openApp(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        _ = ToolService.openLauncherApplication(url)
    }
    #endif
}

/// Drives the slide; the window itself never moves for enter / exit.
@MainActor @Observable
final class ReminderBannerMotion {
    private(set) var presented = false
    /// The outer shadow is a separate layer; it fades in after the slide so it never trails the glass.
    private(set) var settled = false

    func present() {
        let reduce = ReminderBannerCenter.reduceMotion
        withAnimation(reduce ? .easeOut(duration: 0.15) : .smooth(duration: 0.4)) { presented = true } completion: {
            withAnimation(.easeOut(duration: 0.15)) { self.settled = true }
        }
    }

    func dismiss() {
        settled = false
        withAnimation(ReminderBannerCenter.reduceMotion ? .easeOut(duration: 0.15) : .easeIn(duration: 0.25)) { presented = false }
    }
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
    let motion: ReminderBannerMotion
    let onDismiss: () -> Void
    let onHover: (Bool) -> Void
    @State private var hovering = false
    @State private var showingReasons = false
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
                if !item.reasons.isEmpty {
                    Button { showingReasons.toggle() } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(ThemeColor.kTextSubtle)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(Text("提醒原因"))
                    .accessibilityLabel(Text("提醒原因"))
                    .popover(isPresented: $showingReasons, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("提醒原因").font(.system(size: 13, weight: .semibold))
                            ForEach(item.reasons, id: \.self) { Text("• \($0)").textStyle(.secondary) }
                        }
                        .padding(12)
                        .frame(width: 260, alignment: .leading)
                    }
                }
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
                .opacity(motion.settled ? 1 : 0)
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
        // Off-window start: the panel and the screen edge clip the card while it slides in from the right.
        // Only x changes; the animation is applied by ReminderBannerMotion so no layout change rides along.
        .offset(x: motion.presented || ReminderBannerCenter.reduceMotion ? 0 : 360 + ReminderBannerCenter.shadowInset * 2)
        .opacity(motion.presented || !ReminderBannerCenter.reduceMotion ? 1 : 0)
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
