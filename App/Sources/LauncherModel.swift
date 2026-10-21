import AppKit
import Contracts
import Router
import Search
import DirectActions
import LocalStore
import Adapters
import ToolService

/// Shortcut names, listed once per panel session (the `shortcuts` CLI is slow to spawn).
final class ShortcutsProvider: SearchProvider, @unchecked Sendable {
    let source = SearchSource.shortcut
    private let lock = NSLock()
    private var names: [String]?

    func invalidate() { lock.withLock { names = nil } }

    func search(_ query: String, limit: Int) async -> [SearchResult] {
        var all = lock.withLock { names }
        if all == nil {
            all = await ToolService.listLauncherShortcuts()
            lock.withLock { names = all }
        }
        return (all ?? []).compactMap { name -> SearchResult? in
            guard let s = FuzzyMatch.score(query, in: name) else { return nil }
            return SearchResult(source: .shortcut, target: TargetRef(kind: "shortcut", identifier: name), title: name,
                                subtitle: NSLocalizedString("快捷指令", comment: ""), actions: [.runShortcut(name: name)], score: s * 0.9)
        }.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }
}

enum LauncherFilter: String, CaseIterable, Identifiable {
    case all, applications, files, quickLinks, shortcuts, calculatorHistory, windows
    static let commands: [(String, String, String)] = [
        ("windows", "搜索窗口", "sw"), ("calculatorHistory", "计算历史", "calc"), ("files", "搜索文件", "file"), ("applications", "搜索应用", "app"),
        ("quickLinks", "搜索快捷方式", "ql"), ("shortcuts", "搜索快捷指令", "sc")
    ]
    init?(commandID: String) {
        guard commandID != "all", let value = Self(rawValue: commandID) else { return nil }
        self = value
    }
    var id: String { rawValue }
    /// All sources stay compact; choosing a category requests a larger searchable list.
    var providerLimit: Int { self == .all ? 8 : 200 }
    var displayLimit: Int { self == .all ? 40 : 200 }
    var title: String {
        switch self {
        case .windows: "窗口"
        case .calculatorHistory: "计算历史"
        case .all: "全部"
        case .applications: "应用"
        case .files: "文件"
        case .quickLinks: "快捷方式"
        case .shortcuts: "快捷指令"
        }
    }
    func includes(_ source: SearchSource) -> Bool {
        switch self {
        case .windows: source == .app
        case .calculatorHistory: source == .calculator
        case .all: true
        case .applications: source == .app
        case .files: source == .file
        case .quickLinks: source == .keyword
        case .shortcuts: source == .shortcut
        }
    }
}

struct TerminalSession: Identifiable {
    let id = UUID()
    let command: String
    var output = ""
    var exitCode: Int32?
    var spilled: URL?
    var handedOff = false
}

@MainActor @Observable
final class LauncherModel {
    private(set) var filter = LauncherFilter.all
    private var filterText = ""
    private var windowSnapshot: LauncherWindowSnapshot?
    private var folderStack: [(url: URL, previousText: String)] = []
    private var folderText = ""
    var folderScope: URL? { folderStack.last?.url }

    func setFilter(_ value: LauncherFilter, query: String? = nil) {
        let text = query ?? inputText
        folderStack = []
        folderText = ""
        windowSnapshot = nil
        filter = value
        filterText = text
        if value == .all { inputState.replaceRawQuery(text, keywords: app.keywords, bookmarksEnabled: canSearchBookmarks) }
        if value != .all { inputState.leaveCommand() }
        rebuildProviders()
        batches = []
        update()
    }

    /// Category prefixes are parsed only at the root, never inside another mode or folder.
    private func enterCategoryCommand(_ value: String) -> Bool {
        guard filter == .all, folderScope == nil, !inputState.hasScope,
              let separator = value.firstIndex(where: \.isWhitespace) else { return false }
        let token = String(value[..<separator])
        guard let command = LauncherFilter.commands.first(where: {
            app.commandKeyword($0.0).caseInsensitiveCompare(token) == .orderedSame
        }), let category = LauncherFilter(commandID: command.0) else { return false }
        setFilter(category, query: String(value[value.index(after: separator)...]))
        return true
    }

    private var storedInputState = LauncherInputState()
    /// Always parse with the current terminal keyword from settings.
    private var inputState: LauncherInputState {
        get {
            var state = storedInputState
            state.terminalKeyword = app.settings.terminalCommandKeyword
            state.tabToken = app.commandKeyword("tabs")
            state.bookmarkToken = app.commandKeyword("bookmark")
            state.linkToken = app.commandKeyword("link")
            state.aiToken = app.commandKeyword("ai")
            return state
        }
        set { storedInputState = newValue }
    }
    var query: String {
        get { folderScope != nil ? folderText : filter == .all ? inputState.rawQuery : filterText }
        set {
            if enterCategoryCommand(newValue) { return }
            if folderScope != nil { folderText = newValue }
            else if filter == .all { inputState.replaceRawQuery(newValue, keywords: app.keywords, bookmarksEnabled: canSearchBookmarks) }
            else { filterText = newValue }
            update()
        }
    }
    private(set) var results: [SearchResult] = []
    private(set) var isSearching = false
    private(set) var currencyConversion: CurrencyResult?
    var selection = 0 {
        didSet { if selection != oldValue { closeActionsMenu() } }
    }
    @ObservationIgnored var actionsMenuFrame = CGRect.zero
    private(set) var isActionsMenuPresented = false
    var actionSelection = 0
    private var actionMenuTarget: SearchResult?
    private(set) var terminal: TerminalSession?
    private(set) var status: String?
    /// Transient feedback shown above the shell, like the clipboard panel's toast.
    private(set) var toast: String?
    private var toastTask: Task<Void, Never>?

