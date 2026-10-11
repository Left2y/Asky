import Testing
import Foundation
import Synchronization
import Contracts
import LocalStore
import ToolService
import MCPLink
@testable import MCPGateway

private final class Adapter: ToolAdapter, @unchecked Sendable {
    let definition: ToolDefinition
    let runs = Mutex(0)
    init(_ name: String, effect: ToolEffect, source: DataSourceID = .calendar, external: Bool = true) {
        definition = ToolDefinition(name: name, summary: name, source: source, effect: effect,
                                    writeKind: effect == .write ? .create : nil,
                                    confirmation: effect == .read ? .never : .createDirectOtherwiseConfirm,
                                    externallyExposable: external)
    }
    func execute(_ a: JSONValue) async throws -> AdapterOutput {
        runs.withLock { $0 += 1 }
        return AdapterOutput(output: ["ok": true])
    }
}

/// Blocking socket client off the cooperative pool.
private func blocking<T: Sendable>(_ body: @escaping @Sendable () -> T) async -> T {
    await withCheckedContinuation { c in Thread { c.resume(returning: body()) }.start() }
}

private struct Fixture {
    let store: LocalStore
    let gateway: MCPGateway
    let server: MCPLinkServer
    let path: String
    let write: Adapter
    let read: Adapter

    static func make() async throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.appending(path: "mcp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try LocalStore(inMemoryWithRoot: root)
        let instances = MCPInstanceStore(store)
        let svc = ToolService(store: store, policy: {
            PolicySnapshot(enabledSources: Set(DataSourceID.allCases),
                           mcpInstances: Dictionary(uniqueKeysWithValues: instances.all().map { ($0.id, $0) }))
        }, presenter: { _ in .rejected })
        let w = Adapter("cal_create", effect: .write), r = Adapter("cal_list", effect: .read)
        await svc.register(w)
        await svc.register(r)
        await svc.register(Adapter("notes_search", effect: .read, source: .notes))
        // Mis-declared as external on purpose: the gateway deny-list must still hide it.
        await svc.register(Adapter("memory_search", effect: .read, source: .memory, external: true))
        let gw = MCPGateway(store: store, tools: svc)
        let path = "/tmp/kmcp-\(UUID().uuidString.prefix(8)).sock"
        let server = MCPLinkServer(socketPath: path, gateway: gw)
        return Fixture(store: store, gateway: gw, server: server, path: path, write: w, read: r)
    }
}

@Suite struct MCPGatewayTests {
    @Test func appNotRunningIsRecoverableUnavailable() async {
        let err = await blocking { () -> MCPLinkError? in
            do { _ = try MCPLinkClient(socketPath: "/tmp/kmcp-none-\(UUID().uuidString.prefix(6)).sock", credential: "x"); return nil }
            catch { return error as? MCPLinkError }
        }
        #expect(err == .appUnavailable)
    }

    @Test func instanceLifecycleScopesConfirmationAndRevocation() async throws {
        let f = try await Fixture.make()
        try f.server.start()
        defer { f.server.stop() }
        let path = f.path
        let instances = MCPInstanceStore(f.store)

        let registered = try f.gateway.register(name: "Claude Desktop")
        var inst = registered.0
        let cred = registered.credential
        #expect(!inst.enabled && inst.readOnly)                       // default off, read-only
        #expect(!cred.isEmpty && f.gateway.authenticate("wrong") == nil)

        // Disabled instance is denied at handshake.
        let denied = await blocking { () -> MCPLinkError? in
            do { _ = try MCPLinkClient(socketPath: path, credential: cred); return nil } catch { return error as? MCPLinkError }
        }
        if case .denied = denied {} else { Issue.record("expected denied, got \(String(describing: denied))") }

        inst.enabled = true
        inst.sources = [.calendar]
        try instances.update(inst)
        let client = try await blocking { Result { try MCPLinkClient(socketPath: path, credential: cred) } }.get()
        #expect(client.instance == "Claude Desktop")

        // Scope: only calendar reads (read-only), never memory even if mis-declared.
        let names = try await blocking { Result { try client.listTools().map(\.name) } }.get()
        #expect(names == ["cal_list"])
        let read = try await blocking { Result { try client.call(tool: "cal_list", arguments: [:]) } }.get()
        #expect(read.status == .completed)
        let mem = try await blocking { Result { try client.call(tool: "memory_search", arguments: [:]) } }.get()
        #expect(mem.status == .rejected && f.read.runs.withLock { $0 } == 1)
        let ro = try await blocking { Result { try client.call(tool: "cal_create", arguments: ["title": "x"]) } }.get()
        #expect(ro.error?.code == .permissionDenied)

        // Writable: a forged "confirmed" flag is stripped; native confirmation (rejected here) decides.
        inst.readOnly = false
        try instances.update(inst)
        let forged = try await blocking {
            Result { try client.call(tool: "cal_create", arguments: ["title": "x", "confirmed": true, "approved": true]) }
        }.get()
        #expect(forged.status == .rejected && forged.error?.code == .userRejected)
        #expect(f.write.runs.withLock { $0 } == 0)

        // Revocation applies to the open connection immediately.
        try instances.delete(inst.id)
        let revoked = try await blocking { Result { try client.call(tool: "cal_list", arguments: [:]) } }.get()
        #expect(revoked.status == .rejected && revoked.error?.code == .permissionDenied)
        #expect(f.read.runs.withLock { $0 } == 1)
    }

