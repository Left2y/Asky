import AppKit
import ApplicationServices
import ToolService
import Contracts
import Search

@main @MainActor
private enum WindowSearchRegression {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                try await check()
                print("PASS: sw entry, custom trigger, mode isolation, exit, cancellation")
                print("Live Accessibility access: \(AXIsProcessTrusted())")
                exit(0)
            } catch {
                fputs("FAIL: \(error)\n", stderr)
                exit(1)
            }
        }
        app.run()
    }

    static func require(_ value: Bool, _ message: String) throws {
        if !value { throw NSError(domain: "WindowSearch", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func check() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Asky-windows-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let model = LauncherModel(app: app, searchProviders: [], chromeBookmarkAccessAllowed: false)
        model.inputText = "sw"
        guard let command = model.results.first(where: { $0.target.kind == "search-command" && $0.target.identifier == "windows" }) else {
            throw NSError(domain: "WindowSearch", code: 2)
        }
        model.execute(command, action: command.primaryAction)
        try require(model.filter == .windows && model.inputText.isEmpty, "Return must enter empty window search")
        model.inputText = "link readme"
        try require(model.filter == .windows && !model.isLinkScope, "Window query must not switch modes")
        model.inputText = "README"
        model.leaveCommand()
        try require(model.filter == .all && model.inputText == "README", "Escape must retain query")
        model.reset()
        model.inputText = "sw "
        try require(model.filter == .windows && model.inputText.isEmpty, "Space must enter window mode")
        try require(model.backspaceOnEmptyInput() && model.filter == .all, "Backspace must exit")
        app.preferences.commandKeywords["windows"] = "win"
        model.inputText = "win README"
        try require(model.filter == .windows && model.inputText == "README", "Custom trigger must preserve query")
        model.reset()
        try await Task.sleep(for: .milliseconds(300))
        try require(model.filter == .all && model.results.isEmpty, "Cancelled search must not repopulate results")
        try await checkActions(app: app)
        // The native permission branch runs without requesting or changing permissions.
        if !AXIsProcessTrusted() {
            model.inputText = "win "
            try await Task.sleep(for: .milliseconds(400))
            try require(!model.isSearching && model.status != nil && model.results.isEmpty,
                        "Missing permission must be visible without app-only fallback")
            model.reset()
            print("PASS: missing Accessibility permission feedback")
        }
    }
    struct MenuProvider: SearchProvider {
        let source = SearchSource.app
        func search(_ query: String, limit: Int) async -> [SearchResult] {
            LauncherWindowSnapshot.results(from: [
                .init(id: "fixture-window", title: "下载", application: "Finder", applicationPath: "/System/Library/CoreServices/Finder.app")
            ], query: "")
        }
    }

    static func checkActions(app: AppModel) async throws {
        let model = LauncherModel(app: app, searchProviders: [MenuProvider()])
        model.query = "fixture"
        for _ in 0..<60 {
            if !model.isSearching && !model.results.isEmpty { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        model.windowActionCanMoveDisplay = true
        try require(model.secondaryActions.map(\.title) == ["进入全屏", "切换到上一块屏幕", "切换到下一块屏幕", "关闭窗口"], "window menu must expose both actions in order")
        try require(!model.secondaryActions[0].isNegative && model.secondaryActions[3].isNegative, "only close must be red")
        model.windowActionFullScreen = true
        try require(model.secondaryActions.map(\.title) == ["退出全屏", "切换到上一块屏幕", "切换到下一块屏幕", "关闭窗口"], "full-screen window must offer Exit Full Screen")
        model.windowActionFullScreen = nil
        try require(model.secondaryActions.map(\.title) == ["切换到上一块屏幕", "切换到下一块屏幕", "关闭窗口"], "unsupported full-screen windows retain display actions")
        model.windowActionCanMoveDisplay = false
        try require(model.secondaryActions.map(\.title) == ["关闭窗口"], "single display omits display actions")
        try require(app.preferences.shortcut(.windowPreviousDisplay).code == 123
                    && app.preferences.shortcut(.windowPreviousDisplay).modifiers == 512
                    && app.preferences.shortcut(.windowNextDisplay).code == 124
                    && app.preferences.shortcut(.windowNextDisplay).modifiers == 512, "display shortcut defaults must be Shift Left and Right")
        var preferences = app.preferences
        try require(!preferences.setShortcut(.windowPreviousDisplay, preferences.shortcut(.windowNextDisplay)), "display shortcut conflicts must be rejected")
        model.windowActionFullScreen = false
        let controller = LauncherController(model: model)
        NSApp.activate(ignoringOtherApps: true)
        controller.show()
        try await Task.sleep(for: .milliseconds(600))
        defer { controller.hide() }
        guard let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }) else {
            throw NSError(domain: "WindowActionsPanel", code: 1)
        }
        (panel as? LauncherPanel)?.onBlur = {}
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            model.windowActionFullScreen = appearance == .darkAqua
            NSApp.appearance = NSAppearance(named: appearance)
            try await Task.sleep(for: .milliseconds(500))
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                characters: "k", charactersIgnoringModifiers: "k", isARepeat: false, keyCode: 40)!
            try require(model.handleActionKey(event) && model.isActionsMenuPresented, "Command K must open window menu")
            model.windowActionCanMoveDisplay = true
            model.move(3)
            try require(model.actionSelection == 3, "close remains last after display actions")
            try await Task.sleep(for: .milliseconds(350))
            let capture = Process()
            capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-l", String(panel.windowNumber), "build/window-actions-\(appearance.rawValue).png"]
            try capture.run(); capture.waitUntilExit()
            try require(capture.terminationStatus == 0, "window menu screenshot must succeed")
            let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53)!
            try require(model.handleActionKey(escape) && !model.isActionsMenuPresented, "Escape must dismiss menu")
        }
        print("PASS: window actions, negative styling, Command K, menu navigation, Escape, light/dark screenshots")
    }

}
