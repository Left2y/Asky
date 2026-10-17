import AppKit
import Contracts
import ToolService

/// Native confirmation for every write that needs it, regardless of caller (Launcher, Pi, external MCP).
/// Requests are shown one at a time using the system alert layout.
@MainActor @Observable
final class ConfirmationCenter {
    struct Pending: Identifiable {
        let request: ConfirmationRequest
        let continuation: CheckedContinuation<ConfirmationDecision, Never>
        var id: String { request.id }
    }

    private(set) var queue: [Pending] = []
    private var alert: NSAlert?

    nonisolated init() {}

    func present(_ request: ConfirmationRequest) async -> ConfirmationDecision {
        await withCheckedContinuation { continuation in
            queue.append(Pending(request: request, continuation: continuation))
            showNextAlert()
        }
    }

    func rejectAll() {
        let pending = queue
        queue.removeAll()
        pending.forEach { $0.continuation.resume(returning: .rejected) }
        if let alert { AppDialog.dismiss(alert) }
    }

    /// Present the resolved target and changes as one paragraph, rather than exposing
    /// the adapter's field list or raw tool arguments in the alert.
    private static func message(for request: ConfirmationRequest, remaining: Int) -> String {
        func text(_ value: String) -> String {
            value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        }
        func clause(_ value: String) -> String {
            var result = text(value)
            while let last = result.last, "。！？.!?；;".contains(last) { result.removeLast() }
            return result
        }
        var showsDates = false
        func date(_ value: String) -> String {
            let iso = ISO8601DateFormatter()
            var parsed = iso.date(from: value)
            if parsed == nil {
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                parsed = iso.date(from: value)
            }
            guard let parsed else { return value }
            showsDates = true
            let display = DateFormatter()
            display.locale = Locale(identifier: "zh_CN")
            display.timeZone = .current
            display.dateFormat = "yyyy年M月d日 HH:mm"
            return display.string(from: parsed)
        }
        func change(_ value: String) -> String {
            let value = text(value)
            guard let separator = value.firstIndex(of: "：") else {
                if value == "无输入" { return "不传入任何内容" }
                if value.hasPrefix("删除 "), value.hasSuffix(" 的这次日程") {
                    return "时间为" + date(String(value.dropFirst(3).dropLast(6)))
                }
                let range = value.components(separatedBy: " – ")
                if request.tool == "calendar_create_event", range.count == 2 { return "时间为\(date(range[0]))至\(date(range[1]))" }
                return clause(value)
            }
            let field = String(value[..<separator])
            let content = String(value[value.index(after: separator)...])
            let names = ["开始": "开始时间", "结束": "结束时间", "到期": "到期时间"]
            let name = names[field] ?? field
            let fields = ["标题", "内容", "正文", "链接", "路径", "名称", "开始", "结束", "到期", "地点", "追加", "添加", "改为", "草稿", "输入"]
            guard fields.contains(field) else { return clause(value) }
            if request.tool == "calendar_update_event", let arrow = content.range(of: " → ") {
                var before = String(content[..<arrow.lowerBound])
                var after = String(content[arrow.upperBound...])
                if field == "开始" || field == "结束" {
                    before = date(before)
                    after = date(after)
                }
                return "\(name)将从「\(before)」改为「\(after)」"
            }
            if field == "到期" { return "到期时间为\(date(content))" }
            switch field {
            case "追加": return "追加内容「\(content)」"
            case "添加": return "添加内容「\(content)」"
            case "改为": return "改为「\(content)」"
            case "草稿": return "草稿内容为「\(content)」"
            case "输入": return "输入内容为「\(content)」"
            default: return "\(name)为「\(content)」"
            }
        }
        var target = clause(request.target)
        if request.tool == "messages_prepare_draft", target.hasPrefix("Messages：") {
            target = String(target.dropFirst("Messages：".count))
        } else if request.tool == "notes_create", target.hasPrefix("Notes「") {
            target = "备忘录文件夹「" + target.dropFirst("Notes「".count)
        } else if request.tool == "calendar_create_event", target.hasPrefix("苹果日历 ·") {
            target = "苹果日历的" + target.dropFirst("苹果日历 ·".count)
        } else if request.tool == "memory_save", target.hasPrefix("记忆 ") {
            target = "记忆文件「" + target.dropFirst("记忆 ".count) + "」"
        }
        let operation: String
        switch request.tool {
        case "calendar_create_event", "reminders_create", "notes_create", "notes_append", "memory_save":
            operation = "将在\(target)中"
        case "calendar_update_event": operation = "将修改\(target)，"
        case "calendar_delete_event": operation = "将删除\(target)，"
        case "memory_correct": operation = "将把\(target)的内容"
        case "memory_forget": operation = "将删除\(target)"
        case "messages_prepare_draft": operation = "将为\(target)准备信息草稿，"
        case "shortcuts_run": operation = "将运行\(target)，"
        case "chrome_activate_tab": operation = "将在 Chrome 中"
        default: operation = target + (request.changes.isEmpty ? "" : "，")
        }
        let changes = request.tool == "memory_forget" ? "" : request.changes.enumerated().map { index, value in
            if request.tool == "notes_create" {
                if index > 0 { return "内容为「\(text(value))」" }
                if value.hasPrefix("新建「") { return "新建备忘录「" + value.dropFirst("新建「".count) }
            }
            if request.tool == "calendar_create_event", index == 0, value.hasPrefix("新建「") {
                return "新建日程「" + value.dropFirst("新建「".count)
            }
            if request.tool == "chrome_activate_tab", index > 0 { return "页面地址为「\(text(value))」" }
            return change(value)
        }.joined(separator: "，")
        var body = clause(operation + changes) + "。"
        if case .mcp = request.origin { body = "外部应用请求执行这项操作。" + body }
        if let note = request.note, !note.isEmpty {
            let notes = ["重复日程：仅修改本次": "此次只修改重复日程中的这一次",
                         "重复日程：仅删除本次": "此次只删除重复日程中的这一次"]
            body += (notes[note] ?? clause(note)) + "。"
        }
        if showsDates {
            let zone = TimeZone.current
            let name = zone.localizedName(for: .generic, locale: Locale(identifier: "zh_CN")) ?? zone.identifier
            body += "以上时间均按\(name)显示。"
        }
        if remaining > 0 { body += "另外还有\(remaining)项操作需要你确认。" }
        if body.hasSuffix("。") { body.removeLast() }
        return body
    }

