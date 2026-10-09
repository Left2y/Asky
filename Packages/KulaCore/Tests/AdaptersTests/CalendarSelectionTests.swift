import Testing
import Contracts
@testable import Adapters

@Suite struct CalendarSelectionTests {
    let personal = CalendarChoice(id: "personal", name: "个人", account: "iCloud", writable: true)
    let work = CalendarChoice(id: "work", name: "工作", account: "Exchange", writable: true)
    let holidays = CalendarChoice(id: "holidays", name: "节假日", account: "订阅", writable: false)

    @Test func prefersWritableDefault() throws {
        #expect(try CalendarSelection.resolve(selector: nil, defaultID: "work", calendars: [personal, work]) == "work")
    }

    @Test func missingOrReadOnlyDefaultUsesOnlyWritableCalendar() throws {
        for id: String? in [nil, "deleted", "holidays"] {
            #expect(try CalendarSelection.resolve(selector: nil, defaultID: id, calendars: [holidays, personal]) == "personal")
        }
    }

    @Test func multipleCandidatesRequireChoiceAndIncludeRealTargets() {
        do {
            _ = try CalendarSelection.resolve(selector: nil, defaultID: nil, calendars: [personal, work])
            Issue.record("Should require selection")
        } catch let error as ToolError {
            #expect(error.code == .ambiguousTarget)
            #expect(error.message.contains("个人") && error.message.contains("Exchange") && error.message.contains("ID: work"))
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func explicitNamesAndIDsNeverFallBack() throws {
        #expect(try CalendarSelection.resolve(selector: "工作", defaultID: "personal", calendars: [personal, work]) == "work")
        #expect(try CalendarSelection.resolve(selector: "work", defaultID: nil, calendars: [work]) == "work")
        #expect(throws: ToolError(.targetNotFound, "找不到日历「不存在」。可写日历：「个人」（iCloud，ID: personal）")) {
            try CalendarSelection.resolve(selector: "不存在", defaultID: "personal", calendars: [personal])
        }
        #expect(throws: ToolError.self) {
            try CalendarSelection.resolve(selector: "节假日", defaultID: "personal", calendars: [holidays, personal])
        }
    }

    @Test func duplicateNamesNeedID() throws {
        let other = CalendarChoice(id: "other", name: "个人", account: "本机", writable: true)
        #expect(throws: ToolError.self) {
            try CalendarSelection.resolve(selector: "个人", defaultID: nil, calendars: [personal, other])
        }
        #expect(try CalendarSelection.resolve(selector: "other", defaultID: nil, calendars: [personal, other]) == "other")
    }

    @Test func noWritableCalendarGivesRecoveryInstructions() {
        for calendars in [[], [holidays]] {
            do {
                _ = try CalendarSelection.resolve(selector: nil, defaultID: nil, calendars: calendars)
                Issue.record("Should reject unwritable calendars")
            } catch let error as ToolError {
                #expect(error.code == .targetReadOnly)
                #expect(error.message.contains("系统日历 App"))
            } catch { Issue.record("Unexpected error: \(error)") }
        }
    }

    @Test func calendarDiscoveryIsRegisteredAndReadOnly() throws {
        let tools = NativeTools(notesFolders: { [] }).adapters(memories: nil)
        let tool = try #require(tools.first { $0.definition.name == "calendar_list_calendars" })
        #expect(tool.definition.effect == .read)
        #expect(tool.definition.source == .calendar)
        #expect(tool.definition.externallyExposable && tool.definition.agentExposable)
    }
}
