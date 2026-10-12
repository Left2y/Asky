import AppKit
import EventKit
import UserNotifications
import Contracts
import LocalStore
import Memory
import Scheduler
import ToolService

/// Wires the Context Scheduler to EventKit change notifications, wake / time-zone changes and an hourly checkpoint,
/// and delivers plans as silent UserNotifications. Runs only while `proactiveReminders` is on.
/// With background AI on, the configured model also looks across events, open tasks and memories for things
/// worth preparing, and, when separately allowed, recent SMS/iMessage; its suggestions go through the same
/// dedupe, daily cap and quiet-hours rules.
@MainActor
final class ProactiveReminders: NSObject, UNUserNotificationCenterDelegate {
    static let category = "asky.reminder"
    private let app: AppModel
    private let scheduler: ContextScheduler
    private var observers: [NSObjectProtocol] = []
    private var checkpoint: Timer?
    private var pending: Task<Void, Never>?
    private var lastAdvisorCall: Date?
    private static let advisorCacheKey = "reminders.advisor.cache"
    /// Open items condensed from Messages and the newest message already read; cleared when message reading is off.
    private static let triageKey = "reminders.messages.triage"
    /// Unchanged context is re-judged at most this often; changed context at most every `advisorMinGap`.
    private static let advisorRefresh: TimeInterval = 6 * 3600
    private static let advisorMinGap: TimeInterval = 10 * 60

    private struct AdvisorCache: Codable {
        var fingerprint: String
        var generatedAt: Date
        var plans: [ReminderPlan]
    }

