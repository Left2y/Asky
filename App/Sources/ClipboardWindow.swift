import AppKit
import SwiftUI
import LocalStore
import ToolService
import Theme

private final class ClipboardPanel: NSPanel {
    var dismiss: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { dismiss() }

    /// Cards only scroll horizontally, so a vertical wheel/trackpad gesture scrolls them too (no Shift needed).
    override func sendEvent(_ event: NSEvent) {
        if SettingsShortcut.matches(event) { onOpenSettings(); return }
        if event.type == .scrollWheel, let converted = ClipboardScroll.horizontal(event) { super.sendEvent(converted) }
        else { super.sendEvent(event) }
    }
}

enum ClipboardScroll {
    /// Maps a mostly-vertical scroll event onto the horizontal axis; nil when it is already horizontal.
    static func horizontal(_ event: NSEvent) -> NSEvent? {
        guard abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX), let cg = event.cgEvent?.copy() else { return nil }
        // Each setter recomputes related fields, so read everything first and write the pixel delta last.
        let fixed = cg.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let line = cg.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let point = cg.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        cg.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)
        cg.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: fixed)
        cg.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
        cg.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: line)
        cg.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
        cg.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: point)
        return NSEvent(cgEvent: cg)
    }
}

@MainActor @Observable
final class ClipboardController {
    private let app: AppModel
    private let panel: ClipboardPanel
    private let preview: NSPanel
    private var hoverTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    var query = "" { didSet { selection = 0; refresh(); dismissPreview() } }
    var items: [ClipboardItem] = []
    var selection = 0
    var pinned = false
    var status: String?

