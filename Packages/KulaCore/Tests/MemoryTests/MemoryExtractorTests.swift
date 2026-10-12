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
        #expect(second.contains("Orion") && !second.contains("我常从浦东出发") && second.contains("M1 用户的常用机场是浦东"))
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

    @Test func revisesAndDeletesExistingMemoriesFromConversation() async throws {
        let s = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let m = MemoryStore(s)
        let t0 = Date().addingTimeInterval(-60)
        let city = try m.saveStated("用户住在上海", kind: .fact, now: t0)
        let project = try m.saveStated("用户在做 Orion 项目", kind: .episode, now: t0.addingTimeInterval(1))
        let pinned = try m.saveStated("用户的生日是 3 月 2 日", kind: .fact, now: t0.addingTimeInterval(2))
        try m.setPinned(pinned.id, true)
        let cid = try conversation(s, [("user", "我上个月搬到杭州了，Orion 项目也结束了")])
        let calls = Calls()
        // list() orders pinned first, then newest: M1 生日, M2 Orion, M3 上海
        let saved = await MemoryExtractor(store: s) { _, user in
            await calls.add(user)
            return #"{"memories":[],"updates":[{"id":"M3","content":"用户住在杭州"},{"id":"M9","content":"x"},{"id":"M3","content":"重复"}],"deletes":["M2","M1"]}"#
        }.run()
        #expect(await calls.prompts.first?.contains("M3 用户住在上海") == true)
        #expect(saved.map(\.content) == ["用户住在杭州"])
        #expect(saved.first?.sourceIDs == [MemoryStore.assistantSourceID, "conversation:\(cid)"] && saved.first?.confirmed == true)
        #expect(m.get(city.id)?.status == .superseded)
        #expect(m.get(project.id) == nil)
        #expect(m.get(pinned.id)?.status == .active)
    }

    @Test func pruneDropsStaleUnconfirmedAndEpisodesButKeepsUsedConfirmedAndPinned() throws {
        let s = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        try SourceStore(s).upsert(SourceRecord(id: "chat", kind: "conversation", title: "c", permissions: [.read, .aiUse, .extraction]))
        let m = MemoryStore(s)
        let old = Date(timeIntervalSince1970: 0)
        let now = old.addingTimeInterval(MemoryStore.episodeLifetime + 1)
        func add(_ c: String, _ kind: MemoryKind, confirmed: Bool = false, pinned: Bool = false) throws -> MemoryRecord {
            try m.insert(MemoryRecord(content: c, kind: kind, sourceIDs: ["chat"], confirmed: confirmed, pinned: pinned,
                                      permissions: [.read, .aiUse], createdAt: old, updatedAt: old))
        }
        let guess = try add("用户可能喜欢咖啡", .inference)
        let usedGuess = try add("用户可能喜欢茶", .inference)
        let episode = try add("用户在筹备婚礼", .episode, confirmed: true)
        let fact = try add("用户住在杭州", .fact, confirmed: true)
        let pinnedGuess = try add("用户可能养猫", .inference, pinned: true)
        m.markUsed([usedGuess.id], now: now)
        #expect(try m.pruneStale(now: now) == 2)
        #expect(m.get(guess.id) == nil && m.get(episode.id) == nil)
        #expect(m.get(usedGuess.id) != nil && m.get(fact.id) != nil && m.get(pinnedGuess.id) != nil)
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
