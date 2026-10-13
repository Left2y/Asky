import Foundation
import Contracts
import LocalStore

/// Long-term / episodic memory with provenance, permission inheritance, correction and
/// source-deletion cascade. All queries are bounded.
public struct MemoryStore: Sendable {
    let db: Database
    let sources: SourceStore

    public init(_ store: LocalStore) {
        db = store.db
        sources = SourceStore(store)
    }

    /// Effective permissions = intersection of all contributing sources' permissions.
    public func inheritedPermissions(_ sourceIDs: [String]) -> SourcePermissions {
        guard !sourceIDs.isEmpty else { return .none }
        return sourceIDs.map { sources.permissions($0) }.reduce(SourcePermissions(rawValue: ~0)) { $0.intersection($1) }
    }

    public enum InsertError: Error, Equatable {
        case sourceDeleted(String)
        case extractionNotAllowed(String)
    }

    /// Saves a memory. Rejects content whose sources were deleted (deletion markers prevent rebuild)
    /// or, for model-extracted memories, sources that forbid extraction.
    @discardableResult
    public func insert(_ m: MemoryRecord, extracted: Bool = false) throws -> MemoryRecord {
        for s in m.sourceIDs {
            if sources.isDeleted(s) { throw InsertError.sourceDeleted(s) }
            if extracted && !sources.permissions(s).contains(.extraction) { throw InsertError.extractionNotAllowed(s) }
        }
        var r = m
        r.permissions = inheritedPermissions(m.sourceIDs).intersection(m.permissions)
        try db.transaction {
            try db.run("""
                INSERT INTO memories(id, content, kind, status, source_ids, subjects, project, confirmed, pinned,
                  supersedes, superseded_by, permissions, source_deleted, created_at, updated_at)
                VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """, [r.id, r.content, r.kind.rawValue, r.status.rawValue, JSONText.encode(r.sourceIDs),
                      JSONText.encode(r.subjects), r.project, r.confirmed, r.pinned, r.supersedes, r.supersededBy,
                      r.permissions.rawValue, r.sourceDeleted, r.createdAt, r.updatedAt])
            for s in r.sourceIDs {
                try db.run("INSERT OR IGNORE INTO memory_sources(memory_id, source_id) VALUES(?,?)", [r.id, s])
            }
            try reindex(r)
        }
        return r
    }

    /// Source for memories the user asked the assistant to save in conversation.
    public static let assistantSourceID = "assistant"

    /// Saves a memory the user explicitly stated to the assistant. Identical active content is reused.
    @discardableResult
    public func saveStated(_ content: String, kind: MemoryKind, subjects: [String] = [], now: Date = Date()) throws -> MemoryRecord {
        if let same = try db.query("SELECT * FROM memories WHERE content = ? AND status = 'active' LIMIT 1", [content]).first {
            return Self.decode(same)
        }
        if sources.source(Self.assistantSourceID) == nil {
            try sources.upsert(SourceRecord(id: Self.assistantSourceID, kind: "assistant", title: "对话中保存",
                                            permissions: [.read, .aiUse], createdAt: now))
        }
        return try insert(MemoryRecord(content: content, kind: kind, sourceIDs: [Self.assistantSourceID], subjects: subjects,
                                       confirmed: true, permissions: [.read, .aiUse], createdAt: now, updatedAt: now))
    }

    public func get(_ id: String) -> MemoryRecord? {
        (try? db.query("SELECT * FROM memories WHERE id = ?", [id]))?.first.map(Self.decode)
    }

