import AppKit
import Contracts
import Scheduler

@main @MainActor
enum CalendarEditorRegression {
    static func main() {
        let start = Date().addingTimeInterval(86400)
        let draft = MessageCalendarDraft(title: "产品评审", start: start, location: "3 号会议室")
        let choices = [MessageCalendarChoice(id: "personal", name: "个人", account: "iCloud", isDefault: true),
                       MessageCalendarChoice(id: "work", name: "工作", account: "iCloud")]
        let model = MessageCalendarEditorModel(draft, calendars: choices, source: "带上新版原型")
        precondition(model.isValid && model.end == start.addingTimeInterval(3600))
        model.title = " "
        precondition(!model.isValid)
        model.title = "产品评审"
        model.end = start.addingTimeInterval(-60)
        precondition(!model.isValid)
        model.end = start.addingTimeInterval(3600)
        model.calendarID = "missing"
        precondition(!model.isValid)
        model.calendarID = "work"
        precondition(model.isValid && model.draft.arguments["calendar"]?.stringValue == "work")
        precondition(model.draft.arguments["notes"]?.stringValue == "带上新版原型")
        let calendar = Calendar(identifier: .gregorian)
        let pickedDay = calendar.date(byAdding: .day, value: 3, to: start)!
        let picked = CalendarMonthPicker.selecting(pickedDay, preservingTimeFrom: start, calendar: calendar)!
        precondition(calendar.isDate(picked, inSameDayAs: pickedDay))
        precondition(calendar.component(.hour, from: picked) == calendar.component(.hour, from: start))
        precondition(calendar.component(.minute, from: picked) == calendar.component(.minute, from: start))
        precondition(MessageCalendarChoice.writableChoices([
            ["id": "read-only", "name": "生日", "writable": false],
            ["id": "work", "name": "工作", "writable": true]
        ]).map(\.id) == ["work"])
        print("Calendar editor model validation passed")
        guard CommandLine.arguments.contains("--preview") else { return }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        Task { @MainActor in
            var attempts = 0
            _ = await MessageCalendarEditor.present(draft, calendars: choices, source: "带上新版原型") { _ in
                attempts += 1
                if CommandLine.arguments.contains("--preview-error"), attempts == 1 {
                    return .failure("preview", .conflict, "该时间与已有日程冲突，请调整后重试。")
                }
                return ExecutionResult(requestID: "preview", status: .completed)
            }
            print("Preview finished; no calendar writes")
            exit(0)
        }
        app.run()
    }
}
