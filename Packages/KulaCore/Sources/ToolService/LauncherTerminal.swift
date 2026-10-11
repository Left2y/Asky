import Foundation

extension ToolService {
    /// Only called after the user submits an explicit launcher terminal result.
    @MainActor public static func openLauncherTerminal(command: String, workingDirectory: URL,
                                                     application: LauncherTerminalApplication = .system) async throws {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard launcherTerminalApplicationURL(application) != nil else {
            throw NSError(domain: "LauncherTerminal", code: 2, userInfo: [NSLocalizedDescriptionKey:
                String(format: NSLocalizedString("%@ 未安装，请在设置 › 通用 › 终端中重新选择。", comment: ""), application.name)])
        }
        try await LauncherTerminalHandoff.shared.open(command: command, directory: workingDirectory, application: application)
    }
}

/// In-process Apple Events keep Automation permission attributed to the app.
private actor LauncherTerminalHandoff {
    static let shared = LauncherTerminalHandoff()

    func open(command: String, directory: URL, application: LauncherTerminalApplication) throws {
        guard let script = NSAppleScript(source: LauncherTerminalScript.source(command: command, directory: directory, application: application)) else {
            throw NSError(domain: "LauncherTerminal", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("无法创建终端命令。", comment: "")])
        }
        var info: NSDictionary?
        _ = script.executeAndReturnError(&info)
        if let info {
            let code = (info[NSAppleScript.errorNumber] as? Int) ?? 0
            let message = code == -1743
                ? String(format: NSLocalizedString("请在系统设置 › 隐私与安全性 › 自动化中允许 Asky 控制 %@。", comment: ""), application.name)
                : (info[NSAppleScript.errorMessage] as? String) ?? NSLocalizedString("无法打开终端。", comment: "")
            throw NSError(domain: "LauncherTerminal", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}

enum LauncherTerminalScript {
    static func source(command: String, directory: URL, application: LauncherTerminalApplication = .system) -> String {
        let path = "'" + directory.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let shell = "cd \(path) && \(command)"
        let target = "tell application id \(literal(application.rawValue))\nactivate\n"
        switch application {
        case .system:
            return target + "do script \(literal(shell))\nend tell"
        case .iTerm:
            return target + "set win to (create window with default profile)\ntell current session of win to write text \(literal(shell))\nend tell"
        case .ghostty:
            return target + "set cfg to new surface configuration\nset initial working directory of cfg to \(literal(directory.path))\nset initial input of cfg to \(literal(command + "\n"))\nnew window with configuration cfg\nend tell"
        }
    }

    private static func literal(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