    /// Replaces a memory with new content; the old record stays traceable but inactive.
    /// User corrections are confirmed facts. Automatic revisions keep the old confirmation state and add the
    /// conversation that revealed the change as a source.
    @discardableResult
    public func correct(_ id: String, newContent: String, addingSource: String? = nil, byUser: Bool = true,
                        now: Date = Date()) throws -> MemoryRecord? {
        guard let old = get(id), old.status == .active else { return nil }
        var sourceIDs = old.sourceIDs
        if let s = addingSource, !sourceIDs.contains(s) { sourceIDs.append(s) }
        let new = MemoryRecord(content: newContent, kind: byUser && old.kind == .inference ? .fact : old.kind, sourceIDs: sourceIDs,
                               subjects: old.subjects, project: old.project, confirmed: byUser || old.confirmed, pinned: old.pinned,
                               supersedes: old.id, permissions: old.permissions, createdAt: now, updatedAt: now)
        return try db.transaction {
            let saved = try insert(new)
            try db.run("UPDATE memories SET status = 'superseded', superseded_by = ?, updated_at = ? WHERE id = ?",
                       [saved.id, now, old.id])
            try db.run("DELETE FROM memories_fts WHERE id = ?", [old.id])
            return saved
        }
    }

    /// Records that memories were handed to the model, so pruning keeps what is actually used.
    public func markUsed(_ ids: [String], now: Date = Date()) {
        for id in ids { _ = try? db.run("UPDATE memories SET last_used_at = ? WHERE id = ?", [now, id]) }
    }

    /// Unconfirmed memories unused for this long are deleted.
    public static let unconfirmedLifetime: TimeInterval = 60 * 24 * 3600
    /// Episodes (projects, decisions) unused for this long are deleted even when confirmed.
    public static let episodeLifetime: TimeInterval = 180 * 24 * 3600

    /// Deletes active memories that went stale: never pinned, and not created, updated or used recently.
    /// Stated facts and preferences the user confirmed are kept.
    @discardableResult
    public func pruneStale(now: Date = Date()) throws -> Int {
        let unconfirmed = now.addingTimeInterval(-Self.unconfirmedLifetime)
        let episodes = now.addingTimeInterval(-Self.episodeLifetime)
        return try db.transaction {
            let ids = try db.query("""
                SELECT id FROM memories WHERE status = 'active' AND pinned = 0
                  AND MAX(updated_at, COALESCE(last_used_at, 0)) < CASE
                    WHEN confirmed = 0 THEN ? WHEN kind = 'episode' THEN ? ELSE -1 END
                """, [unconfirmed, episodes]).compactMap { $0.string("id") }
            for id in ids {
                try db.run("DELETE FROM memories_fts WHERE id = ?", [id])
                try db.run("DELETE FROM memories WHERE id = ?", [id])
            }
            return ids.count
        }
    }

    public func setPinned(_ id: String, _ pinned: Bool) throws {
        try db.run("UPDATE memories SET pinned = ?, updated_at = ? WHERE id = ?", [pinned, Date(), id])
    }

    public func confirm(_ id: String) throws {
        try db.run("UPDATE memories SET confirmed = 1, updated_at = ? WHERE id = ?", [Date(), id])
    }

    public func delete(_ id: String) throws {
        try db.transaction {
            try db.run("DELETE FROM memories_fts WHERE id = ?", [id])
            try db.run("DELETE FROM memories WHERE id = ?", [id])
        }
    }

    /// Active memories relevant to `query`, filtered to those whose inherited permissions include `required`.
    public func search(_ query: String, requiring required: SourcePermissions = [.aiUse], limit: Int = 10) -> [MemoryRecord] {
        let tokens = FTSQuery.tokens(query)
        guard !tokens.isEmpty else { return [] }
        let rows: [Row]
        if FTSQuery.canUseIndex(tokens) {
            rows = (try? db.query("""
                SELECT m.* FROM memories_fts f JOIN memories m ON m.id = f.id
                WHERE memories_fts MATCH ? AND m.status = 'active' AND (m.permissions & ?) = ?
                ORDER BY m.pinned DESC, m.updated_at DESC LIMIT ?
                """, [FTSQuery.match(tokens), required.rawValue, required.rawValue, limit])) ?? []
        } else {
            let clause = tokens.map { _ in "(content LIKE ? ESCAPE '\\' OR subjects LIKE ? ESCAPE '\\')" }.joined(separator: " AND ")
            var args: [SQLBindable?] = tokens.flatMap { [FTSQuery.likePattern($0), FTSQuery.likePattern($0)] }
            args += [required.rawValue, required.rawValue, limit]
            rows = (try? db.query("""
                SELECT * FROM memories WHERE \(clause) AND status = 'active' AND (permissions & ?) = ?
                ORDER BY pinned DESC, updated_at DESC LIMIT ?
                """, args)) ?? []
        }
        return rows.map(Self.decode)
    }

