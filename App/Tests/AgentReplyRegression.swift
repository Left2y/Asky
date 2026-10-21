import AppKit
import AgentHost
import LocalStore
import SwiftUI
import Contracts
import ToolService

@main
@MainActor
enum AgentReplyRegression {
    static func mathPreview() async throws {
        let formulas = [
            #"E = mc^2"#,
            #"\int_{-\infty}^{\infty} e^{-x^2}\,\mathrm{d}x = \sqrt{\pi}"#,
            #"f(x) = \sum_{n=0}^{\infty} \frac{f^{(n)}(a)}{n!}(x-a)^n"#,
            #"\begin{aligned} \nabla \cdot \mathbf{E} &= \frac{\rho}{\varepsilon_0} \\ \nabla \times \mathbf{B} &= \mu_0 \mathbf{J} + \mu_0 \varepsilon_0 \frac{\partial \mathbf{E}}{\partial t} \end{aligned}"#,
            #"A = \begin{pmatrix} a & b \\ c & d \end{pmatrix},\quad |x| = \begin{cases} x, & x \ge 0 \\ -x, & x < 0 \end{cases}"#
        ]
        for formula in formulas {
            for color in [NSColor.white, .black] {
                guard let rendered = ChatMathRenderer.render(.init(source: formula, display: true), color: color),
                      let bitmap = rendered.image.representations.first as? NSBitmapImageRep else {
                    preconditionFailure(formula)
                }
                // Glyphs must fit inside the transparent top/bottom padding, including descenders.
                for x in 0..<bitmap.pixelsWide {
                    precondition(bitmap.colorAt(x: x, y: 0)!.alphaComponent < 0.01, formula)
                    precondition(bitmap.colorAt(x: x, y: bitmap.pixelsHigh - 1)!.alphaComponent < 0.01, formula)
                }
            }
        }
        precondition(ChatMathRenderer.render(.init(source: #"\unknowncommand{x}"#, display: true), color: .black) == nil)
        for literal in [#"`$x$`"#, "```tex\n$$x$$\n```", #"\$20 and \$30"#, "$20 and $30", #"[price](https://example.com/$x$)"#, "$unfinished", "$$unfinished", "    $$code$$"] {
            precondition(ChatMath.markdown(literal) == literal, literal)
        }
        for input in [#"$x^2$"#, #"$2x$"#, #"$20$"#, #"$$x^2$$"#, #"\(x^2\)"#, #"\[x^2\]"#] {
            precondition(ChatMath.markdown(input).contains("asky-math://"), input)
        }
        let explanatory = "独立公式（使用 $$ 包裹）：\n\n$$x^2$$"
        precondition(ChatMath.markdown(explanatory).hasPrefix("独立公式（使用 $$ 包裹）："))
        precondition(ChatMath.markdown(explanatory).contains("asky-math://display/"))
        let markdown = """
        ## 公式示例
        行内公式：质能方程 $E = mc^2$，圆的面积 $S = \\pi r^2$。

        """ + formulas.dropFirst().map { "$$" + $0 + "$$" }.joined(separator: "\n\n") + """

        **粗体**、`$code$`、价格 $20 and $30 保持原样。
        """
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 760, height: 640),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.title = "Asky Math Regression"
        for (name, scheme, appearance, width) in [("light", ColorScheme.light, NSAppearance.Name.aqua, 760.0),
                                                   ("dark", .dark, .darkAqua, 760.0),
                                                   ("dark-narrow", .dark, .darkAqua, 420.0)] {
            window.setContentSize(NSSize(width: width, height: 640))
            window.appearance = NSAppearance(named: appearance)
            let view = NSHostingView(rootView: ChatMarkdownView(text: markdown).padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(scheme == .dark ? Color(white: 0.15) : .white).environment(\.colorScheme, scheme))
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            try await Task.sleep(for: .milliseconds(800))
            view.layoutSubtreeIfNeeded()
            func checkTextWidth(_ node: NSView) {
                if let text = node as? NSTextView, let container = text.textContainer, let manager = text.layoutManager,
                   String(describing: type(of: manager)) == "ChatInlineLayoutManager" {
                    manager.ensureLayout(for: container)
                    precondition(text.bounds.width <= width - 48 + 1, "Paragraph must fit inside the window")
                    precondition(manager.usedRect(for: container).width <= text.bounds.width + 1,
                                 "Inline text must wrap: used=\(manager.usedRect(for: container)) bounds=\(text.bounds) container=\(container.containerSize)")
                }
                node.subviews.forEach(checkTextWidth)
            }
            checkTextWidth(view)
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("capture") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(filePath: "build/math-" + name + ".png"))
        }
        window.orderOut(nil)
        print("Math parsing, native layout, invalid-source fallback and light/dark window captures passed")
    }

    static func main() async throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--math-preview") {
            try await mathPreview()
            return
        }
        let root = FileManager.default.temporaryDirectory.appending(path: "Asky-reply-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let model = AgentModel(app: app)
        if CommandLine.arguments.contains("--window-glass") {
            func capture(_ window: NSWindow, name: String) throws {
                let frame = window.frame
                let top = NSScreen.screens[0].frame.maxY - frame.maxY
                let capture = Process()
                capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-R", "\(Int(frame.minX)),\(Int(top)),\(Int(frame.width)),\(Int(frame.height))",
                    "build/\(name).png"]
                try capture.run()
                capture.waitUntilExit()
                precondition(capture.terminationStatus == 0)
            }
            let controller = AgentWindowController(model: model, presentation: WindowPresentation())
            controller.show()
            let window = application.windows.first { $0.title == "Asky AI" }!
            defer { window.close() }
            guard let glass = window.contentView as? GlassSurfaceView else {
                preconditionFailure("chat must use the search shell's AppKit glass")
            }
            precondition(glass.style == .regular && glass.tintColor == nil && window.hasShadow)
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                window.appearance = NSAppearance(named: appearance)
                for (name, size) in [("initial", window.frame.size), ("resized", NSSize(width: 820, height: 720))] {
                    window.setContentSize(size)
                    window.contentView!.layoutSubtreeIfNeeded()
                    try await Task.sleep(for: .milliseconds(350))
                    precondition(glass.frame.size == size, "glass must fill the resized window")
                    precondition(glass.contentView?.frame.size == size, "content wrapper must resize with glass")
                    try capture(window, name: "agent-window-glass-\(appearance.rawValue)-\(name)")
                }
            }
            window.orderOut(nil)
            app.preferences.clipboardLayout = .list
            try ClipboardStore(app.store).insert(ClipboardItem(kind: .text,
                text: "原生玻璃列表背景验证", byteSize: 33, contentHash: "window-glass-fixture"))
            let clipboard = ClipboardController(app: app)
            clipboard.pinned = true
            clipboard.show()
            let list = application.windows.first { $0.title == NSLocalizedString("剪贴板历史", comment: "") }!
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                list.appearance = NSAppearance(named: appearance)
                try await Task.sleep(for: .milliseconds(400))
                guard let surface = list.contentView as? GlassSurfaceView else {
                    preconditionFailure("clipboard must share the native window glass")
                }
                precondition(surface.style == .regular && surface.tintColor == nil)
                try capture(list, name: "clipboard-window-glass-\(appearance.rawValue)")
            }
            clipboard.hide()
            print("Chat native Regular glass, untinted surface, light/dark capture and resizing passed")
            return
        }
        if CommandLine.arguments.contains("--compaction-preview") {
            let store = ConversationStore(app.store)
            let cid = try store.create(title: "上下文压缩")
            try store.append(conversationID: cid, role: "user", text: "继续刚才的对话")
            model.open(cid)
            model.beginResponse(taskID: "compaction")
            model.handle(.taskState(taskID: "compaction", .compacting), conversationID: cid)
            precondition(model.state == .compacting && model.isRunning)
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                application.appearance = NSAppearance(named: appearance)
                let controller = AgentWindowController(model: model, presentation: WindowPresentation())
                controller.show()
                let window = application.windows.first { $0.title == "Asky AI" }!
                defer { window.close() }
                window.appearance = NSAppearance(named: appearance)
                try await Task.sleep(for: .milliseconds(600))
                let capture = Process()
                capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-o", "-l", String(window.windowNumber),
                    "build/agent-compaction-\(appearance.rawValue).png"]
                try capture.run()
                capture.waitUntilExit()
                precondition(capture.terminationStatus == 0)
            }
            model.handle(.taskState(taskID: "compaction", .running), conversationID: cid)
            precondition(model.state == .running && model.isRunning)
            model.handle(.taskState(taskID: "compaction", .compacting), conversationID: cid)
            model.handle(.taskState(taskID: "compaction", .cancelled), conversationID: cid)
            model.finishTask(conversationID: cid)
            precondition(!model.isRunning && model.state == .cancelled)
            print("Compaction UI: light/dark captures, resume and cancellation passed")
            return
        }
        let store = ConversationStore(app.store)
        let cid = try store.create(title: "回复回归")
        model.open(cid)
        model.beginResponse(taskID: "clarification", now: Date().addingTimeInterval(-13))
        model.handle(.textDelta(taskID: "clarification", "之前的流式说明"), conversationID: cid)
        model.handle(.clarification(taskID: "clarification", question: "「年后啊」这句我没接上上下文，能补充一下你的意思吗？"), conversationID: cid)
        model.handle(.taskState(taskID: "clarification", .awaitingInput), conversationID: cid)
        let completedAt = Date()
        model.finishTask(conversationID: cid, now: completedAt)
        precondition(model.items[0].completedAt == completedAt)
        precondition(model.items[0].responseID == "clarification")
        precondition(model.items.count == 1, "clarification must have only one reply/copy button")
        precondition(model.streaming.isEmpty)
        precondition(model.items[0].workSeconds == 13, "finished reply retains elapsed time")
        precondition(store.messages(conversationID: cid, limit: 40).count == 1)
        model.open(cid)
        precondition(model.items.count == 1, "clarification must survive reopening")
        model.beginResponse(taskID: "normal")
        model.handle(.textDelta(taskID: "normal", "增量"), conversationID: cid)
        model.handle(.message(taskID: "normal", "完整回答"), conversationID: cid)
        model.finishTask(conversationID: cid)
        precondition(model.items.count == 2 && model.items.last?.text == "完整回答")
        precondition(model.items.last?.workSeconds != nil)
        model.beginResponse(taskID: "stopped")
        model.handle(.textDelta(taskID: "stopped", "停止时保留的部分回答"), conversationID: cid)
        model.handle(.taskState(taskID: "stopped", .cancelled), conversationID: cid)
        model.finishTask(conversationID: cid)
        precondition(model.items.count == 3 && model.items.last?.workSeconds != nil)
        precondition(model.taskStartedAt == nil && !model.isRunning)
        let clock = Date(timeIntervalSince1970: 1_800_000_000)
        for (age, key, value) in [(0, "刚刚", 0), (59, "刚刚", 0), (60, "%d 分钟前", 1),
                                  (3599, "%d 分钟前", 59), (3600, "%d 小时前", 1),
                                  (86399, "%d 小时前", 23), (86400, "%d 天前", 1),
                                  (259199, "%d 天前", 2)] {
            let expected = value == 0 ? NSLocalizedString(key, comment: "") : String(format: NSLocalizedString(key, comment: ""), value)
            precondition(ChatCompletionTime.label(clock.addingTimeInterval(-Double(age)), now: clock) == expected)
        }
        precondition(ChatCompletionTime.label(clock.addingTimeInterval(-259200), now: clock) == ChatCompletionTime.exact(clock.addingTimeInterval(-259200)))
        precondition(ChatCompletionTime.label(clock.addingTimeInterval(1), now: clock) == NSLocalizedString("刚刚", comment: ""))
        print("Completion time regression passed: minute, hour, day, three-day boundaries and clock skew")
        print("AgentReply regression passed: clarification, persisted question, final reply, cancellation, elapsed time")
        let attachmentID = try store.create(title: "附件消息回归")
        let file = root.appending(path: "PRD-Spotlight.md")
        try Data("附件回归".utf8).write(to: file)
        let document = try ComposerAttachmentService.importFile(file, into: app.store.attachmentsDirectory)
        var refs = [document.reference]
        if let index = CommandLine.arguments.firstIndex(of: "--attachment-preview"),
           CommandLine.arguments.indices.contains(index + 1) {
            let image = try ComposerAttachmentService.importFile(URL(filePath: CommandLine.arguments[index + 1]), into: app.store.attachmentsDirectory)
            refs.insert(image.reference, at: 0)
        }
        try store.append(conversationID: attachmentID, role: "user", text: "请分析这些附件", attachments: refs)
        model.open(attachmentID)
        precondition(model.items.first?.attachments == refs, "history must restore message attachments")
        model.open(nil)
        model.open(attachmentID)
        precondition(model.items.first?.attachments == refs, "reopening retains the selected attachment order")
        print("Message attachment regression passed: history restoration and attachment order")
        model.draft = "旧草稿"
        model.attachments = refs
        model.attachmentThumbnails = ["old": Data([1])]
        let revision = model.newConversationRevision
        await model.startNewConversation()
        precondition(model.conversationID == nil && model.items.isEmpty && model.streaming.isEmpty)
        precondition(model.draft.isEmpty && model.attachments.isEmpty && model.attachmentThumbnails.isEmpty)
        precondition(model.state == nil && model.newConversationRevision == revision + 1)
        precondition(!store.messages(conversationID: attachmentID, limit: 40).isEmpty, "new conversation preserves old history")
        print("New conversation regression passed: blank draft, cleared attachments, preserved history")
        if CommandLine.arguments.contains("--tool-preview") {
            let toolID = try store.create(title: "工具调用样式")
            model.open(toolID)
            model.beginResponse(taskID: "tools", now: Date().addingTimeInterval(-13))
            for (id, tool, status, error) in [
                ("calendar", "calendar_search_events", ExecutionStatus.completed, Optional<String>.none),
                ("lark", "plugin_lark__help", .failed, "Error: unknown command \"message\" for \"lark-cli\"\n    at run (plugins/lark/index.mjs:21:5)"),
                ("search", "web_search", .completed, nil),
                ("notes", "notes_search", .completed, nil),
                ("reminders", "reminders_list", .completed, nil),
                ("contacts", "contacts_search", .completed, nil),
                ("messages", "messages_search", .completed, nil),
                ("chrome", "chrome_list_tabs", .completed, nil),
                ("shortcuts", "shortcuts_list", .completed, nil),
                ("memory", "memory_read", .completed, nil),
                ("plugin", "plugin_orca__help", .completed, nil),
                ("lark-success", "plugin_lark__help", .completed, nil),
                ("running", "notes_search", nil, nil)
            ] as [(String, String, ExecutionStatus?, String?)] {
                model.handle(.toolCall(taskID: "tools", ActionRequest(requestID: id, tool: tool, arguments: .object([:]), origin: .agent(sessionID: toolID), intent: .explicitRequest)), conversationID: toolID)
                if let status {
                    model.handle(.toolResult(taskID: "tools", ExecutionResult(requestID: id, status: status, error: error.map { ToolError(.invalidArguments, $0) })), conversationID: toolID)
                }
            }
            precondition(NSImage(named: "MingCute-tool") != nil, "plugins must use the bundled tool icon")
            precondition(model.items.filter { $0.pluginID != nil }.allSatisfy { $0.toolSymbol == "tool" },
                         "Orca and Feishu share the same tool icon")
            precondition(model.items.count == 13, "preview must include each tool family and execution state")
            precondition(model.items.first { $0.id == "search" }?.toolSymbol == "magnifyingglass",
                         "web search uses the MingCute search icon")
            precondition(model.items.first { $0.id == "memory" }?.toolSymbol == "brain",
                         "memory calls use the MingCute brain icon")
            precondition(!model.items[0].text.contains("已完成"))
            precondition(!model.items[1].text.contains("Error:"))
            precondition(model.items[1].toolError?.contains("unknown command") == true)
            precondition(model.items[1].pluginID == "lark")
            model.handle(.message(taskID: "tools", "已检查日历与相关工具，飞书调用失败，可展开工作时间查看详情。"), conversationID: toolID)
            if !CommandLine.arguments.contains("--running-preview") { model.finishTask(conversationID: toolID) }
            let controller = AgentWindowController(model: model, presentation: WindowPresentation())
            controller.show()
            runPreview(controller, application: application)
        }
        if CommandLine.arguments.contains("--attachment-preview") {
            model.open(attachmentID)
            let controller = AgentWindowController(model: model, presentation: WindowPresentation())
            controller.show()
            runPreview(controller, application: application)
        }
        if CommandLine.arguments.contains("--scroll-preview") {
            let scrollID = try store.create(title: "回到底部按钮验证")
            for index in 1...24 {
                try store.append(conversationID: scrollID, role: index.isMultiple(of: 2) ? "assistant" : "user",
                                 text: "第 \(index) 条消息：用于检查向上滚动后的回到底部按钮。")
            }
            model.open(scrollID)
            let controller = AgentWindowController(model: model, presentation: WindowPresentation())
            controller.show()
            runPreview(controller, application: application)
        }
        if CommandLine.arguments.contains("--preview") {
            let previewID = try store.create(title: "澄清回复回归")
            model.open(previewID)
            model.beginResponse(taskID: "preview", now: Date().addingTimeInterval(-13))
            model.handle(.textDelta(taskID: "preview", "不应成为第二条回复的文字"), conversationID: previewID)
            model.handle(.clarification(taskID: "preview", question: "「年后啊」这句我没接上上下文，能补充一下你的意思吗？"), conversationID: previewID)
            model.finishTask(conversationID: previewID)
            // Keep the controller alive while inspecting the actual SwiftUI window.
            let controller = AgentWindowController(model: model, presentation: WindowPresentation())
            controller.show()
            runPreview(controller, application: application)
        }
    }
    private static func runPreview(_ controller: AgentWindowController, application: NSApplication) {
        withExtendedLifetime(controller) { application.run() }
    }
}
