import AppKit
import SwiftUI

@MainActor
private final class TrackingTextField: NSTextField {
    var fontWrites = 0
    var colorWrites = 0
    var placeholderWrites = 0
    override var font: NSFont? {
        didSet { fontWrites += 1 }
    }
    override var textColor: NSColor? {
        didSet { colorWrites += 1 }
    }
    override var placeholderString: String? {
        didSet { placeholderWrites += 1 }
    }
}

/// Standalone AppKit regression check; compile alongside LauncherSearchField.swift.
@main
@MainActor
enum LauncherSearchFieldRegression {
    static func main() {
        _ = NSApplication.shared
        var text = ""
        var scoped = false
        let parent = LauncherSearchField(
            text: Binding(get: { text }, set: { value in
                if !scoped, value == "go " { scoped = true; text = "" }
                else { text = value }
            }),
            fontSize: 18, textColor: .labelColor, placeholder: "",
            backspaceOnEmpty: {
                guard scoped, text.isEmpty else { return false }
                scoped = false
                return true
            },
            move: { _ in }, submit: { _ in }
        )
        let coordinator = LauncherSearchField.Coordinator(parent)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 64),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let field = TrackingTextField(frame: NSRect(x: 0, y: 10, width: 400, height: 26))
        field.delegate = coordinator
        coordinator.configure(field)
        window.contentView?.addSubview(field)
        precondition(window.makeFirstResponder(field), "field must become first responder")
        guard let editor = field.currentEditor() as? NSTextView else {
            fatalError("native field editor must be active")
        }

        // The delegate sees exactly one space, while an actual field editor is active.
        editor.insertText("go ", replacementRange: NSRange(location: 0, length: 0))
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        precondition(scoped && text.isEmpty, "one space must consume the token")
        precondition(field.stringValue.isEmpty && editor.string.isEmpty, "go must disappear immediately")
        precondition(editor.selectedRange().location == 0, "caret must reset with consumed text")

        editor.insertText("Who is fantuan?", replacementRange: editor.selectedRange())
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        precondition(text == "Who is fantuan?", "query must not retain the command")

        text = ""
        coordinator.synchronize(field)
        let handled = coordinator.control(field, textView: editor,
                                          doCommandBy: #selector(NSResponder.deleteBackward(_:)))
        precondition(handled && !scoped && editor.string.isEmpty, "empty Backspace must clear command")
        editor.insertText("Safari", replacementRange: editor.selectedRange())
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        precondition(text == "Safari" && !scoped, "ordinary search must resume")

        // Async search batches trigger representable updates while editing.
        // They must not write editor attributes or move a mid-text selection.
        editor.setSelectedRange(NSRange(location: 2, length: 2))
        let writes = (field.fontWrites, field.colorWrites, field.placeholderWrites)
        for _ in 0..<40 {
            coordinator.configure(field)
            coordinator.synchronize(field)
        }
        precondition(field.fontWrites == writes.0 && field.colorWrites == writes.1
                     && field.placeholderWrites == writes.2, "unchanged appearance must not reset editor attributes")
        precondition(field.currentEditor() === editor, "updates must preserve the active editor")
        precondition(editor.selectedRange() == NSRange(location: 2, length: 2), "updates must preserve selection")

        coordinator.parent.fontSize = 20
        coordinator.parent.textColor = .secondaryLabelColor
        coordinator.parent.placeholder = "Search"
        coordinator.configure(field)
        precondition(field.font?.pointSize == 20 && field.textColor == .secondaryLabelColor
                     && field.placeholderString == "Search", "actual appearance changes must still apply")
        print("LauncherSearchField native regression checks passed")
        window.close()
    }
}
