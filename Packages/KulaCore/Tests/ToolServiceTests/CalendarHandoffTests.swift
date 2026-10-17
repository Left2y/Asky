import Foundation
import Testing
@testable import ToolService

struct CalendarHandoffTests {
    @Test func preservesDatesAndEscapesUntrustedText() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let text = try CalendarHandoff.content(title: "评审,会议;\\\r\nBEGIN:VEVENT",
            start: start, end: start.addingTimeInterval(3600), location: "会议室,一",
            sourceID: "source\r\nUID:injected", notes: "第一行\n第二行")
        #expect(text.contains("DTSTART:20270115T080000Z\r\n"))
        #expect(text.contains("DTEND:20270115T090000Z\r\n"))
        #expect(text.contains("SUMMARY:评审\\,会议\\;\\\\\\nBEGIN:VEVENT\r\n"))
        #expect(text.contains("LOCATION:会议室\\,一\r\n"))
        #expect(text.contains("DESCRIPTION:第一行\\n第二行\r\n"))
        #expect(text.components(separatedBy: "\r\n").filter { $0 == "BEGIN:VEVENT" }.count == 1)
        #expect(!text.contains("\r\nUID:injected"))
    }

    @Test func foldsUTF8AndKeepsSourceIdentity() throws {
        let title = String(repeating: "产品评审🍙", count: 30)
        let start = Date()
        let first = try CalendarHandoff.content(title: title, start: start,
            end: start.addingTimeInterval(3600), location: nil, sourceID: "same", notes: "")
        let second = try CalendarHandoff.content(title: "修改后", start: start,
            end: start.addingTimeInterval(7200), location: nil, sourceID: "same", notes: "")
        #expect(first.components(separatedBy: "\r\n").allSatisfy { $0.utf8.count <= 75 })
        #expect(first.replacingOccurrences(of: "\r\n ", with: "").contains("SUMMARY:\(title)\r\n"))
        let uid = first.components(separatedBy: "\r\n").first { $0.hasPrefix("UID:") }
        #expect(uid != nil && second.contains(uid!))
    }

    @Test func rejectsInvalidDrafts() {
        let start = Date()
        #expect(throws: CalendarHandoff.Failure.self) {
            try CalendarHandoff.content(title: " ", start: start, end: start.addingTimeInterval(60),
                location: nil, sourceID: "id", notes: "")
        }
        #expect(throws: CalendarHandoff.Failure.self) {
            try CalendarHandoff.content(title: "日程", start: start, end: start,
                location: nil, sourceID: "id", notes: "")
        }
    }
}
