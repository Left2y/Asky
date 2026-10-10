import AppKit
import SwiftUI

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
        let field = NSTextField(frame: NSRect(x: 0, y: 10, width: 400, height: 26))
        field.delegate = coordinator
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
        print("LauncherSearchField native regression checks passed")
        window.close()
    }
}
