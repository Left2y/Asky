import AppKit
import SwiftUI
import LocalStore
import ToolService
import Theme
import AVKit
import UniformTypeIdentifiers

private final class ClipboardPanel: NSPanel {
    var dismiss: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var handleKey: (NSEvent) -> Bool = { _ in false }
    var scrollsHorizontally = true
    var onMouseDown: (NSEvent) -> Void = { _ in }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { dismiss() }

    /// Cards only scroll horizontally, so a vertical wheel/trackpad gesture scrolls them too (no Shift needed).
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown { onMouseDown(event) }
        if event.type == .keyDown, handleKey(event) { return }
        if SettingsShortcut.matches(event) { onOpenSettings(); return }
        if scrollsHorizontally, event.type == .scrollWheel, let converted = ClipboardScroll.horizontal(event) { super.sendEvent(converted) }
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

enum ClipboardFilter: String, CaseIterable, Identifiable {
    case all = "全部", image = "图片", video = "视频", text = "文本", file = "文件"
    var id: String { rawValue }
    var title: String { NSLocalizedString(rawValue, tableName: "Clipboard", comment: "Clipboard filter") }
    var icon: String {
        switch self {
        case .all: "square.stack.3d.up"
        case .image: "photo"
        case .video: "video"
        case .text: "text.document"
        case .file: "doc"
        }
    }

    func includes(_ item: ClipboardItem) -> Bool {
        if self == .all { return true }
        if item.kind == .image { return self == .image }
        if item.kind == .text { return self == .text }
        // Classify stored references without opening the files; missing originals keep their category.
        let movies = !item.filePaths.isEmpty && item.filePaths.allSatisfy {
            UTType(filenameExtension: URL(filePath: $0).pathExtension)?.conforms(to: .movie) == true
        }
        return movies ? self == .video : self == .file
    }
}

@MainActor @Observable
final class ClipboardController {
    private let app: AppModel
    private let panel: ClipboardPanel
    private let preview: NSPanel
    private var hoverTask: Task<Void, Never>?
    private var hoveredItemID: String?
    private let dragSource = ClipboardDragSource()
    private var refreshTimer: Timer?
    private let outsideClickDismissal = OutsideClickDismissal()
    private let toastPanel = SurfacePanel()
    private var toastDismissTask: Task<Void, Never>?
    private let filterPanel = SurfacePanel()
    private let actionsPanel = SurfacePanel()
    var actionSelection = 0
    var isActionsMenuPresented = false {
        didSet { updateActionsMenu(); updateOutsideClickDismissal() }
    }
    private var hiding = false
    var layout: ClipboardLayout { app.preferences.clipboardLayout }

    func updateLayout() {
        isActionsMenuPresented = false
        dismissPreview()
        panel.scrollsHorizontally = layout == .cards
        resizePanel()
        updateToast()
    }

    private func resizePanel() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let available = screen.visibleFrame.insetBy(dx: 16, dy: 16)
        let height = min(layout == .cards ? 244.0 : 560.0, available.height)
        let width = min(layout == .cards ? 900.0 : WindowMetrics.launcherWidth, available.width)
        let x = min(max(panel.frame.minX, available.minX), available.maxX - width)
        let y = max(available.minY, min(panel.frame.maxY, available.maxY) - height)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        panel.invalidateShadow()
    }

    func select(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        selection = index
    }

    var selectedItem: ClipboardItem? { items.indices.contains(selection) ? items[selection] : nil }

