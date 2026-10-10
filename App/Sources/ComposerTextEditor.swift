import AppKit
import SwiftUI
import Theme

private final class ComposerTextView: NSTextView {
    var pasteAttachment: () -> Bool = { false }
    var focusChanged: (Bool) -> Void = { _ in }
    var placeholderColor: NSColor = .placeholderTextColor {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !hasMarkedText(), let font, let textContainer else { return }
        // Use TextKit for both the hint and input so their first glyph and
        // baseline agree, including the insertion point in an empty editor.
        let storage = NSTextStorage(string: "输入你的任务", attributes: [
            .font: font, .foregroundColor: placeholderColor
        ])
        let layout = NSLayoutManager()
        let container = NSTextContainer(containerSize: textContainer.containerSize)
        container.lineFragmentPadding = textContainer.lineFragmentPadding
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        let glyphs = layout.glyphRange(for: container)
        layout.drawGlyphs(forGlyphRange: glyphs, at: textContainerOrigin)
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { focusChanged(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { focusChanged(false) }
        return accepted
    }

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
    @Binding var isFocused: Bool
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
        editor.font = .systemFont(ofSize: 14)
        editor.textContainerInset = NSSize(width: 0, height: 4)
        editor.textContainer?.lineFragmentPadding = 0
        editor.minSize = NSSize(width: 0, height: 44)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.delegate = context.coordinator
        editor.focusChanged = { [weak coordinator = context.coordinator] focused in
            DispatchQueue.main.async { coordinator?.parent.isFocused = focused }
        }
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
        editor.setFrameSize(NSSize(width: scroll.contentSize.width, height: max(44, editor.frame.height)))
        editor.pasteAttachment = pasteAttachment
        editor.textColor = NSColor(ThemeColor.kText.color(for: colorScheme))
        editor.placeholderColor = NSColor(ThemeColor.kTextSubtlest.color(for: colorScheme))
        editor.insertionPointColor = editor.textColor ?? .labelColor
        if editor.string != text && !editor.hasMarkedText() {
            editor.string = text
            editor.needsDisplay = true
        }
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
            let height = min(160, max(44, layout.usedRect(for: container).height + 8))
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
