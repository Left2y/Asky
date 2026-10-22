import AppKit
import SwiftUI
import Theme

struct ChatReplyView: View {
    let text: String
    let streaming: Bool
    var values: Binding<[String: [String]]> = .constant([:])
    var active = false
    var submit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(ChatFormParser.parse(text, streaming: streaming)) { part in
                switch part.content {
                case .markdown(let text): ChatMarkdownView(text: text)
                case .form(let form):
                    ChatFormView(form: form, streaming: streaming, values: values, active: active, submit: submit)
                }
            }
        }
    }
}

struct ChatFormView: View {
    @Environment(\.colorScheme) private var colorScheme
    let form: ChatForm
    let streaming: Bool
    @Binding var values: [String: [String]]
    let active: Bool
    let submit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(form.title).font(.system(size: 14, weight: .medium))
            ForEach(form.fields) { field in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text(field.label)
                        if field.required == true { Text(verbatim: "*").foregroundStyle(ThemeColor.kTextSubtle).accessibilityLabel(NSLocalizedString("必填", comment: "")) }
                    }
                    control(field).disabled(!active)
                }
            }
            if streaming || !form.isComplete {
                Text(NSLocalizedString(streaming ? "正在生成表单…" : "表单未生成完整，请在输入框回复。", comment: ""))
                    .font(.system(size: 12)).foregroundStyle(ThemeColor.kTextSubtle)
            } else if active {
                Button(NSLocalizedString("提交回复", comment: ""), action: submit)
                    .buttonStyle(.borderedProminent)
                    .tint(ThemeColor.kBackgroundPrimary.color(for: colorScheme))
                    .foregroundStyle(ThemeColor("iconInverted"))
                    .disabled(!form.accepts(values))
            } else {
                Text(NSLocalizedString("此表单已结束，可在输入框继续对话。", comment: ""))
                    .font(.system(size: 12)).foregroundStyle(ThemeColor.kTextSubtle)
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(ThemeColor.kText)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ThemeColor.kBackgroundNeutral, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ThemeColor.kBorder, lineWidth: 1))
    }

    @ViewBuilder private func control(_ field: ChatForm.Field) -> some View {
        switch field.type {
        case .text:
            ChatFormTextField(label: field.label, text: scalar(field.id))
        case .select:
            ChatFormPicker(label: field.label, options: field.options ?? [], selection: scalar(field.id))
                .fixedSize(horizontal: false, vertical: true)
        case .multi:
            VStack(alignment: .leading, spacing: 8) {
                ForEach(field.options ?? [], id: \.self) { option in
                    Toggle(option, isOn: Binding(get: { (values[field.id] ?? []).contains(option) }, set: { selected in
                        var answer = values[field.id] ?? []
                        answer.removeAll { $0 == option }
                        if selected { answer.append(option) }
                        values[field.id] = answer
                    })).toggleStyle(.checkbox)
                }
            }
        case .date:
            if !active, values[field.id] == nil {
                Text(verbatim: "—").foregroundStyle(ThemeColor.kTextSubtle)
            } else {
                DatePicker(field.label, selection: Binding(get: {
                    ChatForm.date(values[field.id]?.first ?? "") ?? Date()
                }, set: { values[field.id] = [ChatForm.dateString($0)] }), displayedComponents: .date)
                    .labelsHidden().accessibilityLabel(field.label)
                    .onChange(of: active, initial: true) {
                        if active, values[field.id] == nil { values[field.id] = [ChatForm.dateString(Date())] }
                    }
            }
        }
    }

    private func scalar(_ id: String) -> Binding<String> {
        Binding(get: { values[id]?.first ?? "" }, set: { values[id] = [String($0.prefix(4000))] })
    }
}


/// AppKit owns popup text and bezel colors; inherited chat foreground styles must not recolor them.
private struct ChatFormPicker: NSViewRepresentable {
    let label: String
    let options: [String]
    @Binding var selection: String

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.font = .systemFont(ofSize: 14)
        button.cell?.lineBreakMode = .byTruncatingTail
        button.target = context.coordinator
        button.action = #selector(Coordinator.changed(_:))
        return button
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
        let ideal = nsView.intrinsicContentSize
        return CGSize(width: min(ideal.width, proposal.width ?? ideal.width), height: ideal.height)
    }
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let titles = [NSLocalizedString("请选择", comment: "")] + options
        if button.itemTitles != titles {
            button.removeAllItems()
            button.addItems(withTitles: titles)
        }
        button.selectItem(at: options.firstIndex(of: selection).map { $0 + 1 } ?? 0)
        button.setAccessibilityLabel(label)
        button.isEnabled = context.environment.isEnabled
        button.appearance = NSAppearance(named: context.environment.colorScheme == .dark ? .darkAqua : .aqua)
        context.coordinator.selection = $selection
        context.coordinator.options = options
    }
    @MainActor final class Coordinator: NSObject {
        var selection: Binding<String> = .constant("")
        var options: [String] = []
        @objc func changed(_ button: NSPopUpButton) {
            let index = button.indexOfSelectedItem - 1
            selection.wrappedValue = options.indices.contains(index) ? options[index] : ""
        }
    }
}


/// Use the same translucent field surface as Settings, while keeping native editing and IME.
private struct ChatFormTextField: View {
    let label: String
    @Binding var text: String
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool

    var body: some View {
        TextField(label, text: $text).labelsHidden()
            .textFieldStyle(.plain).focused($focused)
            .settingsInputSurface(scheme: scheme, focused: focused)
            .accessibilityLabel(label)
    }
}
