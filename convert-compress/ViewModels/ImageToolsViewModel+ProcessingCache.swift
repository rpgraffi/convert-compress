import Foundation

extension ImageToolsViewModel {

    // MARK: - Preview

    func targetSize(for asset: ImageAsset) -> CGSize? {
        TargetSize.size(for: asset, configuration: currentConfiguration)
    }

    // MARK: - Cache Accessors

    func outputByteCount(for assetID: UUID) -> Int? {
        processedCache.freshEntry(for: assetID, configuration: currentConfiguration)?.data.count
    }

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
        processingTask?.cancel()
        let config = currentConfiguration
        let assetsToProcess = images
            .filter { visibleAssetIDs.contains($0.id) }
            .filter { processedCache[$0.id]?.configuration != config }
        guard !assetsToProcess.isEmpty else { return }

        processingTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            let results = await PreviewEncode.run(
                assets: assetsToProcess,
                configuration: config
            )
            guard !Task.isCancelled else { return }
            self.processedCache.merge(results)
        }
    }
}
