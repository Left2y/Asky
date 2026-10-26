import Foundation
import LocalStore

/// Explicit opt-in profile for the separately packaged Alma development app.
enum DevelopmentProfile {
    static var isolated: Bool { Bundle.main.object(forInfoDictionaryKey: "KHIsolatedDevelopment") as? Bool == true }
    static var root: URL {
        isolated ? FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/Asky-Alma") : LocalStore.defaultRoot
    }
    static var keychainService: String {
        isolated ? "app.left2y.asky-alma.credentials" : "app.kulahere.credentials"
    }
}
