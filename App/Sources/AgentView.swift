import AppKit
import SwiftUI
import Contracts
import Theme

private final class AgentWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AgentWindowController {
    private var window: NSWindow?
    private let presentation: WindowPresentation
    private var restoreAuthenticationWindow = false
    let model: AgentModel

    init(model: AgentModel, presentation: WindowPresentation) {
        self.model = model
        self.presentation = presentation
    }

    func show(prompt: String? = nil) {
        if window == nil {
            let w = AgentWindow(contentRect: NSRect(x: 0, y: 0, width: WindowMetrics.agentInitialSize.width,
                                                 height: WindowMetrics.agentInitialSize.height),
                             styleMask: [.borderless, .resizable, .miniaturizable, .fullSizeContentView],
                             backing: .buffered, defer: true)
            w.title = "KulaHere AI"
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isOpaque = false
            w.backgroundColor = .clear
            w.isMovableByWindowBackground = true
            w.level = .normal
            w.collectionBehavior = [.moveToActiveSpace, .primary]
            w.minSize = NSSize(width: WindowMetrics.agentMinSize.width, height: WindowMetrics.agentMinSize.height)
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: AgentView(model: model, close: { [weak w] in w?.close() }))
            w.center()
            window = w
        }
        bringToFront()
        model.reloadConversations()
        if let prompt {
            if model.isRunning { model.draft = prompt } else {
                model.open(nil)
                model.draft = prompt
                model.send()
            }
        }
    }

    func prepareForAuthentication() {
        restoreAuthenticationWindow = window?.isVisible == true && window?.isMiniaturized == false
        presentation.yieldToAuthentication()
    }

    func restoreAfterAuthentication() {
        defer { restoreAuthenticationWindow = false }
        guard restoreAuthenticationWindow, let window, window.isVisible, !window.isMiniaturized else { return }
        bringToFront()
    }

    private func bringToFront() {
        guard let window else { return }
        presentation.show(window)
    }
}

private enum AgentLayout {
    // Figma UI page 22:293, conversation 38:555 and history 38:654.
    static let radius: CGFloat = 32
    static let message = TextStyle(size: 16, weight: 400, mode: .default)
    static let title = TextStyle(size: 18, weight: 500, mode: .default)
}

