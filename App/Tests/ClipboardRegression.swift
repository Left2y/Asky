import AppKit
import SwiftUI
import LocalStore
import ToolService

@main @MainActor
enum ClipboardRegression {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                let root = FileManager.default.temporaryDirectory.appending(path: "KulaHere-clipboard-\(UUID())")
                let app = try AppModel(root: root)
                let store = ClipboardStore(app.store)
                let text = ClipboardItem(kind: .text, text: "Paste anywhere, this is one example text", byteSize: 42,
                                         sourceApp: "Safari", contentHash: "short", createdAt: Date().addingTimeInterval(4))
                let image = NSImage(size: NSSize(width: 640, height: 360))
                image.lockFocus()
                NSGradient(starting: .systemBlue, ending: .systemTeal)?.draw(in: NSRect(x: 0, y: 0, width: 640, height: 360), angle: 35)
                NSColor.white.setFill()
                NSBezierPath(ovalIn: NSRect(x: 220, y: 80, width: 200, height: 200)).fill()
                image.unlockFocus()
                let path = root.appending(path: "fixture.tiff")
                try image.tiffRepresentation!.write(to: path)
                let picture = ClipboardItem(kind: .image, filePath: path.path, byteSize: 1000, sourceApp: "Safari",
                                            contentHash: "picture", createdAt: Date().addingTimeInterval(3))
                try store.insert(text)
                try store.insert(picture)
                try store.insert(ClipboardItem(kind: .text, text: String(repeating: "完整文字可以滚动查看。\n", count: 60), byteSize: 2000,
                                               contentHash: "long", createdAt: Date().addingTimeInterval(2)))
                try store.insert(ClipboardItem(kind: .text, text: "Another clipboard card", byteSize: 22, contentHash: "fourth"))
                let controller = ClipboardController(app: app)
                controller.show()
                try await Task.sleep(for: .milliseconds(400))
                @MainActor func panel() -> NSWindow { application.windows.first { $0.title == "剪贴板历史" }! }
                @MainActor func snapshot(_ window: NSWindow, _ name: String) throws {
                    let view = window.contentView!
                    view.layoutSubtreeIfNeeded()
                    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(filePath: "build/clipboard-\(name).png"))
                }
                if CommandLine.arguments.contains("--preview") {
                    // Retain the controller while a human or computer-use inspects the actual window.
                    while true { try await Task.sleep(for: .seconds(1)); _ = controller.items.count }
                }
                precondition(controller.items.count == 4)
                precondition(panel().frame.height == 244)
                panel().makeFirstResponder(nil)
                for appearance in ["light", "dark"] {
                    controller.query = ""
                    app.preferences.appearance = appearance
                    try await Task.sleep(for: .milliseconds(250))
                    try snapshot(panel(), appearance)
                }
                controller.query = "example"
                precondition(controller.items.count == 1 && controller.items.first?.id == text.id)
                controller.query = ""
                controller.pinItem(picture)
                precondition(controller.items.first?.id == picture.id && controller.items.first?.pinned == true)
                controller.togglePinned()
                precondition(panel().level == .floating)
                controller.togglePinned()
                precondition(panel().level == .normal)
                controller.hover(picture, frame: panel().frame, inside: true)
                try await Task.sleep(for: .milliseconds(450))
                let preview = application.windows.first { $0.title == "剪贴板完整预览" }!
                precondition(preview.isVisible)
                precondition(preview.frame.minY >= preview.screen!.visibleFrame.minY)
                try snapshot(preview, "image-preview")
                controller.dismissPreview()
                precondition(!preview.isVisible)
                controller.delete(picture)
                precondition(!controller.items.contains { $0.id == picture.id })
                precondition(!FileManager.default.fileExists(atPath: path.path))
                controller.query = "no-match"
                precondition(controller.items.isEmpty)
                try snapshot(panel(), "empty")
                controller.hide()
                precondition(controller.items.isEmpty && panel().contentView == nil && !panel().isVisible)
                try? FileManager.default.removeItem(at: root)
                print("Clipboard native snapshots, search, pin, delete, preview placement and release passed")
                exit(0)
            } catch { fputs("Clipboard regression failed: \(error)\n", stderr); exit(1) }
        }
        application.run()
    }
}
