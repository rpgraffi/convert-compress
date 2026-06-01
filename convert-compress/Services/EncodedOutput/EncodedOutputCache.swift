import Combine
import Foundation

enum EncodedOutputError: LocalizedError {
    case cachedFailure

    var errorDescription: String? {
        String(localized: "Image processing failed.")
    }
}

@MainActor
final class EncodedOutputCache: ObservableObject {
    @Published private var cache: ProcessingCache

    init(cache: ProcessingCache = ProcessingCache()) {
        self.cache = cache
    }

    func freshStatus(for assetID: UUID, configuration: ProcessingConfiguration) -> ProcessingCacheEntry? {
        cache.freshStatus(for: assetID, configuration: configuration)
    }

    func needsProcessing(for assetID: UUID, configuration: ProcessingConfiguration) -> Bool {
        cache.needsProcessing(for: assetID, configuration: configuration)
    }

    func markPending(assetIDs: Set<UUID>, configuration: ProcessingConfiguration) {
        cache.markPending(assetIDs: assetIDs, configuration: configuration)
    }

    func removePending(assetIDs: Set<UUID>, configuration: ProcessingConfiguration) {
        cache.removePending(assetIDs: assetIDs, configuration: configuration)
    }

    func removeValue(forKey assetID: UUID) {
        cache.removeValue(forKey: assetID)
    }

    func removeAll() {
        cache.removeAll()
    }

    func resolve(
        asset: ImageAsset,
        configuration: ProcessingConfiguration,
        shouldCommit: @escaping @MainActor () -> Bool = { true }
    ) async throws -> ProcessedImageData {
        switch cache.freshStatus(for: asset.id, configuration: configuration) {
        case .ready(let data):
            return data
        case .failed:
            throw EncodedOutputError.cachedFailure
        case .pending, nil:
            break
        }

        do {
            try Task.checkCancellation()

            let renderTask = Task.detached(priority: .utility) {
                try ProcessingPipeline(configuration: configuration).renderEncodedData(on: asset)
            }
            let encoded = try await withTaskCancellationHandler {
                try await renderTask.value
            } onCancel: {
                renderTask.cancel()
            }

            try Task.checkCancellation()

            let data = ProcessedImageData(
                data: encoded.data,
                uti: encoded.uti,
                configuration: configuration
            )

            if shouldCommit() {
                cache.storeReady(data, forKey: asset.id)
            }

            return data
        } catch {
            if shouldCommit() {
                cache.storeFailure(forKey: asset.id, configuration: configuration)
            }
            throw error
        }
    }
}
