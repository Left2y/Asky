import AppKit
import SwiftUI

/// A single native layout for both the idle text and the active field editor.
struct ConversationSearchField: NSViewRepresentable {
    @Binding var text: String
    var textColor: NSColor
    var placeholderColor: NSColor

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        let cell = ConversationSearchCell(textCell: "")
        field.cell = cell
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 16)
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        cell.didFocus = { [weak coordinator = context.coordinator, weak field] in
            guard let field else { return }
            coordinator?.beginEditing(field)
        }
        field.setAccessibilityLabel(NSLocalizedString("搜索对话", comment: ""))
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        context.coordinator.observeClicks(field)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.textColor != textColor { field.textColor = textColor }
        if field.stringValue != text { field.stringValue = text }
        context.coordinator.updatePlaceholder(field)
    }

    static func dismantleNSView(_ field: NSTextField, coordinator: Coordinator) {
        coordinator.stopObservingClicks()
        field.delegate = nil
    }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ConversationSearchField
        private var clickMonitor: Any?
        private var editing = false

        init(_ parent: ConversationSearchField) { self.parent = parent }

        func observeClicks(_ field: NSTextField) {
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak field] event in
                guard let field, let window = field.window,
                      event.window === window, field.currentEditor() != nil else { return event }
                // Include the capsule's icon and padding in the search hit area.
                let searchBounds = NSRect(x: -29, y: (field.bounds.height - 36) / 2,
                                          width: field.bounds.width + 45, height: 36)
                if !searchBounds.contains(field.convert(event.locationInWindow, from: nil)) {
                    window.makeFirstResponder(nil)
                }
                return event
            }
        }

        func stopObservingClicks() {
            if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
            clickMonitor = nil
        }

        func updatePlaceholder(_ field: NSTextField) {
            let value = NSAttributedString(string: editing ? "" : NSLocalizedString("搜索对话", comment: ""), attributes: [
                .font: NSFont.systemFont(ofSize: 16), .foregroundColor: parent.placeholderColor
            ])
            if field.placeholderAttributedString != value { field.placeholderAttributedString = value }
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            if let field = notification.object as? NSTextField { beginEditing(field) }
        }

        func beginEditing(_ field: NSTextField) {
            editing = true
            updatePlaceholder(field)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            editing = false
            if let field = notification.object as? NSTextField { updatePlaceholder(field) }
        }

        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSTextField { parent.text = field.stringValue }
        }
    }
}

private final class ConversationSearchCell: NSTextFieldCell {
    var didFocus: (() -> Void)?

    override func select(withFrame rect: NSRect, in controlView: NSView, editor: NSText,
                         delegate: Any?, start selStart: Int, length selLength: Int) {
        didFocus?()
        super.select(withFrame: rect, in: controlView, editor: editor,
                     delegate: delegate, start: selStart, length: selLength)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor: NSText,
                       delegate: Any?, event: NSEvent?) {
        didFocus?()
        super.edit(withFrame: rect, in: controlView, editor: editor, delegate: delegate, event: event)
    }
}
