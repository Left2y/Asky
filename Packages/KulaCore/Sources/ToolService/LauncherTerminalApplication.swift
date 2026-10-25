import Contracts
import AppKit

public enum LauncherTerminalApplication: String, CaseIterable, Sendable, Identifiable {
    case system = "com.apple.Terminal"
    case iTerm = "com.googlecode.iterm2"
    case ghostty = "com.mitchellh.ghostty"
    case otty = "io.appmakes.otty"
    case kero = "sh.kero"

    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .system: CoreLocalization.text("系统终端")
        case .iTerm: "iTerm2"
        case .ghostty: "Ghostty"
        case .otty: "Otty"
        case .kero: "Kero"
        }
    }
}

extension ToolService {
    @MainActor public static func launcherTerminalApplicationURL(_ application: LauncherTerminalApplication) -> URL? {
        validatedLauncherTerminalURL(
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: application.rawValue),
            application: application)
    }

    static func validatedLauncherTerminalURL(_ url: URL?, application: LauncherTerminalApplication) -> URL? {
        guard let url,
              FileManager.default.fileExists(atPath: url.path),
              let bundle = Bundle(url: url),
              bundle.bundleIdentifier == application.rawValue,
              let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else { return nil }
        return url
    }

    @MainActor public static func installedLauncherTerminals() -> [LauncherTerminalApplication] {
        LauncherTerminalApplication.allCases.filter { launcherTerminalApplicationURL($0) != nil }
    }

    @MainActor public static func launcherTerminalIcon(_ application: LauncherTerminalApplication) -> NSImage? {
        guard let url = launcherTerminalApplicationURL(application) else { return nil }
        return launcherIcon(filePath: url.path)
    }
}
