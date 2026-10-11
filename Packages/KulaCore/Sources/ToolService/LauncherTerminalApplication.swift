import AppKit

public enum LauncherTerminalApplication: String, CaseIterable, Sendable, Identifiable {
    case system = "com.apple.Terminal"
    case iTerm = "com.googlecode.iterm2"
    case ghostty = "com.mitchellh.ghostty"

    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .system: NSLocalizedString("系统终端", comment: "")
        case .iTerm: "iTerm2"
        case .ghostty: "Ghostty"
        }
    }
}

extension ToolService {
    @MainActor public static func launcherTerminalApplicationURL(_ application: LauncherTerminalApplication) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: application.rawValue)
    }

    @MainActor public static func installedLauncherTerminals() -> [LauncherTerminalApplication] {
        LauncherTerminalApplication.allCases.filter { launcherTerminalApplicationURL($0) != nil }
    }

    @MainActor public static func launcherTerminalIcon(_ application: LauncherTerminalApplication) -> NSImage? {
        guard let url = launcherTerminalApplicationURL(application) else { return nil }
        return launcherIcon(filePath: url.path)
    }
}
