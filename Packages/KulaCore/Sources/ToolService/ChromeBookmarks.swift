import Foundation
import Contracts

public struct ChromeBookmark: Sendable, Hashable {
    public let title: String
    public let url: URL
}

/// Local Chrome bookmark files only. Never reads history or starts the browser.
public enum ChromeBookmarkService {
    public enum ReadFailure: Error, Sendable, Equatable { case permissionDenied, unreadable, invalidFolder }

    public enum AccessState: String, Sendable {
        case authorized = "已授权"
        case denied = "未授权，请选择 Chrome 书签文件夹"
        case missing = "未找到 Chrome 书签目录"
        case unreadable = "无法读取 Chrome 书签目录"
        case invalidFolder = "请选择 Chrome 或 Chrome 个人资料文件夹"
    }

    private static func resolve(root: URL, accessBookmark: Data?) throws -> URL {
        guard let accessBookmark else { return root }
        var stale = false
        do {
            return try URL(resolvingBookmarkData: accessBookmark, options: [.withSecurityScope],
                           relativeTo: nil, bookmarkDataIsStale: &stale)
        } catch { throw ReadFailure.permissionDenied }
    }

    public static func accessState(root: URL = defaultRoot, accessBookmark: Data? = nil) -> AccessState {
        do {
            let folder = try resolve(root: root, accessBookmark: accessBookmark)
            let accessed = folder.startAccessingSecurityScopedResource()
            defer { if accessed { folder.stopAccessingSecurityScopedResource() } }
            _ = try FileManager.default.attributesOfItem(atPath: folder.path)
            _ = try read(root: folder)
            return .authorized
        } catch ReadFailure.permissionDenied { return .denied }
        catch ReadFailure.invalidFolder { return .invalidFolder }
        catch {
            let error = error as NSError
            if error.code == NSFileReadNoSuchFileError { return .missing }
            if error.code == NSFileReadNoPermissionError ||
                (error.domain == NSPOSIXErrorDomain && [1, 13].contains(error.code)) { return .denied }
            return .unreadable
        }
    }

    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome")
    }

    public static func load(root: URL = defaultRoot) -> [ChromeBookmark] {
        (try? read(root: root)) ?? []
    }

    public static func read(root: URL = defaultRoot, accessBookmark: Data? = nil) throws -> [ChromeBookmark] {
        let root = try resolve(root: root, accessBookmark: accessBookmark)
        let accessed = root.startAccessingSecurityScopedResource()
        defer { if accessed { root.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        func classify(_ error: Error) -> ReadFailure {
            let error = error as NSError
            if error.code == NSFileReadNoPermissionError ||
                (error.domain == NSPOSIXErrorDomain && [1, 13].contains(error.code)) { return .permissionDenied }
            return .unreadable
        }
        func profileDirectories(in folder: URL) throws -> [URL] {
            let children = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            if children.contains(where: { ["Bookmarks", "AccountBookmarks"].contains($0.lastPathComponent) }) {
                return [folder]
            }
            let profiles = children.filter { $0.lastPathComponent == "Default" || $0.lastPathComponent.hasPrefix("Profile ") }
            if !profiles.isEmpty { return profiles }
            // The native picker can return the displayed Google parent folder.
            // Reading the known child still uses the selected scope and system access checks.
            if let chrome = children.first(where: { $0.lastPathComponent == "Chrome" }) {
                let chromeChildren = try fm.contentsOfDirectory(at: chrome, includingPropertiesForKeys: nil)
                let profiles = chromeChildren.filter { $0.lastPathComponent == "Default" || $0.lastPathComponent.hasPrefix("Profile ") }
                if !profiles.isEmpty { return profiles }
            }
            throw ReadFailure.invalidFolder
        }
        let profiles: [URL]
        do { profiles = try profileDirectories(in: root) }
        catch let failure as ReadFailure { throw failure }
        catch {
            if (error as NSError).code == NSFileReadNoSuchFileError { return [] }
            throw classify(error)
        }
        var seen = Set<URL>()
        var bookmarks: [ChromeBookmark] = []
        for profile in profiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).prefix(16) {
            for name in ["Bookmarks", "AccountBookmarks"] {
                guard !Task.isCancelled else { return [] }
                let file = profile.appendingPathComponent(name)
                let data: Data
                do {
                    let attributes = try fm.attributesOfItem(atPath: file.path)
                    guard let size = attributes[.size] as? NSNumber, size.intValue <= 8 * 1024 * 1024 else { continue }
                    data = try Data(contentsOf: file)
                } catch {
                    if (error as NSError).code == NSFileReadNoSuchFileError { continue }
                    throw classify(error)
                }
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
