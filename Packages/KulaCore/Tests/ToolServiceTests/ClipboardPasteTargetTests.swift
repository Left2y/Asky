import AppKit
import Testing
@testable import ToolService

@Suite @MainActor
struct ClipboardPasteTargetTests {
    @Test func weChatTextSelectionDoesNotProveThereIsNoEditor() {
        // Observed in WeChat: AXButton, AXSelectedText not settable, readable AXSelectedTextRange.
        #expect(ClipboardPasteTarget.classify(role: kAXButtonRole, enabled: true,
            selectedTextSettable: false, hasSelectionRange: true) == .unknown)
    }

    @Test func missingAccessibilityIsUnknownRatherThanNoFocus() {
        #expect(ClipboardPasteTarget.classify(role: nil, enabled: nil,
            selectedTextSettable: false, hasSelectionRange: false) == .unknown)
    }

    @Test func ordinaryButtonsAndDisabledEditorsDoNotBecomePasteTargets() {
        #expect(ClipboardPasteTarget.classify(role: kAXButtonRole, enabled: true,
            selectedTextSettable: false, hasSelectionRange: false) == .nonInput)
        #expect(ClipboardPasteTarget.classify(role: kAXTextAreaRole, enabled: false,
            selectedTextSettable: true, hasSelectionRange: true) == .nonInput)
    }

    @Test func nativeAndChromiumTextInputsRemainRecognized() {
        for role in [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole] {
            #expect(ClipboardPasteTarget.classify(role: role, enabled: true,
                selectedTextSettable: false, hasSelectionRange: false) == .input)
        }
    }
}
