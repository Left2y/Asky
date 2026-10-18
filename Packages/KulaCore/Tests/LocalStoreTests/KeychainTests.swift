import Testing
import Foundation
import Contracts
import LocalStore
import Security

@Suite struct KeychainTests {
    @Test func authorizationFailuresHaveActionableMessages() {
        #expect(Keychain.KeychainError.status(errSecUserCanceled).localizedDescription == CoreLocalization.text("钥匙串授权已取消，请重新发送消息并允许 Asky 访问模型 Key。"))
        #expect(Keychain.KeychainError.status(errSecAuthFailed).requiresAuthentication)
        #expect(Keychain.KeychainError.status(errSecInteractionNotAllowed).requiresAuthentication)
        #expect(!Keychain.KeychainError.status(errSecUserCanceled).requiresAuthentication)
        #expect(Keychain.KeychainError.status(errSecNotAvailable).localizedDescription.contains(String(errSecNotAvailable)))
    }

    @Test func metadataAndNoninteractiveReadsUseOnlyTheRequestedAccount() throws {
        let keychain = Keychain(service: "app.asky.tests.\(UUID().uuidString)")
        defer { keychain.delete(account: "model") }
        #expect(!keychain.contains(account: "model"))
        #expect(try keychain.read(account: "model", allowInteraction: false) == nil)

        try keychain.set("synthetic-test-credential", account: "model")
        #expect(keychain.contains(account: "model"))
        #expect(!keychain.contains(account: "other"))
        #expect(try keychain.read(account: "model") == "synthetic-test-credential")
        #expect(try keychain.read(account: "model", allowInteraction: false) == "synthetic-test-credential")

        keychain.delete(account: "model")
        #expect(!keychain.contains(account: "model"))
        #expect(try keychain.read(account: "model", allowInteraction: false) == nil)
    }
}
