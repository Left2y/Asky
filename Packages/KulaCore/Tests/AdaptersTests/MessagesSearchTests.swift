import Testing
import Foundation
import SQLite3
import Contracts
import LocalStore
import ToolService
@testable import Adapters

@Suite struct MessagesSearchTests {
    private let now = Date(timeIntervalSince1970: 1_791_800_000)

    private func fixture(_ url: URL) throws {
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        let date = Int64(now.timeIntervalSince1970 - 978_307_200)
        let sql = """
        CREATE TABLE message (ROWID INTEGER PRIMARY KEY, text TEXT, attributedBody BLOB, handle_id INTEGER, date INTEGER,
            is_from_me INTEGER, associated_message_type INTEGER DEFAULT 0, item_type INTEGER DEFAULT 0);
        CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
        CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, display_name TEXT, style INTEGER);
        CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
        INSERT INTO handle VALUES (1, '+8613812345678');
        INSERT INTO chat VALUES (1, '', 45);
        INSERT INTO message (ROWID,text,handle_id,date,is_from_me) VALUES
          (1,'观鹤报名地点：杭州西溪，订单 123456789012',1,\((date-3600)*1_000_000_000),0),
          (2,'观鹤验证码 123456',1,\((date-1800)*1_000_000_000),0),
          (3,'观鹤旧地点',1,\((date-31*86400)*1_000_000_000),0),
          (4,'好的，观鹤我会去',1,\(date-600),1);
        INSERT INTO chat_message_join VALUES (1,1),(1,2),(1,3),(1,4);
        """
        #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
        // Hundreds of newer unrelated messages must not hide a keyword match.
        for i in 5...400 {
            #expect(sqlite3_exec(db, "INSERT INTO message (ROWID,text,date,is_from_me) VALUES (\(i),'无关消息',\((date-100)*1_000_000_000),0)", nil, nil, nil) == SQLITE_OK)
        }
        let body = Data("NSString".utf8) + Data([1, 0x2B, 6]) + Data("报名".utf8)
        var st: OpaquePointer?
        #expect(sqlite3_prepare_v2(db, "INSERT INTO message (ROWID,attributedBody,date,is_from_me) VALUES (401,?, ?,0)", -1, &st, nil) == SQLITE_OK)
        defer { sqlite3_finalize(st) }
        _ = body.withUnsafeBytes { sqlite3_bind_blob(st, 1, $0.baseAddress, Int32(body.count), nil) }
        sqlite3_bind_int64(st, 2, (date-1200)*1_000_000_000)
        #expect(sqlite3_step(st) == SQLITE_DONE)
    }

