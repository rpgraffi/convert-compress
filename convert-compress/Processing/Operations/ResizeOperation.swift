import CoreImage
import Foundation

struct ResizeOperation: ImageOperation {
    let input: ResizeInput

    func transformed(_ image: CIImage) throws -> CIImage {
        let original = image.extent.size
        let target = ResizeMath.targetSize(for: original, input: self.input, noUpscale: true)
        let scaleX = target.width / original.width
        let scaleY = target.height / original.height
        return try lanczosScale(
            image,
            scale: Float(min(scaleX, scaleY)),
            aspectRatio: Float(scaleX / scaleY),
            targetSize: target
        )
    }
}
