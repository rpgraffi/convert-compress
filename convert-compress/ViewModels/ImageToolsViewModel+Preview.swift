import Foundation

extension ImageToolsViewModel {
    func previewInfo(for asset: ImageAsset) -> PreviewInfo {
        PreviewEstimator().estimate(
            for: asset,
            resizeMode: resizeMode,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
            resizeLongEdge: resizeLongEdge,
            compressionPercent: compressionPercent,
            selectedFormat: selectedFormat
        )
    }
}


