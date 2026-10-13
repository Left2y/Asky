import Foundation

/// Separate switches per source: read, AI use, extraction and background reminders.
public struct SourcePermissions: OptionSet, Sendable, Hashable, Codable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let read = SourcePermissions(rawValue: 1 << 0)
    public static let aiUse = SourcePermissions(rawValue: 1 << 1)
    public static let extraction = SourcePermissions(rawValue: 1 << 2)
    public static let backgroundReminders = SourcePermissions(rawValue: 1 << 3)
    public static let none: SourcePermissions = []
}

public enum ReminderReason: String, Sendable, Codable, CaseIterable {
    case conflict, travel, importantDate
    /// Model-judged suggestion that connects events, tasks and memories; only produced when background AI is on.
    case insight
}

public enum ReminderPlanStatus: String, Sendable, Codable {
    case scheduled, snoozed, delivered, handled, cancelled
}

public struct ReminderPlan: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var eventID: String
    public var reason: ReminderReason
    public var title: String
    public var body: String
    public var evidence: [String]
    public var fireDate: Date
    public var status: ReminderPlanStatus
    /// Fingerprint of the event when planned (start/end/location); mismatch cancels the plan.
    public var eventFingerprint: String
    /// User-set explicit reminders are not counted against the daily suggestion cap.
    public var userRequested: Bool

    public var dedupeKey: String { "\(eventID)|\(reason.rawValue)" }

    public init(id: String = UUID().uuidString, eventID: String, reason: ReminderReason, title: String, body: String,
                evidence: [String], fireDate: Date, status: ReminderPlanStatus = .scheduled,
                eventFingerprint: String, userRequested: Bool = false) {
        self.id = id
        self.eventID = eventID
        self.reason = reason
        self.title = title
        self.body = body
        self.evidence = evidence
        self.fireDate = fireDate
        self.status = status
        self.eventFingerprint = eventFingerprint
        self.userRequested = userRequested
    }
}
