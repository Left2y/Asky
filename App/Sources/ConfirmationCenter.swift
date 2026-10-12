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
        if let alert, NSApp.modalWindow === alert.window { NSApp.abortModal() }
        alert?.window.orderOut(nil)
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
        var details = [
            request.target,
            request.changes.map { "• \($0)" }.joined(separator: "\n")
        ]
        if case .mcp = request.origin {
            details.insert(NSLocalizedString("外部 MCP 客户端请求执行此操作。", comment: ""), at: 0)
        }
        if let note = request.note { details.append(note) }
        if queue.count > 1 {
            details.append(String(format: NSLocalizedString("还有 %@ 项待确认", comment: ""), String(queue.count - 1)))
        }
        alert.informativeText = details.filter { !$0.isEmpty }.joined(separator: "\n\n")
        AppDialog.addDetails(to: alert, text: [request.tool, request.details].compactMap { $0 }.joined(separator: "\n\n"))
        alert.addButton(withTitle: NSLocalizedString("确认执行", comment: "")).keyEquivalent = "\r"
        alert.addButton(withTitle: NSLocalizedString("不执行", comment: "")).keyEquivalent = "\u{1b}"
        self.alert = alert

        // Schedule the modal loop after the continuation has been registered. AppKit owns
        // focus, layout, appearance, and keyboard handling, just like a system permission alert.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.queue.contains(where: { $0.id == pending.id }) else {
                self.alert = nil
                self.showNextAlert()
                return
            }
            NSApp.activate()
            let response = alert.runModal()
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
