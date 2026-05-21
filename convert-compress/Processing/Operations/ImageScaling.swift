import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Applies Lanczos scaling with edge clamping to prevent border artifacts.
func lanczosScale(_ input: CIImage, scale: Float, aspectRatio: Float, targetSize: CGSize) throws -> CIImage {
    let lanczos = CIFilter.lanczosScaleTransform()
    lanczos.inputImage = input.clampedToExtent()
    lanczos.scale = scale
    lanczos.aspectRatio = aspectRatio
    guard let scaled = lanczos.outputImage else { throw ImageOperationError.exportFailed }
    return scaled.cropped(to: CGRect(origin: .zero, size: targetSize))
}
