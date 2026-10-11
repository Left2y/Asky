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
    private let dragSource = ClipboardDragSource()
    private var refreshTimer: Timer?
    private let outsideClickDismissal = OutsideClickDismissal()
    private var hiding = false
    var query = "" { didSet { selection = 0; refresh(); dismissPreview() } }
    var items: [ClipboardItem] = []
    var selection = 0
    var pinned = false { didSet { updateOutsideClickDismissal() } }
    var status: String?

    init(app: AppModel) {
        self.app = app
        panel = ClipboardPanel(contentRect: NSRect(x: 0, y: 0, width: 900, height: 244),
                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        preview = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        for window in [panel, preview] {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .floating
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        // The padded glass canvas must not acquire a rectangular system shadow.
        panel.hasShadow = SurfaceCompatibility.useLegacyMaterial
        panel.level = .normal
        panel.title = NSLocalizedString("剪贴板历史", comment: "")
        preview.title = NSLocalizedString("剪贴板完整预览", comment: "")
        panel.dismiss = { [weak self] in self?.hide() }
        panel.onOpenSettings = { [weak app] in app?.openSettings() }
        // Keyboard application switching must also release the outside-click shield.
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self, !self.pinned, !self.dragSource.active { self.hide() } }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.panel.level = .floating }
        }
    }

    private var shellFrame: NSRect {
        panel.frame.insetBy(dx: LauncherLayout.shadowPadding, dy: LauncherLayout.shadowPadding)
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
                                  width: width, height: 244)
                .insetBy(dx: -LauncherLayout.shadowPadding, dy: -LauncherLayout.shadowPadding), display: false)
        }
        panel.contentView = NSHostingView(rootView: ClipboardHistoryView(controller: self))
        panel.level = .floating
        panel.orderFrontRegardless()
        panel.makeKey()
        updateOutsideClickDismissal()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func hide() {
        guard !hiding else { return }
        hiding = true
        defer { hiding = false }
        outsideClickDismissal.hide()
        dismissPreview()
        refreshTimer?.invalidate()
        refreshTimer = nil
        panel.orderOut(nil)
        panel.contentView = nil
        items = []
    }

    private func updateOutsideClickDismissal() {
        guard panel.isVisible, !pinned, !dragSource.active else { outsideClickDismissal.hide(); return }
        outsideClickDismissal.show(below: panel, contains: { [weak self] point in
            guard let self else { return false }
            return self.shellFrame.contains(point) || (self.preview.isVisible && self.preview.frame.contains(point))
        }, dismiss: { [weak self] in self?.hide() })
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
        guard ClipboardAccess.copy(items[selection]) else { status = NSLocalizedString("无法复制：原始内容已不可用", comment: ""); return }
        hide()
        // The panel never activates Asky, so the previous app is still frontmost and receives ⌘V.
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
        status = ClipboardAccess.copy(item) ? NSLocalizedString("已复制", comment: "") : NSLocalizedString("无法复制：原始内容已不可用", comment: "")
    }

    /// AppKit drag with eagerly written pasteboard data; SwiftUI `.onDrag` promises are ignored by Chromium/Electron targets.
    func beginDrag(_ item: ClipboardItem, from view: NSView, event: NSEvent) {
        guard !dragSource.active, event.type == .leftMouseDragged else { return }
        dismissPreview()
        guard let pasteboardItem = ClipboardAccess.dragItem(for: item) else {
            status = NSLocalizedString("无法拖拽：原始内容已不可用", comment: "")
            return
        }
        copy(item)
        let dragging = NSDraggingItem(pasteboardWriter: pasteboardItem)
        dragging.setDraggingFrame(view.bounds, contents: ClipboardDragSource.snapshot(of: view))
        dragSource.active = true
        // The outside-click shields are real windows and would intercept the destination's drop.
        outsideClickDismissal.hide()
        dragSource.onEnd = { [weak self] operation in
            guard let self else { return }
            if operation != [], !self.pinned { self.hide() }
            else { self.updateOutsideClickDismissal() }
        }
        view.beginDraggingSession(with: [dragging], event: event, source: dragSource)
            .animatesToStartingPositionsOnCancelOrFail = true
    }

    func pinItem(_ item: ClipboardItem) {
        do { try ClipboardStore(app.store).setPinned(item.id, !item.pinned); refresh() }
        catch { status = NSLocalizedString("无法更新固定状态", comment: "") }
    }

    func delete(_ item: ClipboardItem) {
        do {
            let paths = try ClipboardStore(app.store).delete(ids: [item.id])
            ClipboardMonitor.removeFiles(paths)
            dismissPreview()
            refresh()
        } catch { status = NSLocalizedString("无法删除这条记录", comment: "") }
    }

    func hover(_ item: ClipboardItem, frame: NSRect, inside: Bool) {
        guard !dragSource.active else { return }
        hoverTask?.cancel()
        hoverTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(inside ? 1500 : 200))
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
        let inset = ClipboardFullPreview.inset
        var width = min(464.0, available.width)
        let contentHeight: CGFloat
        if let image {
            contentHeight = (width - 2 * inset) * image.size.height / max(1, image.size.width)
        } else {
            let text = NSAttributedString(string: item.text ?? NSLocalizedString("原始图片已不可用", comment: ""), attributes: [.font: NSFont.systemFont(ofSize: 14)])
            contentHeight = text.boundingRect(with: NSSize(width: width - 2 * ClipboardFullPreview.textInset, height: .greatestFiniteMagnitude),
                                              options: [.usesLineFragmentOrigin, .usesFontLeading]).height
                + 2 * (ClipboardFullPreview.textInset - inset)
        }
        let natural = max(80, contentHeight + 2 * inset)
        // Never overlap the panel: 8 pt below it, or above when that side has more room; shrink to fit the chosen side.
        let shell = shellFrame
        let below = shell.minY - 8 - available.minY
        let above = available.maxY - (shell.maxY + 8)
        let placeBelow = min(natural, 440) <= below || below >= above
        let height = min(natural, 440, max(80, placeBelow ? below : above))
        // Images shrink proportionally so a tall screenshot does not leave empty space around it.
        if let image, height < natural {
            width = min(width, (height - 2 * inset) * image.size.width / max(1, image.size.height) + 2 * inset)
        }
        let y = placeBelow ? shell.minY - 8 - height : shell.maxY + 8
        // Centered under the card; near an edge, align to the card's left or right edge instead.
        let bounds = NSRect(x: max(available.minX, shell.minX), y: 0,
                            width: min(available.maxX, shell.maxX) - max(available.minX, shell.minX), height: 0)
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
            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(ThemeColor.kIconSubtle)
                    LauncherSearchField(text: $controller.query, fontSize: 16,
                                        textColor: NSColor(ThemeColor.kText.color(for: scheme)),
                                        accessibilityLabel: NSLocalizedString("搜索剪贴板历史", comment: ""),
                                        placeholder: NSLocalizedString("搜索剪贴板内容", comment: ""),
                                        placeholderColor: NSColor(ThemeColor.kTextSubtlest.color(for: scheme)),
                                        backspaceOnEmpty: { false }, move: controller.moveSelection,
                                        moveHorizontal: controller.moveSelection,
                                        submit: { _ in controller.pasteSelection() })
                        .frame(height: 24)
                }
                .padding(.horizontal, 16).frame(height: 36)
                .nativeGlassBackground(in: Capsule())
                HStack(spacing: 12) {
                    ClipboardHeaderButton(symbol: controller.pinned ? "pin.fill" : "pin",
                                          title: controller.pinned ? NSLocalizedString("取消固定窗口", comment: "") : NSLocalizedString("固定窗口", comment: ""),
                                          action: controller.togglePinned)
                        .accessibilityValue(controller.pinned ? NSLocalizedString("已固定", comment: "") : NSLocalizedString("未固定", comment: ""))
                }
            }.padding(12)
            Rectangle().fill(ThemeColor.kBorder).frame(height: 1)
            if controller.items.isEmpty {
                VStack(spacing: 8) {
                    Text(controller.query.isEmpty ? NSLocalizedString("暂无剪贴板历史", comment: "") : NSLocalizedString("没有匹配的内容", comment: ""))
                    Text(NSLocalizedString("复制文字或图片后会显示在这里", comment: "")).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtlest)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(ThemeColor.kText)
        .nativeGlassBackground(in: RoundedRectangle(cornerRadius: 32))
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .floatingSurfaceShadow(in: RoundedRectangle(cornerRadius: 32))
        .overlay(alignment: .top) {
            if let status = controller.status {
                ClipboardStatusToast(message: status)
                    .padding(.horizontal, 24)
                    .visualEffect { content, geometry in
                        content.offset(y: -geometry.size.height - 12)
                    }
                    .allowsHitTesting(false)
            }
        }
        .padding(LauncherLayout.shadowPadding)
        .onExitCommand { controller.hide() }
        .accessibilityValue(controller.status ?? "")
    }

}

