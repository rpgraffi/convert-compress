import Foundation

struct ProcessingCache {
    private var storage: LRUCache<UUID, ProcessedImageData>

    init(capacity: Int = 256) {
        self.storage = LRUCache(capacity: capacity)
    }

    subscript(assetID: UUID) -> ProcessedImageData? {
        get {
            storage.peekValue(forKey: assetID)
        }
        set {
            if let newValue {
                storage.insert(newValue, forKey: assetID)
            } else {
                storage.removeValue(forKey: assetID)
            }
        }
    }

    func freshEntry(for assetID: UUID, configuration: ProcessingConfiguration) -> ProcessedImageData? {
        guard let cached = storage.peekValue(forKey: assetID),
              cached.isFresh(for: configuration) else {
            return nil
        }
        return cached
    }

    mutating func merge(_ results: [UUID: ProcessedImageData]) {
        for (assetID, data) in results {
            storage.insert(data, forKey: assetID)
        }
    }

    mutating func removeValue(forKey assetID: UUID) {
        storage.removeValue(forKey: assetID)
    }

    mutating func removeAll() {
        storage.removeAll()
    }

    func snapshot() -> [UUID: ProcessedImageData] {
        storage.dictionarySnapshot()
    }
}
