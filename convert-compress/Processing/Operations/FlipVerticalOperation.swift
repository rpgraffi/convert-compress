import CoreImage
import Foundation

/// Flips along the vertical axis (horizontal mirror / left-to-right flip).
struct FlipVerticalOperation: ImageOperation {
    func transformed(_ input: CIImage) throws -> CIImage {
        let extent = input.extent
        let transform = CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -extent.width, y: 0)
        return input.transformed(by: transform)
    }
}
