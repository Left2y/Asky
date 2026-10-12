import Testing
import Foundation
import Contracts
import LocalStore
@testable import Memory

private actor Calls {
    var prompts: [String] = []
    func add(_ p: String) { prompts.append(p) }
}

private func conversation(_ s: LocalStore, _ texts: [(String, String)]) throws -> String {
    let conv = ConversationStore(s)
    let cid = try conv.create(title: "t")
    for (role, text) in texts { try conv.append(conversationID: cid, role: role, text: text) }
    try SourceStore(s).upsert(SourceRecord(id: "conversation:\(cid)", kind: "conversation", title: "t",
                                           permissions: [.read, .aiUse, .extraction]))
    try ExtractionQueue(s).enqueue("conversation:\(cid)")
    return cid
}

@Suite struct MemoryExtractorTests {
    @Test func extractsUnconfirmedMemoriesIncrementally() async throws {
        let s = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let cid = try conversation(s, [("user", "我常从浦东出发"), ("assistant", "好的")])
        let calls = Calls()
        let extractor = MemoryExtractor(store: s) { _, user in
            await calls.add(user)
            return #"好的：{"memories":[{"content":"用户的常用机场是浦东","kind":"fact","subjects":["机场"]},{"content":" ","kind":"fact"}]}"#
        }
        let saved = await extractor.run()
        #expect(saved.map(\.content) == ["用户的常用机场是浦东"])
        #expect(saved.first?.confirmed == false && saved.first?.sourceIDs == ["conversation:\(cid)"])
        #expect(ExtractionQueue(s).count == 0)

        // Re-queue without new messages: no model call, nothing saved.
        try ExtractionQueue(s).enqueue("conversation:\(cid)")
        #expect(await extractor.run().isEmpty)
        #expect(await calls.prompts.count == 1)

        // New messages only: the prompt carries the new turn and the known memory, duplicates are skipped.
        try ConversationStore(s).append(conversationID: cid, role: "user", text: "我在做 Orion 项目")
        try ExtractionQueue(s).enqueue("conversation:\(cid)")
        _ = await extractor.run()
        let second = try #require(await calls.prompts.last)
        #expect(second.contains("Orion") && !second.contains("我常从浦东出发") && second.contains("- 用户的常用机场是浦东"))
        #expect(MemoryStore(s).list(limit: 10).count == 1)
    }

    @Test func failedCallRequeuesAndDeletedSourceIsSkipped() async throws {
        struct Boom: Error {}
        let s = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let cid = try conversation(s, [("user", "记一下我喜欢靠窗")])
        _ = await MemoryExtractor(store: s) { _, _ in throw Boom() }.run()
        #expect(ExtractionQueue(s).count == 1)

        let extractor = MemoryExtractor(store: s) { _, _ in
            try MemoryStore(s).deleteSource("conversation:\(cid)")
            return #"{"memories":[{"content":"用户喜欢靠窗座位","kind":"preference"}]}"#
        }
        #expect(await extractor.run().isEmpty)
        #expect(MemoryStore(s).list(limit: 10).isEmpty)
    }

    @Test func statedMemoryIsConfirmedAndDeduplicated() throws {
        let s = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let m = MemoryStore(s)
        let a = try m.saveStated("用户偏好中文回复", kind: .preference)
        let b = try m.saveStated("用户偏好中文回复", kind: .preference)
        #expect(a.id == b.id && a.confirmed && a.permissions == [.read, .aiUse])
        #expect(m.search("中文回复").map(\.id) == [a.id])
    }
}
