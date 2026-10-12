import Foundation
import Contracts
import LocalStore

/// Drains the extraction queue: sends new conversation messages to the configured model and saves the
/// durable facts it finds as unconfirmed memories. Only conversation sources are handled; each conversation
/// is extracted incrementally from the last processed message.
public struct MemoryExtractor: Sendable {
    public typealias Complete = @Sendable (_ system: String, _ user: String) async throws -> String

    public var batchSize = 3
    public var maxMessages = 40
    public var maxPerSource = 5
    let store: LocalStore
    let complete: Complete

    public init(store: LocalStore, complete: @escaping Complete) {
        self.store = store
        self.complete = complete
    }

    static let conversationPrefix = "conversation:"
    static func cursorKey(_ sourceID: String) -> String { "memory.extracted.\(sourceID)" }

    /// Returns saved memories. Sources whose model call fails are put back in the queue.
    @discardableResult
    public func run(now: Date = Date()) async -> [MemoryRecord] {
        let queue = ExtractionQueue(store)
        guard let batch = try? queue.takeBatch(max: batchSize) else { return [] }
        var saved: [MemoryRecord] = []
        for sid in batch {
            do { saved += try await extract(sid, now: now) }
            catch { _ = try? queue.enqueue(sid, now: now) }
        }
        return saved
    }

    func extract(_ sourceID: String, now: Date) async throws -> [MemoryRecord] {
        guard sourceID.hasPrefix(Self.conversationPrefix) else { return [] }
        let cid = String(sourceID.dropFirst(Self.conversationPrefix.count))
        let after = Int(store.setting(Self.cursorKey(sourceID)) ?? "") ?? 0
        let messages = ConversationStore(store).messages(conversationID: cid, limit: maxMessages)
            .filter { $0.seq > after && ($0.role == "user" || $0.role == "assistant") }
        guard let last = messages.last?.seq else { return [] }
        guard messages.contains(where: { $0.role == "user" }) else {
            store.setSetting(Self.cursorKey(sourceID), String(last))
            return []
        }
        let memories = MemoryStore(store)
        let known = memories.list(limit: 40).map(\.content)
        let reply = try await complete(Self.systemPrompt, Self.prompt(messages, known: known))
        // The source may have been deleted or lost extraction permission while the model was running.
        let sources = SourceStore(store)
        guard !sources.isDeleted(sourceID), sources.permissions(sourceID).contains(.extraction) else { return [] }
        var out: [MemoryRecord] = []
        for c in Self.candidates(from: reply).prefix(maxPerSource) where !known.contains(c.content) {
            let r = MemoryRecord(content: c.content, kind: c.kind, sourceIDs: [sourceID], subjects: c.subjects,
                                 permissions: sources.permissions(sourceID), createdAt: now, updatedAt: now)
            if let saved = try? memories.insert(r, extracted: true) { out.append(saved) }
        }
        store.setSetting(Self.cursorKey(sourceID), String(last))
        return out
    }

    static let systemPrompt = """
        你负责从用户与助理的对话中提炼值得长期记住的个人信息，供以后的对话使用。

        只提炼：
        - 用户陈述的稳定事实：身份、家人与关系、住址城市、工作、常用工具或地点；
        - 用户明确表达的偏好与习惯；
        - 正在推进的项目、做出的决定或约定（episode）。

        不要提炼：
        - 一次性的问题、闲聊、助理自己说的内容、通用知识；
        - 密码、验证码、证件号、银行卡号、精确住址等敏感信息；
        - 已在「已有记忆」中出现的内容；
        - 只能靠猜测得出的结论。没有值得记住的内容时返回空数组。

        每条写成一句完整、可独立理解的中文陈述，以「用户」为主语，不超过 60 字。
        只输出一个 JSON 对象，不要其他文字：
        {"memories":[{"content":"用户的常用机场是浦东","kind":"fact","subjects":["机场"]}]}
        kind 只能是 fact、preference、episode、inference（推测）之一。最多 5 条。
        """

    static func prompt(_ messages: [StoredMessage], known: [String]) -> String {
        var lines = ["已有记忆："]
        lines += known.isEmpty ? ["（无）"] : known.map { "- \($0)" }
        lines += ["", "对话："]
        lines += messages.map { "\($0.role == "user" ? "用户" : "助理")：\($0.text.prefix(1200))" }
        return lines.joined(separator: "\n")
    }

    struct Candidate: Equatable {
        var content: String
        var kind: MemoryKind
        var subjects: [String]
    }

    static func candidates(from reply: String) -> [Candidate] {
        struct Reply: Decodable {
            struct Item: Decodable { var content: String; var kind: String?; var subjects: [String]? }
            var memories: [Item]
        }
        guard let start = reply.firstIndex(of: "{"), let end = reply.lastIndex(of: "}"), start < end,
              let decoded = try? JSONDecoder().decode(Reply.self, from: Data(reply[start...end].utf8)) else { return [] }
        return decoded.memories.compactMap { item in
            let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty, content.count <= 200 else { return nil }
            let kind = MemoryKind(rawValue: item.kind ?? "") ?? .inference
            return Candidate(content: content, kind: kind, subjects: Array((item.subjects ?? []).prefix(8)))
        }
    }
}