    var actionPreferences: SettingsPreferences { app.preferences }
    private let app: AppModel
    private let apps: AppsProvider
    private let files: SpotlightProvider
    private let chrome = ChromeTabsProvider()
    private let shortcuts = ShortcutsProvider()
    private var coordinator: SearchCoordinator
    private var tabCoordinator: SearchCoordinator?
    /// Bookmarks are searched only inside the `bm` scope, never in default search.
    private var bookmarkCoordinator: SearchCoordinator?
    private let searchProviders: [any SearchProvider]?
    private var searchProviderCount = 0
    private var searchSources: Set<SearchSource> = []
    private var remainingSearchProviders = 0
    private var batches: [SearchBatch] = []
    private var direct: [SearchResult] = []
    private var builtInCommandIDs: [String: String] = [:]
    private var chromeAccessTask: Task<Void, Never>?
    private let chromeAccessOverride: Bool?
    private(set) var chromeBookmarkAccessAllowed = false
    private var searchTask: Task<Void, Never>?
    private var currencyTask: Task<Void, Never>?
    private var terminalTask: Task<Void, Never>?
    private(set) var isConfirmingQuit = false
    var onQuit: () -> Void = { NSApp.terminate(nil) }
    var onHide: () -> Void = {}
    var onAskAI: (String) -> Void = { _ in }

    init(app: AppModel, searchProviders: [any SearchProvider]? = nil, chromeBookmarkAccessAllowed: Bool? = nil) {
        self.app = app
        self.searchProviders = searchProviders
        self.chromeAccessOverride = chromeBookmarkAccessAllowed
        apps = AppsProvider(cacheURL: searchProviders == nil
            ? app.store.root.appendingPathComponent("Caches/app-index.json") : nil)
        let reader = SettingsReader(store: app.store)
        files = SpotlightProvider(settings: {
            let s = reader.load()
            return (s.fileScopes.map { URL(filePath: $0) }, s.excludedDirectories)
        })
        coordinator = SearchCoordinator(providers: [])
        rebuildProviders()
        if searchProviders == nil { prewarm() }
    }

    /// Pays every per-process first-use cost in the background so the first search after
    /// launch is as fast as later ones. Chrome is skipped: it may raise an automation prompt.
    private func prewarm() {
        apps.prewarm()
        files.prewarm()
        let apps = apps
        Task.detached(priority: .utility) {
            ToolService.prewarmLauncherIcons(filePaths: Array(apps.applicationPaths().prefix(12)))
        }
    }

    func rebuildProviders() {
        if searchProviders == nil { apps.prewarm() }
        chromeAccessTask?.cancel()
        chromeBookmarkAccessAllowed = chromeAccessOverride ?? (searchProviders != nil)
        configureProviders()
        guard searchProviders == nil, chromeAccessOverride == nil else { return }
        chromeAccessTask = Task { [weak self] in
            guard let self else { return }
            let state = await self.app.refreshChromeBookmarkAccess()
            guard !Task.isCancelled else { return }
            self.chromeBookmarkAccessAllowed = state == .authorized
            self.configureProviders()
            let rawQuery = self.query
            if self.filter == .all, self.folderScope == nil {
                self.inputState.replaceRawQuery(rawQuery, keywords: self.app.keywords,
                                                bookmarksEnabled: self.canSearchBookmarks)
            }
            self.update()
        }
    }

    private func configureProviders() {
        coordinator.cancel()
        bookmarkCoordinator?.cancel()
        tabCoordinator?.cancel()
        if let searchProviders {
            let general = searchProviders.filter { $0.source != .bookmark &&
                ($0.source != .link || chromeBookmarkAccessAllowed) && filter.includes($0.source) }
            let tabs = searchProviders.filter { $0.source == .chromeTab && app.settings.enabledSources.contains(.chrome) }
            tabCoordinator = tabs.isEmpty ? nil : SearchCoordinator(providers: tabs)
            let marks = searchProviders.filter { $0.source == .bookmark && chromeBookmarkAccessAllowed }
            searchProviderCount = general.count
            searchSources = Set(general.map(\.source))
            coordinator = SearchCoordinator(providers: general, perProviderLimit: filter.providerLimit)
            bookmarkCoordinator = marks.isEmpty ? nil : SearchCoordinator(providers: marks)
            return
        }
        let reader = SettingsReader(store: app.store)
        let useChrome = app.settings.enabledSources.contains(.chrome)
        let links = LinksProvider(knownSites: { [chrome] in
            useChrome ? ((try? ChromeBookmarkService.read(accessBookmark: reader.load().chromeBookmarkFolderAccess)) ?? []).map(\.url) + chrome.cachedURLs : []
        })
        var providers: [any SearchProvider] = [apps, shortcuts, files]
        tabCoordinator = useChrome ? SearchCoordinator(providers: [chrome]) : nil
        if useChrome { providers.append(chrome) }
        if useChrome && chromeBookmarkAccessAllowed {
            providers.append(links)
            bookmarkCoordinator = SearchCoordinator(providers: [ChromeBookmarksProvider(load: {
                try ChromeBookmarkService.read(accessBookmark: reader.load().chromeBookmarkFolderAccess)
            }, onFailure: { [weak self] query, _ in
                Task { @MainActor in
                    guard let self, self.isBookmarkScope, self.inputText.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
                    self.chromeBookmarkAccessAllowed = false
                    self.configureProviders()
                    self.inputState.replaceRawQuery(self.query, keywords: self.app.keywords, bookmarksEnabled: false)
                    self.update()
                }
            })])
        } else {
            bookmarkCoordinator = nil
        }
        providers = providers.filter { filter.includes($0.source) }
        searchProviderCount = providers.count
        searchSources = Set(providers.map(\.source))
        coordinator = SearchCoordinator(providers: providers, perProviderLimit: filter.providerLimit)
    }

    /// Panel hidden: cancel work and drop result payloads (resource scope = panel).
    func reset() {
        windowSnapshot = nil
        folderStack = []
        folderText = ""
        closeActionsMenu()
        filter = .all
        filterText = ""
        chromeAccessTask?.cancel()
        coordinator.cancel()
        bookmarkCoordinator?.cancel()
        tabCoordinator?.cancel()
        searchTask?.cancel()
        currencyTask?.cancel()
        batches = []
        direct = []
        results = []
        isSearching = false
        remainingSearchProviders = 0
        status = nil
        toastTask?.cancel()
        toast = nil
        if terminal?.exitCode != nil || terminal == nil { terminal = nil }
        shortcuts.invalidate()
        chrome.invalidate()
        if !query.isEmpty { query = "" }
    }

