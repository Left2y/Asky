import AppKit
import ApplicationServices

/// Converts a rejected drop over an identifiable editor into a normal paste.
/// Never clicks the target: a synthetic click could press Send or another unrelated control.
@MainActor
public struct ClipboardDropTarget {
    private let application: NSRunningApplication
    private let element: AXUIElement
    private let point: CGPoint
    private let capturedText: String?

    /// These custom editors can report an accepted native text drop without inserting it.
    public var canVerifyNativeTextDrop: Bool {
        application.bundleIdentifier == "com.bytedance.macos.feishu"
            && (Self.value(element, kAXRoleAttribute) as? String) == kAXTextAreaRole && capturedText != nil
    }

    public func hasUnchangedText(since previous: Self) -> Bool {
        canVerifyNativeTextDrop && previous.canVerifyNativeTextDrop
            && application.processIdentifier == previous.application.processIdentifier
            && CFEqual(element, previous.element) && capturedText == previous.capturedText
    }

    /// AppKit screen coordinates (bottom-left origin), as used by a dragging session.
    public static func capture(at screenPoint: CGPoint) -> Self? {
        guard AXIsProcessTrusted(), let screen = NSScreen.screens.first else { return nil }
        let point = CGPoint(x: screenPoint.x, y: screen.frame.maxY - screenPoint.y)
        var hit: AXUIElement?
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.15)
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &hit) == .success,
              let hit else { return nil }
        #if DEBUG
        if CommandLine.arguments.contains("--test-clipboard") {
            var hitPID: pid_t = 0
            AXUIElementGetPid(hit, &hitPID)
            NSLog("Clipboard drop hit: %.0f,%.0f pid=%d role=%@", point.x, point.y, hitPID, (value(hit, kAXRoleAttribute) as? String) ?? "unknown")
        }
        #endif
        guard let input = inputAncestor(of: hit) ?? terminalInput(near: hit, point: point),
              contains(input, point: point) else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(input, &pid) == .success,
              pid != ProcessInfo.processInfo.processIdentifier,
              let application = NSRunningApplication(processIdentifier: pid), !application.isTerminated,
              application.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        #if DEBUG
        if CommandLine.arguments.contains("--test-clipboard") {
            NSLog("Clipboard drop target: %@", application.bundleIdentifier ?? "unknown")
        }
        #endif
        return Self(application: application, element: input, point: point,
                    capturedText: value(input, kAXValueAttribute) as? String)
    }

    public func paste(expectedChangeCount: Int) async -> ClipboardPasteTarget.Result {
        guard AXIsProcessTrusted() else { return .accessibilityRequired }
        guard !application.isTerminated, Self.contains(element, point: point) else { return .unavailable }
        application.activate()
        for _ in 0..<12 {
            guard !Task.isCancelled, ClipboardAccess.changeCount == expectedChangeCount else { return .unavailable }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier else { return .unavailable }
        // Request editor focus semantically; never dispatch a mouse click at an untrusted drop point.
        _ = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        try? await Task.sleep(for: .milliseconds(60))
        guard focusedInputContainsPoint() else { return .noInputFocus }
        placeCaretIfSupported()
        let target = ClipboardPasteTarget.capture()
        return await target.paste(expectedChangeCount: expectedChangeCount, validateFocus: focusedInputContainsPoint)
    }

    private func focusedInputContainsPoint() -> Bool {
        guard !application.isTerminated else { return false }
        let app = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.15)
        guard let focused = Self.value(app, kAXFocusedUIElementAttribute),
              CFGetTypeID(focused) == AXUIElementGetTypeID(),
              let input = Self.inputAncestor(of: focused as! AXUIElement) else { return false }
        return Self.contains(input, point: point)
    }

    private func placeCaretIfSupported() {
        var position = point
        guard let parameter = AXValueCreate(.cgPoint, &position) else { return }
        var value: CFTypeRef?
        if AXUIElementCopyParameterizedAttributeValue(element, kAXRangeForPositionParameterizedAttribute as CFString,
                                                      parameter, &value) == .success,
           let value, CFGetTypeID(value) == AXValueGetTypeID() {
            var range = CFRange()
            if AXValueGetValue(value as! AXValue, .cfRange, &range), range.location != kCFNotFound {
                range.length = 0
                if let selection = AXValueCreate(.cfRange, &range),
                   AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, selection) == .success { return }
            }
        }
        // Chromium/WebKit editors can expose text markers instead of integer selection ranges.
        var marker: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, "AXTextMarkerForPosition" as CFString,
                                                         parameter, &marker) == .success, let marker else { return }
        var selection: CFTypeRef?
        if AXUIElementCopyParameterizedAttributeValue(element, "AXTextMarkerRangeForUnorderedTextMarkers" as CFString,
                                                      [marker, marker] as CFArray, &selection) == .success, let selection {
            _ = AXUIElementSetAttributeValue(element, "AXSelectedTextMarkerRange" as CFString, selection)
        }
    }

    private static func inputAncestor(of start: AXUIElement) -> AXUIElement? {
        var current = start
        var editableFallback: AXUIElement?
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(150))
        for _ in 0..<10 {
            guard ContinuousClock.now < deadline else { return editableFallback }
            AXUIElementSetMessagingTimeout(current, 0.05)
            if (value(current, kAXEnabledAttribute) as? Bool) == false { return editableFallback }
            let role = value(current, kAXRoleAttribute) as? String
            // Chromium's content group may advertise selectedText before its enclosing
            // textarea. Normalize both hit testing and focused-element lookup to the editor.
            if role.map({ [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains($0) }) == true {
                return current
            }
            var editable = DarwinBoolean(false)
            if editableFallback == nil,
               AXUIElementIsAttributeSettable(current, kAXSelectedTextAttribute as CFString, &editable) == .success,
               editable.boolValue { editableFallback = current }
            guard let parent = value(current, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { return editableFallback }
            current = parent as! AXUIElement
        }
        return editableFallback
    }

    private static func contains(_ element: AXUIElement, point: CGPoint) -> Bool {
        guard let own = frame(element) else { return false }
        if let region = terminalRegion(of: element, own: own) { return region.contains(point) }
        return own.contains(point)
    }

    /// Native terminal renderers use a tiny helper text field at the caret. Its enclosing
    /// terminal pane is the drop surface; expanding arbitrary small text fields is unsafe.
    private static func terminalRegion(of element: AXUIElement, own: CGRect) -> CGRect? {
        guard (value(element, kAXDescriptionAttribute) as? String) == "Terminal input" else { return nil }
        var parents: [CGRect] = []
        var current = element
        for _ in 0..<3 {
            guard let parent = value(current, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            current = parent as! AXUIElement
            if let rect = frame(current) { parents.append(rect) }
        }
        return terminalBounds(input: own, ancestors: parents)
    }

    static func terminalBounds(input: CGRect, ancestors: [CGRect]) -> CGRect {
        guard input.width < 24, input.height <= 32 else { return input }
        return ancestors.first { $0.width >= 80 && $0.height >= 40 && $0.contains(input) } ?? input
    }

    private static func terminalInput(near hit: AXUIElement, point: CGPoint) -> AXUIElement? {
        var pid: pid_t = 0
        if AXUIElementGetPid(hit, &pid) == .success {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.05)
            if let focused = value(app, kAXFocusedUIElementAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID() {
                let input = focused as! AXUIElement
                AXUIElementSetMessagingTimeout(input, 0.05)
                if (value(input, kAXDescriptionAttribute) as? String) == "Terminal input",
                   contains(input, point: point) { return input }
            }
        }
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(150))
        var root = hit
        for _ in 0..<3 {
            var queue: [(AXUIElement, Int)] = [(root, 0)]
            var visited = 0
            while !queue.isEmpty, visited < 160, ContinuousClock.now < deadline {
                let (node, depth) = queue.removeFirst()
                visited += 1
                AXUIElementSetMessagingTimeout(node, 0.03)
                if (value(node, kAXDescriptionAttribute) as? String) == "Terminal input",
                   (value(node, kAXEnabledAttribute) as? Bool) != false,
                   contains(node, point: point) { return node }
                if depth < 5, let children = value(node, kAXChildrenAttribute) as? [AXUIElement] {
                    queue += children.map { ($0, depth + 1) }
                }
            }
            guard ContinuousClock.now < deadline else { return nil }
            guard let parent = value(root, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            root = parent as! AXUIElement
        }
        return nil
    }

    private static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = value(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = value(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: origin, size: dimensions)
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }
}
