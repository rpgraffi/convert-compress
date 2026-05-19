import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

struct RemoveBackgroundOperation: ImageOperation {
    func transformed(_ input: CIImage) throws -> CIImage {
        try removeBackground(from: input)
    }
}

private func generateForegroundMask(for image: CIImage) throws -> CIImage {
    let handler = VNImageRequestHandler(ciImage: image)
    let request = VNGenerateForegroundInstanceMaskRequest()
    try handler.perform([request])

    guard let result = request.results?.first else {
        throw ImageOperationError.backgroundRemovalUnavailable
    }
    let maskBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
    return CIImage(cvPixelBuffer: maskBuffer)
}

private func removeBackground(from image: CIImage) throws -> CIImage {
    let mask = try generateForegroundMask(for: image)
    let filter = CIFilter.blendWithMask()
    filter.inputImage = image
    filter.maskImage = mask
    filter.backgroundImage = CIImage.empty()
    guard let output = filter.outputImage else { throw ImageOperationError.exportFailed }
    return output
}