    init(app: AppModel) {
        self.app = app
        panel = ClipboardPanel(contentRect: NSRect(x: 0, y: 0, width: 900, height: 244),
                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        preview = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        for window in [panel, preview] {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .floating
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        panel.level = .normal
        panel.title = "剪贴板历史"
        preview.title = "剪贴板完整预览"
        panel.dismiss = { [weak self] in self?.hide() }
        panel.onOpenSettings = { [weak app] in app?.openSettings() }
        // A non-activating panel at .normal level sits behind the frontmost app's windows,
        // so float while focused and only drop back when unpinned and focus moves elsewhere.
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self, !self.pinned { self.panel.level = .normal } }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.panel.level = .floating }
        }
    }

    func toggle() { panel.isVisible ? hide() : show() }

    func show() {
        query = ""
        status = nil
        refresh()
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let width = min(900, frame.width - 32)
            panel.setFrame(NSRect(x: frame.midX - width / 2, y: frame.maxY - frame.height * 0.16 - 244,
                                  width: width, height: 244), display: false)
        }
        panel.contentView = NSHostingView(rootView: ClipboardHistoryView(controller: self))
        panel.level = .floating
        panel.orderFrontRegardless()
        panel.makeKey()
        monitorOutsideClicks()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func hide() {
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        localClickMonitor = nil
        globalClickMonitor = nil
        dismissPreview()
        refreshTimer?.invalidate()
        refreshTimer = nil
        panel.orderOut(nil)
        panel.contentView = nil
        items = []
    }

    private func monitorOutsideClicks() {
        guard localClickMonitor == nil, globalClickMonitor == nil else { return }
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            MainActor.assumeIsolated { self?.dismissIfOutside() }
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismissIfOutside() }
        }
    }

    private func dismissIfOutside() {
        guard panel.isVisible, !pinned else { return }
        let location = NSEvent.mouseLocation
        guard !panel.frame.contains(location),
              !(preview.isVisible && preview.frame.contains(location)) else { return }
        hide()
    }

    func refresh() {
        let store = ClipboardStore(app.store)
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = value.isEmpty ? store.recent(limit: 100) : store.search(value, limit: 100)
        if next != items { items = next; selection = min(selection, max(0, next.count - 1)) }
    }

    func moveSelection(_ delta: Int) {
        guard !items.isEmpty else { return }
        selection = min(max(0, selection + delta), items.count - 1)
        dismissPreview()
    }

    func copySelection() {
        guard items.indices.contains(selection) else { return }
        copy(items[selection])
    }

    /// Return: copy the selected card, close the panel and paste into the app that was in front.
    func pasteSelection() {
        guard items.indices.contains(selection) else { return }
        guard ClipboardAccess.copy(items[selection]) else { status = "无法复制：原始内容已不可用"; return }
        hide()
        // The panel never activates KulaHere, so the previous app is still frontmost and receives ⌘V.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            _ = ClipboardAccess.pasteIntoFrontmostApp()
        }
    }

    func togglePinned() {
        pinned.toggle()
        panel.level = pinned ? .floating : .normal
        if !pinned { dismissPreview() }
    }

    func copy(_ item: ClipboardItem) {
        status = ClipboardAccess.copy(item) ? "已复制" : "无法复制：原始内容已不可用"
    }

    func drag(_ item: ClipboardItem) -> NSItemProvider {
        dismissPreview()
        guard let provider = ClipboardAccess.dragProvider(for: item) else {
            status = "无法拖拽：原始内容已不可用"
            return NSItemProvider()
        }
        copy(item)
        return provider
    }

    func pinItem(_ item: ClipboardItem) {
        do { try ClipboardStore(app.store).setPinned(item.id, !item.pinned); refresh() }
        catch { status = "无法更新固定状态" }
    }

    func delete(_ item: ClipboardItem) {
        do {
            let paths = try ClipboardStore(app.store).delete(ids: [item.id])
            ClipboardMonitor.removeFiles(paths)
            dismissPreview()
            refresh()
        } catch { status = "无法删除这条记录" }
    }

    func hover(_ item: ClipboardItem, frame: NSRect, inside: Bool) {
        hoverTask?.cancel()
        hoverTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(inside ? 300 : 200))
            guard !Task.isCancelled, let self, self.panel.isVisible else { return }
            if inside { self.showPreview(item, anchor: frame) }
            else { self.dismissPreview() }
        }
    }

    func previewHover(_ inside: Bool) {
        hoverTask?.cancel()
        if !inside {
            hoverTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                self?.dismissPreview()
            }
        }
    }

    func dismissPreview() {
        hoverTask?.cancel()
        hoverTask = nil
        preview.orderOut(nil)
        preview.contentView = nil
    }

    private func showPreview(_ item: ClipboardItem, anchor: NSRect) {
        guard let screen = panel.screen else { return }
        let image = item.filePath.flatMap { NSImage(contentsOfFile: $0) }
        let available = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let width = min(464.0, available.width)
        let maxHeight = min(440, available.height)
        let contentHeight: CGFloat
        if let image {
            contentHeight = (width - 2 * ClipboardFullPreview.inset) * image.size.height / max(1, image.size.width)
        } else {
            let text = NSAttributedString(string: item.text ?? "原始图片已不可用", attributes: [.font: NSFont.systemFont(ofSize: 14)])
            contentHeight = text.boundingRect(with: NSSize(width: width - 2 * ClipboardFullPreview.textInset, height: .greatestFiniteMagnitude),
                                              options: [.usesLineFragmentOrigin, .usesFontLeading]).height
                + 2 * (ClipboardFullPreview.textInset - ClipboardFullPreview.inset)
        }
        let height = min(max(80, contentHeight + 2 * ClipboardFullPreview.inset), maxHeight)
        // Below the panel, 8 pt gap; flip above when the screen bottom is too close.
        var y = panel.frame.minY - 8 - height
        if y < available.minY { y = panel.frame.maxY + 8 }
        y = min(max(available.minY, y), available.maxY - height)
        // Centered under the card; near an edge, align to the card's left or right edge instead.
        let bounds = NSRect(x: max(available.minX, panel.frame.minX), y: 0,
                            width: min(available.maxX, panel.frame.maxX) - max(available.minX, panel.frame.minX), height: 0)
        var x = anchor.midX - width / 2
        if x < bounds.minX { x = anchor.minX } else if x + width > bounds.maxX { x = anchor.maxX - width }
        x = min(max(available.minX, x), available.maxX - width)
        preview.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
        preview.contentView = NSHostingView(rootView: ClipboardFullPreview(item: item, image: image)
            .onHover { [weak self] in self?.previewHover($0) })
        preview.orderFrontRegardless()
    }
}

private struct ClipboardHistoryView: View {
    @Bindable var controller: ClipboardController
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 40) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(ThemeColor.kIconSubtle)
                    LauncherSearchField(text: $controller.query, fontSize: 16,
                                        textColor: NSColor(ThemeColor.kText.color(for: scheme)),
                                        accessibilityLabel: "搜索剪贴板历史",
                                        placeholder: "Search your clipboard contents",
                                        placeholderColor: NSColor(ThemeColor.kTextSubtlest.color(for: scheme)),
                                        backspaceOnEmpty: { false }, move: controller.moveSelection,
                                        moveHorizontal: controller.moveSelection,
                                        submit: { _ in controller.pasteSelection() })
                        .frame(height: 24)
                }
                .padding(.horizontal, 16).frame(height: 36)
                .background(ThemeColor.kBackground, in: Capsule())
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                HStack(spacing: 12) {
                    action(controller.pinned ? "pin.fill" : "pin", title: "固定窗口", run: controller.togglePinned)
                }
            }.padding(12)
            Rectangle().fill(ThemeColor.kBorder).frame(height: 1)
            if controller.items.isEmpty {
                VStack(spacing: 8) {
                    Text(controller.query.isEmpty ? "暂无剪贴板历史" : "没有匹配的内容")
                    Text("复制文字或图片后会显示在这里").textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtlest)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 12) {
                            ForEach(controller.items) { item in ClipboardHistoryCard(item: item, controller: controller).id(item.id) }
                        }.padding(12)
                    }.scrollIndicators(.hidden)
                    .onChange(of: controller.selection) { _, index in
                        if controller.items.indices.contains(index) { proxy.scrollTo(controller.items[index].id, anchor: .center) }
                    }
                }
            }
        }
        .foregroundStyle(ThemeColor.kText)
        .background { ClipboardGlass(radius: 32) }
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay(alignment: .bottom) {
            if let status = controller.status {
                Text(status).textStyle(.secondary).padding(.horizontal, 12).padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule()).padding(.bottom, 4)
                    .allowsHitTesting(false)
            }
        }
        .onExitCommand { controller.hide() }
        .accessibilityValue(controller.status ?? "")
    }

    private func action(_ symbol: String, title: String, run: @escaping () -> Void) -> some View {
        Button(action: run) { Image(systemName: symbol).frame(width: 32, height: 32) }
            .buttonStyle(.plain).foregroundStyle(ThemeColor.kIconSubtle)
            .background(ThemeColor.kBackground, in: Circle())
            .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
            .accessibilityLabel(title).help(title)
    }
}

