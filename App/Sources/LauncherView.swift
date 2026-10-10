import AppKit
import SwiftUI
import Contracts
import Theme
import Router
import ToolService

private enum LauncherLayout {
    // Keep empty and populated fields aligned to the populated search layout.
    static let topInsetFraction: CGFloat = 0.12
    static let bottomClearance: CGFloat = 24
    static let inputHeight: CGFloat = 64
    static let inputLeadingPadding: CGFloat = 28
    static let inputTrailingPadding: CGFloat = 28
    static let inputSpacing: CGFloat = 12
    static let searchIconSize: CGFloat = 17
    // Figma blur 80 maps to a 40 pt shadow radius. Reserve three radii
    // around the shell so the transparent NSPanel does not clip the falloff.
    static let shadowRadius: CGFloat = 40
    static let shadowOffsetY: CGFloat = 12
    static let shadowPadding: CGFloat = 132
    static let expandedCornerRadius = CGFloat(Radius.values["radius32"] ?? 32)
    static let dividerHeight: CGFloat = 1
    // Figma Spotlight Item 38:461: 694 × 50, 32 pt icon, 16 pt radius.
    static let rowHeight: CGFloat = 50
    static let maxVisibleResults = 6
    static let sectionHeaderHeight: CGFloat = 52
    static let rowSpacing: CGFloat = 0
    static let listHorizontalPadding: CGFloat = 13
    static let listBottomPadding: CGFloat = 12
    static let rowHorizontalPadding: CGFloat = 16
    static let rowCornerRadius = CGFloat(Radius.values["radius16"] ?? 16)
}

/// Floating, non-activating launcher panel that still takes key focus for the input field.
final class LauncherPanel: NSPanel {
    var onEscape: () -> Void = {}
    var onBlur: () -> Void = {}

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0,
                                      width: WindowMetrics.launcherWidth + LauncherLayout.shadowPadding * 2,
                                      height: LauncherLayout.inputHeight + LauncherLayout.shadowPadding * 2),
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        // The SwiftUI shell supplies the shadow; avoid a rectangular window shadow.
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
        onBlur()
    }
}

@MainActor
final class LauncherController {
    private let panel = LauncherPanel()
    private let model: LauncherModel
    private var hosting: NSHostingView<AnyView>?
    private var contentID = UUID()
    private var hiding = false
    private var availableShellHeight = CGFloat(WindowMetrics.launcherMaxHeight)

