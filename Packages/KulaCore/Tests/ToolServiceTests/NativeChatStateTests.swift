import Foundation
import Testing
import Contracts
import LocalStore
@testable import ToolService

/// Continuations let each test choose exactly which I/O completes after a reconnect.
@MainActor private final class ControlledChatSocket: NativeChatSocket {
    private var frames: [JSONValue] = []
    private var reader: CheckedContinuation<JSONValue, Error>?
    private var writer: CheckedContinuation<Void, Error>?
    private var closed = false
    var sent: [JSONValue] = []
    var holdSend = false

    func resume() {}
    func cancel() {
        closed = true
        reader?.resume(throwing: NativeChatError.unavailable)
        reader = nil
    }
    func receive() async throws -> JSONValue {
        if closed { throw NativeChatError.unavailable }
        if !frames.isEmpty { return frames.removeFirst() }
        return try await withCheckedThrowingContinuation { reader = $0 }
    }
    func send(_ frame: JSONValue) async throws {
        sent.append(frame)
        if holdSend { try await withCheckedThrowingContinuation { writer = $0 } }
    }
    func finishSend(fails: Bool) {
        if fails { writer?.resume(throwing: NativeChatError.unavailable) }
        else { writer?.resume() }
        writer = nil
    }
    func emit(_ type: String, _ data: JSONValue) {
        let frame: JSONValue = ["type": .string(type), "data": data]
        if let reader { self.reader = nil; reader.resume(returning: frame) }
        else { frames.append(frame) }
    }
    func snapshot(busy: Bool = false) { emit("generating_snapshot", ["ids": .array(busy ? ["thread-1"] : [])]) }
    func busy(_ value: Bool) { emit("thread_generating", ["id": "thread-1", "isGenerating": .bool(value)]) }
    func added() { emit("message_added", ["threadId": "thread-1"]) }
    func delta(_ text: String) {
        emit("message_delta", ["threadId": "thread-1", "messageId": "reply", "deltas": [
            ["type": "text_append", "partType": "text", "partIndex": 0, "text": .string(text)]
        ]])
    }
}

@MainActor private final class ControlledChatTransport: NativeChatTransport {
    struct Read {
        let path: String
        var continuation: CheckedContinuation<JSONValue, Error>?
    }
    var sockets: [ControlledChatSocket] = []
    var reads: [Read] = []
    var activeReads: Int { reads.filter { $0.continuation != nil }.count }
    func makeSocket() -> any NativeChatSocket {
        let socket = ControlledChatSocket()
        sockets.append(socket)
        return socket
    }
    func api(_ path: String, body: JSONValue?) async throws -> JSONValue {
        if path == "/api/threads", body != nil { return ["id": "thread-1"] }
        return try await withCheckedThrowingContinuation { reads.append(Read(path: path, continuation: $0)) }
    }
    func finish(_ index: Int, _ body: JSONValue = []) {
        reads[index].continuation?.resume(returning: body)
        reads[index].continuation = nil
    }
    func fail(_ index: Int) {
        reads[index].continuation?.resume(throwing: NativeChatError.http(503))
        reads[index].continuation = nil
    }
}

@MainActor private func eventually(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(3)
    while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(1)) }
    try #require(condition())
}

private func historyRow(_ id: String, _ role: String, _ text: String, messageID: String? = nil) -> JSONValue {
    ["id": .string(id), "message": ["id": .string(messageID ?? id), "role": .string(role),
        "parts": [["type": "text", "text": .string(text)]]]]
}

@MainActor private struct ChatFixture {
    let transport = ControlledChatTransport()
    let store: LocalStore
    let backend: AlmaChatBackend
    init() throws {
        store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        backend = AlmaChatBackend(store: store, transport: transport)
    }
    func start(_ history: JSONValue = [], busy: Bool = false) async throws {
        let task = Task { await backend.newSession() }
        try await eventually { transport.sockets.count == 1 }
        transport.sockets[0].snapshot(busy: busy)
        try await eventually { transport.reads.count == 1 }
        transport.finish(0, history)
        await task.value
        #expect(backend.connected)
    }
    func reconnect(_ history: JSONValue = [], busy: Bool = false) async throws {
        let socketCount = transport.sockets.count
        let readCount = transport.reads.count
        let task = Task { await backend.restore() }
        try await eventually { transport.sockets.count == socketCount + 1 }
        transport.sockets.last!.snapshot(busy: busy)
        try await eventually { transport.reads.count == readCount + 1 }
        transport.finish(readCount, history)
        await task.value
        #expect(backend.connected)
    }
    func close() { transport.sockets.forEach { $0.cancel() } }
}

