import EventKit
import Contracts

struct CalendarChoice {
    let id: String
    let name: String
    let account: String
    let writable: Bool

    init(id: String, name: String, account: String, writable: Bool) {
        self.id = id
        self.name = name
        self.account = account
        self.writable = writable
    }

    init(_ calendar: EKCalendar) {
        self.init(id: calendar.calendarIdentifier, name: calendar.title,
                  account: calendar.source.title, writable: calendar.allowsContentModifications)
    }

    var label: String { "「\(name)」（\(account)，ID: \(id)）" }
}

/// Pure target selection shared by preview and execution; never guesses among multiple calendars.
enum CalendarSelection {
    static func resolve(selector: String?, defaultID: String?, calendars: [CalendarChoice]) throws -> String {
        let writable = calendars.filter(\.writable)
        let candidates = writable.map(\.label).joined(separator: "、")
        let selected: CalendarChoice
        if let selector {
            let matches = calendars.contains(where: { $0.id == selector })
                ? calendars.filter { $0.id == selector }
                : calendars.filter { $0.name == selector }
            guard !matches.isEmpty else {
                throw ToolError(.targetNotFound, "找不到日历「\(selector)」。" + availability(writable))
            }
            guard matches.count == 1 else {
                throw ToolError(.ambiguousTarget, "有多个名为「\(selector)」的日历，请使用 ID 选择：" + matches.map(\.label).joined(separator: "、"))
            }
            selected = matches[0]
        } else if let cal = calendars.first(where: { $0.id == defaultID && $0.writable }) {
            selected = cal
        } else {
            guard !writable.isEmpty else {
                throw ToolError(.targetReadOnly, availability(writable))
            }
            guard writable.count == 1 else {
                throw ToolError(.ambiguousTarget, "系统默认日历不可用，请选择一个可写日历：\(candidates)")
            }
            selected = writable[0]
        }
        guard selected.writable else {
            throw ToolError(.targetReadOnly, "日历\(selected.label)只读。" + availability(writable))
        }
        return selected.id
    }

    private static func availability(_ calendars: [CalendarChoice]) -> String {
        calendars.isEmpty
            ? "没有可写日历，请在系统日历 App 中启用日历账户或创建日历后重试。"
            : "可写日历：" + calendars.map(\.label).joined(separator: "、")
    }
}
