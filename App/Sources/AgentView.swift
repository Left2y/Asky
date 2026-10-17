import AppKit
import SwiftUI
import Contracts
import Theme
import ToolService

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
            w.title = "Asky AI"
            w.hasShadow = true
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isOpaque = false
            w.backgroundColor = .clear
            w.isMovableByWindowBackground = true
            w.level = .normal
            w.collectionBehavior = [.moveToActiveSpace, .primary]
            w.minSize = NSSize(width: WindowMetrics.agentMinSize.width, height: WindowMetrics.agentMinSize.height)
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: AgentView(model: model, close: { [weak w] in w?.close() },
                setPinned: { [weak w] pinned in w?.level = pinned ? .floating : .normal }))
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

    var isVisible: Bool { window?.isVisible == true }

    func showNewConversation() {
        show()
        Task { await model.startNewConversation() }
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
    // Figma UI page 22:293, new chat 43:1072, conversation 42:761 and history 38:654.
    static let radius: CGFloat = 32
    static let message = TextStyle(size: 14, weight: 400, mode: .default)
    static let title = TextStyle(size: 18, weight: 500, mode: .default)
}

struct AgentView: View {
    @Bindable var model: AgentModel
    var close: () -> Void = {}
    var setPinned: (Bool) -> Void = { _ in }
    @State private var pinned = false
    @State private var showingHistory = false
    @State private var historyQuery = ""
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: AgentLayout.radius, style: .continuous) }
    private var navigationAnimation: Animation { .easeInOut(duration: reduceMotion ? 0.15 : 0.24) }
    private var historyTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(x: -16))
    }
    private var conversationTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8))
    }
    private var isEmptyConversation: Bool { model.items.isEmpty && model.streaming.isEmpty && !model.isRunning }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(ThemeColor.kBorder.color(for: colorScheme)).frame(height: 1)
            ZStack {
                if showingHistory {
                    history.transition(historyTransition).zIndex(1)
                } else {
                    VStack(spacing: 0) {
                        ZStack {
                            if isEmptyConversation {
                                AgentGreeting()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .transition(conversationTransition).zIndex(1)
                            } else {
                                Transcript(model: model)
                                    .id(model.conversationID)
                                    .transition(conversationTransition).zIndex(1)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // Animate navigation and the empty-state boundary, never token updates.
                        .animation(navigationAnimation, value: model.conversationID)
                        .animation(navigationAnimation, value: isEmptyConversation)
                        Composer(model: model)
                            .padding(.horizontal, 12).padding(.bottom, 12)
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(x: 16)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(navigationAnimation, value: showingHistory)
        }
        .foregroundStyle(ThemeColor.kText.color(for: colorScheme))
        .nativeGlassBackground(in: shape)
        .clipShape(shape)
        .ignoresSafeArea()
        .onChange(of: model.newConversationRevision) { showingHistory = false; historyQuery = "" }
        .onExitCommand { if showingHistory { showingHistory = false } else { close() } }
        .background {
            Button("") { model.openSettings() }
                .keyboardShortcut(",", modifiers: .command).hidden().accessibilityHidden(true)
        }
    }

    private var header: some View {
        HStack(spacing: 40) {
            HStack(spacing: 12) {
                Button { showingHistory.toggle(); model.reloadConversations() } label: {
                    headerIcon(showingHistory ? "chevron.left" : "list.bullet")
                }
                .accessibilityLabel(showingHistory ? NSLocalizedString("返回对话", comment: "") : NSLocalizedString("历史对话", comment: ""))
                .keyboardShortcut("h", modifiers: [.command, .shift])
                Button { model.open(nil); showingHistory = false } label: {
                    headerIcon("pencil")
                }
                .disabled(model.isRunning)
                .accessibilityLabel(NSLocalizedString("新对话", comment: ""))
                .keyboardShortcut("n", modifiers: .command)
            }
            .buttonStyle(AgentHeaderButtonStyle(colorScheme: colorScheme))
            ZStack {
                if showingHistory {
                    HStack(spacing: 12) {
                        Image(mingCute: "magnifyingglass", size: 17).frame(width: 17, height: 20)
                            .foregroundStyle(ThemeColor.kIconSubtle.color(for: colorScheme))
                        ConversationSearchField(text: $historyQuery,
                            textColor: NSColor(ThemeColor.kText.color(for: colorScheme)),
                            placeholderColor: NSColor(ThemeColor.kTextSubtlest.color(for: colorScheme)))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16).frame(maxWidth: .infinity).frame(height: 36)
                    .nativeGlassBackground(in: Capsule())
                    .transition(.opacity)
                } else {
                    Text(model.conversations.first { $0.id == model.conversationID }?.title ?? NSLocalizedString("新对话", comment: ""))
                        .textStyle(AgentLayout.title).lineLimit(1).frame(maxWidth: .infinity)
                        .contextMenu {
                            Button(NSLocalizedString("新对话", comment: "")) { model.open(nil) }.disabled(model.isRunning)
                            Button(NSLocalizedString("设置…", comment: "")) { model.openSettings() }
                        }
                        .id(model.conversationID)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(navigationAnimation, value: showingHistory)
            .animation(navigationAnimation, value: model.conversationID)
            HStack(spacing: 12) {
                Button { pinned.toggle(); setPinned(pinned) } label: {
                    headerIcon(pinned ? "pin.fill" : "pin")
                }
                .accessibilityLabel(pinned ? NSLocalizedString("取消置顶", comment: "") : NSLocalizedString("置顶窗口", comment: ""))
                .accessibilityValue(pinned ? NSLocalizedString("已置顶", comment: "") : NSLocalizedString("未置顶", comment: ""))
                Button(action: close) { headerIcon("xmark") }
                    .accessibilityLabel(NSLocalizedString("关闭对话窗口", comment: ""))
                    .keyboardShortcut("w", modifiers: .command)
            }
            .buttonStyle(AgentHeaderButtonStyle(colorScheme: colorScheme))
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
        .allowsWindowActivationEvents()
    }

    private func headerIcon(_ symbol: String) -> some View {
        Image(mingCute: symbol)
            .frame(width: 20, height: 20)
            .frame(width: 32, height: 32)
            .contentShape(.interaction, Circle())
    }

    private var history: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.conversations.filter { historyQuery.isEmpty || $0.title.localizedCaseInsensitiveContains(historyQuery) }) { c in
                    Button { model.open(c.id); showingHistory = false } label: {
                        HStack(spacing: 12) {
                            Text(c.title).lineLimit(1).truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(c.updatedAt, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                                .foregroundStyle(ThemeColor.kTextSubtlest).fixedSize()
                        }
                    }
                    .buttonStyle(AgentHistoryRowStyle(selected: model.conversationID == c.id))
                    .disabled(model.isRunning)
                    .contextMenu {
                        Button(NSLocalizedString("删除对话", comment: ""), role: .destructive) { model.delete(c.id) }.disabled(model.isRunning)
                    }
                }
            }
            .textStyle(AgentLayout.message).padding(.horizontal, 12).padding(.vertical, 12)
        }
        .frame(maxHeight: .infinity)
    }
}

private struct AgentGreeting: View {
    private let greeting = "Hey，what’s up?"
    @State private var visibleCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var revealedText: AttributedString {
        var text = AttributedString(greeting)
        let boundary = text.characters.index(text.startIndex, offsetBy: visibleCount)
        text[boundary..<text.endIndex].foregroundColor = .clear
        return text
    }

    var body: some View {
        // Transparent unrevealed characters reserve the final line's width.
        Text(revealedText)
            .textStyle(TextStyle(size: 24, weight: 500, mode: .default))
            .accessibilityLabel(greeting)
            .task(id: reduceMotion) {
                visibleCount = reduceMotion ? greeting.count : 0
                guard !reduceMotion else { return }
                for count in 1...greeting.count {
                    do { try await Task.sleep(for: .milliseconds(38)) }
                    catch { return }
                    visibleCount = count
                }
            }
    }
}

private struct AgentHeaderButtonStyle: ButtonStyle {
    let colorScheme: ColorScheme
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14)).foregroundStyle(ThemeColor.kTextSubtle.color(for: colorScheme))
            .nativeGlassBackground(in: Circle())
            .overlay {
                if isEnabled && (hovering || configuration.isPressed) {
                    Circle().fill(ThemeColor.kInteractionHover.color(for: colorScheme))
                }
            }
            .contentShape(.interaction, Circle())
            .opacity(isEnabled && configuration.isPressed ? 0.7 : 1)
            .onHover { hovering = $0 }
    }
}

