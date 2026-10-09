import Testing
import Foundation
@testable import Resources

@Suite struct ResourcesTests {
    @Test func lruRespectsCostLimitAndRecency() {
        let c = CostLRUCache<String, Int>(name: "t", costLimit: 100)
        c.insert(1, for: "a", cost: 40)
        c.insert(2, for: "b", cost: 40)
        _ = c.value(for: "a")            // a is now most recent
        c.insert(3, for: "c", cost: 40)  // evicts b
        #expect(c.value(for: "b") == nil)
        #expect(c.value(for: "a") == 1)
        #expect(c.totalCost <= 100)
        #expect(!c.insert(9, for: "huge", cost: 101))
        c.trim(toFraction: 0.5)
        #expect(c.totalCost <= 50)
    }

    @Test func budgetsMatchDocs() {
        #expect(Budgets.imageCacheBytes == 32 << 20)
        #expect(Budgets.textCacheBytes == 16 << 20)
        #expect(Budgets.historyFirstPage == 40)
        #expect(Budgets.messageWindow == 120)
        #expect(Budgets.maxToolRounds == 8)
    }

    @Test func boundedQueueDropsOldestAndCoalesces() {
        let q = BoundedQueue<String, Int>(capacity: 2)
        q.enqueue(1, key: "a")
        q.enqueue(2, key: "b")
        q.enqueue(3, key: "a")   // coalesces
        #expect(q.count == 2)
        q.enqueue(4, key: "c")   // drops oldest
        #expect(q.count == 2)
        #expect(q.droppedCount == 1)
    }

    @Test func limiterCapsConcurrency() async {
        let lim = ConcurrencyLimiter(limit: 2)
        let peak = Peak()
        await withTaskGroup(of: Void.self) { g in
            for _ in 0..<8 {
                g.addTask {
                    await lim.withPermit {
                        peak.enter()
                        try? await Task.sleep(for: .milliseconds(20))
                        peak.leave()
                    }
                }
            }
        }
        #expect(peak.max <= 2)
    }

    @Test func thumbnailDecodeIsBounded() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).png")
        try makePNG(width: 2000, height: 1000, to: url)
        let img = try #require(ThumbnailService.decode(url: url, maxPixelSize: 256))
        #expect(max(img.width, img.height) <= 256)
    }
}

final class Peak: @unchecked Sendable {
    private let l = NSLock()
    private var cur = 0
    private(set) var max = 0
    func enter() { l.withLock { cur += 1; max = Swift.max(max, cur) } }
    func leave() { l.withLock { cur -= 1 } }
}

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func makePNG(width: Int, height: Int, to url: URL) throws {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    #expect(CGImageDestinationFinalize(dest))
}
