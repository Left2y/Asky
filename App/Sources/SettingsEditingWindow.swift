import AppKit

/// End editing before dispatching an outside click, preserving the clicked control's action.
@MainActor
final class SettingsEditingWindow: NSWindow {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown,
           let editor = firstResponder as? NSTextView {
            let input: NSView? = editor.isFieldEditor ? editor.delegate as? NSView : editor
            if let input,
               !input.bounds.contains(input.convert(event.locationInWindow, from: nil)) {
                makeFirstResponder(nil)
            }
        }
        super.sendEvent(event)
    }
}