private struct AgentHistoryRowStyle: ButtonStyle {
    var selected = false
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 16).frame(height: 48)
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

struct AgentIconButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.rect(cornerRadius: cornerRadius))
            .background {
                if isEnabled && (hovering || configuration.isPressed) {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(ThemeColor.kInteractionHover)
                }
            }
            .onHover { hovering = $0 }
    }
}

private struct Transcript: View {
    let model: AgentModel
    // Value snapshots let an outgoing transcript finish fading after model.open
    // clears/replaces the active conversation. The live model still owns actions.
    private let items: [ChatItem]
    private let streaming: String
    private let hasOlder: Bool
    private let taskStartedAt: Date?
    private let isRunning: Bool
    private let state: AgentTaskState?

    init(model: AgentModel) {
        self.model = model
        items = model.items
        streaming = model.streaming
        hasOlder = model.hasOlder
        taskStartedAt = model.taskStartedAt
        isRunning = model.isRunning
        state = model.state
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if hasOlder {
                        Button(NSLocalizedString("加载更早的消息", comment: "")) { model.loadOlder() }.buttonStyle(.link).frame(maxWidth: .infinity)
                    }
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        VStack(alignment: .leading, spacing: 6) {
                            ChatBubble(item: item, pluginManager: model.pluginManager)
                            if item.needsPermissionSettings {
                                Button(NSLocalizedString("管理权限…", comment: "")) { model.openSettings(permissions: true) }
                                    .buttonStyle(.link)
                            }
                        }
                        .padding(.top, index == 0 ? 0 : Self.spacing(before: item, after: items[index - 1]))
                    }
                    if !streaming.isEmpty {
                        ChatBubble(item: ChatItem(id: "streaming", kind: .assistant, text: streaming)).padding(.top, 12)
                    }
                    if let started = taskStartedAt, isRunning {
                        TimelineView(.periodic(from: started, by: 1)) { context in
                            Text("Work for \(max(0, Int(context.date.timeIntervalSince(started))))s")
                                .textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtlest)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if let s = state, isRunning {
                        Text(Self.label(s)).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtlest)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 32).padding(.vertical, 12)
            }
            .onAppear { proxy.scrollTo("bottom") }
            .onChange(of: items.count) { proxy.scrollTo("bottom") }
            .onChange(of: streaming) { proxy.scrollTo("bottom") }
        }
    }

    private static func spacing(before item: ChatItem, after previous: ChatItem) -> CGFloat {
        if case .user = item.kind { return 20 }
        if case .user = previous.kind { return 4 }
        return 16
    }

    static func label(_ s: AgentTaskState) -> String {
        switch s {
        case .starting: NSLocalizedString("正在启动…", comment: "")
        case .running: NSLocalizedString("处理中…", comment: "")
        case .awaitingInput: NSLocalizedString("等待你的回答", comment: "")
        case .awaitingConfirmation: NSLocalizedString("等待确认", comment: "")
        case .completed: NSLocalizedString("已完成", comment: "")
        case .cancelled: NSLocalizedString("已停止", comment: "")
        case .failed: NSLocalizedString("失败", comment: "")
        case .pendingVerification: NSLocalizedString("待核实", comment: "")
        }
    }
}

