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
                throw ToolError(.targetNotFound, CoreLocalization.format("找不到日历「%@」。", String(describing: selector)) + availability(writable))
            }
            guard matches.count == 1 else {
                throw ToolError(.ambiguousTarget, CoreLocalization.format("有多个名为「%@」的日历，请使用 ID 选择：", String(describing: selector)) + matches.map(\.label).joined(separator: "、"))
            }
            selected = matches[0]
        } else if let cal = calendars.first(where: { $0.id == defaultID && $0.writable }) {
            selected = cal
        } else {
            guard !writable.isEmpty else {
                throw ToolError(.targetReadOnly, availability(writable))
            }
            guard writable.count == 1 else {
                throw ToolError(.ambiguousTarget, CoreLocalization.format("系统默认日历不可用，请选择一个可写日历：%@", String(describing: candidates)))
            }
            selected = writable[0]
        }
        guard selected.writable else {
            throw ToolError(.targetReadOnly, CoreLocalization.format("日历%@只读。", String(describing: selected.label)) + availability(writable))
        }
        return selected.id
    }

    private static func availability(_ calendars: [CalendarChoice]) -> String {
        calendars.isEmpty
            ? CoreLocalization.text("没有可写日历，请在系统日历 App 中启用日历账户或创建日历后重试。")
            : CoreLocalization.text("可写日历：") + calendars.map(\.label).joined(separator: "、")
    }
}
