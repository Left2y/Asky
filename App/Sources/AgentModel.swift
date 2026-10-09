import AppKit
import Contracts
import LocalStore
import Memory
import AgentHost
import ScreenCaptureKit
import UniformTypeIdentifiers

struct ChatItem: Identifiable, Hashable {
    enum Kind: Hashable { case user, assistant, tool(ExecutionStatus?), notice, error }
    let id: String
    var kind: Kind
    var text: String
    var needsPermissionSettings = false
}

@MainActor @Observable
final class AgentModel {
    func openSettings(permissions: Bool = false) { app.openSettings(permissions: permissions) }

    static let firstPage = 40
    static let window = 120

    private(set) var conversations: [ConversationSummary] = []
    private(set) var conversationID: String?
    private(set) var items: [ChatItem] = []
    private(set) var streaming = ""
    private(set) var taskID: String?
    private(set) var state: AgentTaskState?
    private(set) var hasOlder = false
    var draft = ""
    var attachments: [AttachmentRef] = []

    private let app: AppModel
    private var oldestSeq: Int?
    private var streamTask: Task<Void, Never>?

    init(app: AppModel) { self.app = app }

    private var store: ConversationStore { ConversationStore(app.store) }

    var isRunning: Bool { taskID != nil }

    // MARK: History (native reads only; never starts Pi)

    func reloadConversations() { conversations = store.list(limit: Self.firstPage) }

    func open(_ id: String?) {
        guard !isRunning else { return }
        conversationID = id
        items = []
        oldestSeq = nil
        hasOlder = false
        guard let id else { return }
        let page = store.messages(conversationID: id, limit: Self.firstPage)
        items = page.map(Self.item)
        oldestSeq = page.first?.seq
        hasOlder = page.count == Self.firstPage
        if let ref = conversations.first(where: { $0.id == id })?.runtimeSessionRef, let agent = app.agent {
            Task { await agent.setSessionFile(ref, for: id) }
        }
    }

    func loadOlder() {
        guard let id = conversationID, let seq = oldestSeq else { return }
        let page = store.messages(conversationID: id, limit: Self.firstPage, beforeSeq: seq)
        items.insert(contentsOf: page.map(Self.item), at: 0)
        oldestSeq = page.first?.seq ?? seq
        hasOlder = page.count == Self.firstPage
        if items.count > Self.window { items.removeLast(items.count - Self.window) }
    }

    func delete(_ id: String) {
        try? store.delete(id)
        if conversationID == id { open(nil) }
        reloadConversations()
    }

    private static func item(_ m: StoredMessage) -> ChatItem {
        ChatItem(id: m.id, kind: m.role == "user" ? .user : m.role == "assistant" ? .assistant : .notice, text: m.text)
    }

    private func appendTrimmed(_ item: ChatItem) {
        items.append(item)
        if items.count > Self.window {
            items.removeFirst(items.count - Self.window)
            hasOlder = true
            oldestSeq = nil
        }
    }

    // MARK: Submit (explicit only)

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isRunning else { return }
        guard let agent = app.agent else {
            appendTrimmed(ChatItem(id: UUID().uuidString, kind: .error, text: app.agentUnavailableReason ?? "AI 运行时不可用"))
            return
        }
        guard app.isModelConfigured else {
            appendTrimmed(ChatItem(id: UUID().uuidString, kind: .error, text: "尚未配置模型。请在 设置 › 模型 中填写 API 地址、模型名与 Key。"))
            return
        }
        draft = ""
        let cid: String
        if let existing = conversationID { cid = existing } else {
            guard let created = try? store.create(title: String(text.prefix(40))) else { return }
            cid = created
            conversationID = created
        }
        if let m = try? store.append(conversationID: cid, role: "user", text: text) { appendTrimmed(Self.item(m)) }