private struct ChatBubble: View {
    let item: ChatItem
    var pluginManager: PluginManager? = nil
    @State private var hovering = false
    @State private var copyHovering = false
    @State private var copyFeedbackID: UUID?
    @FocusState private var copyFocused: Bool

    var body: some View {
        switch item.kind {
        case .user:
            VStack(alignment: .trailing, spacing: 8) {
                if !item.attachments.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        attachmentCards
                        ScrollView(.horizontal) { attachmentCards }
                            .scrollIndicators(.hidden)
                            .defaultScrollAnchor(.trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                HStack { Spacer(minLength: 40); bubble.padding(.horizontal, 12).padding(.vertical, 10)
                    .background(ThemeColor.kBackgroundNeutral, in: .rect(cornerRadius: 16)) }
                copyButton
                    .onHover { copyHovering = $0 }
                    .opacity(hovering || copyHovering || copyFocused || copyFeedbackID != nil ? 1 : 0)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            // Include the empty action row and the gap below the bubble in
            // hover tracking, so moving to Copy never hides it mid-gesture.
            .contentShape(.rect)
            .onHover { hovering = $0 }
        case .assistant:
            VStack(alignment: .leading, spacing: 16) {
                ChatMarkdownView(text: item.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if item.id != "streaming" {
                    HStack {
                        if let seconds = item.workSeconds {
                            Text("Work for \(seconds)s").textStyle(.secondary)
                                .foregroundStyle(ThemeColor.kTextSubtlest)
                        }
                        Spacer()
                        copyButton
                    }
                }
            }
        case .tool(let status):
            ToolCallRow(item: item, status: status, pluginManager: pluginManager)
        case .notice:
            Text(item.text).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle)
        case .error:
            Label { Text(item.text) } icon: { Image(mingCute: "exclamationmark.triangle") }.textStyle(.secondary).foregroundStyle(ThemeColor.kTextNegative)
        }
    }

    private var attachmentCards: some View {
        HStack(spacing: 8) {
            ForEach(item.attachments) { attachment in
                ComposerAttachmentCard(attachment: attachment, thumbnail: nil)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var copyButton: some View {
        Button {
            if MessageClipboard.copy(item.text) {
                copyFeedbackID = UUID()
            }
        } label: {
            Group {
                if copyFeedbackID != nil {
                    Image(mingCute: "checkmark", size: 14)
                } else {
                    Image("ChatCopy").resizable().scaledToFit().frame(width: 14, height: 14)
                }
            }
            .frame(width: 16, height: 16).padding(6)
        }
        .buttonStyle(AgentIconButtonStyle()).focused($copyFocused).foregroundStyle(ThemeColor("iconSubtlest"))
        .accessibilityLabel(copyFeedbackID != nil ? NSLocalizedString("已复制", comment: "") : NSLocalizedString("复制消息", comment: ""))
        .task(id: copyFeedbackID) {
            guard let feedbackID = copyFeedbackID else { return }
            do {
                try await Task.sleep(for: .milliseconds(800))
            } catch {
                return
            }
            if copyFeedbackID == feedbackID {
                copyFeedbackID = nil
            }
        }
    }

    private var bubble: some View {
        Text(LocalizedStringKey(item.text)).textStyle(AgentLayout.message).textSelection(.enabled)
    }
}

private struct Composer: View {
    @Bindable var model: AgentModel
    @State private var importing = false
    @State private var editorHeight: CGFloat = 44
    @State private var editorFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.attachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(model.attachments) { attachment in
                            ComposerAttachmentCard(attachment: attachment,
                                thumbnail: model.attachmentThumbnails[attachment.id]) {
                                model.removeAttachment(attachment)
                            }
                        }
                    }
                    // Keep the last delete button inside the scroll content without widening each gap.
                    .padding(.trailing, 8)
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden).frame(height: 58)
            }
            ComposerTextEditor(text: $model.draft, height: $editorHeight,
                isFocused: $editorFocused,
                pasteAttachment: { model.pasteAttachments() }, submit: { model.send() })
                .frame(height: editorHeight)
            .padding(.horizontal, 20)
            HStack {
                Button { importing = true } label: {
                    Image(mingCute: "paperclip", size: 14).frame(width: 32, height: 32)
                }
                .buttonStyle(AgentIconButtonStyle(cornerRadius: 16))
                .accessibilityLabel(NSLocalizedString("选择文件或图片", comment: ""))
                Spacer()
                ApprovalModePicker(model: model)
                Button { if model.isRunning { model.stop() } else { model.send() } } label: {
                    Image(mingCute: model.isRunning ? "stop.fill" : "arrow.up", size: 14).frame(width: 32, height: 32)
                }
                .buttonStyle(ComposerSubmitButtonStyle())
                .disabled(!model.isRunning && !model.canSend)
                .accessibilityLabel(model.isRunning ? NSLocalizedString("停止生成", comment: "") : NSLocalizedString("发送消息", comment: ""))
            }
            .padding(.horizontal, 12)
        }
        // Attachment cards reserve 6 pt above their visible edge for the delete button.
        // Include that reserve in Figma's 16 pt top inset rather than adding it again.
        .padding(.top, model.attachments.isEmpty ? 16 : 10).padding(.bottom, 12)
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

private struct ApprovalModePicker: View {
    @Bindable var model: AgentModel
    @State private var showing = false

    private static let fullAccessColor = Color.orange

    var body: some View {
        let mode = model.approvalMode
        Button { showing.toggle() } label: {
            HStack(spacing: 4) {
                Image(mingCute: Self.icon(mode), size: 13)
                Text(Self.shortTitle(mode)).font(.system(size: 13))
            }
            .foregroundStyle(mode == .fullAccess ? AnyShapeStyle(Self.fullAccessColor) : AnyShapeStyle(ThemeColor.kTextSubtle))
            .padding(.horizontal, 10).frame(height: 32)
        }
        .buttonStyle(AgentIconButtonStyle(cornerRadius: 16))
        .accessibilityLabel(NSLocalizedString("审批模式", comment: ""))
        .accessibilityValue(Self.title(mode))
        .modifier(ApprovalMenuPresentation(showing: $showing) { menu(mode) })
    }

    private func menu(_ mode: ApprovalMode) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(ApprovalMode.allCases, id: \.self) { option in
                ApprovalModeRow(option: option, selected: option == mode) {
                    model.approvalMode = option
                    showing = false
                }
            }
        }
        .padding(6).frame(width: 340)
    }

