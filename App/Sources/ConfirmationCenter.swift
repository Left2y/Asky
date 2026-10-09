import AppKit
import SwiftUI
import Contracts
import Theme

/// Native confirmation for every write that needs it, regardless of caller (Launcher, Pi, external MCP).
/// Requests are shown one at a time in a floating panel; closing the panel counts as rejection.
@MainActor @Observable
final class ConfirmationCenter {
    struct Pending: Identifiable {
        let request: ConfirmationRequest
        let continuation: CheckedContinuation<ConfirmationDecision, Never>
        var id: String { request.id }
    }

    private(set) var queue: [Pending] = []
    private var panel: NSPanel?

    nonisolated init() {}

    func present(_ request: ConfirmationRequest) async -> ConfirmationDecision {
        await withCheckedContinuation { c in
            queue.append(Pending(request: request, continuation: c))
            showPanel()
        }
    }

    func resolve(_ id: String, _ decision: ConfirmationDecision) {
        guard let i = queue.firstIndex(where: { $0.id == id }) else { return }
        queue.remove(at: i).continuation.resume(returning: decision)
        if queue.isEmpty { panel?.orderOut(nil) }
    }

    func rejectAll() {
        let pending = queue
        queue.removeAll()
        pending.forEach { $0.continuation.resume(returning: .rejected) }
        panel?.orderOut(nil)
    }

    private func showPanel() {
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
                            styleMask: [.titled, .closable, .fullSizeContentView, .utilityWindow],
                            backing: .buffered, defer: true)
            p.title = "确认操作"
            p.titlebarAppearsTransparent = true
            p.level = .modalPanel
            p.isReleasedWhenClosed = false
            p.hidesOnDeactivate = false
            p.contentView = NSHostingView(rootView: ConfirmationQueueView(center: self))
            p.delegate = PanelCloseDelegate.shared
            PanelCloseDelegate.shared.onClose = { [weak self] in self?.rejectAll() }
            panel = p
        }
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

@MainActor
private final class PanelCloseDelegate: NSObject, NSWindowDelegate {
    static let shared = PanelCloseDelegate()
    var onClose: (() -> Void)?
    func windowWillClose(_ notification: Notification) { onClose?() }
}

struct ConfirmationQueueView: View {
    let center: ConfirmationCenter

    var body: some View {
        if let p = center.queue.first {
            ConfirmationCard(request: p.request, remaining: center.queue.count - 1) { decision in
                center.resolve(p.id, decision)
            }
            .padding(20)
            .frame(width: 420)
        } else {
            Color.clear.frame(width: 420, height: 1)
        }
    }
}

struct ConfirmationCard: View {
    let request: ConfirmationRequest
    let remaining: Int
    let decide: (ConfirmationDecision) -> Void

    private var originLabel: String {
        switch request.origin {
        case .launcher: "启动器"
        case .agent: "AI 助手"
        case .mcp: "外部 MCP 客户端"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(originLabel) 请求：\(request.tool)").textStyle(.button)
            Text(request.target).textStyle(.resultPrimary)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(request.changes, id: \.self) { Text("• \($0)").textStyle(.secondary) }
            }
            if let note = request.note { Text(note).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle) }
            if remaining > 0 { Text("还有 \(remaining) 项待确认").textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtlest) }
            HStack {
                Spacer()
                Button("不执行", role: .cancel) { decide(.rejected) }.keyboardShortcut(.cancelAction)
                Button("确认执行") { decide(.approved) }.keyboardShortcut(.defaultAction).buttonStyle(.glassProminent)
            }
        }
    }
}
