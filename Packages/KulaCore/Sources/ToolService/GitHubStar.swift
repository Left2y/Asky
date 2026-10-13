import Foundation

extension ToolService {
    /// Asks a locally signed-in GitHub CLI whether the user has starred the Asky repository.
    /// Returns nil when `gh` is missing, signed out or offline, so the caller can fall back.
    public static func appRepositoryStarred() async -> Bool? {
        guard let gh = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
            .first(where: FileManager.default.isExecutableFile(atPath:)) else { return nil }
        return await Task.detached {
            let process = Process(), errors = Pipe()
            process.executableURL = URL(filePath: gh)
            process.arguments = ["api", "user/starred/\(AppUpdate.repository)", "--silent"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errors
            do { try process.run() } catch { return nil }
            let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeout)
            let detail = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            process.waitUntilExit()
            timeout.cancel()
            if process.terminationStatus == 0 { return true }
            // 404 means signed in but not starred; anything else (auth, network) is unknown.
            return detail.contains("HTTP 404") ? false : nil
        }.value
    }
}