    var filter = ClipboardFilter.all {
        didSet { isActionsMenuPresented = false; selection = 0; refresh(); dismissPreview() }
    }
    var isFilterMenuPresented = false {
        didSet { updateFilterMenu(); updateOutsideClickDismissal() }
    }
    var query = "" { didSet { isActionsMenuPresented = false; selection = 0; refresh(); dismissPreview() } }
    var items: [ClipboardItem] = []
    var selection = 0 { didSet { if selection != oldValue { isActionsMenuPresented = false } } }
    var pinned = false { didSet { updateOutsideClickDismissal() } }
    var status: String? {
        didSet {
            toastDismissTask?.cancel()
            toastDismissTask = nil
            if status != oldValue { updateToast() }
            guard status != nil else { return }
            toastDismissTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self?.status = nil
            }
        }
    }

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
        toastPanel.ignoresMouseEvents = true
        panel.level = .normal
        panel.title = NSLocalizedString("剪贴板历史", comment: "")
        preview.title = NSLocalizedString("剪贴板完整预览", comment: "")
        panel.dismiss = { [weak self] in
            guard let self else { return }
            if self.isActionsMenuPresented { self.isActionsMenuPresented = false }
            else if self.isFilterMenuPresented { self.isFilterMenuPresented = false } else { self.hide() }
        }
        panel.onMouseDown = { [weak self] event in
            guard let self else { return }
            let moreButton = NSRect(x: self.panel.frame.width - 130, y: 0, width: 116, height: LauncherLayout.actionBarHeight)
            if !moreButton.contains(event.locationInWindow) { self.isActionsMenuPresented = false }
            guard self.isFilterMenuPresented else { return }
            let point = event.locationInWindow
            let button = NSRect(x: self.panel.frame.width - 88, y: self.panel.frame.height - 48, width: 32, height: 36)
            if !button.contains(point) { self.isFilterMenuPresented = false }
        }
        panel.handleKey = { [weak self] in self?.handleActionKey($0) ?? false }
        panel.onOpenSettings = { [weak app] in app?.openSettings() }
        // Keyboard application switching must also release the outside-click shield.
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self, !self.pinned, !self.dragSource.active { self.hide() } }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.panel.level = .floating }
        }
    }

    /// The panel frame is exactly the glass shell, so the system shadow follows it.
    private var shellFrame: NSRect { panel.frame }

    var isVisible: Bool { panel.isVisible }
    func toggle() { panel.isVisible ? hide() : show() }

    func show() {
        filter = .all
        query = ""
        status = nil
        refresh()
        // Every opening starts from the default spot; a drag only moves this session.
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let width = min(layout == .cards ? 900.0 : WindowMetrics.launcherWidth, frame.width - 32)
            panel.setFrame(NSRect(x: frame.midX - width / 2, y: frame.maxY - frame.height * 0.16 - 244,
                                  width: width, height: 244), display: false)
        }
        updateLayout()
        let host = NSHostingView(rootView: ClipboardHistoryView(controller: self))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: panel.frame.size)
        panel.contentView = WindowSurface.glassContentView(host, cornerRadius: ClipboardHistoryView.cornerRadius)
        panel.invalidateShadow()
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
        isFilterMenuPresented = false
        isActionsMenuPresented = false
        outsideClickDismissal.hide()
        dismissPreview()
        status = nil
        toastPanel.remove()
        refreshTimer?.invalidate()
        refreshTimer = nil
        panel.orderOut(nil)
        panel.contentView = nil
        items = []
    }

    private func updateOutsideClickDismissal() {
        guard panel.isVisible, (!pinned || isFilterMenuPresented || isActionsMenuPresented), !dragSource.active else { outsideClickDismissal.hide(); return }
        outsideClickDismissal.show(below: panel, contains: { [weak self] point in
            guard let self else { return false }
            return self.shellFrame.contains(point) || (self.actionsPanel.isVisible && self.actionsPanel.frame.contains(point)) || (self.filterPanel.isVisible && self.filterPanel.frame.contains(point)) || (self.preview.isVisible && self.preview.frame.contains(point))
        }, dismiss: { [weak self] in
            guard let self else { return }
            if self.pinned { self.isFilterMenuPresented = false; self.isActionsMenuPresented = false } else { self.hide() }
        })
    }

    /// The status toast is its own opaque surface centered 12 pt above the shell.
    private func updateToast() {
        guard panel.isVisible, let status else { toastPanel.remove(); return }
        let view = ClipboardStatusToast(message: status)
        let size = SurfacePanel.fittingSize(of: view, maxWidth: shellFrame.width - 48)
        toastPanel.setSurface(view, size: size, cornerRadius: ClipboardStatusToast.cornerRadius, glass: false)
        toastPanel.setFrameOrigin(NSPoint(x: shellFrame.midX - size.width / 2, y: shellFrame.maxY + 12))
        if toastPanel.parent == nil { panel.addChildWindow(toastPanel, ordered: .above) }
    }

    func toggleFilterMenu() { isActionsMenuPresented = false; isFilterMenuPresented.toggle(); dismissPreview() }

    func toggleActionsMenu() {
        guard layout == .list, selectedItem != nil else { return }
        isFilterMenuPresented = false
        actionSelection = 0
        isActionsMenuPresented.toggle()
    }

    func performSelectedAction(_ index: Int) {
        guard let item = selectedItem else { isActionsMenuPresented = false; return }
        isActionsMenuPresented = false
        if index == 0 { pinItem(item); select(items.first { $0.id == item.id } ?? item) }
        else if index == 1 { delete(item) }
    }

    func handleActionKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
        if event.keyCode == 40, modifiers == .command, layout == .list {
            toggleActionsMenu()
            return true
        }
        guard isActionsMenuPresented else { return false }
        switch event.keyCode {
        case 53: isActionsMenuPresented = false
        case 125: actionSelection = min(1, actionSelection + 1)
        case 126: actionSelection = max(0, actionSelection - 1)
        case 36, 76: performSelectedAction(actionSelection)
        default: return false
        }
        return true
    }

    private func updateActionsMenu() {
        guard isActionsMenuPresented, panel.isVisible, selectedItem != nil else { actionsPanel.remove(); return }
        actionsPanel.title = NSLocalizedString("更多", tableName: "Clipboard", comment: "")
        let view = ClipboardActionsMenu(controller: self)
        actionsPanel.setSurface(view, size: SurfacePanel.fittingSize(of: view, maxWidth: LauncherLayout.actionsMenuWidth), cornerRadius: 18)
        actionsPanel.setFrameOrigin(NSPoint(x: panel.frame.maxX - actionsPanel.frame.width - 14,
                                           y: panel.frame.minY + LauncherLayout.actionBarHeight + 4))
        panel.addChildWindow(actionsPanel, ordered: .above)
    }

    private func updateFilterMenu() {
        guard isFilterMenuPresented, panel.isVisible else { filterPanel.remove(); return }
        let view = ClipboardFilterMenu(controller: self)
        filterPanel.title = NSLocalizedString("筛选剪贴板", tableName: "Clipboard", comment: "")
        filterPanel.setSurface(view, size: SurfacePanel.fittingSize(of: view, maxWidth: 220), cornerRadius: 24)
        filterPanel.setFrameTopLeftPoint(NSPoint(x: panel.frame.maxX - 56 - filterPanel.frame.width,
                                                y: panel.frame.maxY - 52))
        panel.addChildWindow(filterPanel, ordered: .above)
    }

    func refresh() {
        let store = ClipboardStore(app.store)
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Expand the query until there are enough matches, so older categories are not hidden by 100 newer items.
        var limit = 100
        var next: [ClipboardItem]
        while true {
            let candidates = value.isEmpty ? store.recent(limit: limit) : store.search(value, limit: limit)
            next = Array(candidates.lazy.filter { self.filter.includes($0) }.prefix(100))
            if next.count == 100 || candidates.count < limit || filter == .all { break }
            limit *= 2
        }
        if next != items { isActionsMenuPresented = false; items = next; selection = min(selection, max(0, next.count - 1)) }
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
        guard let pasteboardItems = ClipboardAccess.dragItems(for: item) else {
            status = NSLocalizedString("无法拖拽：原始内容已不可用", comment: "")
            return
        }
        #if DEBUG
        if CommandLine.arguments.contains("--test-clipboard") {
            NSLog("Clipboard drag started: %@, %ld items", item.kind.rawValue, pasteboardItems.count)
        }
        #endif
        let preview = ClipboardDragSource.snapshot(of: view)
        let dragging = pasteboardItems.enumerated().map { index, writer in
            let entry = NSDraggingItem(pasteboardWriter: writer)
            entry.setDraggingFrame(view.bounds.offsetBy(dx: CGFloat(index) * 4, dy: CGFloat(index) * 4), contents: preview)
            return entry
        }
        dragSource.active = true
        // The outside-click shields are real windows and would intercept the destination's drop.
        outsideClickDismissal.hide()
        dragSource.onEnd = { [weak self] operation in
            #if DEBUG
            if CommandLine.arguments.contains("--test-clipboard") {
                NSLog("Clipboard drag ended: operation %lu", operation.rawValue)
            }
            #endif
            guard let self else { return }
            if operation != [], !self.pinned { self.hide() }
            else { self.updateOutsideClickDismissal() }
        }
        view.beginDraggingSession(with: dragging, event: event, source: dragSource)
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
        guard layout == .cards, !dragSource.active else { return }
        if inside {
            guard hoveredItemID != item.id else { return }
            hoveredItemID = item.id
        }
        else {
            guard hoveredItemID == item.id, !frame.contains(NSEvent.mouseLocation) else { return }
            hoveredItemID = nil
        }
        hoverTask?.cancel()
        hoverTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(inside ? 1000 : 200))
            guard !Task.isCancelled, let self, self.panel.isVisible else { return }
            if inside { self.showPreview(item, anchor: frame) }
            else { self.dismissPreview() }
        }
    }

    func previewHover(_ inside: Bool) {
        // SwiftUI may emit an initial exit as the preview content is installed.
        // The card still owns the hover in that case; keep its preview and timer.
        guard preview.isVisible, inside || hoveredItemID == nil else { return }
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
        hoveredItemID = nil
        hoverTask?.cancel()
        hoverTask = nil
        preview.orderOut(nil)
        preview.contentView = nil
    }

    private func showPreview(_ item: ClipboardItem, anchor: NSRect) {
        guard let screen = panel.screen else { return }
        let image = item.kind == .image ? item.filePath.flatMap { NSImage(contentsOfFile: $0) } : nil
        let available = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let inset = ClipboardFullPreview.inset
        var width = min(464.0, available.width)
        let contentHeight: CGFloat
        if let image {
            contentHeight = (width - 2 * inset) * image.size.height / max(1, image.size.width)
        } else if ClipboardAccess.videoPreviewURL(for: item) != nil {
            contentHeight = (width - 2 * inset) * 9 / 16
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
        let host = NSHostingView(rootView: ClipboardFullPreview(item: item, image: image)
            .onHover { [weak self] in self?.previewHover($0) })
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: preview.frame.size)
        preview.contentView = WindowSurface.glassContentView(host, cornerRadius: ClipboardFullPreview.radius)
        preview.invalidateShadow()
        preview.orderFrontRegardless()
    }
}

