import AppKit
import Foundation
import Observation
import Contracts
import LocalStore
import CryptoKit

@MainActor protocol NativeChatSocket: AnyObject {
    func resume()
    func cancel()
    func receive() async throws -> JSONValue
    func send(_ frame: JSONValue) async throws
}

@MainActor protocol NativeChatTransport {
    func api(_ path: String, body: JSONValue?) async throws -> JSONValue
    func makeSocket() -> any NativeChatSocket
}

@MainActor private final class LoopbackChatSocket: NativeChatSocket {
    private let task: URLSessionWebSocketTask
    init(_ task: URLSessionWebSocketTask) { self.task = task }
    func resume() { task.resume() }
    func cancel() { task.cancel(with: .goingAway, reason: nil) }
    func receive() async throws -> JSONValue {
        let frame = try await task.receive()
        let data: Data
        switch frame {
        case .data(let value): data = value
        case .string(let value): data = Data(value.utf8)
        @unknown default: throw NativeChatError.protocolChanged
        }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
    func send(_ frame: JSONValue) async throws {
        try await task.send(.data(JSONEncoder().encode(frame)))
    }
}

@MainActor private final class LoopbackChatTransport: NativeChatTransport {
    private let http: URLSession
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 30
        http = URLSession(configuration: configuration, delegate: LoopbackSessionDelegate(), delegateQueue: nil)
    }
    func makeSocket() -> any NativeChatSocket {
        LoopbackChatSocket(http.webSocketTask(with: URL(string: "ws://127.0.0.1:23001/ws/threads")!))
    }
    func api(_ path: String, body: JSONValue?) async throws -> JSONValue {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:23001" + path)!)
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await http.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw NativeChatError.unavailable }
        guard (200..<300).contains(response.statusCode) else {
            throw response.statusCode == 404 ? NativeChatError.missingThread : NativeChatError.http(response.statusCode)
        }
        guard data.count <= 16 * 1024 * 1024 else { throw NativeChatError.protocolChanged }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}

struct NativeChatHistoryMessage {
    let ids: [String]
    let role: String
    let text: String
}

public struct NativeChatMessage: Identifiable, Equatable, Sendable {
    public let id: String
    public let role: String
    public let text: String
}

public struct NativeChatSession: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
}

/// A conversation transport is independent of the Asky agent, model and tool-result pipeline.
@MainActor public protocol NativeChatBackend: AnyObject {
    var messages: [NativeChatMessage] { get }
    var streamingText: String { get }
    var sessions: [NativeChatSession] { get }
    var threadID: String? { get }
    var isBusy: Bool { get }
    var canSend: Bool { get }
    var status: String { get }
    func restore() async
    func select(_ id: String) async
    func newSession() async
    func send(_ text: String) async
    func stop() async
    func openInApplication()
}

public enum NativeChatCodec {
    public static func validID(_ id: String) -> Bool {
        id.range(of: "^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$", options: .regularExpression) != nil
    }
    /// Only user-visible text crosses the boundary. Reasoning and tool payloads stay in Alma.
    public static func messages(_ body: JSONValue) throws -> [NativeChatMessage] {
        try history(body).enumerated().compactMap { offset, row in
            guard ["user", "assistant"].contains(row.role), !row.text.isEmpty else { return nil }
            return NativeChatMessage(id: row.ids.first ?? "row-\(offset)", role: row.role, text: row.text)
        }
    }
    static func history(_ body: JSONValue) throws -> [NativeChatHistoryMessage] {
        guard let rows = body.arrayValue ?? body["messages"]?.arrayValue else { throw NativeChatError.protocolChanged }
        return try rows.map { row in
            var message = row["message"] ?? row
            if let string = message.stringValue { message = try JSONDecoder().decode(JSONValue.self, from: Data(string.utf8)) }
            let text = (message["parts"]?.arrayValue ?? []).compactMap { part -> String? in
                part["type"]?.stringValue == "text" ? part["text"]?.stringValue : nil
            }.joined(separator: "\n")
            return NativeChatHistoryMessage(ids: [row["id"]?.stringValue, message["id"]?.stringValue].compactMap { $0 },
                                            role: message["role"]?.stringValue ?? "", text: text)
        }
    }
    public static func delta(_ data: JSONValue) -> String {
        (data["deltas"]?.arrayValue ?? []).compactMap { delta -> String? in
            guard delta["type"]?.stringValue == "text_append", delta["partType"]?.stringValue == "text" else { return nil }
            return delta["text"]?.stringValue
        }.joined()
    }
}