struct AgentView: View {
    @Bindable var model: AgentModel
    var close: () -> Void = {}
    @State private var showingHistory = false
    @State private var historyQuery = ""
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: AgentLayout.radius, style: .continuous) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(ThemeColor.kBorder.color(for: colorScheme)).frame(height: 1)
            if showingHistory {
                history
            } else {
                Transcript(model: model)
                Composer(model: model)
                    .padding(.horizontal, 12).padding(.bottom, 12)
            }
        }
        .foregroundStyle(ThemeColor.kText.color(for: colorScheme))
        // Keep the shell material behind the content so it does not flatten
        // the header's independent glass controls into the window surface.
        .background {
            shape.fill(ThemeColor.kBackground.color(for: colorScheme, opaque: reduceTransparency))
                .glassEffect(reduceTransparency ? .identity : .regular, in: shape)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(ThemeColor.kBorder.color(for: colorScheme), lineWidth: 1).allowsHitTesting(false))
        .ignoresSafeArea()
        .onExitCommand { if showingHistory { showingHistory = false } else { close() } }
        .background {
            Button("") { model.openSettings() }
                .keyboardShortcut(",", modifiers: .command).hidden().accessibilityHidden(true)
        }
    }

    private var header: some View {
        HStack(spacing: 40) {
            Button { showingHistory.toggle(); model.reloadConversations() } label: {
                Image(systemName: showingHistory ? "chevron.left" : "list.bullet")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(AgentHeaderButtonStyle(colorScheme: colorScheme))
            .accessibilityLabel(showingHistory ? "返回对话" : "历史对话")
            .keyboardShortcut("h", modifiers: [.command, .shift])
            if showingHistory {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17)).frame(width: 17, height: 20)
                        .foregroundStyle(ThemeColor.kIconSubtle.color(for: colorScheme))
                    TextField("搜索对话", text: $historyQuery).textFieldStyle(.plain).textStyle(.input)
                }
                .padding(.horizontal, 16).frame(maxWidth: .infinity).frame(height: 36)
                .background {
                    Capsule().fill(ThemeColor.kBackground.color(for: colorScheme, opaque: reduceTransparency))
                        .glassEffect(reduceTransparency ? .identity : .regular, in: .capsule)
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
                }
            } else {
                Text(model.conversations.first { $0.id == model.conversationID }?.title ?? "新对话")
                    .textStyle(AgentLayout.title).lineLimit(1).frame(maxWidth: .infinity)
                    .contextMenu {
                        Button("新对话") { model.open(nil) }.disabled(model.isRunning)
                        Button("设置…") { model.openSettings() }
                    }
            }
            Button(action: close) { Image(systemName: "xmark").frame(width: 20, height: 20) }
                .buttonStyle(AgentHeaderButtonStyle(colorScheme: colorScheme)).accessibilityLabel("关闭对话窗口")
                .keyboardShortcut("w", modifiers: .command)
        }
        .padding(12)
        .frame(height: showingHistory ? 60 : 56)
    }

    private var history: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(model.conversations.filter { historyQuery.isEmpty || $0.title.localizedCaseInsensitiveContains(historyQuery) }) { c in
                    Button { model.open(c.id); showingHistory = false } label: {
                        Text(c.title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(AgentHistoryRowStyle(selected: model.conversationID == c.id))
                    .disabled(model.isRunning)
                    .contextMenu {
                        Button("删除对话", role: .destructive) { model.delete(c.id) }.disabled(model.isRunning)
                    }
                }
            }
            .textStyle(AgentLayout.message).padding(.horizontal, 12).padding(.vertical, 12)
        }
        .frame(maxHeight: .infinity)
    }
}

private struct AgentHeaderButtonStyle: ButtonStyle {
    let colorScheme: ColorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 17)).foregroundStyle(ThemeColor.kTextSubtle.color(for: colorScheme))
            .padding(6).frame(width: 32, height: 32)
            .background {
                Circle().fill(ThemeColor.kBackground.color(for: colorScheme, opaque: reduceTransparency))
                    .glassEffect(reduceTransparency ? .identity : .regular.interactive(), in: .circle)
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct AgentHistoryRowStyle: ButtonStyle {
    var selected = false
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(.rect(cornerRadius: 12))
            .background {
                if isEnabled && (hovering || configuration.isPressed) {
                    RoundedRectangle(cornerRadius: 12).fill(ThemeColor.kInteractionHover)
                } else if selected {
                    RoundedRectangle(cornerRadius: 12).fill(ThemeColor.kBackgroundNeutral)
                }
            }
            .onHover { hovering = $0 }
    }
}

private struct Transcript: View {
    let model: AgentModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if model.hasOlder {
                        Button("加载更早的消息") { model.loadOlder() }.buttonStyle(.link).frame(maxWidth: .infinity)
                    }
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        VStack(alignment: .leading, spacing: 6) {
                            ChatBubble(item: item)
                            if item.needsPermissionSettings {
                                Button("管理权限…") { model.openSettings(permissions: true) }
                                    .buttonStyle(.link)
                            }
                        }
                        .padding(.top, index == 0 ? 0 : Self.spacing(before: item))
                    }
                    if !model.streaming.isEmpty {
                        ChatBubble(item: ChatItem(id: "streaming", kind: .assistant, text: model.streaming)).padding(.top, 12)
                    }
                    if let s = model.state, model.isRunning {
                        Text(Self.label(s)).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtlest)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 32).padding(.vertical, 12)
            }
            .onChange(of: model.items.count) { proxy.scrollTo("bottom") }
            .onChange(of: model.streaming) { proxy.scrollTo("bottom") }
        }
    }

    private static func spacing(before item: ChatItem) -> CGFloat {
        switch item.kind {
        case .assistant: 12
        default: 20
        }
    }

    static func label(_ s: AgentTaskState) -> String {
        switch s {
        case .starting: "正在启动…"
        case .running: "处理中…"
        case .awaitingInput: "等待你的回答"
        case .awaitingConfirmation: "等待确认"
        case .completed: "已完成"
        case .cancelled: "已停止"
        case .failed: "失败"
        case .pendingVerification: "待核实"
        }
    }
}

