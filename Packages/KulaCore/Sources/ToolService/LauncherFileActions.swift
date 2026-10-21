import Foundation
import Contracts

extension ToolService {
    public static func showLauncherFileInfo(at url: URL) async throws {
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try await LauncherFileInfoHandoff.shared.show(url)
    }
}

/// In-process Apple Events keep Finder Automation permission attributed to Asky.
private actor LauncherFileInfoHandoff {
    static let shared = LauncherFileInfoHandoff()

    func show(_ url: URL) throws {
        let path = url.path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application id "com.apple.finder"
            set targetFile to (POSIX file "\(path)") as alias
            open information window of targetFile
            activate
        end tell
        """
        guard let script = NSAppleScript(source: source) else { throw CocoaError(.executableLoad) }
        var info: NSDictionary?
        _ = script.executeAndReturnError(&info)
        if let info {
            let code = (info[NSAppleScript.errorNumber] as? Int) ?? 0
            let message = code == -1743
                ? String(format: CoreLocalization.text("请在系统设置 › 隐私与安全性 › 自动化中允许 Asky 控制 %@。"), "Finder")
                : (info[NSAppleScript.errorMessage] as? String) ?? CocoaError(.fileReadUnknown).localizedDescription
            throw NSError(domain: "LauncherFileInfo", code: code,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
