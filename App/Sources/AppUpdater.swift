import AppKit
import CoreGraphics
import ToolService

/// Shared update state for the About page and silent background updates.
/// With automatic updates on, new releases are downloaded and verified in the background, then
/// swapped in when Asky quits, or relaunched in place while the user is away and no window is open.
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

    static let launchDelay: Duration = .seconds(120)
    static let checkInterval: TimeInterval = 6 * 3600
    static let idlePoll: Duration = .seconds(60)
    /// No keyboard or pointer input for this long before a silent relaunch.
    static let requiredIdle: TimeInterval = 10 * 60

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
        guard enabled, Self.isSupported else { return }
        loop = Task { [weak self] in
            try? await Task.sleep(for: Self.launchDelay)
            var lastCheck = Date.distantPast
            while !Task.isCancelled, let self {
                if Date().timeIntervalSince(lastCheck) >= Self.checkInterval {
                    lastCheck = Date()
                    await self.check(stage: true, silent: true)
                }
                if case .ready = self.status, self.isQuiet(), Self.systemIdleSeconds >= Self.requiredIdle {
                    self.restartToInstall()
                    return
                }
                try? await Task.sleep(for: Self.idlePoll)
            }
        }
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

    /// Swap now and reopen Asky.
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
