import CoreImage
import Foundation

struct CropOperation: ImageOperation {
    let targetWidth: Int
    let targetHeight: Int

    func transformed(_ input: CIImage) throws -> CIImage {
        let current = input.extent.size
        let target = CGSize(width: targetWidth, height: targetHeight)
        let scale = max(target.width / current.width, target.height / current.height)
        let scaledSize = CGSize(width: current.width * scale, height: current.height * scale)

        let scaled = try lanczosScale(
            input,
            scale: Float(scale),
            aspectRatio: 1.0,
            targetSize: scaledSize
        )

        let cropOrigin = CGPoint(
            x: ((scaledSize.width - target.width) / 2).rounded(.toNearestOrEven),
            y: ((scaledSize.height - target.height) / 2).rounded(.toNearestOrEven)
        )
        let cropRect = CGRect(origin: cropOrigin, size: target)
        return scaled
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropOrigin.x, y: -cropOrigin.y))
    }
}