private struct ClipboardHeaderButton: View {
    let symbol: String
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 32, height: 32)
                .nativeGlassBackground(in: Circle(), interactive: true)
                .contentShape(.interaction, Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(ThemeColor.kIconSubtle.color(for: scheme))
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
                Text(item.text ?? NSLocalizedString("图片不可用", comment: "")).textStyle(.resultPrimary).lineLimit(4)
                    .frame(width: 232, height: 96, alignment: .topLeading).clipped()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12).frame(width: 264, height: 160)
        .nativeGlassBackground(in: RoundedRectangle(cornerRadius: 24), interactive: true)
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(ThemeColor.kBorderIntense, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .background(ClipboardAnchor { anchor = $0 })
        .contentShape(RoundedRectangle(cornerRadius: 24))
        // Read the frame at hover time: scrolling moves the card without re-laying it out.
        .onHover { inside in controller.hover(item, frame: anchor.map(ClipboardAnchor.screenFrame) ?? .zero, inside: inside) }
        .overlay(ClipboardCardMouseSurface(
            copy: { controller.copy(item) },
            drag: { view, event in controller.beginDrag(item, from: view, event: event) }
        ).clipShape(RoundedRectangle(cornerRadius: 24)))
        .contextMenu {
            Button(NSLocalizedString("复制", comment: "")) { controller.copy(item) }
            Button(item.pinned ? NSLocalizedString("取消固定", comment: "") : NSLocalizedString("固定记录", comment: "")) { controller.pinItem(item) }
            Button(NSLocalizedString("删除", comment: ""), role: .destructive) { controller.delete(item) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.kind == .image ? "\(NSLocalizedString("图片", comment: "")), \(item.sourceApp ?? NSLocalizedString("未知来源", comment: ""))" : String((item.text ?? "").prefix(200)))
        .accessibilityAction(named: NSLocalizedString("复制", comment: "")) { controller.copy(item) }
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
                    Text(item.text ?? NSLocalizedString("原始图片已不可用", comment: "")).textStyle(.resultPrimary)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(Self.textInset)
                }.scrollIndicators(.automatic)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(ThemeColor.kText)
        .nativeGlassBackground(in: RoundedRectangle(cornerRadius: Self.radius))
        .clipShape(RoundedRectangle(cornerRadius: Self.radius))
    }
}

