import Foundation
import Contracts
import LocalStore

/// Persists the request before writing. An uncertain result or a relaunch reuses that request,
/// so retrying a card cannot blindly create another event.
public actor MessageCalendarCreation {
    private static let key = "reminders.messages.calendarRequests"
    private let store: LocalStore
    private var inFlight: [String: Task<ExecutionResult, Never>] = [:]

    public init(store: LocalStore) { self.store = store }

    public func hasRequest(sourceID: String) -> Bool { requests[sourceID] != nil }

    private var requests: [String: ActionRequest] {
        store.codableSetting(Self.key, as: [String: ActionRequest].self) ?? [:]
    }

    public func submit(sourceID: String, draft: MessageCalendarDraft, now: Date = Date(),
                       using submit: @escaping @Sendable (ActionRequest) async -> ExecutionResult) async -> ExecutionResult {
        if let task = inFlight[sourceID] { return await task.value }
        var saved = requests
        let request: ActionRequest
        if let previous = saved[sourceID] { request = previous }
        else {
            guard draft.isValid(at: now) else {
                return .failure(UUID().uuidString, .invalidArguments, "日程信息无效或开始时间已过")
            }
            request = ActionRequest(tool: "calendar_create_event", arguments: draft.arguments,
                                    origin: .launcher, intent: .explicitRequest)
            saved[sourceID] = request
            store.setCodableSetting(Self.key, saved)
        }
        let task = Task { await submit(request) }
        inFlight[sourceID] = task
        let result = await task.value
        // Other sources may have finished while this request was running.
        if result.status != .completed && result.status != .pendingVerification {
            var updated = requests
            updated[sourceID] = nil
            store.setCodableSetting(Self.key, updated)
        }
        inFlight[sourceID] = nil
        return result
    }
}
