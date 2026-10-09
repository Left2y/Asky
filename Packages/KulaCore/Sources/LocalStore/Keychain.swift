import Foundation
import Security
import LocalAuthentication

/// Keychain wrapper for API keys and MCP instance credentials. Values never go to SQLite, logs or exports.
public struct Keychain: Sendable {
    public let service: String

    public init(service: String = "app.kulahere.credentials") { self.service = service }

    public enum KeychainError: Error {
        case status(OSStatus)

        public var requiresAuthentication: Bool {
            switch self {
            case .status(let status): status == errSecInteractionNotAllowed || status == errSecAuthFailed
            }
        }
    }

    public func set(_ secret: String, account: String) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(secret.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    public func get(account: String) -> String? {
        try? read(account: account)
    }

    /// Metadata checks must never decrypt a secret or present authentication UI.
    public func contains(account: String) -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]
        return SecItemCopyMatching(q as CFDictionary, nil) == errSecSuccess
    }

    /// Call interactive reads off the main thread, only for an explicit credential use.
    public func read(account: String, allowInteraction: Bool = true) throws -> String? {
        let context = LAContext()
        context.interactionNotAllowed = !allowInteraction
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        guard let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    public func delete(account: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(q as CFDictionary)
    }
}
