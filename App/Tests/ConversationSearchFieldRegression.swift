import AppKit
import SwiftUI

@main
@MainActor
enum ConversationSearchFieldRegression {
    static func main() {
        _ = NSApplication.shared
        var query = ""
        let host = NSHostingView(rootView: ConversationSearchField(
            text: Binding(get: { query }, set: { query = $0 }),
            textColor: .labelColor, placeholderColor: .secondaryLabelColor)
            .fixedSize(horizontal: false, vertical: true))
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 100),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView?.addSubview(host)
        host.frame = NSRect(x: 40, y: 50, width: 320, height: 36)
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        func findField(_ view: NSView) -> NSTextField? {
            if let field = view as? NSTextField { return field }
            return view.subviews.compactMap { findField($0) }.first
        }
        guard let field = findField(host), let cell = field.cell else { fatalError("missing native search field") }
        window.makeFirstResponder(nil)
        precondition(field.placeholderAttributedString?.string == "搜索对话")
        let idleFrame = field.frame
        let idleTextRect = cell.drawingRect(forBounds: field.bounds)
        precondition(window.makeFirstResponder(field))
        precondition((field.placeholderAttributedString?.string ?? "") == "", "focus must hide placeholder before typing")
        guard let editor = field.currentEditor() as? NSTextView else { fatalError("missing active editor") }
        precondition(field.frame == idleFrame && cell.drawingRect(forBounds: field.bounds) == idleTextRect,
                     "focus must preserve text layout")
        editor.insertText("你好", replacementRange: editor.selectedRange())
        precondition(query == "你好", "native editing must update filtering binding")
        let event = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 10, y: 10),
                                      modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                      context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        NSApp.sendEvent(event)
        precondition(field.currentEditor() == nil, "outside click must release focus")
        precondition(query == "你好", "outside click must preserve the query")
        precondition(field.placeholderAttributedString?.string == "搜索对话", "blur must restore placeholder")
        precondition(window.makeFirstResponder(field), "refocusing must work")
        precondition((field.placeholderAttributedString?.string ?? "") == "")
        window.makeFirstResponder(nil)
        window.close()
        print("Conversation search: focus, placeholder, layout, filtering, outside click and refocus passed")
    }
}