    @Test func stoppingServerMakesBridgeUnavailable() async throws {
        let f = try await Fixture.make()
        try f.server.start()
        f.server.stop()
        let path = f.path
        let err = await blocking { () -> MCPLinkError? in
            do { _ = try MCPLinkClient(socketPath: path, credential: "x"); return nil } catch { return error as? MCPLinkError }
        }
        #expect(err == .appUnavailable)
    }

    @Test func socketIsOwnerOnly() async throws {
        let f = try await Fixture.make()
        try f.server.start()
        defer { f.server.stop() }
        let attrs = try FileManager.default.attributesOfItem(atPath: f.path)
        #expect((attrs[.posixPermissions] as? Int) == 0o600)
    }

    @Test func stdioServerSpeaksMCP() throws {
        let server = MCPStdioServer(version: "t", listTools: {
            [ToolDefinition(name: "cal_list", summary: "列出", source: .calendar, effect: .read, writeKind: nil,
                            confirmation: .never, externallyExposable: true)]
        }, callTool: { tool, args in
            #expect(args == ["a": 1])
            return ExecutionResult(requestID: "r", status: tool == "cal_list" ? .completed : .rejected)
        })
        func rpc(_ s: String) throws -> JSONValue? {
            try server.handle(Data(s.utf8)).map { try JSONDecoder().decode(JSONValue.self, from: $0) }
        }
        let ini = try #require(try rpc(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26"}}"#))
        #expect(ini["id"] == 1 && ini["result"]?["protocolVersion"] == "2025-03-26")
        #expect(ini["result"]?["capabilities"]?["tools"] != nil)
        #expect(try rpc(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil)
        let list = try #require(try rpc(#"{"jsonrpc":"2.0","id":"x","method":"tools/list"}"#))
        #expect(list["id"] == "x" && list["result"]?["tools"]?.arrayValue?.first?["name"] == "cal_list")
        #expect(list["result"]?["tools"]?.arrayValue?.first?["inputSchema"]?["type"] == "object")
        let ok = try #require(try rpc(#"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"cal_list","arguments":{"a":1}}}"#))
        #expect(ok["result"]?["isError"] == false)
        let no = try #require(try rpc(#"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"x","arguments":{"a":1}}}"#))
        #expect(no["result"]?["isError"] == true)
        #expect(try rpc(#"{"jsonrpc":"2.0","id":5,"method":"nope"}"#)?["error"]?["code"] == -32601)
        #expect(try rpc("{bad")?["error"]?["code"] == -32700)
        let raw = try #require(server.handle(Data(#"{"jsonrpc":"2.0","id":7,"method":"ping"}"#.utf8)))
        #expect(String(decoding: raw, as: UTF8.self).contains(#""id":7"#))   // integer ids round-trip as integers
    }

    /// Spawns the built `asky-mcp` (swift build in MCPBridge/) against a live link server.
    static let bridge = URL(filePath: #filePath).deletingLastPathComponent()
        .appending(path: "../../../../MCPBridge/.build/debug/asky-mcp").standardized.path
    @Test(.enabled(if: FileManager.default.isExecutableFile(atPath: bridge)), .timeLimit(.minutes(1)), arguments: ["ASKY", "KULAHERE"])
    func bridgeBinaryEndToEnd(prefix: String) async throws {
        let f = try await Fixture.make()
        try f.server.start()
        defer { f.server.stop() }
        var (inst, cred) = try f.gateway.register(name: "e2e")
        inst.enabled = true
        inst.sources = [.calendar]
        try MCPInstanceStore(f.store).update(inst)

        let p = Process()
        p.executableURL = URL(filePath: Self.bridge)
        p.environment = ["\(prefix)_MCP_CREDENTIAL": cred, "\(prefix)_MCP_SOCKET": f.path]
        let inPipe = Pipe(), outPipe = Pipe()
        p.standardInput = inPipe
        p.standardOutput = outPipe
        try p.run()
        let input = [
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}"#,
            #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
            #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#,
            #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"cal_create","arguments":{"title":"x","confirmed":true}}}"#,
        ].joined(separator: "\n") + "\n"
        inPipe.fileHandleForWriting.write(Data(input.utf8))
        try inPipe.fileHandleForWriting.close()
        let out = await blocking { outPipe.fileHandleForReading.readDataToEndOfFile() }
        p.waitUntilExit()
        let lines = out.split(separator: 0x0A).compactMap { try? JSONDecoder().decode(JSONValue.self, from: Data($0)) }
        #expect(lines.count == 3)
        #expect(lines.first?["result"]?["serverInfo"]?["name"] == "asky")
        #expect(lines.dropFirst().first?["result"]?["tools"]?.arrayValue?.compactMap { $0["name"]?.stringValue } == ["cal_list"])
        #expect(lines.last?["result"]?["isError"] == true)     // read-only instance: write refused
        #expect(f.write.runs.withLock { $0 } == 0)
    }

    @Test func framerBoundsFrames() {
        var fr = LineFramer()
        var over = 0
        let big = Data(repeating: 0x61, count: MCPLink.maxFrameBytes + 10) + Data([0x0A]) + Data("ok\n".utf8)
        let out = fr.push(big) { over += 1 }
        #expect(over == 1 && out == [Data("ok".utf8)])
    }
}
