import Foundation

enum ProcessingCacheEntry {
    case pending(configuration: ProcessingConfiguration)
    case ready(ProcessedImageData)
    case failed(configuration: ProcessingConfiguration)

    var configuration: ProcessingConfiguration {
        switch self {
        case .pending(let configuration), .failed(let configuration):
            configuration
        case .ready(let data):
            data.configuration
        }
    }

    var data: ProcessedImageData? {
        guard case .ready(let data) = self else {
            return nil
        }
        return data
    }

    func isFresh(for configuration: ProcessingConfiguration) -> Bool {
        self.configuration == configuration
    }
}

struct ProcessingCache {
    private var storage: LRUCache<UUID, ProcessingCacheEntry>

    init(capacity: Int = 256) {
        self.storage = LRUCache(capacity: capacity)
    }

    func freshStatus(for assetID: UUID, configuration: ProcessingConfiguration) -> ProcessingCacheEntry? {
        guard let cached = storage.peekValue(forKey: assetID),
              cached.isFresh(for: configuration) else {
            return nil
        }
        return cached
    }

    func needsProcessing(for assetID: UUID, configuration: ProcessingConfiguration) -> Bool {
        switch freshStatus(for: assetID, configuration: configuration) {
        case nil, .pending:
            return true
        case .ready, .failed:
            return false
        }
    }

    mutating func markPending(assetIDs: Set<UUID>, configuration: ProcessingConfiguration) {
        for assetID in assetIDs {
            storage.insert(.pending(configuration: configuration), forKey: assetID)
        }
    }

    mutating func removePending(assetIDs: Set<UUID>, configuration: ProcessingConfiguration) {
        for assetID in assetIDs {
            guard case .pending(let cachedConfiguration) = storage.peekValue(forKey: assetID),
                  cachedConfiguration == configuration else {
                continue
            }
            storage.removeValue(forKey: assetID)
        }
    }

    mutating func storeReady(_ data: ProcessedImageData, forKey assetID: UUID) {
        storage.insert(.ready(data), forKey: assetID)
    }

    mutating func storeFailure(forKey assetID: UUID, configuration: ProcessingConfiguration) {
        storage.insert(.failed(configuration: configuration), forKey: assetID)
    }

    mutating func removeValue(forKey assetID: UUID) {
        storage.removeValue(forKey: assetID)
    }

    mutating func removeAll() {
        storage.removeAll()
    }
}