private struct ClipboardHistoryView: View {
    static let cornerRadius: CGFloat = 32
    @Bindable var controller: ClipboardController
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(mingCute: "magnifyingglass").foregroundStyle(ThemeColor.kIconSubtle)
                    LauncherSearchField(text: $controller.query, fontSize: 16,
                                        textColor: NSColor(ThemeColor.kText.color(for: scheme)),
                                        accessibilityLabel: NSLocalizedString("搜索剪贴板历史", comment: ""),
                                        placeholder: NSLocalizedString("搜索剪贴板内容", comment: ""),
                                        placeholderColor: NSColor(ThemeColor.kTextSubtlest.color(for: scheme)),
                                        backspaceOnEmpty: { false }, move: controller.moveSelection,
                                        moveHorizontal: controller.moveSelection,
                                        submit: { _ in
                                            if controller.layout == .list { controller.copySelection() }
                                            else { controller.pasteSelection() }
                                        })
                        .frame(height: 24)
                }
                .padding(.horizontal, 16).frame(height: 36)
                .nativeGlassBackground(in: Capsule())
                HStack(spacing: 12) {
                    ClipboardHeaderButton(symbol: "line.3.horizontal.decrease",
                                          title: NSLocalizedString("筛选剪贴板", tableName: "Clipboard", comment: ""),
                                          action: controller.toggleFilterMenu,
                                          selected: controller.filter != .all || controller.isFilterMenuPresented)
                        .accessibilityValue(controller.filter.title)
                    ClipboardHeaderButton(symbol: controller.pinned ? "pin.fill" : "pin",
                                          title: controller.pinned ? NSLocalizedString("取消固定窗口", comment: "") : NSLocalizedString("固定窗口", comment: ""),
                                          action: controller.togglePinned)
                        .accessibilityValue(controller.pinned ? NSLocalizedString("已固定", comment: "") : NSLocalizedString("未固定", comment: ""))
                }
            }
            .padding(12)
            // The header gaps drag the panel, like the agent window's title bar.
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
            .allowsWindowActivationEvents()
            Rectangle().fill(ThemeColor.kBorder).frame(height: 1)
            if controller.items.isEmpty {
                VStack(spacing: 8) {
                    Text(controller.query.isEmpty && controller.filter == .all ? NSLocalizedString("暂无剪贴板历史", comment: "") : NSLocalizedString("没有匹配的内容", comment: ""))
                    Text(NSLocalizedString("复制文字或图片后会显示在这里", comment: "")).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtlest)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if controller.layout == .list {
                ClipboardListView(controller: controller)
                ClipboardActionBar(controller: controller)
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
        .windowSurfaceBackground(in: RoundedRectangle(cornerRadius: Self.cornerRadius))
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        .onChange(of: controller.layout) { _, _ in controller.updateLayout() }
        .onExitCommand {
            if controller.isActionsMenuPresented { controller.isActionsMenuPresented = false }
            else if controller.isFilterMenuPresented { controller.isFilterMenuPresented = false } else { controller.hide() }
        }
    }

}

