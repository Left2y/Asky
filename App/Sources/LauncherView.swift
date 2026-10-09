import AppKit
import SwiftUI
import Contracts
import Theme
import Router

/// Floating, non-activating launcher panel that still takes key focus for the input field.
final class LauncherPanel: NSPanel {
    var onEscape: () -> Void = {}

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: WindowMetrics.launcherWidth, height: 72),
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
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
            let view = NSHostingView(rootView: AnyView(LauncherView(model: model)))
            view.sizingOptions = [.preferredContentSize]
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

    /// Hiding releases the SwiftUI tree and the result payloads (panel resource scope).
    func hide() {
        guard panel.isVisible, !hiding else { return }
        hiding = true
        defer { hiding = false }
        panel.orderOut(nil)
        model.reset()
        panel.contentView = nil
        hosting = nil
    }
}

struct LauncherView: View {
    @Bindable var model: LauncherModel
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(ThemeColor.kIconSubtle)
                TextField("搜索应用、文件、标签页，或输入 > 运行命令", text: $model.query)
                    .textFieldStyle(.plain)
                    .textStyle(.input)
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
            .padding(.horizontal, 16)
            .frame(height: 56)

            if let t = model.terminal {
                Divider()
                TerminalOutputView(session: t, stop: model.stopTerminal)
            } else if !model.results.isEmpty {
                Divider()
                ResultList(model: model)
            }
            if let s = model.status {
                Text(s).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
        .frame(width: WindowMetrics.launcherWidth)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .windowBackgroundColor))
            }
        }
        .glassEffect(reduceTransparency ? .identity : .regular, in: .rect(cornerRadius: 16))
        .onAppear { focused = true }
    }
}

private struct ResultList: View {
    @Bindable var model: LauncherModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { i, r in
                        ResultRow(result: r, selected: i == model.selection)
                            .id(i)
                            .contentShape(Rectangle())
                            .onTapGesture { model.selection = i; model.submit(.executeSelection) }
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: WindowMetrics.launcherMaxHeight - 56)
            .fixedSize(horizontal: false, vertical: true)
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
        .padding(.horizontal, 10)
        .frame(height: 44)
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