    init(model: LauncherModel) {
        self.model = model
        panel.onEscape = { [weak self] in
            guard let self else { return }
            if self.model.commandInput != nil { self.model.leaveCommand() }
            else { self.hide() }
        }
        panel.onBlur = { [weak self] in self?.hide() }
        model.onHide = { [weak self] in self?.hide() }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        model.rebuildProviders()
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            availableShellHeight = min(CGFloat(WindowMetrics.launcherMaxHeight), floor(f.height * (1 - LauncherLayout.topInsetFraction) - LauncherLayout.bottomClearance))
        }
        if hosting == nil {
            let id = UUID()
            contentID = id
            let view = NSHostingView(rootView: AnyView(LauncherView(model: model, maxShellHeight: availableShellHeight) { [weak self] height in
                // Resize after SwiftUI's layout pass, and ignore callbacks from a hidden tree.
                Task { @MainActor [weak self] in
                    guard let self, self.contentID == id, self.hosting != nil else { return }
                    self.resize(to: height)
                }
            }
            // Layout changes before the asynchronous panel resize. Pin the shell
            // to the top of the current host rather than centering it for a frame.
            .frame(maxHeight: .infinity, alignment: .top)))
            // The controller owns the window frame; preferredContentSize alone does not resize it.
            view.sizingOptions = []
            panel.contentView = view
            hosting = view
        }
        // Anchor near the top of the pointer screen, leaving room for results below.
        if let f = screen?.visibleFrame {
            let w = WindowMetrics.launcherWidth + LauncherLayout.shadowPadding * 2
            panel.setFrameTopLeftPoint(NSPoint(x: f.midX - w / 2,
                                              y: f.maxY - f.height * LauncherLayout.topInsetFraction + LauncherLayout.shadowPadding))
        }
        panel.makeKeyAndOrderFront(nil)
    }

    private func resize(to contentHeight: CGFloat) {
        let shadowSpace = LauncherLayout.shadowPadding * 2
        let height = min(availableShellHeight + shadowSpace,
                         max(LauncherLayout.inputHeight + shadowSpace, ceil(contentHeight)))
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
    @Bindable var model: LauncherModel
    var maxShellHeight: CGFloat = CGFloat(WindowMetrics.launcherMaxHeight)
    var onHeightChange: (CGFloat) -> Void = { _ in }
    @State private var statusHeight: CGFloat = 0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private var shellShape: AnyShape {
        if hasInput || model.terminal != nil || !model.results.isEmpty || model.status != nil {
            AnyShape(RoundedRectangle(cornerRadius: LauncherLayout.expandedCornerRadius, style: .continuous))
        } else {
            // The design system's radius99999 maps to a real capsule.
            AnyShape(Capsule())
        }
    }

    private var hasInput: Bool { !model.query.isEmpty }
    private var inputHeight: CGFloat { LauncherLayout.inputHeight }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: LauncherLayout.inputSpacing) {
                if model.commandInput != nil {
                    commandIcon
                        .frame(width: 24, height: 24)
                        .accessibilityLabel(model.commandInput?.command.name ?? "关键词命令")
                }
                LauncherSearchField(
                    text: Binding(get: { model.inputText }, set: { model.inputText = $0 }),
                    fontSize: 18,
                    textColor: NSColor(ThemeColor.kText.color(for: colorScheme)),
                    placeholder: "",
                    backspaceOnEmpty: model.backspaceOnEmptyInput,
                    move: model.move,
                    submit: { model.submit($0 ? .submitToAI : .executeSelection) }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                searchIcon
            }
            .padding(.leading, LauncherLayout.inputLeadingPadding)
            .padding(.trailing, LauncherLayout.inputTrailingPadding)
            .frame(height: inputHeight)

            if let t = model.terminal {
                inputDivider
                TerminalOutputView(session: t, stop: model.stopTerminal)
            } else if !model.results.isEmpty {
                inputDivider
                ResultList(model: model, maxHeight: maxShellHeight
                           - inputHeight - LauncherLayout.dividerHeight - statusHeight)
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
                .stroke((hasInput ? ThemeColor.kBorder : ThemeColor.kBorderFocused).color(for: colorScheme),
                        lineWidth: CGFloat(BorderWidth.values["borderWidth1"] ?? 1))
                .padding(0.5)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(LauncherLayout.shadowPadding)
        .background {
            // Keep the shadow outside glassEffect's compositing subtree and draw
            // directly in the padded canvas, without negative layout padding.
            shellShape.fill(.black)
                .padding(LauncherLayout.shadowPadding)
                .shadow(color: .black.opacity(0.12), radius: LauncherLayout.shadowRadius,
                        x: 0, y: LauncherLayout.shadowOffsetY)
                .mask {
                    Rectangle().overlay {
                        shellShape.fill(.black)
                            .padding(LauncherLayout.shadowPadding)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: onHeightChange)
        .onChange(of: model.status) { _, status in
            if status == nil { statusHeight = 0 }
        }
    }
    private var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: LauncherLayout.searchIconSize, weight: .regular))
            .foregroundStyle(ThemeColor.kIconSubtle.color(for: colorScheme))
            .frame(width: 19, height: 24)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var commandIcon: some View {
        if let command = model.commandInput?.command,
           let url = command.url(for: ""),
           let icon = ToolService.launcherBrowserIcon(for: url) {
            Image(nsImage: icon).resizable().scaledToFit()
        } else {
            Image(systemName: "globe").font(.system(size: 20)).foregroundStyle(ThemeColor.kIcon)
        }
    }

    private var inputDivider: some View {
        Rectangle().fill(ThemeColor.kBorder)
            .frame(height: LauncherLayout.dividerHeight)
            .padding(.horizontal, 28)
    }

}

private struct ResultList: View {
    @Bindable var model: LauncherModel
    let maxHeight: CGFloat

    private var sections: [SearchSource] {
        var seen = Set<SearchSource>()
        return model.results.compactMap { seen.insert($0.source).inserted ? $0.source : nil }
    }

    private var showsHeaders: Bool { model.commandInput == nil }

