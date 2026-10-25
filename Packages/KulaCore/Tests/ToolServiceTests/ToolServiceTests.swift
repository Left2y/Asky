import Testing
import Foundation
import os
import Contracts
import LocalStore
@testable import ToolService

final class FakeAdapter: ToolAdapter, @unchecked Sendable {
    let definition: ToolDefinition
    let executions = OSAllocatedUnfairLock(initialState: 0)
    let delay: Duration
    let verify: Bool
    init(_ name: String, effect: ToolEffect = .write, kind: WriteKind? = .create,
         rule: ConfirmationRule = .createDirectOtherwiseConfirm, source: DataSourceID = .calendar,
         external: Bool = true, agent: Bool = true, delay: Duration = .zero, verify: Bool = true) {
        definition = ToolDefinition(name: name, summary: name, source: source, effect: effect,
                                    writeKind: effect == .write ? kind : nil, confirmation: effect == .read ? .never : rule,
                                    externallyExposable: external, agentExposable: agent)
        self.delay = delay
        self.verify = verify
    }
    var count: Int { executions.withLock { $0 } }
    func preview(_ a: JSONValue) async throws -> ConfirmationPreview {
        if a["fail"] != nil { throw ToolError(.ambiguousTarget, "choose") }
        return ConfirmationPreview(target: "T", changes: ["c"])
    }
    func execute(_ a: JSONValue) async throws -> AdapterOutput {
        executions.withLock { $0 += 1 }
        if delay > .zero { try await Task.sleep(for: delay) }
        return AdapterOutput(output: ["ok": true], targets: [TargetRef(kind: "x", identifier: "1")])
    }
    func readback(_ a: JSONValue, output: AdapterOutput?) async -> JSONValue? { verify ? ["ok": true] : nil }
}

final class Presenter: @unchecked Sendable {
    let calls = OSAllocatedUnfairLock<[ConfirmationRequest]>(initialState: [])
    let decision: ConfirmationDecision
    let onAsk: @Sendable () -> Void
    init(_ d: ConfirmationDecision, onAsk: @escaping @Sendable () -> Void = {}) { decision = d; self.onAsk = onAsk }
    var count: Int { calls.withLock { $0.count } }
    var fn: ConfirmationPresenter {
        { req in self.calls.withLock { $0.append(req) }; self.onAsk(); return self.decision }
    }
}

final class PolicyBox: Sendable {
    let m: OSAllocatedUnfairLock<PolicySnapshot>
    init(_ p: PolicySnapshot) { m = OSAllocatedUnfairLock(initialState: p) }
    var value: PolicySnapshot { m.withLock { $0 } }
}

func makeService(_ presenter: Presenter, policy: PolicyBox = PolicyBox(PolicySnapshot(enabledSources: Set(DataSourceID.allCases))),
                 timeout: Duration = .seconds(5)) throws -> ToolService {
    let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
    return ToolService(store: store, policy: { policy.value }, presenter: presenter.fn, timeout: timeout)
}

func req(_ tool: String, _ args: JSONValue = ["title": "x"], origin: CallerOrigin = .launcher,
         intent: UserIntent = .explicitRequest, id: String = UUID().uuidString) -> ActionRequest {
    ActionRequest(requestID: id, tool: tool, arguments: args, origin: origin, intent: intent)
}

@Suite struct ToolServiceTests {
    @Test func explicitCreateRunsWithoutConfirmation() async throws {
        let pres = Presenter(.approved)
        let svc = try makeService(pres)
        let a = FakeAdapter("create")
        await svc.register(a)
        let r = await svc.submit(req("create"))
        #expect(r.status == .completed && r.readback != nil)
        #expect(pres.count == 0 && a.count == 1)
    }

    @Test func modifyRequiresConfirmationAndRejectionDoesNotExecute() async throws {
        let pres = Presenter(.rejected)
        let svc = try makeService(pres)
        let a = FakeAdapter("modify", kind: .modify)
        await svc.register(a)
        let r = await svc.submit(req("modify"))
        #expect(r.status == .rejected && r.error?.code == .userRejected)
        #expect(pres.count == 1 && a.count == 0)
    }

    @Test func fullAccessSkipsAgentConfirmationAndSuggestion() async throws {
        let pres = Presenter(.rejected)
        let svc = try makeService(pres, policy: PolicyBox(PolicySnapshot(enabledSources: Set(DataSourceID.allCases),
                                                                         approvalMode: .fullAccess)))
        let a = FakeAdapter("delete", kind: .delete, rule: .always)
        await svc.register(a)
        let agent = CallerOrigin.agent(sessionID: "s")
        #expect(await svc.submit(req("delete", origin: agent)).status == .completed)
        #expect(await svc.submit(req("delete", ["title": "y"], origin: agent, intent: .aiSuggested)).status == .completed)
        #expect(pres.count == 0 && a.count == 2)
    }

