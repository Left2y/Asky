import AppKit
import Foundation

extension ToolService {
    /// Opens an unsaved event in Apple's Calendar import flow; never saves through EventKit.
    @MainActor
    public static func openCalendarDraft(title: String, start: Date, end: Date,
                                         location: String?, sourceID: String, notes: String) async throws {
        let content = try CalendarHandoff.content(title: title, start: start, end: end,
            location: location, sourceID: sourceID, notes: notes)
        guard let calendar = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else {
            throw CalendarHandoff.Failure.calendarUnavailable
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Asky-Calendar-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let file = directory.appendingPathComponent("Event.ics")
        try Data(content.utf8).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.open([file], withApplicationAt: calendar, configuration: configuration)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
        // Keep the file available while Calendar reads it; the OS manages temporary storage.
    }
}

enum CalendarHandoff {
    enum Failure: LocalizedError {
        case invalidEvent, calendarUnavailable
        var errorDescription: String? {
            switch self {
            case .invalidEvent: NSLocalizedString("日程信息无效，请重新检查。", comment: "")
            case .calendarUnavailable: NSLocalizedString("无法找到 macOS 日历应用。", comment: "")
            }
        }
    }

    static func content(title: String, start: Date, end: Date, location: String?,
                        sourceID: String, notes: String) throws -> String {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite, end > start else {
            throw Failure.invalidEvent
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        // Stable UID makes repeated handoffs of the same source identifiable by Calendar.
        let uid = Data(sourceID.utf8).base64EncodedString()
        let lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Asky//Calendar Handoff//EN",
            "CALSCALE:GREGORIAN", "BEGIN:VEVENT", "UID:\(uid)@asky.local",
            "DTSTAMP:\(formatter.string(from: Date()))", "DTSTART:\(formatter.string(from: start))",
            "DTEND:\(formatter.string(from: end))", "SUMMARY:\(escape(title))",
            "LOCATION:\(escape(location ?? ""))", "DESCRIPTION:\(escape(notes))",
            "END:VEVENT", "END:VCALENDAR"]
        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
    }

    private static func fold(_ line: String) -> String {
        var result = "", bytes = 0
        for character in line.unicodeScalars {
            let value = String(character)
            if bytes + value.utf8.count > 75 {
                result += "\r\n "
                bytes = 1
            }
            result += value
            bytes += value.utf8.count
        }
        return result
    }
}
