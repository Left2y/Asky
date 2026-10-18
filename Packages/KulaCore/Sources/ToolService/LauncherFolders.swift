import Foundation
import Contracts

extension ToolService {
    /// Packages (including .app bundles) keep their normal open behavior.
    public static func launcherFolder(at path: String) -> URL? {
        let url = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
              values.isDirectory == true, values.isPackage != true else { return nil }
        return url
    }

    /// Empty input browses immediate children. Spotlight adds indexed descendants for a name search.
    /// Directory reads run off the UI thread; no private index or document-content scan is created.
    public static func searchLauncherFolder(_ folder: URL, query: String, excluded: [String],
                                            limit: Int = 40) async throws -> [SearchResult] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let children = try await Task.detached(priority: .userInitiated) {
            try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                        options: [.skipsHiddenFiles])
        }.value
        try Task.checkCancellation()
        var urls = children.filter { text.isEmpty || $0.lastPathComponent.localizedStandardContains(text) }
        if !text.isEmpty {
            urls += await FolderMetadataSearch().run(folder: folder, text: text, limit: limit * 4)
        }
        try Task.checkCancellation()
        let exclusions = excluded.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        let root = folder.standardizedFileURL.path
        var seen = Set<String>()
        return urls.filter { url in
            let path = url.standardizedFileURL.path
            return path.hasPrefix(root == "/" ? "/" : root + "/") &&
                !path.dropFirst(root.count).split(separator: "/").contains(where: { $0.hasPrefix(".") }) &&
                !exclusions.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) &&
                seen.insert(path).inserted
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .prefix(max(0, limit)).map { url in
                SearchResult(source: .file, target: TargetRef(kind: "file", identifier: url.path),
                             title: url.lastPathComponent,
                             subtitle: (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath,
                             actions: [.open, .revealInFinder])
            }
    }
}

@MainActor
private final class FolderMetadataSearch {
    private var observer: NSObjectProtocol?
    nonisolated init() {}

    func run(folder: URL, text: String, limit: Int) async -> [URL] {
        guard !Task.isCancelled else { return [] }
        let query = NSMetadataQuery()
        query.searchScopes = [folder]
        query.predicate = NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemFSNameKey, text)
        return await withCheckedContinuation { continuation in
            var finished = false
            let finish: @MainActor () -> Void = {
                guard !finished else { return }
                finished = true
                query.disableUpdates()
                let urls = (0..<min(limit, query.resultCount)).compactMap { index -> URL? in
                    guard let path = (query.result(at: index) as? NSMetadataItem)?
                        .value(forAttribute: NSMetadataItemPathKey) as? String else { return nil }
                    return URL(fileURLWithPath: path)
                }
                query.stop()
                if let observer = self.observer { NotificationCenter.default.removeObserver(observer) }
                self.observer = nil
                continuation.resume(returning: urls)
            }
            self.observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering,
                                                               object: query, queue: .main) { _ in
                MainActor.assumeIsolated { finish() }
            }
            if !query.start() { finish(); return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                finish()
            }
        }
    }
}
