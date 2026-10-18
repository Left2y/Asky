import Foundation
import SQLite3
import Contracts

/// Reads recent Messages history (SMS and iMessage) from the local Messages database, read-only.
/// macOS offers no API for this; the database is readable only after the user grants Full Disk Access.
/// Nothing is written, and verification-code messages and long numbers are removed before anything leaves this type.
public struct MessagesHistoryReader: Sendable {
    public static let defaultURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Messages/chat.db")
    /// Apple stores message dates relative to 2001-01-01.
    static let referenceOffset: TimeInterval = 978_307_200

    public var url: URL
    public var maxTextLength = 300

    public init(url: URL = Self.defaultURL) { self.url = url }

    /// True only when the database can actually be opened and queried, which is how Full Disk Access shows up.
    public var isReadable: Bool {
        guard let db = open() else { return false }
        defer { sqlite3_close(db) }
        var st: OpaquePointer?
        defer { sqlite3_finalize(st) }
        return sqlite3_prepare_v2(db, "SELECT 1 FROM message LIMIT 1", -1, &st, nil) == SQLITE_OK && sqlite3_step(st) != SQLITE_ERROR
    }

    /// Most recent first. `name` maps a raw handle (phone or email) to a contact name.
    public func recent(since: Date, limit: Int = 40, name: (String) -> String? = { _ in nil }) throws -> [MessageSnapshot] {
        try read(since: since, until: .distantFuture, query: nil, limit: limit, scanLimit: limit * 2, name: name).messages
    }

    public struct SearchResult: Sendable {
        public var messages: [MessageSnapshot]
        public var hasMore: Bool
        public var scanLimitReached: Bool
    }

    /// Searches decoded and redacted text before truncation, including attributedBody-only messages.
    public func search(query: String, since: Date, until: Date, limit: Int = 20,
                       name: (String) -> String? = { _ in nil }) throws -> SearchResult {
        try read(since: since, until: until, query: query, limit: limit, scanLimit: 10_000, name: name)
    }

    private func read(since: Date, until: Date, query: String?, limit: Int, scanLimit: Int,
                      name: (String) -> String?) throws -> SearchResult {
        guard let db = open() else {
            throw ToolError(.permissionDenied, CoreLocalization.text("无法读取信息数据库。请在系统设置 › 隐私与安全性 › 完全磁盘访问权限中允许 Asky。"))
        }
        defer { sqlite3_close(db) }
        // Reactions, edits and system items carry no text of their own.
        let sql = """
            SELECT m.ROWID, m.text, m.attributedBody, m.is_from_me, m.date, h.id, c.display_name, c.style, c.ROWID, h.ROWID
            FROM message m
            LEFT JOIN handle h ON h.ROWID = m.handle_id
            LEFT JOIN chat_message_join j ON j.message_id = m.ROWID
            LEFT JOIN chat c ON c.ROWID = j.chat_id
            WHERE (CASE WHEN m.date > 10000000000 THEN m.date / 1000000000.0 ELSE m.date END) >= ?
              AND (CASE WHEN m.date > 10000000000 THEN m.date / 1000000000.0 ELSE m.date END) < ?
              AND m.associated_message_type = 0 AND m.item_type = 0
            GROUP BY m.ROWID
            ORDER BY (CASE WHEN m.date > 10000000000 THEN m.date / 1000000000.0 ELSE m.date END) DESC, m.ROWID DESC
            LIMIT ?
            """
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else {
            throw ToolError(.adapterFailure, CoreLocalization.format("信息数据库格式无法识别：%@", String(describing: String(cString: sqlite3_errmsg(db)))))
        }
        defer { sqlite3_finalize(st) }
        sqlite3_bind_double(st, 1, since.timeIntervalSince1970 - Self.referenceOffset)
        sqlite3_bind_double(st, 2, until.timeIntervalSince1970 - Self.referenceOffset)
        sqlite3_bind_int(st, 3, Int32(scanLimit + 1))

        var out: [MessageSnapshot] = []
        var scanned = 0
        var step = sqlite3_step(st)
        while step == SQLITE_ROW {
            if scanned == scanLimit { return SearchResult(messages: out, hasMore: false, scanLimitReached: true) }
            scanned += 1
            defer { step = sqlite3_step(st) }
            var body = sqlite3_column_text(st, 1).map { String(cString: $0) } ?? ""
            if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let blob = sqlite3_column_blob(st, 2) {
                body = Self.decodeAttributedBody(Data(bytes: blob, count: Int(sqlite3_column_bytes(st, 2)))) ?? ""
            }
            guard let clean = Self.sanitize(body, maxLength: body.count) else { continue }
            if let query, !clean.localizedStandardContains(query) { continue }
            if out.count == limit { return SearchResult(messages: out, hasMore: true, scanLimitReached: false) }
            let text: String
            if let query, let match = clean.localizedStandardRange(of: query),
               clean.distance(from: clean.startIndex, to: match.lowerBound) >= maxTextLength {
                let start = clean.index(match.lowerBound, offsetBy: -maxTextLength / 2, limitedBy: clean.startIndex) ?? clean.startIndex
                text = "…" + String(clean[start...].prefix(maxTextLength))
            } else {
                text = String(clean.prefix(maxTextLength))
            }
            let handle = sqlite3_column_text(st, 5).map { String(cString: $0) } ?? ""
            let groupName = sqlite3_column_text(st, 6).map { String(cString: $0) } ?? ""
            let isGroup = sqlite3_column_int(st, 7) == 43
            out.append(MessageSnapshot(
                id: String(sqlite3_column_int64(st, 0)),
                conversation: sqlite3_column_type(st, 8) == SQLITE_NULL ? "h:\(sqlite3_column_int64(st, 9))" : "c:\(sqlite3_column_int64(st, 8))",
                sender: name(handle) ?? Self.mask(handle),
                isFromMe: sqlite3_column_int(st, 3) != 0,
                group: isGroup ? (groupName.isEmpty ? CoreLocalization.text("群聊") : groupName) : nil,
                date: Self.date(fromRaw: sqlite3_column_int64(st, 4)),
                text: text))
        }
        guard step == SQLITE_DONE else {
            throw ToolError(.adapterFailure, CoreLocalization.format("信息数据库查询失败：%@", String(describing: String(cString: sqlite3_errmsg(db)))))
        }
        return SearchResult(messages: out, hasMore: false, scanLimitReached: false)
    }

