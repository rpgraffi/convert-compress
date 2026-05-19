import Foundation

struct TrueSizeEstimator {
    static func estimate(
        assets: [ImageAsset],
        configuration: ProcessingConfiguration
    ) async -> [UUID: ProcessedImageData] {
        guard !assets.isEmpty else { return [:] }

        let pipeline = ProcessingPipeline(configuration: configuration)
        let results = await ConcurrentMap.compactMap(
            assets,
            maxConcurrent: 4,
            priority: .utility
        ) { asset in
            processOne(asset: asset, pipeline: pipeline, configuration: configuration)
        }

        return Dictionary(uniqueKeysWithValues: results)
    }

    private static func processOne(
        asset: ImageAsset,
        pipeline: ProcessingPipeline,
        configuration: ProcessingConfiguration
    ) -> (UUID, ProcessedImageData)? {
        do {
            let encoded = try pipeline.renderEncodedData(on: asset)
            let result = ProcessedImageData(
                data: encoded.data,
                uti: encoded.uti,
                configuration: configuration
            )
            return (asset.id, result)
        } catch {
            AppLogger.processing.error("Preview size estimation failed for \(asset.originalURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
