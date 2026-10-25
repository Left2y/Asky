import Foundation
import Testing
@testable import ToolService

@Suite struct LauncherTerminalTests {
    @Test func removedTerminalBundleIsRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = root.appendingPathComponent("Ghostty.app")
        let contents = url.appendingPathComponent("Contents")
        let executable = contents.appendingPathComponent("MacOS/ghostty")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let plist = try PropertyListSerialization.data(fromPropertyList: [
            "CFBundleIdentifier": LauncherTerminalApplication.ghostty.rawValue,
            "CFBundleExecutable": "ghostty",
            "CFBundlePackageType": "APPL",
        ], format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        #expect(ToolService.validatedLauncherTerminalURL(url, application: .ghostty) == url)
        #expect(ToolService.validatedLauncherTerminalURL(url, application: .iTerm) == nil)
        try FileManager.default.removeItem(at: executable)
        #expect(ToolService.validatedLauncherTerminalURL(url, application: .ghostty) == nil)
        try FileManager.default.removeItem(at: url)
        #expect(ToolService.validatedLauncherTerminalURL(url, application: .ghostty) == nil)
        #expect(ToolService.validatedLauncherTerminalURL(nil, application: .ghostty) == nil)
    }

    @Test @MainActor func missingTerminalIsReportedInsteadOfFallingBack() async {
        guard let missing = LauncherTerminalApplication.allCases.first(where: {
            ToolService.launcherTerminalApplicationURL($0) == nil
        }) else { return }
        do {
            try await ToolService.openLauncherTerminal(command: "echo test", workingDirectory: URL(filePath: "/tmp"), application: missing)
            Issue.record("An uninstalled terminal must not execute through another app")
        } catch {
            #expect((error as NSError).domain == "LauncherTerminal")
            #expect((error as NSError).code == 2)
            #expect(error.localizedDescription.contains(missing.name))
        }
    }

    @Test func thirdPartyDispatchUsesTheirNativeCommandInterfaces() {
        let directory = URL(filePath: "/tmp/test folder")
        let iterm = LauncherTerminalScript.source(command: "echo hello", directory: directory, application: .iTerm)
        #expect(iterm.contains("com.googlecode.iterm2"))
        #expect(iterm.contains("tell current session of win to write text"))
        let ghostty = LauncherTerminalScript.source(command: "echo hello", directory: directory, application: .ghostty)
        #expect(ghostty.contains("com.mitchellh.ghostty"))
        #expect(ghostty.contains("set initial working directory of cfg to \"/tmp/test folder\""))
        #expect(ghostty.contains("set initial input of cfg to \"echo hello\n\""))
    }

    @Test func scriptPreservesCommandAndQuotesDirectory() throws {
        let command = "printf '%s\\n' \"hello\" > result.txt"
        let source = LauncherTerminalScript.source(command: command, directory: URL(filePath: "/tmp/Asky's folder"))
        #expect(source.contains("cd '/tmp/Asky'\\\\''s folder' && printf"))
        #expect(source.contains("\\\"hello\\\" > result.txt"))
        #expect(NSAppleScript(source: source)?.compileAndReturnError(nil) == true)
    }
}