    private var router: IntentRouter {
        IntentRouter(keywords: app.keywords, terminalKeyword: app.settings.terminalCommandKeyword)
    }

    var commandInput: (command: KeywordCommand, text: String)? {
        inputState.command.map { (command: $0, text: inputState.text) }
    }

    var calculation: (expression: String, result: String)? {
        guard filter == .all, !hasScope, case .calculation(_, let value) = router.route(query) else { return nil }
        return (query, Calculator.format(value))
    }

    var unitConversion: ConversionResult? {
        guard filter == .all, !hasScope, case .conversion(let value) = router.route(query) else { return nil }
        return value
    }

    var calculationCompletion: String? { calculation.map { "= " + $0.result } }

    var terminalApplication: LauncherTerminalApplication {
        app.settings.terminalApplicationID.flatMap(LauncherTerminalApplication.init(rawValue:)) ?? .system
    }

    var terminalIcon: NSImage? { ToolService.launcherTerminalIcon(terminalApplication) }

    var isTerminalScope: Bool { inputState.terminal }
    private var canSearchBookmarks: Bool { chromeBookmarkAccessAllowed && app.settings.enabledSources.contains(.chrome) }
    var isTabScope: Bool { inputState.tabs }
    var isBookmarkScope: Bool { inputState.bookmarks }
    var isLinkScope: Bool { inputState.links }
    var isAIScope: Bool { inputState.ai }
    var hasScope: Bool { filter != .all || folderScope != nil || inputState.hasScope }

    var inputText: String {
        get { folderScope != nil ? folderText : filter == .all ? inputState.text : filterText }
        set {
            if enterCategoryCommand(newValue) { return }
            if folderScope != nil { folderText = newValue }
            else if filter == .all { inputState.edit(newValue, keywords: app.keywords, bookmarksEnabled: canSearchBookmarks) }
            else { filterText = newValue }
            update()
        }
    }

    func leaveCommand() {
        guard hasScope else { return }
        if let previous = folderStack.popLast() {
            folderText = folderStack.isEmpty ? "" : previous.previousText
            update()
            return
        }
        if filter != .all {
            setFilter(.all)
            return
        }
        inputState.leaveCommand()
        update()
    }

    func backspaceOnEmptyInput() -> Bool {
        if folderScope != nil {
            guard folderText.isEmpty else { return false }
            if app.preferences.folderBackspaceBehavior == .exitNavigation {
                folderStack = []
                folderText = ""
                filterText = ""
                inputState.replaceRawQuery("", keywords: app.keywords, bookmarksEnabled: canSearchBookmarks)
                update()
            } else {
                leaveCommand()
            }
            return true
        }
        if filter != .all {
            guard inputText.isEmpty else { return false }
            leaveCommand()
            return true
        }
        guard inputState.backspaceOnEmptyText() else { return false }
        update()
        return true
    }

    @discardableResult
    func enterSelectedFolder() -> Bool {
        guard !isActionsMenuPresented, results.indices.contains(selection) else { return false }
        let result = results[selection]
        guard result.source == .file,
              let folder = ToolService.launcherFolder(at: result.target.identifier) else { return false }
        folderStack.append((folder, inputText))
        folderText = ""
        update()
        return true
    }

    var canEnterSelectedFolder: Bool {
        guard results.indices.contains(selection), results[selection].source == .file else { return false }
        return ToolService.launcherFolder(at: results[selection].target.identifier) != nil
    }

    func keyword(for result: SearchResult) -> String? {
        guard result.source == .keyword else { return nil }
        if result.target.kind == "keyword-match" {
            return KeywordCommand.builtIn.first { $0.url(for: "")?.absoluteString == result.target.identifier }?.keyword
        }
        if let command = commandInput?.command {
            return KeywordCommand.builtIn.first { $0.urlTemplate == command.urlTemplate }?.keyword
        }
        return KeywordCommand.builtIn.first {
            $0.url(for: query.trimmingCharacters(in: .whitespacesAndNewlines))?.absoluteString == result.target.identifier
        }?.keyword
    }

