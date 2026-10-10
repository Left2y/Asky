import Foundation
import Contracts

public struct ChromeBookmark: Sendable, Hashable {
    public let title: String
    public let url: URL
}

/// Local Chrome bookmark files only. Never reads history or starts the browser.
public enum ChromeBookmarkService {
    public static func load(root: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Google/Chrome")) -> [ChromeBookmark] {
        let fm = FileManager.default
        let profiles = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        var seen = Set<URL>()
        var bookmarks: [ChromeBookmark] = []
        for profile in profiles.filter({ $0.lastPathComponent == "Default" || $0.lastPathComponent.hasPrefix("Profile ") })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).prefix(16) {
            // Signed-in Chrome keeps synced bookmarks in AccountBookmarks, local ones in Bookmarks.
            for name in ["Bookmarks", "AccountBookmarks"] {
                guard !Task.isCancelled else { return [] }
                let file = profile.appendingPathComponent(name)
                guard let size = (try? fm.attributesOfItem(atPath: file.path)[.size]) as? NSNumber,
                      size.intValue <= 8 * 1024 * 1024,
                      let data = try? Data(contentsOf: file) else { continue }
                for bookmark in decode(data) where seen.insert(bookmark.url).inserted {
                    bookmarks.append(bookmark)
                    if bookmarks.count >= 20_000 { return bookmarks }
                }
            }
        }
        return bookmarks
    }

    public static func decode(_ data: Data) -> [ChromeBookmark] {
        guard data.count <= 8 * 1024 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let roots = object["roots"] as? [String: Any] else { return [] }
        var result: [ChromeBookmark] = []
        var pending = Array(roots.values)
        var visited = 0
        while let value = pending.popLast(), visited < 40_000, result.count < 20_000 {
            guard !Task.isCancelled else { return [] }
            visited += 1
            guard let node = value as? [String: Any] else { continue }
            if node["type"] as? String == "url", let raw = node["url"] as? String,
               let url = LauncherWebURL.parse(raw) {
                let name = node["name"] as? String ?? ""
                result.append(ChromeBookmark(title: name.isEmpty ? url.absoluteString : name, url: url))
            }
            if let children = node["children"] as? [Any] { pending.append(contentsOf: children.prefix(40_000 - visited)) }
        }
        return result
    }
}
