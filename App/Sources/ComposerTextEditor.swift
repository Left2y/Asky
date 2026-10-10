import AppKit
import SwiftUI
import Theme

private final class ComposerTextView: NSTextView {
    var pasteAttachment: () -> Bool = { false }
    // This accessory app has no standard Edit menu. Handle the responder's
    // paste shortcut directly, including image-only pasteboards that plain
    // NSTextView would otherwise mark as unavailable.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "v" {
            paste(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "v" {
            paste(nil)
        } else { super.keyDown(with: event) }
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(paste(_:)) { return true }
        return super.validateUserInterfaceItem(item)
    }

    override func paste(_ sender: Any?) {
        if !pasteAttachment() { super.paste(sender) }
    }
    override func pasteAsPlainText(_ sender: Any?) { paste(sender) }
}

struct ComposerTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var pasteAttachment: () -> Bool
    var submit: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let editor = ComposerTextView()
        editor.isRichText = false
        editor.allowsUndo = true
        editor.importsGraphics = false
        editor.drawsBackground = false
        editor.font = .systemFont(ofSize: 16)
        editor.textContainerInset = NSSize(width: 0, height: 4)
        editor.minSize = NSSize(width: 0, height: 48)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.delegate = context.coordinator
        editor.setAccessibilityLabel("消息输入")
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.documentView = editor
        context.coordinator.editor = editor
        DispatchQueue.main.async { [weak editor] in
            guard let editor else { return }
            editor.window?.makeFirstResponder(editor)
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? ComposerTextView else { return }
        context.coordinator.parent = self
        editor.setFrameSize(NSSize(width: scroll.contentSize.width, height: max(48, editor.frame.height)))
        editor.pasteAttachment = pasteAttachment
        editor.textColor = NSColor(ThemeColor.kText.color(for: colorScheme))
        editor.insertionPointColor = editor.textColor ?? .labelColor
        if editor.string != text && !editor.hasMarkedText() { editor.string = text }
        context.coordinator.updateHeight()
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerTextEditor
        weak var editor: NSTextView?
        init(_ parent: ComposerTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor else { return }
            parent.text = editor.string
            updateHeight()
        }
        func updateHeight() {
            guard let editor, let container = editor.textContainer, let layout = editor.layoutManager else { return }
            layout.ensureLayout(for: container)
            let height = min(160, max(48, layout.usedRect(for: container).height + 8))
            if abs(parent.height - height) > 1 {
                DispatchQueue.main.async { [weak self] in self?.parent.height = height }
            }
        }
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)),
               !textView.hasMarkedText(), !(NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false) {
                parent.submit()
                return true
            }
            return false
        }
    }
}
