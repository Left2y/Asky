import Foundation
import Testing
@testable import LocalStore

@Suite struct ClipboardClearAllTests {
    @Test func clearsAllRowsAndSearchIncludingPinnedWithoutReturningOriginalFiles() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ClipboardStore(try LocalStore(inMemoryWithRoot: root))
        for i in 0..<125 {
            try store.insert(ClipboardItem(kind: .text, text: "history \(i)", byteSize: 1,
                pinned: i == 0, contentHash: "text-\(i)"))
        }
        try store.insert(ClipboardItem(kind: .image, filePath: "/owned/image", thumbPath: "/owned/thumb",
            byteSize: 1, pinned: true, contentHash: "image"))
        try store.insert(ClipboardItem(kind: .file, filePath: "/original/file", byteSize: 1, contentHash: "file"))
        #expect(Set(try store.clearAll()) == Set(["/owned/image", "/owned/thumb"]))
        #expect(store.recent(limit: 1000).isEmpty)
        #expect(store.search("history").isEmpty)
        #expect(try store.clearAll().isEmpty)
        try store.insert(ClipboardItem(kind: .text, text: "history again", byteSize: 1, contentHash: "text-0"))
        #expect(store.search("history").count == 1)
    }
}
