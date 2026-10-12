import AppKit
import Contracts

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
        let alert = NSAlert()
        alert.alertStyle = .informational
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            alert.icon = icon
        }
        alert.messageText = NSLocalizedString("确认操作", comment: "")
        let originLabel: String
        switch request.origin {
        case .launcher: originLabel = NSLocalizedString("启动器", comment: "")
        case .agent: originLabel = NSLocalizedString("AI 助手", comment: "")
        case .mcp: originLabel = NSLocalizedString("外部 MCP 客户端", comment: "")
        }
        var details = [
            String(format: NSLocalizedString("%@ 请求：%@", comment: ""), originLabel, request.tool),
            request.target,
            request.changes.map { "• \($0)" }.joined(separator: "\n")
        ]
        if let note = request.note { details.append(note) }
        if queue.count > 1 {
            details.append(String(format: NSLocalizedString("还有 %@ 项待确认", comment: ""), String(queue.count - 1)))
        }
        alert.informativeText = details.filter { !$0.isEmpty }.joined(separator: "\n\n")
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