    private func update() {
        closeActionsMenu()
        builtInCommandIDs = [:]
        if inputState.bookmarks && !canSearchBookmarks {
            let rawQuery = inputState.rawQuery
            inputState.replaceRawQuery(rawQuery, keywords: app.keywords, bookmarksEnabled: false)
        }
        currencyConversion = nil
        status = nil
        selection = 0
        searchTask?.cancel()
        coordinator.cancel()
        bookmarkCoordinator?.cancel()
        tabCoordinator?.cancel()
        currencyTask?.cancel()
        if let folder = folderScope {
            searchFolder(folder)
            return
        }
        if filter == .windows {
            searchWindows()
            return
        }
        if filter == .calculatorHistory {
            batches = []
            isSearching = false
            remainingSearchProviders = 0
            direct = ToolService.calculatorHistory(in: app.store, query: inputText).map { record in
                SearchResult(source: .calculator,
                             target: TargetRef(kind: "calculator-history", identifier: record.id),
                             title: "\(record.expression) = \(record.result)",
                             actions: [.copy(record.result)], score: 100)
            }
            status = direct.isEmpty ? NSLocalizedString("暂无计算记录", tableName: "Launcher", comment: "") : nil
            publish()
            return
        }
        if inputState.ai || inputState.links {
            batches = []
            isSearching = false
            remainingSearchProviders = 0
            direct = []
            if inputState.ai {
                direct = router.askAIResult(for: inputState.text).map { result in
                    var result = result
                    result.title = String(format: NSLocalizedString("询问 AI：%@", comment: ""), inputState.text)
                    return [result]
                } ?? []
            } else if let url = LauncherWebURL.parse(inputState.text) {
                direct = [SearchResult(source: .link, target: TargetRef(kind: "url", identifier: url.absoluteString),
                                       title: NSLocalizedString("打开链接", comment: ""), subtitle: url.absoluteString,
                                       actions: [.openURL(url), .copy(url.absoluteString)], score: 100)]
            }
            publish()
            return
        }
        if inputState.tabs || inputState.bookmarks {
            searchScopedBrowser(inputState.text)
            return
        }
        let route: Route = filter != .all
            ? (query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .search(query: query))
            : isTerminalScope && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Route.empty
            : commandInput.map { Route.keyword($0.command, query: $0.text) } ?? router.route(query)
        isSearching = router.includesSearch(route) && searchProviderCount > 0
        remainingSearchProviders = isSearching ? searchProviderCount : 0
        direct = router.directResults(for: route)
        // Core routing keeps stable command names; presentation uses the app's bundle.
        if case .keyword(let command, let text) = route {
            let name = NSLocalizedString(command.name, comment: "Built-in website command")
            direct = direct.map { result in
                var result = result
                if let preset = KeywordCommand.builtIn.first(where: { $0.urlTemplate == command.urlTemplate }) {
                    builtInCommandIDs[result.id] = preset.keyword
                }
                result.title = command.supportsQuery
                    ? String(format: NSLocalizedString("%@：%@", comment: "Website search result"), name, text)
                    : String(format: NSLocalizedString("打开 %@", comment: "Open website"), name)
                if !command.supportsQuery {
                    result.subtitle = NSLocalizedString("仅打开网页，问题不会传递到网站", comment: "Website command limitation")
                }
                return result
            }
        }
        if case .conversation(let prompt) = route {
            direct = direct.map { result in
                var result = result
                result.title = String(format: NSLocalizedString("询问 AI：%@", comment: ""), prompt)
                return result
            }
        }
        if case .terminal(let command) = route {
            direct = direct.map { result in
                var result = result
                result.title = String(format: NSLocalizedString("运行：%@", comment: ""), command)
                result.subtitle = NSLocalizedString("↩ 在终端中运行", comment: "")
                return result
            }
        }
        if case .search(let text) = route {
            if filter == .all, QuitAskyCommand.matches(text) { direct.append(QuitAskyCommand.result) }
            direct += app.keywords.commands.compactMap { command in
                let exact = command.keyword.caseInsensitiveCompare(text.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                guard exact || command.urlTemplate.contains("{query}"),
                      let url = command.url(for: exact ? "" : text) else { return nil }
                let result = SearchResult(source: .keyword, target: TargetRef(kind: exact ? "keyword-match" : "url", identifier: url.absoluteString),
                                          title: NSLocalizedString(command.name, comment: "Built-in website command"), actions: [.openURL(url)], score: 0)
                if let preset = KeywordCommand.builtIn.first(where: { $0.urlTemplate == command.urlTemplate }) {
                    builtInCommandIDs[result.id] = preset.keyword
                }
                return result
            }
            let aliasQuery = text.trimmingCharacters(in: .whitespacesAndNewlines)
            direct += app.preferences.aliases.compactMap { item in
                guard item.alias.caseInsensitiveCompare(aliasQuery) == .orderedSame else { return nil }
                let actions: [ResultAction] = item.kind == "shortcut" ? [.runShortcut(name: item.target)] : [.open, .revealInFinder]
                return SearchResult(source: .keyword, target: TargetRef(kind: "launcher-alias", identifier: item.target),
                                    title: item.alias, subtitle: item.kind == "app" ? URL(filePath: item.target).deletingPathExtension().lastPathComponent : item.target,
                                    actions: actions, score: 100)
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if filter == .all {
                for command in AppModel.searchCommands {
                    let exact = app.commandKeyword(command.0).caseInsensitiveCompare(trimmed) == .orderedSame
                    let categoryName = (LauncherFilter(commandID: command.0) != nil || command.0 == "colorPicker") && !trimmed.isEmpty &&
                        (command.1.localizedStandardContains(trimmed) ||
                         NSLocalizedString(command.1, comment: "").localizedStandardContains(trimmed))
                    guard exact || categoryName,
                          command.0 != "bookmark" || canSearchBookmarks,
                          command.0 != "tabs" || tabCoordinator != nil else { continue }
                    direct.append(SearchResult(source: .keyword, target: TargetRef(kind: "search-command", identifier: command.0),
                                               title: NSLocalizedString(command.1, comment: ""), actions: [.open], score: 100))
                }
            }
            let hasExactSearchCommand = direct.contains { $0.target.kind == "search-command" }
            if filter == .all, !hasExactSearchCommand, tabCoordinator != nil, !trimmed.isEmpty {
                direct.append(SearchResult(source: .chromeTab, target: TargetRef(kind: "tab-search", identifier: trimmed),
                                           title: NSLocalizedString("搜索开启的标签页", comment: ""), subtitle: trimmed, actions: [.open], score: 0))
            }
            if filter == .all, !hasExactSearchCommand, bookmarkCoordinator != nil, !trimmed.isEmpty {
                direct.append(SearchResult(source: .bookmark, target: TargetRef(kind: Self.bookmarkSearchKind, identifier: trimmed),
                                           title: NSLocalizedString("搜索书签", comment: ""), subtitle: trimmed, actions: [.open], score: 0))
            }
        }
        batches = router.includesSearch(route) ? retainedBatches(for: query) : []
        if case .currency(let q) = route {
            isSearching = true
            status = nil
            let exchange = app.exchange
            currencyTask = Task { [weak self] in
                let loadingHint = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                    self?.status = NSLocalizedString("正在获取汇率…", comment: "")
                }
                defer { loadingHint.cancel() }
                let rows = await withTaskCancellationHandler {
                    await ToolService.launcherCurrencyResults(q, service: exchange)
                } onCancel: {
                    loadingHint.cancel()
                }
                guard !Task.isCancelled, let self else { return }
                self.isSearching = false
                self.status = nil
                self.currencyConversion = rows.first
                self.direct = rows.map(Self.currencyRow)
                self.publish()
            }
        }
        if router.includesSearch(route) {
            let text = query
            searchTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { return }
                guard let self, !Task.isCancelled else { return }
                self.coordinator.query(text) { [weak self] batch in
                    guard let self else { return }
                    self.batches.removeAll { $0.provider == batch.provider }
                    self.batches.append(batch)
                    self.remainingSearchProviders = max(0, self.remainingSearchProviders - 1)
                    self.isSearching = self.remainingSearchProviders > 0
                    self.publish()
                }
            }
        } else {
            coordinator.cancel()
        }
        publish()
    }

