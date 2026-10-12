import Testing
import Foundation
import UniformTypeIdentifiers
@testable import ToolService

@MainActor
struct SystemPermissionTests {
    @Test func authorizationOnlyCompletesAfterRealGrantAndOnlyOnce() {
        var progress = PermissionAuthorizationProgress(initialState: .denied)
        let transitions = [progress.observe(.denied), progress.observe(.restricted), progress.observe(.authorized)]
        #expect(transitions == [false, false, true])
        #expect(progress.completed)
        let repeatGrant = progress.observe(.authorized)
        #expect(!repeatGrant)
    }

    @Test func reauthorizationWaitsForRevocationBeforeClosing() {
        var progress = PermissionAuthorizationProgress(initialState: .authorized)
        let existingGrant = [progress.observe(.authorized), progress.observe(.authorized)]
        #expect(existingGrant == [false, false])
        #expect(!progress.completed)
        let regrant = [progress.observe(.denied), progress.observe(.authorized)]
        #expect(regrant == [false, true])
    }

    @Test func booleanPermissionsAllowExplicitRequestButNeverRequestWhenAuthorized() {
        for permission in [SystemPermission.accessibility, .screenRecording, .fullDiskAccess] {
            #expect(permission.canRequest(from: .denied))
            #expect(!permission.canRequest(from: .authorized))
            #expect(!permission.canRequest(from: .restricted))
        }
        for permission in [SystemPermission.calendar, .reminders, .contacts, .notifications] {
            #expect(!permission.canRequest(from: .denied))
            #expect(permission.canRequest(from: .notDetermined))
        }
    }

    @Test func onlyDragPermissionsResetTheirOwnTCCServiceAndOnlyScreenRecordingNeedsRelaunch() {
        #expect(SystemPermission.screenRecording.tccService == "ScreenCapture")
        #expect(SystemPermission.accessibility.tccService == "Accessibility")
        #expect(SystemPermission.fullDiskAccess.tccService == "SystemPolicyAllFiles")
        for permission in SystemPermission.allCases where !permission.supportsAppDrag {
            #expect(permission.tccService == nil)
        }
        #expect(SystemPermission.allCases.filter(\.requiresRelaunchAfterGrant) == [.screenRecording])
    }

    @Test func dragRejectsTemporaryAndNonApplicationURLs() {
        for url in [URL(filePath: "/private/var/folders/T/AppTranslocation/id/d/Asky.app"),
                    URL(filePath: "/Applications/file.txt"), URL(string: "https://example.com/Asky.app")!] {
            #expect(SystemPermissions.appDragProvider(for: url) == nil)
        }
    }

    @Test func dragExportsExactRunningBundlePathIncludingSpaces() async throws {
        let url = URL(filePath: "/Users/test/Development Builds/Asky.app")
        let provider = try #require(SystemPermissions.appDragProvider(for: url))
        #expect(provider.suggestedName == "Asky.app")
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: data ?? Data()) }
            }
        }
        #expect(URL(string: String(decoding: data, as: UTF8.self)) == url)
    }
}
