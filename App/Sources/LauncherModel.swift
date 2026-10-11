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
                                subtitle: "快捷指令", actions: [.runShortcut(name: name)], score: s * 0.9)
        }.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
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
    private var inputState = LauncherInputState()
    var query: String {
        get { inputState.rawQuery }
        set {
            inputState.replaceRawQuery(newValue, keywords: app.keywords)
            update()
        }
    }
    private(set) var results: [SearchResult] = []
    private(set) var isSearching = false
    var selection = 0
    private(set) var terminal: TerminalSession?
    private(set) var status: String?

    private let app: AppModel
    private let apps = AppsProvider()
    private let chrome = ChromeTabsProvider()
    private let shortcuts = ShortcutsProvider()
    private var coordinator: SearchCoordinator
    /// Bookmarks are searched only inside the `bm` scope, never in default search.
    private var bookmarkCoordinator: SearchCoordinator?
    private let searchProviders: [any SearchProvider]?
    private var searchProviderCount = 0
    private var searchSources: Set<SearchSource> = []
    private var remainingSearchProviders = 0
    private var batches: [SearchBatch] = []
    private var direct: [SearchResult] = []
    private var searchTask: Task<Void, Never>?
    private var currencyTask: Task<Void, Never>?
    private var terminalTask: Task<Void, Never>?
    var onHide: () -> Void = {}
    var onAskAI: (String) -> Void = { _ in }

    init(app: AppModel, searchProviders: [any SearchProvider]? = nil) {
        self.app = app
        self.searchProviders = searchProviders
        coordinator = SearchCoordinator(providers: [])
        rebuildProviders()
    }

    func rebuildProviders() {
        if let searchProviders {
            let general = searchProviders.filter { $0.source != .bookmark }
            let marks = searchProviders.filter { $0.source == .bookmark }
            searchProviderCount = general.count
            searchSources = Set(general.map(\.source))
            coordinator = SearchCoordinator(providers: general)
            bookmarkCoordinator = marks.isEmpty ? nil : SearchCoordinator(providers: marks)
            return
        }
        let reader = SettingsReader(store: app.store)
        let useChrome = app.settings.enabledSources.contains(.chrome)
        let links = LinksProvider(knownSites: { [chrome] in
            useChrome ? ChromeBookmarkService.load().map(\.url) + chrome.cachedURLs : []
        })
        var providers: [any SearchProvider] = [apps, shortcuts, links,
            SpotlightProvider(settings: {
                let s = reader.load()
                return (s.fileScopes.map { URL(filePath: $0) }, s.excludedDirectories)
            })]
        if useChrome {
            providers.append(chrome)
            bookmarkCoordinator = SearchCoordinator(providers: [ChromeBookmarksProvider()])
        } else {
            bookmarkCoordinator = nil
        }
        searchProviderCount = providers.count
        searchSources = Set(providers.map(\.source))
        coordinator = SearchCoordinator(providers: providers)
    }

    /// Panel hidden: cancel work and drop result payloads (resource scope = panel).
    func reset() {
        coordinator.cancel()
        bookmarkCoordinator?.cancel()
        searchTask?.cancel()
        currencyTask?.cancel()
        batches = []
        direct = []
        results = []
        isSearching = false
        remainingSearchProviders = 0
        status = nil
        if terminal?.exitCode != nil || terminal == nil { terminal = nil }
        shortcuts.invalidate()
        chrome.invalidate()
        if !query.isEmpty { query = "" }
    }

    private var router: IntentRouter { IntentRouter(keywords: app.keywords) }

    var commandInput: (command: KeywordCommand, text: String)? {
        inputState.command.map { (command: $0, text: inputState.text) }
    }

    var terminalApplication: LauncherTerminalApplication {
        app.settings.terminalApplicationID.flatMap(LauncherTerminalApplication.init(rawValue:)) ?? .system
    }

    var terminalIcon: NSImage? { ToolService.launcherTerminalIcon(terminalApplication) }

    var isTerminalScope: Bool { inputState.terminal }
    var isBookmarkScope: Bool { inputState.bookmarks }
    var hasScope: Bool { inputState.hasScope }

    var inputText: String {
        get { inputState.text }
        set {
            inputState.edit(newValue, keywords: app.keywords)
            update()
        }
    }

    func leaveCommand() {
        guard hasScope else { return }
        inputState.leaveCommand()
        update()
    }

    func backspaceOnEmptyInput() -> Bool {
        guard inputState.backspaceOnEmptyText() else { return false }
        update()
        return true
    }

    func keyword(for result: SearchResult) -> String? {
        guard result.source == .keyword else { return nil }
        if result.target.kind == "keyword-match" {
            return app.keywords.commands.first { $0.url(for: "")?.absoluteString == result.target.identifier }?.keyword
        }
        return commandInput?.command.keyword ?? app.keywords.commands.first {
            $0.url(for: query.trimmingCharacters(in: .whitespacesAndNewlines))?.absoluteString == result.target.identifier
        }?.keyword
    }

    private func update() {
        status = nil
        selection = 0
        searchTask?.cancel()
        coordinator.cancel()
        bookmarkCoordinator?.cancel()
        currencyTask?.cancel()
        if inputState.bookmarks {
            searchBookmarks(inputState.text)
            return
        }
        let route = isTerminalScope && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Route.empty
            : commandInput.map { Route.keyword($0.command, query: $0.text) } ?? router.route(query)
        isSearching = router.includesSearch(route) && searchProviderCount > 0
        remainingSearchProviders = isSearching ? searchProviderCount : 0
        direct = router.directResults(for: route)
        if case .search(let text) = route {
            direct += app.keywords.commands.compactMap { command in
                let exact = command.keyword.caseInsensitiveCompare(text.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                guard exact || command.urlTemplate.contains("{query}"),
                      let url = command.url(for: exact ? "" : text) else { return nil }
                return SearchResult(source: .keyword, target: TargetRef(kind: exact ? "keyword-match" : "url", identifier: url.absoluteString),
                                    title: command.name, actions: [.openURL(url)], score: 0)
            }
            let aliasQuery = text.trimmingCharacters(in: .whitespacesAndNewlines)
            direct += app.preferences.aliases.compactMap { item in
                guard item.alias.caseInsensitiveCompare(aliasQuery) == .orderedSame else { return nil }
                let action: ResultAction = item.kind == "shortcut" ? .runShortcut(name: item.target) : .open
                return SearchResult(source: .keyword, target: TargetRef(kind: "launcher-alias", identifier: item.target),
                                    title: item.alias, subtitle: item.kind == "app" ? URL(filePath: item.target).deletingPathExtension().lastPathComponent : item.target,
                                    actions: [action], score: 100)
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if bookmarkCoordinator != nil, !trimmed.isEmpty {
                direct.append(SearchResult(source: .bookmark, target: TargetRef(kind: Self.bookmarkSearchKind, identifier: trimmed),
                                           title: "搜索书签", subtitle: trimmed, actions: [.open], score: 0))
            }
        }
        batches = router.includesSearch(route) ? retainedBatches(for: query) : []
        if case .currency(let q) = route {
            let exchange = app.exchange
            currencyTask = Task { [weak self] in
                let r = await exchange.convert(q)
                guard !Task.isCancelled, let self else { return }
                self.direct = [Self.currencyRow(r, q)]
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

    private static let bookmarkSearchKind = "bookmark-search"

    private func searchBookmarks(_ text: String) {
        direct = []
        batches = []
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        isSearching = hasText && bookmarkCoordinator != nil
        remainingSearchProviders = isSearching ? 1 : 0
        if isSearching, let coordinator = bookmarkCoordinator {
            searchTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { return }
                guard let self, !Task.isCancelled else { return }
                coordinator.query(text) { [weak self] batch in
                    guard let self, self.inputState.bookmarks else { return }
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

    private static func currencyRow(_ r: CurrencyResult, _ q: CurrencyQuery) -> SearchResult {
        switch r {
        case .converted(let value, let rate, let date, let cached, _):
            let v = String(format: "%.2f", value)
            return SearchResult(source: .currency, target: TargetRef(kind: "fx", identifier: "\(q.amount)\(q.from)\(q.to)"),
                                title: "\(v) \(q.to)",
                                subtitle: "1 \(q.from) = \(String(format: "%.4f", rate)) \(q.to) · ECB \(date)\(cached ? " · 缓存" : "") · ↩ 复制",
                                actions: [.copy(v)], score: 100)
        case .unavailable(let reason):
            return SearchResult(source: .currency, target: TargetRef(kind: "fx", identifier: "na"),
                                title: "汇率不可用", subtitle: reason, actions: [], score: 100)
        }
    }

    private func publish() {
        var merged = direct + ResultMerger.merge(batches, limit: 40)
        // Generic search shortcuts are not local matches. Plain text with no
        // concrete target falls back to AI regardless of its wording.
        if !hasScope, case .search = router.route(query) {
            let hasLocalMatch = merged.contains {
                ($0.source != .keyword || ($0.target.kind == "keyword-match" || $0.target.kind == "launcher-alias")) && $0.source != .askAI && $0.target.kind != "bookmark-search"
            }
            if !hasLocalMatch { merged = [] }
        }
        if !hasScope, !merged.contains(where: { $0.source == .askAI }),
           let ask = router.askAIResult(for: query) { merged.append(ask) }
        let order: [SearchSource] = [.app, .link, .bookmark, .file, .chromeTab, .shortcut, .keyword, .calculator, .conversion, .currency, .terminal, .askAI]
        let priority = merged.filter { ($0.target.kind == "keyword-match" || $0.target.kind == "launcher-alias") || $0.source == .shortcut }
        let remaining = merged.filter { $0.target.kind != "keyword-match" && $0.target.kind != "launcher-alias" && $0.source != .shortcut }
        merged = priority.filter { ($0.target.kind == "keyword-match" || $0.target.kind == "launcher-alias") }
            + priority.filter { $0.source == .shortcut }
            + order.flatMap { source in remaining.filter { $0.source == source } }
        results = merged
        selection = min(selection, max(0, results.count - 1))
    }

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = min(max(selection + delta, 0), results.count - 1)
    }

    /// Return executes the selection; ⌘Return explicitly submits to AI.
    func submit(_ kind: SubmitKind) {
        switch kind {
        case .submitToAI:
            let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            onAskAI(text)
        case .executeSelection:
            guard results.indices.contains(selection) else { return }
            execute(results[selection], action: results[selection].primaryAction)
        }
    }

    func execute(_ r: SearchResult, action: ResultAction?) {
        guard let action else { return }
        if r.target.kind == Self.bookmarkSearchKind {
            inputState.enterBookmarks(r.target.identifier)
            update()
            return
        }
        try? ActivityStore(app.store).append(kind: "launcher", sourceID: "launcher", text: r.title)
        switch action {
        case .open:
            if r.source == .clipboard {
                if let item = ClipboardStore(app.store).recent(limit: 500).first(where: { $0.id == r.target.identifier }),
                   let path = item.filePath { copyFile(path, kind: item.kind) }
                onHide()
                return
            }
            let url = URL(filePath: r.target.identifier)
            if r.source == .app { apps.recordLaunch(path: url.path) }
            if r.target.kind == "launcher-alias" {
                if ToolService.openLauncherApplication(url) { onHide() }
                else { status = "应用已移动或无法打开，请更新别名。" }
            } else {
                NSWorkspace.shared.open(url)
                onHide()
            }
        case .revealInFinder:
            NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: r.target.identifier)])
            onHide()
        case .switchTo:
            switchChromeTab(r)
        case .copy(let s):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(s, forType: .string)
            onHide()
        case .openURL(let url):
            if ToolService.openLauncherURL(url) { onHide() }
            else { status = "无法打开链接，请检查网址或默认浏览器。" }
        case .runTerminal(let command):
            runTerminal(command)
        case .runShortcut(let name):
            runShortcut(name)
        case .askAI(let prompt):
            onAskAI(prompt)
        }
    }

    private func copyFile(_ path: String, kind: ClipboardKind) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if kind == .image, let img = NSImage(contentsOfFile: path) { pb.writeObjects([img]) }
        else { pb.writeObjects([URL(filePath: path) as NSURL]) }
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
                status = "标签已变化或已关闭，请重新搜索。"
                chrome.invalidate()
            }
        }
    }

    private func runShortcut(_ name: String) {
        status = "正在运行快捷指令：\(name)…"
        Task {
            for await state in ToolService.runLauncherShortcut(name: name) {
                status = "\(name)：\(state)"
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
