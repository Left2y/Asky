import AppKit
import Contracts
import LocalStore
import Memory
import AgentHost
import ScreenCaptureKit
import UniformTypeIdentifiers
import ToolService

struct ChatItem: Identifiable, Hashable {
    enum Kind: Hashable { case user, assistant, tool(ExecutionStatus?), notice, error }
    let id: String
    var kind: Kind
    var text: String
    var needsPermissionSettings = false
    var toolName: String? = nil
    var workSeconds: Int? = nil
    var attachments: [AttachmentRef] = []

    var toolSource: DataSourceID? {
        guard let name = toolName else { return nil }
        return DataSourceID.allCases.first { name.hasPrefix($0.rawValue + "_") }
    }

    var toolSymbol: String {
        let name = toolName ?? ""
        switch name {
        case let n where n.hasPrefix("calendar_"): return "calendar"
        case let n where n.hasPrefix("reminders_"): return "checklist"
        case let n where n.hasPrefix("notes_"): return "note.text"
        case let n where n.hasPrefix("contacts_"): return "person.crop.circle"
        case let n where n.hasPrefix("messages_"): return "message"
        case let n where n.hasPrefix("chrome_"): return "globe"
        case let n where n.hasPrefix("shortcuts_"): return "square.stack.3d.up"
        case "memory_search": return "brain"
        default: return "gearshape"
        }
    }
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
    private(set) var taskStartedAt: Date?
    private var responseStartIndex = 0
    private(set) var state: AgentTaskState?
    private(set) var hasOlder = false
    private(set) var newConversationRevision = 0
    private var startingNewConversation = false
    var draft = ""
    var attachments: [AttachmentRef] = []
    var attachmentThumbnails: [String: Data] = [:]

