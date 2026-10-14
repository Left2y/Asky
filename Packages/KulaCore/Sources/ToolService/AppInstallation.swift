import AppKit
import Foundation

extension ToolService {
    public static var appInstallationRequired: Bool {
        // Source builds stay runnable in their build directory.
        Bundle.main.object(forInfoDictionaryKey: "KHSourceRoot") == nil &&
        !appIsInstalled(at: Bundle.main.bundleURL)
    }

    public static var appInstallationURL: URL { URL(filePath: "/Applications/Asky.app") }

    static func appIsInstalled(at url: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let parent = url.standardizedFileURL.deletingLastPathComponent()
        return !url.pathComponents.contains("AppTranslocation") &&
            (parent.path == "/Applications" || parent.path == home.appending(path: "Applications").path)
    }

    public static var existingInstalledApp: URL? {
        let url = appInstallationURL
        guard Bundle(url: url)?.bundleIdentifier == Bundle.main.bundleIdentifier else { return nil }
        return url
    }

    /// Stages a complete, verified copy before publishing it in Applications. Never replaces an existing app.
    public static func installAppInApplications() async throws -> URL {
        let source = Bundle.main.bundleURL
        let destination = appInstallationURL
        return try await Task.detached(priority: .userInitiated) {
            try copyAppForInstallation(from: source, to: destination)
            return destination
        }.value
    }

    static func copyAppForInstallation(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        let parent = destination.deletingLastPathComponent()
        guard !fm.fileExists(atPath: destination.path) else {
            throw AppUpdateError.installFailed(NSLocalizedString("应用程序中已有 Asky，请打开已安装的版本。", comment: ""))
        }
        guard fm.isWritableFile(atPath: parent.path) else { throw AppUpdateError.notWritable(parent.path) }
        guard let bundle = Bundle(url: source), bundle.bundleIdentifier == "app.kulahere.KulaHere" else {
            throw AppUpdateError.invalidBundle
        }
        let work = parent.appending(path: ".asky-install-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: work) }
        let staged = work.appending(path: "Asky.app")
        try AppUpdate.run("/usr/bin/ditto", [source.path, staged.path])
        try AppUpdate.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", staged.path])
        // moveItem fails if the destination appeared during the copy; it never overwrites it.
        try fm.moveItem(at: staged, to: destination)
    }

    /// Passed to the installed app by `reopenInstalledAppAfterExit`, so a misrouted launch cannot bounce forever.
    public static let redirectedLaunchArgument = "--asky-redirected"

    /// The installed copy is at least as new as this one, so opening it instead loses nothing.
    public static func installedAppIsCurrent(_ url: URL, current: String = currentAppVersion) -> Bool {
        let installed = NSDictionary(contentsOf: url.appending(path: "Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
        return installed.map { !AppUpdate.isNewer(current, than: $0) } ?? false
    }

    /// Opens the installed bundle only after this process exits, avoiding Launch Services returning this instance.
    /// Re-registers it first: a stale record (e.g. right after an update swap) can make Launch Services
    /// open another registered copy with the same bundle identifier instead of this path.
    public static func reopenInstalledAppAfterExit(at url: URL) throws {
        guard Bundle(url: url)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw AppUpdateError.invalidBundle
        }
        let helper = Process()
        helper.executableURL = URL(filePath: "/bin/sh")
        helper.arguments = ["-c", """
                            while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
                            \(AppUpdate.lsregister) -f "$2" 2>/dev/null || true
                            /usr/bin/open "$2" --args "$3"
                            """,
                            "asky-install", String(ProcessInfo.processInfo.processIdentifier), url.path,
                            redirectedLaunchArgument]
        helper.standardOutput = FileHandle.nullDevice
        helper.standardError = FileHandle.nullDevice
        try helper.run()
    }

    public static func revealAppInstallationFolder() {
        NSWorkspace.shared.open(appInstallationURL.deletingLastPathComponent())
    }
}
