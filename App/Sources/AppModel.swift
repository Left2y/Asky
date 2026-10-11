import AppKit
import Contracts
import LocalStore
import ToolService
import AgentHost
import Adapters
import Memory
import MCPGateway
import MCPLink
import DirectActions
import Router

/// Persisted user settings (non-secret). Secrets stay in Keychain.
struct AppSettings: Codable, Equatable, Sendable {
    var enabledSources: Set<DataSourceID> = [.calendar, .reminders, .notes, .contacts, .chrome, .shortcuts, .messages, .memory]
    var fileScopes: [String] = [FileManager.default.homeDirectoryForCurrentUser.path]
    var excludedDirectories: [String] = ["Library", ".Trash", "node_modules", ".git"]
    var notesFolders: [NotesFolder] = []
    var clipboardEnabled = true
    var clipboardExcludedApps: [String] = ["com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop",
                                            "com.apple.keychainaccess", "com.apple.Passwords"]
    var terminalWorkingDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    var memoryExtractionPaused = false
    var backgroundAI = false
    var proactiveReminders = false

    static let key = "app.settings"
}

/// Reads settings straight from SQLite so `@Sendable` policy closures need no main-actor hop.
struct SettingsReader: Sendable {
    let store: LocalStore
    func load() -> AppSettings { store.codableSetting(AppSettings.key, as: AppSettings.self) ?? AppSettings() }
}

enum ModelSettings {
    static let configKey = "model.config"
    static let keyAccount = "model-api-key"
}

@MainActor @Observable
final class AppModel {
    let store: LocalStore
    let tools: ToolService
    let native: NativeTools
    let memories: MemoryStore
    let gateway: MCPGateway
    let keychain = Keychain()
    let confirmations: ConfirmationCenter
    let exchange: ExchangeRateService
    let terminal: TerminalRunner
    private(set) var agent: AgentHost?
    private(set) var agentUnavailableReason: String?
    private var mcpServer: MCPLinkServer?
    private(set) var mcpServerError: String?

    var settingsTab = SettingsPage.general.rawValue
    let credentialSession = ModelCredentialSession()
    var hotKeyStatus = ""
    var clipboardHotKeyStatus = ""
    var agentHotKeyStatus = ""
    @ObservationIgnored var onHotKeyChange: ((UInt32, UInt32) -> Bool)?
    @ObservationIgnored var onClipboardHotKeyChange: ((UInt32, UInt32) -> Bool)?
    @ObservationIgnored var onAgentHotKeyChange: ((UInt32, UInt32) -> Bool)?
    var preferences: SettingsPreferences {
        didSet {
            store.setCodableSetting(SettingsPreferences.key, preferences)
            NSApp.appearance = preferences.appearance == "system" ? nil : NSAppearance(named: preferences.appearance == "dark" ? .darkAqua : .aqua)
        }
    }
    @ObservationIgnored var onOpenSettings: (() -> Void)?

