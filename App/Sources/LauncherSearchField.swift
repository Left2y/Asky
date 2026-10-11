import AppKit
import SwiftUI

/// Owns the active AppKit field editor so consuming a command updates visible text immediately.
struct LauncherSearchField: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var textColor: NSColor
    var accessibilityLabel = NSLocalizedString("搜索应用、文件、标签页或命令", comment: "")
    var placeholder: String
    var placeholderColor: NSColor? = nil
    var completion: String? = nil
    var backspaceOnEmpty: () -> Bool
    var move: (Int) -> Void
    /// When set, ←/→ switch items instead of moving the caret.
    var moveHorizontal: ((Int) -> Void)? = nil
    var submit: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = CompletionTextField()
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
            if let field = field as? CompletionTextField {
                field.completion = parent.completion
                field.updateCompletion()
            }
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
            let editorNeedsUpdate = editor.map { $0.string != value } ?? false
            if field.stringValue != value { field.stringValue = value }
            if let editor, editorNeedsUpdate {
                editor.string = value
                editor.setSelectedRange(NSRange(location: (value as NSString).length, length: 0))
            }
            (field as? CompletionTextField)?.updateCompletion()
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
            case #selector(NSResponder.moveLeft(_:)), #selector(NSResponder.moveRight(_:)):
                guard let moveHorizontal = parent.moveHorizontal else { return false }
                moveHorizontal(selector == #selector(NSResponder.moveLeft(_:)) ? -1 : 1)
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

/// A display-only suffix: it never enters the binding, selection, clipboard, or IME buffer.
@MainActor
final class CompletionTextField: NSTextField {
    private let suffix = CompletionLabel(labelWithString: "")
    var completion: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        usesSingleLineMode = true
        cell?.wraps = false
        cell?.isScrollable = true
        lineBreakMode = .byClipping
        suffix.isHidden = true
        suffix.setAccessibilityElement(false)
        addSubview(suffix)
        NotificationCenter.default.addObserver(self, selector: #selector(selectionChanged(_:)),
            name: NSTextView.didChangeSelectionNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func selectionChanged(_ notification: Notification) {
        guard let editor = currentEditor(), notification.object as? NSTextView === editor else { return }
        updateCompletion()
    }

    override func layout() {
        super.layout()
        updateCompletion()
    }

    func updateCompletion() {
        suffix.isHidden = true
        guard let completion, !completion.isEmpty, !stringValue.isEmpty else { return }
        suffix.stringValue = completion
        suffix.font = font
        suffix.textColor = .tertiaryLabelColor
        suffix.sizeToFit()
        var x = (stringValue as NSString).size(withAttributes: [.font: font ?? NSFont.systemFont(ofSize: 18)]).width + 3
        if let editor = currentEditor() as? NSTextView {
            let end = (editor.string as NSString).length
            guard !editor.hasMarkedText(), editor.selectedRange() == NSRange(location: end, length: 0),
                  let window else { return }
            let caret = editor.firstRect(forCharacterRange: NSRange(location: end, length: 0), actualRange: nil)
            x = convert(window.convertFromScreen(caret), from: nil).maxX
        }
        x += 8
        guard x >= bounds.minX, x + suffix.frame.width <= bounds.maxX else { return }
        suffix.frame.origin = NSPoint(x: x, y: (bounds.height - suffix.frame.height) / 2)
        suffix.isHidden = false
    }
}

@MainActor
private final class CompletionLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