private struct ClipboardActionBar: View {
    let controller: ClipboardController

    var body: some View {
        HStack {
            Button { controller.copySelection() } label: {
                label("复制到剪贴板", icon: "ChatCopy", shortcut: "↩")
            }
            .buttonStyle(LauncherActionButtonStyle())
            Spacer(minLength: 12)
            Button { controller.toggleActionsMenu() } label: {
                label("更多", shortcut: "⌘ K")
            }
            .buttonStyle(LauncherActionButtonStyle())
            .accessibilityValue(controller.isActionsMenuPresented ? "On" : "Off")
        }
        .disabled(controller.selectedItem == nil)
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .frame(height: LauncherLayout.actionBarHeight, alignment: .bottom)
    }

    private func label(_ title: String, icon: String? = nil, shortcut: String) -> some View {
        HStack(spacing: 8) {
            if let icon { Image(icon).resizable().renderingMode(.template).scaledToFit().frame(width: 14, height: 14) }
            Text(NSLocalizedString(title, tableName: "Clipboard", comment: "Clipboard action"))
            LauncherActionKeyCap(value: shortcut)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 12)
        .frame(height: 32)
        .contentShape(Capsule())
    }
}

private struct ClipboardActionsMenu: View {
    @Bindable var controller: ClipboardController
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<2) { index in
                Button { controller.performSelectedAction(index) } label: {
                    HStack(spacing: 10) {
                        Image(mingCute: index == 0 ? "pin" : "trash", size: 16).frame(width: 20)
                        Text(NSLocalizedString(index == 0 ? (controller.selectedItem?.pinned == true ? "Unpin" : "Pin") : "删除记录", tableName: "Clipboard", comment: "Clipboard action"))
                        Spacer(minLength: 8)
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(controller.actionSelection == index ? ThemeColor.kInteractionHover.color(for: scheme) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10))
                .onHover { if $0 { controller.actionSelection = index } }
                .accessibilityAddTraits(controller.actionSelection == index ? .isSelected : [])
            }
        }
        .padding(8)
        .frame(width: LauncherLayout.actionsMenuWidth)
        .foregroundStyle(ThemeColor.kText)
        .windowSurfaceBackground(in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ClipboardFilterMenu: View {
    @Bindable var controller: ClipboardController
    @State private var hoveredFilter: ClipboardFilter?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 4) {
            ForEach(ClipboardFilter.allCases) { filter in
                Button {
                    controller.filter = filter
                    controller.isFilterMenuPresented = false
                } label: {
                    HStack(spacing: 12) {
                        Image(mingCute: filter.icon).frame(width: 22)
                        Text(filter.title)
                        Spacer()
                        if controller.filter == filter { Image(mingCute: "checkmark") }
                    }
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(controller.filter == filter || hoveredFilter == filter ? ThemeColor.kInteractionHover.color(for: scheme) : .clear,
                            in: RoundedRectangle(cornerRadius: 12))
                .onHover { hoveredFilter = $0 ? filter : nil }
                .accessibilityValue(controller.filter == filter ? "On" : "Off")
            }
        }
        .padding(8)
        .frame(width: 220)
        .foregroundStyle(ThemeColor.kText.color(for: scheme))
        .windowSurfaceBackground(in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct ClipboardHeaderButton: View {
    let symbol: String
    let title: String
    let action: () -> Void
    var selected = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Image(mingCute: symbol)
                .frame(width: 32, height: 32)
                .contentShape(.interaction, Circle())
        }
        .buttonStyle(LauncherActionButtonStyle())
        .foregroundStyle(selected ? ThemeColor.kText.color(for: scheme) : ThemeColor.kIconSubtle.color(for: scheme))
        .accessibilityLabel(title).help(title)
    }
}

private struct ClipboardHistoryCard: View {
    let item: ClipboardItem
    let controller: ClipboardController
    @State private var hovering = false
    private var selected: Bool {
        controller.items.indices.contains(controller.selection) && controller.items[controller.selection].id == item.id
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let icon = ClipboardAccess.sourceIcon(bundleID: item.sourceBundleID, name: item.sourceApp) {
                    Image(nsImage: icon).resizable().frame(width: 28, height: 28)
                } else { Image(mingCute: "doc.on.clipboard").frame(width: 28, height: 28) }
                Spacer()
                if item.pinned { Image(mingCute: "pin.fill", size: 12).foregroundStyle(ThemeColor.kIconSubtle).opacity(hovering ? 0 : 1) }
            }
            if item.kind == .image, let path = item.thumbPath ?? item.filePath, let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image).resizable().scaledToFill().frame(width: 232, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else if item.kind == .file {
                HStack(alignment: .top, spacing: 8) {
                    if let icon = ClipboardAccess.fileIcon(for: item) {
                        Image(nsImage: icon).resizable().frame(width: 32, height: 32)
                    }
                    Text(item.text ?? item.filePaths.map { URL(filePath: $0).lastPathComponent }.joined(separator: "\n"))
                        .textStyle(.resultPrimary).lineLimit(4)
                }.frame(width: 232, height: 96, alignment: .topLeading).clipped()
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
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .overlay(ClipboardCardMouseSurface(
            copy: { controller.copy(item) },
            hover: { view, inside in controller.hover(item, frame: ClipboardAnchor.screenFrame(view), inside: inside) },
            drag: { view, event in controller.beginDrag(item, from: view, event: event) }
        ).clipShape(RoundedRectangle(cornerRadius: 24)))
        .overlay(alignment: .topTrailing) {
            SettingsMoreMenu { cardActions }
                .accessibilityLabel(NSLocalizedString("更多", tableName: "Clipboard", comment: ""))
                .opacity(hovering ? 1 : 0)
                .allowsHitTesting(hovering)
                .accessibilityHidden(!hovering)
                .padding(.top, 12)
                .padding(.trailing, 16)
        }
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.kind == .image ? "\(NSLocalizedString("图片", comment: "")), \(item.sourceApp ?? NSLocalizedString("未知来源", comment: ""))" : String((item.text ?? "").prefix(200)))
        .accessibilityAction(named: NSLocalizedString("复制", comment: "")) { controller.copy(item) }
    }

    @ViewBuilder private var cardActions: some View {
        Button(NSLocalizedString("复制", comment: "")) { controller.copy(item) }
        Button(item.pinned ? NSLocalizedString("取消固定", comment: "") : NSLocalizedString("固定记录", comment: "")) { controller.pinItem(item) }
        Button(NSLocalizedString("删除", comment: ""), role: .destructive) { controller.delete(item) }
    }

}

