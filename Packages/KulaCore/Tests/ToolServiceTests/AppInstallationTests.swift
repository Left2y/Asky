import Foundation
import Testing
@testable import ToolService

struct AppInstallationTests {
    @Test func installationLocationExcludesDownloadsDiskImagesAndTranslocation() {
        let home = URL(filePath: "/Users/test")
        #expect(ToolService.appIsInstalled(at: URL(filePath: "/Applications/Asky.app"), home: home))
        #expect(ToolService.appIsInstalled(at: home.appending(path: "Applications/Asky.app"), home: home))
        for path in ["/Users/test/Downloads/Asky.app", "/Volumes/Asky/Asky.app",
                     "/private/var/folders/T/AppTranslocation/id/d/Asky.app",
                     "/Applications/Other/Asky.app"] {
            #expect(!ToolService.appIsInstalled(at: URL(filePath: path), home: home))
        }
    }

    @Test func collisionPreservesExistingAppAndSource() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appending(path: UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let source = root.appending(path: "download.app")
        let installed = root.appending(path: "Asky.app")
        try Data("source".utf8).write(to: source)
        try Data("installed".utf8).write(to: installed)
        #expect(throws: AppUpdateError.self) {
            try ToolService.copyAppForInstallation(from: source, to: installed)
        }
        #expect(try Data(contentsOf: source) == Data("source".utf8))
        #expect(try Data(contentsOf: installed) == Data("installed".utf8))
        #expect(try fm.contentsOfDirectory(atPath: root.path).count == 2)
    }

    @Test func invalidSourceLeavesNoPartialInstallation() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appending(path: UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        #expect(throws: AppUpdateError.self) {
            try ToolService.copyAppForInstallation(from: root.appending(path: "missing.app"),
                                                  to: root.appending(path: "Asky.app"))
        }
        #expect(try fm.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func verifiedBundleCopiesFromPathWithSpacesAndPreservesSource() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appending(path: UUID().uuidString)
        let source = root.appending(path: "Download Folder/Asky.app")
        let contents = source.appending(path: "Contents")
        try fm.createDirectory(at: contents.appending(path: "MacOS"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let info: [String: Any] = ["CFBundleIdentifier": "app.kulahere.KulaHere",
                                  "CFBundleExecutable": "Asky", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appending(path: "Info.plist"))
        let executable = contents.appending(path: "MacOS/Asky")
        try fm.copyItem(at: URL(filePath: "/usr/bin/true"), to: executable)
        try AppUpdate.run("/usr/bin/codesign", ["--force", "--sign", "-", source.path])
        let installed = root.appending(path: "Asky.app")
        try ToolService.copyAppForInstallation(from: source, to: installed)
        #expect(fm.fileExists(atPath: executable.path))
        #expect(Bundle(url: installed)?.bundleIdentifier == "app.kulahere.KulaHere")
        try AppUpdate.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", installed.path])
        // A corrupted signed source must fail without leaving a partial app behind.
        try Data("corrupted".utf8).write(to: executable)
        let rejected = root.appending(path: "Rejected.app")
        #expect(throws: AppUpdateError.self) {
            try ToolService.copyAppForInstallation(from: source, to: rejected)
        }
        #expect(!fm.fileExists(atPath: rejected.path))
        #expect(try fm.contentsOfDirectory(atPath: root.path).sorted() == ["Asky.app", "Download Folder"])
    }
}
