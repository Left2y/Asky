import AppKit
import Scheduler

@main @MainActor
enum MessageCalendarRegression {
    static func main() async {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        application.finishLaunching()
        let start = Date().addingTimeInterval(86400)
        let original = MessageCalendarDraft(title: "产品评审", start: start, location: "3 号会议室")
        let model = MessageCalendarEditorModel(original)
        precondition(model.isValid && model.end == start.addingTimeInterval(3600))
        model.title = "  "
        precondition(!model.isValid)
        model.title = "编辑后的日程"
        model.end = start.addingTimeInterval(-60)
        precondition(!model.isValid)
        model.end = start.addingTimeInterval(1800)
        precondition(model.isValid && model.draft.title == "编辑后的日程")

        if CommandLine.arguments.contains("--preview") {
            let edited = await MessageCalendarEditor.present(original, source: "测试短信：明天下午在 3 号会议室参加产品评审。不会写入真实日历。")
            print(edited == nil ? "Preview cancelled; no write" : "Preview confirmed; no write")
        } else {
            // Exercise the real modal/editor cancellation. The regression never calls ToolService.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.abortModal() }
            let cancelled = await MessageCalendarEditor.present(original, source: "取消回归测试，不写入日历。")
            precondition(cancelled == nil)
            print("Message calendar editor validation and cancellation passed")
        }
        exit(0)
    }
}