private struct ClipboardListView: View {
    let controller: ClipboardController

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: LauncherLayout.rowSpacing) {
                        ForEach(controller.items) { item in
                            ClipboardHistoryRow(item: item, controller: controller).id(item.id)
                        }
                    }.padding(.horizontal, LauncherLayout.listHorizontalPadding)
                        .padding(.vertical, LauncherLayout.listBottomPadding)
                }
                .onChange(of: controller.selection) { _, _ in
                    if let item = controller.selectedItem { proxy.scrollTo(item.id, anchor: .center) }
                }
                .onAppear {
                    if let item = controller.selectedItem { proxy.scrollTo(item.id, anchor: .center) }
                }
            }
            .frame(width: 272)
            Rectangle().fill(ThemeColor.kBorder).frame(width: 1)
            if let item = controller.selectedItem {
                ClipboardListDetail(item: item).id(item.id)
            }
        }
    }
}

private struct ClipboardHistoryRow: View {
    let item: ClipboardItem
    let controller: ClipboardController
    @State private var hovering = false
    private var selected: Bool { controller.selectedItem?.id == item.id }
    private var title: String {
        if item.kind == .image { return NSLocalizedString("图片", comment: "") }
        return item.text ?? item.filePaths.map { URL(filePath: $0).lastPathComponent }.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if item.kind == .image, let path = item.thumbPath ?? item.filePath, let image = NSImage(contentsOfFile: path) {
                    Image(nsImage: image).resizable().scaledToFill()
                } else if item.kind == .text {
                    Image(mingCute: "doc.on.clipboard", size: 18)
                        .foregroundStyle(ThemeColor.kIconSubtle)
                        .frame(width: LauncherLayout.rowIconSize, height: LauncherLayout.rowIconSize)
                        .background(ThemeColor.kBackgroundNeutral, in: RoundedRectangle(cornerRadius: 6))
                } else if let icon = ClipboardAccess.fileIcon(for: item) {
                    Image(nsImage: icon).resizable().scaledToFit()
                } else {
                    Image(mingCute: item.kind == .file ? "doc" : "text.document", size: 18)
                        .foregroundStyle(ThemeColor.kIconSubtle)
                }
            }
            .frame(width: LauncherLayout.rowIconSize, height: LauncherLayout.rowIconSize).clipShape(RoundedRectangle(cornerRadius: 6))
            Text(title.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 14)).foregroundStyle(ThemeColor.kText).lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if item.pinned { Image(mingCute: "pin.fill", size: 12).foregroundStyle(ThemeColor.kIconSubtle) }
        }
        .padding(.horizontal, LauncherLayout.rowHorizontalPadding)
        .frame(height: LauncherLayout.rowHeight)
        .background(hovering ? AnyShapeStyle(ThemeColor.kInteractionHover) :
                        selected ? AnyShapeStyle(ThemeColor.kBackgroundSelected) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: LauncherLayout.rowCornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: LauncherLayout.rowCornerRadius))
        .overlay(ClipboardCardMouseSurface(
            copy: { controller.copy(item) },
            select: { controller.select(item) }, requiresDoubleClick: true,
            hover: { _, inside in hovering = inside },
            drag: { view, event in controller.select(item); controller.beginDrag(item, from: view, event: event) }
        ).clipShape(RoundedRectangle(cornerRadius: LauncherLayout.rowCornerRadius)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : [.isButton])
        .accessibilityAction { controller.select(item) }
        .accessibilityAction(named: NSLocalizedString("复制", comment: "")) { controller.copy(item) }
    }
}

