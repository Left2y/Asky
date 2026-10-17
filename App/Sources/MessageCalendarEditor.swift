import AppKit
import SwiftUI
import Scheduler
import ToolService

/// Uses the shared app dialog; nothing is written until the user accepts the edited fields.
@MainActor
enum MessageCalendarEditor {
    static func present(_ draft: MessageCalendarDraft, source: String) async -> MessageCalendarDraft? {
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
        guard await AppDialog.present(alert) == .alertFirstButtonReturn, model.isValid else { return nil }
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
        NativeDateTimeSelect(selection: date)
            .fixedSize()
    }
}

private struct NativeDateTimeSelect: NSViewRepresentable {
    @Binding var selection: Date

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let select = NSPopUpButton(frame: .zero, pullsDown: false)
        select.controlSize = .regular
        select.font = .systemFont(ofSize: 14)
        select.setAccessibilityLabel(NSLocalizedString("日期和时间", comment: ""))
        let menu = NSMenu()
        menu.autoenablesItems = false
        let value = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menu.addItem(value)
        let picker = NSDatePicker()
        picker.datePickerStyle = .clockAndCalendar
        picker.datePickerElements = [.yearMonthDay, .hourMinute]
        picker.dateValue = selection
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.changed(_:))
        picker.sizeToFit()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: picker.frame.width + 24,
                                             height: picker.frame.height + 24))
        picker.frame.origin = NSPoint(x: 12, y: 12)
        container.addSubview(picker)
        let item = NSMenuItem()
        item.view = container
        menu.addItem(item)
        select.menu = menu
        select.selectItem(at: 0)
        context.coordinator.select = select
        context.coordinator.picker = picker
        return select
    }

    func updateNSView(_ select: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        select.item(at: 0)?.title = title
        if context.coordinator.picker?.dateValue != selection {
            context.coordinator.picker?.dateValue = selection
        }
    }

    private var title: String {
        selection.formatted(.dateTime.year().month().day().hour().minute())
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: NativeDateTimeSelect
        weak var select: NSPopUpButton?
        weak var picker: NSDatePicker?

        init(_ parent: NativeDateTimeSelect) { self.parent = parent }

        @objc func changed(_ picker: NSDatePicker) {
            parent.selection = picker.dateValue
            select?.item(at: 0)?.title = parent.title
        }
    }
}
