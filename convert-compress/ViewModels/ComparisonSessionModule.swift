import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ComparisonSessionModule {
    var comparisonSelection: ComparisonSelection? = nil {
        didSet {
            guard comparisonSelection == nil else { return }
            comparisonPreview = .empty
            comparisonPreviewTask?.cancel()
            comparisonPreviewTask = nil
            liveRenderDebouncer.cancel()
        }
    }
    var comparisonPreview: ComparisonPreviewState = .empty

    @ObservationIgnored private let settings: PipelineSettingsModule
    @ObservationIgnored private let assets: AssetCollectionModule
    @ObservationIgnored private let encodedOutput: EncodedOutputModule
    @ObservationIgnored private var comparisonPreviewTask: Task<Void, Never>?
    @ObservationIgnored private let liveRenderDebouncer = Debouncer()

    init(
        settings: PipelineSettingsModule,
        assets: AssetCollectionModule,
        encodedOutput: EncodedOutputModule
    ) {
        self.settings = settings
        self.assets = assets
        self.encodedOutput = encodedOutput
    }

    func presentComparison(for asset: ImageAsset) {
        comparisonSelection = ComparisonSelection(assetID: asset.id)
    }

    func dismissComparison() {
        comparisonSelection = nil
    }

    func dismissIfSelected(assetIDs: Set<UUID>) {
        if comparisonSelection.map({ assetIDs.contains($0.assetID) }) == true {
            comparisonSelection = nil
        }
    }

    func navigateToNextImage() {
        guard let selection = comparisonSelection else { return }
        guard let currentIndex = assets.images.firstIndex(where: { $0.id == selection.assetID }) else { return }
        let nextIndex = (currentIndex + 1) % assets.images.count
        comparisonSelection = ComparisonSelection(assetID: assets.images[nextIndex].id)
    }

    func navigateToPreviousImage() {
        guard let selection = comparisonSelection else { return }
        guard let currentIndex = assets.images.firstIndex(where: { $0.id == selection.assetID }) else { return }
        let previousIndex = (currentIndex - 1 + assets.images.count) % assets.images.count
        comparisonSelection = ComparisonSelection(assetID: assets.images[previousIndex].id)
    }

    func selectedAsset() -> ImageAsset? {
        guard let selection = comparisonSelection else { return nil }
        return assets.images.first(where: { $0.id == selection.assetID })
    }

    func indexLabel(for asset: ImageAsset) -> String? {
        guard let currentIndex = assets.images.firstIndex(where: { $0.id == asset.id }) else {
            return nil
        }
        return "\(currentIndex + 1)/\(assets.images.count)"
    }

    func refreshComparisonPreviewIfNeeded() {
        guard let selection = comparisonSelection else { return }
        guard assets.images.contains(where: { $0.id == selection.assetID }) else {
            comparisonSelection = nil
            return
        }
    }

    func refreshComparisonPreview() {
        guard let selection = comparisonSelection,
              let asset = assets.images.first(where: { $0.id == selection.assetID }) else { return }

        let cropRegion = calculateCropRegion(for: asset)

        comparisonPreview = ComparisonPreviewState(
            originalImage: asset.thumbnail,
            processedImage: nil,
            isLoading: true,
            errorMessage: nil,
            cropRegion: cropRegion,
            originalSize: asset.originalPixelSize,
            processedSize: nil
        )

        comparisonPreviewTask?.cancel()
        comparisonPreviewTask = Task { [weak self] in
            await self?.loadComparisonPreview(for: asset)
        }
    }

    func scheduleComparisonPreviewRefresh() {
        guard comparisonSelection != nil else { return }
        liveRenderDebouncer.schedule(after: .milliseconds(250)) { [weak self] in
            self?.refreshComparisonPreview()
        }
    }

    func calculateCropRegion(for asset: ImageAsset) -> CGRect? {
        guard let targetSize = settings.currentConfiguration.resizeSpecification.cropSize,
              let originalSize = asset.originalPixelSize,
              originalSize.width > 0,
              originalSize.height > 0 else {
            return nil
        }

        return CropGeometry.normalizedCenterCropRegion(
            originalSize: originalSize,
            targetSize: targetSize
        )
    }

    private func loadComparisonPreview(for asset: ImageAsset) async {
        let assetID = asset.id
        let cropRegion = await MainActor.run { calculateCropRegion(for: asset) }

        let original = await Task.detached(priority: .medium) {
            NSImage(contentsOf: asset.originalURL)
        }.value

        let originalSize = original?.size

        guard await isStillSelected(assetID) else { return }

        await MainActor.run {
            comparisonPreview = ComparisonPreviewState(
                originalImage: original,
                processedImage: nil,
                isLoading: true,
                errorMessage: nil,
                cropRegion: cropRegion,
                originalSize: originalSize,
                processedSize: nil
            )
        }

        let configuration = settings.currentConfiguration

        do {
            let (processed, processedPixelSize) = try await Task.detached(priority: .medium) {
                let data = try await self.encodedOutput.resolve(
                    asset: asset,
                    configuration: configuration
                ) { [weak self] in
                    guard let self else { return false }
                    return self.comparisonSelection?.assetID == assetID
                        && self.settings.currentConfiguration == configuration
                }

                let image = NSImage(data: data.data)
                let pixelSize = ImageMetadata.pixelSize(for: data.data)
                return (image, pixelSize)
            }.value

            guard await isStillShowingComparison(assetID, configuration: configuration) else { return }

            await MainActor.run {
                comparisonPreview = ComparisonPreviewState(
                    originalImage: original,
                    processedImage: processed,
                    isLoading: false,
                    errorMessage: nil,
                    cropRegion: cropRegion,
                    originalSize: originalSize,
                    processedSize: processedPixelSize
                )
            }
        } catch {
            guard await isStillShowingComparison(assetID, configuration: configuration) else { return }

            await MainActor.run {
                comparisonPreview = ComparisonPreviewState(
                    originalImage: original,
                    processedImage: nil,
                    isLoading: false,
                    errorMessage: error.localizedDescription,
                    cropRegion: cropRegion,
                    originalSize: originalSize,
                    processedSize: nil
                )
            }
        }
    }

    private func isStillSelected(_ assetID: UUID) async -> Bool {
        await MainActor.run { comparisonSelection?.assetID == assetID }
    }

    private func isStillShowingComparison(
        _ assetID: UUID,
        configuration: ProcessingConfiguration
    ) async -> Bool {
        await MainActor.run {
            comparisonSelection?.assetID == assetID && settings.currentConfiguration == configuration
        }
    }
}
