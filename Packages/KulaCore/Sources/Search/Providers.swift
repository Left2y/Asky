import Foundation
import Contracts
import Synchronization
import LocalStore

/// Installed applications from standard folders, ranked by fuzzy match + recent launches.
/// The index is a small list of (name, path); it is rebuilt lazily and on demand.
public final class AppsProvider: SearchProvider {
    public let source = SearchSource.app
    private let roots: [URL]
    private let index = Mutex<[(name: String, path: String)]?>(nil)
    private let usage = Mutex<[String: Date]>([:])

    public init(roots: [URL] = AppsProvider.defaultRoots) { self.roots = roots }

    public static var defaultRoots: [URL] {
        ["/Applications", "/System/Applications", "/System/Applications/Utilities", "/Applications/Utilities",
         NSHomeDirectory() + "/Applications"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    public func invalidate() { index.withLock { $0 = nil } }

    public func recordLaunch(path: String, at date: Date = Date()) { usage.withLock { $0[path] = date } }

    public func search(_ query: String, limit: Int) async -> [SearchResult] {
        let apps = loadIndex()
        let recent = usage.withLock { $0 }
        let now = Date()
        var scored: [(SearchResult, Double)] = []
        for app in apps {
            if Task.isCancelled { return [] }
            guard var s = FuzzyMatch.score(query, in: app.name) else { continue }
            if let last = recent[app.path] { s += max(0, 0.1 - now.timeIntervalSince(last) / (86400 * 70)) }
            let r = SearchResult(source: .app, target: TargetRef(kind: "app", identifier: app.path), title: app.name,
                                 subtitle: "应用", actions: [.open, .revealInFinder], score: s)
            scored.append((r, s))
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    private func loadIndex() -> [(name: String, path: String)] {
        if let cached = index.withLock({ $0 }) { return cached }
        var out: [(String, String)] = []
        var seen = Set<String>()
        let fm = FileManager.default
        for root in roots {
            guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles]) else { continue }
            for u in items where u.pathExtension == "app" {
                let name = u.deletingPathExtension().lastPathComponent
                if seen.insert(u.path).inserted { out.append((name, u.path)) }
            }
        }
        index.withLock { $0 = out }
        return out
    }
}

/// File-name search through Spotlight (NSMetadataQuery), restricted to configured scopes and
/// excluding configured directories. Never builds its own full-disk index.
public final class SpotlightProvider: SearchProvider {
    public let source = SearchSource.file
    private let settings: @Sendable () -> (scopes: [URL], excluded: [String])
    public let timeout: Duration

    public init(timeout: Duration = .milliseconds(450),
                settings: @escaping @Sendable () -> (scopes: [URL], excluded: [String]) = {
                    ([FileManager.default.homeDirectoryForCurrentUser], [])
                }) {
        self.settings = settings
        self.timeout = timeout
    }

    public func search(_ query: String, limit: Int) async -> [SearchResult] {
        guard query.count >= 2 else { return [] }
        let (scopes, excluded) = settings()
        let runner = SpotlightRunner()
        let paths = await runner.run(query: query, scopes: scopes, limit: limit * 3, timeout: timeout)
        if Task.isCancelled { return [] }
        return paths.lazy
            .filter { p in !excluded.contains { p.hasPrefix($0) } && !p.contains("/Library/") && !p.contains("/.") }
            .prefix(limit)
            .map { p in
                let u = URL(fileURLWithPath: p)
                return SearchResult(source: .file, target: TargetRef(kind: "file", identifier: p), title: u.lastPathComponent,
                                    subtitle: (u.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath,
                                    actions: [.open, .revealInFinder], score: FuzzyMatch.score(query, in: u.lastPathComponent) ?? 0.3)
            }
    }
}

@MainActor
final class SpotlightRunner {
    private var query: NSMetadataQuery?
    private var observer: NSObjectProtocol?

    nonisolated init() {}

    func run(query text: String, scopes: [URL], limit: Int, timeout: Duration) async -> [String] {
        let q = NSMetadataQuery()
        q.searchScopes = scopes
        q.predicate = NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemFSNameKey, text)
        q.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)]
        query = q
        let paths: [String] = await withCheckedContinuation { cont in
            var done = false
            let finish: @MainActor () -> Void = { [weak self] in
                guard !done else { return }
                done = true
                q.disableUpdates()
                let n = min(q.resultCount, limit)
                let out = (0..<n).compactMap { (q.result(at: $0) as? NSMetadataItem)?.value(forAttribute: NSMetadataItemPathKey) as? String }
                q.stop()
                if let o = self?.observer { NotificationCenter.default.removeObserver(o) }
                cont.resume(returning: out)
            }
            observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: q, queue: .main) { _ in
                MainActor.assumeIsolated { finish() }
            }
            q.start()
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                finish()
            }
        }
        query = nil
        return paths
    }
}

/// Clipboard history search; read-only, bounded.
public struct ClipboardProvider: SearchProvider {
    public let source = SearchSource.clipboard
    let store: ClipboardStore
    public init(store: ClipboardStore) { self.store = store }

    public func search(_ query: String, limit: Int) async -> [SearchResult] {
        store.search(query, limit: limit).map { item in
            let title: String
            switch item.kind {
            case .text: title = String((item.text ?? "").prefix(120)).replacingOccurrences(of: "\n", with: " ")
            case .image: title = "图片"
            case .file: title = URL(fileURLWithPath: item.filePath ?? "").lastPathComponent
            }
            return SearchResult(source: .clipboard, target: TargetRef(kind: "clipboard", identifier: item.id), title: title,
                                subtitle: "剪贴板 · \(item.sourceApp ?? "")",
                                actions: item.text.map { [.copy($0)] } ?? [.open], score: 0.35)
        }
    }
}