public enum NativeChatError: LocalizedError {
    case protocolChanged, unavailable, busy, missingThread, http(Int)
    public var errorDescription: String? {
        switch self {
        case .protocolChanged: "Alma 会话协议不兼容；请在 Alma 查看。"
        case .unavailable: "无法连接 Alma。请打开 Alma 后点“重新连接”。发送结果不明时，请先恢复历史，不要重发。"
        case .busy: "Alma 正在生成，请等待完成或停止。"
        case .missingThread: "会话已不存在，请新建会话。"
        case .http(let code): "Alma 返回 HTTP \(code)，请恢复历史核实结果。"
        }
    }
}

private final class LoopbackSessionDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}

/// Alma's durable GUI thread is the source of truth; never retries a generation request.
@MainActor @Observable public final class AlmaChatBackend: NativeChatBackend {
    public private(set) var messages: [NativeChatMessage] = []
    public private(set) var streamingText = ""
    public private(set) var sessions: [NativeChatSession]
    public private(set) var threadID: String?
    public private(set) var isBusy = false
    public private(set) var status = "正在连接 Alma…"
    public private(set) var connected = false
    private var sending = false
    private var loading = false
    public var canSend: Bool {
        guard let threadID else { return false }
        return connected && historyReady && !isBusy && !sending && !loading && pendingSends[threadID] == nil
    }
    private var pendingSends: [String: PendingSend]
    private var historyReady = false
    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let noTools: Bool
    @ObservationIgnored private let transport: any NativeChatTransport
    @ObservationIgnored private var socket: (any NativeChatSocket)?
    @ObservationIgnored private var socketAlive = false
    @ObservationIgnored private var receiver: Task<Void, Never>?
    @ObservationIgnored private var longWait: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Bool, Never>?
    @ObservationIgnored private var epoch = UUID()
    @ObservationIgnored private var snapshot = false
    @ObservationIgnored private var activityRevision = 0
    @ObservationIgnored private var pendingRefresh = false
    @ObservationIgnored private var durableHistory: [NativeChatHistoryMessage] = []
    @ObservationIgnored private var displayedThreadID: String?
    private static let key = "nativeChat.alma.v1"
    private struct PendingSend: Codable {
        var baselineIDs: [String]
        var textHash: String
    }
    private struct Saved: Codable {
        var current: String?
        var sessions: [NativeChatSession]
        var pendingSends: [String: PendingSend]?
    }

