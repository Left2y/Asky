import AppKit
import ToolService

@MainActor
enum AppInstallationPrompt {
    /// Runs before models, hotkeys and permission flows are initialized.
    static func handleLaunchIfNeeded() -> Bool {
        guard ToolService.appInstallationRequired else { return false }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("安装 Asky", comment: "")
        if let installed = ToolService.existingInstalledApp {
            alert.informativeText = NSLocalizedString("应用程序中已有 Asky，请打开已安装的版本。", comment: "")
            alert.addButton(withTitle: NSLocalizedString("打开已安装的版本", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("退出", comment: ""))
            if alert.runModal() == .alertFirstButtonReturn {
                do { try ToolService.reopenInstalledAppAfterExit(at: installed) }
                catch { showError(error) }
            }
            NSApp.terminate(nil)
        } else {
            alert.informativeText = NSLocalizedString("Asky 需要先安装到“应用程序”，才能正常授权和更新。安装后会自动重新打开。", comment: "")
            alert.addButton(withTitle: NSLocalizedString("安装并重新打开", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("退出", comment: ""))
            guard alert.runModal() == .alertFirstButtonReturn else {
                NSApp.terminate(nil)
                return true
            }
            let progress = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 100),
                                   styleMask: [.titled], backing: .buffered, defer: false)
            progress.title = NSLocalizedString("安装 Asky", comment: "")
            let label = NSTextField(labelWithString: NSLocalizedString("正在安装…", comment: ""))
            label.frame = NSRect(x: 24, y: 35, width: 272, height: 24)
            progress.contentView?.addSubview(label)
            progress.center()
            progress.makeKeyAndOrderFront(nil)
            Task {
                do {
                    let installed = try await ToolService.installAppInApplications()
                    try ToolService.reopenInstalledAppAfterExit(at: installed)
                } catch { showError(error) }
                progress.close()
                NSApp.terminate(nil)
            }
        }
        return true
    }

    private static func showError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("无法安装 Asky", comment: "")
        alert.informativeText = error.localizedDescription + "\n\n" + NSLocalizedString("请在 Finder 中将 Asky.app 拖入“应用程序”，然后从那里重新打开。", comment: "")
        alert.addButton(withTitle: NSLocalizedString("打开应用程序文件夹", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("退出", comment: ""))
        if alert.runModal() == .alertFirstButtonReturn { ToolService.revealAppInstallationFolder() }
    }
}
