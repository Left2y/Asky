import Testing
import Foundation
import Darwin
import Contracts
@testable import AgentHost

/// Real Node + built AgentRuntime (`npm run build` in AgentRuntime/). Skipped when either is missing.
@Suite struct RealRuntimeIntegrationTests {
    static let repoRoot = URL(filePath: #filePath).deletingLastPathComponent()
        .appending(path: "../../../..").standardized
    static let entry = repoRoot.appending(path: "AgentRuntime/dist/src/main.js").path
    static let node = NodeRuntimeLauncher.findNode()
    static var available: Bool { node != nil && FileManager.default.fileExists(atPath: entry) }

    @Test func environmentCarriesNoCredentials() {
        setenv("OPENAI_API_KEY", "leak", 1)
        defer { unsetenv("OPENAI_API_KEY") }
        let env = NodeRuntimeLauncher(nodePath: "/x", entryScript: "/y", dataDirectory: "/tmp/z").environment()
        #expect(Set(env.keys).isSubset(of: ["PATH", "HOME", "TMPDIR", "LANG", "LC_ALL", "TZ"]))
        #expect(!env.values.contains("leak"))
    }

    @Test(.enabled(if: available), .timeLimit(.minutes(1)))
    func unreachableModelFailsAndProcessIsGone() async throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "kula-int-\(UUID().uuidString)").path
        let launcher = NodeRuntimeLauncher(nodePath: Self.node!, entryScript: Self.entry, dataDirectory: dir, stderrLog: dir + "/runtime.log")
        let host = AgentHost(launcher: launcher.launcher,
                             configProvider: { RuntimeLaunchConfig(baseURL: "http://127.0.0.1:1/v1", model: "m", apiKey: "sk-int") },
                             toolsProvider: { [] },
                             toolHandler: { req in ExecutionResult(requestID: req.requestID, status: .failed) })
        let request = AgentRequest(sessionID: "s", taskID: "t", text: "hi", attachments: [], context: [])
        var states: [AgentTaskState] = []
        for await ev in await host.submit(request) {
            if case .taskState(_, let s) = ev { states.append(s) }
        }
        #expect(states.first == .starting)
        #expect(states.contains(.running))
        #expect(states.last == .failed)
        let pid = try #require(await host.runningPID)
        await host.shutdown()
        #expect(kill(pid, 0) == -1 && errno == ESRCH)
        #expect(await host.runningPID == nil)
    }
}
