import CoreImage
import Foundation

/// Ensures the image matches target-format square restrictions by center-cropping when necessary.
struct ConstrainSizeOperation: ImageOperation {
    let targetFormat: ImageFormat
    let resize: ResizeSpecification

    func transformed(_ input: CIImage) throws -> CIImage {
        let current = input.extent.size

        guard let side = RestrictedFormatSizing.targetSquareSide(
            sourceSize: current,
            resize: resize,
            format: targetFormat
        ) else {
            return input
        }

        let target = CGSize(width: side, height: side)
        guard current != target else {
            return input
        }

        return try CropOperation(targetWidth: side, targetHeight: side)
            .transformed(input)
    }
}