@MainActor
final class ClipboardDragSource: NSObject, NSDraggingSource {
    var active = false
    var onEnd: (NSDragOperation) -> Void = { _ in }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        active = false
        onEnd(operation)
    }

    /// The mouse surface draws no content, so capture the card's area from the window instead.
    static func snapshot(of view: NSView) -> NSImage {
        let image = NSImage(size: view.bounds.size)
        guard let content = view.window?.contentView else { return image }
        let rect = view.convert(view.bounds, to: content)
        guard let bitmap = content.bitmapImageRepForCachingDisplay(in: rect) else { return image }
        content.cacheDisplay(in: rect, to: bitmap)
        image.addRepresentation(bitmap)
        return image
    }
}

/// Start the AppKit session inside mouseDragged, using the event delivered to the card itself.
/// SwiftUI gesture updates can run after NSApp.currentEvent has changed or been cleared.
private struct ClipboardCardMouseSurface: NSViewRepresentable {
    let copy: () -> Void
    let drag: (NSView, NSEvent) -> Void

    func makeNSView(context: Context) -> ClipboardCardMouseView { ClipboardCardMouseView() }
    func updateNSView(_ view: ClipboardCardMouseView, context: Context) {
        view.copy = copy
        view.drag = drag
    }
}

final class ClipboardCardMouseView: NSView {
    var copy: () -> Void = {}
    var drag: (NSView, NSEvent) -> Void = { _, _ in }
    private var press: NSPoint?
    private var dragged = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        press = event.locationInWindow
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragged, let press,
              hypot(event.locationInWindow.x - press.x, event.locationInWindow.y - press.y) >= 3 else { return }
        dragged = true
        drag(self, event)
    }

    override func mouseUp(with event: NSEvent) {
        if press != nil, !dragged { copy() }
        press = nil
        dragged = false
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
