import AppKit
import SwiftUI
import Contracts
import Theme

@MainActor
final class AgentWindowController {
    private var window: NSWindow?
    let model: AgentModel

    init(model: AgentModel) { self.model = model }

    func show(prompt: String? = nil) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: WindowMetrics.agentInitialSize.width,
                                                 height: WindowMetrics.agentInitialSize.height),
                             styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                             backing: .buffered, defer: true)
            w.title = "KulaHere AI"
            w.titlebarAppearsTransparent = true
            w.minSize = NSSize(width: WindowMetrics.agentMinSize.width, height: WindowMetrics.agentMinSize.height)
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: AgentView(model: model))
            w.center()
            window = w
        }
        model.reloadConversations()
        if let prompt {
            if model.isRunning { model.draft = prompt } else {
                model.open(nil)
                model.draft = prompt
                model.send()
            }
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

struct AgentView: View {
    @Bindable var model: AgentModel

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { model.conversationID }, set: { model.open($0) })) {
                ForEach(model.conversations) { c in
                    Text(c.title).lineLimit(1).tag(Optional(c.id))
                        .contextMenu { Button("删除对话", role: .destructive) { model.delete(c.id) } }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .toolbar {
                Button { model.open(nil) } label: { Label("新对话", systemImage: "square.and.pencil") }
                    .disabled(model.isRunning)
            }
        } detail: {
            VStack(spacing: 0) {
                Transcript(model: model)
                Divider()
                Composer(model: model)
            }
        }
    }
}

private struct Transcript: View {
    let model: AgentModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if model.hasOlder {
                        Button("加载更早的消息") { model.loadOlder() }.buttonStyle(.link).frame(maxWidth: .infinity)
                    }
                    ForEach(model.items) { ChatBubble(item: $0) }
                    if !model.streaming.isEmpty {
                        ChatBubble(item: ChatItem(id: "streaming", kind: .assistant, text: model.streaming))
                    }
                    if let s = model.state, model.isRunning {
                        Text(Self.label(s)).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtlest)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(16)
            }
            .onChange(of: model.items.count) { proxy.scrollTo("bottom") }
            .onChange(of: model.streaming) { proxy.scrollTo("bottom") }
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
            HStack { Spacer(minLength: 60); bubble.background(ThemeColor.kBackgroundSelected, in: .rect(cornerRadius: 12)) }
        case .assistant:
            HStack { bubble; Spacer(minLength: 60) }
        case .tool(let status):
            Label(item.text, systemImage: Self.symbol(status)).textStyle(.secondary)
                .foregroundStyle(status == .completed ? ThemeColor.kTextPositive
                                 : status == nil ? ThemeColor.kTextSubtle : ThemeColor.kTextNegative)
        case .notice:
            Text(item.text).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle)
        case .error:
            Label(item.text, systemImage: "exclamationmark.triangle").textStyle(.secondary).foregroundStyle(ThemeColor.kTextNegative)
        }
    }

    private var bubble: some View {
        Text(LocalizedStringKey(item.text)).textStyle(.body).textSelection(.enabled).padding(10)
    }

    static func symbol(_ s: ExecutionStatus?) -> String {
        switch s {
        case nil: "gearshape"
        case .completed?: "checkmark.circle"
        case .pendingVerification?: "questionmark.circle"
        default: "xmark.circle"
        }
    }
}

private struct Composer: View {
    @Bindable var model: AgentModel
    @State private var importing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.attachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(model.attachments) { a in
                            HStack(spacing: 4) {
                                Image(systemName: a.kind == .image ? "photo" : "doc.text")
                                Text(URL(filePath: a.path).lastPathComponent).lineLimit(1)
                                Button { model.attachments.removeAll { $0.id == a.id } } label: { Image(systemName: "xmark") }
                                    .buttonStyle(.borderless)
                            }
                            .textStyle(.secondary).padding(6).glassEffect(in: .capsule)
                        }
                    }
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                Menu {
                    Button("选择文件或图片…") { importing = true }
                    Button("截取屏幕") { model.captureScreen() }
                    Button("粘贴剪贴板文本") {
                        if let s = NSPasteboard.general.string(forType: .string) { model.attachText(s) }
                    }
                } label: { Image(systemName: "paperclip") }
                    .menuStyle(.borderlessButton).fixedSize()
                TextField("输入消息，↩ 发送", text: $model.draft, axis: .vertical)
                    .textFieldStyle(.plain).textStyle(.body).lineLimit(1...8)
                    .onSubmit { model.send() }
                if model.isRunning {
                    Button("停止") { model.stop() }.buttonStyle(.glass)
                } else {
                    Button("发送") { model.send() }.buttonStyle(.glassProminent)
                        .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(12)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { r in
            if case .success(let urls) = r { urls.forEach { u in
                let ok = u.startAccessingSecurityScopedResource()
                model.attach(fileURL: u)
                if ok { u.stopAccessingSecurityScopedResource() }
            } }
        }
        .dropDestination(for: URL.self) { urls, _ in
            urls.forEach { model.attach(fileURL: $0) }
            return !urls.isEmpty
        }
    }
}
