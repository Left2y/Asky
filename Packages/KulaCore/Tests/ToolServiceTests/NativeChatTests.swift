import Foundation
import Testing
import Contracts
@testable import ToolService

struct NativeChatTests {
    @Test func historyOnlyExposesVisibleText() throws {
        let body: JSONValue = [
            ["id": "durable-user", "message": ["id": "rewritten", "role": "user", "parts": [["type": "text", "text": "工资"]]]],
            ["id": "reply", "message": ["role": "assistant", "parts": [
                ["type": "reasoning", "text": "private reasoning"],
                ["type": "tool-call", "text": "secret tool input"],
                ["type": "text", "text": "9080.46"]
            ]]],
            ["message": ["role": "system", "parts": [["type": "text", "text": "internal"]]]]
        ]
        let rows = try NativeChatCodec.messages(body)
        #expect(rows.map(\.text) == ["工资", "9080.46"])
        #expect(rows.first?.id == "durable-user")
        #expect(throws: Error.self) { try NativeChatCodec.messages(["unexpected": true]) }
    }
    @Test func deltasExcludeReasoningAndTools() {
        let data: JSONValue = ["deltas": [
            ["type": "text_append", "partType": "reasoning", "text": "secret"],
            ["type": "text_append", "partType": "text", "text": "工资"],
            ["type": "other", "partType": "text", "text": "hidden"],
            ["type": "text_append", "partType": "text", "text": "9080.46"]
        ]]
        #expect(NativeChatCodec.delta(data) == "工资9080.46")
    }
    @Test func optionalCapabilityKeepsV1Fallback() throws {
        let legacy = Data(#"{"name":"alma","title":"Alma","tool":"chat","mode":"action","queryArgument":"input"}"#.utf8)
        var command = try JSONDecoder().decode(PluginCommand.self, from: legacy)
        #expect(command.chat == nil)
        command.chat = PluginChatDescriptor(backend: "alma")
        let roundtrip = try JSONDecoder().decode(PluginCommand.self, from: JSONEncoder().encode(command))
        #expect(roundtrip.chat?.backend == "alma")
        #expect(roundtrip.mode == .action && roundtrip.tool == "chat")
        #expect(!NativeChatCodec.validID("../../secret"))
        #expect(NativeChatCodec.validID("test-thread_1"))
    }
}
