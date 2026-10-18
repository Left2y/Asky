import AppKit
import ApplicationServices

/// A paste belongs to the application that was in front before the history panel opened.
@MainActor
public struct ClipboardPasteTarget {
    public enum Result: Equatable, Sendable {
        case posted, noInputFocus, accessibilityRequired, unavailable
    }

    public enum FocusState: Equatable, Sendable {
        case input, nonInput, unknown
    }

    private let application: NSRunningApplication?
    public let focusState: FocusState

    public static var unavailable: Self { Self(application: nil, focusState: .nonInput) }
    /// Missing accessibility information is not proof that the app has no input focus.
    public var canPaste: Bool { focusState != .nonInput && application?.isTerminated == false && AXIsProcessTrusted() }

    public static func capture() -> Self {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let target = frontmost?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : frontmost
        return Self(application: target, focusState: target.map { focusedInput(in: $0) } ?? .nonInput)
    }

    /// Check before dismissing the panel so a copy-only fallback can leave it open.
    public func prepare() -> Result {
        guard let application, !application.isTerminated else { return .unavailable }
        guard AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) else {
            return .accessibilityRequired
        }
        return focusState != .nonInput ? .posted : .noInputFocus
    }

    /// `.posted` means the shortcut was delivered, not that the receiving app accepted its content.
    public func paste(expectedChangeCount: Int) async -> Result {
        await paste(expectedChangeCount: expectedChangeCount, validateFocus: { true })
    }

    func paste(expectedChangeCount: Int, validateFocus: @MainActor () -> Bool) async -> Result {
        guard let application, !application.isTerminated else { return .unavailable }
        guard AXIsProcessTrusted() else { return .accessibilityRequired }
        guard focusState != .nonInput else { return .noInputFocus }
        application.activate()
        try? await Task.sleep(for: .milliseconds(80))
        for _ in 0..<10 {
            guard !Task.isCancelled, !application.isTerminated,
                  NSPasteboard.general.changeCount == expectedChangeCount else { return .unavailable }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
                guard Self.focusedInput(in: application) != .nonInput, validateFocus() else { return .noInputFocus }
                guard let source = CGEventSource(stateID: .combinedSessionState),
                      let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                      let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return .unavailable }
                // Match a physical shortcut after restoring focus. PID delivery bypasses parts of
                // normal key routing in custom/Chromium clients, so it is not used for this path.
                down.flags = .maskCommand
                up.flags = .maskCommand
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier,
                      NSPasteboard.general.changeCount == expectedChangeCount else { return .unavailable }
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
                return .posted
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return .unavailable
    }

    /// WeChat exposes text-bearing elements as AXButton with a readable selection range,
    /// but marks selected text/value as non-settable. This cannot prove editable focus;
    /// preserve an unknown state so custom editors can still receive an explicit paste.
    static func classify(role: String?, enabled: Bool?, selectedTextSettable: Bool,
                         hasSelectionRange: Bool) -> FocusState {
        if enabled == false { return .nonInput }
        if selectedTextSettable { return .input }
        guard let role else { return .unknown }
        if [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) { return .input }
        return hasSelectionRange ? .unknown : .nonInput
    }

    private static func focusedInput(in application: NSRunningApplication) -> FocusState {
        guard AXIsProcessTrusted() else { return .unknown }
        let app = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.15)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return .unknown }
        let element = value as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.15)
        var enabled: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabled)
        var role: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        var editable = DarwinBoolean(false)
        let canReplace = AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &editable) == .success
            && editable.boolValue
        var selection: CFTypeRef?
        let selectionResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selection)
        var range = CFRange()
        let hasRange = selectionResult == .success && selection.map {
            CFGetTypeID($0) == AXValueGetTypeID() && AXValueGetValue($0 as! AXValue, .cfRange, &range)
                && range.location != kCFNotFound
        } == true
        return classify(role: role as? String, enabled: enabled as? Bool,
                        selectedTextSettable: canReplace, hasSelectionRange: hasRange)
    }
}
