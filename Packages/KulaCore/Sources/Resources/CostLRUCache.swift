import Foundation
import Synchronization

/// LRU cache with explicit cost accounting. Eviction happens on admission, so the
/// accounted total never exceeds `costLimit` (unlike NSCache, whose limits are advisory).
public final class CostLRUCache<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    private struct Entry { var value: Value; var cost: Int; var tick: UInt64 }
    private struct State {
        var entries: [Key: Entry] = [:]
        var totalCost = 0
        var tick: UInt64 = 0
    }
    private let state = Mutex(State())
    public let costLimit: Int
    public let name: String

    public init(name: String, costLimit: Int) {
        self.name = name
        self.costLimit = costLimit
    }

    public var totalCost: Int { state.withLock { $0.totalCost } }
    public var count: Int { state.withLock { $0.entries.count } }

    public func value(for key: Key) -> Value? {
        state.withLock { s in
            guard var e = s.entries[key] else { return nil }
            s.tick += 1
            e.tick = s.tick
            s.entries[key] = e
            return e.value
        }
    }

    /// Returns false if the item alone exceeds the limit (it is not cached).
    @discardableResult
    public func insert(_ value: Value, for key: Key, cost: Int) -> Bool {
        guard cost <= costLimit else { return false }
        state.withLock { s in
            if let old = s.entries.removeValue(forKey: key) { s.totalCost -= old.cost }
            while s.totalCost + cost > costLimit, let victim = s.entries.min(by: { $0.value.tick < $1.value.tick }) {
                s.entries.removeValue(forKey: victim.key)
                s.totalCost -= victim.value.cost
            }
            s.tick += 1
            s.entries[key] = Entry(value: value, cost: cost, tick: s.tick)
            s.totalCost += cost
        }
        return true
    }

    public func remove(_ key: Key) {
        state.withLock { s in
            if let old = s.entries.removeValue(forKey: key) { s.totalCost -= old.cost }
        }
    }

    public func removeAll() {
        state.withLock { s in
            s.entries.removeAll()
            s.totalCost = 0
        }
    }

    /// Trim to a fraction of the limit (used on memory pressure).
    public func trim(toFraction fraction: Double) {
        let target = Int(Double(costLimit) * fraction)
        state.withLock { s in
            while s.totalCost > target, let victim = s.entries.min(by: { $0.value.tick < $1.value.tick }) {
                s.entries.removeValue(forKey: victim.key)
                s.totalCost -= victim.value.cost
            }
        }
    }
}

public enum Budgets {
    public static let imageCacheBytes = 32 * 1024 * 1024
    public static let textCacheBytes = 16 * 1024 * 1024
    public static let historyFirstPage = 40
    public static let messageWindow = 120
    public static let decodeConcurrency = 2
    public static let piIdleSeconds: TimeInterval = 60
    public static let maxToolRounds = 50
}