    @Test func searchesThroughServiceWithRedactionAndBounds() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "messages-search-\(UUID()).db")
        defer { try? FileManager.default.removeItem(at: url) }
        try fixture(url)
        let tool = MessagesSearchTool(reader: .init(url: url), enabled: { true }, now: { now })
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let svc = ToolService(store: store, policy: { PolicySnapshot(enabledSources: [.messages]) }, presenter: { _ in .rejected })
        await svc.register(tool)
        let result = await svc.submit(ActionRequest(tool: "messages_search", arguments: ["query": "观鹤"], origin: .agent(sessionID: "c"), intent: .explicitRequest))
        #expect(result.status == .completed)
        let items = try #require(result.output?["messages"]?.arrayValue)
        #expect(items.count == 2)
        #expect(items[0]["isFromMe"] == true)
        #expect(items[1]["text"]?.stringValue == "观鹤报名地点：杭州西溪，订单 ••••9012")
        #expect(items[1]["sender"]?.stringValue == CoreLocalization.format("尾号%@", "5678"))
        let limited = try await tool.execute(["query": "观鹤", "limit": 1])
        #expect(limited.output["hasMore"] == true)
        let decoded = try await tool.execute(["query": "报名"])
        #expect(decoded.output["messages"]?.arrayValue?.count == 2)
        let empty = try await tool.execute(["query": "没有这个关键词"])
        #expect(empty.output["messages"]?.arrayValue?.isEmpty == true)
        let external = await svc.submit(ActionRequest(tool: "messages_search", arguments: ["query": "观鹤"], origin: .mcp(instanceID: "test"), intent: .explicitRequest))
        #expect(external.error?.code == .notExposed)
    }

    @Test func reportsScanCapAndKeepsKeywordInLongExcerpt() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "messages-cap-\(UUID()).db")
        defer { try? FileManager.default.removeItem(at: url) }
        try fixture(url)
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        let date = Int64(now.timeIntervalSince1970 - 978_307_200)
        let text = String(repeating: "长正文", count: 1000) + "观鹤地址：西溪"
        #expect(sqlite3_exec(db, "INSERT INTO message (ROWID,text,date,is_from_me) VALUES (501,'\(text)',\((date-50)*1_000_000_000),0)", nil, nil, nil) == SQLITE_OK)
        var reader = MessagesHistoryReader(url: url)
        reader.maxTextLength = 100
        let excerpt = try reader.search(query: "观鹤地址", since: now.addingTimeInterval(-30*86400), until: now)
        #expect(excerpt.messages.first?.text.contains("观鹤地址：西溪") == true)
        #expect(excerpt.messages.first!.text.count <= 101)
        #expect(sqlite3_exec(db, "WITH RECURSIVE rows(n) AS (SELECT 1000 UNION ALL SELECT n+1 FROM rows WHERE n<11000) INSERT INTO message (ROWID,text,date,is_from_me) SELECT n,'无关',\((date-20)*1_000_000_000),0 FROM rows", nil, nil, nil) == SQLITE_OK)
        let capped = try reader.search(query: "观鹤", since: now.addingTimeInterval(-30*86400), until: now)
        #expect(capped.messages.isEmpty && capped.scanLimitReached)
    }

    @Test func revokingDuringSearchWithholdsResults() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "messages-revoke-\(UUID()).db")
        defer { try? FileManager.default.removeItem(at: url) }
        try fixture(url)
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        store.setSetting("messages-test-enabled", "yes")
        let tool = MessagesSearchTool(reader: .init(url: url), enabled: { store.setting("messages-test-enabled") == "yes" },
                                      now: { now }, names: { store.setSetting("messages-test-enabled", "no"); return [:] })
        do { _ = try await tool.execute(["query": "观鹤"]); Issue.record("Must withhold revoked results") }
        catch let e as ToolError { #expect(e.code == .sourceDisabled) }
    }

    @Test func respectsChosenLookbackWindow() async throws {
        let missing = MessagesHistoryReader(url: URL(filePath: "/tmp/nonexistent-\(UUID()).db"))
        let tenDaysAgo = JSONValue.string(ISO8601DateFormatter().string(from: now.addingTimeInterval(-10 * 86400)))
        let narrow = MessagesSearchTool(reader: missing, enabled: { true }, days: { 3 }, now: { now })
        do { _ = try await narrow.execute(["query": "报名", "from": tenDaysAgo]); Issue.record("Should reject range beyond 3 days") }
        catch let e as ToolError { #expect(e.code == .invalidArguments) }
        let wide = MessagesSearchTool(reader: missing, enabled: { true }, days: { 30 }, now: { now })
        do { _ = try await wide.execute(["query": "报名", "from": tenDaysAgo]); Issue.record("Should fail reading") }
        catch let e as ToolError { #expect(e.code == .permissionDenied) }
    }

    @Test func failsClearlyWhenDisabledUnreadableOrInvalid() async throws {
        let missing = MessagesHistoryReader(url: URL(filePath: "/tmp/nonexistent-\(UUID()).db"))
        let off = MessagesSearchTool(reader: missing, enabled: { false }, now: { now })
        await #expect(throws: ToolError.self) { try await off.execute(["query": "报名"]) }
        let on = MessagesSearchTool(reader: missing, enabled: { true }, now: { now })
        do { _ = try await on.execute(["query": "报名"]); Issue.record("Should fail") }
        catch let e as ToolError { #expect(e.code == .permissionDenied) }
        for args: JSONValue in [["query": " "], ["query": "报名", "from": "2000-01-01"],
                               ["query": "报名", "limit": 0], ["query": "报名", "to": "bad-date"]] {
            do { _ = try await on.execute(args); Issue.record("Should reject invalid query") }
            catch let e as ToolError { #expect(e.code == .invalidArguments) }
        }
    }
}
