import Testing
import Foundation
import Contracts
import LocalStore
import ToolService
import Memory
@testable import Adapters

@Suite struct MemoryToolsTests {
    private func service(_ s: LocalStore, _ m: MemoryFolder, approve: Bool) async -> ToolService {
        let svc = ToolService(store: s, policy: { PolicySnapshot(enabledSources: [.memory]) },
                              presenter: { _ in approve ? .approved : .rejected })
        for a in [MemoryReadTool(m), MemorySaveTool(m), MemoryCorrectTool(m), MemoryForgetTool(m)] as [any ToolAdapter] {
            await svc.register(a)
        }
        return svc
    }

    private func call(_ svc: ToolService, _ tool: String, _ args: JSONValue, intent: UserIntent = .explicitRequest) async -> ExecutionResult {
        await svc.submit(ActionRequest(tool: tool, arguments: args, origin: .agent(sessionID: "c"), intent: intent))
    }

    private func folder() -> MemoryFolder {
        MemoryFolder(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    @Test func explicitSaveRunsDirectlyAndInferredSaveIsOnlySuggested() async throws {
        let s = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let m = folder()
        let svc = await service(s, m, approve: false)
        let inferred = await call(svc, "memory_save", ["content": "用户可能喜欢咖啡", "section": "偏好"], intent: .aiSuggested)
        #expect(inferred.status == .suggestion && m.context() == nil)

        let r = await call(svc, "memory_save", ["content": "用户的常用机场是浦东", "section": "关于我"])
        #expect(r.status == .completed && m.read().contains("## 关于我\n- 用户的常用机场是浦东"))

        let topic = await call(svc, "memory_save", ["content": "用户常去成都出差", "file": "travel", "description": "出行习惯"])
        #expect(topic.status == .completed && m.read("travel.md").contains("- 用户常去成都出差"))
        #expect(m.read().contains("[travel.md](travel.md) — 出行习惯"))

        let read = await call(svc, "memory_read", ["file": "travel.md"])
        #expect(read.status == .completed && read.output?["text"]?.stringValue?.contains("成都") == true)
        let missing = await call(svc, "memory_read", ["file": "nope.md"])
        #expect(missing.error?.code == .targetNotFound)
        let bad = await call(svc, "memory_save", ["content": "x", "file": "../x"])
        #expect(bad.error?.code == .invalidArguments)
    }

    @Test func explicitCorrectAndForgetRunWithoutConfirmation() async throws {
        let s = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let m = folder()
        try m.add("用户的常用机场是虹桥", section: "关于我")
        let svc = await service(s, m, approve: false)   // presenter would reject any prompt

        let inferred = await call(svc, "memory_forget", ["old": "常用机场是虹桥"], intent: .aiSuggested)
        #expect(inferred.status == .suggestion && m.read().contains("虹桥"))

        let fixed = await call(svc, "memory_correct", ["old": "用户的常用机场是虹桥", "content": "用户的常用机场是浦东"])
        #expect(fixed.status == .completed && m.read().contains("- 用户的常用机场是浦东") && !m.read().contains("虹桥"))

        let missing = await call(svc, "memory_forget", ["old": "虹桥"])
        #expect(missing.error?.code == .targetNotFound)
        let gone = await call(svc, "memory_forget", ["file": "MEMORY.md", "old": "常用机场是浦东"])
        #expect(gone.status == .completed && m.context() == nil)
    }
}
