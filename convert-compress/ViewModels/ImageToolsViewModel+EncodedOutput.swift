import Combine
import Foundation

private let previewProcessingConcurrency = 4

extension ImageToolsViewModel {
    func setupEncodedOutputObservation() {
        encodedOutputCache.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Preview

    func targetSize(for asset: ImageAsset) -> CGSize? {
        TargetSize.size(for: asset, configuration: currentConfiguration)
    }

    func displayInfo(for asset: ImageAsset) -> ImageAssetDisplayInfo {
        ImageAssetDisplayInfo(
            asset: asset,
            targetPixelSize: targetSize(for: asset),
            outputStatus: outputDisplayStatus(for: asset.id),
            selectedFormat: selectedFormat
        )
    }

    // MARK: - Clipboard

    func temporaryEncodedOutputURL(for asset: ImageAsset) async throws -> URL {
        let configuration = currentConfiguration
        let encodedOutputCache = encodedOutputCache

        return try await Task.detached(priority: .medium) {
            let data = try await encodedOutputCache.resolve(
                asset: asset,
                configuration: configuration
            ) {
                !Task.isCancelled
            }
            return try ProcessingPipeline(configuration: configuration).renderTemporaryURL(
                on: asset,
                preEncoded: data.encodedOutput
            )
        }.value
    }

    // MARK: - Background Processing

    func updateVisibleAssets(_ ids: Set<UUID>) {
        visibleAssetIDs = ids
        scheduleProcessing()
    }

    func scheduleProcessing() {
        processingDebouncer.schedule(after: .milliseconds(150)) { [weak self] in
            self?.runProcessing()
        }
    }

    // MARK: - Private

    private func runProcessing() {
        let configuration = currentConfiguration
        let assetsToProcess = images
            .filter { visibleAssetIDs.contains($0.id) }
            .filter { encodedOutputCache.needsProcessing(for: $0.id, configuration: configuration) }
        let assetIDs = Set(assetsToProcess.map(\.id))

        if let processingBatch,
           processingBatch.configuration == configuration,
           processingBatch.assetIDs == assetIDs {
            return
        }

        cancelPreviewProcessing()
        guard !assetsToProcess.isEmpty else { return }

        let batch = PreviewProcessingBatch(assetIDs: assetIDs, configuration: configuration)
        processingBatch = batch
        encodedOutputCache.markPending(
            assetIDs: assetIDs,
            configuration: configuration
        )

        processingTask = Task(priority: .utility) { [weak self] in
            await self?.processPreviews(assetsToProcess, batch: batch)
        }
    }

    private func processPreviews(
        _ assets: [ImageAsset],
        batch: PreviewProcessingBatch
    ) async {
        defer {
            finishPreviewProcessing(batch)
        }

        let semaphore = AsyncSemaphore(value: previewProcessingConcurrency)
        let encodedOutputCache = encodedOutputCache

        await withTaskGroup(of: Void.self) { group in
            for asset in assets {
                group.addTask(priority: .utility) {
                    guard !Task.isCancelled else { return }

                    await semaphore.acquire()
                    guard !Task.isCancelled else {
                        await semaphore.release()
                        return
                    }

                    do {
                        _ = try await encodedOutputCache.resolve(
                            asset: asset,
                            configuration: batch.configuration
                        ) { [weak self] in
                            guard let self else { return false }
                            return self.processingBatch?.id == batch.id
                                && self.currentConfiguration == batch.configuration
                                && self.images.contains(where: { $0.id == asset.id })
                        }
                    } catch {
                        AppLogger.processing.error("Preview encode failed for \(asset.originalURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }

                    await semaphore.release()
                }
            }
        }
    }

    private func cancelPreviewProcessing() {
        processingTask?.cancel()

        if let processingBatch {
            encodedOutputCache.removePending(
                assetIDs: processingBatch.assetIDs,
                configuration: processingBatch.configuration
            )
        }

        processingTask = nil
        processingBatch = nil
    }

    private func finishPreviewProcessing(_ batch: PreviewProcessingBatch) {
        guard processingBatch?.id == batch.id else { return }

        processingTask = nil
        processingBatch = nil
    }

    private func outputDisplayStatus(for assetID: UUID) -> ImageOutputDisplayStatus? {
        guard let status = encodedOutputCache.freshStatus(for: assetID, configuration: currentConfiguration) else {
            return nil
        }

        switch status {
        case .pending:
            return .pending
        case .ready(let data):
            return .ready(byteCount: data.data.count)
        case .failed:
            return .failed
        }
    }
}
