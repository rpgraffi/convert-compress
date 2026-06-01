import Foundation
import UniformTypeIdentifiers

struct ExportRunner {
    let destinationResolver: ExportDestinationResolver
    let configuration: ProcessingConfiguration
    let encodedOutputCache: EncodedOutputCache
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
            var iterator = exportTargets(from: targets).makeIterator()
            let limit = min(max(1, maxConcurrent), targets.count)

            func addNextTask(
                from iterator: inout IndexingIterator<[ExportRunnerTarget]>,
                to group: inout TaskGroup<ExportRunnerTaskResult>
            ) {
                guard !Task.isCancelled else { return }
                guard let target = iterator.next() else { return }
                group.addTask(priority: .utility) {
                    guard !Task.isCancelled else {
                        return .cancelled
                    }

                    do {
                        let encoded = try await encodedOutputCache.resolve(
                            asset: target.asset,
                            configuration: configuration
                        ) {
                            !Task.isCancelled
                        }
                        let updated = try write(
                            target: target,
                            encoded: encoded.encodedOutput
                        )
                        return .success(original: target.asset, updated: updated)
                    } catch {
                        AppLogger.export.error("Export failed for \(target.asset.originalURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        return .failure(ExportAssetFailure(asset: target.asset, error: error))
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

    private func exportTargets(from assets: [ImageAsset]) -> [ExportRunnerTarget] {
        assets.enumerated().map { index, asset in
            ExportRunnerTarget(asset: asset, index: index, totalCount: assets.count)
        }
    }

    private func write(
        target: ExportRunnerTarget,
        encoded: (data: Data, uti: UTType)
    ) throws -> ImageAsset {
        let destinationURL = destinationResolver.destinationURL(
            for: ExportDestinationRequest(
                asset: target.asset,
                index: target.index,
                totalCount: target.totalCount,
                configuration: configuration,
                outputUTType: encoded.uti
            )
        )
        let destinationDirectory = destinationURL.deletingLastPathComponent()

        guard writeAccess.allowsWriting(to: destinationDirectory) else {
            throw ImageOperationError.permissionDenied
        }

        if !FileManager.default.fileExists(atPath: destinationDirectory.path) {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        }

        let temporaryURL = destinationDirectory.appendingPathComponent(
            destinationURL.deletingPathExtension().lastPathComponent
                + "_tmp_"
                + String(UUID().uuidString.prefix(8))
                + "."
                + destinationURL.pathExtension
        )
        try encoded.data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: temporaryURL, backupItemName: nil, options: [])
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        }

        var updated = target.asset
        updated.workingURL = destinationURL
        updated.isEdited = true
        return updated
    }
}

struct ExportRunnerResult {
    let updatedImages: [ImageAsset]
    let failures: [ExportAssetFailure]
    let completedCount: Int
    let wasCancelled: Bool
}

private enum ExportRunnerTaskResult {
    case success(original: ImageAsset, updated: ImageAsset)
    case failure(ExportAssetFailure)
    case cancelled
}

private struct ExportRunnerTarget {
    let asset: ImageAsset
    let index: Int
    let totalCount: Int
}
