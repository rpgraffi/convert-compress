import Combine
import Foundation
import Observation

private let previewProcessingConcurrency = 4

@MainActor
@Observable
final class EncodedOutputModule {
    struct PreviewProcessingBatch {
        let id = UUID()
        let assetIDs: Set<UUID>
        let configuration: ProcessingConfiguration
    }

    @ObservationIgnored private let settings: PipelineSettingsModule
    @ObservationIgnored private let assets: AssetCollectionModule
    @ObservationIgnored private let encodedOutputCache = EncodedOutputCache()
    @ObservationIgnored private var processingTask: Task<Void, Never>?
    @ObservationIgnored private var processingBatch: PreviewProcessingBatch?
    @ObservationIgnored private let processingDebouncer = Debouncer()
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    private var visibleAssetIDs: Set<UUID> = []
    private var cacheRevision: Int = 0

    init(settings: PipelineSettingsModule, assets: AssetCollectionModule) {
        self.settings = settings
        self.assets = assets

        encodedOutputCache.objectWillChange
            .sink { [weak self] _ in
                self?.cacheRevision += 1
            }
            .store(in: &cancellables)
    }

    var cache: EncodedOutputCache {
        encodedOutputCache
    }

    func targetSize(for asset: ImageAsset) -> CGSize? {
        TargetSize.size(for: asset, configuration: settings.currentConfiguration)
    }

    func displayInfo(for asset: ImageAsset) -> ImageAssetDisplayInfo {
        _ = cacheRevision
        return ImageAssetDisplayInfo(
            asset: asset,
            targetPixelSize: targetSize(for: asset),
            outputStatus: outputDisplayStatus(for: asset.id),
            selectedFormat: settings.selectedFormat
        )
    }

    func temporaryEncodedOutputURL(for asset: ImageAsset) async throws -> URL {
        let configuration = settings.currentConfiguration
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

    func resolve(
        asset: ImageAsset,
        configuration: ProcessingConfiguration,
        shouldCommit: @escaping @MainActor () -> Bool = { true }
    ) async throws -> ProcessedImageData {
        try await encodedOutputCache.resolve(
            asset: asset,
            configuration: configuration,
            shouldCommit: shouldCommit
        )
    }

    func updateVisibleAssets(_ ids: Set<UUID>) {
        visibleAssetIDs = ids
        scheduleProcessing()
    }

    func scheduleProcessing() {
        processingDebouncer.schedule(after: .milliseconds(150)) { [weak self] in
            self?.runProcessing()
        }
    }

    func removeValue(forKey assetID: UUID) {
        encodedOutputCache.removeValue(forKey: assetID)
    }

    func removeAll() {
        processingDebouncer.cancel()
        cancelPreviewProcessing()
        encodedOutputCache.removeAll()
    }

    private func runProcessing() {
        let configuration = settings.currentConfiguration
        let assetsToProcess = assets.images
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
        _ assetsToProcess: [ImageAsset],
        batch: PreviewProcessingBatch
    ) async {
        defer {
            finishPreviewProcessing(batch)
        }

        let semaphore = AsyncSemaphore(value: previewProcessingConcurrency)
        let encodedOutputCache = encodedOutputCache

        await withTaskGroup(of: Void.self) { group in
            for asset in assetsToProcess {
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
                                && self.settings.currentConfiguration == batch.configuration
                                && self.assets.images.contains(where: { $0.id == asset.id })
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
        guard let status = encodedOutputCache.freshStatus(for: assetID, configuration: settings.currentConfiguration) else {
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