    private var height: CGFloat {
        let rows = CGFloat(model.results.count) * LauncherLayout.rowHeight
        let headers = showsHeaders ? CGFloat(sections.count) * LauncherLayout.sectionHeaderHeight : 0
        // Headers share the six-row budget so scrolling past them cannot reveal
        // more than six items. Short result lists still size to their content.
        let sixRowHeight = CGFloat(LauncherLayout.maxVisibleResults) * LauncherLayout.rowHeight
        return min(rows + headers + LauncherLayout.listBottomPadding, sixRowHeight, maxHeight)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sections, id: \.self) { source in
                        VStack(spacing: 0) {
                            if showsHeaders {
                                Text(Self.title(source)).font(.system(size: 16))
                                    .foregroundStyle(ThemeColor.kTextSubtle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16).padding(.bottom, 12)
                                    .frame(height: LauncherLayout.sectionHeaderHeight)
                            }
                            ForEach(Array(model.results.enumerated()).filter { $0.element.source == source }, id: \.element.id) { i, r in
                                Button {
                                    model.selection = i
                                    model.submit(.executeSelection)
                                } label: {
                                    ResultRow(result: r, selected: i == model.selection, keyword: model.keyword(for: r))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(r.title)
                                .accessibilityAddTraits(i == model.selection ? .isSelected : [])
                                .id(r.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, LauncherLayout.listHorizontalPadding)
                .padding(.bottom, LauncherLayout.listBottomPadding)
            }
            .frame(height: height)
            .onChange(of: model.selection) { _, s in
                if model.results.indices.contains(s) { proxy.scrollTo(model.results[s].id) }
            }
        }
    }

    private static func title(_ source: SearchSource) -> String {
        switch source {
        case .app: "APP 应用"
        case .file: "文件文档"
        case .link: "链接"
        case .bookmark: "书签"
        case .chromeTab: "Chrome 标签页"
        case .shortcut: "快捷指令"
        case .keyword: "默认搜索"
        case .askAI: "AI"
        case .calculator, .conversion, .currency: "计算与换算"
        case .terminal: "终端命令"
        case .clipboard: "剪贴板"
        }
    }
}

private struct ResultRow: View {
    let result: SearchResult
    let selected: Bool
    let keyword: String?
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            icon.frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(keyword == nil ? result.title : result.title.components(separatedBy: "：").first ?? result.title)
                        .font(.system(size: 14)).lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(ThemeColor.kText)
                    if let keyword {
                        Text(keyword).font(.system(size: 14)).lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(ThemeColor.kTextSubtle)
                            .padding(.horizontal, 6)
                            .frame(height: 22)
                            .background(ThemeColor.kBackgroundNeutral,
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(height: 22, alignment: .leading)
                if keyword == nil, !result.subtitle.isEmpty {
                    Text(result.source == .app ? result.target.identifier : result.subtitle)
                        .font(.system(size: 12)).foregroundStyle(ThemeColor.kTextSubtlest).lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: 20, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, LauncherLayout.rowHorizontalPadding)
        .frame(height: LauncherLayout.rowHeight)
        .background(hovering ? AnyShapeStyle(ThemeColor.kInteractionHover) :
                        selected ? AnyShapeStyle(ThemeColor.kBackgroundSelected) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: LauncherLayout.rowCornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: LauncherLayout.rowCornerRadius))
        .onHover { hovering = $0 }
    }

    @ViewBuilder private var icon: some View {
        switch result.source {
        case .app, .file:
            Image(nsImage: ToolService.launcherIcon(filePath: result.target.identifier)).resizable().scaledToFit()
        case .keyword:
            if case .openURL(let url) = result.primaryAction, let icon = ToolService.launcherBrowserIcon(for: url) {
                Image(nsImage: icon).resizable().scaledToFit()
            } else {
                Image(systemName: "globe").font(.system(size: 28)).foregroundStyle(ThemeColor.kIcon)
            }
        default:
            Image(systemName: Self.symbol(result.source)).font(.system(size: 28)).foregroundStyle(ThemeColor.kIcon)
        }
    }

    static func symbol(_ s: SearchSource) -> String {
        switch s {
        case .chromeTab, .keyword: "globe"
        case .link: "link"
        case .bookmark: "bookmark"
        case .clipboard: "doc.on.clipboard"
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