    private func open() -> OpaquePointer? {
        var db: OpaquePointer?
        let uri = "file:\(url.path(percentEncoded: true))?mode=ro"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        sqlite3_busy_timeout(db, 500)
        return db
    }

    // MARK: Decoding and redaction

    /// Older databases stored seconds; current ones store nanoseconds.
    static func date(fromRaw raw: Int64) -> Date {
        let seconds = raw > 10_000_000_000 ? TimeInterval(raw) / 1_000_000_000 : TimeInterval(raw)
        return Date(timeIntervalSince1970: seconds + referenceOffset)
    }

    /// `attributedBody` is an NSAttributedString in the legacy typedstream format. The first NSString payload is
    /// the message text: after the class name comes a `+` marker and a length (one byte, or 0x81 + UInt16 LE,
    /// or 0x82 + UInt32 LE). Parsed by hand so no archived objects from another party are ever instantiated.
    static func decodeAttributedBody(_ data: Data) -> String? {
        let bytes = [UInt8](data)
        let marker = Array("NSString".utf8)
        guard let start = bytes.firstRange(of: marker)?.upperBound,
              let plus = bytes[start..<min(bytes.count, start + 16)].firstIndex(of: 0x2B) else { return nil }
        var i = plus + 1
        func read(_ n: Int) -> Int? {
            guard i + n <= bytes.count else { return nil }
            defer { i += n }
            return bytes[i..<i + n].enumerated().reduce(0) { $0 | Int($1.element) << (8 * $1.offset) }
        }
        guard let first = read(1) else { return nil }
        let length: Int? = switch first {
        case 0x81: read(2)
        case 0x82: read(4)
        default: first
        }
        guard let length, length > 0, i + length <= bytes.count else { return nil }
        return String(bytes: bytes[i..<i + length], encoding: .utf8)
    }

    private static let codePattern = try! NSRegularExpression(
        pattern: "验证码|校验码|动态码|动态密码|确认码|安全码|verification code|security code|one-time|passcode|\\bOTP\\b|\\bcode\\b.{0,12}\\d{4,8}",
        options: [.caseInsensitive])
    private static let longNumber = try! NSRegularExpression(pattern: "\\d{8,}")

    /// Drops verification-code messages entirely and masks long numbers (cards, accounts, IDs) to their last 4 digits.
    static func sanitize(_ raw: String, maxLength: Int) -> String? {
        let text = raw.replacingOccurrences(of: "\u{FFFC}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let ns = text as NSString
        if codePattern.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil { return nil }
        var masked = text
        for m in longNumber.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let digits = ns.substring(with: m.range)
            masked = (masked as NSString).replacingCharacters(in: m.range, with: "••••" + digits.suffix(4))
        }
        return String(masked.prefix(maxLength))
    }

    /// Phone numbers keep only their last 4 digits; emails keep the first letter and domain.
    static func mask(_ handle: String) -> String {
        if handle.isEmpty { return CoreLocalization.text("未知联系人") }
        if let at = handle.firstIndex(of: "@") { return "\(handle.prefix(1))…\(handle[at...])" }
        let digits = handle.filter(\.isNumber)
        return digits.count > 4 ? CoreLocalization.format("尾号%@", String(describing: digits.suffix(4))) : handle
    }

    /// Key used to match a Messages handle against contact phone numbers and emails.
    public static func normalize(_ handle: String) -> String {
        if handle.contains("@") { return handle.lowercased() }
        let digits = handle.filter(\.isNumber)
        return String(digits.suffix(11))
    }
}