    func windowApplicationPath(for result: SearchResult) -> String? {
        guard result.target.kind == "application-window" else { return nil }
        return windowSnapshot?.entries.first { $0.id == result.target.identifier }?.applicationPath
    }

    private func searchWindows() {
        let text = inputText
        direct = []
        batches = []
        isSearching = true
        remainingSearchProviders = 1
        publish()
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                let snapshot: LauncherWindowSnapshot
                if let cached = self.windowSnapshot { snapshot = cached }
                else { snapshot = try await ToolService.launcherWindows() }
                guard !Task.isCancelled, self.filter == .windows, self.inputText == text else { return }
                self.windowSnapshot = snapshot
                self.direct = LauncherWindowSnapshot.results(from: snapshot.entries, query: text)
                self.status = self.direct.isEmpty ? NSLocalizedString("没有匹配的窗口", comment: "") : nil
            } catch {
                guard let self, !Task.isCancelled, self.filter == .windows else { return }
                self.status = NSLocalizedString("请在系统设置中授予 Asky 辅助功能权限后重新搜索窗口", comment: "")
            }
            guard let self, !Task.isCancelled else { return }
            self.isSearching = false
            self.remainingSearchProviders = 0
            self.publish()
        }
    }

    private static let bookmarkSearchKind = "bookmark-search"

    private func searchFolder(_ folder: URL) {
        let text = folderText
        let excluded = app.settings.excludedDirectories
        direct = []
        batches = []
        isSearching = true
        remainingSearchProviders = 1
        publish()
        searchTask = Task { [weak self] in
            do {
                if !text.isEmpty { try await Task.sleep(for: .milliseconds(100)) }
                let rows = try await ToolService.searchLauncherFolder(folder, query: text, excluded: excluded)
                guard let self, !Task.isCancelled, self.folderScope == folder, self.folderText == text else { return }
                self.direct = rows
                self.isSearching = false
                self.remainingSearchProviders = 0
                self.status = rows.isEmpty ? NSLocalizedString("文件夹中没有匹配项目", comment: "") : nil
                self.publish()
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.isSearching = false
                self.remainingSearchProviders = 0
                self.status = NSLocalizedString("无法读取文件夹，请检查访问权限或文件夹是否已移动。", comment: "")
                self.publish()
            }
        }
    }

    private func searchScopedBrowser(_ text: String) {
        let searchingTabs = inputState.tabs
        let scopedCoordinator = searchingTabs ? tabCoordinator : bookmarkCoordinator
        direct = []
        batches = []
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        isSearching = hasText && scopedCoordinator != nil
        remainingSearchProviders = isSearching ? 1 : 0
        if isSearching, let coordinator = scopedCoordinator {
            searchTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { return }
                guard let self, !Task.isCancelled else { return }
                coordinator.query(text) { [weak self] batch in
                    guard let self, searchingTabs ? self.inputState.tabs : self.inputState.bookmarks else { return }
                    self.batches = [batch]
                    self.remainingSearchProviders = 0
                    self.isSearching = false
                    self.publish()
                }
            }
        }
        publish()
    }

    private func retainedBatches(for query: String) -> [SearchBatch] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reuse concrete targets that still match the new input. Query-dependent
        // actions (links, keyword URLs, AI prompts) are always rebuilt separately.
        return batches.compactMap { previous in
            guard searchSources.contains(previous.provider),
                  [.app, .file, .bookmark, .chromeTab, .shortcut].contains(previous.provider) else { return nil }
            var batch = previous
            batch.results = batch.results.filter { result in
                FuzzyMatch.score(text, in: result.title) != nil ||
                    ([.bookmark, .chromeTab].contains(result.source) &&
                     FuzzyMatch.score(text, in: result.subtitle) != nil)
            }
            return batch
        }
    }

    private static func currencyRow(_ r: CurrencyResult) -> SearchResult {
        switch r {
        case .converted(let value, _, _, _, let q):
            let v = String(format: "%.2f", value)
            return SearchResult(source: .currency, target: TargetRef(kind: "fx", identifier: q.to),
                                title: "\(v) \(CurrencyPresentation.name(for: q.to)) · \(q.to)",
                                subtitle: "",
                                actions: [], score: 100)
        case .unavailable(let reason):
            return SearchResult(source: .currency, target: TargetRef(kind: "fx", identifier: "na"),
                                title: NSLocalizedString("汇率不可用", comment: ""), subtitle: reason, actions: [], score: 100)
        }
    }

    private func publish() {
        var merged = direct + ResultMerger.merge(batches, limit: filter.displayLimit)
        // Generic search shortcuts are not local matches. Plain text with no
        // concrete target falls back to AI regardless of its wording.
        if filter == .all, !hasScope, case .search = router.route(query) {
            let hasLocalMatch = merged.contains {
                if $0.target.kind == "search-command" { return true }
                return ($0.source != .keyword || ($0.target.kind == "keyword-match" || $0.target.kind == "launcher-alias" || QuitAskyCommand.isResult($0))) && $0.source != .askAI && $0.target.kind != "bookmark-search" && $0.target.kind != "tab-search"
            }
            if !hasLocalMatch { merged = [] }
        }
        // An empty result is not a confirmed no-match while search or currency work is pending.
        // Defer the AI-only fallback so the list never briefly opens with just AI.
        if filter == .all, !hasScope, !merged.contains(where: { $0.source == .askAI }),
           (!isSearching || !merged.isEmpty),
           var ask = router.askAIResult(for: query) {
            ask.title = String(format: NSLocalizedString("询问 AI：%@", comment: ""), query)
            merged.append(ask)
        }
        merged = merged.filter { filter.includes($0.source) &&
            (![.link, .bookmark].contains($0.source) || canSearchBookmarks || (inputState.links && $0.source == .link)) }
        let order: [SearchSource] = [.app, .link, .bookmark, .file, .chromeTab, .shortcut, .keyword, .calculator, .conversion, .currency, .terminal, .askAI]
        let priority = merged.filter { ($0.target.kind == "keyword-match" || $0.target.kind == "launcher-alias") || $0.source == .shortcut }
        let remaining = merged.filter { $0.target.kind != "keyword-match" && $0.target.kind != "launcher-alias" && $0.source != .shortcut }
        merged = priority.filter { ($0.target.kind == "keyword-match" || $0.target.kind == "launcher-alias") }
            + priority.filter { $0.source == .shortcut }
            + order.flatMap { source in remaining.filter { $0.source == source } }
        // An alias and its provider result open the same target. Keep the alias
        // in its priority position instead of listing that application/shortcut twice.
        let aliases = merged.filter { $0.target.kind == "launcher-alias" }
        merged.removeAll { result in
            guard [.app, .shortcut].contains(result.source) else { return false }
            return aliases.contains { alias in
                alias.target.identifier == result.target.identifier &&
                    (result.source == .app ? alias.primaryAction == .open : alias.primaryAction == result.primaryAction)
            }
        }
        // Exact command triggers must remain visible ahead of fuzzy app/shortcut matches.
        let exactEntries = merged.filter { $0.target.kind == "search-command" }
        merged = exactEntries + merged.filter { $0.target.kind != "search-command" }
        merged = merged.filter(QuitAskyCommand.isResult) + merged.filter { !QuitAskyCommand.isResult($0) }
        if isActionsMenuPresented, merged.indices.contains(selection), merged[selection] != actionMenuTarget {
            closeActionsMenu()
        }
        if merged.isEmpty { closeActionsMenu() }
        if filter != .all && filter != .windows { merged = Array(merged.prefix(filter.displayLimit)) }
        results = merged
        selection = min(selection, max(0, results.count - 1))
    }

    func move(_ delta: Int) {
        if isActionsMenuPresented {
            actionSelection = min(max(actionSelection + delta, 0), max(0, secondaryActions.count - 1))
            return
        }
        guard currencyConversion == nil, unitConversion == nil, !results.isEmpty else { return }
        selection = min(max(selection + delta, 0), results.count - 1)
    }

    /// ⌥⌘C copies the selected file/app path, like Finder's "Copy as Pathname".
    func copySelectedPath() -> Bool {
        guard currencyConversion == nil, unitConversion == nil, results.indices.contains(selection),
              results[selection].actions.contains(.revealInFinder) else { return false }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(results[selection].target.identifier, forType: .string)
        showToast(NSLocalizedString("已拷贝路径", comment: ""))
        return true
    }

    /// Copy the selected file or app bundle as a Finder-pasteable file URL.
    @discardableResult
    func copySelectedFile() -> Bool {
        guard let result = selectedActionResult, [.file, .app].contains(result.source),
              result.actions.contains(.revealInFinder) else { return false }
        closeActionsMenu()
        if ClipboardAccess.copyFile(at: URL(fileURLWithPath: result.target.identifier)) {
            showToast(NSLocalizedString("已拷贝", comment: ""))
        } else {
            showToast(NSLocalizedString("无法拷贝文件", comment: ""))
        }
        return true
    }

    @discardableResult
    func copySelectedFileName() -> Bool {
        guard let result = selectedActionResult, [.file, .app].contains(result.source),
              result.actions.contains(.revealInFinder) else { return false }
        closeActionsMenu()
        if ClipboardAccess.copyFileName(at: URL(fileURLWithPath: result.target.identifier)) {
            showToast(NSLocalizedString("已复制文件名", comment: ""))
        }
        return true
    }

    @discardableResult
    func showSelectedFileInfo() -> Bool {
        guard let result = selectedActionResult, [.file, .app].contains(result.source),
              result.actions.contains(.revealInFinder) else { return false }
        closeActionsMenu()
        Task { @MainActor [weak self] in
            do {
                try await ToolService.showLauncherFileInfo(at: URL(fileURLWithPath: result.target.identifier))
                self?.onHide()
            } catch {
                self?.status = error.localizedDescription
            }
        }
        return true
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    /// ⌘F reveals the selected file/app in Finder.
    func revealSelectionInFinder() -> Bool {
        guard currencyConversion == nil, unitConversion == nil, results.indices.contains(selection),
              results[selection].actions.contains(.revealInFinder) else { return false }
        execute(results[selection], action: .revealInFinder)
        return true
    }

    /// Return executes the selection; ⌘Return explicitly submits to AI.
    func submit(_ kind: SubmitKind) {
        if isActionsMenuPresented { performHighlightedAction(); return }
        switch kind {
        case .submitToAI:
            let text = (isAIScope ? inputText : query).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            onAskAI(text)
        case .executeSelection:
            guard unitConversion == nil, results.indices.contains(selection) else { return }
            execute(results[selection], action: results[selection].primaryAction)
        }
    }

    func execute(_ r: SearchResult, action: ResultAction?) {
        closeActionsMenu()
        guard let action else { return }
        guard ![.link, .bookmark].contains(r.source) || canSearchBookmarks else { return }
        if r.target.kind == "search-command" {
            guard AppModel.searchCommands.contains(where: { $0.0 == r.target.identifier }) else { return }
            if r.target.identifier == "colorPicker" {
                onHide()
                Task { @MainActor in
                    // Let the launcher finish disappearing before sampling the screen.
                    try? await Task.sleep(for: .milliseconds(250))
                    ToolService.pickScreenColor { copied in
                        guard copied == false else { return }
                        Task { @MainActor in
                            let alert = AppDialog.make()
                            alert.messageText = NSLocalizedString("无法复制所选颜色，请重试。", comment: "")
                            alert.addButton(withTitle: NSLocalizedString("好", comment: ""))
                            _ = await AppDialog.present(alert)
                        }
                    }
                }
                return
            }
            if let category = LauncherFilter(commandID: r.target.identifier) {
                setFilter(category, query: "")
                return
            }
            inputState.replaceRawQuery(app.commandKeyword(r.target.identifier) + " ", keywords: app.keywords,
                                       bookmarksEnabled: canSearchBookmarks)
            update()
            return
        }
        if r.target.kind == "tab-search" {
            guard tabCoordinator != nil else { return }
            inputState.enterTabs(r.target.identifier.caseInsensitiveCompare(app.commandKeyword("tabs")) == .orderedSame ? "" : r.target.identifier)
            update()
            return
        }
        if r.target.kind == Self.bookmarkSearchKind {
            guard chromeBookmarkAccessAllowed, bookmarkCoordinator != nil else { return }
            inputState.enterBookmarks(r.target.identifier)
            update()
            return
        }
        if QuitAskyCommand.isResult(r) {
            confirmQuit()
            return
        }
        try? ActivityStore(app.store).append(kind: "launcher", sourceID: "launcher", text: r.title)
        switch action {
        case .open:
            if r.source == .clipboard {
                if let item = app.clipboardStore.recent(limit: 500).first(where: { $0.id == r.target.identifier }) {
                    _ = ClipboardAccess.copy(item)
                }
                onHide()
                return
            }
            let url = URL(filePath: r.target.identifier)
            if r.source == .app { apps.recordLaunch(path: url.path) }
            if r.target.kind == "launcher-alias" {
                if ToolService.openLauncherApplication(url) { onHide() }
                else { status = NSLocalizedString("应用已移动或无法打开，请更新别名。", comment: "") }
            } else {
                NSWorkspace.shared.open(url)
                onHide()
            }
        case .revealInFinder:
            NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: r.target.identifier)])
            onHide()
        case .switchTo:
            if r.target.kind == "application-window", let snapshot = windowSnapshot {
                Task {
                    do {
                        try await ToolService.activateLauncherWindow(r.target.identifier, in: snapshot)
                        onHide()
                    } catch {
                        windowSnapshot = nil
                        status = NSLocalizedString("窗口已关闭或无法切换，请重新搜索并检查辅助功能权限", comment: "")
                    }
                }
            } else { switchChromeTab(r) }
        case .copy(let s):
            if r.source == .calculator, r.target.kind != "calculator-history", let calculation {
                ToolService.saveCalculatorHistory(expression: calculation.expression, result: calculation.result, in: app.store)
            }
            _ = ToolService.copyCalculatorResult(s)
            onHide()
        case .openURL(let url):
            if ToolService.openLauncherURL(url) { onHide() }
            else { status = NSLocalizedString("无法打开链接，请检查网址或默认浏览器。", comment: "") }
        case .runTerminal(let command):
            runTerminal(command)
        case .runShortcut(let name):
            runShortcut(name)
        case .askAI(let prompt):
            onAskAI(prompt)
        }
    }

    private func confirmQuit() {
        guard !isConfirmingQuit else { return }
        isConfirmingQuit = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isConfirmingQuit = false }
            let alert = QuitAskyCommand.makeAlert()
            NSApp.activate()
            let response = await AppDialog.present(alert)
            alert.window.orderOut(nil)
            if response == .alertFirstButtonReturn { self.onQuit() }
        }
    }

    private func switchChromeTab(_ r: SearchResult) {
        let parts = r.target.identifier.split(separator: ":").map(String.init)
        guard parts.count == 2 else { return }
        let expected = r.subtitle
        Task {
            do {
                _ = try await ChromeBridge().activate(windowID: parts[0], tabID: parts[1], expectedURL: expected)
                onHide()
            } catch {
                status = NSLocalizedString("标签已变化或已关闭，请重新搜索。", comment: "")
                chrome.invalidate()
            }
        }
    }

    private func runShortcut(_ name: String) {
        status = String(format: NSLocalizedString("正在运行快捷指令：%@…", comment: ""), name)
        Task {
            for await state in ToolService.runLauncherShortcut(name: name) {
                switch state {
                case .started:
                    status = String(format: NSLocalizedString("正在运行快捷指令：%@…", comment: ""), name)
                case .completed(let output):
                    status = output.isEmpty
                        ? String(format: NSLocalizedString("快捷指令 %@ 已完成", comment: ""), name)
                        : String(format: NSLocalizedString("快捷指令 %@：%@", comment: ""), name, output)
                case .failed(let message):
                    status = String(format: NSLocalizedString("快捷指令 %@ 失败：%@", comment: ""), name, message)
                }
            }
        }
    }

    // MARK: Terminal (explicit `>` only)

    private func runTerminal(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        terminalTask?.cancel()
        let cwd = URL(filePath: app.settings.terminalWorkingDirectory)
        let application = terminalApplication
        terminalTask = Task {
            do {
                try await ToolService.openLauncherTerminal(command: command, workingDirectory: cwd, application: application)
                onHide()
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func stopTerminal() { app.terminal.stop() }
}

extension LauncherModel {
    /// Intercept before the field editor, including while a child surface is open.
    func handleActionKey(_ event: NSEvent) -> Bool {
        if isActionsMenuPresented {
            if event.type == .leftMouseDown, !actionsMenuFrame.contains(event.locationInWindow) {
                closeActionsMenu()
            }
        }
        guard event.type == .keyDown,
              (NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() != true else { return false }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == 40, modifiers == .command {
            // Reserve ⌘K consistently, even for results without secondary actions.
            if !event.isARepeat { toggleActionsMenu() }
            return true
        }
        if event.keyCode == 8, modifiers == .command,
           ((NSApp.keyWindow?.firstResponder as? NSTextView)?.selectedRange().length ?? 0) == 0,
           copySelectedFile() { return true }
        if event.keyCode == 47, modifiers == [.command, .shift],
           copySelectedFileName() { return true }
        if event.keyCode == 34, modifiers == .command,
           showSelectedFileInfo() { return true }
        guard isActionsMenuPresented else { return false }
        if modifiers.isEmpty {
            switch event.keyCode {
            case 125: move(1); return true
            case 126: move(-1); return true
            case 36, 76: performHighlightedAction(); return true
            case 53: closeActionsMenu(); return true
            default: break
            }
        }
        // Typing resumes search; editing is still handled by the native field editor.
        if event.characters?.isEmpty == false { closeActionsMenu() }
        return false
    }

    var selectedActionResult: SearchResult? {
        guard currencyConversion == nil, unitConversion == nil, terminal == nil, results.indices.contains(selection) else { return nil }
        return results[selection]
    }

    var primaryLauncherAction: LauncherAction? {
        guard let result = selectedActionResult, let action = result.primaryAction else { return nil }
        if QuitAskyCommand.isResult(result) {
            return LauncherAction(title: "退出 Asky", icon: "xmark", shortcut: "↵", kind: .result(action))
        }
        if result.target.kind == "application-window" {
            return LauncherAction(title: "切换窗口", icon: "web", shortcut: "↵", kind: .result(action))
        }
        if result.target.kind == "search-command" {
            return LauncherAction(title: result.title, icon: "magnifyingglass", shortcut: "↵", kind: .result(action))
        }
        if result.target.kind == "tab-search" {
            return LauncherAction(title: "搜索开启的标签页", icon: "globe", shortcut: "↵", kind: .result(action))
        }
        if result.target.kind == Self.bookmarkSearchKind {
            return LauncherAction(title: "搜索书签", icon: "bookmark", shortcut: "↵", kind: .result(action))
        }
        return LauncherAction(action: action, source: result.source, shortcut: "↵")
    }

    var finderLauncherAction: LauncherAction? {
        guard let result = selectedActionResult, [.file, .app].contains(result.source),
              result.primaryAction != .revealInFinder,
              result.actions.contains(.revealInFinder) else { return nil }
        return LauncherAction(action: .revealInFinder, source: result.source,
                              shortcut: actionPreferences.revealInFinderHotKey.label)
    }

    var secondaryActions: [LauncherAction] {
        guard let result = selectedActionResult, result.primaryAction != nil else { return [] }
        if result.target.kind == "calculator-history" {
            return [LauncherAction(title: "基于此继续计算", icon: "equal.square", shortcut: nil, kind: .continueCalculation),
                    LauncherAction(title: "删除记录", icon: "trash", shortcut: nil, kind: .deleteCalculation)]
        }
        var actions = result.actions.dropFirst().filter {
            finderLauncherAction == nil || $0 != .revealInFinder
        }.map {
            LauncherAction(action: $0, source: result.source,
                           shortcut: $0 == .revealInFinder ? actionPreferences.revealInFinderHotKey.label : nil)
        }
        if canEnterSelectedFolder {
            actions.append(LauncherAction(title: "搜索文件夹", icon: "folder",
                                          shortcut: "⇥", kind: .enterFolder))
        }
        if result.actions.contains(.revealInFinder) {
            if [.file, .app].contains(result.source) {
                actions.append(LauncherAction(title: "拷贝", icon: "doc.on.clipboard",
                                              shortcut: "⌘ C", kind: .copyFile))
            }
            actions.append(LauncherAction(title: "复制路径", icon: "doc.on.clipboard",
                                          shortcut: actionPreferences.copyPathHotKey.label, kind: .copyPath))
        }
        if [.file, .app].contains(result.source), result.actions.contains(.revealInFinder) {
            actions.append(LauncherAction(title: "复制文件名", icon: "doc.on.clipboard",
                                          shortcut: "⇧⌘ .", kind: .copyFileName))
            actions.append(LauncherAction(title: "展示文件信息", icon: "info.circle",
                                          shortcut: "⌘ I", kind: .showFileInfo))
        }
        let link = result.source == .chromeTab ? result.subtitle : result.target.identifier
        if [.link, .bookmark, .chromeTab].contains(result.source), LauncherWebURL.parse(link) != nil {
            actions.append(LauncherAction(title: "复制链接", icon: "link", shortcut: nil, kind: .result(.copy(link))))
        }
        if let id = builtInCommandIDs[result.id] {
            actions.append(LauncherAction(title: "编辑快捷指令", icon: "pencil", shortcut: nil, kind: .editCommand(id)))
            actions.append(LauncherAction(title: "停用", icon: "xmark", shortcut: nil, kind: .disableCommand(id)))
        }
        return actions
    }

    @discardableResult
    func toggleActionsMenu() -> Bool {
        if isActionsMenuPresented { closeActionsMenu(); return true }
        guard !secondaryActions.isEmpty else { return false }
        actionSelection = 0
        actionMenuTarget = selectedActionResult
        isActionsMenuPresented = true
        return true
    }

    func closeActionsMenu() {
        isActionsMenuPresented = false
        actionMenuTarget = nil
        actionSelection = 0
    }

    func performHighlightedAction() {
        guard isActionsMenuPresented, selectedActionResult == actionMenuTarget,
              secondaryActions.indices.contains(actionSelection) else { closeActionsMenu(); return }
        performLauncherAction(secondaryActions[actionSelection])
    }

    func performLauncherAction(_ action: LauncherAction) {
        let result = selectedActionResult
        closeActionsMenu()
        switch action.kind {
        case .editCommand(let id):
            guard let result, builtInCommandIDs[result.id] == id else { return }
            onHide()
            app.editCommand(id)
        case .disableCommand(let id):
            guard let result, builtInCommandIDs[result.id] == id else { return }
            app.preferences.disabledBuiltInCommands.insert(id)
            inputState.replaceRawQuery(inputState.rawQuery, keywords: app.keywords, bookmarksEnabled: canSearchBookmarks)
            update()
        case .continueCalculation:
            guard let result, result.target.kind == "calculator-history",
                  let record = ToolService.calculatorHistory(in: app.store).first(where: { $0.id == result.target.identifier }) else { return }
            setFilter(.all, query: record.expression)
        case .deleteCalculation:
            guard let result, result.target.kind == "calculator-history" else { return }
            let previousSelection = selection
            ToolService.deleteCalculatorHistory(id: result.target.identifier, in: app.store)
            update()
            selection = min(previousSelection, max(0, results.count - 1))
        case .enterFolder: _ = enterSelectedFolder()
        case .copyFile: _ = copySelectedFile()
        case .copyPath: _ = copySelectedPath()
        case .copyFileName: _ = copySelectedFileName()
        case .showFileInfo: _ = showSelectedFileInfo()
        case .result(let value):
            if let result { execute(result, action: value) }
        }
    }
}
