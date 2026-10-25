import Foundation
import Contracts

extension ToolService {
    /// Only called after the user submits an explicit launcher terminal result.
    @MainActor public static func openLauncherTerminal(command: String, workingDirectory: URL,
                                                     application: LauncherTerminalApplication = .system) async throws {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let applicationURL = launcherTerminalApplicationURL(application) else {
            throw NSError(domain: "LauncherTerminal", code: 2, userInfo: [NSLocalizedDescriptionKey:
                String(format: CoreLocalization.text("%@ 未安装，请在设置 › 指令 › 终端中重新选择。"), application.name)])
        }
        if application == .kero {
            guard let executable = Bundle(url: applicationURL)?.executableURL else {
                throw NSError(domain: "LauncherTerminal", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: CoreLocalization.text("无法打开终端。")])
            }
            let result = try await PluginProcess.command(executable.path,
                LauncherTerminalCLI.keroArguments(command: command, directory: workingDirectory), seconds: 15)
            guard result.exitCode == 0 else {
                let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                throw NSError(domain: "LauncherTerminal", code: Int(result.exitCode),
                              userInfo: [NSLocalizedDescriptionKey: message.isEmpty
                                ? CoreLocalization.text("无法打开终端。") : message])
            }
            return
        }
        try await LauncherTerminalHandoff.shared.open(command: command, directory: workingDirectory, application: application)
    }
}

/// In-process Apple Events keep Automation permission attributed to the app.
private actor LauncherTerminalHandoff {
    static let shared = LauncherTerminalHandoff()

    func open(command: String, directory: URL, application: LauncherTerminalApplication) throws {
        guard let source = LauncherTerminalScript.source(command: command, directory: directory, application: application),
              let script = NSAppleScript(source: source) else {
            throw NSError(domain: "LauncherTerminal", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: CoreLocalization.text("无法创建终端命令。")])
        }
        var info: NSDictionary?
        _ = script.executeAndReturnError(&info)
        if let info {
            let code = (info[NSAppleScript.errorNumber] as? Int) ?? 0
            let message = code == -1743
                ? String(format: CoreLocalization.text("请在系统设置 › 隐私与安全性 › 自动化中允许 Asky 控制 %@。"), application.name)
                : (info[NSAppleScript.errorMessage] as? String) ?? CoreLocalization.text("无法打开终端。")
            throw NSError(domain: "LauncherTerminal", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}

enum LauncherTerminalScript {
    static func source(command: String, directory: URL, application: LauncherTerminalApplication = .system) -> String? {
        let path = "'" + directory.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let shell = "cd \(path) && \(command)"
        let target = "tell application id \(literal(application.rawValue))\nactivate\n"
        switch application {
        case .system, .otty:
            return target + "do script \(literal(shell))\nend tell"
        case .iTerm:
            return target + "set win to (create window with default profile)\ntell current session of win to write text \(literal(shell))\nend tell"
        case .ghostty:
            return target + "set cfg to new surface configuration\nset initial working directory of cfg to \(literal(directory.path))\nset initial input of cfg to \(literal(command + "\n"))\nnew window with configuration cfg\nend tell"
        case .kero:
            return nil
        }
    }

    private static func literal(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

enum LauncherTerminalCLI {
    static func keroArguments(command: String, directory: URL) -> [String] {
        // Kero passes the command to the session's shell and keeps its output in the pane.
        // No --wait: Asky waits only for the handoff, never for the user's command to finish.
        ["new", "--focus", "--dir", directory.path, "--", command]
    }
}
