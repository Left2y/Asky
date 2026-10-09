import Foundation
import Synchronization

/// Bounded FIFO queue with key-based coalescing. When full, the oldest item is dropped.
public final class BoundedQueue<Key: Hashable & Sendable, Item: Sendable>: Sendable {
    private struct State {
        var order: [Key] = []
        var items: [Key: Item] = [:]
        var dropped = 0
    }
    private let state = Mutex(State())
    public let capacity: Int

    public init(capacity: Int) { self.capacity = capacity }

    public var count: Int { state.withLock { $0.order.count } }
    public var droppedCount: Int { state.withLock { $0.dropped } }

    /// Inserts or replaces (coalesces) the item for `key`.
    public func enqueue(_ item: Item, key: Key) {
        state.withLock { s in
            if s.items[key] != nil {
                s.items[key] = item
                return
            }
            if s.order.count >= capacity, let oldest = s.order.first {
                s.order.removeFirst()
                s.items.removeValue(forKey: oldest)
                s.dropped += 1
            }
            s.order.append(key)
            s.items[key] = item
        }
    }

    public func dequeue(max: Int) -> [(Key, Item)] {
        state.withLock { s in
            let keys = s.order.prefix(max)
            s.order.removeFirst(keys.count)
            return keys.compactMap { k in s.items.removeValue(forKey: k).map { (k, $0) } }
        }
    }

    public func remove(where predicate: (Key, Item) -> Bool) {
        state.withLock { s in
            s.order.removeAll { k in
                guard let it = s.items[k], predicate(k, it) else { return false }
                s.items.removeValue(forKey: k)
                return true
            }
        }
    }

    public func snapshot() -> [(Key, Item)] {
        state.withLock { s in s.order.compactMap { k in s.items[k].map { (k, $0) } } }
    }
}

/// Async semaphore limiting concurrent work (e.g. image decodes).
public actor ConcurrencyLimiter {
    private let limit: Int
    private var running = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(limit: Int) { self.limit = limit }

    public func acquire() async {
        if running < limit {
            running += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    public func release() {
        if !waiters.isEmpty {
            waiters.removeFirst().resume()
        } else {
            running -= 1
        }
    }

    public func withPermit<T: Sendable>(_ op: @Sendable () async throws -> T) async rethrows -> T {
        await acquire()
        do {
            let r = try await op()
            release()
            return r
        } catch {
            release()
            throw error
        }
    }
}