    static func icon(_ mode: ApprovalMode) -> String {
        mode == .fullAccess ? "exclamationmark.shield" : "checkmark.shield"
    }

    static func shortTitle(_ mode: ApprovalMode) -> String {
        mode == .fullAccess ? NSLocalizedString("完全访问", comment: "") : NSLocalizedString("自动审批", comment: "")
    }

    static func title(_ mode: ApprovalMode) -> String {
        mode == .fullAccess ? NSLocalizedString("完全访问权限", comment: "") : NSLocalizedString("自动审批", comment: "")
    }

    static func detail(_ mode: ApprovalMode) -> String {
        mode == .fullAccess
            ? NSLocalizedString("AI 执行任何操作都不再询问，包括删除、发送和修改", comment: "")
            : NSLocalizedString("仅对检测到的风险操作请求批准", comment: "")
    }
}

private struct ApprovalModeRow: View {
    let option: ApprovalMode
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let tint = option == .fullAccess ? AnyShapeStyle(Color.orange) : AnyShapeStyle(ThemeColor.kText)
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(mingCute: ApprovalModePicker.icon(option), size: 15).frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ApprovalModePicker.title(option)).font(.system(size: 13, weight: .medium))
                    Text(ApprovalModePicker.detail(option)).font(.system(size: 12)).opacity(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if selected { Image(mingCute: "checkmark", size: 12) }
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .contentShape(.rect(cornerRadius: 8))
            .background {
                if hovering { RoundedRectangle(cornerRadius: 8).fill(ThemeColor.kInteractionHover) }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// An in-window menu instead of NSPopover, whose chrome is always system Liquid Glass on macOS 26
/// and so ignores the Liquid Glass setting.
private struct ApprovalMenuPresentation<Menu: View>: ViewModifier {
    @Binding var showing: Bool
    @ViewBuilder let menu: () -> Menu
    @State private var monitor: Any?
    @State private var menuView = WeakViewBox()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if showing {
                    menu()
                        .nativeGlassBackground(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .background(ViewReader(box: menuView).allowsHitTesting(false))
                        .fixedSize()
                        // Sit 8 pt above the 32 pt picker, extending over the send button and its spacing.
                        .offset(x: 40, y: -40)
                        .transition(reduceMotion ? .opacity
                                    : .opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: showing)
            .onChange(of: showing) { _, shown in shown ? startMonitoring() : stopMonitoring() }
            .onDisappear { showing = false; stopMonitoring() }
    }

    private func startMonitoring() {
        stopMonitoring()
        let box = menuView
        let dismiss = $showing
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { event in
            let isEscape = event.type == .keyDown && event.keyCode == 53
            if event.type == .keyDown && !isEscape { return event }
            let point = event.locationInWindow
            let window = event.window
            let consumed = MainActor.assumeIsolated {
                if !isEscape, let view = box.view, window === view.window,
                   view.bounds.contains(view.convert(point, from: nil)) {
                    return false
                }
                // Like a transient popover, the dismissing click does nothing else.
                dismiss.wrappedValue = false
                return true
            }
            return consumed ? nil : event
        }
    }

    private func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

@MainActor private final class WeakViewBox {
    weak var view: NSView?
}

private struct ViewReader: NSViewRepresentable {
    let box: WeakViewBox
    func makeNSView(context: Context) -> NSView { let view = NSView(); box.view = view; return view }
    func updateNSView(_ view: NSView, context: Context) { box.view = view }
}

private struct ComposerSubmitButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ThemeColor("iconInverted"))
            // Fade only the fill so the arrow keeps its contrast when disabled.
            .background(ThemeColor.kBackgroundPrimary.opacity(isEnabled ? 1 : 0.3), in: .circle)
    }
}

private struct ToolCallRow: View {
    let item: ChatItem
    let status: ExecutionStatus?
    let pluginManager: PluginManager?
    @State private var expanded = false
    @State private var pluginIcon: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Group {
                    if status == nil {
                        ProgressView().controlSize(.small)
                    } else if status == .failed {
                        Image(mingCute: "xmark.circle")
                            .accessibilityLabel(AgentModel.statusLabel(.failed))
                    } else if let pluginIcon {
                        Image(nsImage: pluginIcon).resizable().scaledToFit()
                    } else if item.pluginID != nil {
                        Image("Plugin").resizable().scaledToFit()
                    } else if let source = item.toolSource {
                        DataSourceIcon(source: source)
                    } else {
                        Image(mingCute: item.toolSymbol)
                    }
                }
                .frame(width: 20, height: 20)
                Text(item.text).textSelection(.enabled)
                if let status, status != .completed, status != .failed {
                    Text(AgentModel.statusLabel(status))
                }
                Spacer(minLength: 0)
                if item.toolError != nil {
                    Button { expanded.toggle() } label: {
                        Image(mingCute: expanded ? "chevron.down" : "chevron.right", size: 12).frame(width: 28, height: 28)
                    }
                    .buttonStyle(AgentIconButtonStyle())
                    .accessibilityLabel(NSLocalizedString(expanded ? "收起错误详情" : "展开错误详情", comment: ""))
                    .accessibilityValue(expanded ? "expanded" : "collapsed")
                }
            }
            if expanded, let error = item.toolError {
                Text(error).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 28)
            }
        }
        .textStyle(AgentLayout.message)
        .foregroundStyle(ThemeColor.kTextSubtlest)
        .task(id: item.pluginID) {
            guard let id = item.pluginID, let pluginManager else { return }
            if let data = await pluginManager.iconData(for: id), let image = NSImage(data: data), image.isValid {
                pluginIcon = image
            } else {
                let installed = await pluginManager.installed()
                let repository = installed.first(where: { $0.id == id })?.repository
                    ?? PluginManager.officialRepositories.first(where: { $0.hasSuffix("asky-plugin-" + id) })
                if let repository {
                    pluginIcon = ToolService.pluginApplicationIcon(repository: repository)
                }
            }
        }
    }
}
