import Testing
import Foundation
import Contracts
import LocalStore
@testable import Scheduler

private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return c
}

/// 2026-10-12 08:00 Asia/Shanghai.
private let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 8))!
private func at(_ h: Double) -> Date { now.addingTimeInterval(h * 3600) }
private func iso(_ d: Date) -> String { ISO8601DateFormatter().string(from: d) }

private let review = EventSnapshot(id: "ev-review", title: "季度评审", start: at(26), end: at(27))
private let deck = TaskSnapshot(id: "rm-deck", title: "准备评审 PPT", due: at(25))
private let memo = ContextSnippet(sourceID: "memory:m1", text: "老板希望评审时带上用户增长数据")
private let input = AdvisorInput(events: [review], tasks: [deck], memories: [memo], now: now)

private func advisor(_ reply: String, seen: (@Sendable (String) -> Void)? = nil) -> SmartAdvisor {
    SmartAdvisor(calendar: cal) { _, user in seen?(user); return reply }
}

@Suite struct SmartAdvisorTests {
    @Test func promptUsesAliasesNotSystemIDs() async throws {
        let box = Box()
        _ = try await advisor(#"{"suggestions":[]}"#, seen: { box.value = $0 }).suggest(input)
        #expect(box.value.contains("E1") && box.value.contains("T1") && box.value.contains("M1"))
        #expect(box.value.contains("老板希望") && !box.value.contains("ev-review"))
    }

    @Test func validSuggestionBecomesInsightPlanWithEvidence() async throws {
        let reply = """
            ```json
            {"suggestions":[{"anchor":"E1","title":"评审材料缺增长数据","body":"明天评审前PPT还没完成，老板提过要带增长数据。","fire_at":"\(iso(at(2)))","evidence":["T1","M1","X9"]}]}
            ```
            """
        let plans = try await advisor(reply).suggest(input)
        let p = try #require(plans.first)
        #expect(plans.count == 1 && p.reason == .insight && p.eventID == "event:ev-review")
        #expect(p.fireDate == at(2))
        #expect(p.evidence.contains("task:rm-deck") && p.evidence.contains("memory:m1"))
        #expect(p.evidence.contains("记忆：老板希望评审时带上用户增长数据") && !p.evidence.contains { $0.contains("X9") })
    }

    @Test func dropsUnknownAnchorsAndClampsTimes() async throws {
        let reply = """
            {"suggestions":[
              {"anchor":"E7","title":"幻觉","body":"不存在的日程","fire_at":"\(iso(at(1)))"},
              {"anchor":"E1","title":"太晚","body":"晚于日程开始","fire_at":"\(iso(at(40)))"},
              {"anchor":"T1","title":"过去","body":"时间已过","fire_at":"\(iso(at(-5)))"},
              {"anchor":"M1","title":"只锚定记忆","body":"不允许","fire_at":"\(iso(at(1)))"}
            ]}
            """
        let plans = try await advisor(reply).suggest(input)
        #expect(plans.map(\.eventID) == ["event:ev-review", "task:rm-deck"])
        #expect(plans[0].fireDate == review.start)
        #expect(plans[1].fireDate == now)
    }

    @Test func garbageOrEmptyReplyYieldsNothing() async throws {
        #expect(try await advisor("今天没什么要提醒的").suggest(input).isEmpty)
        #expect(try await advisor(#"{"suggestions":[]}"#).suggest(input).isEmpty)
        // Nothing to look at: no model call.
        let box = Box()
        let empty = AdvisorInput(events: [], tasks: [], memories: [memo], now: now)
        #expect(try await advisor("{}", seen: { box.value = $0 }).suggest(empty).isEmpty && box.value.isEmpty)
    }

    @Test func fingerprintAndValidity() async throws {
        #expect(input.fingerprint == AdvisorInput(events: [review], tasks: [deck], memories: [memo], now: at(5)).fingerprint)
        var moved = review
        moved.start = at(30)
        let changed = AdvisorInput(events: [moved], tasks: [deck], memories: [memo], now: now)
        #expect(changed.fingerprint != input.fingerprint)

        let reply = #"{"suggestions":[{"anchor":"E1","title":"t","body":"b","fire_at":"\#(iso(at(2)))"}]}"#
        let plans = try await advisor(reply).suggest(input)
        #expect(SmartAdvisor.stillValid(plans, in: input).count == 1)
        #expect(SmartAdvisor.stillValid(plans, in: changed).isEmpty)
    }

    @Test func messageNotesAreReferencedAndCanAnchorASuggestion() async throws {
        let note = MessageNote(id: "1068", sender: "王磊", date: at(-3), summary: "王磊要你周五前发合同扫描件，你已答应", due: at(80),
                               messageIDs: ["1068", "1069"])
        let withSMS = AdvisorInput(events: [], tasks: [], memories: [], messages: [note], now: now)
        let box = Box()
        let reply = #"{"suggestions":[{"anchor":"S1","title":"发合同扫描件","body":"王磊要你周五前发合同扫描件，还没有待办。","fire_at":"\#(iso(at(2)))","evidence":["S1"]}]}"#
        let plans = try await advisor(reply, seen: { box.value = $0 }).suggest(withSMS)
        // Notes alone are enough to ask; the advisor never sees raw message text.
        #expect(box.value.contains("S1") && box.value.contains("王磊：王磊要你周五前发合同扫描件") && box.value.contains("截止"))
        let p = try #require(plans.first)
        #expect(p.eventID == "message:1068" && p.evidence.contains("短信（王磊）：王磊要你周五前发合同扫描件，你已答应"))
        #expect(SmartAdvisor.stillValid(plans, in: withSMS).count == 1)
        let resolved = AdvisorInput(events: [], tasks: [], memories: [], messages: [], now: now)
        #expect(SmartAdvisor.stillValid(plans, in: resolved).isEmpty)
        #expect(resolved.fingerprint != withSMS.fingerprint)
    }

    @Test func insightsNeverTakeARuleConflictsSlot() throws {
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let s = ContextScheduler(store: ReminderStore(store), rules: ReminderRules(calendar: cal))
        let a = EventSnapshot(id: "a", title: "A", start: at(6), end: at(7))
        let b = EventSnapshot(id: "b", title: "B", start: at(6.5), end: at(8))
        let insights = (0..<3).map {
            ReminderPlan(eventID: "event:x\($0)", reason: .insight, title: "i\($0)", body: "b", evidence: ["event:x\($0)"],
                         fireDate: at(1), eventFingerprint: "f")
        }
        let out = try s.reconcile(events: [a, b], insights: insights, travelEnabled: false, now: now)
        #expect(out.schedule.count == 2)
        #expect(out.schedule.contains { $0.reason == .conflict })
    }
}

private final class Box: @unchecked Sendable { var value = "" }