    func openSettings(permissions: Bool = false) {
        if permissions { settingsTab = "permissions" }
        onOpenSettings?()
    }

    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            store.setCodableSetting(AppSettings.key, settings)
            onSettingsChange?()
        }
    }
    @ObservationIgnored var onSettingsChange: (() -> Void)?
    @ObservationIgnored var onModelAuthenticationFinished: (() -> Void)?
    @ObservationIgnored var onModelAuthenticationStarted: (() -> Void)?
    var keywords: KeywordRegistry {
        didSet { store.setCodableSetting("keywords", keywords) }
    }

    init(root: URL = LocalStore.defaultRoot) throws {
        let store = try LocalStore(root: root)
        self.store = store
        let reader = SettingsReader(store: store)
        settings = reader.load()
        let savedPreferences = store.codableSetting(SettingsPreferences.key, as: SettingsPreferences.self) ?? SettingsPreferences()
        preferences = savedPreferences
        var savedKeywords = store.codableSetting("keywords", as: KeywordRegistry.self) ?? KeywordRegistry()
        if store.codableSetting("websitePresetsInstalled", as: Bool.self) != true {
            savedKeywords.addMissingWebsitePresets(excluding: Set(savedPreferences.aliases.map(\.alias)))
            store.setCodableSetting("keywords", savedKeywords)
            store.setCodableSetting("websitePresetsInstalled", true)
        }
        if store.codableSetting("queryPresetsMigrated", as: Bool.self) != true {
            savedKeywords.migrateQueryPresets(excluding: Set(savedPreferences.aliases.map(\.alias)))
            store.setCodableSetting("keywords", savedKeywords)
            store.setCodableSetting("queryPresetsMigrated", true)
        }
        keywords = savedKeywords
        let confirmations = ConfirmationCenter()
        self.confirmations = confirmations
        memories = MemoryStore(store)
        let instances = MCPInstanceStore(store)
        tools = ToolService(store: store, policy: {
            let s = reader.load()
            return PolicySnapshot(enabledSources: s.enabledSources,
                                  mcpInstances: Dictionary(uniqueKeysWithValues: instances.all().map { ($0.id, $0) }))
        }, presenter: { request in await confirmations.present(request) },
           authorize: { source, origin in try await SystemPermissions.require(source, origin: origin) })
        native = NativeTools(notesFolders: { reader.load().notesFolders })
        gateway = MCPGateway(store: store, tools: tools)
        exchange = ExchangeRateService(cacheURL: store.root.appending(path: "ecb-rates.json"))
        terminal = TerminalRunner(spillDirectory: store.outputDirectory)
    }

    func start() async {
        await native.register(into: tools, memories: memories)
        agent = makeAgentHost()
        refreshMCPServer()
        ClipboardMonitor.cleanup(ClipboardStore(store))
        _ = try? ActivityStore(store).purgeExpired()
    }

    func shutdown() async {
        mcpServer?.stop()
        await agent?.shutdown()
    }

    // MARK: Agent runtime

    /// Bundled runtime first, then the dev checkout recorded in Info.plist.
    static func runtimeEntry() -> String? {
        var candidates: [String] = []
        if let r = Bundle.main.resourceURL { candidates.append(r.appending(path: "AgentRuntime/dist/src/main.js").path) }
        if let root = Bundle.main.object(forInfoDictionaryKey: "KHSourceRoot") as? String, !root.isEmpty {
            candidates.append(URL(filePath: root).appending(path: "AgentRuntime/dist/src/main.js").path)
        }
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func makeAgentHost() -> AgentHost? {
        guard let node = NodeRuntimeLauncher.findNode(bundleResources: Bundle.main.resourceURL) else {
            agentUnavailableReason = "未找到 Node（需要 Node 22+）。"
            return nil
        }
        guard let entry = Self.runtimeEntry() else {
            agentUnavailableReason = "未找到 AgentRuntime（请先在 AgentRuntime/ 运行 npm install && npm run build）。"
            return nil
        }
        let runtimeDir = store.root.appending(path: "runtime")
        let launcher = NodeRuntimeLauncher(nodePath: node, entryScript: entry, dataDirectory: runtimeDir.path,
                                           stderrLog: store.root.appending(path: "runtime-stderr.log").path)
        let store = store, tools = tools
        return AgentHost(launcher: launcher.launcher, configProvider: { [weak self] in
            guard let cfg = store.codableSetting(ModelSettings.configKey, as: ModelConfiguration.self) else { return nil }
            guard let self else { return nil }
            let key = try await self.readModelCredential(account: cfg.credentialRef)
            guard let key, !key.isEmpty else { throw AgentHostError.credentialMissing }
            return RuntimeLaunchConfig(baseURL: cfg.baseURL.absoluteString, model: cfg.modelName, apiKey: key)
        }, toolsProvider: {
            await tools.definitions(for: .agent(sessionID: ""))
        }, toolHandler: { request in
            await tools.submit(request)
        })
    }

    func readModelCredential(account: String) async throws -> String? {
        try await credentialSession.read(account: account, keychain: keychain,
            started: { [weak self] in await MainActor.run { self?.onModelAuthenticationStarted?() } },
            finished: { [weak self] in await MainActor.run { self?.onModelAuthenticationFinished?() } })
    }

    var modelConfiguration: ModelConfiguration? {
        get { store.codableSetting(ModelSettings.configKey, as: ModelConfiguration.self) }
        set { if let newValue { store.setCodableSetting(ModelSettings.configKey, newValue) } else { store.setSetting(ModelSettings.configKey, nil) } }
    }

    var isModelConfigured: Bool {
        guard let cfg = modelConfiguration else { return false }
        return keychain.contains(account: cfg.credentialRef)
    }

    // MARK: External MCP

    /// The link socket only listens while at least one instance is enabled.
    func refreshMCPServer() {
        let anyEnabled = MCPInstanceStore(store).all().contains { $0.enabled }
        if anyEnabled, mcpServer == nil {
            let server = MCPLinkServer(gateway: gateway)
            do {
                try server.start()
                mcpServer = server
                mcpServerError = nil
            } catch {
                mcpServerError = "本地连接启动失败：\(error)"
            }
        } else if !anyEnabled, let server = mcpServer {
            server.stop()
            mcpServer = nil
        }
    }

    var isMCPListening: Bool { mcpServer != nil }

    static var bridgeExecutablePath: String {
        Bundle.main.bundleURL.appending(path: "Contents/MacOS/asky-mcp").path
    }
}
