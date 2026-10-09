import Testing
import Foundation
import Contracts
import LocalStore
@testable import Memory

private func setup() throws -> (LocalStore, MemoryStore, SourceStore) {
    let s = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
    let src = SourceStore(s)
    try src.upsert(SourceRecord(id: "chat", kind: "conversation", title: "c", permissions: [.read, .aiUse, .extraction]))
    try src.upsert(SourceRecord(id: "note", kind: "note", title: "n", permissions: [.read]))
    return (s, MemoryStore(s), src)
}

@Suite struct MemoryTests {
    @Test func permissionsAreIntersectionOfSources() throws {
        let (_, m, _) = try setup()
        let mixed = try m.insert(MemoryRecord(content: "项目 Orion 截止 10 月底", kind: .episode, sourceIDs: ["chat", "note"],
                                              permissions: [.read, .aiUse, .extraction]))
        #expect(mixed.permissions == [.read])
        #expect(m.search("Orion").isEmpty)                         // not AI-usable
        #expect(m.search("Orion", requiring: [.read]).count == 1)
    }

    @Test func extractionRequiresPermissionAndDeletionMarkerBlocksRebuild() throws {
        let (_, m, _) = try setup()
        #expect(throws: MemoryStore.InsertError.extractionNotAllowed("note")) {
            try m.insert(MemoryRecord(content: "x", kind: .inference, sourceIDs: ["note"], permissions: [.aiUse]), extracted: true)
        }
        try m.insert(MemoryRecord(content: "喜欢靠窗座位", kind: .preference, sourceIDs: ["chat"], permissions: [.read, .aiUse]))
        let r = try m.deleteSource("chat")
        #expect(r.deleted.count == 1)
        #expect(m.search("靠窗座位").isEmpty)
        #expect(throws: MemoryStore.InsertError.sourceDeleted("chat")) {
            try m.insert(MemoryRecord(content: "y", kind: .fact, sourceIDs: ["chat"], permissions: [.read]))
        }
    }

    @Test func deleteSourceKeepsPinnedAndTightensMixed() throws {
        let (_, m, src) = try setup()
        try src.upsert(SourceRecord(id: "chat2", kind: "conversation", title: "c2", permissions: [.read, .aiUse]))
        let pinned = try m.insert(MemoryRecord(content: "生日 3 月 2 日", kind: .fact, sourceIDs: ["chat"], pinned: true,
                                               permissions: [.read, .aiUse]))
        let mixed = try m.insert(MemoryRecord(content: "周会改到周四", kind: .episode, sourceIDs: ["chat", "chat2"],
                                              permissions: [.read, .aiUse]))
        let r = try m.deleteSource("chat")
        #expect(r.marked.sorted() == [pinned.id, mixed.id].sorted())
        #expect(m.get(pinned.id)?.sourceDeleted == true)
        #expect(m.get(mixed.id)?.sourceIDs == ["chat2"])
        #expect(src.isDeleted("chat"))
    }

    @Test func correctionSupersedes() throws {
        let (_, m, _) = try setup()
        let old = try m.insert(MemoryRecord(content: "常用机场是虹桥", kind: .inference, sourceIDs: ["chat"], permissions: [.read, .aiUse]))
        let new = try #require(try m.correct(old.id, newContent: "常用机场是浦东"))
        #expect(new.kind == .fact && new.confirmed && new.supersedes == old.id)
        #expect(m.get(old.id)?.status == .superseded && m.get(old.id)?.supersededBy == new.id)
        #expect(m.search("常用机场").map(\.id) == [new.id])
    }

    @Test func revokingAIUseRefreshesDerivedMemories() throws {
        let (_, m, src) = try setup()
        let r = try m.insert(MemoryRecord(content: "偏好中文回复", kind: .preference, sourceIDs: ["chat"], permissions: [.read, .aiUse]))
        try src.upsert(SourceRecord(id: "chat", kind: "conversation", title: "c", permissions: [.read]))
        try m.refreshPermissions(forSource: "chat")
        #expect(m.get(r.id)?.permissions == [.read])
        #expect(ContextAssembler(memories: m).snippets(for: "中文回复").isEmpty)
    }

    @Test func assemblerLabelsInferenceAndBoundsSize() throws {
        let (_, m, _) = try setup()
        try m.insert(MemoryRecord(content: "可能在准备搬家", kind: .inference, sourceIDs: ["chat"], permissions: [.read, .aiUse]))
        try m.insert(MemoryRecord(content: "准备搬家" + String(repeating: "很", count: 50), kind: .fact, sourceIDs: ["chat"],
                                  permissions: [.read, .aiUse]))
        let s = ContextAssembler(memories: m, maxCharacters: 60).snippets(for: "准备搬家")
        #expect(s.count == 1)
        let all = ContextAssembler(memories: m).snippets(for: "准备搬家")
        #expect(all.contains { $0.text.hasPrefix("（推测）") })
    }

    @Test func extractionQueueFiltersCoalescesAndBounds() throws {
        let (s, m, src) = try setup()
        let q = ExtractionQueue(s)
        #expect(try q.enqueue("chat"))
        #expect(try q.enqueue("chat"))
        #expect(!(try q.enqueue("note")))
        #expect(q.count == 1)
        for i in 0..<(ExtractionQueue.capacity + 5) {
            try src.upsert(SourceRecord(id: "s\(i)", kind: "k", title: "", permissions: [.extraction]))
            try q.enqueue("s\(i)", now: Date().addingTimeInterval(Double(i)))
        }
        #expect(q.count == ExtractionQueue.capacity)
        try m.deleteSource("s10")
        let batch = try q.takeBatch(max: 1000)
        #expect(!batch.contains("s10") && batch.count <= ExtractionQueue.capacity)
        #expect(q.count == 0)
    }
}
