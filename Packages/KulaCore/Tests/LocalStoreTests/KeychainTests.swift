import Testing
import Foundation
import LocalStore

@Suite struct KeychainTests {
    @Test func metadataAndNoninteractiveReadsUseOnlyTheRequestedAccount() throws {
        let keychain = Keychain(service: "app.kulahere.tests.\(UUID().uuidString)")
        defer { keychain.delete(account: "model") }
        #expect(!keychain.contains(account: "model"))
        #expect(try keychain.read(account: "model", allowInteraction: false) == nil)

        try keychain.set("synthetic-test-credential", account: "model")
        #expect(keychain.contains(account: "model"))
        #expect(!keychain.contains(account: "other"))
        #expect(try keychain.read(account: "model", allowInteraction: false) == "synthetic-test-credential")

        keychain.delete(account: "model")
        #expect(!keychain.contains(account: "model"))
        #expect(try keychain.read(account: "model", allowInteraction: false) == nil)
    }
}