        var context: [ContextSnippet] = []
        if app.settings.enabledSources.contains(.memory) {
            context = ContextAssembler(memories: app.memories).snippets(for: text)
        }
        let request = AgentRequest(sessionID: cid, text: text, attachments: attachments, context: context)
        attachments = []
        taskID = request.taskID
        state = .starting
        streaming = ""
        streamTask = Task {
            let stream = await agent.submit(request)
            for await event in stream { handle(event, conversationID: cid) }
            finishTask(conversationID: cid)
        }
    }

    func stop() {
        guard let id = taskID, let agent = app.agent else { return }
        Task { await agent.cancel(taskID: id) }
    }

    private func handle(_ event: AgentEvent, conversationID cid: String) {
        switch event {
        case .taskState(_, let s):
            state = s
        case .textDelta(_, let d):
            streaming += d
        case .message(_, let text):
            streaming = ""
            if let m = try? store.append(conversationID: cid, role: "assistant", text: text) { appendTrimmed(Self.item(m)) }
        case .toolCall(_, let req):
            appendTrimmed(ChatItem(id: req.requestID, kind: .tool(nil), text: "调用 \(req.tool)…"))
        case .toolResult(_, let r):
            let text = "\(Self.statusLabel(r.status))\(r.error.map { "：\($0.message)" } ?? "")"
            if let i = items.lastIndex(where: { $0.id == r.requestID }) {
                items[i].needsPermissionSettings = r.error?.code == .permissionDenied || r.error?.code == .sourceDisabled
                items[i].kind = .tool(r.status)
                items[i].text = items[i].text.replacingOccurrences(of: "…", with: "") + " · " + text
            } else {
                appendTrimmed(ChatItem(id: r.requestID, kind: .tool(r.status), text: text, needsPermissionSettings: r.error?.code == .permissionDenied || r.error?.code == .sourceDisabled))
            }
        case .clarification(_, let q):
            appendTrimmed(ChatItem(id: UUID().uuidString, kind: .assistant, text: q))
        case .confirmationRequired:
            state = .awaitingConfirmation
        case .error(_, let msg):
            appendTrimmed(ChatItem(id: UUID().uuidString, kind: .error, text: msg))
        case .runtimeExited(let code):
            if taskID != nil { appendTrimmed(ChatItem(id: UUID().uuidString, kind: .error, text: "AI 运行时已退出（\(code)）")) }
        }
    }

    private func finishTask(conversationID cid: String) {
        if !streaming.isEmpty {
            if let m = try? store.append(conversationID: cid, role: "assistant", text: streaming) { appendTrimmed(Self.item(m)) }
            streaming = ""
        }
        if state == .pendingVerification {
            appendTrimmed(ChatItem(id: UUID().uuidString, kind: .notice, text: "任务中断，涉及写入的结果待核实；请勿假定已完成。"))
        }
        taskID = nil
        streamTask = nil
        if let agent = app.agent {
            Task {
                if let ref = await agent.sessionFile(for: cid) { try? store.setRuntimeSession(cid, ref: ref) }
            }
        }
        recordForMemory(cid)
        reloadConversations()
    }

    /// Conversation becomes a memory source; extraction is queued (bounded) and processed on a later explicit AI use.
    private func recordForMemory(_ cid: String) {
        let sources = SourceStore(app.store)
        let sid = "conversation:\(cid)"
        if sources.source(sid) == nil {
            try? sources.upsert(SourceRecord(id: sid, kind: "conversation", title: conversations.first { $0.id == cid }?.title ?? "对话",
                                             permissions: [.read, .aiUse, .extraction]))
        }
        if !app.settings.memoryExtractionPaused { _ = try? ExtractionQueue(app.store).enqueue(sid) }
        try? ActivityStore(app.store).append(kind: "conversation", sourceID: sid, text: String(items.last?.text.prefix(200) ?? ""))
    }

    static func statusLabel(_ s: ExecutionStatus) -> String {
        switch s {
        case .completed: "已完成"
        case .rejected: "未执行"
        case .cancelled: "已取消"
        case .failed: "失败"
        case .pendingVerification: "待核实"
        case .awaitingConfirmation: "等待确认"
        case .suggestion: "建议"
        }
    }

    // MARK: Attachments (passed by file reference)

    func attach(fileURL url: URL) {
        let type = UTType(filenameExtension: url.pathExtension)
        let isImage = type?.conforms(to: .image) == true
        guard let dest = copyIntoAttachments(url) else { return }
        let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int) ?? 0
        attachments.append(AttachmentRef(kind: isImage ? .image : .file, path: dest.path,
                                         mimeType: type?.preferredMIMEType ?? "application/octet-stream",
                                         byteSize: size, temporary: false))
    }

    func attachText(_ text: String) {
        let url = app.store.attachmentsDirectory.appending(path: "\(UUID().uuidString).txt")
        try? FileManager.default.createDirectory(at: app.store.attachmentsDirectory, withIntermediateDirectories: true)
        guard (try? Data(text.utf8).write(to: url)) != nil else { return }
        attachments.append(AttachmentRef(kind: .text, path: url.path, mimeType: "text/plain", byteSize: text.utf8.count, temporary: false))
    }

    /// User-initiated screenshot of the main display (ScreenCaptureKit; Screen Recording permission is asked by the system).
    func captureScreen() {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else { return }
                let own = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
                let filter = SCContentFilter(display: display, excludingApplications: own, exceptingWindows: [])
                let cfg = SCStreamConfiguration()
                cfg.width = display.width * 2
                cfg.height = display.height * 2
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
                let url = app.store.attachmentsDirectory.appending(path: "screenshot-\(UUID().uuidString).png")
                try FileManager.default.createDirectory(at: app.store.attachmentsDirectory, withIntermediateDirectories: true)
                guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
                CGImageDestinationAddImage(dest, image, nil)
                guard CGImageDestinationFinalize(dest) else { return }
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                attachments.append(AttachmentRef(kind: .image, path: url.path, mimeType: "image/png", byteSize: size, temporary: false))
            } catch {
                appendTrimmed(ChatItem(id: UUID().uuidString, kind: .error, text: "截图失败：\(error.localizedDescription)"))
            }
        }
    }

    private func copyIntoAttachments(_ url: URL) -> URL? {
        let dir = app.store.attachmentsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appending(path: "\(UUID().uuidString)-\(url.lastPathComponent)")
        return (try? FileManager.default.copyItem(at: url, to: dest)) != nil ? dest : nil
    }
}
