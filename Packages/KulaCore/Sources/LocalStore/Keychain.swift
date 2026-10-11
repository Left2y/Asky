import Foundation
import Security
import LocalAuthentication

/// Keychain wrapper for API keys and MCP instance credentials. Values never go to SQLite, logs or exports.
public struct Keychain: Sendable {
    public let service: String

    public init(service: String = "app.kulahere.credentials") { self.service = service }

    public enum KeychainError: LocalizedError {
        case status(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .status(let status):
                switch status {
                case errSecUserCanceled: return "钥匙串授权已取消，请重新发送消息并允许 Asky 访问模型 Key。"
                case errSecAuthFailed: return "钥匙串授权失败，请重新发送消息并完成模型 Key 的访问授权。"
                case errSecInteractionNotAllowed: return "钥匙串暂时无法交互，请解锁登录钥匙串后重新发送消息。"
                default: return "读取模型 Key 失败（钥匙串状态码 \(status)）。请检查钥匙串授权或在设置 › 模型中重新保存 Key。"
                }
            }
        }

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
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        // Interactive reads use Keychain's default authorization UI. A fresh LAContext
        // is only needed to explicitly suppress interaction for the first attempt.
        if !allowInteraction {
            let context = LAContext()
            context.interactionNotAllowed = true
            q[kSecUseAuthenticationContext as String] = context
        }
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
