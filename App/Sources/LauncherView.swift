import AppKit
import SwiftUI
import Contracts
import Theme
import Router

private enum LauncherLayout {
    // Figma Field 22:348: 720 × 60, 24/20 insets, 12 gap, 17 pt SF Symbol.
    static let inputHeight: CGFloat = 60
    static let inputLeadingPadding: CGFloat = 24
    static let inputTrailingPadding: CGFloat = 20
    static let inputSpacing: CGFloat = 12
    static let searchIconSize: CGFloat = 17
    static let expandedCornerRadius = CGFloat(Radius.values["radius32"] ?? 32)
    static let dividerHeight: CGFloat = 1
    static let rowHeight: CGFloat = 44
    static let rowSpacing: CGFloat = 2
    static let listHorizontalPadding: CGFloat = 12
    static let listVerticalPadding: CGFloat = 10
    static let rowHorizontalPadding: CGFloat = 12
}

/// Floating, non-activating launcher panel that still takes key focus for the input field.
final class LauncherPanel: NSPanel {
    var onEscape: () -> Void = {}

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: WindowMetrics.launcherWidth, height: LauncherLayout.inputHeight),
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        // Liquid Glass supplies a shape-aware shadow; the borderless panel's
        // rectangular shadow otherwise shows through at the capsule corners.
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape() }
    override func resignKey() {
        super.resignKey()
        onEscape()
    }
}

@MainActor
final class LauncherController {
    private let panel = LauncherPanel()
    private let model: LauncherModel
    private var hosting: NSHostingView<AnyView>?
    private var contentID = UUID()
    private var hiding = false

    init(model: LauncherModel) {
        self.model = model
        panel.onEscape = { [weak self] in self?.hide() }
        model.onHide = { [weak self] in self?.hide() }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        model.rebuildProviders()
        if hosting == nil {
            let id = UUID()
            contentID = id
            let view = NSHostingView(rootView: AnyView(LauncherView(model: model) { [weak self] height in
                // Resize after SwiftUI's layout pass, and ignore callbacks from a hidden tree.
                Task { @MainActor [weak self] in
                    guard let self, self.contentID == id, self.hosting != nil else { return }
                    self.resize(to: height)
                }
            }))
            // The controller owns the window frame; preferredContentSize alone does not resize it.
            view.sizingOptions = []
            panel.contentView = view
            hosting = view
        }
        // Screen with the mouse pointer (multi-display), upper third.
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            let w = WindowMetrics.launcherWidth
            panel.setFrameTopLeftPoint(NSPoint(x: f.midX - w / 2, y: f.maxY - f.height * 0.22))
        }
        panel.makeKeyAndOrderFront(nil)
    }

    private func resize(to contentHeight: CGFloat) {
        let height = min(WindowMetrics.launcherMaxHeight, max(LauncherLayout.inputHeight, ceil(contentHeight)))
        var frame = panel.frame
        guard frame.height != height else { return }
        // AppKit's origin is at the bottom left. Keep the input anchored while expanding down.
        frame.origin.y = frame.maxY - height
        frame.size.height = height
        panel.setFrame(frame, display: true)
    }

    /// Hiding releases the SwiftUI tree and the result payloads (panel resource scope).
    func hide() {
        guard panel.isVisible, !hiding else { return }
        hiding = true
        defer { hiding = false }
        panel.orderOut(nil)
        contentID = UUID()
        model.reset()
        panel.contentView = nil
        hosting = nil
    }
}

