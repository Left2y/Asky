import AppKit
import SwiftUI
import Scheduler
import ToolService

/// Uses the shared app dialog; nothing is written until the user accepts the edited fields.
@MainActor
enum MessageCalendarEditor {
    static func present(_ draft: MessageCalendarDraft, source: String) -> MessageCalendarDraft? {
        let model = MessageCalendarEditorModel(draft)
        let alert = AppDialog.make()
        alert.messageText = NSLocalizedString("创建日程？", comment: "")
        alert.informativeText = source + (draft.end == nil
            ? "\n\n" + NSLocalizedString("短信未提供结束时间，暂按 1 小时预填，请确认或修改。", comment: "") : "")
        let create = alert.addButton(withTitle: NSLocalizedString("创建日程", comment: ""))
        create.keyEquivalent = "\r"
        create.isEnabled = model.isValid
        alert.addButton(withTitle: NSLocalizedString("取消", comment: "")).keyEquivalent = "\u{1b}"
        let form = MessageCalendarEditorForm(model: model) { create.isEnabled = $0 }
        let host = NSHostingView(rootView: form)
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 330)
        alert.accessoryView = host
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn, model.isValid else { return nil }
        return model.draft
    }
}

@MainActor @Observable
final class MessageCalendarEditorModel {
    var title: String
    var start: Date
    var end: Date
    var location: String

    init(_ draft: MessageCalendarDraft) {
        title = draft.title
        start = draft.start
        end = draft.proposedEnd
        location = draft.location ?? ""
    }

    var draft: MessageCalendarDraft { .init(title: title, start: start, end: end, location: location) }
    var isValid: Bool { draft.isValid(at: Date()) }
}

private struct MessageCalendarEditorForm: View {
    @Bindable var model: MessageCalendarEditorModel
    var onValidityChange: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            field("标题") {
                TextField("", text: $model.title).accessibilityLabel(NSLocalizedString("标题", comment: ""))
            }
            field("开始时间") { dateAndTime($model.start) }
            field("结束时间") { dateAndTime($model.end) }
            field("地点") {
                TextField("", text: $model.location).accessibilityLabel(NSLocalizedString("地点", comment: ""))
            }
            Text(model.isValid ? " " : NSLocalizedString("请填写标题和未来的开始时间，结束时间须晚于开始时间。", comment: ""))
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(model.isValid)
        }
        .font(.system(size: 14))
        .textFieldStyle(.roundedBorder)
        .controlSize(.large)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(width: 400, height: 330, alignment: .topLeading)
        .onChange(of: model.isValid) { _, valid in onValidityChange(valid) }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString(title, comment: ""))
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dateAndTime(_ date: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            DatePicker(NSLocalizedString("日期", comment: ""), selection: date, displayedComponents: [.date])
            DatePicker(NSLocalizedString("时间", comment: ""), selection: date, displayedComponents: [.hourAndMinute])
            Spacer(minLength: 0)
        }
        .labelsHidden()
    }
}