private struct ClipboardHistoryCard: View {
    let item: ClipboardItem
    let controller: ClipboardController
    @State private var anchor: NSView?
    private var selected: Bool {
        controller.items.indices.contains(controller.selection) && controller.items[controller.selection].id == item.id
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let icon = ClipboardAccess.sourceIcon(bundleID: item.sourceBundleID, name: item.sourceApp) {
                    Image(nsImage: icon).resizable().frame(width: 28, height: 28)
                } else { Image(systemName: "doc.on.clipboard").frame(width: 28, height: 28) }
                Spacer()
                if item.pinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(ThemeColor.kIconSubtle) }
            }
            if item.kind == .image, let path = item.thumbPath ?? item.filePath, let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image).resizable().scaledToFill().frame(width: 232, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Text(item.text ?? "图片不可用").textStyle(.resultPrimary).lineLimit(4)
                    .frame(width: 232, height: 96, alignment: .topLeading).clipped()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12).frame(width: 264, height: 160)
        .background(ThemeColor.kBackground, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(selected ? ThemeColor.kBorderIntense : ThemeColor.kBorder, lineWidth: selected ? 2 : 1)
        }
        .background(ClipboardAnchor { anchor = $0 })
        .contentShape(RoundedRectangle(cornerRadius: 24))
        // Read the frame at hover time: scrolling moves the card without re-laying it out.
        .onHover { inside in controller.hover(item, frame: anchor.map(ClipboardAnchor.screenFrame) ?? .zero, inside: inside) }
        .onTapGesture { controller.copy(item) }
        .onDrag { controller.drag(item) }
        .contextMenu {
            Button("复制") { controller.copy(item) }
            Button(item.pinned ? "取消固定" : "固定记录") { controller.pinItem(item) }
            Button("删除", role: .destructive) { controller.delete(item) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.kind == .image ? "图片，\(item.sourceApp ?? "未知来源")" : String((item.text ?? "").prefix(200)))
        .accessibilityAction(named: "复制") { controller.copy(item) }
    }
}

private struct ClipboardFullPreview: View {
    static let radius: CGFloat = 24
    static let inset: CGFloat = 8
    static let textInset: CGFloat = 16
    let item: ClipboardItem
    let image: NSImage?
    var body: some View {
        Group {
            if let image {
                // Concentric with the outer shape: inner radius = outer radius − inset.
                Image(nsImage: image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Self.radius - Self.inset))
                    .padding(Self.inset)
            } else {
                ScrollView {
                    Text(item.text ?? "原始图片已不可用").textStyle(.resultPrimary)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(Self.textInset)
                }.scrollIndicators(.automatic)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(ThemeColor.kText)
        .background { ClipboardGlass(radius: Self.radius) }
        .clipShape(RoundedRectangle(cornerRadius: Self.radius))
        .overlay { RoundedRectangle(cornerRadius: Self.radius).stroke(ThemeColor.kBorder, lineWidth: 1) }
    }
}

private struct ClipboardGlass: View {
    let radius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var opaque
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        if opaque { shape.fill(ThemeColor.kBackground.color(for: scheme, opaque: true)) }
        else { shape.fill(ThemeColor.kBackground).glassEffect(.regular, in: shape) }
    }
}

private struct ClipboardAnchor: NSViewRepresentable {
    let attach: (NSView) -> Void
    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        DispatchQueue.main.async { attach(view) }
        return view
    }
    func updateNSView(_ view: AnchorView, context: Context) {}
    static func screenFrame(_ view: NSView) -> NSRect {
        guard let window = view.window else { return .zero }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }
    final class AnchorView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