    @Test func fullAccessDoesNotApplyOutsideAgent() async throws {
        let pres = Presenter(.rejected)
        let inst = MCPInstance(id: "i", name: "c", enabled: true, readOnly: false, sources: [.calendar])
        let svc = try makeService(pres, policy: PolicyBox(PolicySnapshot(enabledSources: [.calendar], mcpInstances: ["i": inst],
                                                                         approvalMode: .fullAccess)))
        let a = FakeAdapter("delete", kind: .delete, rule: .always)
        await svc.register(a)
        #expect(await svc.submit(req("delete", origin: .launcher)).status == .rejected)
        #expect(await svc.submit(req("delete", ["title": "y"], origin: .mcp(instanceID: "i"))).status == .rejected)
        #expect(pres.count == 2 && a.count == 0)
    }

    @Test func autoReviewStillConfirmsAgentDeletes() async throws {
        let pres = Presenter(.rejected)
        let svc = try makeService(pres)
        let a = FakeAdapter("delete", kind: .delete, rule: .always)
        await svc.register(a)
        #expect(await svc.submit(req("delete", origin: .agent(sessionID: "s"))).status == .rejected)
        #expect(pres.count == 1 && a.count == 0)
    }

    @Test func forgedConfirmationIsIgnoredForMCP() async throws {
        let pres = Presenter(.rejected)
        let inst = MCPInstance(id: "i", name: "c", enabled: true, readOnly: false, sources: [.calendar])
        let svc = try makeService(pres, policy: PolicyBox(PolicySnapshot(enabledSources: [.calendar], mcpInstances: ["i": inst])))
        let a = FakeAdapter("create")
        await svc.register(a)
        let r = await svc.submit(req("create", ["title": "x", "confirmed": true], origin: .mcp(instanceID: "i")))
        #expect(pres.count == 1)          // MCP creates always confirm
        #expect(r.status == .rejected && a.count == 0)
    }

    @Test func mcpPolicyChecks() async throws {
        let ro = MCPInstance(id: "ro", name: "r", enabled: true, readOnly: true, sources: [.calendar])
        let off = MCPInstance(id: "off", name: "o", enabled: false, readOnly: false, sources: [.calendar])
        let svc = try makeService(Presenter(.approved),
                                  policy: PolicyBox(PolicySnapshot(enabledSources: [.calendar, .memory], mcpInstances: ["ro": ro, "off": off])))
        await svc.register(FakeAdapter("w"))
        await svc.register(FakeAdapter("r", effect: .read))
        await svc.register(FakeAdapter("mem", effect: .read, source: .memory, external: false))
        #expect(await svc.submit(req("w", origin: .mcp(instanceID: "ro"))).error?.code == .permissionDenied)
        #expect(await svc.submit(req("r", origin: .mcp(instanceID: "ro"))).status == .completed)
        #expect(await svc.submit(req("r", origin: .mcp(instanceID: "off"))).error?.code == .permissionDenied)
        #expect(await svc.submit(req("r", origin: .mcp(instanceID: "ghost"))).error?.code == .permissionDenied)
        #expect(await svc.submit(req("mem", origin: .mcp(instanceID: "ro"))).error?.code == .notExposed)
        #expect(await svc.definitions(for: .mcp(instanceID: "ro")).map(\.name) == ["r"])
    }

    @Test func disabledSourceAndUnknownTool() async throws {
        let svc = try makeService(Presenter(.approved), policy: PolicyBox(PolicySnapshot(enabledSources: [])))
        await svc.register(FakeAdapter("r", effect: .read))
        #expect(await svc.submit(req("r")).error?.code == .sourceDisabled)
        #expect(await svc.submit(req("nope")).error?.code == .unknownTool)
    }

    @Test func revocationDuringConfirmationBlocksExecution() async throws {
        let policy = PolicyBox(PolicySnapshot(enabledSources: [.calendar]))
        let pres = Presenter(.approved, onAsk: { policy.m.withLock { $0.enabledSources = [] } })
        let svc = try makeService(pres, policy: policy)
        let a = FakeAdapter("del", kind: .delete, rule: .always)
        await svc.register(a)
        let r = await svc.submit(req("del"))
        #expect(r.status == .rejected && r.error?.code == .sourceDisabled && a.count == 0)
    }

