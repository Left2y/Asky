import Testing
import Foundation
import Contracts
import SQLite3
@testable import ToolService

struct MessagesHistoryTests {
    /// typedstream payload shaped like Messages' attributedBody: class name, `+`, length, UTF-8 bytes.
    private func body(_ text: String) -> Data {
        let utf8 = Array(text.utf8)
        var d = Data([0x04, 0x0B]) + Data("streamtyped".utf8) + Data([0x81, 0xE8, 0x03, 0x84, 0x01, 0x40, 0x84, 0x84, 0x84])
        d += Data([0x12]) + Data("NSAttributedString".utf8) + Data([0x00, 0x84, 0x84, 0x08]) + Data("NSObject".utf8)
        d += Data([0x00, 0x85, 0x92, 0x84, 0x84, 0x84, 0x08]) + Data("NSString".utf8) + Data([0x01, 0x94, 0x84, 0x01, 0x2B])
        if utf8.count < 0x80 { d.append(UInt8(utf8.count)) }
        else { d += Data([0x81, UInt8(utf8.count & 0xFF), UInt8(utf8.count >> 8)]) }
        return d + Data(utf8) + Data([0x86, 0x84])
    }

    @Test func decodesShortAndLongAttributedBodies() {
        #expect(MessagesHistoryReader.decodeAttributedBody(body("明天下午三点见")) == "明天下午三点见")
        let long = String(repeating: "合同", count: 100)
        #expect(MessagesHistoryReader.decodeAttributedBody(body(long)) == long)
        #expect(MessagesHistoryReader.decodeAttributedBody(Data("garbage".utf8)) == nil)
    }

    @Test func dropsVerificationCodesAndMasksLongNumbers() {
        #expect(MessagesHistoryReader.sanitize("【某银行】您的验证码是 482913，5 分钟内有效", maxLength: 300) == nil)
        #expect(MessagesHistoryReader.sanitize("Your verification code is 1234", maxLength: 300) == nil)
        #expect(MessagesHistoryReader.sanitize("尾号卡 6222020200112233 本月账单 1,203 元，10 月 20 日到期", maxLength: 300)
                == "尾号卡 ••••2233 本月账单 1,203 元，10 月 20 日到期")
        #expect(MessagesHistoryReader.sanitize("\u{FFFC} ", maxLength: 300) == nil)
        #expect(MessagesHistoryReader.mask("+8613812345678") == CoreLocalization.format("尾号%@", "5678"))
        #expect(MessagesHistoryReader.normalize("+86 138-1234-5678") == MessagesHistoryReader.normalize("13812345678"))
    }

    @Test func readsRecentMessagesReadOnlyWithNamesAndGroups() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "chat-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: url) }
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        let offset = MessagesHistoryReader.referenceOffset
        let ns = { (d: Date) in Int64((d.timeIntervalSince1970 - offset) * 1_000_000_000) }
        let now = Date()
        let sql = """
            CREATE TABLE message (ROWID INTEGER PRIMARY KEY, text TEXT, attributedBody BLOB, handle_id INTEGER, date INTEGER,
                is_from_me INTEGER, associated_message_type INTEGER DEFAULT 0, item_type INTEGER DEFAULT 0);
            CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
            CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, display_name TEXT, style INTEGER);
            CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
            INSERT INTO handle VALUES (1, '+8613812345678'), (2, 'friend@example.com');
            INSERT INTO chat VALUES (1, '', 45), (2, '周末徒步', 43);
            INSERT INTO message (ROWID, text, handle_id, date, is_from_me) VALUES
                (1, '周五前把合同发我', 1, \(ns(now.addingTimeInterval(-3600))), 0),
                (2, '你的验证码是 123456', 1, \(ns(now.addingTimeInterval(-1800))), 0),
                (3, '太久以前', 1, \(ns(now.addingTimeInterval(-30 * 86400))), 0),
                (5, '周六 8 点集合', 2, \(ns(now.addingTimeInterval(-600))), 0);
            INSERT INTO message (ROWID, text, handle_id, date, is_from_me, associated_message_type) VALUES
                (6, 'Loved “周六 8 点集合”', 2, \(ns(now.addingTimeInterval(-300))), 1, 2000);
            INSERT INTO chat_message_join VALUES (1, 1), (1, 2), (1, 3), (2, 5), (2, 6), (1, 4);
            """
        #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
        var st: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO message (ROWID, text, attributedBody, handle_id, date, is_from_me) VALUES (4, NULL, ?, 1, ?, 1)", -1, &st, nil)
        let blob = body("好的，明天发")
        _ = blob.withUnsafeBytes { sqlite3_bind_blob(st, 1, $0.baseAddress, Int32(blob.count), nil) }
        sqlite3_bind_int64(st, 2, ns(now.addingTimeInterval(-1200)))
        #expect(sqlite3_step(st) == SQLITE_DONE)
        sqlite3_finalize(st)
        sqlite3_close(db)

        let reader = MessagesHistoryReader(url: url)
        #expect(reader.isReadable)
        let items = try reader.recent(since: now.addingTimeInterval(-3 * 86400)) {
            MessagesHistoryReader.normalize($0) == "13812345678" ? "王磊" : nil
        }
        #expect(items.map(\.text) == ["周六 8 点集合", "好的，明天发", "周五前把合同发我"])
        #expect(items[0].sender == "f…@example.com" && items[0].group == "周末徒步")
        #expect(items[1].isFromMe && items[2].sender == "王磊" && items[2].group == nil)
        #expect(abs(items[2].date.timeIntervalSince(now.addingTimeInterval(-3600))) < 1)
        #expect(!MessagesHistoryReader(url: url.appending(path: "missing")).isReadable)
    }
}
