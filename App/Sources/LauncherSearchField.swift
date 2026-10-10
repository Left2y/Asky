import AppKit
import SwiftUI

/// Owns the active AppKit field editor so consuming a command updates visible text immediately.
struct LauncherSearchField: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var textColor: NSColor
    var accessibilityLabel = "搜索应用、文件、标签页或命令"
    var placeholder: String
    var placeholderColor: NSColor? = nil
    var backspaceOnEmpty: () -> Bool
    var move: (Int) -> Void
    var submit: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.setAccessibilityLabel(accessibilityLabel)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        DispatchQueue.main.async { [weak field] in
            guard let field else { return }
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.configure(field)
        context.coordinator.synchronize(field)
    }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LauncherSearchField
        init(_ parent: LauncherSearchField) { self.parent = parent }

        func configure(_ field: NSTextField) {
            // AppKit forwards these setters to the live field editor. Reapplying
            // identical attributes on every result batch resets its layout/caret.
            let font = NSFont.systemFont(ofSize: parent.fontSize)
            if field.font != font { field.font = font }
            if field.textColor != parent.textColor { field.textColor = parent.textColor }
            if let color = parent.placeholderColor {
                let value = NSAttributedString(string: parent.placeholder, attributes: [.foregroundColor: color, .font: font])
                if field.placeholderAttributedString != value { field.placeholderAttributedString = value }
            } else if field.placeholderString != parent.placeholder { field.placeholderString = parent.placeholder }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField,
                  (field.currentEditor() as? NSTextView)?.hasMarkedText() != true else { return }
            parent.text = field.stringValue
            // SwiftUI can defer pushing a transformed Binding back into its TextField.
            // Update the live editor during the same delegate callback instead.
            synchronize(field)
        }

        func synchronize(_ field: NSTextField) {
            let editor = field.currentEditor() as? NSTextView
            guard editor?.hasMarkedText() != true else { return }
            let value = parent.text
            if field.stringValue != value { field.stringValue = value }
            if let editor, editor.string != value {
                editor.string = value
                editor.setSelectedRange(NSRange(location: (value as NSString).length, length: 0))
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard !textView.hasMarkedText() else { return false }
            switch selector {
            case #selector(NSResponder.deleteBackward(_:)):
                guard parent.text.isEmpty, parent.backspaceOnEmpty() else { return false }
                if let field = control as? NSTextField { synchronize(field) }
                return true
            case #selector(NSResponder.moveUp(_:)):
                parent.move(-1)
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.move(1)
                return true
            case #selector(NSResponder.insertNewline(_:)),
                 #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
                parent.submit(NSApp.currentEvent?.modifierFlags.contains(.command) == true)
                return true
            default:
                return false
            }
        }
    }
}