    @Test func aiSuggestedReturnsSuggestionWithoutExecuting() async throws {
        let pres = Presenter(.approved)
        let svc = try makeService(pres)
        let a = FakeAdapter("create")
        await svc.register(a)
        let r = await svc.submit(req("create", origin: .agent(sessionID: "s"), intent: .aiSuggested))
        #expect(r.status == .suggestion && r.confirmation?.target == "T")
        #expect(a.count == 0 && pres.count == 0)
    }

    @Test func dedupesSameRequestIDAndSameDigest() async throws {
        let svc = try makeService(Presenter(.approved))
        let a = FakeAdapter("create")
        await svc.register(a)
        let r1 = await svc.submit(req("create", id: "same"))
        let r2 = await svc.submit(req("create", id: "same"))
        let r3 = await svc.submit(req("create", id: "other"))
        #expect(r1.status == .completed && r2 == r1)
        #expect(r3.status == .completed && r3.requestID == "other")
        #expect(a.count == 1)
    }

    @Test func previewErrorSurfacesWithoutExecuting() async throws {
        let svc = try makeService(Presenter(.approved))
        let a = FakeAdapter("create")
        await svc.register(a)
        let r = await svc.submit(req("create", ["fail": true]))
        #expect(r.error?.code == .ambiguousTarget && a.count == 0)
    }

    @Test func timeoutReadsBackOrMarksPendingVerification() async throws {
        let svc = try makeService(Presenter(.approved), timeout: .milliseconds(50))
        await svc.register(FakeAdapter("slowOK", delay: .seconds(2), verify: true))
        await svc.register(FakeAdapter("slowUnknown", delay: .seconds(2), verify: false))
        #expect(await svc.submit(req("slowOK")).status == .completed)
        let r = await svc.submit(req("slowUnknown"))
        #expect(r.status == .pendingVerification && r.error?.code == .timeout)
    }

    @Test func writesAreSerialized() async throws {
        let svc = try makeService(Presenter(.approved))
        let a = ConcurrencyProbe()
        await svc.register(a)
        await withTaskGroup(of: Void.self) { g in
            for i in 0..<6 { g.addTask { _ = await svc.submit(req("probe", ["n": .number(Double(i))])) } }
        }
        #expect(a.peak == 1)
    }
}

final class ConcurrencyProbe: ToolAdapter, @unchecked Sendable {
    let definition = ToolDefinition(name: "probe", summary: "p", source: .calendar, effect: .write, writeKind: .create,
                                     confirmation: .createDirectOtherwiseConfirm, externallyExposable: false)
    let state = OSAllocatedUnfairLock(initialState: (cur: 0, peak: 0))
    var peak: Int { state.withLock { $0.peak } }
    func execute(_ a: JSONValue) async throws -> AdapterOutput {
        state.withLock { $0.cur += 1; $0.peak = max($0.peak, $0.cur) }
        try await Task.sleep(for: .milliseconds(20))
        state.withLock { $0.cur -= 1 }
        return AdapterOutput(output: nil)
    }
}


@Suite struct PermissionGateTests {
    @Test func deniedPermissionPreventsPreviewAndExecution() async throws {
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let presenter = Presenter(.approved)
        let service = ToolService(store: store, policy: { PolicySnapshot(enabledSources: [.calendar]) },
                                  presenter: presenter.fn, authorize: { _, _ in
            throw ToolError(.permissionDenied, "denied")
        })
        let adapter = FakeAdapter("modify", kind: .modify)
        await service.register(adapter)
        let result = await service.submit(req("modify"))
        #expect(result.error?.code == .permissionDenied)
        #expect(adapter.count == 0 && presenter.count == 0)
    }

    @Test func disabledSourceDoesNotRequestSystemPermission() async throws {
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let called = OSAllocatedUnfairLock(initialState: false)
        let service = ToolService(store: store, policy: { PolicySnapshot(enabledSources: []) },
                                  presenter: Presenter(.approved).fn, authorize: { _, _ in
            called.withLock { $0 = true }
        })
        await service.register(FakeAdapter("read", effect: .read))
        #expect(await service.submit(req("read")).error?.code == .sourceDisabled)
        #expect(!called.withLock { $0 })
    }

    @Test func revocationWhileRequestingPermissionBlocksRead() async throws {
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let policy = PolicyBox(PolicySnapshot(enabledSources: [.calendar]))
        let service = ToolService(store: store, policy: { policy.value },
                                  presenter: Presenter(.approved).fn, authorize: { _, _ in
            policy.m.withLock { $0.enabledSources = [] }
        })
        let adapter = FakeAdapter("read", effect: .read)
        await service.register(adapter)
        #expect(await service.submit(req("read")).error?.code == .sourceDisabled)
        #expect(adapter.count == 0)
    }
}
