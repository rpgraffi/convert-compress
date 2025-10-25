import Foundation
import CoreImage

struct TrueSizeEstimator {
    struct Result {
        let assetId: UUID
        let bytes: Int
    }

    // Estimate encoded byte sizes for assets concurrently. Skips flips for speed as requested.
    static func estimate(
        assets: [ImageAsset],
        configuration: ProcessingConfiguration
    ) async -> [UUID: Int] {
        guard !assets.isEmpty else { return [:] }

        // Concurrency limit to keep UI responsive
        let maxConcurrent = 4
        var results: [UUID: Int] = [:]
        var index = 0

        while index < assets.count {
            let end = min(index + maxConcurrent, assets.count)
            let slice = Array(assets[index..<end])
            await withTaskGroup(of: (UUID, Int)?.self) { group in
                for asset in slice {
                    group.addTask(priority: .utility) {
                        return estimateOne(
                            asset: asset,
                            configuration: configuration
                        )
                    }
                }
                for await item in group {
                    if let (id, bytes) = item { results[id] = bytes }
                }
            }
            index = end
            // Yield to keep UI responsive
            await Task.yield()
        }

        return results
    }

    private static func estimateOne(
        asset: ImageAsset,
        configuration: ProcessingConfiguration
    ) -> (UUID, Int)? {
        do {
            // Build a pipeline identical to the real processing path (exportDirectory not needed for estimation)
            let pipeline = PipelineBuilder().build(configuration: configuration, exportDirectory: nil)

            // Apply the same operations in-memory
            var ci = try loadCIImageApplyingOrientation(from: asset.originalURL)
            for op in pipeline.operations {
                ci = try op.transformed(ci)
            }

            // Encode using the same exporter logic as the pipeline
            let encoded = try ImageExporter.encodeToData(
                ciImage: ci,
                originalURL: asset.originalURL,
                format: pipeline.finalFormat,
                compressionQuality: pipeline.compressionPercent.map { max(min($0, 1.0), 0.01) },
                stripMetadata: pipeline.removeMetadata
            )
            let bytes = encoded.data.count
            return (asset.id, bytes)
        } catch {
            return nil
        }
    }
}


