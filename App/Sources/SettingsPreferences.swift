import AppKit
import Carbon.HIToolbox
import LocalStore
import ToolService

struct SettingsPreferences: Codable, Equatable, Sendable {
    var appearance = "system"
    var language = ApplicationLanguage.system
    var provider = "custom"
    var hotKeyCode: UInt32 = UInt32(kVK_Space)
    var hotKeyModifiers: UInt32 = UInt32(optionKey)
    var hotKeyLabel = "⌥ Space"
    var clipboardHotKeyCode: UInt32 = Self.defaultClipboardHotKey.code
    var clipboardHotKeyModifiers: UInt32 = Self.defaultClipboardHotKey.modifiers
    var clipboardHotKeyLabel = Self.defaultClipboardHotKey.label
    var agentHotKeyCode: UInt32 = Self.defaultAgentHotKey.code
    var agentHotKeyModifiers: UInt32 = Self.defaultAgentHotKey.modifiers
    var agentHotKeyLabel = Self.defaultAgentHotKey.label
    var aliases: [LauncherAlias] = []
    static let key = "app.preferences.v1"
    static let defaultClipboardHotKey = (code: UInt32(kVK_ANSI_C), modifiers: UInt32(controlKey | shiftKey), label: "⌃⇧ C")

    static let defaultAgentHotKey = (code: UInt32(kVK_ANSI_Slash), modifiers: UInt32(controlKey | shiftKey), label: "⌃⇧ /")

    init() {}

    // Saved preferences from older builds lack newer fields; fill defaults instead of discarding everything.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SettingsPreferences()
        appearance = try c.decodeIfPresent(String.self, forKey: .appearance) ?? d.appearance
        let savedLanguage = try c.decodeIfPresent(String.self, forKey: .language)
        language = savedLanguage.flatMap(ApplicationLanguage.init(rawValue:)) ?? .system
        provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? d.provider
        hotKeyCode = try c.decodeIfPresent(UInt32.self, forKey: .hotKeyCode) ?? d.hotKeyCode
        hotKeyModifiers = try c.decodeIfPresent(UInt32.self, forKey: .hotKeyModifiers) ?? d.hotKeyModifiers
        hotKeyLabel = try c.decodeIfPresent(String.self, forKey: .hotKeyLabel) ?? d.hotKeyLabel
        clipboardHotKeyCode = try c.decodeIfPresent(UInt32.self, forKey: .clipboardHotKeyCode) ?? d.clipboardHotKeyCode
        clipboardHotKeyModifiers = try c.decodeIfPresent(UInt32.self, forKey: .clipboardHotKeyModifiers) ?? d.clipboardHotKeyModifiers
        clipboardHotKeyLabel = try c.decodeIfPresent(String.self, forKey: .clipboardHotKeyLabel) ?? d.clipboardHotKeyLabel
        agentHotKeyCode = try c.decodeIfPresent(UInt32.self, forKey: .agentHotKeyCode) ?? d.agentHotKeyCode
        agentHotKeyModifiers = try c.decodeIfPresent(UInt32.self, forKey: .agentHotKeyModifiers) ?? d.agentHotKeyModifiers
        agentHotKeyLabel = try c.decodeIfPresent(String.self, forKey: .agentHotKeyLabel) ?? d.agentHotKeyLabel
        aliases = try c.decodeIfPresent([LauncherAlias].self, forKey: .aliases) ?? d.aliases
    }
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
