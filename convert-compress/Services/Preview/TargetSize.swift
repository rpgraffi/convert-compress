import Foundation

enum TargetSize {
    static func size(for asset: ImageAsset, configuration: ProcessingConfiguration) -> CGSize? {
        EffectiveImageSizing.targetPixelSize(
            originalSize: asset.originalPixelSize,
            isVector: VectorImageSupport.isVectorImage(asset.originalURL),
            resize: configuration.resizeSpecification,
            selectedFormat: configuration.selectedFormat
        )
    }
}
