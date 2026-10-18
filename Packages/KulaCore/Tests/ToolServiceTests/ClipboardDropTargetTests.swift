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
}
