import Foundation
import AppKit
import Combine

extension ImageToolsViewModel {
    // Setup comparison state observation
    func setupComparisonObservation() {
        // Observe images array changes to validate comparison selection
        $images
            .sink { [weak self] _ in
                self?.refreshComparisonPreviewIfNeeded()
            }
            .store(in: &cancellables)
        
        // Observe comparison selection changes
        $comparisonSelection
            .sink { [weak self] selection in
                guard let self else { return }
                if selection == nil {
                    self.comparisonPreview = .empty
                    self.comparisonPreviewTask?.cancel()
                    self.comparisonPreviewTask = nil
                    self.liveRenderDebouncer.cancel()
                }
                // Note: Don't trigger refresh here - let ComparisonView do it after animation
            }
            .store(in: &cancellables)
        
        // Refresh comparison preview when any pipeline-affecting setting changes
        observeConfigurationChanges { [weak self] in
            self?.scheduleComparisonPreviewRefresh()
        }
    }
    // MARK: - Comparison Flow
    
    func presentComparison(for asset: ImageAsset) {
        comparisonSelection = ComparisonSelection(assetID: asset.id)
    }
    
    func dismissComparison() {
        comparisonSelection = nil
    }
    
    func navigateToNextImage() {
        guard let selection = comparisonSelection else { return }
        guard let currentIndex = images.firstIndex(where: { $0.id == selection.assetID }) else { return }
        let nextIndex = (currentIndex + 1) % images.count
        comparisonSelection = ComparisonSelection(assetID: images[nextIndex].id)
    }
    
    func navigateToPreviousImage() {
        guard let selection = comparisonSelection else { return }
        guard let currentIndex = images.firstIndex(where: { $0.id == selection.assetID }) else { return }
        let previousIndex = (currentIndex - 1 + images.count) % images.count
        comparisonSelection = ComparisonSelection(assetID: images[previousIndex].id)
    }
    
    func refreshComparisonPreviewIfNeeded() {
        guard let selection = comparisonSelection else { return }
        guard images.contains(where: { $0.id == selection.assetID }) else {
            comparisonSelection = nil
            return
        }
    }
    
    func refreshComparisonPreview() {
        guard let selection = comparisonSelection,
              let asset = images.first(where: { $0.id == selection.assetID }) else { return }
        
        // Calculate crop region immediately for consistency
        let cropRegion = calculateCropRegion(for: asset)
        
        // Immediately show thumbnail for instant feedback
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
    
    // MARK: - Private
    
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
        
        do {
            let cached = cachedProcessedData(for: assetID)
            let pipeline = cached == nil ? buildPipeline() : nil
            let config = currentConfiguration

            let (processed, processedPixelSize, cacheEntry) = try await Task.detached(priority: .medium) {
                let data: Data
                let cacheEntry: ProcessedImageData?
                if let cached {
                    data = cached.data
                    cacheEntry = nil
                } else {
                    guard let pipeline else {
                        throw ImageOperationError.exportFailed
                    }
                    let encoded = try pipeline.renderEncodedData(on: asset)
                    data = encoded.data
                    cacheEntry = ProcessedImageData(data: data, uti: encoded.uti, configuration: config)
                }
                let image = NSImage(data: data)
                let pixelSize = ImageMetadata.pixelSize(for: data)
                return (image, pixelSize, cacheEntry)
            }.value
            
            guard await isStillSelected(assetID) else { return }
            
            await MainActor.run {
                if let cacheEntry {
                    processedCache[assetID] = cacheEntry
                }
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
            guard await isStillSelected(assetID) else { return }
            
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
    
    /// Calculate the normalized crop region (0-1 coordinates) on the original image
    func calculateCropRegion(for asset: ImageAsset) -> CGRect? {
        guard let targetSize = currentConfiguration.resizeSpecification.cropSize,
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
}

