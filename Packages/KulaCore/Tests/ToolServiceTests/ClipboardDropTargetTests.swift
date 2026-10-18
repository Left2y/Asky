import AppKit
import Testing
@testable import ToolService

@Suite @MainActor
struct ClipboardDropTargetTests {
    @Test func terminalCaretUsesItsPaneWithoutIncludingToolbarOrSidebar() {
        let caret = CGRect(x: 268, y: 761, width: 8, height: 16)
        let pane = CGRect(x: 252, y: 73, width: 1208, height: 752)
        let region = ClipboardDropTarget.terminalBounds(input: caret, ancestors: [caret, pane])
        #expect(region == pane)
        #expect(region.contains(CGPoint(x: 500, y: 600)))
        #expect(!region.contains(CGPoint(x: 500, y: 50)))
        #expect(!region.contains(CGPoint(x: 100, y: 600)))
    }

    @Test func fullSizeInputsAndMissingTerminalPanesDoNotExpandToTheWindow() {
        let editor = CGRect(x: 100, y: 600, width: 300, height: 100)
        let window = CGRect(x: 0, y: 0, width: 1400, height: 900)
        #expect(ClipboardDropTarget.terminalBounds(input: editor, ancestors: [window]) == editor)
        let caret = CGRect(x: 268, y: 761, width: 8, height: 16)
        #expect(ClipboardDropTarget.terminalBounds(input: caret, ancestors: []) == caret)
    }
    @Test func emptyFeishuComposerIncludesPaddingButExcludesSendControls() {
        let line = CGRect(x: 402, y: 795, width: 772, height: 22)
        let wrapper = CGRect(x: 398, y: 795, width: 787, height: 34)
        let composer = CGRect(x: 389, y: 782, width: 1055, height: 48)
        let region = ClipboardDropTarget.feishuEditorBounds(input: line, ancestors: [wrapper, composer])
        #expect(region.contains(CGPoint(x: 1100, y: 790)))
        #expect(region.contains(CGPoint(x: 1100, y: 805)))
        #expect(!region.contains(CGPoint(x: 1200, y: 805)))
        #expect(!region.contains(CGPoint(x: 1100, y: 780)))
        #expect(!region.contains(CGPoint(x: 1100, y: 832)))
    }

    @Test func feishuEditorDoesNotExpandToUnrelatedAncestors() {
        let line = CGRect(x: 402, y: 795, width: 772, height: 22)
        let window = CGRect(x: 0, y: 33, width: 1470, height: 825)
        #expect(ClipboardDropTarget.feishuEditorBounds(input: line, ancestors: [window]) == line)
        let expanded = CGRect(x: 402, y: 562, width: 1028, height: 221)
        #expect(ClipboardDropTarget.feishuEditorBounds(input: expanded, ancestors: [window]) == expanded)
    }

}
