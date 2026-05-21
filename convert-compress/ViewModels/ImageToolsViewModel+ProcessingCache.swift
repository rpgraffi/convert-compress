import Foundation

private let previewProcessingConcurrency = 4

extension ImageToolsViewModel {

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

    // MARK: - Cache Accessors

    func cachedProcessedData(for assetID: UUID) -> ProcessedImageData? {
        processedCache.freshEntry(for: assetID, configuration: currentConfiguration)
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
            .filter { processedCache.needsProcessing(for: $0.id, configuration: configuration) }
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
        processedCache.markPending(
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

        await withTaskGroup(of: PreviewEncode.Output?.self) { group in
            for asset in assets {
                group.addTask(priority: .utility) {
                    guard !Task.isCancelled else { return nil }

                    await semaphore.acquire()
                    guard !Task.isCancelled else {
                        await semaphore.release()
                        return nil
                    }

                    let output = PreviewEncode.process(
                        asset: asset,
                        configuration: batch.configuration
                    )
                    await semaphore.release()
                    return output
                }
            }

            for await output in group {
                guard let output else { continue }
                applyPreviewProcessingOutput(output, batch: batch)
            }
        }
    }

    private func cancelPreviewProcessing() {
        processingTask?.cancel()

        if let processingBatch {
            processedCache.removePending(
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

    private func applyPreviewProcessingOutput(
        _ output: PreviewEncode.Output,
        batch: PreviewProcessingBatch
    ) {
        guard processingBatch?.id == batch.id,
              currentConfiguration == batch.configuration,
              images.contains(where: { $0.id == output.assetID }) else {
            return
        }

        switch output {
        case .ready(let assetID, let data):
            processedCache.storeReady(data, forKey: assetID)
        case .failed(let assetID):
            processedCache.storeFailure(forKey: assetID, configuration: batch.configuration)
        }
    }

    private func outputDisplayStatus(for assetID: UUID) -> ImageOutputDisplayStatus? {
        guard let status = processedCache.freshStatus(for: assetID, configuration: currentConfiguration) else {
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
