#if DEBUG
import AppKit
import Contracts

/// Exercises real confirmation UI with adapter-shaped fixtures, without initializing tools.
@MainActor
enum ConfirmationPreviews {
    struct Scenario {
        let id: String
        let request: ConfirmationRequest
    }

    static var scenarios: [Scenario] {
        let agent = CallerOrigin.agent(sessionID: "preview")
        func item(_ id: String, _ tool: String, _ target: String, _ changes: [String],
                  note: String? = nil, title: String? = nil, external: Bool = false) -> Scenario {
            Scenario(id: id, request: ConfirmationRequest(requestID: id, tool: tool,
                target: target, changes: changes, note: note, argumentsDigest: "preview",
                origin: external ? .mcp(instanceID: "preview") : agent, title: title,
                details: #"{"preview":true,"secret":"must-not-appear"}"#))
        }
        return [
            item("calendar-create", "calendar_create_event", "苹果日历 ·「工作」",
                 ["新建「产品评审」", "2026-10-18T14:00:00+08:00 – 2026-10-18T15:00:00+08:00", "地点：3 号会议室"], note: "与 1 个日程时间重叠"),
            item("calendar-update", "calendar_update_event", "日程「产品评审」",
                 ["标题：产品评审 → 设计评审", "开始：2026-10-18T14:00:00+08:00 → 2026-10-18T16:00:00+08:00", "结束：2026-10-18T15:00:00+08:00 → 2026-10-18T17:00:00+08:00", "地点：3 号会议室 → 5 号会议室"], note: "重复日程：仅修改本次"),
            item("calendar-delete", "calendar_delete_event", "日程「产品评审」",
                 ["删除 2026-10-18T14:00:00+08:00 的这次日程"], note: "重复日程：仅删除本次"),
            item("reminders-create", "reminders_create", "提醒列表「工作」",
                 ["新建提醒「提交报告」", "到期：2026-10-18T18:00:00+08:00"]),
            item("reminders-dash-title", "reminders_create", "提醒列表「工作」", ["新建提醒「方案 A – 方案 B 对比」"]),
            item("notes-create", "notes_create", "Notes「工作 / 项目」",
                 ["新建「项目说明」", "第一项：完成登录页面。\n第二项：核对错误提示。"]),
            item("notes-append", "notes_append", "备忘录「项目想法」（工作 / 项目）",
                 ["追加：下周先完成登录页面。"]),
            item("memory-save", "memory_save", "记忆 MEMORY.md", ["添加：我习惯下午开会。"]),
            item("memory-correct", "memory_correct", "记忆「我习惯上午开会」", ["改为：我习惯下午开会。"]),
            item("memory-forget", "memory_forget", "记忆「我习惯上午开会」", ["删除这一行"]),
            item("messages-draft", "messages_prepare_draft", "Messages：小李（13800000000）",
                 ["草稿：我周末来看你。\n周六下午方便吗？"], note: "只会打开草稿，需要你在 Messages 中手动发送"),
            item("shortcuts-input", "shortcuts_run", "快捷指令「整理收件箱」", ["输入：本周项目"], note: "快捷指令可能执行其自身定义的任意操作"),
            item("shortcuts-empty", "shortcuts_run", "快捷指令「整理收件箱」", ["无输入"], note: "快捷指令可能执行其自身定义的任意操作"),
            item("chrome-switch", "chrome_activate_tab", "Chrome 标签页", ["切换到「项目文档」", "https://example.com/project?next=a:b"]),
            item("plugin-create", "plugin_lark__execute", "将通过「飞书」创建知识库内容。", ["标题：项目说明"], title: "通过「飞书」创建知识库内容？"),
            item("plugin-arrow-title", "plugin_lark__execute", "将通过「飞书」创建文档内容。", ["标题：从 A → B"], title: "通过「飞书」创建文档内容？"),
            item("memory-arrow-content", "memory_correct", "记忆「原始说明」", ["改为：流程是 A → B。"]),
            item("plugin-generic", "plugin_example__run", "将通过「示例插件」插件执行操作。", ["路径：/Users/demo/文档/项目说明.md"], title: "允许「示例插件」执行操作？"),
            item("external-notes", "notes_append", "备忘录「项目想法」（工作 / 项目）", ["追加：下周先完成登录页面。"], external: true),
            item("unknown-tool", "future_action", "将归档当前选中的项目。", [], title: "归档项目？"),
            item("long-content", "notes_append", "备忘录「周会记录」（工作）", ["追加：" + String(repeating: "确认登录页面、错误提示和键盘操作的验收结果。", count: 10)])
        ]
    }

    static func run() {
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 760),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.center()
        window.makeKeyAndOrderFront(nil)
        let center = ConfirmationCenter()
        Task { @MainActor in
            for scenario in scenarios {
                for expected in [ConfirmationDecision.approved, .rejected] {
                    window.title = "Asky — \(scenario.id) — \(expected.rawValue)"
                    let decision = await center.present(scenario.request)
                    precondition(decision == expected, "Unexpected confirmation response: \(scenario.id)")
                    print("PASS \(scenario.id) \(decision.rawValue)")
                    fflush(stdout)
                }
            }
            window.close()
            NSApp.terminate(nil)
        }
    }
}
#endif
