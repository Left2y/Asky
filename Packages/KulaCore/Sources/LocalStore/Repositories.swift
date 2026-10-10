import Foundation
import Contracts

// MARK: - Executions (dedupe + persistence of tool calls)

public struct ExecutionRecord: Sendable, Hashable {
    public var requestID: String
    public var tool: String
    public var argumentsDigest: String
    public var origin: String
    public var taskID: String?
    public var status: ExecutionStatus
    public var result: ExecutionResult?
    public var createdAt: Date
    public var updatedAt: Date

    public init(requestID: String, tool: String, argumentsDigest: String, origin: String, taskID: String?,
                status: ExecutionStatus, result: ExecutionResult?, createdAt: Date, updatedAt: Date) {
        self.requestID = requestID
        self.tool = tool
        self.argumentsDigest = argumentsDigest
        self.origin = origin
        self.taskID = taskID
        self.status = status
        self.result = result
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ExecutionStore: Sendable {
    let db: Database
    public init(_ store: LocalStore) { db = store.db }

    public func record(requestID: String) -> ExecutionRecord? {
        (try? db.query("SELECT * FROM executions WHERE request_id = ?", [requestID]))?.first.map(Self.decode)
    }

    /// Most recent completed / in-flight execution with the same digest inside `window` (for write dedupe).
    public func recent(digest: String, within window: TimeInterval, now: Date = Date()) -> ExecutionRecord? {
        (try? db.query("""
            SELECT * FROM executions WHERE args_digest = ? AND updated_at >= ?
              AND status IN ('completed','pendingVerification') ORDER BY updated_at DESC LIMIT 1
            """, [digest, now.addingTimeInterval(-window)]))?.first.map(Self.decode)
    }

    public func upsert(_ r: ExecutionRecord) throws {
        try db.run("""
            INSERT INTO executions(request_id, tool, args_digest, origin, task_id, status, result, created_at, updated_at)
            VALUES(?,?,?,?,?,?,?,?,?)
            ON CONFLICT(request_id) DO UPDATE SET status = excluded.status, result = excluded.result,
              updated_at = excluded.updated_at
            """, [r.requestID, r.tool, r.argumentsDigest, r.origin, r.taskID, r.status.rawValue,
                  r.result.map { JSONText.encode($0) }, r.createdAt, r.updatedAt])
    }

    public func pendingVerification(limit: Int = 50) -> [ExecutionRecord] {
        ((try? db.query("SELECT * FROM executions WHERE status = 'pendingVerification' ORDER BY updated_at DESC LIMIT ?",
                        [limit])) ?? []).map(Self.decode)
    }

    static func decode(_ row: Row) -> ExecutionRecord {
        ExecutionRecord(requestID: row.string("request_id") ?? "", tool: row.string("tool") ?? "",
                        argumentsDigest: row.string("args_digest") ?? "", origin: row.string("origin") ?? "",
                        taskID: row.string("task_id"),
                        status: ExecutionStatus(rawValue: row.string("status") ?? "") ?? .failed,
                        result: JSONText.decode(row.string("result"), as: ExecutionResult.self),
                        createdAt: row.date("created_at") ?? .distantPast, updatedAt: row.date("updated_at") ?? .distantPast)
    }
}

// MARK: - Sources & activity

public struct SourceRecord: Sendable, Hashable {
    public var id: String
    public var kind: String
    public var title: String
    public var permissions: SourcePermissions
    public var createdAt: Date
    public init(id: String, kind: String, title: String, permissions: SourcePermissions, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.title = title
        self.permissions = permissions
        self.createdAt = createdAt
    }
}

public struct SourceStore: Sendable {
    let db: Database
    public init(_ store: LocalStore) { db = store.db }

    public func upsert(_ s: SourceRecord) throws {
        try db.run("""
            INSERT INTO sources(id, kind, title, permissions, created_at) VALUES(?,?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET title = excluded.title, permissions = excluded.permissions
            """, [s.id, s.kind, s.title, s.permissions.rawValue, s.createdAt])
    }

    public func source(_ id: String) -> SourceRecord? {
        (try? db.query("SELECT * FROM sources WHERE id = ?", [id]))?.first.map {
            SourceRecord(id: $0.string("id") ?? "", kind: $0.string("kind") ?? "", title: $0.string("title") ?? "",
                         permissions: SourcePermissions(rawValue: $0.int("permissions") ?? 0),
                         createdAt: $0.date("created_at") ?? .distantPast)
        }
    }

    public func permissions(_ id: String) -> SourcePermissions {
        source(id)?.permissions ?? .none
    }

    public func isDeleted(_ id: String) -> Bool {
        ((try? db.scalarInt("SELECT COUNT(*) FROM deletion_markers WHERE source_id = ?", [id])) ?? 0) > 0
    }
}

public struct ActivityStore: Sendable {
    public static let retention: TimeInterval = 30 * 24 * 3600
    let db: Database
    public init(_ store: LocalStore) { db = store.db }

    public func append(kind: String, sourceID: String, text: String, now: Date = Date()) throws {
        try db.run("INSERT INTO activity(id, kind, source_id, text, created_at, expires_at) VALUES(?,?,?,?,?,?)",
                   [UUID().uuidString, kind, sourceID, text, now, now.addingTimeInterval(Self.retention)])
    }

    /// Expiry is not a deletion: derived memories keep their provenance and are not marked source-deleted.
    @discardableResult
    public func purgeExpired(now: Date = Date()) throws -> Int {
        try db.run("DELETE FROM activity WHERE expires_at < ?", [now])
    }

    public func count() -> Int { (try? db.scalarInt("SELECT COUNT(*) FROM activity")) ?? 0 }
}

// MARK: - Conversations & messages (display / search projection)

public struct ConversationSummary: Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var runtimeSessionRef: String?
    public var updatedAt: Date
}

public struct StoredMessage: Sendable, Hashable, Identifiable {
    public var id: String
    public var conversationID: String
    public var seq: Int
    public var role: String
    public var text: String
    public var createdAt: Date
    public var attachments: [AttachmentRef] = []
}

public struct ConversationStore: Sendable {
    let db: Database
    public init(_ store: LocalStore) { db = store.db }