    init(app: AppModel) {
        self.app = app
        scheduler = ContextScheduler(store: ReminderStore(app.store))
        super.init()
    }

    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([UNNotificationCategory(identifier: Self.category, actions: [
            UNNotificationAction(identifier: "evidence", title: NSLocalizedString("查看依据", comment: ""), options: [.foreground]),
            UNNotificationAction(identifier: "snooze", title: NSLocalizedString("稍后", comment: "")),
            UNNotificationAction(identifier: "handled", title: NSLocalizedString("已处理", comment: "")),
            UNNotificationAction(identifier: "disable", title: NSLocalizedString("关闭此类", comment: ""), options: [.destructive]),
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
        let insights = await smartSuggestions(events: events, settings: s, now: now)
        guard let outcome = try? scheduler.reconcile(events: events, insights: insights,
                                                     travelEnabled: s.enabledSources.contains(.maps), now: now) else { return }
        center.removePendingNotificationRequests(withIdentifiers: outcome.cancel)
        for plan in outcome.schedule { await deliver(plan) }
    }

    // MARK: Smart suggestions

    private func smartSuggestions(events: [EventSnapshot], settings s: AppSettings, now: Date) async -> [ReminderPlan] {
        guard s.backgroundAI, let cfg = app.modelConfiguration else { return [] }
        if s.advisorReadsMessages != true { app.store.setSetting(Self.triageKey, nil) }
        var triage = app.store.codableSetting(Self.triageKey, as: MessageTriageState.self) ?? MessageTriageState()
        let tasks = s.enabledSources.contains(.reminders) ? await openTasks() : []
        func input() -> AdvisorInput {
            AdvisorInput(events: events, tasks: tasks,
                         memories: s.enabledSources.contains(.memory) ? relevantMemories(events: events, tasks: tasks) : [],
                         messages: s.advisorReadsMessages == true ? triage.notes : [],
                         recentSuggestions: ReminderStore(app.store).plans(status: [.delivered, .handled])
                            .filter { $0.reason == .insight }.suffix(10).map(\.title),
                         now: now)
        }
        let cached = app.store.codableSetting(Self.advisorCacheKey, as: AdvisorCache.self)
        let fallback = { SmartAdvisor.stillValid(cached?.plans ?? [], in: input()) }
        if lastAdvisorCall.map({ now.timeIntervalSince($0) < Self.advisorMinGap }) == true { return fallback() }

        let keychain = app.keychain, account = cfg.credentialRef
        // Background work never prompts for the keychain; without a readable key we simply skip.
        guard let key = await Task.detached(operation: { try? keychain.read(account: account, allowInteraction: false) }).value,
              !key.isEmpty else { return fallback() }
        let client = ChatCompletionClient(baseURL: cfg.baseURL, model: cfg.modelName, apiKey: key)
        let complete: SmartAdvisor.Complete = { system, user in try await client.complete(system: system, user: user) }

        // Pass 1: only messages not read before, in small batches, condensed to open items.
        if s.advisorReadsMessages == true {
            let messages = await recentMessages(now: now)
            let updated = await MessageTriage(complete: complete).update(triage, messages: messages, now: now)
            if updated != triage {
                if updated.watermark != triage.watermark { lastAdvisorCall = now }
                triage = updated
                app.store.setCodableSetting(Self.triageKey, triage)
            }
        }

        // Pass 2: the advisor sees events, tasks, memories and those short items, never raw message text.
        let current = input()
        let fingerprint = current.fingerprint
        if let cached, cached.fingerprint == fingerprint, now.timeIntervalSince(cached.generatedAt) < Self.advisorRefresh {
            return SmartAdvisor.stillValid(cached.plans, in: current)
        }
        lastAdvisorCall = now
        guard let plans = try? await SmartAdvisor(complete: complete).suggest(current) else {
            return SmartAdvisor.stillValid(cached?.plans ?? [], in: current)
        }
        app.store.setCodableSetting(Self.advisorCacheKey, AdvisorCache(fingerprint: fingerprint, generatedAt: now, plans: plans))
        return plans
    }

    private func openTasks() async -> [TaskSnapshot] {
        guard app.native.eventKit.remindersAuthorized else { return [] }
        let ek = app.native.eventKit.store
        let pred = ek.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        return await withCheckedContinuation { cont in
            ek.fetchReminders(matching: pred) { rs in
                let items = (rs ?? []).prefix(60).map {
                    TaskSnapshot(id: $0.calendarItemIdentifier, title: $0.title ?? "", due: $0.dueDateComponents?.date,
                                 list: $0.calendar?.title ?? "")
                }
                // Dated tasks first: they are the ones that can collide with the calendar.
                cont.resume(returning: items.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) })
            }
        }
    }

    /// Last 30 days of Messages, read-only and redacted. Silently empty without Full Disk Access.
    private func recentMessages(now: Date) async -> [MessageSnapshot] {
        let contacts = app.native.contacts
        return await Task.detached(priority: .utility) {
            let reader = MessagesHistoryReader()
            guard reader.isReadable else { return [] }
            let names = contacts.nameIndex()
            return (try? reader.recent(since: now.addingTimeInterval(-30 * 86400), limit: 300) {
                names[MessagesHistoryReader.normalize($0)]
            }) ?? []
        }.value
    }

    /// Memories that mention upcoming items, plus the most recent ones; only those allowed for AI use.
    private func relevantMemories(events: [EventSnapshot], tasks: [TaskSnapshot]) -> [ContextSnippet] {
        let assembler = ContextAssembler(memories: app.memories, maxSnippets: 3, maxCharacters: 1200)
        var out: [ContextSnippet] = []
        for title in (events.map(\.title) + tasks.map(\.title)).prefix(40) {
            for m in assembler.snippets(for: title) where !out.contains(where: { $0.sourceID == m.sourceID }) { out.append(m) }
        }
        for m in app.memories.list(limit: 10) where m.permissions.contains(.aiUse) && !out.contains(where: { $0.sourceID == "memory:\(m.id)" }) {
            out.append(ContextSnippet(sourceID: "memory:\(m.id)", text: m.content))
        }
        return Array(out.prefix(20))
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
            alert.informativeText = evidence.isEmpty ? NSLocalizedString("无记录的依据。", comment: "") : evidence.map { "• \($0)" }.joined(separator: "\n")
            NSApp.activate()
            alert.runModal()
        }
    }
}
