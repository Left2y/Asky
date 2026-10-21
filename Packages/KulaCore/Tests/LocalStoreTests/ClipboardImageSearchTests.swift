import Foundation
import Testing
@testable import LocalStore

@Suite struct ClipboardImageSearchTests {
    @Test func matchesVisibleImageTitleAlongsideLiteralTextBeforeLimiting() throws {
        let store = ClipboardStore(try LocalStore(inMemoryWithRoot: tempRoot()))
        let now = Date()
        let image = ClipboardItem(kind: .image, filePath: "/missing/fixture.png", byteSize: 1,
                                  contentHash: "image", createdAt: now)
        try store.insert(image)
        for i in 1...105 {
            try store.insert(ClipboardItem(kind: .text, text: "unrelated \(i)", byteSize: 1,
                contentHash: "text-\(i)", createdAt: now.addingTimeInterval(Double(i))))
        }
        for query in ["图片", "图", "Image", "IMAGE", "im", " 图片 \n", image.imageTitle,
                      String(image.imageTitle.prefix(4)), String(image.imageTitle.prefix(10))] {
            #expect(store.search(query, limit: 100).map(\.id) == [image.id])
        }
        let literal = ClipboardItem(kind: .text, text: "图片 image caption", byteSize: 1,
                                    contentHash: "caption", createdAt: now.addingTimeInterval(200))
        try store.insert(literal)
        for query in ["图片", "image"] {
            #expect(store.search(query).map(\.id) == [literal.id, image.id])
            #expect(store.search(query, limit: 1).map(\.id) == [literal.id])
        }
        #expect(store.search("图片 caption").map(\.id) == [literal.id])
        #expect(store.search("image caption").map(\.id) == [literal.id])
        #expect(store.search("img").isEmpty)
        #expect(store.search("100%").isEmpty)
        #expect(store.search("_").map(\.id) == [image.id])
        #expect(store.search(image.imageTitle + "_missing").isEmpty)
    }
}