@MainActor struct NativeChatStateTests {
    @Test func failedInitialHistoryNeverConnects() async throws {
        let f = try ChatFixture()
        defer { f.close() }
        let task = Task { await f.backend.newSession() }
        try await eventually { f.transport.sockets.count == 1 }
        f.transport.sockets[0].snapshot()
        try await eventually { f.transport.reads.count == 1 }
        f.transport.fail(0)
        await task.value
        #expect(!f.backend.connected)
        #expect(!f.backend.canSend)
    }

    @Test func disconnectDuringInitialHistoryCannotResurrectConnection() async throws {
        let f = try ChatFixture()
        defer { f.close() }
        let task = Task { await f.backend.newSession() }
        try await eventually { f.transport.sockets.count == 1 }
        f.transport.sockets[0].snapshot()
        try await eventually { f.transport.reads.count == 1 }
        f.transport.sockets[0].cancel()
        try await eventually { f.backend.status.contains("无法连接") }
        f.transport.finish(0)
        try await eventually { f.transport.reads.count == 2 }
        f.transport.finish(1)
        await task.value
        #expect(!f.backend.connected)
        #expect(!f.backend.canSend)
    }

    @Test(arguments: [false, true])
    func reconnectReleasesWorkerAndIgnoresOldHistory(failOld: Bool) async throws {
        let f = try ChatFixture()
        defer { f.close() }
        try await f.start()
        f.transport.sockets[0].added()
        try await eventually { f.transport.reads.count == 2 }
        try await f.reconnect([historyRow("new", "assistant", "new history")])
        if failOld { f.transport.fail(1) }
        else { f.transport.finish(1, [historyRow("old", "assistant", "old history")]) }
        f.transport.sockets[1].added()
        try await eventually { f.transport.reads.count == 4 }
        #expect(f.backend.messages.map(\.text) == ["new history"])
        #expect(f.backend.connected)
        f.transport.finish(3, [historyRow("latest", "assistant", "latest history")])
        try await eventually { f.backend.messages.last?.text == "latest history" }
        #expect(f.backend.canSend)
    }

    @Test func refreshesAreSerializedAndOnlyStableHistoryIsApplied() async throws {
        let f = try ChatFixture()
        defer { f.close() }
        try await f.start()
        let ws = f.transport.sockets[0]
        ws.added()
        try await eventually { f.transport.reads.count == 2 }
        ws.added(); ws.delta("live")
        try await eventually { f.backend.streamingText == "live" }
        #expect(f.transport.reads.count == 2)
        #expect(f.transport.activeReads == 1)
        f.transport.finish(1, [historyRow("stale", "assistant", "stale")])
        try await eventually { f.transport.reads.count == 3 }
        #expect(f.backend.messages.isEmpty)
        #expect(f.backend.streamingText == "live")
        #expect(f.transport.activeReads == 1)
        f.transport.finish(2, [historyRow("fresh", "assistant", "live complete")])
        try await eventually { f.backend.messages.last?.text == "live complete" }
        #expect(f.backend.streamingText.isEmpty)
        #expect(f.backend.canSend)
    }

    @Test(arguments: [false, true])
    func busyHistoryNeitherLosesNorDuplicatesLiveText(deltaDuringRead: Bool) async throws {
        let f = try ChatFixture()
        defer { f.close() }
        try await f.start([historyRow("baseline", "user", "question")])
        let ws = f.transport.sockets[0]
        ws.busy(true); ws.delta("hello")
        try await eventually { f.backend.streamingText == "hello" }
        ws.added()
        try await eventually { f.transport.reads.count == 2 }
        if deltaDuringRead {
            ws.delta(" world")
            try await eventually { f.backend.streamingText == "hello world" }
        }
        let reply = deltaDuringRead ? "hello world" : "hello"
        f.transport.finish(1, [historyRow("baseline", "user", "question"), historyRow("reply", "assistant", reply)])
        ws.busy(false)
        try await eventually { f.transport.reads.count == 3 }
        // The real displayed output still contains exactly one copy, including late deltas.
        #expect(f.backend.messages.map(\.text) == ["question"])
        #expect(f.backend.streamingText == reply)
        #expect(!f.backend.canSend)
        f.transport.finish(2, [historyRow("baseline", "user", "question"), historyRow("reply", "assistant", reply)])
        try await eventually { f.backend.canSend }
        #expect(f.backend.messages.map(\.text) == ["question", reply])
        #expect(f.backend.streamingText.isEmpty)
    }