    public func create(title: String, now: Date = Date()) throws -> String {
        let id = UUID().uuidString
        try db.run("INSERT INTO conversations(id, title, created_at, updated_at) VALUES(?,?,?,?)", [id, title, now, now])
        return id
    }

    public func setRuntimeSession(_ id: String, ref: String?) throws {
        try db.run("UPDATE conversations SET runtime_session_ref = ? WHERE id = ?", [ref, id])
    }

    @discardableResult
    public func append(conversationID: String, role: String, text: String, attachments: [AttachmentRef] = [], now: Date = Date()) throws -> StoredMessage {
        let attachmentJSON = String(decoding: try JSONEncoder().encode(attachments), as: UTF8.self)
        return try db.transaction {
            let seq = try db.scalarInt("SELECT COALESCE(MAX(seq), 0) + 1 FROM messages WHERE conversation_id = ?", [conversationID])
            let id = UUID().uuidString
            try db.run("INSERT INTO messages(id, conversation_id, seq, role, text, created_at, attachments_json) VALUES(?,?,?,?,?,?,?)",
                       [id, conversationID, seq, role, text, now, attachmentJSON])
            try db.run("INSERT INTO messages_fts(id, conversation_id, text) VALUES(?,?,?)", [id, conversationID, text])
            try db.run("UPDATE conversations SET updated_at = ? WHERE id = ?", [now, conversationID])
            return StoredMessage(id: id, conversationID: conversationID, seq: seq, role: role, text: text, createdAt: now, attachments: attachments)
        }
    }

    public func list(limit: Int, before: Date? = nil) -> [ConversationSummary] {
        let rows = (try? db.query("""
            SELECT id, title, runtime_session_ref, updated_at FROM conversations
            WHERE updated_at < ? ORDER BY updated_at DESC LIMIT ?
            """, [before ?? .distantFuture, limit])) ?? []
        return rows.map {
            ConversationSummary(id: $0.string("id") ?? "", title: $0.string("title") ?? "",
                                runtimeSessionRef: $0.string("runtime_session_ref"), updatedAt: $0.date("updated_at") ?? .distantPast)
        }
    }

    /// Page of messages ending before `beforeSeq` (newest page when nil), returned in ascending order.
    public func messages(conversationID: String, limit: Int, beforeSeq: Int? = nil) -> [StoredMessage] {
        let rows = (try? db.query("""
            SELECT * FROM messages WHERE conversation_id = ? AND seq < ? ORDER BY seq DESC LIMIT ?
            """, [conversationID, beforeSeq ?? Int.max, limit])) ?? []
        return rows.reversed().map(Self.decode)
    }