private struct ClipboardListDetail: View {
    let item: ClipboardItem
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                if item.kind == .image, let path = item.filePath, let image = NSImage(contentsOfFile: path) {
                    Image(nsImage: image).resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
                } else if let url = ClipboardAccess.videoPreviewURL(for: item) {
                    ClipboardVideoPreview(url: url).id(url)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
                } else if item.kind == .file, let icon = ClipboardAccess.fileIcon(for: item) {
                    VStack(spacing: 16) {
                        Image(nsImage: icon).resizable().scaledToFit()
                            .frame(width: 160, height: 160)
                        Text(item.filePaths.map { URL(filePath: $0).lastPathComponent }.joined(separator: "\n"))
                            .textStyle(.resultPrimary).textSelection(.enabled)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 24)
                } else {
                    ScrollView {
                        Text(item.text ?? (item.kind == .image ? NSLocalizedString("原始图片已不可用", comment: "") : item.filePaths.joined(separator: "\n")))
                            .textStyle(.resultPrimary).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.horizontal, 24)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(ThemeColor.kBorder).frame(height: 1).padding(.horizontal, 24)
            ClipboardInformation(item: item).padding(.horizontal, 24)
        }
        // Inset the content, not the scroll viewport, so the native scroller stays at the pane edge.
        .padding(.vertical, 24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipboardInformation: View {
    let item: ClipboardItem
    private func label(_ key: String) -> String { NSLocalizedString(key, tableName: "Clipboard", comment: "") }

    var body: some View {
        let info = ClipboardAccess.information(for: item)
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    Text(label("来源"))
                    HStack(spacing: 6) {
                        if let icon = ClipboardAccess.sourceIcon(bundleID: item.sourceBundleID, name: item.sourceApp) {
                            Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                        }
                        Text(item.sourceApp ?? NSLocalizedString("未知来源", comment: ""))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .gridColumnAlignment(.trailing)
                }
                GridRow {
                    Text(label("类型"))
                    Text(info.typeName ?? label(item.kind == .image ? "图片" : item.kind == .file ? "文件" : "文本"))
                }
                GridRow {
                    Text(label("尺寸"))
                    Text(info.pixelDimensions ?? "—")
                }
                GridRow {
                    Text(label("大小"))
                    Text(info.byteSize.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "—")
                }
                GridRow {
                    Text(label("复制时间"))
                    Text(item.createdAt, format: .dateTime.year().month().day().hour().minute())
                }
            }
            .multilineTextAlignment(.trailing)
            .font(.system(size: 14))
            .foregroundStyle(ThemeColor.kTextSubtlest)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            } else if let url = ClipboardAccess.videoPreviewURL(for: item) {
                ClipboardVideoPreview(url: url).id(url)
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
        .windowSurfaceBackground(in: RoundedRectangle(cornerRadius: Self.radius))
        .clipShape(RoundedRectangle(cornerRadius: Self.radius))
    }
}

/// AVKit leaves extra space below its movable floating controls by default.
/// Locate the native glass surface using public AppKit types, and align its
/// bottom gap with its horizontal gap without replacing the playback controls.
private final class ClipboardPlayerView: AVPlayerView {
    private var controlsBottom: NSLayoutConstraint?
    private var controlsLayoutObserver: CFRunLoopObserver?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let controlsLayoutObserver { CFRunLoopObserverInvalidate(controlsLayoutObserver) }
        controlsLayoutObserver = nil
        guard window != nil else { return }
        // AVKit creates its pane asynchronously. Resolve its position at the
        // end of the event cycle, before the window server receives the frame.
        let observer = CFRunLoopObserverCreateWithHandler(nil,
            CFRunLoopActivity.beforeWaiting.rawValue, true, 0) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.alignFloatingControls() }
            }
        controlsLayoutObserver = observer
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    override func layout() {
        super.layout()
        // AVKit lays out the floating pane below this view in its hierarchy.
        // Resolve that layout before locating and positioning its glass surface.
        subviews.forEach { $0.layoutSubtreeIfNeeded() }
        alignFloatingControls()
    }

    private func alignFloatingControls() {
        guard controlsStyle == .floating,
              let glass = glassSurface(in: self) else { return }
        var controls: NSView = glass
        while let parent = controls.superview, parent !== self,
              abs(parent.bounds.height - controls.frame.height) < 0.5 {
            controls = parent
        }
        guard let container = controls.superview, container !== self,
              controls.bounds.height > 0, controls.bounds.height < container.bounds.height else { return }
        let frame = convert(controls.bounds, from: controls)
        let inset = max(8, (bounds.width - frame.width) / 2)
        if controlsBottom?.firstItem as? NSView !== controls {
            controlsBottom?.isActive = false
            let constraint = controls.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset)
            // Override AVKit's low-priority movable position, preserving its
            // required minimum margins and compact-height fallback.
            constraint.priority = .defaultHigh
            constraint.isActive = true
            controlsBottom = constraint
        } else if abs((controlsBottom?.constant ?? 0) + inset) > 0.5 {
            controlsBottom?.constant = -inset
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            container.layoutSubtreeIfNeeded()
        }
    }

    private func glassSurface(in view: NSView) -> NSView? {
        if #available(macOS 26.0, *), view is NSGlassEffectView,
           view.bounds.width > 100, view.bounds.height >= 40 { return view }
        return view.subviews.lazy.compactMap { self.glassSurface(in: $0) }.first
    }
}

