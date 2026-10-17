import AppKit
import SwiftUI
import LocalStore
import ToolService
import AVKit

@main @MainActor
enum ClipboardRegression {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                if CommandLine.arguments.contains("--toast-surfaces") {
                    try await verifyToastSurfaces()
                    exit(0)
                }
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
                if CommandLine.arguments.contains("--chat-images") {
                    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
                    let monitor = ClipboardMonitor(app: app)
                    monitor.start()
                    for fileOnly in [false, true] {
                        let original = root.appending(path: "img_v3_02167_827d327e.jpg")
                        try bitmap.representation(using: .jpeg, properties: [:])!.write(to: original)
                        NSPasteboard.general.clearContents()
                        if fileOnly {
                            NSPasteboard.general.writeObjects([original as NSURL])
                        } else {
                            NSPasteboard.general.setData(image.tiffRepresentation!, forType: .tiff)
                        }
                        NSPasteboard.general.setString(original.lastPathComponent, forType: .string)
                        let expectedCount = fileOnly ? 2 : 1
                        for _ in 0..<50 {
                            if store.recent(limit: 10).count == expectedCount { break }
                            try await Task.sleep(for: .milliseconds(100))
                        }
                        let items = store.recent(limit: 10)
                        precondition(items.count == expectedCount && items.allSatisfy { $0.kind == .image },
                                     "chat image plus filename must record an image")
                        let recorded = items.first!
                        try FileManager.default.removeItem(at: original)
                        precondition(recorded.thumbPath.flatMap(NSImage.init(contentsOfFile:)) != nil,
                                     "chat image must have a usable thumbnail")
                        precondition(ClipboardAccess.copy(recorded), "image must copy after source file removal")
                        let restored = NSBitmapImageRep(data: ClipboardAccess.snapshot().image!)!
                        precondition(restored.pixelsWide == bitmap.pixelsWide && restored.pixelsHigh == bitmap.pixelsHigh,
                                     "copy must restore image pixels instead of filename")
                        try await Task.sleep(for: .milliseconds(1200))
                        precondition(store.recent(limit: 10).count == expectedCount, "restore must not add a text row")
                    }
                    monitor.stop()
                    let controller = ClipboardController(app: app)
                    controller.pinned = true
                    controller.show()
                    try await Task.sleep(for: .milliseconds(500))
                    let view = application.windows.first { $0.title == "剪贴板历史" }!.contentView!
                    view.layoutSubtreeIfNeeded()
                    let capture = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                    view.cacheDisplay(in: view.bounds, to: capture)
                    try capture.representation(using: .png, properties: [:])!.write(to: URL(filePath: "build/clipboard-chat-images.png"))
                    print("Chat image monitoring, thumbnails, temporary-file survival and image copy passed")
                    application.terminate(nil)
                    return
                }
                let picture = ClipboardItem(kind: .image, filePath: path.path, byteSize: 1000, sourceApp: "Safari",
                                            contentHash: "picture", createdAt: Date().addingTimeInterval(3))
                try store.insert(text)
                try store.insert(picture)
                try store.insert(ClipboardItem(kind: .text, text: String(repeating: "完整文字可以滚动查看。\n", count: 60), byteSize: 2000,
                                               contentHash: "long", createdAt: Date().addingTimeInterval(2)))
                try store.insert(ClipboardItem(kind: .text, text: "Another clipboard card", byteSize: 22, contentHash: "fourth"))
                let fileTest = CommandLine.arguments.contains("--files")
                let fileURLs = [root.appending(path: "复制文件.txt"), root.appending(path: "second.pdf")]
                if fileTest {
                    _ = try store.delete(ids: store.recent(limit: 20).map(\.id))
                    for url in fileURLs { try Data("real file: \(url.lastPathComponent)".utf8).write(to: url) }
                    let monitor = ClipboardMonitor(app: app)
                    monitor.start()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects(fileURLs.map { $0 as NSURL })
                    NSPasteboard.general.setString("复制文件.txt\nsecond.pdf", forType: .string)
                    for _ in 0..<30 {
                        if store.recent(limit: 1).first?.kind == .file { break }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    monitor.stop()
                    let recorded = store.recent(limit: 1).first!
                    precondition(recorded.kind == .file && recorded.filePaths == fileURLs.map(\.path), "monitor must prioritize complete file selection")
                    monitor.start()
                    precondition(ClipboardAccess.copy(recorded), "file selection must copy")
                    precondition(ClipboardAccess.snapshot().fileURLs == fileURLs, "copy must restore all URLs")
                    try await Task.sleep(for: .milliseconds(1200))
                    monitor.stop()
                    let afterRestore = store.recent(limit: 1).first!
                    precondition(afterRestore.id == recorded.id && afterRestore.createdAt == recorded.createdAt &&
                        afterRestore.sourceApp == recorded.sourceApp && afterRestore.sourceBundleID == recorded.sourceBundleID,
                        "restoring history must not overwrite source metadata or reorder the card")
                }
                let controller = ClipboardController(app: app)
                let dragPreview = CommandLine.arguments.contains("--drag-preview")
                let dragTest = CommandLine.arguments.contains("--drag") || fileTest
                if CommandLine.arguments.contains("--preview") || CommandLine.arguments.contains("--layouts") || dragPreview || dragTest { controller.pinned = true }
                controller.show()
                if !CommandLine.arguments.contains("--preview"), !dragPreview { controller.pinned = true }
                try await Task.sleep(for: .milliseconds(400))
                @MainActor func panel() -> NSWindow { application.windows.first { $0.title == "剪贴板历史" }! }
                @MainActor func shellFrame() -> NSRect { panel().frame }
                @MainActor func snapshot(_ window: NSWindow, _ name: String) throws {
                    if CommandLine.arguments.contains("--video-preview") {
                        // AVPlayer renders in a composited layer, absent from cacheDisplay bitmaps.
                        let capture = Process()
                        capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
                        capture.arguments = ["-x", "-l", String(window.windowNumber), "build/clipboard-\(name).png"]
                        try capture.run()
                        capture.waitUntilExit()
                        precondition(capture.terminationStatus == 0)
                        return
                    }
                    let view = window.contentView!
                    view.layoutSubtreeIfNeeded()
                    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(filePath: "build/clipboard-\(name).png"))
                }
                if CommandLine.arguments.contains("--filters") || CommandLine.arguments.contains("--filter-preview") {
                    let movie = ClipboardItem(kind: .file, text: "sample movie.mp4", filePath: root.appending(path: "missing.mp4").path,
                                              byteSize: 10, contentHash: "filter-movie")
                    let document = ClipboardItem(kind: .file, text: "sample document.pdf", filePath: root.appending(path: "missing.pdf").path,
                                                 byteSize: 10, contentHash: "filter-document")
                    try store.insert(movie)
                    try store.insert(document)
                    for i in 0..<105 {
                        try store.insert(ClipboardItem(kind: .text, text: "newer sample text \(i)", byteSize: 20, contentHash: "filter-text-\(i)"))
                    }
                    controller.refresh()
                    precondition(controller.filter == .all && controller.items.count == 100)
                    for (filter, ids) in [(ClipboardFilter.image, [picture.id]), (.video, [movie.id]), (.file, [document.id])] {
                        controller.filter = filter
                        precondition(Set(controller.items.map(\.id)) == Set(ids), "category must find older matching records")
                        precondition(controller.selection == 0)
                    }
                    controller.filter = .text
                    precondition(controller.items.count == 100 && controller.items.allSatisfy { $0.kind == .text })
                    controller.query = "sample"
                    controller.filter = .file
                    precondition(controller.items.map(\.id) == [document.id])
                    controller.filter = .image
                    precondition(controller.items.isEmpty, "query and type must both match")
                    controller.query = ""
                    controller.filter = .video
                    app.preferences.clipboardLayout = .list
                    controller.updateLayout()
                    try await Task.sleep(for: .milliseconds(250))
                    try snapshot(panel(), "filter-list-video")
                    controller.hide()
                    controller.show()
                    precondition(controller.filter == .all, "new opening defaults to all")
                    controller.toggleFilterMenu()
                    try await Task.sleep(for: .milliseconds(250))
                    let menu = application.windows.first { $0.title == "筛选剪贴板" }!
                    precondition(menu.isVisible && menu.parent == panel())
                    precondition(abs(menu.frame.maxY - (panel().frame.maxY - 52)) < 0.5,
                                 "menu sits 6pt below the filter button")
                    precondition(abs(menu.frame.maxX - (panel().frame.maxX - 56)) < 0.5,
                                 "menu right edge aligns with the filter button")
                    try snapshot(menu, "filter-menu")
                    try snapshot(panel(), "filter-header")
                    if CommandLine.arguments.contains("--filter-preview") {
                        try await Task.sleep(for: .seconds(90))
                    }
                    controller.isFilterMenuPresented = false
                    precondition(!menu.isVisible)
                    controller.hide()
                    print("Clipboard filters passed: all categories, older history, search intersection, both layouts, reset and menu lifecycle")
                    application.terminate(nil)
                    return
                }
                if CommandLine.arguments.contains("--video-preview") {
                    let url = URL(filePath: ProcessInfo.processInfo.environment["ASKY_CLIPBOARD_VIDEO_FIXTURE"]!)
                    let movie = ClipboardItem(kind: .file, text: url.lastPathComponent, filePath: url.path,
                        filePaths: [url.path], byteSize: 220, sourceApp: "微信", contentHash: "movie")
                    try store.insert(movie)
                    controller.query = url.lastPathComponent
                    precondition(controller.selectedItem?.id == movie.id)
                    func previews(in view: NSView) -> [AVPlayerView] {
                        (view as? AVPlayerView).map { [$0] } ?? view.subviews.flatMap { previews(in: $0) }
                    }
                    @MainActor func verifyControlInsets(_ preview: AVPlayerView) async throws {
                        @MainActor func glass(in view: NSView) -> NSView? {
                            if view is NSGlassEffectView, view.bounds.width > 100, view.bounds.height >= 40 { return view }
                            return view.subviews.lazy.compactMap { glass(in: $0) }.first
                        }
                        let center = preview.window!.convertPoint(toScreen: preview.convert(
                            NSPoint(x: preview.bounds.midX, y: preview.bounds.midY), to: nil))
                        CGWarpMouseCursorPosition(CGPoint(x: center.x, y: NSScreen.screens[0].frame.maxY - center.y))
                        preview.mouseEntered(with: NSEvent.mouseEvent(with: .mouseMoved, location: .zero,
                            modifierFlags: [], timestamp: 0, windowNumber: preview.window!.windowNumber,
                            context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!)
                        let windowFrame = preview.window!.frame
                        let playerFrame = preview.convert(preview.bounds, to: nil)
                        @MainActor final class Frames {
                            var firstControlsFrame: NSRect?
                            var count = 0
                        }
                        let frames = Frames()
                        // Sample after the player's pre-display layout observer,
                        // rather than midway through AVKit's asynchronous updates.
                        let observer = CFRunLoopObserverCreateWithHandler(nil,
                            CFRunLoopActivity.beforeWaiting.rawValue, true, 1000) { _, _ in
                            MainActor.assumeIsolated {
                                precondition(preview.window!.frame == windowFrame &&
                                    preview.convert(preview.bounds, to: nil) == playerFrame,
                                    "hover window and video must not move when controls appear")
                                if let surface = glass(in: preview) {
                                    let frame = preview.convert(surface.bounds, from: surface)
                                    if let first = frames.firstControlsFrame {
                                        precondition(abs(frame.minY - first.minY) < 0.5,
                                            "controls must not jump between displayed frames")
                                    } else { frames.firstControlsFrame = frame }
                                    frames.count += 1
                                }
                            }
                        }
                        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
                        try await Task.sleep(for: .milliseconds(400))
                        CFRunLoopObserverInvalidate(observer)
                        precondition(frames.count > 0, "must sample displayed playback controls")
                        preview.layoutSubtreeIfNeeded()
                        guard let surface = glass(in: preview) else {
                            preconditionFailure("native floating controls must have a glass surface")
                        }
                        let frame = preview.convert(surface.bounds, from: surface)
                        let left = frame.minX - preview.bounds.minX
                        let right = preview.bounds.maxX - frame.maxX
                        let bottom = preview.isFlipped ? preview.bounds.maxY - frame.maxY : frame.minY - preview.bounds.minY
                        precondition(abs(left - right) < 1 && abs(left - bottom) < 1,
                            "floating controls must have equal left/right/bottom gaps: \(left), \(right), \(bottom)")
                        print("Video control gaps: \(left), \(right), \(bottom) pt")
                    }
                    app.preferences.clipboardLayout = .list
                    controller.updateLayout()
                    try await Task.sleep(for: .seconds(3))
                    let listPreview = previews(in: panel().contentView!)
                    precondition(listPreview.count == 1 && (listPreview[0].player?.currentItem?.asset as? AVURLAsset)?.url == url)
                    let player = listPreview[0].player!
                    precondition(player.currentItem?.status == .readyToPlay && player.rate == 0)
                    player.play()
                    try await Task.sleep(for: .milliseconds(600))
                    precondition(player.currentTime().seconds > 0.1, "video playback must advance")
                    player.pause()
                    precondition(listPreview[0].bounds.height > 100)
                    let listSize = listPreview[0].bounds.size
                    precondition(listSize.height > 200, "list video must fill the preview height before controls appear")
                    try await verifyControlInsets(listPreview[0])
                    try await Task.sleep(for: .seconds(2))
                    precondition(listPreview[0].bounds.size == listSize,
                        "floating controls must not change the list video size")
                    print("Stable list video size: \(listSize)")
                    try snapshot(panel(), "video-list")
                    controller.query = "Another"
                    try await Task.sleep(for: .milliseconds(300))
                    precondition(previews(in: panel().contentView!).isEmpty && player.currentItem == nil,
                        "switching selection removes movie preview and releases its asset")
                    controller.query = url.lastPathComponent
                    app.preferences.clipboardLayout = .cards
                    controller.updateLayout()
                    let pointer = NSEvent.mouseLocation
                    let screenTop = NSScreen.screens[0].frame.maxY
                    defer { CGWarpMouseCursorPosition(CGPoint(x: pointer.x, y: screenTop - pointer.y)) }
                    // Keep real tracking exits from cancelling the hover under test.
                    CGWarpMouseCursorPosition(CGPoint(x: panel().frame.minX + 100,
                        y: screenTop - (panel().frame.minY + 100)))
                    controller.hover(movie, frame: panel().frame, inside: true)
                    try await Task.sleep(for: .seconds(3))
                    let hover = application.windows.first { $0.title == "剪贴板完整预览" && $0.isVisible }!
                    let hoverPreview = previews(in: hover.contentView!)
                    precondition(hoverPreview.count == 1 && (hoverPreview[0].player?.currentItem?.asset as? AVURLAsset)?.url == url)
                    precondition(hoverPreview[0].player?.currentItem?.status == .readyToPlay)
                    precondition(hover.frame.height > 200, "video hover must have room for playback")
                    let hoverSize = hoverPreview[0].bounds.size
                    try await verifyControlInsets(hoverPreview[0])
                    try await Task.sleep(for: .seconds(2))
                    precondition(hoverPreview[0].bounds.size == hoverSize,
                        "floating controls must not change the hover video size")
                    print("Stable hover video size: \(hoverSize)")
                    try snapshot(hover, "video-hover")
                    controller.dismissPreview()
                    precondition(!hover.isVisible && hover.contentView == nil)
                    controller.copySelection()
                    precondition(ClipboardAccess.snapshot().fileURLs == [url], "video copies as original file")
                    controller.hide()
                    print("Video list and hover previews, selection switching, dismissal and original-file copy passed")
                    application.terminate(nil)
                    return
                }
                if CommandLine.arguments.contains("--layouts") {
                    let legacy = try JSONDecoder().decode(SettingsPreferences.self, from: Data("{}".utf8))
                    precondition(legacy.clipboardLayout == .cards)
                    precondition(controller.layout == .cards && panel().frame.height == 244)
                    controller.selection = 1
                    let selectedID = controller.selectedItem!.id
                    app.preferences.clipboardLayout = controller.layout == .cards ? .list : .cards
                    controller.updateLayout()
                    try await Task.sleep(for: .milliseconds(400))
                    precondition(controller.selectedItem?.id == selectedID && panel().frame.height == 560)
                    try snapshot(panel(), "layout-list-image")
                    controller.selection = 2
                    try await Task.sleep(for: .milliseconds(200))
                    try snapshot(panel(), "layout-list-text")
                    // Exercise the rendered row mouse surface and the search field's Return delegate.
                    @MainActor func descendants<T: NSView>(_ view: NSView, of type: T.Type) -> [T] {
                        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, of: type) }
                    }
                    let rows = descendants(panel().contentView!, of: ClipboardCardMouseView.self)
                    precondition(!rows.isEmpty)
                    controller.status = nil
                    let down = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [],
                        timestamp: 0, windowNumber: panel().windowNumber, context: nil, eventNumber: 0,
                        clickCount: 1, pressure: 1)!
                    let up = NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [],
                        timestamp: 0, windowNumber: panel().windowNumber, context: nil, eventNumber: 0,
                        clickCount: 1, pressure: 0)!
                    rows[0].mouseDown(with: down)
                    rows[0].mouseUp(with: up)
                    precondition(controller.selectedItem?.id == controller.items[0].id)
                    precondition(NSPasteboard.general.string(forType: .string) == controller.items[0].text,
                                 "click must select and copy the clicked row")
                    precondition(controller.status == NSLocalizedString("已复制", comment: "") && controller.isVisible)
                    controller.query = "Another"
                    try await Task.sleep(for: .milliseconds(200))
                    controller.status = nil
                    NSPasteboard.general.clearContents()
                    let field = descendants(panel().contentView!, of: CompletionTextField.self).first!
                    let delegate = field.delegate as! LauncherSearchField.Coordinator
                    precondition(delegate.control(field, textView: NSTextView(),
                        doCommandBy: #selector(NSResponder.insertNewline(_:))))
                    precondition(NSPasteboard.general.string(forType: .string) == "Another clipboard card",
                                 "Return must copy the selected list row")
                    precondition(controller.status == NSLocalizedString("已复制", comment: "") && controller.isVisible,
                                 "Return must show copy feedback and keep the list open")
                    try await Task.sleep(for: .milliseconds(200))
                    let toast = panel().childWindows!.first { $0.isVisible && $0.frame.minY > panel().frame.maxY }
                    precondition(toast != nil, "copy toast must be visible above the list")
                    try snapshot(toast!, "layout-list-copy-toast")
                    try snapshot(panel(), "layout-list-copy")
                    precondition(controller.items.count == 1 && controller.layout == .list)
                    controller.pinItem(controller.items[0])
                    precondition(controller.items[0].pinned)
                    controller.copySelection()
                    precondition(NSPasteboard.general.string(forType: .string) == "Another clipboard card")
                    app.preferences.clipboardLayout = controller.layout == .cards ? .list : .cards
                    controller.updateLayout()
                    precondition(controller.query == "Another" && panel().frame.height == 244)
                    controller.query = ""
                    try await Task.sleep(for: .milliseconds(200))
                    try snapshot(panel(), "layout-cards")
                    app.preferences.clipboardLayout = controller.layout == .cards ? .list : .cards
                    controller.updateLayout()
                    try await Task.sleep(for: .milliseconds(200))
                    try snapshot(panel(), "layout-list")
                    let reloaded = try AppModel(root: root)
                    precondition(reloaded.preferences.clipboardLayout == .list)
                    print("Clipboard settings layout, persistence, legacy default, selection, filtering, pinning and copy passed")
                    if CommandLine.arguments.contains("--layout-preview") {
                        try await Task.sleep(for: .seconds(300))
                    }
                    controller.hide()
                    app.settingsTab = SettingsPage.general.rawValue
                    let settingsWindow = SettingsWindow.make(app: app)
                    settingsWindow.makeKeyAndOrderFront(nil)
                    try await Task.sleep(for: .milliseconds(500))
                    func scrollToClipboard(_ view: NSView) {
                        if let scroll = view as? NSScrollView, scroll.frame.width > 300,
                           let document = scroll.documentView {
                            scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, document.bounds.height - scroll.contentSize.height)))
                            scroll.reflectScrolledClipView(scroll.contentView)
                        }
                        for child in view.subviews { scrollToClipboard(child) }
                    }
                    scrollToClipboard(settingsWindow.contentView!)
                    try await Task.sleep(for: .milliseconds(200))
                    try snapshot(settingsWindow, "layout-settings")
                    settingsWindow.orderOut(nil)
                    application.terminate(nil)
                    return
                }
                if dragPreview || dragTest {
                    // Keep the initial launch stable, then enable the real unpinned dismissal shield.
                    panel().makeKey()
                    controller.pinned = false
                }
                if dragTest {
                    let externalPoint = ProcessInfo.processInfo.environment["ASKY_CLIPBOARD_DROP_POINT"]?
                        .split(separator: ",").compactMap { Double($0) }
                    let draggingImage = ProcessInfo.processInfo.environment["ASKY_CLIPBOARD_DRAG_IMAGE"] == "1"
                    let screen = panel().screen!.visibleFrame
                    let destination = NSWindow(contentRect: NSRect(x: screen.minX + 24, y: screen.minY + 24,
                        width: 240, height: 160), styleMask: [.titled], backing: .buffered, defer: false)
                    destination.title = "Clipboard drag destination"
                    let fileReceiver = ClipboardFileDropReceiver(frame: NSRect(x: 0, y: 0, width: 240, height: 160))
                    let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 160))
                    editor.isRichText = false
                    destination.contentView = fileTest ? fileReceiver : editor
                    if externalPoint == nil { destination.orderFrontRegardless() }
                    panel().makeKey()
                    controller.pinned = false
                    try await Task.sleep(for: .milliseconds(200))
                    func mouse(_ type: CGEventType, _ point: NSPoint) {
                        let location = CGPoint(x: point.x, y: NSScreen.screens[0].frame.maxY - point.y)
                        CGWarpMouseCursorPosition(location)
                        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location,
                            mouseButton: .left)
                        event?.flags = []
                        event?.post(tap: .cghidEventTap)
                    }
                    let start = NSPoint(x: shellFrame().minX + 100 + (draggingImage ? 276 : 0), y: shellFrame().minY + 100)
                    let end: NSPoint
                    if let externalPoint {
                        precondition(externalPoint.count == 2, "ASKY_CLIPBOARD_DROP_POINT must be screen x,y")
                        end = NSPoint(x: externalPoint[0], y: NSScreen.screens[0].frame.maxY - externalPoint[1])
                    } else {
                        end = destination.convertToScreen(NSRect(x: 40, y: 80, width: 1, height: 1)).origin
                    }
                    let clipboardChangeBeforeDrag = ClipboardAccess.changeCount
                    mouse(.leftMouseDown, start)
                    try await Task.sleep(for: .milliseconds(150))
                    for step in 1...30 {
                        let progress = CGFloat(step) / 30
                        mouse(.leftMouseDragged, NSPoint(x: start.x + (end.x - start.x) * progress,
                            y: start.y + (end.y - start.y) * progress))
                        try await Task.sleep(for: .milliseconds(30))
                    }
                    try await Task.sleep(for: .milliseconds(150))
                    mouse(.leftMouseUp, end)
                    try await Task.sleep(for: .milliseconds(500))
                    if externalPoint == nil {
                        precondition(ClipboardAccess.changeCount == clipboardChangeBeforeDrag,
                            "dragging must leave the system clipboard unchanged")
                        if fileTest {
                            precondition(fileReceiver.urls == fileURLs, "native destination must receive every original URL")
                            for url in fileReceiver.urls {
                                let received = try Data(contentsOf: url)
                                precondition(received == Data("real file: \(url.lastPathComponent)".utf8))
                            }
                        } else {
                            precondition(editor.string == text.text, "native text destination must receive the card contents")
                        }
                    }
                    if panel().isVisible {
                        fputs("Drag not accepted: source=\(start), destination=\(end), status=\(controller.status ?? "none")\n", stderr)
                    }
                    precondition(!panel().isVisible, "accepted unpinned drag must close the source panel")
                    destination.orderOut(nil)
                    try? FileManager.default.removeItem(at: root)
                    if fileTest { print("File monitor, history copy, real mouse multi-file drag and destination byte readback passed") }
                    print(externalPoint == nil ? "Clipboard real mouse drag, destination text and unpinned panel dismissal passed"
                        : "External destination accepted the clipboard drag; verify destination contents separately")
                    exit(0)
                }
                if CommandLine.arguments.contains("--preview") || dragPreview {
                    // Retain the controller while a human or computer-use inspects the actual window.
                    while true { try await Task.sleep(for: .seconds(1)); _ = controller.items.count }
                }
                if CommandLine.arguments.contains("--hover-mouse") {
                    // Exercise WindowServer delivery to the actual drag overlay, not controller callbacks.
                    panel().makeKey()
                    controller.pinned = false
                    panel().orderFrontRegardless()
                    panel().contentView!.layoutSubtreeIfNeeded()
                    @MainActor func surfaces(_ view: NSView) -> [ClipboardCardMouseView] {
                        if let card = view as? ClipboardCardMouseView { return [card] }
                        return view.subviews.flatMap(surfaces)
                    }
                    let cards = surfaces(panel().contentView!).sorted {
                        $0.convert(.zero, to: nil).x < $1.convert(.zero, to: nil).x
                    }
                    precondition(cards.count >= 2)
                    let originalPointer = NSEvent.mouseLocation
                    func movePointer(_ point: NSPoint) {
                        let location = CGPoint(x: point.x, y: NSScreen.screens[0].frame.maxY - point.y)
                        CGWarpMouseCursorPosition(location)
                        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: location,
                                mouseButton: .left)?.post(tap: .cghidEventTap)
                    }
                    defer { movePointer(originalPointer) }
                    let preview = application.windows.first { $0.title == "剪贴板完整预览" }!
                    let outside = NSPoint(x: shellFrame().minX + 8, y: shellFrame().maxY - 8)
                    let first = panel().convertToScreen(cards[0].convert(cards[0].bounds, to: nil))
                    let second = panel().convertToScreen(cards[1].convert(cards[1].bounds, to: nil))
                    movePointer(outside)
                    try await Task.sleep(for: .milliseconds(300))
                    movePointer(NSPoint(x: first.midX, y: first.midY))
                    try await Task.sleep(for: .milliseconds(600))
                    precondition(!preview.isVisible, "real brief hover must not show a preview")
                    movePointer(outside)
                    try await Task.sleep(for: .milliseconds(600))
                    precondition(!preview.isVisible, "real pointer departure cancels pending preview")
                    for (index, frame) in [first, second].enumerated() {
                        movePointer(NSPoint(x: frame.midX, y: frame.midY))
                        try await Task.sleep(for: .milliseconds(1200))
                        precondition(preview.isVisible, "real card hover must display the full preview")
                        precondition(abs(preview.frame.midX - frame.midX) < 1 ||
                                     abs(preview.frame.minX - frame.minX) < 1 ||
                                     abs(preview.frame.maxX - frame.maxX) < 1, "preview follows the hovered card")
                        try snapshot(preview, "mouse-preview-\(index)")
                        movePointer(NSPoint(x: preview.frame.midX, y: preview.frame.midY))
                        try await Task.sleep(for: .milliseconds(350))
                        precondition(preview.isVisible, "moving into the preview keeps it open")
                        movePointer(outside)
                        try await Task.sleep(for: .milliseconds(350))
                        precondition(!preview.isVisible, "leaving both surfaces dismisses preview")
                    }
                    controller.hide()
                    precondition(!preview.isVisible)
                    try? FileManager.default.removeItem(at: root)
                    print("Clipboard real mouse text/image hover, one-second delay, cancellation and preview handoff passed")
                    exit(0)
                }
                // Direct-callback regressions must not consume concurrent desktop keyboard/pointer input.
                panel().makeFirstResponder(nil)
                panel().resignKey()
                panel().ignoresMouseEvents = true
                controller.query = ""
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
                precondition(panel().frame.height == 244 && panel().hasShadow, "panel is exactly the shadowed glass shell")
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
                let pointerBeforeSyntheticHover = NSEvent.mouseLocation
                func restorePointer() {
                    CGWarpMouseCursorPosition(CGPoint(x: pointerBeforeSyntheticHover.x,
                        y: NSScreen.screens[0].frame.maxY - pointerBeforeSyntheticHover.y))
                }
                // Tracking callbacks can still arrive for an ignored window. Park away from cards/previews.
                CGWarpMouseCursorPosition(CGPoint(x: shellFrame().midX,
                    y: NSScreen.screens[0].frame.maxY - (shellFrame().maxY - 8)))
                panel().ignoresMouseEvents = true
                application.windows.first { $0.title == "剪贴板完整预览" }!.ignoresMouseEvents = true
                @MainActor func card(_ minX: CGFloat) -> NSRect { NSRect(x: minX, y: shellFrame().minY + 12, width: 264, height: 160) }
                @MainActor func previewFor(_ item: ClipboardItem, _ anchor: NSRect) async throws -> NSWindow {
                    controller.dismissPreview()
                    controller.hover(item, frame: anchor, inside: true)
                    try await Task.sleep(for: .milliseconds(1200))
                    let window = application.windows.first { $0.title == "剪贴板完整预览" }!
                    precondition(window.isVisible, "preview for \(item.contentHash) at \(anchor) panel \(panel().frame) visible \(panel().isVisible)")
                    return window
                }
                let middle = card(shellFrame().midX - 132)
                controller.dismissPreview()
                let pendingPreview = application.windows.first { $0.title == "剪贴板完整预览" }!
                controller.hover(picture, frame: middle, inside: true)
                try await Task.sleep(for: .milliseconds(600))
                precondition(!pendingPreview.isVisible, "brief hover must not show the preview")
                controller.hover(picture, frame: middle, inside: false)
                try await Task.sleep(for: .milliseconds(700))
                precondition(!pendingPreview.isVisible, "leaving cancels the pending preview")
                var preview = try await previewFor(picture, middle)
                if CommandLine.arguments.contains("--hover-delay") {
                    controller.hide()
                    precondition(!preview.isVisible, "closing releases the preview")
                    try? FileManager.default.removeItem(at: root)
                    restorePointer()
                    print("Clipboard 1-second hover delay, cancellation and preview release passed")
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
                // AppKit rounds narrow window frames to screen pixels.
                precondition(abs(preview.frame.midX - middle.midX) <= 1, "tall preview is centered under the card: preview=\(preview.frame), anchor=\(middle)")
                // Real card anchors must report each card's on-screen frame.
                @MainActor func anchors(_ view: NSView) -> [NSView] {
                    (view is ClipboardCardMouseView ? [view] : []) + view.subviews.flatMap(anchors)
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
                restorePointer()
                print("Clipboard native snapshots, search, pin, delete, preview placement and release passed")
                exit(0)
            } catch { fputs("Clipboard regression failed: \(error)\n", stderr); exit(1) }
        }
        application.run()
    }

    private static func verifyToastSurfaces() async throws {
        let panel = SurfacePanel()
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            panel.appearance = NSAppearance(named: appearance)
            for (kind, message) in [("copied", "已复制"), ("error", "无法复制：原始内容已不可用")] {
                let view = ClipboardStatusToast(message: message)
                let size = SurfacePanel.fittingSize(of: view, maxWidth: 672)
                panel.setSurface(view, size: size, cornerRadius: ClipboardStatusToast.cornerRadius, glass: false)
                panel.center()
                panel.orderFrontRegardless()
                try await Task.sleep(for: .milliseconds(200))
                let host = panel.contentView!
                host.layoutSubtreeIfNeeded()
                precondition(panel.frame.size == size, "hosting must preserve the measured surface size")
                precondition(size.height <= 40, "short feedback must fit on one line")
                let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
                host.cacheDisplay(in: host.bounds, to: bitmap)
                precondition(bitmap.colorAt(x: 0, y: 0)!.alphaComponent < 0.1,
                             "toast corner must remain transparent rather than overflow as a rectangle")
                precondition(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)!.alphaComponent > 0.99,
                             "toast must retain its opaque background")
                try bitmap.representation(using: .png, properties: [:])!.write(
                    to: URL(filePath: "build/clipboard-toast-\(name)-\(kind).png"))
                print("PASS: toast \(name) \(kind) \(size)")
                panel.remove()
            }
        }
    }
}


@MainActor
final class ClipboardFileDropReceiver: NSView {
    var urls: [URL] = []
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        urls = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        return !urls.isEmpty
    }
}
