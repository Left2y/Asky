import Foundation
import Testing
import Contracts
import LocalStore
@testable import ToolService

private func fixture(_ version: String = "1", dependency: Bool = false) -> String {
    """
    {"id":"example","name":"Example","version":"\(version)","apiVersion":1,"entry":"index.mjs","instructions":"SKILL.md",
    "configuration":[{"key":"choice","label":"Choice","type":"enum","options":["one","two"],"required":true,"defaultValue":"one"}],
    "tools":[{"name":"run","description":"Run","effect":"write","confirmation":"explicitDirectOtherwiseConfirm","timeoutSeconds":20,
    "inputSchema":{"type":"object","required":["text"],"additionalProperties":false,"properties":{"text":{"type":"string","minLength":1}}}}]}
    """
}
private func prepareFixture(_ url: URL, version: String = "1", dependency: Bool = false) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    try fixture(version).write(to: url.appending(path: "asky-plugin.json"), atomically: true, encoding: .utf8)
    try "Use example tools.".write(to: url.appending(path: "SKILL.md"), atomically: true, encoding: .utf8)
    try """
    export default {tools:{run:{async execute(args,ctx){
    console.log('diagnostic only');
    const r=await ctx.exec('/usr/bin/printf',['%s',args.text]);
    await ctx.saveState({[ctx.requestID]:r.stdout});return {text:r.stdout};
    },async readback(args,ctx){return ctx.state[ctx.requestID]===args.text?{text:ctx.state[ctx.requestID]}:null;}}}};
    """.write(to: url.appending(path: "index.mjs"), atomically: true, encoding: .utf8)
    if dependency { try "{\"dependencies\":{\"example\":\"1\"}}".write(to: url.appending(path: "package.json"), atomically: true, encoding: .utf8) }
}
private func installer(version: String = "1", dependency: Bool = false, failure: Bool = false) -> @Sendable (String, [String], URL?, Double) async throws -> PluginCommandResult {
    { _, args, _, _ in
        if failure { throw ToolError(.adapterFailure, "simulated download failure") }
        if args.first == "clone" { try prepareFixture(URL(filePath: args.last!), version: version, dependency: dependency) }
        return PluginCommandResult(stdout: "commit-\(version)", stderr: "", exitCode: 0)
    }
}
@Suite struct PluginTests {
    @Test func repositoryAndManifestValidation() throws {
        #expect(try PluginManager.repositoryURL("https://github.com/niall-young/asky-plugin-orca.git/") == PluginManager.officialRepositories[0])
        for url in ["file:///tmp/repo", "https://user:token@github.com/a/b", "https://github.com/a/b/tree/main", "https://github.com/a/b?token=x"] {
            #expect(throws: Error.self) { try PluginManager.repositoryURL(url) }
        }
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try prepareFixture(root)
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(fixture().utf8))
        try manifest.validate(at: root)
        #expect(throws: Error.self) { try PluginManifest.resource("../escape", at: root) }
    }
    @Test func installUpdateFailureRollbackDisableAndUninstall() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LocalStore(root: root), manager = PluginManager(store: store)
        #expect(await manager.installed().isEmpty)
        await manager.setInstallationCommand(installer())
        try await manager.install(repository: "https://github.com/example/plugin")
        #expect(await manager.definitions().count == 1)
        #expect(await manager.guidance().first?.contains("example") == true)
        await manager.setInstallationCommand(installer(version: "2"))
        try await manager.install(repository: "https://github.com/example/plugin")
        #expect(await manager.installed().first?.commit == "commit-2")
        await manager.setInstallationCommand(installer(failure: true))
        await #expect(throws: Error.self) { try await manager.install(repository: "https://github.com/example/plugin") }
        #expect(await manager.installed().first?.commit == "commit-2")
        try await manager.rollback("example")
        #expect(await manager.installed().first?.commit == "commit-1")
        await manager.setInstallationCommand(installer())
        await #expect(throws: Error.self) { try await manager.install(repository: "https://github.com/other/plugin") }
        await manager.setEnabled("example", false)
        #expect(await manager.definitions().isEmpty)
        #expect(await manager.adapter(named: "plugin_example__run") == nil)
        await #expect(throws: Error.self) { try await manager.configure("example", values: ["choice": "invalid"]) }
        store.setCodableSetting("plugins.state.example", ["kept": true] as JSONValue)
        try await manager.uninstall("example")
        #expect(await manager.installed().isEmpty)
        #expect(store.codableSetting("plugins.state.example", as: JSONValue.self)?["kept"] == true)
    }
    @Test func missingLockfileLeavesNoInstallation() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = PluginManager(store: try LocalStore(root: root))
        await manager.setInstallationCommand(installer(dependency: true))
        await #expect(throws: Error.self) { try await manager.install(repository: "https://github.com/example/plugin") }
        #expect(await manager.installed().isEmpty)
    }
    @Test func nativeWorkerRoundTripAndPolicy() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var repository = URL(filePath: #filePath)
        for _ in 0..<5 { repository.deleteLastPathComponent() }
        let runner = repository.appending(path: "AgentRuntime/dist/src/plugin-runner.js")
        let node = try PluginProcess.executable("node")
        #expect(FileManager.default.fileExists(atPath: runner.path))
        let store = try LocalStore(root: root)
        let service = ToolService(store: store, policy: { PolicySnapshot(enabledSources: [.plugins]) },
            presenter: { _ in Issue.record("Explicit plugin requests should not confirm"); return .rejected },
            pluginRuntime: .init(nodePath: node, runnerPath: runner.path))
        await service.plugins.setInstallationCommand(installer())
        try await service.plugins.install(repository: "https://github.com/example/plugin")
        let text = "line one\n\"quotes\" `literal` $(literal) 中文"
        let request = ActionRequest(requestID: "stable-request", tool: "plugin_example__run", arguments: ["text": .string(text)], origin: .agent(sessionID: "s"), intent: .explicitRequest)
        let result = await service.submit(request)
        #expect(result.status == .completed)
        #expect(result.output?["text"] == .string(text))
        #expect(result.readback?["text"] == .string(text))
        #expect(await service.submit(request) == result)
        let suggestion = await service.submit(ActionRequest(tool: request.tool, arguments: request.arguments, origin: request.origin, intent: .aiSuggested))
        #expect(suggestion.status == .suggestion)
        #expect(await service.definitions(for: .mcp(instanceID: "unknown")).isEmpty)
        await service.plugins.setEnabled("example", false)
        let disabled = await service.submit(ActionRequest(tool: request.tool, arguments: request.arguments, origin: request.origin, intent: .explicitRequest))
        #expect(disabled.status == .failed || disabled.status == .rejected)
    }
    @Test func processCancellationAndOutputLimit() async throws {
        let start = ContinuousClock.now
        let task = Task { try await PluginProcess.command("/bin/sleep", ["30"]) }
        try await Task.sleep(for: .milliseconds(100)); task.cancel()
        await #expect(throws: Error.self) { _ = try await task.value }
        #expect(start.duration(to: .now) < .seconds(3))
        await #expect(throws: Error.self) { _ = try await PluginProcess.command("/usr/bin/yes", [], seconds: 3) }
    }
    @Test func updateWaitsForExecutionLeaseAndDisableBlocksNewCalls() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = PluginManager(store: try LocalStore(root: root))
        await manager.setInstallationCommand(installer())
        try await manager.install(repository: "https://github.com/example/plugin")
        try await manager.acquire("example", requestID: "lease")
        await manager.setInstallationCommand(installer(version: "2"))
        let update = Task { try await manager.install(repository: "https://github.com/example/plugin") }
        try await Task.sleep(for: .milliseconds(150))
        #expect(await manager.installed().first?.commit == "commit-1")
        await manager.setEnabled("example", false)
        #expect(await manager.definitions().isEmpty)
        await manager.release("example", requestID: "lease")
        try await update.value
        #expect(await manager.installed().first?.commit == "commit-2")
        #expect(await manager.installed().first?.enabled == false)
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ASKY_ORCA_LIVE_TEST"] == "1"))
    func liveGitHubInstallAndOrcaHandoff() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "asky-orca-live-" + UUID().uuidString)
        // Retain this test project because Orca owns the resulting independent checkout and Agent.
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let project = root.appending(path: "project")
        _ = try await PluginProcess.command("git", ["init", "-b", "main", project.path])
        try "Dedicated Asky plugin acceptance project.\n".write(to: project.appending(path: "README.md"), atomically: true, encoding: .utf8)
        _ = try await PluginProcess.command("git", ["add", "README.md"], cwd: project)
        _ = try await PluginProcess.command("git", ["-c", "user.name=Asky Test", "-c", "user.email=asky-test@example.invalid", "commit", "-m", "test: initial acceptance project"], cwd: project)
        var repository = URL(filePath: #filePath)
        for _ in 0..<5 { repository.deleteLastPathComponent() }
        let service = ToolService(store: try LocalStore(root: root.appending(path: "data")),
            policy: { PolicySnapshot(enabledSources: [.plugins]) }, presenter: { _ in .rejected },
            pluginRuntime: .init(nodePath: try PluginProcess.executable("node"), runnerPath: repository.appending(path: "AgentRuntime/dist/src/plugin-runner.js").path))
        try await service.plugins.install(repository: PluginManager.officialRepositories[0])
        let request = ActionRequest(requestID: UUID().uuidString, tool: "plugin_orca__submit_task",
            arguments: ["projectPath": .string(project.path), "agent": "codex", "name": "asky-plugin-acceptance",
                        "prompt": "This is a plugin acceptance test. Read README.md and reply exactly ASKY_ORCA_PLUGIN_OK. Do not modify files, commit, or start other agents."],
            origin: .agent(sessionID: "live"), intent: .explicitRequest)
        let result = await service.submit(request)
        try JSONEncoder().encode(result).write(to: repository.appending(path: "build/plugin-live-result.json"))
        #expect(result.status == .completed)
        let handoff = try #require(result.output?["handoffID"]?.stringValue)
        #expect(["input_accepted", "turn_started"].contains(result.output?["stage"]?.stringValue ?? ""))
        let query = await service.submit(ActionRequest(tool: "plugin_orca__query_handoff", arguments: ["handoffID": .string(handoff)], origin: .agent(sessionID: "live"), intent: .explicitRequest))
        try JSONEncoder().encode(query).write(to: repository.appending(path: "build/plugin-live-query.json"))
        #expect(query.status == .completed)
        let followup = await service.submit(ActionRequest(tool: "plugin_orca__send_message", arguments: ["handoffID": .string(handoff), "prompt": "Reply exactly ASKY_ORCA_FOLLOWUP_OK. Do not modify files."], origin: .agent(sessionID: "live"), intent: .explicitRequest))
        try JSONEncoder().encode(followup).write(to: repository.appending(path: "build/plugin-live-followup.json"))
        #expect(followup.status == .completed)
        print("Live plugin acceptance state retained at \(root.path)")
    }

}
