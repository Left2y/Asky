import AppKit
import CryptoKit
import Foundation

/// A published GitHub release that carries an installable Asky ZIP.
public struct AppRelease: Sendable, Equatable {
    public let version: String
    public let name: String
    public let pageURL: URL
    public let archiveURL: URL
    public let checksumURL: URL?
}

public enum AppUpdateError: LocalizedError, Equatable {
    case network(String)
    case noRelease
    case missingArchive
    case checksumMismatch
    case invalidBundle
    case translocated
    case notWritable(String)
    case installFailed(String)

    public var errorDescription: String? {
        switch self {
        case .network(let detail):
            String(format: NSLocalizedString("无法连接 GitHub：%@", comment: ""), detail)
        case .noRelease: NSLocalizedString("GitHub 上还没有可用的发布版本。", comment: "")
        case .missingArchive: NSLocalizedString("最新发布版本中没有适用于 macOS 的安装包。", comment: "")
        case .checksumMismatch: NSLocalizedString("安装包校验失败，已停止安装。", comment: "")
        case .invalidBundle: NSLocalizedString("安装包中没有有效的 Asky.app。", comment: "")
        case .translocated: NSLocalizedString("请先将 Asky.app 移到“应用程序”文件夹并重新打开，再安装更新。", comment: "")
        case .notWritable(let path):
            String(format: NSLocalizedString("没有权限写入 %@，无法替换旧版本。", comment: ""), path)
        case .installFailed(let detail):
            String(format: NSLocalizedString("安装失败：%@", comment: ""), detail)
        }
    }
}

enum AppUpdate {
    static let repository = "Niall-Young/Asky"
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!

    private struct ReleasePayload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let name: String?
        let html_url: URL
        let draft: Bool?
        let prerelease: Bool?
        let assets: [Asset]
    }

    /// Prefers the arm64 macOS ZIP published by the release workflow, falling back to any ZIP.
    static func parseRelease(_ data: Data) throws -> AppRelease {
        let payload = try JSONDecoder().decode(ReleasePayload.self, from: data)
        let zips = payload.assets.filter { $0.name.lowercased().hasSuffix(".zip") }
        guard let archive = zips.first(where: { $0.name.lowercased().contains("macos") }) ?? zips.first else {
            throw AppUpdateError.missingArchive
        }
        let checksum = payload.assets.first { $0.name == archive.name + ".sha256" }
        let version = normalizedVersion(payload.tag_name)
        return AppRelease(version: version, name: payload.name ?? payload.tag_name, pageURL: payload.html_url,
                          archiveURL: archive.browser_download_url, checksumURL: checksum?.browser_download_url)
    }

    static func normalizedVersion(_ tag: String) -> String {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first == "v" || trimmed.first == "V" ? String(trimmed.dropFirst()) : trimmed
    }

    /// Numeric component comparison so "0.0.10" > "0.0.9" and "1.0" == "1.0.0".
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let parse = { (s: String) -> [Int] in normalizedVersion(s).split(separator: ".").map { Int($0) ?? 0 } }
        let a = parse(candidate), b = parse(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// `shasum -a 256` format: "<hex>  <file name>".
    static func parseChecksum(_ text: String) -> String? {
        guard let hex = text.split(whereSeparator: \.isWhitespace).first.map(String.init)?.lowercased(),
              hex.count == 64, hex.allSatisfy(\.isHexDigit) else { return nil }
        return hex
    }

    static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Asky-Updater", forHTTPHeaderField: "User-Agent")
        return request
    }

    static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw AppUpdateError.installFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Waits for the running app to exit, swaps bundles, removes the old one and relaunches.
    /// On a failed move the old bundle is restored so the user is never left without an app.
    static let swapScript = """
    pid="$1"; old="$2"; new="$3"; work="$4"
    while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
    backup="$work/previous.app"
    if mv "$old" "$backup"; then
      if mv "$new" "$old"; then rm -rf "$backup"; else mv "$backup" "$old"; fi
    fi
    open "$old"
    rm -rf "$work"
    """
}

extension ToolService {
    public static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    public static var currentAppBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    public static var appRepositoryURL: URL { URL(string: "https://github.com/\(AppUpdate.repository)")! }

    /// Returns the latest release only when it is newer than the running app.
    public static func checkForAppUpdate() async throws -> AppRelease? {
        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: AppUpdate.request(AppUpdate.latestReleaseURL)) }
        catch { throw AppUpdateError.network(error.localizedDescription) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { throw AppUpdateError.noRelease }
        guard (200..<300).contains(status) else { throw AppUpdateError.network("HTTP \(status)") }
        let release = try AppUpdate.parseRelease(data)
        return AppUpdate.isNewer(release.version, than: currentAppVersion) ? release : nil
    }

    /// Downloads, verifies and stages the release, then starts a detached helper that replaces
    /// the running bundle once the app quits. The caller must terminate the app afterwards.
    public static func prepareAppUpdate(_ release: AppRelease, progress: @escaping @Sendable (String) async -> Void) async throws {
        let installed = Bundle.main.bundleURL.standardizedFileURL
        guard !installed.path.contains("/AppTranslocation/") else { throw AppUpdateError.translocated }
        let parent = installed.deletingLastPathComponent()
        let fileManager = FileManager.default
        guard fileManager.isWritableFile(atPath: parent.path), fileManager.isWritableFile(atPath: installed.path) else {
            throw AppUpdateError.notWritable(parent.path)
        }
        // Same volume as the installed app, so the final swap is an atomic rename.
        let work = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: installed, create: true)
        do {
            await progress(NSLocalizedString("正在下载…", comment: ""))
            let archive = work.appending(path: release.archiveURL.lastPathComponent)
            do {
                let (downloaded, response) = try await URLSession.shared.download(for: AppUpdate.request(release.archiveURL))
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw AppUpdateError.network("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                }
                try fileManager.moveItem(at: downloaded, to: archive)
            } catch let error as AppUpdateError { throw error }
            catch { throw AppUpdateError.network(error.localizedDescription) }

            await progress(NSLocalizedString("正在校验…", comment: ""))
            if let checksumURL = release.checksumURL {
                let (data, _) = try await URLSession.shared.data(for: AppUpdate.request(checksumURL))
                guard let expected = AppUpdate.parseChecksum(String(decoding: data, as: UTF8.self)),
                      try AppUpdate.sha256(of: archive) == expected else { throw AppUpdateError.checksumMismatch }
            }

            await progress(NSLocalizedString("正在安装…", comment: ""))
            let extracted = work.appending(path: "extracted")
            try AppUpdate.run("/usr/bin/ditto", ["-x", "-k", archive.path, extracted.path])
            let candidates = (try? fileManager.contentsOfDirectory(at: extracted, includingPropertiesForKeys: nil)) ?? []
            guard let app = candidates.first(where: { $0.pathExtension == "app" }),
                  let bundle = Bundle(url: app),
                  bundle.bundleIdentifier == Bundle.main.bundleIdentifier else { throw AppUpdateError.invalidBundle }
            try AppUpdate.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
            try? fileManager.removeItem(at: archive)

            let helper = Process()
            helper.executableURL = URL(filePath: "/bin/sh")
            helper.arguments = ["-c", AppUpdate.swapScript, "asky-update",
                                String(ProcessInfo.processInfo.processIdentifier), installed.path, app.path, work.path]
            helper.standardOutput = FileHandle.nullDevice
            helper.standardError = FileHandle.nullDevice
            try helper.run()
        } catch {
            try? fileManager.removeItem(at: work)
            throw error
        }
    }
}
