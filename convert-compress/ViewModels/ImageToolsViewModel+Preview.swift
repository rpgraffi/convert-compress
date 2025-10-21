import Foundation

extension ImageToolsViewModel {
    func previewInfo(for asset: ImageAsset) -> PreviewInfo {
        PreviewEstimator().estimate(
            for: asset,
            resizeMode: resizeMode,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
            resizeLongSide: resizeLongSide,
            compressionPercent: compressionPercent,
            selectedFormat: selectedFormat
        )
    }
}


