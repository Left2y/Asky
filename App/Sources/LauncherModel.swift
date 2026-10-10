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
            all = await ShortcutsService.list()
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
    var selection = 0
    private(set) var terminal: TerminalSession?
    private(set) var status: String?

    private let app: AppModel
    private let apps = AppsProvider()
    private let chrome = ChromeTabsProvider()
    private let shortcuts = ShortcutsProvider()
    private var coordinator: SearchCoordinator
    private var batches: [SearchBatch] = []
    private var direct: [SearchResult] = []
    private var searchTask: Task<Void, Never>?
    private var currencyTask: Task<Void, Never>?
    private var terminalTask: Task<Void, Never>?
    var onHide: () -> Void = {}
    var onAskAI: (String) -> Void = { _ in }

    init(app: AppModel) {
        self.app = app
        coordinator = SearchCoordinator(providers: [])
        rebuildProviders()
    }

    func rebuildProviders() {
        let reader = SettingsReader(store: app.store)
        var providers: [any SearchProvider] = [apps, shortcuts, LinksProvider(),
            SpotlightProvider(settings: {
                let s = reader.load()
                return (s.fileScopes.map { URL(filePath: $0) }, s.excludedDirectories)
            })]
        if app.settings.enabledSources.contains(.chrome) {
            providers.append(chrome)
            providers.append(ChromeBookmarksProvider())
        }
        coordinator = SearchCoordinator(providers: providers)
    }

    /// Panel hidden: cancel work and drop result payloads (resource scope = panel).
    func reset() {
        coordinator.cancel()
        searchTask?.cancel()
        currencyTask?.cancel()
        batches = []
        direct = []
        results = []
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

    var inputText: String {
        get { inputState.text }
        set {
            inputState.edit(newValue, keywords: app.keywords)
            update()
        }
    }

    func leaveCommand() {
        guard commandInput != nil else { return }
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
        return commandInput?.command.keyword ?? app.keywords.commands.first {
            $0.url(for: query.trimmingCharacters(in: .whitespacesAndNewlines))?.absoluteString == result.target.identifier
        }?.keyword
    }

    private func update() {
        status = nil
        selection = 0
        searchTask?.cancel()
        coordinator.cancel()
        let route = commandInput.map { Route.keyword($0.command, query: $0.text) } ?? router.route(query)
        direct = router.directResults(for: route)
        if case .search(let text) = route {
            direct += app.keywords.commands.compactMap { command in
                guard let url = command.url(for: text) else { return nil }
                return SearchResult(source: .keyword, target: TargetRef(kind: "url", identifier: url.absoluteString),
                                    title: command.name, actions: [.openURL(url)], score: 0)
            }
        }
        batches = []
        currencyTask?.cancel()
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
                    self.batches.append(batch)
                    self.publish()
                }
            }
        } else {
            coordinator.cancel()
        }
        publish()
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
        if commandInput == nil, let ask = router.askAIResult(for: query) { merged.append(ask) }
        let order: [SearchSource] = [.link, .app, .file, .bookmark, .chromeTab, .shortcut, .keyword, .calculator, .conversion, .currency, .terminal, .askAI]
        merged = order.flatMap { source in merged.filter { $0.source == source } }
        results = merged
        selection = min(selection, max(0, results.count - 1))
    }

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = (selection + delta + results.count) % results.count
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
            NSWorkspace.shared.open(url)
            onHide()
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
            for await state in ShortcutsService.run(name: name) {
                status = "\(name)：\(state)"
            }
        }
    }

    // MARK: Terminal (explicit `>` only)

    private func runTerminal(_ command: String) {
        terminalTask?.cancel()
        terminal = TerminalSession(command: command)
        let cwd = URL(filePath: app.settings.terminalWorkingDirectory)
        let runner = app.terminal
        terminalTask = Task {
            for await event in runner.run(command, workingDirectory: cwd) {
                switch event {
                case .stdout(let s), .stderr(let s):
                    terminal?.output += s
                    if let out = terminal?.output, out.count > 64_000 { terminal?.output = String(out.suffix(48_000)) }
                case .exited(let code, let spilled):
                    terminal?.exitCode = code
                    terminal?.spilled = spilled
                case .handedOffToTerminal:
                    terminal?.handedOff = true
                    Self.openInTerminalApp(command, cwd: cwd)
                }
            }
        }
    }

    func stopTerminal() { app.terminal.stop() }

    /// Interactive commands go to Terminal.app instead of running inside the panel.
    private static func openInTerminalApp(_ command: String, cwd: URL) {
        let script = "cd \(shellQuote(cwd.path)) && \(command)"
        let source = "tell application \"Terminal\"\nactivate\ndo script \(AppleScript.literal(script))\nend tell"
        Task { _ = try? await AppleScriptRunner.shared.run(source) }
    }

    private static func shellQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
}