    public convenience init(store: LocalStore, noTools: Bool = false) {
        self.init(store: store, noTools: noTools, transport: LoopbackChatTransport())
    }
    init(store: LocalStore, noTools: Bool = false, transport: any NativeChatTransport) {
        self.store = store; self.noTools = noTools; self.transport = transport
        let saved = store.codableSetting(Self.key, as: Saved.self)
        let restoredSessions = (saved?.sessions ?? []).filter { NativeChatCodec.validID($0.id) }
        sessions = restoredSessions
        threadID = restoredSessions.first(where: { $0.id == saved?.current })?.id
        pendingSends = saved?.pendingSends ?? [:]
    }
    private func save() {
        store.setCodableSetting(Self.key, Saved(current: threadID, sessions: sessions, pendingSends: pendingSends))
    }
    private func api(_ path: String, body: JSONValue? = nil) async throws -> JSONValue {
        try await transport.api(path, body: body)
    }
    private func isCurrent(_ token: UUID, _ ws: any NativeChatSocket) -> Bool {
        epoch == token && socket === ws
    }
    private func updateStatus() {
        guard connected else { return }
        if let id = threadID, pendingSends[id] != nil {
            status = "发送结果待历史确认，已暂停发送；请重新连接核实或在 Alma 查看。"
        } else {
            status = isBusy ? "Alma 正在生成；工具审批请在 Alma 处理。" : "已连接 Alma"
        }
    }
    private static func textHash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func verifyPendingSend(_ rows: [NativeChatHistoryMessage], thread id: String) {
        guard let pending = pendingSends[id] else { return }
        let baseline: Int
        if pending.baselineIDs.isEmpty { baseline = -1 }
        else if let index = rows.firstIndex(where: { !Set($0.ids).isDisjoint(with: pending.baselineIDs) }) { baseline = index }
        else { return }
        guard let candidate = rows.dropFirst(baseline + 1).first(where: { $0.role == "user" }),
              Self.textHash(candidate.text) == pending.textHash else { return }
        pendingSends[id] = nil
        save()
    }
    public func restore() async {
        if threadID == nil { await newSession() } else { await connect() }
    }
    public func newSession() async {
        guard !sending && !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let result = try await api("/api/threads", body: ["title": "Asky · Alma"])
            guard let id = result["id"]?.stringValue, NativeChatCodec.validID(id) else { throw NativeChatError.protocolChanged }
            sessions.insert(NativeChatSession(id: id, title: "Asky · Alma · \(Date().formatted(date: .abbreviated, time: .shortened))"), at: 0)
            threadID = id; save()
            await connect()
        } catch { status = error.localizedDescription }
    }
    public func select(_ id: String) async {
        guard !sending && !loading, sessions.contains(where: { $0.id == id }) else { return }
        threadID = id; save()
        await connect()
    }
    private func connect() async {
        epoch = UUID()
        let token = epoch
        receiver?.cancel(); receiver = nil
        refreshTask?.cancel(); refreshTask = nil
        longWait?.cancel(); longWait = nil
        socket?.cancel()
        connected = false; socketAlive = false; snapshot = false; isBusy = false; sending = false
        historyReady = false; pendingRefresh = false
        // A reconnect must not discard text whose persistence is still unknown.
        if displayedThreadID != threadID {
            messages = []; streamingText = ""; durableHistory = []
            displayedThreadID = threadID
        }
        status = "正在连接 Alma…"
        guard let id = threadID else { return }
        let ws = transport.makeSocket()
        socket = ws; socketAlive = true; ws.resume()
        receiver = Task { [weak self] in
            do {
                while !Task.isCancelled {
                    let frame = try await ws.receive()
                    guard let self, self.isCurrent(token, ws), self.socketAlive, !Task.isCancelled else { return }
                    self.receive(frame, thread: id)
                }
            } catch {
                guard let self, self.isCurrent(token, ws), !Task.isCancelled else { return }
                self.socketAlive = false; self.connected = false
                self.status = NativeChatError.unavailable.localizedDescription
                // A history read is safe after disconnect. Never resend generate_response.
                _ = await self.requestRefresh().value
            }
        }
        do {
            for _ in 0..<100 {
                guard isCurrent(token, ws), socketAlive else { throw NativeChatError.unavailable }
                if snapshot { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            guard isCurrent(token, ws), socketAlive, snapshot else { throw NativeChatError.unavailable }
            let succeeded = await requestRefresh().value
            guard isCurrent(token, ws) else { return }
            guard succeeded, socketAlive else { throw NativeChatError.unavailable }
            connected = true
            updateStatus()
        } catch {
            guard isCurrent(token, ws) else { return }
            connected = false; socketAlive = false; status = error.localizedDescription
            ws.cancel()
        }
    }
    /// All callers share one worker; later events request another read after the current read.
    @discardableResult private func requestRefresh() -> Task<Bool, Never> {
        pendingRefresh = true
        if let refreshTask { return refreshTask }
        let token = epoch
        let task = Task { [weak self] in
            guard let self else { return false }
            defer { if self.epoch == token { self.refreshTask = nil } }
            while self.pendingRefresh && self.epoch == token && !Task.isCancelled {
                self.pendingRefresh = false
                do { try await self.reloadHistory(token: token) }
                catch {
                    guard self.epoch == token, !Task.isCancelled else { return false }
                    self.historyReady = false
                    self.connected = false; self.status = error.localizedDescription
                    return false
                }
            }
            return self.epoch == token && !Task.isCancelled
        }
        refreshTask = task
        return task
    }
    private func reloadHistory(token: UUID) async throws {
        guard let id = threadID, epoch == token else { throw CancellationError() }
        let revision = activityRevision
        let startedIdle = snapshot && !isBusy && socketAlive
        let body = try await api("/api/threads/\(id)/messages")
        guard epoch == token, !Task.isCancelled else { throw CancellationError() }
        let rows = try NativeChatCodec.history(body)
        verifyPendingSend(rows, thread: id)
        // A busy snapshot may contain any prefix of the live reply. Keep the two
        // displays stable until a read that starts and ends in the same idle state.
        guard startedIdle, !isBusy, socketAlive, revision == activityRevision else { return }
        durableHistory = rows
        messages = try NativeChatCodec.messages(body)
        streamingText = ""
        sending = false
        historyReady = true
        updateStatus()
    }
    private func scheduleRefresh() { requestRefresh() }
    private func receive(_ frame: JSONValue, thread id: String) {
        guard let type = frame["type"]?.stringValue, let data = frame["data"] else { return }
        if type == "generating_snapshot", let ids = data["ids"]?.arrayValue {
            snapshot = true; isBusy = ids.contains(.string(id)); activityRevision += 1
            return
        }
        guard (data["threadId"]?.stringValue ?? (type == "thread_generating" ? data["id"]?.stringValue : nil)) == id else { return }
        if type == "message_delta" {
            streamingText += NativeChatCodec.delta(data)
            activityRevision += 1
            historyReady = false
        }
        if type == "thread_generating", let busy = data["isGenerating"]?.boolValue {
            isBusy = busy; activityRevision += 1; historyReady = false
            if !busy { longWait?.cancel(); longWait = nil; scheduleRefresh() }
            updateStatus()
        }
        if ["message_added", "generation_completed", "generation_stopped", "generation_error"].contains(type) {
            activityRevision += 1; historyReady = false; scheduleRefresh()
        }
        if type == "generation_error" { status = "Alma 生成失败，请在 Alma 查看原因。" }
    }
    public func send(_ text: String) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, canSend, let id = threadID, let socket, socketAlive else { return }
        let token = epoch
        // Persist before the first suspension: a failed send may already have reached Alma.
        pendingSends[id] = PendingSend(baselineIDs: durableHistory.last?.ids ?? [], textHash: Self.textHash(text))
        save()
        sending = true; isBusy = true; historyReady = false; activityRevision += 1
        status = "Alma 正在生成；工具审批请在 Alma 处理。"
        let frame: JSONValue = ["type": "generate_response", "data": [
            "threadId": .string(id), "tools": ["__auto__"], "noTools": .bool(noTools),
            "userMessage": ["role": "user", "parts": [["type": "text", "text": .string(text)]]]
        ]]
        do {
            try await socket.send(frame)
            guard isCurrent(token, socket), socketAlive, isBusy else { return }
            longWait?.cancel()
            longWait = Task { [weak self] in
                try? await Task.sleep(for: .seconds(240))
                guard !Task.isCancelled, let self, self.isCurrent(token, socket), self.socketAlive, self.isBusy else { return }
                self.status = "已等待 4 分钟。Alma 可继续在后台运行；可关闭窗口后恢复，或在 Alma 处理审批。"
            }
        } catch {
            guard isCurrent(token, socket), socketAlive else { return }
            socketAlive = false; connected = false
            status = NativeChatError.unavailable.localizedDescription
            socket.cancel()
            _ = await requestRefresh().value
        }
    }
    public func stop() async {
        guard connected, socketAlive, isBusy, let id = threadID, let socket else { return }
        let token = epoch
        do {
            try await socket.send(["type": "stop_generation", "data": ["threadId": .string(id)]])
            guard isCurrent(token, socket), socketAlive, isBusy else { return }
            status = "已请求停止，正在等待 Alma 确认…"
        } catch {
            guard isCurrent(token, socket), socketAlive else { return }
            socketAlive = false; connected = false
            status = NativeChatError.unavailable.localizedDescription
            socket.cancel()
        }
    }
    public func openInApplication() {
        guard let id = threadID, NativeChatCodec.validID(id), let url = URL(string: "alma://thread/\(id)") else { return }
        NSWorkspace.shared.open(url)
    }
}

extension PluginManager {
    /// Resolve current enabled installation again before creating a native transport.
    public func nativeChatDescriptor(commandID: String) -> PluginChatDescriptor? {
        launcherCommands().first(where: { $0.id == commandID })?.command.chat
    }
}
