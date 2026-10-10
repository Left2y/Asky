import AppKit
import Carbon.HIToolbox
import LocalStore

struct SettingsPreferences: Codable, Equatable, Sendable {
    var appearance = "system"
    var provider = "custom"
    var hotKeyCode: UInt32 = UInt32(kVK_Space)
    var hotKeyModifiers: UInt32 = UInt32(optionKey)
    var hotKeyLabel = "⌥ Space"
    var aliases: [LauncherAlias] = []
    static let key = "app.preferences.v1"
}

struct LauncherAlias: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var alias: String
    var kind: String
    var target: String
}

/// One credential read per account per app session; concurrent users share the read.
actor ModelCredentialSession {
    private var values: [String: String] = [:]
    private var generations: [String: Int] = [:]
    private var pending: [String: Task<String?, Error>] = [:]

    func remember(_ value: String, account: String) {
        generations[account, default: 0] += 1
        values[account] = value
    }

    func read(account: String, keychain: Keychain,
              started: @escaping @Sendable () async -> Void,
              finished: @escaping @Sendable () async -> Void) async throws -> String? {
        if let value = values[account] { return value }
        if let task = pending[account] {
            let value = try await task.value
            return values[account] ?? value
        }
        let generation = generations[account, default: 0]
        let task = Task.detached { () throws -> String? in
            do { return try keychain.read(account: account, allowInteraction: false) }
            catch let error as Keychain.KeychainError where error.requiresAuthentication {
                await started()
                do {
                    let value = try keychain.read(account: account)
                    await finished()
                    return value
                } catch {
                    await finished()
                    throw error
                }
            }
        }
        pending[account] = task
        defer { pending[account] = nil }
        let value = try await task.value
        if generation != generations[account, default: 0] { return values[account] }
        if let value { values[account] = value }
        return value
    }
}