    private func showNextAlert() {
        guard alert == nil, let pending = queue.first else { return }
        let request = pending.request
        let alert = AppDialog.make()
        let titles = [
            "calendar_create_event": "创建日程？", "calendar_update_event": "修改日程？",
            "calendar_delete_event": "删除日程？", "reminders_create": "创建提醒事项？",
            "notes_create": "创建备忘录？", "notes_append": "追加备忘录内容？",
            "messages_prepare_draft": "准备信息草稿？", "shortcuts_run": "运行快捷指令？",
            "chrome_activate_tab": "切换浏览器标签页？", "memory_save": "保存这条记忆？",
            "memory_correct": "修改这条记忆？", "memory_forget": "删除这条记忆？"
        ]
        alert.messageText = request.title ?? NSLocalizedString(titles[request.tool] ?? "执行这项操作？", comment: "")
        alert.informativeText = Self.message(for: request, remaining: queue.count - 1)
        alert.addButton(withTitle: NSLocalizedString("确认执行", comment: "")).keyEquivalent = "\r"
        alert.addButton(withTitle: NSLocalizedString("不执行", comment: "")).keyEquivalent = "\u{1b}"
        self.alert = alert

        // Schedule presentation after the continuation has been registered. AppKit owns
        // focus, layout, appearance, and keyboard handling, just like a system permission alert.
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.queue.contains(where: { $0.id == pending.id }) else {
                self.alert = nil
                self.showNextAlert()
                return
            }
            NSApp.activate()
            let response = await AppDialog.present(alert)
            alert.window.orderOut(nil)
            self.alert = nil
            if let index = self.queue.firstIndex(where: { $0.id == pending.id }) {
                self.queue.remove(at: index).continuation.resume(
                    returning: response == .alertFirstButtonReturn ? .approved : .rejected)
            }
            self.showNextAlert()
        }
    }
}