    public func list(status: MemoryStatus? = .active, limit: Int, offset: Int = 0) -> [MemoryRecord] {
        let rows: [Row]
        if let status {
            rows = (try? db.query("SELECT * FROM memories WHERE status = ? ORDER BY pinned DESC, updated_at DESC LIMIT ? OFFSET ?",
                                  [status.rawValue, limit, offset])) ?? []
        } else {
            rows = (try? db.query("SELECT * FROM memories ORDER BY updated_at DESC LIMIT ? OFFSET ?", [limit, offset])) ?? []
        }
        return rows.map(Self.decode)
    }

    /// Recomputes inherited permissions after a source's permissions change (e.g. AI use revoked).
    public func refreshPermissions(forSource sourceID: String) throws {
        let ids = try db.query("SELECT memory_id FROM memory_sources WHERE source_id = ?", [sourceID]).compactMap { $0.string("memory_id") }
        for id in ids {
            guard let m = get(id) else { continue }
            let p = inheritedPermissions(m.sourceIDs.filter { !sources.isDeleted($0) })
            try db.run("UPDATE memories SET permissions = ? WHERE id = ?", [p.rawValue, id])
        }
    }

    /// Active deletion of a source: removes memories derived only from it (unless pinned), marks pinned or
    /// mixed-source memories as source-deleted, drops activity / queue entries, and leaves a deletion marker
    /// so pending extraction cannot rebuild from residue.
    @discardableResult
    public func deleteSource(_ sourceID: String, now: Date = Date()) throws -> (deleted: [String], marked: [String]) {
        try db.transaction {
            try db.run("INSERT OR REPLACE INTO deletion_markers(source_id, deleted_at) VALUES(?,?)", [sourceID, now])
            try db.run("DELETE FROM activity WHERE source_id = ?", [sourceID])
            try db.run("DELETE FROM extraction_queue WHERE source_id = ?", [sourceID])
            let ids = try db.query("SELECT memory_id FROM memory_sources WHERE source_id = ?", [sourceID]).compactMap { $0.string("memory_id") }
            var deleted: [String] = [], marked: [String] = []
            for id in ids {
                guard let m = get(id) else { continue }
                let remaining = m.sourceIDs.filter { $0 != sourceID && !sources.isDeleted($0) }
                if m.pinned {
                    try db.run("UPDATE memories SET source_deleted = 1, updated_at = ? WHERE id = ?", [now, id])
                    marked.append(id)
                } else if remaining.isEmpty {
                    try db.run("DELETE FROM memories_fts WHERE id = ?", [id])
                    try db.run("DELETE FROM memories WHERE id = ?", [id])
                    deleted.append(id)
                } else {
                    // Mixed-source summary: drop the deleted source and tighten to remaining sources' permissions.
                    let p = inheritedPermissions(remaining)
                    try db.run("UPDATE memories SET source_ids = ?, source_deleted = 1, permissions = ?, updated_at = ? WHERE id = ?",
                               [JSONText.encode(remaining), p.rawValue, now, id])
                    try db.run("DELETE FROM memory_sources WHERE memory_id = ? AND source_id = ?", [id, sourceID])
                    marked.append(id)
                }
            }
            try db.run("UPDATE sources SET state = 'deleted' WHERE id = ?", [sourceID])
            return (deleted, marked)
        }
    }

    private func reindex(_ r: MemoryRecord) throws {
        try db.run("DELETE FROM memories_fts WHERE id = ?", [r.id])
        guard r.status == .active else { return }
        try db.run("INSERT INTO memories_fts(id, content, subjects, project) VALUES(?,?,?,?)",
                   [r.id, r.content, r.subjects.joined(separator: " "), r.project ?? ""])
    }

