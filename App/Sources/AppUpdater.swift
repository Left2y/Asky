import AppKit
import CoreGraphics
import ToolService

/// Shared update state for the About page and silent background updates.
/// With automatic updates on, new releases are downloaded and verified in the background, then
/// installed by a silent relaunch once Asky is not in use, or by the swap helper when the user quits.
/// Nothing is announced; the About page shows a staged release for users who look.
@MainActor @Observable
final class AppUpdater {
    enum Status: Equatable {
        case idle, checking, upToDate
        case available(AppRelease)
        case downloading(AppRelease, String)
        case ready(StagedAppUpdate)
        case installing
        case failed(String)
    }

    private(set) var status = Status.idle
    /// Set by the app delegate: true only when restarting cannot interrupt anything the user sees.
    @ObservationIgnored var isQuiet: () -> Bool = { false }
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var lastUsed = Date()
    @ObservationIgnored private var screenSaverRunning = false

    static let launchDelay: Duration = .seconds(120)
    static let checkInterval: TimeInterval = 6 * 3600
    static let idlePoll: Duration = .seconds(60)
    /// Asky itself has not been opened for this long…
    static let unusedFor: TimeInterval = 30 * 60
    /// …and the Mac saw no input for this long, so a hotkey press is not about to land mid-restart.
    static let inputIdleFor: TimeInterval = 2 * 60

    /// Source builds run from DerivedData and must never replace themselves.
    static var isSupported: Bool {
        Bundle.main.object(forInfoDictionaryKey: "KHSourceRoot") == nil && !ToolService.appInstallationRequired
    }

    var isBusy: Bool {
        switch status {
        case .checking, .downloading, .installing: true
        default: false
        }
    }

    func setAutomatic(_ enabled: Bool) {
        loop?.cancel()
        loop = nil
        observers.forEach { $0.0.removeObserver($0.1) }
        observers = []
        guard enabled, Self.isSupported else { return }
        observe()
        loop = Task { [weak self] in
            try? await Task.sleep(for: Self.launchDelay)
            var lastCheck = Date.distantPast
            while !Task.isCancelled, let self {
                if Date().timeIntervalSince(lastCheck) >= Self.checkInterval {
                    lastCheck = Date()
                    await self.check(stage: true, silent: true)
                }
                self.restartIfUnused()
                try? await Task.sleep(for: Self.idlePoll)
            }
        }
    }

    /// Any Asky window taking focus counts as use; lock, screen saver and wake re-evaluate at once.
    private func observe() {
        let local = NotificationCenter.default
        let distributed = DistributedNotificationCenter.default()
        let workspace = NSWorkspace.shared.notificationCenter
        let add = { (center: NotificationCenter, name: Notification.Name, handler: @escaping @MainActor (AppUpdater) -> Void) in
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { if let self { handler(self) } }
            }
            self.observers.append((center, token))
        }
        add(local, NSWindow.didBecomeKeyNotification) { $0.lastUsed = Date() }
        add(distributed, .init("com.apple.screensaver.didstart")) { $0.screenSaverRunning = true; $0.restartIfUnused() }
        add(distributed, .init("com.apple.screensaver.didstop")) { $0.screenSaverRunning = false }
        add(distributed, .init("com.apple.screenIsLocked")) { $0.restartIfUnused() }
        add(workspace, NSWorkspace.didWakeNotification) { $0.restartIfUnused() }
    }

    /// Relaunch only when nothing in Asky is open or working, and the user is either away
    /// (screen locked or saver running) or has not opened Asky for a while and is not typing.
    private func restartIfUnused() {
        guard case .ready = status else { return }
        guard isQuiet() else { lastUsed = Date(); return }
        let away = screenSaverRunning || Self.screenIsLocked
        let unused = Date().timeIntervalSince(lastUsed) >= Self.unusedFor && Self.systemIdleSeconds >= Self.inputIdleFor
        if away || unused { restartToInstall() }
    }

    /// `stage` downloads right away; `silent` keeps transient failures out of the UI.
    func check(stage: Bool, silent: Bool = false) async {
        guard !isBusy else { return }
        let previous = status
        status = .checking
        do {
            guard let release = try await ToolService.checkForAppUpdate() else {
                if case .ready(let staged) = previous { ToolService.discardStagedAppUpdate(staged) }
                status = .upToDate
                return
            }
            if case .ready(let staged) = previous {
                if staged.release.version == release.version { status = previous; return }
                ToolService.discardStagedAppUpdate(staged)
            }
            status = .available(release)
            if stage { await download(release, silent: silent) }
        } catch {
            status = silent ? previous.restingState : .failed(error.localizedDescription)
        }
    }

    func download(_ release: AppRelease, silent: Bool = false) async {
        if case .downloading = status { return }
        status = .downloading(release, NSLocalizedString("正在准备…", comment: ""))
        do {
            let staged = try await ToolService.stageAppUpdate(release) { [weak self] step in
                await MainActor.run {
                    if case .downloading = self?.status { self?.status = .downloading(release, step) }
                }
            }
            status = .ready(staged)
        } catch {
            status = silent ? .available(release) : .failed(error.localizedDescription)
        }
    }

    /// Swap now and reopen Asky in the background without taking focus.
    func restartToInstall() {
        guard case .ready(let staged) = status else { return }
        do {
            try ToolService.installStagedAppUpdate(staged, relaunch: true)
            status = .installing
            NSApp.terminate(nil)
        } catch {
            ToolService.discardStagedAppUpdate(staged)
            status = .failed(error.localizedDescription)
        }
    }

    /// Called while quitting: a downloaded update replaces the app after exit without reopening it.
    func installOnQuit() {
        guard case .ready(let staged) = status else { return }
        status = .installing
        if (try? ToolService.installStagedAppUpdate(staged, relaunch: false)) == nil {
            ToolService.discardStagedAppUpdate(staged)
        }
    }

    static var screenIsLocked: Bool {
        (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool == true
    }

    static var systemIdleSeconds: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }
}

private extension AppUpdater.Status {
    /// Background failures fall back to the last state the user could act on.
    var restingState: Self {
        switch self {
        case .checking, .downloading, .installing: .idle
        default: self
        }
    }
}
