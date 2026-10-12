import Testing
import Foundation
import Contracts
import LocalStore
import ToolService
import Memory
@testable import Adapters

@Suite struct MemoryToolsTests {
    private func service(_ s: LocalStore, approve: Bool) async -> ToolService {
        let svc = ToolService(store: s, policy: { PolicySnapshot(enabledSources: [.memory]) },
                              presenter: { _ in approve ? .approved : .rejected })
        let m = MemoryStore(s)
        for a in [MemorySearchTool(m), MemorySaveTool(m), MemoryCorrectTool(m), MemoryForgetTool(m)] as [any ToolAdapter] {
            await svc.register(a)
        }
        return svc
    }

    private func call(_ svc: ToolService, _ tool: String, _ args: JSONValue, intent: UserIntent = .explicitRequest) async -> ExecutionResult {
        await svc.submit(ActionRequest(tool: tool, arguments: args, origin: .agent(sessionID: "c"), intent: intent))
    }

    @Test func explicitSaveRunsDirectlyAndInferredSaveIsOnlySuggested() async throws {
        let s = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let svc = await service(s, approve: false)
        let inferred = await call(svc, "memory_save", ["content": "用户可能喜欢咖啡", "kind": "preference"], intent: .aiSuggested)
        #expect(inferred.status == .suggestion)
        #expect(MemoryStore(s).list(limit: 10).isEmpty)

        let r = await call(svc, "memory_save", ["content": "用户的常用机场是浦东", "kind": "fact", "subjects": ["机场"]])
        #expect(r.status == .completed)
        let saved = try #require(MemoryStore(s).list(limit: 10).first)
        #expect(saved.confirmed && saved.subjects == ["机场"] && r.output?["id"]?.stringValue == "memory:\(saved.id)")

        let bad = await call(svc, "memory_save", ["content": "x", "kind": "secret"])
        #expect(bad.error?.code == .invalidArguments)
    }

    @Test func correctAndForgetRequireConfirmation() async throws {
        let s = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let old = try MemoryStore(s).saveStated("用户的常用机场是虹桥", kind: .fact)

        let rejected = await call(await service(s, approve: false), "memory_forget", ["id": .string("memory:\(old.id)")])
        #expect(rejected.status == .rejected && MemoryStore(s).get(old.id) != nil)

        let svc = await service(s, approve: true)
        let fixed = await call(svc, "memory_correct", ["id": .string("memory:\(old.id)"), "content": "用户的常用机场是浦东"])
        #expect(fixed.status == .completed)
        #expect(MemoryStore(s).get(old.id)?.status == .superseded)
        let newID = try #require(fixed.output?["id"]?.stringValue)

        let missing = await call(svc, "memory_forget", ["id": .string("memory:\(old.id)")])
        #expect(missing.error?.code == .targetNotFound)
        let gone = await call(svc, "memory_forget", ["id": .string(newID)])
        #expect(gone.status == .completed && MemoryStore(s).search("浦东").isEmpty)
    }
}