private struct ChatBubble: View {
    let item: ChatItem

    var body: some View {
        switch item.kind {
        case .user:
            HStack { Spacer(minLength: 60); bubble.padding(.horizontal, 12).padding(.vertical, 10)
                .background(ThemeColor.kBackgroundNeutral, in: .rect(cornerRadius: 16)) }
        case .assistant:
            ChatMarkdownView(text: item.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .tool(let status):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: item.toolSymbol).frame(width: 20)
                Text(item.text).textSelection(.enabled)
            }
            .textStyle(AgentLayout.message)
            .foregroundStyle(status == nil || status == .completed ? ThemeColor.kTextSubtlest : ThemeColor.kTextNegative)
        case .notice:
            Text(item.text).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle)
        case .error:
            Label(item.text, systemImage: "exclamationmark.triangle").textStyle(.secondary).foregroundStyle(ThemeColor.kTextNegative)
        }
    }

    private var bubble: some View {
        Text(LocalizedStringKey(item.text)).textStyle(AgentLayout.message).textSelection(.enabled)
    }
}

private struct Composer: View {
    @Bindable var model: AgentModel
    @State private var importing = false
    @State private var editorHeight: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.attachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(model.attachments) { attachment in
                            ComposerAttachmentCard(attachment: attachment,
                                thumbnail: model.attachmentThumbnails[attachment.id]) {
                                model.removeAttachment(attachment)
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 4)
                }
                .scrollIndicators(.hidden).frame(height: 96)
            }
            ZStack(alignment: .topLeading) {
                if model.draft.isEmpty {
                    Text("输入你的任务").textStyle(.input)
                        .foregroundStyle(ThemeColor.kTextSubtlest).padding(.top, 4)
                        .allowsHitTesting(false)
                }
                ComposerTextEditor(text: $model.draft, height: $editorHeight,
                    pasteAttachment: { model.pasteAttachments() }, submit: { model.send() })
                    .frame(height: editorHeight)
            }
            .padding(.horizontal, 20)
            HStack {
                Menu {
                    Button("选择文件或图片…") { importing = true }
                    Button("截取屏幕") { model.captureScreen() }
                    Button("粘贴剪贴板文本") {
                        if let s = NSPasteboard.general.string(forType: .string) { model.attachText(s) }
                    }
                    Divider()
                    Button("新对话") { model.open(nil) }.disabled(model.isRunning)
                        .keyboardShortcut("n", modifiers: .command)
                    Button("设置…") { model.openSettings() }
                } label: {
                    Image(systemName: "paperclip").font(.system(size: 17)).frame(width: 32, height: 32)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel("添加附件与对话操作")
                Spacer()
                Button { if model.isRunning { model.stop() } else { model.send() } } label: {
                    Image(systemName: model.isRunning ? "stop.fill" : "arrow.up")
                        .font(.system(size: 16, weight: .medium)).frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ThemeColor("iconInverted"))
                .background(ThemeColor.kBackgroundPrimary, in: .circle)
                .disabled(!model.isRunning && !model.canSend)
                .opacity(!model.isRunning && !model.canSend ? 0.3 : 1)
                .accessibilityLabel(model.isRunning ? "停止生成" : "发送消息")
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 12)
        .background(ThemeColor.kInput, in: .rect(cornerRadius: 24))
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data, .image, .text], allowsMultipleSelection: true) { r in
            switch r {
            case .success(let urls): urls.forEach { model.attach(fileURL: $0) }
            case .failure(let error): model.reportAttachmentError(error)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            urls.forEach { model.attach(fileURL: $0) }
            return !urls.isEmpty
        }
    }
}
