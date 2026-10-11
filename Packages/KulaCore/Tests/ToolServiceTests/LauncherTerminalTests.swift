import Foundation
import Testing
@testable import ToolService

@Suite struct LauncherTerminalTests {
    @Test func scriptPreservesCommandAndQuotesDirectory() throws {
        let command = "printf '%s\\n' \"hello\" > result.txt"
        let source = LauncherTerminalScript.source(command: command, directory: URL(filePath: "/tmp/Asky's folder"))
        #expect(source.contains("cd '/tmp/Asky'\\\\''s folder' && printf"))
        #expect(source.contains("\\\"hello\\\" > result.txt"))
        #expect(NSAppleScript(source: source)?.compileAndReturnError(nil) == true)
    }
}
