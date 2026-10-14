import AppKit
import ApplicationServices

/// Opens the clipboard panel beside the focused text field so it never covers what the user is typing into.
public enum ClipboardPlacement {
    /// Focused field and caret in AppKit screen coordinates (bottom-left origin).
    public struct Anchor: Equatable, Sendable {
        public var field: CGRect?
        public var caret: CGRect?
        public init(field: CGRect? = nil, caret: CGRect? = nil) { self.field = field; self.caret = caret }
        /// The point the panel belongs to; also picks the screen.
        public var reference: CGRect? { caret ?? field }
    }

    /// Panel rect (without shadow padding) inside `visible`, or nil when neither the field nor the caret line can be avoided.
    /// The panel opens on whichever side of the target has more room (above for low fields, below for high ones).
    /// Right-half anchors align the panel's right edge, so a field in the bottom-right corner gets the panel at its top-left.
    public static func frame(size: CGSize, anchor: Anchor, visible: CGRect, gap: CGFloat = 8, margin: CGFloat = 8) -> CGRect? {
        let bounds = visible.insetBy(dx: margin, dy: margin)
        let size = CGSize(width: min(size.width, bounds.width), height: min(size.height, bounds.height))
        // A full-window editor cannot be avoided as a whole; keep just the caret line visible instead.
        for target in [anchor.field, anchor.caret].compactMap({ $0 }) {
            if let rect = place(size, avoiding: target, in: bounds, gap: gap) { return rect }
        }
        return nil
    }

    private static func place(_ size: CGSize, avoiding target: CGRect, in bounds: CGRect, gap: CGFloat) -> CGRect? {
        // The roomier side is the only one that can fit when the other cannot.
        let above = bounds.maxY - target.maxY >= target.minY - bounds.minY
        let y = above ? target.maxY + gap : target.minY - gap - size.height
        guard y >= bounds.minY, y + size.height <= bounds.maxY else { return nil }
        let aligned = target.midX > bounds.midX ? target.maxX - size.width : target.minX
        let x = min(max(bounds.minX, aligned), bounds.maxX - size.width)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    /// Reads the frontmost app's focused element through Accessibility. Never prompts; nil without permission.
    @MainActor public static func focusedAnchor() -> Anchor? {
        guard AXIsProcessTrusted() else { return nil }
        let system = AXUIElementCreateSystemWide()
        // A hung target app must not delay the hotkey.
        AXUIElementSetMessagingTimeout(system, 0.15)
        guard let focused = attribute(system, kAXFocusedUIElementAttribute),
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var pid: pid_t = 0
        if AXUIElementGetPid(element, &pid) == .success, pid == getpid() { return nil }
        AXUIElementSetMessagingTimeout(element, 0.15)
        var field: CGRect?
        if let origin = value(attribute(element, kAXPositionAttribute), .cgPoint, CGPoint.zero),
           let size = value(attribute(element, kAXSizeAttribute), .cgSize, CGSize.zero) {
            field = CGRect(origin: origin, size: size)
        }
        var caret: CGRect?
        if let range = attribute(element, kAXSelectedTextRangeAttribute) {
            var bounds: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString,
                                                          range, &bounds) == .success {
                caret = value(bounds, .cgRect, CGRect.zero)
            }
        }
        let anchor = Anchor(field: field.flatMap { appKitRect($0, minWidth: 1) }, caret: caret.flatMap { appKitRect($0, minWidth: 0) })
        return anchor.reference == nil ? nil : anchor
    }

    /// Accessibility uses a top-left origin on the primary screen; discard empty or off-screen rects some apps report.
    @MainActor private static func appKitRect(_ rect: CGRect, minWidth: CGFloat) -> CGRect? {
        guard rect.width >= minWidth, rect.height > 0, let primary = NSScreen.screens.first else { return nil }
        let converted = CGRect(x: rect.minX, y: primary.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
        let center = CGPoint(x: converted.midX, y: converted.midY)
        return NSScreen.screens.contains { $0.frame.contains(center) } ? converted : nil
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success ? result : nil
    }

    private static func value<T: BitwiseCopyable>(_ ref: CFTypeRef?, _ type: AXValueType, _ empty: T) -> T? {
        guard let ref, CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
        var result = empty
        let ok = withUnsafeMutableBytes(of: &result) { AXValueGetValue(ref as! AXValue, type, $0.baseAddress!) }
        return ok ? result : nil
    }
}
