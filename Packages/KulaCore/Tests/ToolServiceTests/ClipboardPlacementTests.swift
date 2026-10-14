import CoreGraphics
import Testing
@testable import ToolService

@Suite
struct ClipboardPlacementTests {
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let size = CGSize(width: 900, height: 244)

    @Test func bottomRightFieldOpensAtItsTopLeft() throws {
        let field = CGRect(x: 1000, y: 40, width: 400, height: 36)
        let rect = try #require(ClipboardPlacement.frame(size: size, anchor: .init(field: field), visible: visible))
        #expect(rect.minY == field.maxY + 8)
        #expect(rect.maxX == field.maxX)
        #expect(!rect.intersects(field))
    }

    @Test func topLeftFieldOpensBelowAlignedLeft() throws {
        let field = CGRect(x: 20, y: 780, width: 300, height: 30)
        let rect = try #require(ClipboardPlacement.frame(size: size, anchor: .init(field: field), visible: visible))
        #expect(rect.maxY == field.minY - 8)
        #expect(rect.minX == field.minX)
    }

    @Test func staysInsideScreenMargins() throws {
        let field = CGRect(x: 1300, y: 600, width: 130, height: 30)
        let rect = try #require(ClipboardPlacement.frame(size: size, anchor: .init(field: field), visible: visible))
        #expect(visible.insetBy(dx: 8, dy: 8).contains(rect))
        #expect(!rect.intersects(field))
    }

    @Test func secondaryScreenUsesItsOwnBounds() throws {
        let screen = CGRect(x: -1920, y: 200, width: 1920, height: 1055)
        let field = CGRect(x: -400, y: 260, width: 380, height: 40)
        let rect = try #require(ClipboardPlacement.frame(size: size, anchor: .init(field: field), visible: screen))
        #expect(rect.minY == field.maxY + 8 && rect.maxX == field.maxX)
        #expect(screen.insetBy(dx: 8, dy: 8).contains(rect))
    }

    @Test func fullWindowEditorAvoidsTheCaretLine() throws {
        let caret = CGRect(x: 700, y: 400, width: 1, height: 18)
        let rect = try #require(ClipboardPlacement.frame(size: size, anchor: .init(field: visible, caret: caret), visible: visible))
        #expect(!rect.intersects(caret))
        #expect(visible.insetBy(dx: 8, dy: 8).contains(rect))
    }

    @Test func unavoidableFieldWithoutCaretUsesDefaultPosition() {
        #expect(ClipboardPlacement.frame(size: size, anchor: .init(field: visible), visible: visible) == nil)
    }
}