/// Keep playback local to the visible preview and release its asset when removed.
private struct ClipboardVideoPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = ClipboardPlayerView()
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.player = AVPlayer(url: url)
        return view
    }

    // The native player's intrinsic height changes when floating controls appear.
    // Always accept the preview's proposed size so controls cannot shrink the video.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: AVPlayerView, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height,
              width.isFinite, height.isFinite else { return nil }
        return CGSize(width: width, height: height)
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {}

    static func dismantleNSView(_ view: AVPlayerView, coordinator: ()) {
        view.player?.pause()
        view.player?.replaceCurrentItem(with: nil)
        view.player = nil
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
    var select: () -> Void = {}
    var requiresDoubleClick = false
    let hover: (NSView, Bool) -> Void
    let drag: (NSView, NSEvent) -> Void

    func makeNSView(context: Context) -> ClipboardCardMouseView { ClipboardCardMouseView() }
    func updateNSView(_ view: ClipboardCardMouseView, context: Context) {
        view.select = select
        view.requiresDoubleClick = requiresDoubleClick
        view.copy = copy
        view.hover = hover
        view.drag = drag
    }
}

final class ClipboardCardMouseView: NSView {
    var select: () -> Void = {}
    var requiresDoubleClick = false
    var copy: () -> Void = {}
    var hover: (NSView, Bool) -> Void = { _, _ in }
    private var hoverTracking: NSTrackingArea?
    var drag: (NSView, NSEvent) -> Void = { _, _ in }
    private var press: NSPoint?
    private var dragged = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    // The drag overlay receives pointer hits, so it must own hover tracking too.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // inVisibleRect follows scrolling/resizing without rebuilding the area.
        guard hoverTracking == nil else { return }
        let tracking = NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(tracking)
        hoverTracking = tracking
    }

    override func mouseEntered(with event: NSEvent) { hover(self, true) }
    override func mouseExited(with event: NSEvent) { hover(self, false) }

    override func mouseDown(with event: NSEvent) {
        press = event.locationInWindow
        dragged = false
        select()
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragged, let press,
              hypot(event.locationInWindow.x - press.x, event.locationInWindow.y - press.y) >= 3 else { return }
        dragged = true
        drag(self, event)
    }

    override func mouseUp(with event: NSEvent) {
        if press != nil, !dragged, !requiresDoubleClick || event.clickCount == 2 { copy() }
        press = nil
        dragged = false
    }
}

@MainActor
private enum ClipboardAnchor {
    static func screenFrame(_ view: NSView) -> NSRect {
        guard let window = view.window else { return .zero }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }
}
