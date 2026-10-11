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
                let root = FileManager.default.temporaryDirectory.appending(path: "Asky-clipboard-\(UUID())")
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
                if CommandLine.arguments.contains("--preview") { controller.pinned = true }
                controller.show()
                if !CommandLine.arguments.contains("--preview") { controller.pinned = true }
                try await Task.sleep(for: .milliseconds(400))
                @MainActor func panel() -> NSWindow { application.windows.first { $0.title == "剪贴板历史" }! }
                @MainActor func shellFrame() -> NSRect { panel().frame.insetBy(dx: LauncherLayout.shadowPadding, dy: LauncherLayout.shadowPadding) }
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
                var settingsOpened = 0
                app.onOpenSettings = { settingsOpened += 1 }
                let comma = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                            timestamp: 0, windowNumber: panel().windowNumber,
                                            context: nil, characters: ",", charactersIgnoringModifiers: ",",
                                            isARepeat: false, keyCode: 43)!
                panel().sendEvent(comma)
                precondition(settingsOpened == 1, "clipboard Cmd-comma must reach Settings")
                let launcher = LauncherPanel()
                launcher.onOpenSettings = { settingsOpened += 1 }
                launcher.sendEvent(comma)
                precondition(settingsOpened == 2, "launcher Cmd-comma must reach Settings")
                let modifiedComma = NSEvent.keyEvent(with: .keyDown, location: .zero,
                    modifierFlags: [.command, .shift], timestamp: 0, windowNumber: 0, context: nil,
                    characters: "<", charactersIgnoringModifiers: ",", isARepeat: false, keyCode: 43)!
                precondition(!SettingsShortcut.matches(modifiedComma), "extra modifiers must not open Settings")
                if CommandLine.arguments.contains("--settings-shortcut") {
                    controller.hide()
                    try? FileManager.default.removeItem(at: root)
                    print("Launcher and clipboard Cmd-comma event routing passed")
                    exit(0)
                }
                precondition(controller.items.count == 4)
                precondition(panel().frame.height == 244 + LauncherLayout.shadowPadding * 2)
                precondition(controller.selection == 0, "first card is selected by default")
                controller.moveSelection(1)
                precondition(controller.selection == 1)
                controller.moveSelection(-5)
                precondition(controller.selection == 0)
                let notes = ClipboardAccess.sourceIcon(bundleID: "com.apple.Notes", name: "备忘录")
                precondition(notes != nil, "bundle ID resolves icons for apps that are not running")
                // A vertical wheel event becomes horizontal so cards scroll without Shift.
                let wheel = NSEvent(cgEvent: CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                                                     wheel1: -60, wheel2: 0, wheel3: 0)!)!
                let sideways = ClipboardScroll.horizontal(wheel)!
                precondition(sideways.scrollingDeltaY == 0 && sideways.scrollingDeltaX == wheel.scrollingDeltaY)
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
                controller.pinned = false
                controller.togglePinned()
                precondition(panel().level == .floating)
                controller.togglePinned()
                precondition(panel().level == .normal)
                // Drive hover callbacks explicitly without the live pointer overriding timed checks.
                controller.togglePinned()
                panel().ignoresMouseEvents = true
                application.windows.first { $0.title == "剪贴板完整预览" }!.ignoresMouseEvents = true
                @MainActor func card(_ minX: CGFloat) -> NSRect { NSRect(x: minX, y: shellFrame().minY + 12, width: 264, height: 160) }
                @MainActor func previewFor(_ item: ClipboardItem, _ anchor: NSRect) async throws -> NSWindow {
                    controller.dismissPreview()
                    controller.hover(item, frame: anchor, inside: true)
                    try await Task.sleep(for: .milliseconds(1700))
                    let window = application.windows.first { $0.title == "剪贴板完整预览" }!
                    precondition(window.isVisible, "preview for \(item.contentHash) at \(anchor) panel \(panel().frame) visible \(panel().isVisible)")
                    return window
                }
                let middle = card(shellFrame().midX - 132)
                controller.dismissPreview()
                let pendingPreview = application.windows.first { $0.title == "剪贴板完整预览" }!
                controller.hover(picture, frame: middle, inside: true)
                try await Task.sleep(for: .milliseconds(1000))
                precondition(!pendingPreview.isVisible, "brief hover must not show the preview")
                controller.hover(picture, frame: middle, inside: false)
                try await Task.sleep(for: .milliseconds(700))
                precondition(!pendingPreview.isVisible, "leaving cancels the pending preview")
                var preview = try await previewFor(picture, middle)
                if CommandLine.arguments.contains("--hover-delay") {
                    controller.hide()
                    precondition(!preview.isVisible, "closing releases the preview")
                    try? FileManager.default.removeItem(at: root)
                    print("Clipboard 1.5-second hover delay, cancellation and preview release passed")
                    exit(0)
                }
                precondition(preview.frame.minY >= preview.screen!.visibleFrame.minY)
                precondition(abs(preview.frame.maxY - (shellFrame().minY - 8)) < 0.5, "preview sits 8 pt below the panel")
                precondition(abs(preview.frame.midX - middle.midX) < 0.5, "preview is centered under the card")
                try snapshot(preview, "image-preview")
                let leftCard = card(shellFrame().minX + 12)
                preview = try await previewFor(picture, leftCard)
                precondition(abs(preview.frame.minX - leftCard.minX) < 0.5, "left edge card aligns preview left")
                let rightCard = card(shellFrame().maxX - 12 - 264)
                preview = try await previewFor(picture, rightCard)
                precondition(abs(preview.frame.maxX - rightCard.maxX) < 0.5, "right edge card aligns preview right")
                // A tall portrait image must shrink to fit beside the panel rather than cover it.
                let tall = NSImage(size: NSSize(width: 400, height: 2400))
                tall.lockFocus(); NSColor.systemPink.setFill(); NSRect(x: 0, y: 0, width: 400, height: 2400).fill(); tall.unlockFocus()
                let tallPath = root.appending(path: "tall.tiff")
                try tall.tiffRepresentation!.write(to: tallPath)
                let portrait = ClipboardItem(kind: .image, filePath: tallPath.path, byteSize: 1000, contentHash: "tall")
                preview = try await previewFor(portrait, middle)
                precondition(!preview.frame.intersects(shellFrame()), "preview never covers the panel")
                precondition(preview.frame.width < 464, "tall image narrows to its aspect ratio")
                precondition(abs(preview.frame.midX - middle.midX) < 0.5, "tall preview is centered under the card")
                // Real card anchors must report each card's on-screen frame.
                @MainActor func anchors(_ view: NSView) -> [NSView] {
                    (String(describing: type(of: view)).contains("AnchorView") ? [view] : []) + view.subviews.flatMap(anchors)
                }
                let frames = anchors(panel().contentView!).compactMap { v in v.window.map { $0.convertToScreen(v.convert(v.bounds, to: nil)) } }
                    .sorted { $0.minX < $1.minX }
                print("card anchors:", frames.map { "\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))x\(Int($0.height))" })
                precondition(frames.count >= 2 && frames.allSatisfy { abs($0.width - 264) < 1 && abs($0.height - 160) < 1 })
                precondition(abs(frames[0].minX - (shellFrame().minX + 12)) < 1, "first anchor sits at the panel's leading inset")
                let long = controller.items.first { $0.contentHash == "long" }!
                preview = try await previewFor(long, middle)
                precondition(preview.frame.height <= 440, "long text is capped and scrolls")
                try snapshot(preview, "text-preview")
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
