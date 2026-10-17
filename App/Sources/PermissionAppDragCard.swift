import AppKit
import SwiftUI
import Theme
import ToolService

/// AppKit reports both drag start and whether the destination accepted the app.
struct PermissionAppDragCard: NSViewRepresentable {
    let onStarted: () -> Void
    let onEnded: (Bool) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeNSView(context: Context) -> PermissionCardHostingView {
        PermissionCardHostingView(rootView: card, onStarted: onStarted, onEnded: onEnded)
    }

    func updateNSView(_ view: PermissionCardHostingView, context: Context) {
        view.rootView = card
        view.onStarted = onStarted
        view.onEnded = onEnded
    }

    private var card: PermissionAppCard {
        PermissionAppCard(colorScheme: colorScheme, reduceTransparency: reduceTransparency)
    }
}

@MainActor
final class PermissionCardHostingView: NSView, NSDraggingSource {
    private let hosting: NSHostingView<PermissionAppCard>
    var rootView: PermissionAppCard {
        get { hosting.rootView }
        set { hosting.rootView = newValue }
    }
    var onStarted: () -> Void
    var onEnded: (Bool) -> Void
    private var mouseDownPoint: NSPoint?
    private var dragging = false

    init(rootView: PermissionAppCard, onStarted: @escaping () -> Void, onEnded: @escaping (Bool) -> Void) {
        self.onStarted = onStarted
        self.onEnded = onEnded
        hosting = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        hosting.autoresizingMask = [.width, .height]
        addSubview(hosting)
        wantsLayer = true
    }
    @MainActor required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize { NSSize(width: 320, height: 80) }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    override func layout() {
        super.layout()
        hosting.frame = bounds
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) { mouseDownPoint = event.locationInWindow }
    override func mouseUp(with event: NSEvent) { mouseDownPoint = nil }

    override func mouseDragged(with event: NSEvent) {
        guard !dragging, let start = mouseDownPoint,
              hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) >= 3,
              SystemPermissions.canDragApp(at: SystemPermissions.appURL),
              let image = cardSnapshot() else { return }
        let item = NSDraggingItem(pasteboardWriter: SystemPermissions.appURL as NSURL)
        item.setDraggingFrame(bounds, contents: image)
        dragging = true
        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func cardSnapshot() -> NSImage? {
        layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmap)
        return image
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) { beginCardDrag() }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        finishCardDrag(operation: operation)
    }

    // Kept separate so the native callback behavior can be checked without granting TCC access.
    func beginCardDrag() {
        alphaValue = 0
        onStarted()
    }

    func finishCardDrag(operation: NSDragOperation) {
        dragging = false
        mouseDownPoint = nil
        let accepted = !operation.isEmpty
        alphaValue = accepted ? 0 : 1
        onEnded(accepted)
    }
}

struct PermissionAppCard: View {
    let colorScheme: ColorScheme
    let reduceTransparency: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: SystemPermissions.appIcon).resizable().frame(width: 48, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("Asky.app").font(.system(size: 16, weight: .regular))
                Text(NSLocalizedString("拖拽授权", comment: ""))
                    .font(.system(size: 13)).foregroundStyle(ThemeColor.kTextSubtle)
            }
            Spacer(minLength: 0)
            Image(mingCute: "hand.draw").foregroundStyle(ThemeColor.kIconSubtle)
        }
        .padding(16)
        .foregroundStyle(ThemeColor.kText)
        .nativeGlassBackground(in: RoundedRectangle(cornerRadius: 16, style: .continuous), forceOpaque: reduceTransparency)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("Asky 应用授权卡片，拖到系统设置的应用列表", comment: ""))
        .environment(\.colorScheme, colorScheme)
    }
}
