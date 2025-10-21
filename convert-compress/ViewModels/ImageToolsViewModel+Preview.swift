import Foundation

extension ImageToolsViewModel {
    func previewInfo(for asset: ImageAsset) -> PreviewInfo {
        PreviewEstimator().estimate(
            for: asset,
            resizeMode: resizeMode,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
            resizelongEdge: resizelongEdge,
            compressionPercent: compressionPercent,
            selectedFormat: selectedFormat
        )
    }
}


