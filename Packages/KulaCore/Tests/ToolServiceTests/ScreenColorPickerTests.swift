import AppKit
import Testing
@testable import ToolService

@MainActor
struct ScreenColorPickerTests {
    @Test func standardHexAndProfileConversion() throws {
        #expect(ToolService.screenColorHex(NSColor(srgbRed: 1, green: 147.0 / 255, blue: 23.0 / 255, alpha: 1)) == "#FF9317")
        #expect(ToolService.screenColorHex(.black) == "#000000")
        #expect(ToolService.screenColorHex(.white) == "#FFFFFF")
        #expect(ToolService.screenColorHex(NSColor(srgbRed: 0.5, green: 0, blue: 1, alpha: 0.2)) == "#8000FF")
        let p3 = NSColor(displayP3Red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
        let srgb = try #require(p3.usingColorSpace(.sRGB))
        #expect(ToolService.screenColorHex(p3) == ToolService.screenColorHex(srgb))
        #expect(ToolService.screenColorHex(p3) != "#996633")
    }

    @Test func copiesPlainTextThatClipboardCanRecognize() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("previous", forType: .string)
        #expect(ToolService.copyScreenColor(NSColor(srgbRed: 1, green: 147.0 / 255, blue: 23.0 / 255, alpha: 1), to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "#FF9317")
        #expect(ClipboardAccess.snapshot(from: pasteboard).text == "#FF9317")
        #expect(ClipboardAccess.snapshot(from: pasteboard).image == nil)
    }
}