struct LauncherView: View {
    private static let searchPlaceholder = "Search"
    @Bindable var model: LauncherModel
    var onHeightChange: (CGFloat) -> Void = { _ in }
    @FocusState private var focused: Bool
    @State private var statusHeight: CGFloat = 0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private var shellShape: AnyShape {
        if model.terminal != nil || !model.results.isEmpty || model.status != nil {
            AnyShape(RoundedRectangle(cornerRadius: LauncherLayout.expandedCornerRadius, style: .continuous))
        } else {
            // The design system's radius99999 maps to a real capsule.
            AnyShape(Capsule())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: LauncherLayout.inputSpacing) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: LauncherLayout.searchIconSize, weight: .regular))
                    .foregroundStyle(ThemeColor.kTextSubtle.color(for: colorScheme))
                    .frame(width: 21, height: 22)
                TextField(Self.searchPlaceholder, text: $model.query,
                          prompt: Text(Self.searchPlaceholder).foregroundStyle(ThemeColor.kTextSubtlest.color(for: colorScheme)))
                    .textFieldStyle(.plain)
                    .textStyle(.input)
                    .tint(ThemeColor.kIcon.color(for: colorScheme))
                    .accessibilityLabel("搜索应用、文件、标签页或命令")
                    .focused($focused)
                    .onSubmit { model.submit(.executeSelection) }
                    .onKeyPress(.upArrow) { model.move(-1); return .handled }
                    .onKeyPress(.downArrow) { model.move(1); return .handled }
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.command) else { return .ignored }
                        model.submit(.submitToAI)
                        return .handled
                    }
            }
            .padding(.leading, LauncherLayout.inputLeadingPadding)
            .padding(.trailing, LauncherLayout.inputTrailingPadding)
            .frame(height: LauncherLayout.inputHeight)

            if let t = model.terminal {
                Divider().frame(height: LauncherLayout.dividerHeight)
                TerminalOutputView(session: t, stop: model.stopTerminal)
            } else if !model.results.isEmpty {
                Divider().frame(height: LauncherLayout.dividerHeight)
                ResultList(model: model, maxHeight: WindowMetrics.launcherMaxHeight
                           - LauncherLayout.inputHeight - LauncherLayout.dividerHeight - statusHeight)
            }
            if let s = model.status {
                Text(s).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, LauncherLayout.inputLeadingPadding)
                    .padding(.trailing, LauncherLayout.inputTrailingPadding).padding(.vertical, 8)
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { statusHeight = $0 }
            }
        }
        .frame(width: WindowMetrics.launcherWidth)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(ThemeColor.kText.color(for: colorScheme))
        .background {
            // A normal alpha fill preserves both theme modes without re-blending
            // pixels sampled from windows behind this transparent panel.
            shellShape.fill(ThemeColor.kBackground.color(for: colorScheme, opaque: reduceTransparency))
        }
        // Use the native frosted material to keep underlying window text from
        // competing with the input. Do not blend a fill into the sampled backdrop.
        .glassEffect(reduceTransparency ? .identity : .regular, in: shellShape)
        // Glass highlights alone disappear over light backdrops. Keep a semantic
        // outline above the material, inset so the panel does not clip its edge.
        .overlay {
            shellShape
                .stroke(ThemeColor.kBorderFocused.color(for: colorScheme),
                        lineWidth: CGFloat(BorderWidth.values["borderWidth1"] ?? 1))
                .padding(0.5)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: onHeightChange)
        .onChange(of: model.status) { _, status in
            if status == nil { statusHeight = 0 }
        }
        .onAppear { focused = true }
    }
}

private struct ResultList: View {
    @Bindable var model: LauncherModel
    let maxHeight: CGFloat

    private var height: CGFloat {
        let count = model.results.count
        let rows = CGFloat(count) * LauncherLayout.rowHeight
        let gaps = CGFloat(max(0, count - 1)) * LauncherLayout.rowSpacing
        return min(rows + gaps + LauncherLayout.listVerticalPadding * 2, maxHeight)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: LauncherLayout.rowSpacing) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { i, r in
                        ResultRow(result: r, selected: i == model.selection)
                            .id(i)
                            .contentShape(Rectangle())
                            .onTapGesture { model.selection = i; model.submit(.executeSelection) }
                    }
                }
                .padding(.horizontal, LauncherLayout.listHorizontalPadding)
                .padding(.vertical, LauncherLayout.listVerticalPadding)
            }
            .frame(height: height)
            .onChange(of: model.selection) { _, s in proxy.scrollTo(s) }
        }
    }
}

private struct ResultRow: View {
    let result: SearchResult
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            icon.frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title).textStyle(.resultPrimary).lineLimit(1)
                if !result.subtitle.isEmpty {
                    Text(result.subtitle).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LauncherLayout.rowHorizontalPadding)
        .frame(height: LauncherLayout.rowHeight)
        .background(selected ? AnyShapeStyle(ThemeColor.kBackgroundSelected) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private var icon: some View {
        switch result.source {
        case .app, .file:
            Image(nsImage: NSWorkspace.shared.icon(forFile: result.target.identifier)).resizable()
        default:
            Image(systemName: Self.symbol(result.source)).foregroundStyle(ThemeColor.kIcon)
        }
    }

    static func symbol(_ s: SearchSource) -> String {
        switch s {
        case .chromeTab: "globe"
        case .clipboard: "doc.on.clipboard"
        case .keyword: "link"
        case .calculator: "equal.square"
        case .conversion: "arrow.left.arrow.right"
        case .currency: "dollarsign.arrow.circlepath"
        case .terminal: "terminal"
        case .shortcut: "square.stack.3d.up"
        case .askAI: "sparkles"
        case .app, .file: "doc"
        }
    }
}

private struct TerminalOutputView: View {
    let session: TerminalSession
    let stop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("> \(session.command)").font(.system(.body, design: .monospaced)).lineLimit(1)
                Spacer()
                if session.handedOff {
                    Text("已转到“终端”").textStyle(.secondary)
                } else if let code = session.exitCode {
                    Text("退出码 \(code)").textStyle(.secondary)
                        .foregroundStyle(code == 0 ? ThemeColor.kTextPositive : ThemeColor.kTextNegative)
                } else {
                    Button("停止", action: stop)
                }
            }
            ScrollView {
                Text(session.output.isEmpty ? " " : session.output)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 260)
            if let spilled = session.spilled {
                Button("完整输出已保存：\(spilled.lastPathComponent)") { NSWorkspace.shared.activateFileViewerSelecting([spilled]) }
                    .buttonStyle(.link)
            }
        }
        .padding(12)
    }
}
