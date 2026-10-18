import AppKit
import Search

/// Live Spotlight acceptance against the indexed parent of this checkout.
@main @MainActor
private enum LauncherFileSearchRegression {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                let expected = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent()
                let root = FileManager.default.temporaryDirectory.appending(path: "Asky-file-search-\(UUID())")
                defer { try? FileManager.default.removeItem(at: root) }
                for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                    application.appearance = NSAppearance(named: appearance)
                    let app = try AppModel(root: root.appending(path: appearance.rawValue))
                    let model = LauncherModel(app: app, chromeBookmarkAccessAllowed: false)
                    let controller = LauncherController(model: model)
                    controller.show()
                    // Leave typing focus with the user's app during this read-only check.
                    if let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }) as? LauncherPanel {
                        panel.onBlur = {}
                        panel.resignKey()
                    }
                    application.deactivate()
                    model.query = expected.lastPathComponent
                    for _ in 0..<40 {
                        if model.results.contains(where: { $0.target.identifier == expected.path }) { break }
                        try await Task.sleep(for: .milliseconds(50))
                    }
                    guard let index = model.results.firstIndex(where: { $0.source == .file && $0.target.identifier == expected.path }) else {
                        throw NSError(domain: "LiveFileSearch", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: "Missing \(expected.path): \(model.results.map(\.title))"])
                    }
                    model.selection = index
                    guard model.canEnterSelectedFolder else { throw NSError(domain: "LiveFileSearch", code: 2) }
                    try await Task.sleep(for: .milliseconds(350))
                    if let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }) {
                        let capture = Process()
                        capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
                        capture.arguments = ["-x", "-l", String(panel.windowNumber), "build/file-search-\(appearance.rawValue).png"]
                        try capture.run()
                        capture.waitUntilExit()
                        guard capture.terminationStatus == 0 else { throw NSError(domain: "LiveFileSearch", code: 3) }
                    }
                    print("\(appearance.rawValue): \(model.results.filter { $0.source == .file }.map(\.target.identifier))")
                    controller.hide()
                }
                print("Live file search regression passed")
                exit(0)
            } catch {
                fputs("Live file search failed: \(error)\n", stderr)
                exit(1)
            }
        }
        application.run()
    }
}