    public func search(_ text: String, limit: Int = 20) -> [StoredMessage] {
        let tokens = FTSQuery.tokens(text)
        guard !tokens.isEmpty else { return [] }
        let rows: [Row]
        if FTSQuery.canUseIndex(tokens) {
            rows = (try? db.query("""
                SELECT m.* FROM messages_fts f JOIN messages m ON m.id = f.id
                WHERE messages_fts MATCH ? ORDER BY m.created_at DESC LIMIT ?
                """, [FTSQuery.match(tokens), limit])) ?? []
        } else {
            let clause = tokens.map { _ in "text LIKE ? ESCAPE '\\'" }.joined(separator: " AND ")
            let args: [SQLBindable?] = tokens.map { FTSQuery.likePattern($0) } + [limit]
            rows = (try? db.query("SELECT * FROM messages WHERE \(clause) ORDER BY created_at DESC LIMIT ?", args)) ?? []
        }
        return rows.map(Self.decode)
    }

    public func delete(_ id: String) throws {
        try db.transaction {
            try db.run("DELETE FROM messages_fts WHERE conversation_id = ?", [id])
            try db.run("DELETE FROM conversations WHERE id = ?", [id])
        }
    }

    static func decode(_ r: Row) -> StoredMessage {
        StoredMessage(id: r.string("id") ?? "", conversationID: r.string("conversation_id") ?? "", seq: r.int("seq") ?? 0,
                      role: r.string("role") ?? "", text: r.string("text") ?? "", createdAt: r.date("created_at") ?? .distantPast,
                      attachments: (try? JSONDecoder().decode([AttachmentRef].self,
                          from: Data((r.string("attachments_json") ?? "[]").utf8))) ?? [])
    }
}

// MARK: - Clipboard history

public enum ClipboardKind: String, Sendable, Codable {
    case text, image, file
}

public struct ClipboardItem: Sendable, Hashable, Identifiable {
    public var id: String
    public var kind: ClipboardKind
    public var text: String?
    public var filePath: String?
    public var thumbPath: String?
    public var byteSize: Int
    public var sourceApp: String?
    public var sourceBundleID: String?
    public var pinned: Bool
    public var contentHash: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString, kind: ClipboardKind, text: String? = nil, filePath: String? = nil,
                thumbPath: String? = nil, byteSize: Int, sourceApp: String? = nil, sourceBundleID: String? = nil,
                pinned: Bool = false, contentHash: String, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.text = text
        self.filePath = filePath
        self.thumbPath = thumbPath
        self.byteSize = byteSize
        self.sourceApp = sourceApp
        self.sourceBundleID = sourceBundleID
        self.pinned = pinned
        self.contentHash = contentHash
        self.createdAt = createdAt
    }
}

public struct ClipboardStore: Sendable {
    public static let retention: TimeInterval = 30 * 24 * 3600
    public static let byteBudget = 200 * 1024 * 1024
    let db: Database
    public init(_ store: LocalStore) { db = store.db }

    /// Inserts, or bumps the existing row with the same content hash to the top.
    public func insert(_ item: ClipboardItem) throws {
        try db.transaction {
            if let existing = try db.query("SELECT id FROM clipboard WHERE content_hash = ? LIMIT 1", [item.contentHash]).first?.string("id") {
                try db.run("UPDATE clipboard SET created_at = ?, source_app = ?, source_bundle_id = ? WHERE id = ?",
                           [item.createdAt, item.sourceApp, item.sourceBundleID, existing])
                return
            }
            try db.run("""
                INSERT INTO clipboard(id, kind, text, file_path, thumb_path, byte_size, source_app, source_bundle_id, pinned, content_hash, created_at)
                VALUES(?,?,?,?,?,?,?,?,?,?,?)
                """, [item.id, item.kind.rawValue, item.text, item.filePath, item.thumbPath, item.byteSize, item.sourceApp,
                      item.sourceBundleID, item.pinned, item.contentHash, item.createdAt])
            if let t = item.text { try db.run("INSERT INTO clipboard_fts(id, text) VALUES(?,?)", [item.id, t]) }
        }
    }

    public func recent(limit: Int, before: Date? = nil) -> [ClipboardItem] {
        ((try? db.query("SELECT * FROM clipboard WHERE created_at < ? ORDER BY pinned DESC, created_at DESC LIMIT ?",
                        [before ?? .distantFuture, limit])) ?? []).map(Self.decode)
    }

    public func search(_ text: String, limit: Int = 20) -> [ClipboardItem] {
        let tokens = FTSQuery.tokens(text)
        guard !tokens.isEmpty else { return recent(limit: limit) }
        let rows: [Row]
        if FTSQuery.canUseIndex(tokens) {
            rows = (try? db.query("""
                SELECT c.* FROM clipboard_fts f JOIN clipboard c ON c.id = f.id WHERE clipboard_fts MATCH ?
                ORDER BY c.created_at DESC LIMIT ?
                """, [FTSQuery.match(tokens), limit])) ?? []
        } else {
            let clause = tokens.map { _ in "text LIKE ? ESCAPE '\\'" }.joined(separator: " AND ")
            rows = (try? db.query("SELECT * FROM clipboard WHERE \(clause) ORDER BY created_at DESC LIMIT ?",
                                  tokens.map { FTSQuery.likePattern($0) } + [limit])) ?? []
        }
        return rows.map(Self.decode)
    }

