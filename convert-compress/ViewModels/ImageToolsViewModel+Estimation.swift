import Foundation

extension ImageToolsViewModel {
    private func mergeEstimatedBytes(with map: [UUID: Int]) {
        estimatedBytes.merge(map) { _, new in new }
    }

    func triggerEstimationForVisible(_ visibleAssets: [ImageAsset]) {
        // Cancel previous run
        estimationTask?.cancel()
        let resizeMode = self.resizeMode
        let resizeWidth = self.resizeWidth
        let resizeHeight = self.resizeHeight
        let resizeLongSide = self.resizeLongSide
        let selectedFormat = self.selectedFormat
        let compressionPercent = self.compressionPercent
        let removeMetadata = self.removeMetadata
        let removeBackground = self.removeBackground
        let flipV = self.flipV

        estimationTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            let enabled = visibleAssets
            let map = await TrueSizeEstimator.estimate(
                assets: enabled,
                resizeMode: resizeMode,
                resizeWidth: resizeWidth,
                resizeHeight: resizeHeight,
                resizeLongSide: resizeLongSide,
                selectedFormat: selectedFormat,
                compressionPercent: compressionPercent,
                flipV: flipV,
                removeMetadata: removeMetadata,
                removeBackground: removeBackground
            )
            self.mergeEstimatedBytes(with: map)
        }
    }
}


