import Foundation
import LocalStore
import UniformTypeIdentifiers

extension ClipboardAccess {
    /// Search the content and the source/type shown in the information pane.
    /// Metadata is resolved inside ToolService; dimensions are deliberately excluded.
    public static func search(in store: ClipboardStore, query: String, limit: Int = 100) -> [ClipboardItem] {
        let tokens = FTSQuery.tokens(query)
        guard !tokens.isEmpty else { return store.recent(limit: limit) }
        guard limit > 0 else { return [] }
        let contentMatches = Set(store.search(query, limit: Int.max).map(\.id))
        // Do not truncate to the visible page before matching older records.
        return Array(store.recent(limit: Int.max).sorted { $0.createdAt > $1.createdAt }.lazy.filter { item in
            if contentMatches.contains(item.id) { return true }
            let kindNames: String
            switch item.kind {
            case .text: kindNames = "文本 Text"
            case .image: kindNames = "图片 Image Images"
            case .file: kindNames = "文件 File Files"
            }
            let basic = [item.text, item.kind == .image ? item.imageTitle : nil, item.sourceApp, kindNames].compactMap { $0 }.joined(separator: " ")
            let unmatched = tokens.filter { !basic.localizedCaseInsensitiveContains($0) }
            if unmatched.isEmpty { return true }
            guard item.kind != .text else { return false }
            let paths = item.kind == .file ? item.filePaths : [item.filePath].compactMap { $0 }
            // Generic file groups have no single type in the information pane.
            guard paths.count == 1, let path = paths.first else { return false }
            let extensionName = URL(filePath: path).pathExtension
            let type = UTType(filenameExtension: extensionName)
            let names = [information(for: item).typeName, type?.localizedDescription, extensionName,
                         type?.conforms(to: .movie) == true ? "视频 Video" : nil]
                .compactMap { $0 }.joined(separator: " ")
            return unmatched.allSatisfy { names.localizedCaseInsensitiveContains($0) }
        }.prefix(limit))
    }
}
