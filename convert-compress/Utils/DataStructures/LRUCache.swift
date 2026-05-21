import Foundation

struct LRUCache<Key: Hashable, Value> {
    private var values: [Key: Value] = [:]
    private var usageOrder: [Key] = []
    let capacity: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    var count: Int {
        values.count
    }

    func peekValue(forKey key: Key) -> Value? {
        values[key]
    }

    mutating func value(forKey key: Key) -> Value? {
        guard let value = values[key] else {
            return nil
        }
        markRecentlyUsed(key)
        return value
    }

    mutating func insert(_ value: Value, forKey key: Key) {
        values[key] = value
        markRecentlyUsed(key)
        evictIfNeeded()
    }

    mutating func removeValue(forKey key: Key) {
        values.removeValue(forKey: key)
        usageOrder.removeAll { $0 == key }
    }

    mutating func removeAll() {
        values.removeAll()
        usageOrder.removeAll()
    }

    func dictionarySnapshot() -> [Key: Value] {
        values
    }

    private mutating func markRecentlyUsed(_ key: Key) {
        usageOrder.removeAll { $0 == key }
        usageOrder.append(key)
    }

    private mutating func evictIfNeeded() {
        while values.count > capacity, let leastRecentlyUsed = usageOrder.first {
            usageOrder.removeFirst()
            values.removeValue(forKey: leastRecentlyUsed)
        }
    }
}
