import CoreImage
import Foundation

/// Loads a CIImage from any supported source, including vector formats.
/// Vector images rasterize at a generous size when resize operations are present.
func loadCIImage(from url: URL, operations: [ImageOperation] = []) throws -> CIImage {
    if VectorImageSupport.isVectorImage(url) {
        let intrinsic = try VectorImageSupport.intrinsicSize(for: url)
        let size = operations.containsResizeOperation ? VectorImageSupport.generousSize(for: intrinsic) : intrinsic
        return try VectorImageSupport.loadAsCIImage(from: url, targetSize: size)
    }
    return try loadCIImageApplyingOrientation(from: url)
}

private func loadCIImageApplyingOrientation(from url: URL) throws -> CIImage {
    let options: [CIImageOption: Any] = [
        .applyOrientationProperty: true
    ]
    if let image = CIImage(contentsOf: url, options: options) {
        return image
    }
    throw ImageOperationError.loadFailed
}
