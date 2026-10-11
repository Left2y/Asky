import AppKit
import EventKit
import UserNotifications
import Contracts
import LocalStore
import Scheduler

/// Wires the Context Scheduler to EventKit change notifications, wake / time-zone changes and an hourly checkpoint,
/// and delivers plans as silent UserNotifications. Runs only while `proactiveReminders` is on.
@MainActor
final class ProactiveReminders: NSObject, UNUserNotificationCenterDelegate {
    static let category = "asky.reminder"
    private let app: AppModel
    private let scheduler: ContextScheduler
    private var observers: [NSObjectProtocol] = []
    private var checkpoint: Timer?
    private var pending: Task<Void, Never>?

    init(app: AppModel) {
        self.app = app
        scheduler = ContextScheduler(store: ReminderStore(app.store))
        super.init()
    }

    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([UNNotificationCategory(identifier: Self.category, actions: [
            UNNotificationAction(identifier: "evidence", title: "查看依据", options: [.foreground]),
            UNNotificationAction(identifier: "snooze", title: "稍后"),
            UNNotificationAction(identifier: "handled", title: "已处理"),
            UNNotificationAction(identifier: "disable", title: "关闭此类", options: [.destructive]),
        ], intentIdentifiers: [])])

        let nc = NotificationCenter.default, ws = NSWorkspace.shared.notificationCenter
        let trigger: @Sendable (Notification) -> Void = { [weak self] _ in Task { @MainActor in self?.schedule() } }
        observers = [
            nc.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main, using: trigger),
            nc.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main, using: trigger),
            ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: trigger),
        ]
        let t = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.schedule() } }
        t.tolerance = 300
        RunLoop.main.add(t, forMode: .common)
        checkpoint = t
        schedule()
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []
        checkpoint?.invalidate()
        checkpoint = nil
        pending?.cancel()
    }

    /// Debounced: bursts of EventKit changes collapse into one reconcile.
    func schedule() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.reconcile()
        }
    }

    private func reconcile() async {
        let s = app.settings
        let center = UNUserNotificationCenter.current()
        guard s.proactiveReminders, s.enabledSources.contains(.calendar), app.native.eventKit.calendarAuthorized else {
            // Turning the feature off withdraws everything pending.
            let ids = ReminderStore(app.store).plans(status: [.scheduled, .snoozed]).filter { !$0.userRequested }.map(\.id)
            center.removePendingNotificationRequests(withIdentifiers: ids)
            return
        }
        guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
        let now = Date()
        let ek = app.native.eventKit.store
        let pred = ek.predicateForEvents(withStart: now, end: now.addingTimeInterval(7 * 24 * 3600), calendars: nil)
        let events = ek.events(matching: pred).filter { $0.availability != .free }.map {
            EventSnapshot(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "", start: $0.startDate,
                          end: $0.endDate, location: $0.location, isAllDay: $0.isAllDay)
        }
        guard let outcome = try? scheduler.reconcile(events: events, travelEnabled: s.enabledSources.contains(.maps), now: now) else { return }
        center.removePendingNotificationRequests(withIdentifiers: outcome.cancel)
        for plan in outcome.schedule { await deliver(plan) }
    }

    private func deliver(_ plan: ReminderPlan) async {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = nil
        content.categoryIdentifier = Self.category
        content.userInfo = ["planID": plan.id, "evidence": plan.evidence]
        let interval = max(1, plan.fireDate.timeIntervalSinceNow)
        let req = UNNotificationRequest(identifier: plan.id, content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
        try? await UNUserNotificationCenter.current().add(req)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        let id = notification.request.identifier
        await MainActor.run { try? scheduler.markDelivered(id) }
        return [.banner, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let id = response.notification.request.identifier
        let action = response.actionIdentifier
        let evidence = response.notification.request.content.userInfo["evidence"] as? [String] ?? []
        let title = response.notification.request.content.title
        await MainActor.run { handle(action: action, planID: id, title: title, evidence: evidence) }
    }

    private func handle(action: String, planID: String, title: String, evidence: [String]) {
        switch action {
        case "snooze":
            if let when = try? scheduler.snooze(planID), let plan = ReminderStore(app.store).plans(status: [.snoozed]).first(where: { $0.id == planID }) {
                var p = plan
                p.fireDate = when
                Task { await deliver(p) }
            }
        case "handled":
            try? scheduler.markHandled(planID)
        case "disable":
            if let plan = ReminderStore(app.store).plans(status: [.scheduled, .snoozed, .delivered]).first(where: { $0.id == planID }),
               let ids = try? scheduler.disableCategory(plan.reason) {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
            }
        default:
            try? scheduler.markDelivered(planID)
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = evidence.isEmpty ? "无记录的依据。" : evidence.map { "• \($0)" }.joined(separator: "\n")
            NSApp.activate()
            alert.runModal()
        }
    }
}