    public func setPinned(_ id: String, _ pinned: Bool) throws {
        try db.run("UPDATE clipboard SET pinned = ? WHERE id = ?", [pinned, id])
    }

    /// Deletes rows and returns the file paths the caller must remove from disk.
    @discardableResult
    public func delete(ids: [String]) throws -> [String] {
        guard !ids.isEmpty else { return [] }
        return try db.transaction {
            var paths: [String] = []
            for id in ids {
                if let r = try db.query("SELECT file_path, thumb_path FROM clipboard WHERE id = ?", [id]).first {
                    paths += [r.string("file_path"), r.string("thumb_path")].compactMap { $0 }
                }
                try db.run("DELETE FROM clipboard_fts WHERE id = ?", [id])
                try db.run("DELETE FROM clipboard WHERE id = ?", [id])
            }
            return paths
        }
    }

    /// Removes unpinned items older than retention, then oldest unpinned until under the byte budget.
    /// Returns file paths to remove.
    public func cleanup(now: Date = Date(), budget: Int = ClipboardStore.byteBudget) throws -> [String] {
        let expired = try db.query("SELECT id FROM clipboard WHERE pinned = 0 AND created_at < ?",
                                   [now.addingTimeInterval(-Self.retention)]).compactMap { $0.string("id") }
        var paths = try delete(ids: expired)
        var total = try db.scalarInt("SELECT COALESCE(SUM(byte_size), 0) FROM clipboard")
        guard total > budget else { return paths }
        let rows = try db.query("SELECT id, byte_size FROM clipboard WHERE pinned = 0 ORDER BY created_at ASC LIMIT 1000")
        var victims: [String] = []
        for r in rows where total > budget {
            victims.append(r.string("id") ?? "")
            total -= r.int("byte_size") ?? 0
        }
        paths += try delete(ids: victims)
        return paths
    }

    public func totalBytes() -> Int { (try? db.scalarInt("SELECT COALESCE(SUM(byte_size), 0) FROM clipboard")) ?? 0 }

    static func decode(_ r: Row) -> ClipboardItem {
        ClipboardItem(id: r.string("id") ?? "", kind: ClipboardKind(rawValue: r.string("kind") ?? "") ?? .text,
                      text: r.string("text"), filePath: r.string("file_path"), thumbPath: r.string("thumb_path"),
                      byteSize: r.int("byte_size") ?? 0, sourceApp: r.string("source_app"),
                      sourceBundleID: r.string("source_bundle_id"), pinned: r.bool("pinned"),
                      contentHash: r.string("content_hash") ?? "", createdAt: r.date("created_at") ?? .distantPast)
    }
}

// MARK: - Reminder plans

public struct ReminderStore: Sendable {
    let db: Database
    public init(_ store: LocalStore) { db = store.db }

    public func upsert(_ p: ReminderPlan, now: Date = Date()) throws {
        try db.run("""
            INSERT INTO reminder_plans(id, event_id, reason, title, body, evidence, fire_date, status, fingerprint,
              user_requested, dedupe_key, updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET title = excluded.title, body = excluded.body, evidence = excluded.evidence,
              fire_date = excluded.fire_date, status = excluded.status, fingerprint = excluded.fingerprint,
              updated_at = excluded.updated_at
            """, [p.id, p.eventID, p.reason.rawValue, p.title, p.body, JSONText.encode(p.evidence), p.fireDate,
                  p.status.rawValue, p.eventFingerprint, p.userRequested, p.dedupeKey, now])
    }

    public func plan(dedupeKey: String) -> ReminderPlan? {
        (try? db.query("SELECT * FROM reminder_plans WHERE dedupe_key = ? ORDER BY updated_at DESC LIMIT 1", [dedupeKey]))?
            .first.map(Self.decode)
    }

    public func plans(status: [ReminderPlanStatus], limit: Int = 200) -> [ReminderPlan] {
        let marks = status.map { _ in "?" }.joined(separator: ",")
        let args: [SQLBindable?] = status.map(\.rawValue) + [limit]
        return ((try? db.query("SELECT * FROM reminder_plans WHERE status IN (\(marks)) ORDER BY fire_date LIMIT ?", args)) ?? [])
            .map(Self.decode)
    }

