import Testing
import Foundation
import Contracts
@testable import Scheduler

private let now = Date(timeIntervalSince1970: 1_791_763_200)
private func msg(_ id: Int, _ chat: String, _ text: String, mine: Bool = false, ago hours: Double = 1) -> MessageSnapshot {
    MessageSnapshot(id: String(id), conversation: chat, sender: chat == "c:1" ? "王磊" : "快递", isFromMe: mine,
                    date: now.addingTimeInterval(-hours * 3600), text: text)
}

private final class Calls: @unchecked Sendable {
    var prompts: [String] = []
    var replies: [String]
    var failAt: Int?
    init(_ replies: [String], failAt: Int? = nil) { self.replies = replies; self.failAt = failAt }
}

private func triage(_ calls: Calls, batch: Int = 2500) -> MessageTriage {
    var t = MessageTriage { _, user in
        calls.prompts.append(user)
        if calls.failAt == calls.prompts.count { throw URLError(.timedOut) }
        return calls.replies.isEmpty ? #"{"items":[]}"# : calls.replies.removeFirst()
    }
    t.batchCharacters = batch
    return t
}

@Suite struct MessageTriageTests {
    @Test func splitsNewMessagesIntoSmallBatchesOldestFirst() {
        let t = triage(Calls([]), batch: 10)
        let all = [msg(3, "c:1", "123456"), msg(1, "c:1", "1234567"), msg(2, "c:1", "1234"), msg(4, "c:2", "12345678901")]
        #expect(t.batches(all, after: 0).map { $0.map(\.id) } == [["1"], ["2", "3"], ["4"]])
        #expect(t.batches(all, after: 2).map { $0.map(\.id) } == [["3"], ["4"]])
    }

    @Test func eachMessageIsSentOnceAndOnlyNotesAreKept() async {
        let calls = Calls([#"{"items":[{"source":["S1","S2"],"summary":"王磊要你周五前发合同，你已答应","due":null}]}"#])
        let first = [msg(10, "c:1", "周五前把合同发我"), msg(11, "c:1", "好的", mine: true), msg(12, "c:2", "广告：双十一大促")]
        let state = await triage(calls).update(MessageTriageState(), messages: first, now: now)
        #expect(calls.prompts.count == 1 && state.watermark == 12)
        #expect(state.notes.map(\.summary) == ["王磊要你周五前发合同，你已答应"])
        #expect(state.notes[0].id == "10" && state.notes[0].sender == "王磊" && state.notes[0].messageIDs == ["10", "11"])

        // Nothing new: no call at all.
        let same = await triage(calls).update(state, messages: first, now: now)
        #expect(calls.prompts.count == 1 && same == state)

        // A later message closes the note; earlier messages of that chat come along only as context.
        calls.replies = [#"{"items":[],"resolved":["N1"]}"#]
        let next = await triage(calls).update(state, messages: first + [msg(13, "c:1", "合同收到了，谢谢")], now: now)
        let prompt = calls.prompts.last ?? ""
        #expect(prompt.contains("N1 王磊：王磊要你周五前发合同") && prompt.contains("C1") && prompt.contains("S1") && prompt.contains("合同收到了"))
        #expect(!prompt.contains("双十一"))
        #expect(next.notes.isEmpty && next.watermark == 13)
    }

    @Test func failureKeepsWatermarkAtLastGoodBatchAndDropsBadAliases() async {
        let calls = Calls([#"{"items":[{"source":["S9"],"summary":"不存在"},{"source":["S1"],"summary":"取件码已发，今天取快递"}]}"#], failAt: 2)
        let messages = [msg(1, "c:2", "您的快递已到驿站，请今天取件"), msg(2, "c:1", String(repeating: "长", count: 30))]
        let state = await triage(calls, batch: 20).update(MessageTriageState(), messages: messages, now: now)
        #expect(calls.prompts.count == 2)
        #expect(state.watermark == 1 && state.notes.map(\.summary) == ["取件码已发，今天取快递"])
    }

    @Test func notesOutsideTheWindowExpire() async {
        let old = MessageNote(id: "1", sender: "王磊", date: now.addingTimeInterval(-31 * 86400), summary: "旧事", messageIDs: ["1"])
        let state = await triage(Calls([])).update(MessageTriageState(notes: [old], watermark: 5), messages: [], now: now)
        #expect(state.notes.isEmpty && state.watermark == 5)
    }
}