    @Test func idleDuringBusyReadRequiresAnotherReadBeforeClearingStream() async throws {
        let f = try ChatFixture()
        defer { f.close() }
        try await f.start()
        let ws = f.transport.sockets[0]
        ws.busy(true); ws.delta("complete"); ws.added()
        try await eventually { f.transport.reads.count == 2 }
        ws.busy(false)
        try await eventually { !f.backend.isBusy }
        f.transport.finish(1) // Snapshot taken before the final reply was persisted.
        try await eventually { f.transport.reads.count == 3 }
        #expect(f.backend.streamingText == "complete")
        #expect(!f.backend.canSend)
        f.transport.finish(2, [historyRow("reply", "assistant", "complete")])
        try await eventually { f.backend.canSend }
        #expect(f.backend.messages.map(\.text) == ["complete"])
        #expect(f.backend.streamingText.isEmpty)
    }

    @Test func uncertainSendStaysLockedAcrossReconnectAndBackendRecreation() async throws {
        let f = try ChatFixture()
        defer { f.close() }
        let baseline: JSONValue = [historyRow("old-user", "user", "repeat"), historyRow("baseline", "assistant", "old reply")]
        try await f.start(baseline)
        let ws = f.transport.sockets[0]
        ws.holdSend = true
        let send = Task { await f.backend.send("repeat") }
        try await eventually { ws.sent.count == 1 }
        ws.finishSend(fails: true)
        try await eventually { f.transport.reads.count == 2 }
        f.transport.finish(1, baseline)
        await send.value
        try await f.reconnect(baseline)
        #expect(!f.backend.canSend) // An identical user text BEFORE the baseline proves nothing.
        await f.backend.send("repeat")
        #expect(f.transport.sockets[1].sent.isEmpty)

        let restoredTransport = ControlledChatTransport()
        let restored = AlmaChatBackend(store: f.store, transport: restoredTransport)
        defer { restoredTransport.sockets.forEach { $0.cancel() } }
        let restore = Task { await restored.restore() }
        try await eventually { restoredTransport.sockets.count == 1 }
        restoredTransport.sockets[0].snapshot()
        try await eventually { restoredTransport.reads.count == 1 }
        restoredTransport.finish(0, baseline)
        await restore.value
        #expect(restored.connected && !restored.canSend)
        restoredTransport.sockets[0].added()
        try await eventually { restoredTransport.reads.count == 2 }
        restoredTransport.finish(1, .array(baseline.arrayValue! + [
            historyRow("rewritten-durable-user", "user", "repeat", messageID: "different-client-id")
        ]))
        try await eventually { restored.canSend }
        #expect(restored.messages.last?.id == "rewritten-durable-user")
        #expect(ws.sent.count == 1)
    }

    @Test(arguments: [false, true])
    func oldSendCompletionCannotMutateNewConnection(fails: Bool) async throws {
        let f = try ChatFixture()
        defer { f.close() }
        try await f.start()
        let old = f.transport.sockets[0]
        old.holdSend = true
        let send = Task { await f.backend.send("question") }
        try await eventually { old.sent.count == 1 }
        try await f.reconnect([historyRow("user", "user", "question")])
        let status = f.backend.status
        old.finishSend(fails: fails)
        await send.value
        #expect(f.backend.connected)
        #expect(f.backend.canSend)
        #expect(f.backend.status == status)
        #expect(f.transport.reads.count == 2)
        #expect(f.transport.sockets[1].sent.isEmpty)
    }

    @Test(arguments: [false, true])
    func oldStopCompletionCannotMutateNewConnection(fails: Bool) async throws {
        let f = try ChatFixture()
        defer { f.close() }
        try await f.start(busy: true)
        let old = f.transport.sockets[0]
        old.holdSend = true
        let stop = Task { await f.backend.stop() }
        try await eventually { old.sent.count == 1 }
        try await f.reconnect()
        let status = f.backend.status
        old.finishSend(fails: fails)
        await stop.value
        #expect(f.backend.connected && f.backend.canSend)
        #expect(f.backend.status == status)
        #expect(f.transport.reads.count == 2)
    }
}
