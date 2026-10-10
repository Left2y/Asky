import AppKit

/// Explicit native conversation copy action; no model or runtime access.
@MainActor
public enum MessageClipboard {
    @discardableResult
    public static func copy(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
