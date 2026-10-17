import Foundation
import Testing
import Contracts
import LocalStore
@testable import Scheduler

private actor CalendarWriter {
    var requests: [ActionRequest] = []
    var pending: Bool
    var failing: Bool
    init(pending: Bool = false, failing: Bool = false) { self.pending = pending; self.failing = failing }
    func submit(_ request: ActionRequest) async -> ExecutionResult {
        requests.append(request)
        try? await Task.sleep(for: .milliseconds(20))
        if failing { return .failure(request.requestID, .conflict, "冲突") }
        return ExecutionResult(requestID: request.requestID, status: pending ? .pendingVerification : .completed)
    }
}

@Suite struct MessageCalendarCreationTests {
    private var now: Date { Date(timeIntervalSince1970: 1_791_763_200) }
    private var draft: MessageCalendarDraft { .init(title: "产品评审", start: now.addingTimeInterval(86400), location: "会议室") }

    @Test func concurrentClicksShareOneWriteAndUseExplicitNativeIntent() async throws {
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let creation = MessageCalendarCreation(store: store)
        let writer = CalendarWriter()
        async let a = creation.submit(sourceID: "sms1", draft: draft, now: now) { await writer.submit($0) }
        async let b = creation.submit(sourceID: "sms1", draft: draft, now: now) { await writer.submit($0) }
        let (first, second) = await (a, b)
        let requests = await writer.requests
        #expect(first.requestID == second.requestID && requests.count == 1)
        #expect(requests[0].tool == "calendar_create_event" && requests[0].origin == .launcher)
        #expect(requests[0].intent == .explicitRequest && requests[0].arguments["allowConflict"] == nil)
    }

    @Test func editedCalendarAndNotesReachTheWriterAndLegacyDraftsStillDecode() async throws {
        var edited = draft
        edited.calendar = "writable-calendar-id"
        edited.notes = "带上新版原型"
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let creation = MessageCalendarCreation(store: store)
        let writer = CalendarWriter()
        _ = await creation.submit(sourceID: "edited", draft: edited, now: now) { await writer.submit($0) }
        let request = await writer.requests.first
        #expect(request?.arguments["calendar"]?.stringValue == edited.calendar)
        #expect(request?.arguments["notes"]?.stringValue == edited.notes)
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as! [String: Any]
        legacy.removeValue(forKey: "calendar")
        legacy.removeValue(forKey: "notes")
        let decoded = try JSONDecoder().decode(MessageCalendarDraft.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(decoded.calendar == nil && decoded.notes == nil && decoded.title == draft.title)
    }

    @Test func pendingAndCompletedRequestsKeepTheirIdentityAcrossRelaunches() async throws {
        for pending in [true, false] {
            let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
            let writer = CalendarWriter(pending: pending)
            let original = MessageCalendarCreation(store: store)
            let first = await original.submit(sourceID: "sms1", draft: draft, now: now) { await writer.submit($0) }
            let relaunched = MessageCalendarCreation(store: store)
            var edited = draft
            edited.title = "不同标题"
            _ = await relaunched.submit(sourceID: "sms1", draft: edited, now: now) { await writer.submit($0) }
            let requests = await writer.requests
            #expect(requests.count == 2 && requests[1].requestID == first.requestID)
            #expect(requests[1].arguments == requests[0].arguments)
        }
    }

    @Test func definitiveFailureAllowsANewAttemptButInvalidDraftNeverWrites() async throws {
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let creation = MessageCalendarCreation(store: store)
        let writer = CalendarWriter(failing: true)
        var invalid = draft
        invalid.end = invalid.start.addingTimeInterval(-1)
        let rejected = await creation.submit(sourceID: "invalid", draft: invalid, now: now) { await writer.submit($0) }
        let rejectedRequests = await writer.requests
        #expect(rejected.error?.code == .invalidArguments && rejectedRequests.isEmpty)
        _ = await creation.submit(sourceID: "sms1", draft: draft, now: now) { await writer.submit($0) }
        #expect(await creation.hasRequest(sourceID: "sms1") == false)
        _ = await creation.submit(sourceID: "sms1", draft: draft, now: now) { await writer.submit($0) }
        let attempts = await writer.requests
        #expect(attempts.count == 2 && attempts[0].requestID != attempts[1].requestID)
    }

    @Test func appointmentCandidatesIgnoreExistingEventsAndChangedDraftsInvalidateCache() throws {
        let note = MessageNote(id: "10", sender: "同事", date: now, summary: "明天产品评审", messageIDs: ["10"], calendarDraft: draft)
        var input = AdvisorInput(events: [], tasks: [], memories: [], messages: [note], now: now)
        let plans = SmartAdvisor.calendarSuggestions(in: input)
        var duplicate = note
        duplicate.id = "11"
        input.messages.append(duplicate)
        #expect(SmartAdvisor.calendarSuggestions(in: input).count == 1)
        input.messages = [note]
        #expect(plans.count == 1 && plans[0].fireDate == now)
        input.events = [.init(id: "existing", title: draft.title, start: draft.start, end: draft.proposedEnd)]
        #expect(SmartAdvisor.calendarSuggestions(in: input).isEmpty)
        #expect(SmartAdvisor.stillValid(plans, in: input).isEmpty)
        input.events = []
        input.messages[0].calendarDraft?.location = "新会议室"
        #expect(SmartAdvisor.stillValid(plans, in: input).isEmpty)
        #expect(SmartAdvisor.matchesMessage(input.messages[0], plan: plans[0]) == false)
    }
}
