import Testing
import Foundation
import Contracts
@testable import ToolService

@Suite struct PluginConfirmationTests {
    @Test func olderConfirmationPayloadStillDecodes() throws {
        let request = ConfirmationRequest(requestID: "request", tool: "notes_append", target: "备忘录",
                                          changes: ["追加内容"], argumentsDigest: "digest", origin: .launcher)
        let value = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(request))
        let restored = try JSONDecoder().decode(ConfirmationRequest.self,
            from: value.removingKeys(["title", "details"]).canonicalData())
        #expect(restored == request)
    }
    @Test func readablePreviewPreservesExactArguments() {
        let args: JSONValue = .object(["argv": .array([
            .string("wiki"), .string("spaces"), .string("node-create"), .string("--data"),
            .string("{\"title\":\"示例\",\"space_id\":\"123\"}")
        ])])
        let preview = PluginConfirmation.preview(pluginName: "飞书", arguments: args)
        #expect(preview.title?.contains(CoreLocalization.text("创建")) == true)
        #expect(preview.changes == [CoreLocalization.text("标题") + "：示例"])
        #expect(preview.target.contains(CoreLocalization.text("知识库内容")))
        #expect(preview.details?.contains("space_id") == true)
        #expect(preview.details?.contains("node-create") == true)
    }

    @Test func unknownCommandDoesNotInventAnOperation() {
        let args: JSONValue = .object(["argv": .array([.string("unknown"), .string("run")]),
                                     "body": .string("{\"delete\":true}")])
        let preview = PluginConfirmation.preview(pluginName: "Example", arguments: args)
        #expect(preview.changes.isEmpty)
        #expect(preview.title?.contains("删除") == false)
        #expect(preview.details?.contains("delete") == true)
    }
}