    public func setStatus(_ id: String, _ status: ReminderPlanStatus, fireDate: Date? = nil, now: Date = Date()) throws {
        if let fireDate {
            try db.run("UPDATE reminder_plans SET status = ?, fire_date = ?, updated_at = ? WHERE id = ?",
                       [status.rawValue, fireDate, now, id])
        } else {
            try db.run("UPDATE reminder_plans SET status = ?, updated_at = ? WHERE id = ?", [status.rawValue, now, id])
        }
    }

    /// Delivered non-user-requested suggestions within [start, end).
    public func deliveredSuggestions(from start: Date, to end: Date) -> Int {
        (try? db.scalarInt("""
            SELECT COUNT(*) FROM reminder_plans WHERE user_requested = 0 AND status IN ('delivered','handled')
              AND fire_date >= ? AND fire_date < ?
            """, [start, end])) ?? 0
    }

    public func isCategoryEnabled(_ reason: ReminderReason) -> Bool {
        let rows = (try? db.query("SELECT enabled FROM reminder_category_state WHERE reason = ?", [reason.rawValue])) ?? []
        return rows.first.map { $0.bool("enabled") } ?? true
    }

    public func setCategory(_ reason: ReminderReason, enabled: Bool) throws {
        try db.run("""
            INSERT INTO reminder_category_state(reason, enabled) VALUES(?,?)
            ON CONFLICT(reason) DO UPDATE SET enabled = excluded.enabled
            """, [reason.rawValue, enabled])
    }

    static func decode(_ r: Row) -> ReminderPlan {
        ReminderPlan(id: r.string("id") ?? "", eventID: r.string("event_id") ?? "",
                     reason: ReminderReason(rawValue: r.string("reason") ?? "") ?? .conflict,
                     title: r.string("title") ?? "", body: r.string("body") ?? "",
                     evidence: JSONText.decode(r.string("evidence"), as: [String].self) ?? [],
                     fireDate: r.date("fire_date") ?? .distantPast,
                     status: ReminderPlanStatus(rawValue: r.string("status") ?? "") ?? .cancelled,
                     eventFingerprint: r.string("fingerprint") ?? "", userRequested: r.bool("user_requested"))
    }
}

// MARK: - MCP instances

public struct MCPInstance: Sendable, Hashable, Identifiable, Codable {
    public var id: String
    public var name: String
    public var enabled: Bool
    public var readOnly: Bool
    public var sources: [DataSourceID]
    public var createdAt: Date
    public init(id: String = UUID().uuidString, name: String, enabled: Bool = false, readOnly: Bool = true,
                sources: [DataSourceID] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.readOnly = readOnly
        self.sources = sources
        self.createdAt = createdAt
    }
}

public struct MCPInstanceStore: Sendable {
    let db: Database
    public init(_ store: LocalStore) { db = store.db }

    /// Stores only the credential hash; the credential itself lives in Keychain / the client config.
    public func save(_ i: MCPInstance, credentialHash: String) throws {
        try db.run("""
            INSERT INTO mcp_instances(id, name, enabled, read_only, sources, credential_hash, created_at) VALUES(?,?,?,?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET name = excluded.name, enabled = excluded.enabled, read_only = excluded.read_only,
              sources = excluded.sources, credential_hash = excluded.credential_hash
            """, [i.id, i.name, i.enabled, i.readOnly, JSONText.encode(i.sources), credentialHash, i.createdAt])
    }

    public func update(_ i: MCPInstance) throws {
        try db.run("UPDATE mcp_instances SET name = ?, enabled = ?, read_only = ?, sources = ? WHERE id = ?",
                   [i.name, i.enabled, i.readOnly, JSONText.encode(i.sources), i.id])
    }

    public func all() -> [MCPInstance] {
        ((try? db.query("SELECT * FROM mcp_instances ORDER BY created_at LIMIT 100")) ?? []).map(Self.decode)
    }

    public func instance(credentialHash: String) -> MCPInstance? {
        (try? db.query("SELECT * FROM mcp_instances WHERE credential_hash = ?", [credentialHash]))?.first.map(Self.decode)
    }

    public func delete(_ id: String) throws { try db.run("DELETE FROM mcp_instances WHERE id = ?", [id]) }

    static func decode(_ r: Row) -> MCPInstance {
        MCPInstance(id: r.string("id") ?? "", name: r.string("name") ?? "", enabled: r.bool("enabled"),
                    readOnly: r.bool("read_only"), sources: JSONText.decode(r.string("sources"), as: [DataSourceID].self) ?? [],
                    createdAt: r.date("created_at") ?? .distantPast)
    }
}
