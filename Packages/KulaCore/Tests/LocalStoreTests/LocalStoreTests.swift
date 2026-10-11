import Testing
import Foundation
import Contracts
@testable import LocalStore

func tempRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("kula-\(UUID().uuidString)", isDirectory: true)
}

@Suite struct LocalStoreTests {
    @Test func migrationIsIdempotentOnDisk() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try LocalStore(root: root)
        let again = try LocalStore(root: root)
        #expect(try again.db.scalarInt("PRAGMA user_version") == Schema.migrations.count)
        #expect(FileManager.default.fileExists(atPath: again.clipboardDirectory.path))
    }

    @Test func nestedTransactionRollsBackOnlyInner() throws {
        let s = try LocalStore(inMemoryWithRoot: tempRoot())
        try s.db.transaction {
            try s.db.run("INSERT INTO settings(key, value) VALUES('a', '1')")
            _ = try? s.db.transaction {
                try s.db.run("INSERT INTO settings(key, value) VALUES('b', '2')")
                throw SQLiteError(code: 0, message: "boom")
            }
        }
        #expect(s.setting("a") == "1")
        #expect(s.setting("b") == nil)
    }

    @Test func settingsRoundTrip() throws {
        let s = try LocalStore(inMemoryWithRoot: tempRoot())
        s.setCodableSetting("k", ["x", "y"])
        #expect(s.codableSetting("k", as: [String].self) == ["x", "y"])
        s.setSetting("k", nil)
        #expect(s.setting("k") == nil)
    }

    @Test func clipboardCleanupKeepsPinnedAndRespectsBudget() throws {
        let s = try LocalStore(inMemoryWithRoot: tempRoot())
        let c = ClipboardStore(s)
        let now = Date()
        let old = now.addingTimeInterval(-31 * 86400)
        try c.insert(ClipboardItem(kind: .text, text: "old pinned", byteSize: 10, pinned: true, contentHash: "p", createdAt: old))
        try c.insert(ClipboardItem(kind: .text, text: "old", byteSize: 10, contentHash: "o", createdAt: old))
        for i in 0..<5 {
            try c.insert(ClipboardItem(kind: .image, filePath: "/tmp/\(i).png", byteSize: 100, contentHash: "i\(i)",
                                       createdAt: now.addingTimeInterval(Double(i))))
        }
        let paths = try c.cleanup(now: now, budget: 250)
        let left = c.recent(limit: 50)
        #expect(left.contains { $0.contentHash == "p" })
        #expect(!left.contains { $0.contentHash == "o" })
        #expect(c.totalBytes() <= 250)
        // Oldest images go first.
        #expect(Set(paths) == ["/tmp/0.png", "/tmp/1.png", "/tmp/2.png"])
        #expect(left.contains { $0.contentHash == "i4" })
    }

    @Test func clipboardDedupesByHashAndSearchesShortTokens() throws {
        let s = try LocalStore(inMemoryWithRoot: tempRoot())
        let c = ClipboardStore(s)
        try c.insert(ClipboardItem(kind: .text, text: "会议纪要 Asky", byteSize: 5, contentHash: "h"))
        try c.insert(ClipboardItem(kind: .text, text: "会议纪要 Asky", byteSize: 5, contentHash: "h"))
        #expect(c.recent(limit: 10).count == 1)
        #expect(c.search("会议").count == 1)      // 2 chars → LIKE fallback
        #expect(c.search("Asky").count == 1) // trigram index
        #expect(c.search("100%").isEmpty)        // LIKE metacharacters escaped
    }

    @Test func conversationPagingAndDeleteCascade() throws {
        let s = try LocalStore(inMemoryWithRoot: tempRoot())
        let cs = ConversationStore(s)
        let id = try cs.create(title: "t")
        for i in 1...130 { try cs.append(conversationID: id, role: "user", text: "message \(i)") }
        let first = cs.messages(conversationID: id, limit: 40)
        #expect(first.count == 40)
        #expect(first.first?.seq == 91 && first.last?.seq == 130)
        let older = cs.messages(conversationID: id, limit: 40, beforeSeq: first.first!.seq)
        #expect(older.last?.seq == 90)
        #expect(cs.search("message 7").count > 0)
        try cs.delete(id)
        #expect(cs.messages(conversationID: id, limit: 40).isEmpty)
        #expect(cs.search("message").isEmpty)
    }

    @Test func oldMessagesMigrateWithoutAttachments() throws {
        let db = try Database(path: ":memory:")
        try db.execute(Schema.migrations[0])
        try db.execute("PRAGMA user_version = 1")
        try db.run("INSERT INTO conversations(id,title,created_at,updated_at) VALUES('old','old',0,0)")
        try db.run("INSERT INTO messages(id,conversation_id,seq,role,text,created_at) VALUES('message','old',1,'user','old text',0)")
        try Schema.migrate(db)
        try Schema.migrate(db)
        let row = try #require(db.query("SELECT * FROM messages WHERE id = 'message'").first)
        #expect(ConversationStore.decode(row).text == "old text")
        #expect(ConversationStore.decode(row).attachments.isEmpty)
    }

    @Test func messageAttachmentsSurviveReopeningAndPaging() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let local = try LocalStore(root: root)
        let store = ConversationStore(local)
        let cid = try store.create(title: "附件")
        let refs = [AttachmentRef(kind: .image, path: "/local/picture.png", mimeType: "image/png", byteSize: 123, temporary: false),
                    AttachmentRef(kind: .file, path: "/local/AGENTS.md", mimeType: "text/plain", byteSize: 456, temporary: false)]
        let submitted = try store.append(conversationID: cid, role: "user", text: "查看附件", attachments: refs)
        try store.append(conversationID: cid, role: "assistant", text: "回复")
        let reopened = ConversationStore(try LocalStore(root: root))
        let restored = try #require(reopened.messages(conversationID: cid, limit: 1, beforeSeq: 2).first)
        #expect(restored.id == submitted.id)
        #expect(restored.text == submitted.text)
        #expect(restored.attachments == refs)
        #expect(reopened.messages(conversationID: cid, limit: 1).first?.attachments == [])
        #expect(reopened.search("查看").first?.attachments == refs)
        try reopened.delete(cid)
        #expect(reopened.messages(conversationID: cid, limit: 40).isEmpty)
    }

    @Test func mcpInstanceLookupByHashOnly() throws {
        let s = try LocalStore(inMemoryWithRoot: tempRoot())
        let m = MCPInstanceStore(s)
        let inst = MCPInstance(name: "Claude", enabled: true, sources: [.calendar])
        try m.save(inst, credentialHash: "abc")
        #expect(m.instance(credentialHash: "abc")?.id == inst.id)
        #expect(m.instance(credentialHash: "nope") == nil)
        #expect(MCPInstance(name: "x").enabled == false && MCPInstance(name: "x").readOnly)
    }

    @Test func activityExpiryPurges() throws {
        let s = try LocalStore(inMemoryWithRoot: tempRoot())
        let a = ActivityStore(s)
        try a.append(kind: "search", sourceID: "s1", text: "x", now: Date().addingTimeInterval(-31 * 86400))
        try a.append(kind: "search", sourceID: "s2", text: "y")
        #expect(try a.purgeExpired() == 1)
        #expect(a.count() == 1)
        #expect(!SourceStore(s).isDeleted("s1"))
    }
}
