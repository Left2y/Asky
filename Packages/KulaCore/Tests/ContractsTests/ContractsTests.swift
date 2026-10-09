import Testing
import Foundation
@testable import Contracts

@Suite struct ContractsTests {
    @Test func actionRequestStripsForgedConfirmation() {
        let r = ActionRequest(tool: "calendar_delete_event",
                              arguments: ["id": "x", "confirmed": true, "nested": ["approved": true, "keep": 1]],
                              origin: .mcp(instanceID: "i"), intent: .explicitRequest)
        #expect(r.arguments["confirmed"] == nil)
        #expect(r.arguments["nested"]?["approved"] == nil)
        #expect(r.arguments["nested"]?["keep"] == 1)
    }

    @Test func digestIsKeyOrderIndependentAndArgumentSensitive() {
        let a = ActionRequest(tool: "t", arguments: ["a": 1, "b": "x"], origin: .launcher, intent: .explicitRequest)
        let b = ActionRequest(tool: "t", arguments: ["b": "x", "a": 1], origin: .launcher, intent: .explicitRequest)
        let c = ActionRequest(tool: "t", arguments: ["b": "y", "a": 1], origin: .launcher, intent: .explicitRequest)
        #expect(a.argumentsDigest == b.argumentsDigest)
        #expect(a.argumentsDigest != c.argumentsDigest)
    }

    @Test func jsonValueRoundTrips() throws {
        let v: JSONValue = ["s": "x", "n": 1.5, "b": false, "a": [1, "2"], "z": nil]
        let back = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(v))
        #expect(back == v)
    }

    @Test func taskStateTerminality() {
        #expect(AgentTaskState.pendingVerification.isTerminal)
        #expect(!AgentTaskState.awaitingConfirmation.isTerminal)
        #expect(!AgentTaskState.awaitingInput.isTerminal)
    }

    @Test func resourceScopeCancelsAndReleasesOnce() async {
        let scope = ResourceScope(owner: "panel", kind: .panel)
        let counter = Counter()
        scope.onEnd { counter.bump() }
        let t = scope.run { try? await Task.sleep(for: .seconds(30)) }
        scope.end()
        scope.end()
        await t.value
        #expect(t.isCancelled)
        #expect(counter.value == 1)
        // Late registration runs immediately; late work is cancelled.
        scope.onEnd { counter.bump() }
        #expect(counter.value == 2)
        let late = scope.run { }
        #expect(late.isCancelled)
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func bump() { lock.withLock { n += 1 } }
    var value: Int { lock.withLock { n } }
}
