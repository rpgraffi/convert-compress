import Foundation

struct ExportRunner {
    let pipeline: ProcessingPipeline
    let configuration: ProcessingConfiguration
    let cacheSnapshot: [UUID: ProcessedImageData]
    let maxConcurrent: Int
    let writeAccess: ExportWriteAccess

    func run(
        targets: [ImageAsset],
        initialImages: [ImageAsset],
        didFinishAsset: @escaping @MainActor () -> Void
    ) async -> ExportRunnerResult {
        guard !targets.isEmpty else {
            return ExportRunnerResult(
                updatedImages: initialImages,
                failures: [],
                completedCount: 0,
                wasCancelled: false
            )
        }

        var updatedImages = initialImages
        var failures: [ExportAssetFailure] = []
        var completedCount = 0
        var wasCancelled = false

        await withTaskGroup(of: ExportRunnerTaskResult.self) { group in
            var iterator = targets.makeIterator()
            let limit = min(max(1, maxConcurrent), targets.count)

            func addNextTask(
                from iterator: inout IndexingIterator<[ImageAsset]>,
                to group: inout TaskGroup<ExportRunnerTaskResult>
            ) {
                guard !Task.isCancelled else { return }
                guard let asset = iterator.next() else { return }
                group.addTask(priority: .utility) {
                    guard !Task.isCancelled else {
                        return .cancelled
                    }

                    do {
                        let cached = cacheSnapshot[asset.id]
                        let preEncoded = (cached?.configuration == configuration)
                            ? cached.map { (data: $0.data, uti: $0.uti) }
                            : nil
                        let updated = try pipeline.run(
                            on: asset,
                            preEncoded: preEncoded,
                            writeAccess: writeAccess
                        )
                        return .success(original: asset, updated: updated)
                    } catch {
                        AppLogger.export.error("Pipeline run failed for \(asset.originalURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        return .failure(ExportAssetFailure(asset: asset, error: error))
                    }
                }
            }

            for _ in 0..<limit {
                addNextTask(from: &iterator, to: &group)
            }

            while let result = await group.next() {
                switch result {
                case .success(let original, let updated):
                    if let index = updatedImages.firstIndex(of: original) {
                        updatedImages[index] = updated
                    }
                    completedCount += 1
                    await didFinishAsset()

                case .failure(let failure):
                    failures.append(failure)
                    completedCount += 1
                    await didFinishAsset()

                case .cancelled:
                    wasCancelled = true
                    group.cancelAll()
                }

                if Task.isCancelled {
                    wasCancelled = true
                    group.cancelAll()
                    continue
                }

                addNextTask(from: &iterator, to: &group)
                await Task.yield()
            }
        }

        return ExportRunnerResult(
            updatedImages: updatedImages,
            failures: failures,
            completedCount: completedCount,
            wasCancelled: wasCancelled
        )
    }
}

private enum ExportRunnerTaskResult {
    case success(original: ImageAsset, updated: ImageAsset)
    case failure(ExportAssetFailure)
    case cancelled
}
