import AppKit
import EventKit
import Contracts
import LocalStore
import Memory
import Scheduler
import ToolService

/// Wires the Context Scheduler to EventKit change notifications, wake / time-zone changes and an hourly checkpoint,
/// and delivers plans as silent Asky reminder cards. Runs only while `proactiveReminders` is on.
/// With background AI on, the configured model also looks across events, open tasks and memories for things
/// worth preparing, and, when separately allowed, recent SMS/iMessage; its suggestions go through the same
/// dedupe, daily cap and quiet-hours rules.
@MainActor
final class ProactiveReminders: NSObject {
    private let app: AppModel
    private let scheduler: ContextScheduler
    private var observers: [NSObjectProtocol] = []
    private var checkpoint: Timer?
    private var deliveryTimer: Timer?
    private var bannerIDs: [String: UUID] = [:]
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
        Task { await LegacyReminderNotifications.removeAll() }

        let nc = NotificationCenter.default, ws = NSWorkspace.shared.notificationCenter
        let trigger: @Sendable (Notification) -> Void = { [weak self] _ in Task { @MainActor in self?.schedule() } }
        observers = [
            nc.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main, using: trigger),
            nc.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main, using: trigger),
            ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: trigger),
            ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    // Wake must revalidate before an overdue timer can present a stale plan.
                    self?.deliveryTimer?.invalidate()
                    self?.deliveryTimer = nil
                    self?.pending?.cancel()
                }
            },
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
        deliveryTimer?.invalidate()
        deliveryTimer = nil
        withdrawCards()
    }

    /// Debounced: bursts of EventKit changes collapse into one reconcile.
    func schedule() {
        deliveryTimer?.invalidate()
        deliveryTimer = nil
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.reconcile()
        }
    }

    private func reconcile() async {
        let s = app.settings
        guard s.proactiveReminders, s.enabledSources.contains(.calendar), app.native.eventKit.calendarAuthorized else {
            withdrawCards()
            return
        }
        let now = Date()
        let ek = app.native.eventKit.store
        let pred = ek.predicateForEvents(withStart: now, end: now.addingTimeInterval(7 * 24 * 3600), calendars: nil)
        let events = ek.events(matching: pred).filter { $0.availability != .free }.map {
            EventSnapshot(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "", start: $0.startDate,
                          end: $0.endDate, location: $0.location, isAllDay: $0.isAllDay)
        }
        let insights = await smartSuggestions(events: events, settings: s, now: now)
        guard !Task.isCancelled else { return }
        guard let outcome = try? scheduler.reconcile(events: events, insights: insights,
                                                     travelEnabled: s.enabledSources.contains(.maps), now: now) else { return }
        guard !Task.isCancelled else { return }
        for id in outcome.cancel { withdrawCard(id) }
        armDelivery()
    }

    // MARK: Smart suggestions

    private func smartSuggestions(events: [EventSnapshot], settings s: AppSettings, now: Date) async -> [ReminderPlan] {
        guard s.backgroundAI, let cfg = app.modelConfiguration else { return [] }
        if s.advisorReadsMessages != true || !s.enabledSources.contains(.messages) { app.store.setSetting(Self.triageKey, nil) }
        var triage = app.store.codableSetting(Self.triageKey, as: MessageTriageState.self) ?? MessageTriageState()
        let tasks = s.enabledSources.contains(.reminders) ? await openTasks() : []
        func input() -> AdvisorInput {
            AdvisorInput(events: events, tasks: tasks,
                         memories: s.enabledSources.contains(.memory) ? memoryIndex() : [],
                         messages: s.advisorReadsMessages == true && s.enabledSources.contains(.messages) ? triage.notes : [],
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
        if s.advisorReadsMessages == true && s.enabledSources.contains(.messages) {
            let days = s.messagesLookback
            let messages = await recentMessages(days: days, now: now)
            var triager = MessageTriage(complete: complete)
            triager.window = Double(days) * 86400
            let updated = await triager.update(triage, messages: messages, now: now)
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

    /// Recent Messages within the chosen window, read-only and redacted. Silently empty without Full Disk Access.
    private func recentMessages(days: Int, now: Date) async -> [MessageSnapshot] {
        let contacts = app.native.contacts
        return await Task.detached(priority: .utility) {
            let reader = MessagesHistoryReader()
            guard reader.isReadable else { return [] }
            let names = contacts.nameIndex()
            return (try? reader.recent(since: now.addingTimeInterval(-Double(days) * 86400), limit: 300) {
                names[MessagesHistoryReader.normalize($0)]
            }) ?? []
        }.value
    }

    /// The memory index (MEMORY.md); topic files are left out of background suggestions.
    private func memoryIndex() -> [ContextSnippet] {
        app.memory.context().map { [ContextSnippet(sourceID: "memory/\(MemoryFolder.indexName)", text: $0)] } ?? []
    }

    /// Rebuild from persisted plans after every reconcile, including unchanged and snoozed plans.
    private func armDelivery() {
        deliveryTimer?.invalidate()
        deliveryTimer = nil
        guard app.settings.proactiveReminders, app.settings.enabledSources.contains(.calendar),
              app.native.eventKit.calendarAuthorized else { return }
        let plans = ReminderStore(app.store).plans(status: [.scheduled, .snoozed]).sorted { $0.fireDate < $1.fireDate }
        let now = Date()
        for plan in plans where plan.fireDate <= now { deliver(plan) }
        guard let next = plans.first(where: { $0.fireDate > now }) else { return }
        let timer = Timer(fire: next.fireDate, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.armDelivery() }
        }
        RunLoop.main.add(timer, forMode: .common)
        deliveryTimer = timer
    }

    private func deliver(_ plan: ReminderPlan) {
        // Persist before presenting, so checkpoints and relaunches cannot show it twice.
        do { try scheduler.markDelivered(plan.id) } catch { return }
        withdrawCard(plan.id)
        let item = ReminderBannerItem(
            source: "Asky", timeLabel: NSLocalizedString("现在", comment: ""),
            title: plan.title, body: plan.body,
            symbol: plan.reason == .travel ? "car.fill" : "calendar",
            reasons: plan.evidence,
            actions: [
                .init(title: NSLocalizedString("稍后提醒", comment: "")) { [weak self] in self?.snooze(plan.id) },
                .init(title: NSLocalizedString("关闭此类", comment: "")) { [weak self] in self?.disable(plan) },
                .init(title: NSLocalizedString("已处理", comment: ""), prominent: true) { [weak self] in
                    try? self?.scheduler.markHandled(plan.id)
                    self?.bannerIDs[plan.id] = nil
                },
            ], lifetime: nil)
        bannerIDs[plan.id] = item.id
        ReminderBannerCenter.shared.show(item)
    }

    private func snooze(_ id: String) {
        guard (try? scheduler.snooze(id)) != nil else { return }
        bannerIDs[id] = nil
        armDelivery()
    }

    private func disable(_ plan: ReminderPlan) {
        guard (try? scheduler.disableCategory(plan.reason)) != nil else { return }
        let ids = ReminderStore(app.store).plans(status: [.delivered, .cancelled])
            .filter { $0.reason == plan.reason && !$0.userRequested }.map(\.id)
        for id in ids { withdrawCard(id) }
        armDelivery()
    }

    private func withdrawCard(_ planID: String) {
        guard let id = bannerIDs.removeValue(forKey: planID) else { return }
        ReminderBannerCenter.shared.dismiss(id)
    }

    private func withdrawCards() {
        for id in Array(bannerIDs.keys) { withdrawCard(id) }
    }
}