    var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty }

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

    /// Finish cancellation before changing the visible conversation so late
    /// events remain attached to the old conversation.
    func startNewConversation() async {
        guard !startingNewConversation else { return }
        startingNewConversation = true
        defer { startingNewConversation = false }
        if let id = taskID, let agent = app.agent {
            let previousStream = streamTask
            await agent.cancel(taskID: id)
            await previousStream?.value
        }
        guard !isRunning else { return }
        open(nil)
        draft = ""
        attachments = []
        attachmentThumbnails = [:]
        streaming = ""
        state = nil
        newConversationRevision += 1
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
        ChatItem(id: m.id, kind: m.role == "user" ? .user : m.role == "assistant" ? .assistant : .notice, text: m.text, attachments: m.attachments)
    }

    private func appendTrimmed(_ item: ChatItem) {
        items.append(item)
        if items.count > Self.window {
            let removed = items.count - Self.window
            items.removeFirst(removed)
            responseStartIndex = max(0, responseStartIndex - removed)
            hasOlder = true
            oldestSeq = nil
        }
    }

    // MARK: Submit (explicit only)

    func send() {
        let input = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend, !isRunning else { return }
        let text = input.isEmpty ? NSLocalizedString("请分析这些附件", comment: "") : input
        guard let agent = app.agent else {
            appendTrimmed(ChatItem(id: UUID().uuidString, kind: .error, text: app.agentUnavailableReason ?? NSLocalizedString("AI 运行时不可用", comment: "")))
            return
        }
        guard app.modelConfiguration != nil else {
            appendTrimmed(ChatItem(id: UUID().uuidString, kind: .error, text: NSLocalizedString("尚未配置模型。请在 设置 › 模型 中填写 API 地址、模型名与 Key。", comment: "")))
            return
        }
        let cid: String
        if let existing = conversationID { cid = existing } else {
            guard let created = try? store.create(title: String(text.prefix(40))) else { return }
            cid = created
            conversationID = created
        }
        do {
            let message = try store.append(conversationID: cid, role: "user", text: text, attachments: attachments)
            appendTrimmed(Self.item(message))
        } catch {
            appendTrimmed(ChatItem(id: UUID().uuidString, kind: .error, text: String(format: NSLocalizedString("保存消息失败：%@", comment: ""), error.localizedDescription)))
            return
        }
        draft = ""

        var context: [ContextSnippet] = []
        if app.settings.enabledSources.contains(.memory) {
            context = ContextAssembler(memories: app.memories).snippets(for: text)
        }
        let request = AgentRequest(sessionID: cid, text: text, attachments: attachments, context: context)
        attachments = []
        attachmentThumbnails = [:]
        beginResponse(taskID: request.taskID)
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

    func beginResponse(taskID: String, now: Date = Date()) {
        self.taskID = taskID
        taskStartedAt = now
        responseStartIndex = items.count
        state = .starting
        streaming = ""
    }

    func handle(_ event: AgentEvent, conversationID cid: String) {
        switch event {
        case .taskState(_, let s):
            state = s
        case .textDelta(_, let d):
            streaming += d
        case .message(_, let text):
            streaming = ""
            if let m = try? store.append(conversationID: cid, role: "assistant", text: text) { appendTrimmed(Self.item(m)) }
        case .toolCall(_, let req):
            appendTrimmed(ChatItem(id: req.requestID, kind: .tool(nil), text: String(format: NSLocalizedString("调用 %@…", comment: ""), req.tool), toolName: req.tool))
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
            // The clarification is the authoritative reply for this turn. Do not
            // flush earlier model narration as another reply when the stream ends.
            streaming = ""
            if let m = try? store.append(conversationID: cid, role: "assistant", text: q) {
                appendTrimmed(Self.item(m))
            }
        case .confirmationRequired:
            state = .awaitingConfirmation
        case .error(_, let msg):
            appendTrimmed(ChatItem(id: UUID().uuidString, kind: .error, text: msg))
        case .runtimeExited(let code):
            if taskID != nil { appendTrimmed(ChatItem(id: UUID().uuidString, kind: .error, text: String(format: NSLocalizedString("AI 运行时已退出（%@）", comment: ""), String(code)))) }
        }
    }

    func finishTask(conversationID cid: String) {
        if !streaming.isEmpty {
            if let m = try? store.append(conversationID: cid, role: "assistant", text: streaming) { appendTrimmed(Self.item(m)) }
            streaming = ""
        }
        if state == .pendingVerification {
            appendTrimmed(ChatItem(id: UUID().uuidString, kind: .notice, text: NSLocalizedString("任务中断，涉及写入的结果待核实；请勿假定已完成。", comment: "")))
        }
        if let started = taskStartedAt,
           let index = items.indices.last(where: { $0 >= responseStartIndex && items[$0].kind == .assistant }) {
            items[index].workSeconds = max(0, Int(Date().timeIntervalSince(started)))
        }
        taskStartedAt = nil
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
            try? sources.upsert(SourceRecord(id: sid, kind: "conversation", title: conversations.first { $0.id == cid }?.title ?? NSLocalizedString("对话", comment: ""),
                                             permissions: [.read, .aiUse, .extraction]))
        }
        if !app.settings.memoryExtractionPaused { _ = try? ExtractionQueue(app.store).enqueue(sid) }
        try? ActivityStore(app.store).append(kind: "conversation", sourceID: sid, text: String(items.last?.text.prefix(200) ?? ""))
    }

    static func statusLabel(_ s: ExecutionStatus) -> String {
        switch s {
        case .completed: NSLocalizedString("已完成", comment: "")
        case .rejected: NSLocalizedString("未执行", comment: "")
        case .cancelled: NSLocalizedString("已取消", comment: "")
        case .failed: NSLocalizedString("失败", comment: "")
        case .pendingVerification: NSLocalizedString("待核实", comment: "")
        case .awaitingConfirmation: NSLocalizedString("等待确认", comment: "")
        case .suggestion: NSLocalizedString("建议", comment: "")
        }
    }

    // MARK: Attachments (passed by file reference)

    func attach(fileURL url: URL) {
        do { addAttachment(try ComposerAttachmentService.importFile(url, into: app.store.attachmentsDirectory)) }
        catch { reportAttachmentError(error) }
    }

    private func addAttachment(_ preview: ComposerAttachmentService.Preview) {
        attachments.append(preview.reference)
        attachmentThumbnails[preview.reference.id] = preview.thumbnail
    }

    func removeAttachment(_ attachment: AttachmentRef) {
        attachments.removeAll { $0.id == attachment.id }
        attachmentThumbnails.removeValue(forKey: attachment.id)
        ComposerAttachmentService.removeDraft(attachment, from: app.store.attachmentsDirectory)
    }

    /// Return false for plain text so NSTextView preserves normal paste and undo.
    func pasteAttachments() -> Bool {
        let files = ComposerAttachmentService.pastedFiles()
        if !files.isEmpty { files.forEach { attach(fileURL: $0) }; return true }
        guard let image = ComposerAttachmentService.pastedImage() else { return false }
        do { addAttachment(try ComposerAttachmentService.importImage(image, into: app.store.attachmentsDirectory)) }
        catch { reportAttachmentError(error) }
        return true
    }

    func reportAttachmentError(_ error: Error) {
        appendTrimmed(ChatItem(id: UUID().uuidString, kind: .error, text: String(format: NSLocalizedString("添加附件失败：%@", comment: ""), error.localizedDescription)))
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
                addAttachment(ComposerAttachmentService.preview(AttachmentRef(kind: .image, path: url.path, mimeType: "image/png", byteSize: size, temporary: false)))
            } catch {
                appendTrimmed(ChatItem(id: UUID().uuidString, kind: .error, text: String(format: NSLocalizedString("截图失败：%@", comment: ""), error.localizedDescription)))
            }
        }
    }

}
