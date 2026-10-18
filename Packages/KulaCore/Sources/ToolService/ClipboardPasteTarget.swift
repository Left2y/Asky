import AppKit
import ApplicationServices

/// A paste belongs to the application and input that were focused before the history panel opened.
@MainActor
public struct ClipboardPasteTarget {
    public enum Result: Equatable, Sendable {
        case posted, noInputFocus, accessibilityRequired, unavailable
    }

    private let application: NSRunningApplication?
    private let input: AXUIElement?

    public static var unavailable: Self { Self(application: nil, input: nil) }
    public var hasInputFocus: Bool { input != nil && application?.isTerminated == false && AXIsProcessTrusted() }

    public static func capture() -> Self {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let target = frontmost?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : frontmost
        return Self(application: target, input: target.flatMap { focusedInput(in: $0) })
    }

    /// Check before dismissing the panel so a copy-only fallback can leave it open.
    public func prepare() -> Result {
        guard let application, !application.isTerminated else { return .unavailable }
        guard AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) else {
            return .accessibilityRequired
        }
        return input != nil ? .posted : .noInputFocus
    }

    /// `.posted` means the shortcut was delivered, not that the receiving app accepted its content.
    public func paste(expectedChangeCount: Int) async -> Result {
        guard let application, !application.isTerminated else { return .unavailable }
        guard AXIsProcessTrusted() else { return .accessibilityRequired }
        guard let input else { return .noInputFocus }
        application.activate()
        try? await Task.sleep(for: .milliseconds(80))
        for _ in 0..<10 {
            guard !Task.isCancelled, !application.isTerminated,
                  NSPasteboard.general.changeCount == expectedChangeCount else { return .unavailable }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
                guard let focused = Self.focusedInput(in: application), CFEqual(input, focused) else { return .noInputFocus }
                guard let source = CGEventSource(stateID: .combinedSessionState),
                      let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                      let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return .unavailable }
                down.flags = .maskCommand
                up.flags = .maskCommand
                down.postToPid(application.processIdentifier)
                up.postToPid(application.processIdentifier)
                return .posted
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return .unavailable
    }

    private static func focusedInput(in application: NSRunningApplication) -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }
        let app = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.15)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let element = value as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.15)
        var enabled: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabled) == .success,
           let enabled = enabled as? Bool, !enabled { return nil }
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           let role = role as? String,
           [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) { return element }
        var editable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &editable) == .success
            && editable.boolValue ? element : nil
    }
}
