import Foundation
import Contracts
import LocalStore

/// Drains the extraction queue: sends new conversation messages and current memories to the configured model,
/// saves new durable facts as unconfirmed memories, and applies the revisions and deletions the conversation implies.
/// Only conversation sources are handled; each conversation is extracted incrementally from the last processed message.
/// Every run also prunes stale memories.
public struct MemoryExtractor: Sendable {
    public typealias Complete = @Sendable (_ system: String, _ user: String) async throws -> String

    public var batchSize = 3
    public var maxMessages = 40
    public var maxPerSource = 5
    public var maxKnown = 60
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
        _ = try? MemoryStore(store).pruneStale(now: now)
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
        // Only memories the user allowed AI to use may be shown to the model.
        let known = memories.list(limit: maxKnown).filter { $0.permissions.contains(.aiUse) }
        let reply = try await complete(Self.systemPrompt, Self.prompt(messages, known: known.map(\.content)))
        // The source may have been deleted or lost extraction permission while the model was running.
        let sources = SourceStore(store)
        guard !sources.isDeleted(sourceID), sources.permissions(sourceID).contains(.extraction) else { return [] }
        let result = Self.parse(reply)
        var out: [MemoryRecord] = []
        var touched = Set<String>()
        func target(_ alias: String) -> MemoryRecord? {
            let a = alias.trimmingCharacters(in: .whitespaces).uppercased()
            guard a.hasPrefix("M"), let n = Int(a.dropFirst()), known.indices.contains(n - 1) else { return nil }
            let m = known[n - 1]
            return touched.insert(m.id).inserted ? m : nil
        }
        for u in result.updates.prefix(maxPerSource) {
            guard let old = target(u.id), u.content != old.content,
                  let new = try? memories.correct(old.id, newContent: u.content, addingSource: sourceID, byUser: false, now: now)
            else { continue }
            out.append(new)
        }
        for alias in result.deletes.prefix(maxPerSource) {
            guard let old = target(alias), !old.pinned else { continue }
            try? memories.delete(old.id)
        }
        let existing = Set(known.map(\.content))
        for c in result.memories.prefix(maxPerSource) where !existing.contains(c.content) {
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
        - 只能靠猜测得出的结论。

        同时检查「已有记忆」（编号 M1、M2…）：
        - 对话表明某条已经改变或有误（如搬家、换工作、改了偏好、用户纠正），放进 updates，给出更新后的完整陈述；
        - 对话表明某条已经不再成立且没有替代内容（如项目已结束、计划已取消、用户要求忘记），放进 deletes；
        - 只依据本次对话中明确的信息修改或删除，不确定时保持不变。

        每条写成一句完整、可独立理解的中文陈述，以「用户」为主语，不超过 60 字。
        只输出一个 JSON 对象，不要其他文字；没有需要处理的内容时对应数组为空：
        {"memories":[{"content":"用户的常用机场是浦东","kind":"fact","subjects":["机场"]}],
         "updates":[{"id":"M2","content":"用户住在杭州"}],
         "deletes":["M5"]}
        kind 只能是 fact、preference、episode、inference（推测）之一。每个数组最多 5 条。
        """

    static func prompt(_ messages: [StoredMessage], known: [String]) -> String {
        var lines = ["已有记忆："]
        lines += known.isEmpty ? ["（无）"] : known.enumerated().map { "M\($0 + 1) \($1)" }
        lines += ["", "对话："]
        lines += messages.map { "\($0.role == "user" ? "用户" : "助理")：\($0.text.prefix(1200))" }
        return lines.joined(separator: "\n")
    }

    struct Candidate: Equatable {
        var content: String
        var kind: MemoryKind
        var subjects: [String]
    }

    struct Update: Equatable {
        var id: String
        var content: String
    }

    struct Result: Equatable {
        var memories: [Candidate] = []
        var updates: [Update] = []
        var deletes: [String] = []
    }

    static func parse(_ reply: String) -> Result {
        struct Reply: Decodable {
            struct Item: Decodable { var content: String; var kind: String?; var subjects: [String]? }
            struct Change: Decodable { var id: String; var content: String }
            var memories: [Item]?
            var updates: [Change]?
            var deletes: [String]?
        }
        guard let start = reply.firstIndex(of: "{"), let end = reply.lastIndex(of: "}"), start < end,
              let decoded = try? JSONDecoder().decode(Reply.self, from: Data(reply[start...end].utf8)) else { return Result() }
        func clean(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty || t.count > 200 ? nil : t
        }
        return Result(
            memories: (decoded.memories ?? []).compactMap { item in
                guard let content = clean(item.content) else { return nil }
                return Candidate(content: content, kind: MemoryKind(rawValue: item.kind ?? "") ?? .inference,
                                 subjects: Array((item.subjects ?? []).prefix(8)))
            },
            updates: (decoded.updates ?? []).compactMap { u in clean(u.content).map { Update(id: u.id, content: $0) } },
            deletes: decoded.deletes ?? [])
    }
}
