import Foundation

extension ToolService {
    /// Only called after the user submits an explicit launcher terminal result.
    public static func openLauncherTerminal(command: String, workingDirectory: URL) async throws {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        try await LauncherTerminalHandoff.shared.open(command: command, directory: workingDirectory)
    }
}

/// In-process Apple Events keep Automation permission attributed to the app.
private actor LauncherTerminalHandoff {
    static let shared = LauncherTerminalHandoff()

    func open(command: String, directory: URL) throws {
        guard let script = NSAppleScript(source: LauncherTerminalScript.source(command: command, directory: directory)) else {
            throw NSError(domain: "LauncherTerminal", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("无法创建终端命令。", comment: "")])
        }
        var info: NSDictionary?
        _ = script.executeAndReturnError(&info)
        if let info {
            let code = (info[NSAppleScript.errorNumber] as? Int) ?? 0
            let message = code == -1743
                ? NSLocalizedString("请在系统设置 › 隐私与安全性 › 自动化中允许 Asky 控制终端。", comment: "")
                : (info[NSAppleScript.errorMessage] as? String) ?? NSLocalizedString("无法打开终端。", comment: "")
            throw NSError(domain: "LauncherTerminal", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}

enum LauncherTerminalScript {
    static func source(command: String, directory: URL) -> String {
        let path = "'" + directory.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let shell = "cd \(path) && \(command)"
        let literal = "\"" + shell.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
        return "tell application \"Terminal\"\nactivate\ndo script \(literal)\nend tell"
    }
}
