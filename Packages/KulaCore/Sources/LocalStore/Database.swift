import Foundation
import SQLite3

public struct SQLiteError: Error, CustomStringConvertible {
    public let code: Int32
    public let message: String
    public var description: String { "SQLite(\(code)): \(message)" }
}

public enum SQLValue: Sendable, Equatable {
    case null
    case int(Int64)
    case double(Double)
    case text(String)
    case blob(Data)
}

public protocol SQLBindable { var sqlValue: SQLValue { get } }
extension String: SQLBindable { public var sqlValue: SQLValue { .text(self) } }
extension Int: SQLBindable { public var sqlValue: SQLValue { .int(Int64(self)) } }
extension Int64: SQLBindable { public var sqlValue: SQLValue { .int(self) } }
extension Double: SQLBindable { public var sqlValue: SQLValue { .double(self) } }
extension Bool: SQLBindable { public var sqlValue: SQLValue { .int(self ? 1 : 0) } }
extension Date: SQLBindable { public var sqlValue: SQLValue { .double(timeIntervalSince1970) } }
extension Data: SQLBindable { public var sqlValue: SQLValue { .blob(self) } }
extension Optional: SQLBindable where Wrapped: SQLBindable {
    public var sqlValue: SQLValue { self?.sqlValue ?? .null }
}

public struct Row: Sendable {
    let values: [String: SQLValue]
    public func string(_ c: String) -> String? { if case .text(let s) = values[c] { return s }; return nil }
    public func int(_ c: String) -> Int? {
        switch values[c] {
        case .int(let i): Int(i)
        case .double(let d): Int(d)
        default: nil
        }
    }
    public func double(_ c: String) -> Double? {
        switch values[c] {
        case .double(let d): d
        case .int(let i): Double(i)
        default: nil
        }
    }
    public func bool(_ c: String) -> Bool { int(c) == 1 }
    public func date(_ c: String) -> Date? { double(c).map(Date.init(timeIntervalSince1970:)) }
    public func data(_ c: String) -> Data? { if case .blob(let d) = values[c] { return d }; return nil }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Thin, thread-safe SQLite wrapper. Statements are finalized after each call (no long-lived cursors);
/// queries are always bounded by the caller with LIMIT.
public final class Database: @unchecked Sendable {
    private var handle: OpaquePointer?
    private let lock = NSRecursiveLock()
    private var txDepth = 0
    public let path: String

    public init(path: String) throws {
        self.path = path
        if path != ":memory:" {
            try FileManager.default.createDirectory(at: URL(fileURLWithPath: path).deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
        }
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            sqlite3_close(handle)
            throw SQLiteError(code: -1, message: msg)
        }
        try execute("PRAGMA foreign_keys = ON")
        if path != ":memory:" { try execute("PRAGMA journal_mode = WAL") }
        try execute("PRAGMA cache_size = -2048") // ~2 MiB page cache per connection; tune after measurement
    }

    deinit { sqlite3_close_v2(handle) }

    private func error(_ code: Int32) -> SQLiteError {
        SQLiteError(code: code, message: String(cString: sqlite3_errmsg(handle)))
    }

    public func execute(_ sql: String) throws {
        lock.lock(); defer { lock.unlock() }
        let rc = sqlite3_exec(handle, sql, nil, nil, nil)
        guard rc == SQLITE_OK else { throw error(rc) }
    }

    @discardableResult
    public func run(_ sql: String, _ args: [SQLBindable?] = []) throws -> Int {
        lock.lock(); defer { lock.unlock() }
        let stmt = try prepare(sql, args)
        defer { sqlite3_finalize(stmt) }
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE || rc == SQLITE_ROW else { throw error(rc) }
        return Int(sqlite3_changes(handle))
    }

    public func query(_ sql: String, _ args: [SQLBindable?] = []) throws -> [Row] {
        lock.lock(); defer { lock.unlock() }
        let stmt = try prepare(sql, args)
        defer { sqlite3_finalize(stmt) }
        var rows: [Row] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw error(rc) }
            var values: [String: SQLValue] = [:]
            for i in 0..<sqlite3_column_count(stmt) {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER: values[name] = .int(sqlite3_column_int64(stmt, i))
                case SQLITE_FLOAT: values[name] = .double(sqlite3_column_double(stmt, i))
                case SQLITE_TEXT: values[name] = .text(String(cString: sqlite3_column_text(stmt, i)))
                case SQLITE_BLOB:
                    let n = Int(sqlite3_column_bytes(stmt, i))
                    values[name] = .blob(n > 0 ? Data(bytes: sqlite3_column_blob(stmt, i), count: n) : Data())
                default: values[name] = .null
                }
            }
            rows.append(Row(values: values))
        }
        return rows
    }

    public func scalarInt(_ sql: String, _ args: [SQLBindable?] = []) throws -> Int {
        try query(sql, args).first.flatMap { r in r.values.values.first }.flatMap { v -> Int? in
            if case .int(let i) = v { return Int(i) }
            return nil
        } ?? 0
    }

    /// Nestable: the outermost call uses BEGIN IMMEDIATE, inner calls use savepoints.
    public func transaction<T>(_ body: () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        let depth = txDepth
        let sp = "sp\(depth)"
        try execute(depth == 0 ? "BEGIN IMMEDIATE" : "SAVEPOINT \(sp)")
        txDepth += 1
        defer { txDepth -= 1 }
        do {
            let r = try body()
            try execute(depth == 0 ? "COMMIT" : "RELEASE \(sp)")
            return r
        } catch {
            if depth == 0 {
                try? execute("ROLLBACK")
            } else {
                try? execute("ROLLBACK TO \(sp)")
                try? execute("RELEASE \(sp)")
            }
            throw error
        }
    }

    private func prepare(_ sql: String, _ args: [SQLBindable?]) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(handle, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK else { throw error(rc) }
        for (i, a) in args.enumerated() {
            let idx = Int32(i + 1)
            switch a?.sqlValue ?? .null {
            case .null: sqlite3_bind_null(stmt, idx)
            case .int(let v): sqlite3_bind_int64(stmt, idx, v)
            case .double(let v): sqlite3_bind_double(stmt, idx, v)
            case .text(let v): sqlite3_bind_text(stmt, idx, v, -1, SQLITE_TRANSIENT)
            case .blob(let v): _ = v.withUnsafeBytes { sqlite3_bind_blob(stmt, idx, $0.baseAddress, Int32(v.count), SQLITE_TRANSIENT) }
            }
        }
        return stmt
    }
}
