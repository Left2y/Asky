import AppKit
import AgentHost
import LocalStore
import SwiftUI
import Contracts
import ToolService

@main
@MainActor
enum AgentReplyRegression {
    static func main() async throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let root = FileManager.default.temporaryDirectory.appending(path: "Asky-reply-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let model = AgentModel(app: app)
        let store = ConversationStore(app.store)
        let cid = try store.create(title: "回复回归")
        model.open(cid)
        model.beginResponse(taskID: "clarification", now: Date().addingTimeInterval(-13))
        model.handle(.textDelta(taskID: "clarification", "之前的流式说明"), conversationID: cid)
        model.handle(.clarification(taskID: "clarification", question: "「年后啊」这句我没接上上下文，能补充一下你的意思吗？"), conversationID: cid)
        model.handle(.taskState(taskID: "clarification", .awaitingInput), conversationID: cid)
        model.finishTask(conversationID: cid)
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
        if CommandLine.arguments.contains("--attachment-preview") {
            model.open(attachmentID)
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