    static func decode(_ r: Row) -> MemoryRecord {
        MemoryRecord(id: r.string("id") ?? "", content: r.string("content") ?? "",
                     kind: MemoryKind(rawValue: r.string("kind") ?? "") ?? .inference,
                     status: MemoryStatus(rawValue: r.string("status") ?? "") ?? .active,
                     sourceIDs: JSONText.decode(r.string("source_ids"), as: [String].self) ?? [],
                     subjects: JSONText.decode(r.string("subjects"), as: [String].self) ?? [],
                     project: r.string("project"), confirmed: r.bool("confirmed"), pinned: r.bool("pinned"),
                     supersedes: r.string("supersedes"), supersededBy: r.string("superseded_by"),
                     permissions: SourcePermissions(rawValue: r.int("permissions") ?? 0),
                     sourceDeleted: r.bool("source_deleted"),
                     createdAt: r.date("created_at") ?? .distantPast, updatedAt: r.date("updated_at") ?? .distantPast)
    }
}

/// Bounded, coalescing persistent queue of sources awaiting model extraction.
/// Processed in batches at the next explicit AI use (background AI is off by default).
public struct ExtractionQueue: Sendable {
    public static let capacity = 500
    let db: Database
    let sources: SourceStore

    public init(_ store: LocalStore) {
        db = store.db
        sources = SourceStore(store)
    }

    /// Enqueues only sources that permit extraction and are not deleted. Re-enqueue coalesces.
    @discardableResult
    public func enqueue(_ sourceID: String, now: Date = Date()) throws -> Bool {
        guard !sources.isDeleted(sourceID), sources.permissions(sourceID).contains(.extraction) else { return false }
        try db.transaction {
            try db.run("INSERT INTO extraction_queue(source_id, enqueued_at) VALUES(?,?) ON CONFLICT(source_id) DO UPDATE SET enqueued_at = excluded.enqueued_at",
                       [sourceID, now])
            let n = try db.scalarInt("SELECT COUNT(*) FROM extraction_queue")
            if n > Self.capacity {
                try db.run("DELETE FROM extraction_queue WHERE source_id IN (SELECT source_id FROM extraction_queue ORDER BY enqueued_at ASC LIMIT ?)",
                           [n - Self.capacity])
            }
        }
        return true
    }

    /// Takes up to `max` oldest entries enqueued no later than `before`, re-checking permissions at dequeue time.
    public func takeBatch(max: Int, enqueuedBefore before: Date = .distantFuture) throws -> [String] {
        try db.transaction {
            let ids = try db.query("SELECT source_id FROM extraction_queue WHERE enqueued_at <= ? ORDER BY enqueued_at ASC LIMIT ?",
                                   [before, max])
                .compactMap { $0.string("source_id") }
            for id in ids { try db.run("DELETE FROM extraction_queue WHERE source_id = ?", [id]) }
            return ids.filter { !sources.isDeleted($0) && sources.permissions($0).contains(.extraction) }
        }
    }

    public var count: Int { (try? db.scalarInt("SELECT COUNT(*) FROM extraction_queue")) ?? 0 }
}

/// Assembles authorised context snippets for a model request. Only `.aiUse` memories are eligible,
/// and the total is bounded.
public struct ContextAssembler: Sendable {
    public let memories: MemoryStore
    public let maxSnippets: Int
    public let maxCharacters: Int

    public init(memories: MemoryStore, maxSnippets: Int = 8, maxCharacters: Int = 4000) {
        self.memories = memories
        self.maxSnippets = maxSnippets
        self.maxCharacters = maxCharacters
    }

    public func snippets(for query: String) -> [ContextSnippet] {
        var used = 0
        var out: [ContextSnippet] = []
        for m in memories.search(query, requiring: [.aiUse], limit: maxSnippets) {
            guard used + m.content.count <= maxCharacters else { break }
            used += m.content.count
            let label = m.kind == .inference && !m.confirmed ? "（推测）" : ""
            out.append(ContextSnippet(sourceID: "memory:\(m.id)", text: label + m.content))
        }
        memories.markUsed(out.map { String($0.sourceID.dropFirst(7)) })
        return out
    }
}
