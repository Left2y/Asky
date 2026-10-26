import AppKit
import SwiftUI
import Theme
import ToolService

/// External conversations have their own transport and state; AgentModel remains unchanged.
@MainActor final class NativeChatWindowController {
    private var window: NSWindow?
    private let backend: AlmaChatBackend
    init(backend: AlmaChatBackend) { self.backend = backend }

    func show(draft: String = "") {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 680),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Asky · Alma"
            window.minSize = NSSize(width: 540, height: 440)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: NativeChatView(backend: backend, initialDraft: draft))
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        Task { await backend.restore() }
    }
}

struct NativeChatView: View {
    let backend: AlmaChatBackend
    var initialDraft = ""
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Menu("恢复会话") {
                    ForEach(backend.sessions) { session in
                        Button(session.title) { Task { await backend.select(session.id) } }
                    }
                }
                .disabled(backend.sessions.isEmpty)
                Button("新建") { Task { await backend.newSession() } }
                Spacer()
                Button("重新连接") { Task { await backend.restore() } }
                Button("在 Alma 打开") { backend.openInApplication() }
                    .disabled(backend.threadID == nil)
            }
            .padding(16)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        if backend.messages.isEmpty && backend.streamingText.isEmpty {
                            Text(backend.connected ? "直接向 Alma 提问。会话也会保存在 Alma 中。" : "连接后将加载 Alma 会话历史。")
                                .foregroundStyle(ThemeColor.kTextSubtle).padding(.vertical, 40)
                        }
                        ForEach(backend.messages) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(message.role == "user" ? "你" : "Alma")
                                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(ThemeColor.kTextSubtle)
                                ChatMarkdownView(text: message.text).textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !backend.streamingText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Alma").font(.system(size: 12, weight: .semibold)).foregroundStyle(ThemeColor.kTextSubtle)
                                ChatMarkdownView(text: backend.streamingText).textSelection(.enabled)
                            }
                        }
                        Color.clear.frame(height: 1).id("latest")
                    }
                    .padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
                }
                .onChange(of: backend.streamingText) { _, _ in proxy.scrollTo("latest", anchor: .bottom) }
                .onChange(of: backend.messages.count) { _, _ in proxy.scrollTo("latest", anchor: .bottom) }
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    if backend.isBusy { ProgressView().controlSize(.small) }
                    Text(backend.status).font(.system(size: 12)).foregroundStyle(ThemeColor.kTextSubtle).textSelection(.enabled)
                    Spacer(minLength: 0)
                }
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("向 Alma 提问…", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(1...6).focused($composerFocused)
                        .onSubmit { send() }
                        .accessibilityIdentifier("alma-composer")
                    if backend.isBusy {
                        Button("停止") { Task { await backend.stop() } }.disabled(!backend.connected)
                    } else {
                        Button("发送", action: send).disabled(!backend.canSend || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .keyboardShortcut(.return, modifiers: .command)
                    }
                }
            }
            .padding(16)
        }
        .background(ThemeColor.kBackground)
        .onAppear { draft = initialDraft; composerFocused = true }
    }
    private func send() {
        guard backend.canSend, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = draft
        draft = ""
        Task { await backend.send(text) }
    }
}
